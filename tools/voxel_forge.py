"""Voxel prop forge: designs the map props as coloured voxels (toy-brick style,
matching the Capybara Onsen references), greedy-merges them into a few boxes,
renders preview pictures, and writes src/shared/PropData.luau for the game.

    python tools/voxel_forge.py            # write PropData.luau and previews
    python tools/voxel_forge.py --preview  # previews only

Previews go to the folder in $PROP_PREVIEW_DIR (default: <temp>/prop_previews).
Coordinates: x right, y up, z back (the prop faces -z). Prop origin = bottom
centre. `unit` is studs per voxel.
"""

import math
import os
import random
import sys
import tempfile
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
DATA_OUT = os.path.join(ROOT, "src", "shared", "PropData.luau")
PREVIEW_DIR = os.environ.get("PROP_PREVIEW_DIR", os.path.join(tempfile.gettempdir(), "prop_previews"))


def rgb(r, g, b):
    return (r, g, b)


def lighter(c, n):
    return tuple(min(255, v + n) for v in c)


def darker(c, n):
    return tuple(max(0, v - n) for v in c)


class Vox:
    def __init__(self, unit=1.0, solid=False, glow=()):
        self.v = {}
        self.unit = unit
        self.solid = solid  # whether the built parts collide
        self.glow = set(glow)  # colours that render as Neon

    def set(self, x, y, z, c):
        self.v[(x, y, z)] = c

    def box(self, x0, y0, z0, x1, y1, z1, c):
        """Fills x0..x1-1, y0..y1-1, z0..z1-1."""
        for x in range(x0, x1):
            for y in range(y0, y1):
                for z in range(z0, z1):
                    self.v[(x, y, z)] = c

    def sphere(self, cx, cy, cz, r, c, squash=1.0):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            for y in range(int(cy - r) - 1, int(cy + r) + 2):
                for z in range(int(cz - r) - 1, int(cz + r) + 2):
                    if (x - cx) ** 2 + ((y - cy) / squash) ** 2 + (z - cz) ** 2 <= r * r:
                        self.v[(x, y, z)] = c

    def cylinder(self, cx, cz, y0, y1, r, c):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            for z in range(int(cz - r) - 1, int(cz + r) + 2):
                if (x - cx) ** 2 + (z - cz) ** 2 <= r * r:
                    for y in range(y0, y1):
                        self.v[(x, y, z)] = c

    def boxes(self):
        """Greedy-merged boxes (x, y, z, sx, sy, sz, colour) in voxel units."""
        if not self.v:
            return []
        ys = sorted({p[1] for p in self.v})
        layers = {}
        for y in ys:
            cells = {(x, z): c for (x, yy, z), c in self.v.items() if yy == y}
            layers[y] = greedy2d(cells)
        # Merge identical rectangles in consecutive layers into taller boxes.
        out = []
        open_boxes = {}
        for y in range(min(ys), max(ys) + 2):
            current = {(x, z, w, d, c) for (x, z, w, d, c) in layers.get(y, [])}
            for key in list(open_boxes):
                if key not in current:
                    y0 = open_boxes.pop(key)
                    out.append((key[0], y0, key[1], key[2], y - y0, key[3], key[4]))
            for key in current:
                if key not in open_boxes:
                    open_boxes[key] = y
        return out


def greedy2d(cells):
    """cells: {(x, z): colour} -> [(x, z, w, d, colour)] maximal rectangles."""
    remaining = dict(cells)
    rects = []
    for z in sorted({k[1] for k in cells}):
        for x in sorted(k[0] for k in cells if k[1] == z):
            if (x, z) not in remaining:
                continue
            c = remaining[(x, z)]
            w = 1
            while remaining.get((x + w, z)) == c:
                w += 1
            d = 1
            while all(remaining.get((x + i, z + d)) == c for i in range(w)):
                d += 1
            for i in range(w):
                for j in range(d):
                    del remaining[(x + i, z + j)]
            rects.append((x, z, w, d, c))
    return rects


# ---------------------------------------------------------------- preview

def render(vox, path, scale=16):
    """Isometric picture of the voxels, three shades per cube, painter's algorithm."""
    pts = list(vox.v.items())
    if not pts:
        return
    cos, sin = math.cos(math.radians(45)), math.sin(math.radians(45))

    def project(x, y, z):
        # rotate 45 deg about y, then 2:1 dimetric
        rx = x * cos - z * sin
        rz = x * sin + z * cos
        return (rx * scale, -(y * scale * 1.0) + rz * scale * 0.5)

    pts.sort(key=lambda p: (p[0][0] * sin + p[0][2] * cos + 0.001 * p[0][1] * 0, p[0][1]))
    # depth: larger rz drawn later
    pts.sort(key=lambda p: (p[0][0] * sin + p[0][2] * cos, p[0][1]))
    xs = [project(*p[0])[0] for p in pts]
    ys = [project(*p[0])[1] for p in pts]
    pad = 3 * scale
    width = int(max(xs) - min(xs) + 2 * pad + scale * 2)
    height = int(max(ys) - min(ys) + 2 * pad + scale * 2)
    img = Image.new("RGB", (width, height), (176, 218, 250))
    d = ImageDraw.Draw(img)
    ox, oy = pad - min(xs) + scale, pad - min(ys) + scale
    for (x, y, z), c in pts:
        # cube corners
        def P(dx, dy, dz):
            px, py = project(x + dx, y + dy, z + dz)
            return (px + ox, py + oy)

        top = [P(0, 1, 0), P(1, 1, 0), P(1, 1, 1), P(0, 1, 1)]
        left = [P(0, 0, 1), P(0, 1, 1), P(1, 1, 1), P(1, 0, 1)]
        right = [P(1, 0, 1), P(1, 1, 1), P(1, 1, 0), P(1, 0, 0)]
        d.polygon(top, fill=lighter(c, 26))
        d.polygon(left, fill=c)
        d.polygon(right, fill=darker(c, 34))
    img.save(path)


# ------------------------------------------------------------------ props

PINK_A, PINK_B, PINK_C = rgb(255, 176, 204), rgb(246, 140, 178), rgb(255, 208, 224)
TRUNK, TRUNK_D = rgb(112, 78, 50), rgb(82, 56, 36)


def cherry_tree():
    v = Vox(unit=1.0, solid=True)
    rng = random.Random(21)
    # trunk: flared base, tall stem, then stair-stepped branches to the clumps
    v.box(-2, 0, -2, 2, 2, 2, TRUNK)
    v.box(-1, 2, -1, 1, 11, 1, TRUNK)
    for i in range(4):  # right branch
        v.box(1 + i, 9 + i, -1, 2 + i, 10 + i, 1, TRUNK)
    for i in range(3):  # left branch
        v.box(-2 - i, 10 + i, -1, -1 - i, 11 + i, 1, TRUNK)
    for i in range(3):  # back branch
        v.box(-1, 9 + i, -2 - i, 1, 10 + i, -1 - i, TRUNK)

    def clump(cx, cy, cz, w, h, colour):
        """A rounded block of blossom with lighter top, nubs and a few hanging petals."""
        x0, z0 = cx - w // 2, cz - w // 2
        v.box(x0 + 1, cy, z0, x0 + w - 1, cy + h, z0 + w, colour)
        v.box(x0, cy, z0 + 1, x0 + w, cy + h, z0 + w - 1, colour)
        v.box(x0 + 1, cy + h, z0 + 1, x0 + w - 1, cy + h + 1, z0 + w - 1, colour)
        for _ in range(1):  # nub
            nx = rng.randint(x0 + 1, x0 + w - 3)
            nz = rng.randint(z0 + 1, z0 + w - 3)
            v.box(nx, cy + h + 1, nz, nx + 2, cy + h + 2, nz + 2, lighter(colour, 22))
        for _ in range(2):  # hanging blossoms
            hx = rng.randint(x0 + 1, x0 + w - 2)
            hz = rng.choice([z0 - 0, z0 + w - 1])
            v.box(hx, cy - 2, hz, hx + 1, cy, hz + 1, PINK_C)

    clump(0, 15, 0, 11, 4, PINK_A)      # top centre
    clump(8, 13, 1, 9, 4, PINK_B)       # right
    clump(-7, 14, 1, 8, 4, PINK_C)      # left
    clump(0, 12, -8, 8, 3, PINK_B)      # back
    clump(3, 11, 7, 7, 3, PINK_A)       # front, lower
    return v


STONE, STONE_D, STONE_L = rgb(150, 150, 158), rgb(118, 118, 128), rgb(176, 176, 184)
LAMP_GLOW, LAMP_FRAME = rgb(255, 176, 80), rgb(96, 68, 44)  # warm orange: pale glows bloom to white


def stone_lantern():
    v = Vox(unit=0.5, solid=True, glow={LAMP_GLOW})
    v.box(-4, 0, -4, 4, 2, 4, STONE_D)
    v.box(-3, 2, -3, 3, 3, 3, STONE)
    v.box(-1, 3, -1, 2, 9, 2, STONE)
    v.box(-3, 9, -3, 4, 10, 4, STONE_L)
    # lamp box: frame corners + glowing sides
    v.box(-2, 10, -2, 3, 15, 3, LAMP_GLOW)
    for x, z in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
        v.box(x, 10, z, x + 1, 15, z + 1, LAMP_FRAME)
    v.box(-2, 12, -2, 3, 13, 3, LAMP_FRAME)
    # roof
    v.box(-5, 15, -5, 6, 16, 6, STONE)
    v.box(-4, 16, -4, 5, 17, 5, STONE_L)
    v.box(-2, 17, -2, 3, 18, 3, STONE)
    v.box(-1, 18, -1, 2, 20, 2, STONE_L)
    return v


RED, RED_D, BLACK = rgb(214, 52, 46), rgb(168, 36, 34), rgb(40, 42, 54)


def torii():
    v = Vox(unit=1.0, solid=True)
    for sx in (-6, 5):
        v.box(sx - 1, 0, -1, sx + 3, 1, 3, BLACK)      # stone footing
        v.box(sx, 1, 0, sx + 2, 13, 2, RED)
        v.box(sx + 1, 1, 0, sx + 2, 13, 2, RED_D)
    v.box(-8, 13, -1, 9, 14, 3, RED)                   # shimagi (red underbeam)
    v.box(-10, 14, -1, 11, 16, 3, BLACK)               # kasagi (top beam)
    for i in range(3):                                  # upturned ends
        v.box(-12 + i, 15 + i, -1, -10 + i, 16 + i, 3, BLACK)
        v.box(11 - i, 15 + i, -1, 13 - i, 16 + i, 3, BLACK)
    v.box(-7, 10, 0, 8, 11, 2, RED)                    # nuki (lower beam)
    v.box(-1, 11, 0, 2, 13, 2, rgb(238, 196, 64))      # plaque
    return v


BAMBOO, BAMBOO_L, BAMBOO_D, LEAF = rgb(96, 178, 62), rgb(126, 204, 84), rgb(58, 128, 42), rgb(74, 160, 56)


def bamboo():
    rng = random.Random(5)
    v = Vox(unit=1.0)
    spots = [(0, 0), (3, 1), (-3, 1), (1, -3), (-1, 3)]
    for x, z in spots:
        h = rng.randint(13, 20)
        v.box(x, 0, z, x + 1, h, z + 1, BAMBOO)
        # only two ring bands per stalk keeps the box count low
        v.set(x, h // 2, z, BAMBOO_D)
        # leaf tuft
        v.box(x - 1, h - 1, z, x + 2, h, z + 1, LEAF)
        v.box(x, h - 1, z - 1, x + 1, h, z + 2, LEAF)
    return v


# -------------------------------------------------------- station row props

ORANGE, ORANGE_D, CREAM = rgb(240, 150, 40), rgb(200, 108, 30), rgb(255, 238, 200)
IRON, IRON_D, PORT_GLOW = rgb(120, 124, 136), rgb(78, 80, 92), rgb(255, 214, 110)
WOOD, WOOD_D, WOOD_L = rgb(150, 100, 60), rgb(96, 64, 40), rgb(184, 132, 84)
AWNING_RED, AWNING_WHITE = rgb(222, 56, 52), rgb(250, 246, 240)
AURA, AURA_L = rgb(170, 90, 240), rgb(214, 160, 255)


def processor_barrel():
    """The big orange processor barrel (reference/capybara-onsen-stations.webp): cream
    bands, a stone base ring, a porthole facing front (-z), a side pipe and a chimney."""
    v = Vox(unit=1.0, solid=True, glow={PORT_GLOW})
    v.cylinder(0, 0, 0, 2, 7.6, STONE)                  # stone base ring
    v.cylinder(0, 0, 2, 18, 7, ORANGE)                  # body
    v.cylinder(0, 0, 2, 3, 7, ORANGE_D)                 # dark foot band
    for y in (6, 11, 16):                               # cream bands
        v.cylinder(0, 0, y, y + 1, 7.2, CREAM)
    v.cylinder(0, 0, 18, 19, 7.4, ORANGE_D)             # top rim
    v.cylinder(0, 0, 19, 20, 6, IRON_D)                 # lid
    v.box(2, 20, 1, 5, 25, 4, IRON)                     # chimney
    v.box(1, 25, 0, 6, 26, 5, IRON_D)
    v.box(-3, 8, -8, 3, 15, -7, WOOD_D)                 # porthole frame
    v.box(-2, 9, -9, 2, 14, -8, PORT_GLOW)              # porthole glass
    v.box(7, 3, -1, 8, 17, 1, IRON)                     # side pipe
    v.box(7, 16, -1, 9, 17, 1, IRON_D)
    v.box(7, 3, -1, 9, 4, 1, IRON_D)
    return v


def deposit_stall():
    """Wooden stall with a red and white striped awning and an Aura sign; the counter
    faces front (-z). The keeper brainrot is added in code behind the counter."""
    v = Vox(unit=1.0, solid=True, glow={AURA_L})
    v.box(-6, 0, -2, 6, 3, 1, WOOD)                     # counter
    v.box(-7, 3, -3, 7, 4, 1, WOOD_L)                   # counter top
    for x in (-7, 6):                                   # posts
        v.box(x, 0, 1, x + 1, 11, 2, WOOD_D)
        v.box(x, 4, -3, x + 1, 10, -2, WOOD_D)
    for i, x in enumerate(range(-8, 8, 2)):             # striped awning, stepped slope
        c = AWNING_RED if i % 2 == 0 else AWNING_WHITE
        v.box(x, 10, -4, x + 2, 11, 0, c)
        v.box(x, 11, -1, x + 2, 12, 3, c)
        v.box(x, 9, -4, x + 2, 10, -3, c)               # front lip
    v.box(-3, 12, 0, 3, 16, 1, WOOD_D)                  # sign board
    v.box(-2, 13, -1, 2, 15, 0, CREAM)
    v.box(-1, 13, -2, 1, 15, -1, AURA)                  # aura gem on the sign
    v.box(-5, 4, -2, -3, 5, 0, AURA)                    # aura crystals on the counter
    v.box(3, 4, -2, 5, 6, 0, AURA_L)
    return v


def _board_frame(v, roof):
    """Posts and a frame around a 14 x 9 board (y 4..13) that code places at z 0."""
    for x in (-9, 7):
        v.box(x, 0, -1, x + 2, 15 if roof else 14, 1, WOOD_D)
    v.box(-9, 3, -1, 9, 4, 1, WOOD_D)
    v.box(-9, 13, -1, 9, 14, 1, WOOD_D)
    if roof:                                            # curved torii-style roof
        v.box(-11, 14, -2, 11, 15, 2, WOOD)
        v.box(-10, 15, -2, 10, 16, 2, WOOD_D)
        v.box(-13, 15, -2, -10, 16, 2, WOOD_D)
        v.box(10, 15, -2, 13, 16, 2, WOOD_D)
        v.box(-14, 16, -2, -12, 17, 2, WOOD_D)
        v.box(12, 16, -2, 14, 17, 2, WOOD_D)
        v.box(-2, 16, -1, 2, 17, 1, WOOD)
    else:
        v.box(-10, 14, -1, 10, 15, 1, WOOD)


def rim_lantern():
    """Small wooden lantern with a glowing core for the bath rims (about 2 x 3 studs)."""
    v = Vox(unit=0.25, glow={LAMP_GLOW})
    v.box(-1, 0, -1, 1, 3, 1, WOOD_D)                   # stem
    v.box(-3, 3, -3, 3, 4, 3, WOOD_D)                   # base plate
    v.box(-3, 4, -3, 3, 9, 3, LAMP_GLOW)                # glowing core
    for x, z in [(-3, -3), (2, -3), (-3, 2), (2, 2)]:   # corner frame
        v.box(x, 4, z, x + 1, 9, z + 1, WOOD_D)
    v.box(-4, 9, -4, 4, 10, 4, BLACK)                   # roof
    v.box(-2, 10, -2, 2, 11, 2, BLACK)
    return v


LEAF_A, LEAF_B = rgb(84, 168, 60), rgb(110, 194, 78)
FLOWER_W, FLOWER_P = rgb(250, 250, 255), rgb(255, 170, 205)


def bush():
    """A rounded toy-brick bush with a couple of flowers (about 6 x 5 studs)."""
    v = Vox(unit=1.0)
    v.box(-3, 0, -2, 3, 3, 2, LEAF_A)
    v.box(-2, 0, -3, 2, 3, 3, LEAF_A)
    v.box(-2, 3, -2, 2, 4, 2, LEAF_B)
    v.box(-1, 4, -1, 1, 5, 1, LEAF_B)
    v.set(1, 4, 0, FLOWER_W)
    v.set(-2, 3, 1, FLOWER_P)
    v.set(2, 2, -3, FLOWER_W)
    return v


def grass_tuft():
    """A clump of blocky grass blades (about 1.5 studs), for lawn edges (2026-10-06)."""
    v = Vox(unit=0.25)
    blades = [(-2, 0, 4, LEAF_A), (-1, -2, 5, LEAF_B), (0, 1, 6, LEAF_A), (1, -1, 4, LEAF_B), (2, 1, 5, LEAF_A), (-1, 2, 3, LEAF_B), (1, 2, 4, LEAF_B)]
    for x, z, h, c in blades:
        v.box(x, 0, z, x + 1, h, z + 1, c)
    v.box(-2, 0, -2, 3, 1, 3, LEAF_A)                  # base
    return v


BUCKET_WOOD, BUCKET_BAND = rgb(196, 140, 84), rgb(120, 120, 130)
TOWEL_A, TOWEL_B, TOWEL_C = rgb(250, 250, 252), rgb(140, 200, 255), rgb(255, 176, 196)
DUCK_Y, DUCK_O = rgb(255, 220, 50), rgb(255, 140, 30)


def wash_bucket():
    """A blocky wooden onsen wash bucket with two metal bands and water (about 1.2 studs)."""
    v = Vox(unit=0.2)
    v.box(-3, 0, -3, 3, 5, 3, BUCKET_WOOD)
    v.box(-3, 1, -3, 3, 2, 3, BUCKET_BAND)             # bands
    v.box(-3, 3, -3, 3, 4, 3, BUCKET_BAND)
    v.box(-2, 4, -2, 2, 5, 2, rgb(110, 210, 245))     # water
    return v


def towel_stack():
    """Three folded towels in a stack (about 1.6 x 1 studs)."""
    v = Vox(unit=0.2)
    for i, c in enumerate((TOWEL_B, TOWEL_A, TOWEL_C)):
        v.box(-4, i * 2, -2, 4, i * 2 + 2, 3, c)
        v.box(-4, i * 2, 3, 4, i * 2 + 1, 4, darker(c, 20))   # the folded edge
    return v


def rubber_duck():
    """A rubber duck for the baths (about 1.2 studs)."""
    v = Vox(unit=0.2)
    v.box(-3, 0, -2, 3, 3, 3, DUCK_Y)                  # body
    v.box(-2, 3, -2, 1, 6, 1, DUCK_Y)                  # head
    v.box(-2, 4, -3, 1, 5, -2, DUCK_O)                 # beak
    v.set(-2, 5, -2, BLACK)
    v.set(0, 5, -2, BLACK)
    v.box(2, 2, 2, 4, 4, 4, DUCK_Y)                    # tail
    return v


def entrance_gate():
    """Dark wooden entrance gate (like Capybara Onsen's): two posts, a lintel the noren
    curtains hang from (code adds them and the wide name board above it) and a roof
    with upturned ends. Inner opening 18 studs."""
    v = Vox(unit=1.0, solid=True)
    for x in (-11, 9):
        v.box(x, 0, -1, x + 2, 16, 1, WOOD_D)           # posts
        v.box(x - 1, 0, -2, x + 3, 1, 2, STONE_D)       # stone footings
    v.box(-12, 11, -1, 12, 12, 1, WOOD_D)               # lintel
    v.box(-14, 16, -2, 14, 17, 2, WOOD)                 # roof
    v.box(-13, 17, -2, 13, 18, 2, WOOD_D)
    v.box(-16, 17, -2, -13, 18, 2, WOOD_D)              # upturned ends
    v.box(13, 17, -2, 16, 18, 2, WOOD_D)
    v.box(-17, 18, -2, -15, 19, 2, WOOD_D)
    v.box(15, 18, -2, 17, 19, 2, WOOD_D)
    v.box(-4, 18, -1, 4, 19, 1, WOOD)                   # ridge
    return v


def sprig():
    """A small low clump of leaves (Capybara Onsen's ground cover), about 2 studs."""
    v = Vox(unit=0.5)
    v.box(-2, 0, -1, 0, 2, 1, LEAF_A)
    v.box(0, 0, -2, 2, 3, 0, LEAF_B)
    v.box(0, 0, 1, 2, 2, 3, LEAF_A)
    return v


def info_board_frame():
    v = Vox(unit=1.0, solid=True)
    _board_frame(v, True)
    return v


def market_board_frame():
    v = Vox(unit=1.0, solid=True)
    _board_frame(v, False)
    return v


# ------------------------------------------------------------- drop items
# The 20 tier drop items (Config/Tiers item names), chunky voxels in the map's
# style: about 2 studs across (unit 0.25, 8 voxels), few colours so they merge to
# a handful of boxes each (up to 50 float per plot).

DU = 0.25
YEL, YEL_D = rgb(255, 214, 60), rgb(222, 164, 30)
ORG, ORG_L = rgb(255, 128, 60), rgb(255, 176, 120)
BLK, GRY = rgb(44, 44, 52), rgb(150, 150, 160)
WHT, CYN, CYN_L = rgb(245, 248, 255), rgb(120, 220, 255), rgb(200, 244, 255)
RED, GRN, GRN_D = rgb(232, 60, 60), rgb(96, 196, 70), rgb(58, 140, 44)
BRN, BRN_D, BRN_L = rgb(140, 88, 50), rgb(96, 58, 32), rgb(196, 140, 90)
BLU, GOLD, GOLD_L = rgb(70, 130, 240), rgb(255, 196, 40), rgb(255, 236, 140)
PNK = rgb(255, 150, 190)


def rounded(v, r, y0, h, c):
    """A chunky rounded cube of half-width r from y0 up h voxels: three crossed boxes
    (cheap: 3 boxes, where a voxel sphere would split into 20+)."""
    v.box(-r, y0 + 1, -r + 1, r, y0 + h - 1, r - 1, c)
    v.box(-r + 1, y0 + 1, -r, r - 1, y0 + h - 1, r, c)
    v.box(-r + 1, y0, -r + 1, r - 1, y0 + h, r - 1, c)


def drop_cheese():
    v = Vox(DU)
    v.box(-4, 0, -3, 4, 5, 3, YEL)
    for x, y in ((-2, 3), (1, 1), (2, 3)):
        v.set(x, y, -3, YEL_D)          # holes on the front face
    return v


def drop_shrimp():
    v = Vox(DU)
    for i, (x, y) in enumerate(((-3, 0), (-1, 1), (1, 2), (2, 4))):
        v.box(x, y, -2, x + 3, y + 3, 2, ORG if i % 2 == 0 else ORG_L)
    v.box(-5, 0, -2, -3, 2, 2, ORG_L)   # tail fan
    return v


def drop_tire():
    v = Vox(DU)
    v.cylinder(0, 0, 0, 3, 4, BLK)
    v.cylinder(0, 0, 0, 3, 1.6, GRY)
    return v


def drop_ice():
    v = Vox(DU)
    v.box(-3, 0, -3, 3, 6, 3, CYN)
    v.box(-3, 5, -3, 3, 6, 3, CYN_L)
    v.box(-3, 0, -3, -2, 6, -2, CYN_L)
    return v


def drop_clock():
    v = Vox(DU)
    v.cylinder(0, 0, 0, 2, 4, RED)
    v.cylinder(0, 0, 2, 3, 3.2, WHT)
    v.box(0, 3, -2, 1, 4, 1, BLK)       # hands
    v.box(0, 3, 0, 2, 4, 1, BLK)
    return v


def drop_banana():
    v = Vox(DU)
    for x, y in ((-4, 3), (-2, 1), (0, 0), (2, 1), (3, 3)):
        v.box(x, y, -1, x + 2, y + 2, 1, YEL)
    v.box(4, 5, -1, 5, 6, 0, BRN_D)
    return v


def drop_leaf():
    v = Vox(DU)
    for i, w in enumerate((1, 2, 3, 3, 2, 1)):
        v.box(-w, 0, -3 + i, w, 1, -2 + i, GRN)
    v.box(0, 1, -3, 1, 2, 3, GRN_D)     # vein
    return v


def drop_feather():
    v = Vox(DU)
    for i, w in enumerate((1, 2, 2, 2, 1)):
        v.box(-w, i, -1, w, i + 1, 0, WHT if i < 4 else CYN_L)
    v.box(0, -2, -1, 1, 0, 0, GRY)      # quill
    v.box(-2, 1, -1, 2, 5, 0, WHT)
    return v


def drop_bean():
    v = Vox(DU)
    rounded(v, 3, 0, 5, BRN)
    v.box(-1, 4, -3, 1, 5, 3, BRN_D)     # the split
    return v


def drop_cup():
    v = Vox(DU)
    rounded(v, 3, 0, 6, WHT)
    v.box(-2, 5, -2, 2, 6, 2, BRN)
    v.box(3, 2, -1, 5, 5, 1, WHT)       # handle
    return v


def drop_bomb():
    v = Vox(DU, glow={ORG})
    rounded(v, 3, 0, 6, BLK)
    v.box(-1, 6, -1, 1, 7, 1, GRY)
    v.box(0, 7, 0, 1, 9, 1, ORG)        # lit fuse
    return v


def drop_shoe():
    v = Vox(DU)
    v.box(-4, 0, -2, 4, 1, 2, WHT)      # sole
    v.box(-4, 1, -2, 1, 4, 2, BLU)      # upper
    v.box(1, 1, -2, 4, 2, 2, BLU)       # toe
    v.box(-2, 3, -1, 1, 4, 1, WHT)      # laces
    return v


def drop_stick():
    v = Vox(DU)
    v.box(-1, 0, -5, 1, 2, 5, BRN)
    v.box(-1, 0, 5, 1, 2, 6, BRN_L)     # cut end
    v.box(1, 1, -2, 3, 2, -1, BRN)      # twig
    return v


def drop_milk():
    v = Vox(DU)
    v.box(-2, 0, -2, 2, 6, 2, WHT)
    v.box(-2, 6, -2, 2, 8, 2, BLU)      # gable top
    v.box(-2, 3, -2, 2, 4, -1, BLU)     # label band
    return v


def drop_fruit():
    v = Vox(DU)
    rounded(v, 3, 0, 6, ORG)
    v.box(0, 6, 0, 1, 7, 1, BRN_D)
    v.box(1, 6, -1, 3, 7, 1, GRN)
    return v


def drop_coconut():
    v = Vox(DU)
    rounded(v, 3, 0, 6, BRN)
    for x in (-1, 1):
        v.set(x, 4, -3, BRN_D)          # the coconut's eyes
    v.set(0, 3, -3, BRN_D)
    return v


def drop_bell():
    v = Vox(DU, glow={GOLD_L})
    v.cylinder(0, 0, 0, 2, 3.5, GOLD)
    v.cylinder(0, 0, 2, 5, 2.5, GOLD)
    v.box(-1, 5, -1, 1, 7, 1, GOLD)
    v.box(0, -1, 0, 1, 0, 1, GOLD_L)    # clapper
    return v


def drop_star():
    v = Vox(DU, glow={GOLD_L})
    v.box(-4, 2, -1, 4, 4, 1, GOLD)
    v.box(-1, 0, -1, 1, 7, 1, GOLD)
    v.box(-3, 0, -1, -2, 2, 1, GOLD)
    v.box(2, 0, -1, 3, 2, 1, GOLD)
    v.box(-1, 2, -1, 1, 4, 1, GOLD_L)   # bright centre
    return v


def drop_watermelon():
    v = Vox(DU)
    for i, w in enumerate((4, 3, 2, 1)):
        v.box(-w, i + 1, -1, w, i + 2, 1, RED)
    v.box(-4, 0, -1, 4, 1, 1, GRN_D)    # rind
    v.box(-4, 1, -1, 4, 2, 1, WHT)
    for x in (-2, 0, 2):
        v.set(x, 2, -1, BLK)            # seeds
    return v


def drop_golden_shoe():
    v = Vox(DU, glow={GOLD_L})
    v.box(-4, 0, -2, 4, 1, 2, GOLD_L)
    v.box(-4, 1, -2, 1, 4, 2, GOLD)
    v.box(1, 1, -2, 4, 2, 2, GOLD)
    v.box(-2, 3, -1, 1, 4, 1, GOLD_L)
    return v



# Lucky block chests, one per block type (Config/LuckyBlocks): a 1-stud design
# (unit 1/16) that code scales to the size it needs. Front (-z) carries the lock.
# Redesigned 2026-10-06 after Capybara Onsen's chests: a frame along every edge,
# recessed panels between the frame bars, a domed lid with a cross band, a lock plate
# with a keyhole; rare types (Diamond and up) get a gold frame and glowing corner gems.
CHEST_COLOURS = {
    # body, frame
    "Wood": (rgb(178, 120, 66), rgb(104, 66, 34)),
    "Stone": (rgb(150, 152, 162), rgb(84, 86, 98)),
    "Iron": (rgb(214, 222, 232), rgb(112, 120, 136)),
    "Gold": (rgb(255, 204, 64), rgb(176, 112, 18)),
    "Diamond": (rgb(126, 228, 255), rgb(236, 180, 40)),
    "Emerald": (rgb(72, 214, 124), rgb(236, 180, 40)),
    "Ruby": (rgb(230, 58, 86), rgb(236, 180, 40)),
    "Rainbow": (rgb(255, 136, 214), rgb(236, 180, 40)),
    "Cosmic": (rgb(130, 76, 246), rgb(236, 180, 40)),
}
CHEST_RARE = {"Diamond", "Emerald", "Ruby", "Rainbow", "Cosmic"}
LOCK = rgb(255, 214, 90)
KEYHOLE = rgb(40, 30, 30)
GEM = rgb(255, 255, 255)


def make_chest(name, body, trim):
    rare = name in CHEST_RARE

    def build():
        lock_c = LOCK if rare or name == "Gold" else darker(trim, 10)
        v = Vox(1 / 16, glow={GEM} if rare else set())
        W, H_BODY, H = 16, 8, 14          # x/z span -8..7, body y 0..7, lid y 9..13
        lo, hi = -8, 7
        panel = body
        lid = lighter(body, 18)
        # Solid core, one voxel inside the shell: the panels show recessed behind the frame.
        v.box(lo + 1, 0, lo + 1, hi, H, hi, panel)
        # Lid one voxel lighter so it reads as a separate part.
        v.box(lo + 1, 9, lo + 1, hi, H, hi, lid)
        # Frame: the 12 edges of the body box and of the lid, 1 voxel proud of the panels.
        def frame(y0, y1):
            for x in (lo, hi):
                for z in (lo, hi):
                    v.box(x, y0, z, x + 1, y1, z + 1, trim)     # vertical corner bars
            for y in (y0, y1 - 1):
                v.box(lo, y, lo, hi + 1, y + 1, lo + 1, trim)   # front / back bars
                v.box(lo, y, hi, hi + 1, y + 1, hi + 1, trim)
                v.box(lo, y, lo, lo + 1, y + 1, hi + 1, trim)   # side bars
                v.box(hi, y, lo, hi + 1, y + 1, hi + 1, trim)
        frame(0, H_BODY + 1)    # body: y 0..8 (y 8 is the band under the lid)
        frame(9, H)             # lid: y 9..13
        # Domed lid: a raised middle and a cross band over the top.
        v.box(lo + 3, H, lo + 3, hi - 2, H + 1, hi - 2, lid)
        v.box(-1, H, lo, 1, H + 1, hi + 1, trim)
        v.box(lo, H, -1, hi + 1, H + 1, 1, trim)
        # Lock plate on the front, over the seam, with a keyhole.
        v.box(-2, 5, lo - 1, 2, 11, lo, lock_c)
        v.box(-1, 6, lo - 2, 1, 10, lo - 1, lock_c)
        v.set(0, 8, lo - 2, KEYHOLE)
        v.set(0, 7, lo - 2, KEYHOLE)
        if name == "Rainbow":
            for i, c in enumerate((rgb(255, 90, 90), rgb(255, 170, 60), rgb(250, 230, 70), rgb(90, 220, 110), rgb(80, 160, 255), rgb(170, 100, 255))):
                v.box(lo + 1, 1 + i, lo, hi, 2 + i, lo + 1, c)   # stripes across the front panel
            v.box(-2, 5, lo - 1, 2, 11, lo, lock_c)               # the lock stays on top
        if name == "Cosmic":
            for x, y in ((-5, 2), (4, 3), (-4, 11), (5, 11), (3, 6)):
                v.set(x, y, lo, GEM)                              # stars on the front
        if rare:
            # A glowing gem on each top corner of the lid and the body.
            for x in (lo, hi):
                for z in (lo, hi):
                    v.set(x, H, z, GEM)
                    v.set(x, H_BODY, z, GEM)
        return v

    return build

DROPS = [
    drop_cheese, drop_shrimp, drop_tire, drop_ice, drop_clock, drop_banana, drop_leaf,
    drop_feather, drop_bean, drop_cup, drop_bomb, drop_shoe, drop_stick, drop_milk,
    drop_fruit, drop_coconut, drop_bell, drop_star, drop_watermelon, drop_golden_shoe,
]


PROPS = {
    "CherryTree": cherry_tree,
    "StoneLantern": stone_lantern,
    "Torii": torii,
    "Bamboo": bamboo,
    "ProcessorBarrel": processor_barrel,
    "DepositStall": deposit_stall,
    "InfoBoardFrame": info_board_frame,
    "RimLantern": rim_lantern,
    "Bush": bush,
    "EntranceGate": entrance_gate,
    "Sprig": sprig,
    "GrassTuft": grass_tuft,
    "WashBucket": wash_bucket,
    "TowelStack": towel_stack,
    "RubberDuck": rubber_duck,
    "MarketBoardFrame": market_board_frame,
}
for _i, _build in enumerate(DROPS, start=1):
    PROPS[f"Drop{_i}"] = _build
for _name, (_body, _trim) in CHEST_COLOURS.items():
    PROPS[f"Chest{_name}"] = make_chest(_name, _body, _trim)


# ----------------------------------------------------------------- output

def to_luau(name, vox):
    colours = []
    index = {}

    def ci(c):
        if c not in index:
            index[c] = len(colours) + 1
            colours.append(c)
        return index[c]

    # centre horizontally on the voxel bounds; y starts at 0
    xs = [p[0] for p in vox.v]
    zs = [p[2] for p in vox.v]
    ys = [p[1] for p in vox.v]
    cx = (min(xs) + max(xs) + 1) / 2
    cz = (min(zs) + max(zs) + 1) / 2
    y0 = min(ys)
    rows = []
    for (x, y, z, w, h, d, c) in vox.boxes():
        px = (x + w / 2 - cx) * vox.unit
        py = (y + h / 2 - y0) * vox.unit
        pz = (z + d / 2 - cz) * vox.unit
        rows.append(f"{{{px:g},{py:g},{pz:g},{w*vox.unit:g},{h*vox.unit:g},{d*vox.unit:g},{ci(c)}}}")
    glow = sorted(ci(c) for c in vox.glow if c in index)
    palette = ",".join(f"{{{r},{g},{b}}}" for r, g, b in colours)
    return (
        f"\t{name} = {{\n\t\tsolid = {str(vox.solid).lower()},\n\t\tglow = {{{','.join(map(str, glow))}}},\n"
        f"\t\tcolors = {{{palette}}},\n\t\tboxes = {{\n\t\t\t" + ",\n\t\t\t".join(rows) + "\n\t\t},\n\t},\n"
    ), len(rows)


def main():
    preview_only = "--preview" in sys.argv
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    body = []
    for name, build in PROPS.items():
        vox = build()
        render(vox, os.path.join(PREVIEW_DIR, f"{name}.png"))
        text, count = to_luau(name, vox)
        body.append(text)
        print(f"{name}: {len(vox.v)} voxels -> {count} boxes")
    if not preview_only:
        with open(DATA_OUT, "w", encoding="utf-8", newline="\n") as f:
            f.write(
                "--!strict\n-- GENERATED by tools/voxel_forge.py. Do not edit by hand.\n"
                "-- Each prop: colors (rgb), boxes {x, y, z, sx, sy, sz, colourIndex} in studs around the\n"
                "-- bottom centre, glow = colour indexes drawn Neon, solid = whether the parts collide.\n\n"
                "export type Prop = { solid: boolean, glow: { number }, colors: { { number } }, boxes: { { number } } }\n\n"
                "local PropData: { [string]: Prop } = {\n" + "".join(body) + "}\n\nreturn PropData\n"
            )
        print("Wrote", DATA_OUT)
    print("Previews in", PREVIEW_DIR)


if __name__ == "__main__":
    main()
