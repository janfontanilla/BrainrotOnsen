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
    """A cherry tree (2026-10-09 redrawn in more detail, user): unit 0.5 (was 1), a
    flared trunk with roots and darker bark streaks, five branches stepping out, and
    blossom clouds built as stacked rounded tiers: a darker underside, the main body,
    lighter top tiers, white-pink highlights and hanging blossoms. About 22 studs."""
    v = Vox(unit=0.5, solid=True)
    rng = random.Random(21)
    # Roots and trunk.
    v.box(-5, 0, -1, 6, 1, 2, TRUNK_D)
    v.box(-1, 0, -5, 2, 1, 6, TRUNK_D)
    v.box(-3, 0, -3, 4, 4, 4, TRUNK)
    v.box(-2, 4, -2, 3, 16, 3, TRUNK)
    v.box(-1, 16, -1, 3, 24, 3, TRUNK)                    # leans a little to +x
    for y in range(1, 23, 2):                              # bark streaks
        x = rng.choice([-2, 2, -1, 1])
        v.set(x, y, -2 if y < 16 else -1, TRUNK_D)
        v.set(2 if y < 16 else 2, y, rng.choice([-1, 0, 1]), TRUNK_D)

    def branch(x, y, z, dx, dz, length, rise):
        for k in range(length):
            v.box(x, y, z, x + 2, y + 2, z + 2, TRUNK)
            x, z = x + dx, z + dz
            if k % 2 == 1:
                y += rise
        return x, y, z

    ends = [
        branch(1, 20, 0, 1, 0, 9, 1),     # right
        branch(-1, 21, 0, -1, 0, 8, 1),   # left
        branch(0, 19, -1, 0, -1, 7, 1),   # back
        branch(1, 18, 1, 1, 1, 6, 1),     # front right
        branch(0, 22, 1, -1, 1, 6, 1),    # front left
    ]

    def clump(cx, cy, cz, w, h):
        """Stacked rounded tiers: underside, body (chamfered), two lighter top tiers."""
        def tier(y0, y1, half, colour, chamfer=1):
            v.box(cx - half + chamfer, y0, cz - half, cx + half - chamfer, y1, cz + half, colour)
            v.box(cx - half, y0, cz - half + chamfer, cx + half, y1, cz + half - chamfer, colour)
        half = w // 2
        tier(cy - 1, cy, half - 2, PINK_D)                  # darker underside
        tier(cy, cy + h, half, PINK_B, 2)                   # body
        tier(cy + h, cy + h + 1, half - 1, PINK_A, 2)       # lighter top tiers
        tier(cy + h + 1, cy + h + 2, half - 3, PINK_C, 1)
        for _ in range(3):                                  # highlight specks on top
            hx = rng.randint(cx - half + 3, cx + half - 4)
            hz = rng.randint(cz - half + 3, cz + half - 4)
            v.box(hx, cy + h + 2, hz, hx + 2, cy + h + 3, hz + 2, PINK_W)
        for _ in range(3):                                  # hanging blossoms
            hx = rng.randint(cx - half + 2, cx + half - 3)
            hz = rng.choice([cz - half + 1, cz + half - 2])
            v.box(hx, cy - 3, hz, hx + 1, cy - 1, hz + 1, PINK_C)

    clump(1, 29, 1, 20, 5)                                 # crown
    (rx, ry, rz) = ends[0]
    clump(rx + 2, ry + 1, rz, 15, 4)
    (lx, ly, lz) = ends[1]
    clump(lx - 1, ly + 2, lz, 14, 4)
    (bx, by, bz) = ends[2]
    clump(bx, by + 1, bz - 2, 13, 4)
    (fx, fy, fz) = ends[3]
    clump(fx + 1, fy, fz + 2, 12, 4)
    (gx, gy, gz) = ends[4]
    clump(gx - 1, gy + 1, gz + 2, 12, 3)
    return v


PINK_D, PINK_W = rgb(226, 116, 160), rgb(255, 232, 240)
TRUNK_D = rgb(76, 50, 30)


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


def bamboo_shoot():
    """A little clump of young bamboo shoots with pale nodes and a leaf (about 2 studs),
    scattered over the lawns (2026-10-09, user: more ground detail)."""
    v = Vox(unit=0.25)
    stalks = [(0, 0, 8), (2, 1, 6), (-1, 2, 5), (1, -2, 4)]
    for x, z, h in stalks:
        v.box(x, 0, z, x + 1, h, z + 1, BAMBOO_G)
        for y in range(2, h, 3):
            v.set(x, y, z, BAMBOO_N)                        # nodes
        v.set(x, h, z, BAMBOO_L)                            # pale tip
    v.box(1, 7, 0, 3, 8, 1, LEAF_B)                         # leaves
    v.box(-2, 5, 2, 0, 6, 3, LEAF_A)
    v.box(-1, 0, -1, 3, 1, 3, LEAF_A)                       # grassy base
    return v


def hot_tub():
    """A round wooden hot tub (2026-10-09, user's Capybara Onsen reference): plank
    staves in two shades, a cream band, a lighter rim, on a dark stone foot ring.
    Unit 0.25: about 6.5 studs across, 2.5 tall. Water, steam and a brainrot are added
    in code (Decor.hotTub)."""
    import math as _m
    v = Vox(unit=0.25, solid=True)
    for x in range(-13, 13):
        for z in range(-13, 13):
            d = _m.hypot(x + 0.5, z + 0.5)
            if d > 13:
                continue
            if d > 11.6:
                v.set(x, 0, z, TUB_STONE)                       # stone foot ring
            if d <= 11.6:
                v.set(x, 0, z, TUB_FLOOR)
            if 9.6 < d <= 11.6:
                stave = int((_m.atan2(z + 0.5, x + 0.5) + _m.pi) / (2 * _m.pi) * 18) % 2
                for y in range(1, 10):
                    c = TUB_A if stave == 0 else TUB_B
                    if y in (4, 5):
                        c = TUB_BAND
                    if y == 9:
                        c = TUB_RIM
                    v.set(x, y, z, c)
            elif d <= 9.6:
                v.set(x, 1, z, TUB_FLOOR)                       # inside floor
    return v


TUB_A, TUB_B, TUB_BAND = rgb(200, 140, 70), rgb(184, 124, 58), rgb(244, 228, 196)
TUB_RIM, TUB_FLOOR, TUB_STONE = rgb(214, 156, 86), rgb(140, 92, 50), rgb(96, 100, 116)


def make_flower(petal, centre):
    """A little flower: stem with two leaves, a cross of petals round a centre."""
    def build():
        v = Vox(unit=0.2)
        v.box(0, 0, 0, 1, 5, 1, LEAF_A)                     # stem
        v.box(1, 1, 0, 3, 2, 1, LEAF_B)                     # leaves
        v.box(-2, 2, 0, 0, 3, 1, LEAF_B)
        v.box(-1, 5, 0, 2, 6, 1, petal)                     # petals
        v.box(0, 5, -1, 1, 6, 2, petal)
        v.box(-1, 6, -1, 2, 7, 2, petal)
        v.box(0, 7, 0, 1, 8, 1, centre)                     # centre on top
        v.set(0, 6, -2, petal)
        v.set(0, 6, 2, petal)
        v.set(-2, 6, 0, petal)
        v.set(2, 6, 0, petal)
        return v
    return build


BAMBOO_G, BAMBOO_N, BAMBOO_L = rgb(92, 186, 72), rgb(150, 220, 110), rgb(196, 236, 150)
FLOWERS = {
    "Flower1": make_flower(rgb(255, 150, 196), rgb(255, 220, 80)),   # pink
    "Flower2": make_flower(rgb(250, 250, 255), rgb(255, 200, 40)),   # white daisy
    "Flower3": make_flower(rgb(140, 160, 255), rgb(255, 240, 160)),  # blue
    "Flower4": make_flower(rgb(255, 214, 60), rgb(230, 120, 40)),    # yellow
}


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


def planter():
    """A wooden flower box with bamboo shoots and flowers, for beside the stations
    (about 3 x 1.5 x 3 studs, 2026-10-06)."""
    v = Vox(unit=0.25)
    v.box(-6, 0, -3, 6, 4, 3, BUCKET_WOOD)                # box
    v.box(-6, 3, -3, 6, 4, -2, darker(BUCKET_WOOD, 30))   # rim, front
    v.box(-6, 3, 2, 6, 4, 3, darker(BUCKET_WOOD, 30))     # rim, back
    v.box(-5, 4, -2, 5, 5, 2, LEAF_A)                     # leaves over the soil
    for x, h in ((-4, 9), (-1, 12), (3, 10)):
        v.box(x, 5, -1, x + 1, 5 + h, 0, rgb(96, 196, 70))   # bamboo shoots
        v.box(x - 1, 4 + h, -1, x + 2, 5 + h, 0, LEAF_B)
    for x, z, c in ((-3, -2, FLOWER_P), (1, 1, FLOWER_W), (4, -2, FLOWER_P), (-5, 1, FLOWER_W)):
        v.box(x, 5, z, x + 1, 6, z + 1, c)
    return v


TUNG_WOOD, TUNG_BARK, TUNG_CUT = rgb(206, 150, 92), rgb(140, 92, 52), rgb(236, 200, 146)
TUNG_EYE, TUNG_PUPIL, TUNG_NOSE = rgb(255, 255, 255), rgb(36, 28, 24), rgb(236, 120, 70)
TUNG_GRAIN, BAT_WOOD = rgb(176, 124, 74), rgb(150, 98, 52)


def tung_host():
    """Tung Tung Tung Sahur for the tutorial host (2026-10-09 redesign from the user's
    cartoon references): a tall rounded wooden log with vertical wood grain and a wavy
    top, small round black eyes with a shine, a round orange nose and a smile, stick
    arms and legs with little feet. His right arm holding the bat up is TungHostArm
    (it waves). Unit 0.2."""
    v = Vox(unit=0.2)
    for x in (-2, 2):                                          # stick legs
        v.box(x, 1, 0, x + 1, 7, 1, TUNG_BARK)
    v.box(-3, 0, -2, -1, 1, 1, TUNG_BARK)                      # feet
    v.box(2, 0, -2, 4, 1, 1, TUNG_BARK)
    v.box(-5, 7, -3, 6, 27, 4, TUNG_WOOD)                      # the log
    for x, z in ((-5, -3), (5, -3), (-5, 3), (5, 3)):          # rounded edges
        for y in range(7, 27):
            v.v.pop((x, y, z), None)
    v.box(-4, 27, -2, 5, 28, 3, TUNG_CUT)                      # wavy top
    for x, z in ((-2, 0), (1, -1), (3, 1), (0, 2)):
        v.set(x, 28, z, TUNG_CUT)
    for x, z, y0, y1 in ((-3, -3, 8, 18), (3, -3, 9, 19), (-1, -3, 8, 12), (1, -3, 9, 12),
                         (-2, -3, 23, 26), (2, -3, 23, 26),
                         (-5, -1, 8, 26), (-5, 1, 9, 24), (5, -1, 10, 25), (5, 1, 8, 23), (-4, -3, 10, 24), (4, -3, 9, 22),
                         (-2, 3, 8, 26), (0, 3, 9, 25), (2, 3, 8, 24)):
        v.box(x, y0, z, x + 1, y1, z + 1, TUNG_GRAIN)          # wood grain
    f = -4                                                     # face plane, in front of the log
    for ex in (-3, 2):
        v.box(ex, 19, f, ex + 2, 22, f + 1, TUNG_PUPIL)        # round black eyes
        v.set(ex, 21, f, TUNG_EYE)                             # shine
    v.box(0, 16, -5, 1, 18, -3, TUNG_NOSE)                     # round nose
    v.box(-1, 13, f, 2, 14, f + 1, TUNG_PUPIL)                 # smile
    v.set(-2, 14, f, TUNG_PUPIL)
    v.set(2, 14, f, TUNG_PUPIL)
    v.box(6, 11, 0, 7, 19, 1, TUNG_WOOD)                       # left stick arm (viewer's right)
    v.set(6, 10, 0, TUNG_BARK)
    return v


def tung_host_arm():
    """Tung's right stick arm, the shoulder at the top, holding his bat up in front of
    it; the host rotates it about the shoulder to wave."""
    v = Vox(unit=0.2)
    v.box(0, 0, 0, 1, 8, 1, TUNG_WOOD)                         # arm
    v.set(0, -1, 0, TUNG_BARK)                                 # hand
    v.box(0, -3, -1, 1, 4, 0, BAT_WOOD)                        # bat handle in the hand
    v.box(-1, 4, -2, 1, 15, 0, BAT_WOOD)                       # bat barrel, pointing up
    v.box(-1, 15, -2, 1, 16, 0, darker(BAT_WOOD, 20))
    return v


KOI_WHITE, KOI_RED, KOI_DARK = rgb(246, 246, 250), rgb(232, 70, 52), rgb(40, 36, 40)
STATUE_STONE = rgb(170, 172, 180)


def koi_statue():
    """A fountain koi (2026-10-09, user reference "Spitting Koi Fish Fountain"; more
    detail the same day): a white koi with red patches leaping up out of its fanned
    tail on a two-step stone pedestal, leaning forward, big open mouth at the front
    (-z) top where server/Plots adds the water spout. Unit 0.2, about 2 x 4.5 studs."""
    v = Vox(unit=0.2)
    lip = rgb(255, 150, 70)
    eye_ring = rgb(255, 255, 255)
    stone_d = darker(STATUE_STONE, 24)
    # pedestal: wide step, narrower top with a darker edge
    v.box(-5, 0, -5, 5, 2, 5, stone_d)
    v.box(-4, 2, -4, 4, 3, 4, STATUE_STONE)
    # tail fanned out on the pedestal, behind (+z)
    v.box(-4, 3, 1, 4, 4, 5, KOI_RED)
    v.box(-3, 4, 2, 3, 5, 4, KOI_WHITE)
    v.box(-5, 3, 3, -3, 5, 5, KOI_RED)
    v.box(3, 3, 3, 5, 5, 5, KOI_RED)
    # body: narrow at the tail, thick in the middle, leaning forward as it rises
    v.box(-2, 3, -1, 2, 7, 2, KOI_WHITE)
    v.box(-3, 7, -2, 3, 12, 2, KOI_WHITE)
    v.box(-3, 12, -3, 3, 15, 1, KOI_WHITE)
    # head, forward and up, with a big open mouth and orange lips
    v.box(-3, 15, -5, 3, 19, 0, KOI_WHITE)
    v.box(-2, 16, -6, 2, 19, -5, lip)                 # lips
    v.box(-1, 17, -6, 1, 18, -5, KOI_DARK)            # the open mouth
    v.box(-1, 17, -5, 1, 18, -4, KOI_DARK)
    for x in (-3, 2):
        v.box(x, 16, -4, x + 1, 18, -2, eye_ring)       # eyes
        v.set(x + (0 if x < 0 else 0), 17, -3, KOI_DARK)
    # red patches, a little irregular
    v.box(-3, 9, -2, -2, 12, 1, KOI_RED)
    v.box(2, 8, -1, 3, 10, 2, KOI_RED)
    v.box(-1, 18, -3, 2, 19, 0, KOI_RED)              # cap patch on the head
    v.box(-3, 13, -2, -2, 15, 0, KOI_RED)
    # dorsal fin along the back, pectoral fins on the sides
    v.box(-1, 9, 2, 1, 15, 3, KOI_RED)
    v.box(-1, 11, 3, 1, 14, 4, KOI_RED)
    v.box(-5, 9, -1, -3, 10, 1, KOI_RED)
    v.box(3, 9, -1, 5, 10, 1, KOI_RED)
    v.box(-4, 8, -1, -3, 9, 1, KOI_WHITE)
    v.box(3, 8, -1, 4, 9, 1, KOI_WHITE)
    return v


def make_koi(base, patch, patches, fin):
    """A swimming koi seen from above (2026-10-09, user: the block fish looked bad):
    rounded head with pink lips and eyes at the front (-z), a plump body tapering to
    a fanned two-lobed tail, side fins and a dorsal fin, patches of a second colour.
    Unit 0.125: about 0.9 x 2.4 studs. KoiController swims them round the pond."""
    def build():
        v = Vox(unit=0.125)
        v.box(-1, 0, -10, 1, 2, -9, rgb(240, 150, 150))      # lips
        v.box(-2, 0, -9, 2, 3, -7, base)                       # head
        v.box(-3, 0, -7, 3, 3, 1, base)                        # body
        v.box(-2, 3, -6, 2, 4, 0, base)                        # rounded back
        v.box(-2, 0, 1, 2, 3, 4, base)
        v.box(-1, 0, 4, 1, 2, 6, base)                         # tail root
        for x0, y0, z0, x1, y1, z1 in patches:
            v.box(x0, y0, z0, x1, y1, z1, patch)
        v.box(-2, 1, 6, 2, 2, 7, fin)                          # tail fan
        v.box(-3, 1, 7, 3, 2, 9, fin)
        for x in (-3, 2):                                      # eyes
            v.set(x if x < 0 else x - 1, 2, -8, KOI_DARK)
        v.box(-5, 0, -5, -3, 1, -2, fin)                       # side fins
        v.box(3, 0, -5, 5, 1, -2, fin)
        v.box(-6, 0, -4, -5, 1, -2, fin)
        v.box(5, 0, -4, 6, 1, -2, fin)
        v.box(0, 4, -3, 1, 5, 1, fin)                          # dorsal fin
        # notch between the tail lobes
        for z in (8,):
            for x in (-1, 0):
                v.v.pop((x, 1, z), None)
        return v
    return build


KOI_ORANGE, KOI_GOLD = rgb(255, 128, 40), rgb(255, 196, 60)
KOI_FIN = rgb(255, 236, 228)
KOIS = {
    # kohaku: white with red patches
    "Koi1": make_koi(KOI_WHITE, KOI_RED, [(-2, 2, -9, 2, 3, -7), (-2, 2, -5, 1, 4, -1), (0, 2, 0, 2, 3, 3)], KOI_FIN),
    # orange with white patches
    "Koi2": make_koi(KOI_ORANGE, KOI_WHITE, [(-1, 2, -8, 2, 3, -6), (-2, 2, -2, 2, 4, 1)], rgb(255, 210, 170)),
    # gold
    "Koi3": make_koi(KOI_GOLD, rgb(255, 240, 160), [(-1, 3, -5, 1, 4, 0)], rgb(255, 232, 170)),
    # sanke: white, red and black spots
    "Koi4": make_koi(KOI_WHITE, KOI_RED, [(-2, 2, -6, 0, 4, -3), (1, 2, -1, 2, 3, 2)], KOI_FIN),
}


_sanke_base = KOIS["Koi4"]


def _sanke():
    v = _sanke_base()
    for x, y, z in ((1, 3, -4), (-2, 2, 1), (2, 2, -6), (0, 3, -1)):
        v.set(x, y, z, KOI_DARK)
    return v


KOIS["Koi4"] = _sanke


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
# The 20 tier drop items (Config/Tiers item names) in the map's voxel style: about
# 2 studs across at unit 0.125 (16 voxels; 2026-10-09 redrawn in more detail, user:
# "they just look like blocks"), with highlights and small details. Up to 50 float
# per plot, so keep each to a few dozen boxes.

DU = 0.125  # 16 voxels = 2 studs
YEL, YEL_D, YEL_L = rgb(255, 210, 60), rgb(214, 156, 28), rgb(255, 236, 140)
ORG, ORG_L, ORG_D = rgb(255, 128, 60), rgb(255, 184, 130), rgb(214, 86, 34)
BLK, BLK_L, GRY, GRY_L = rgb(40, 40, 48), rgb(78, 78, 90), rgb(150, 150, 162), rgb(212, 214, 222)
WHT, CYN, CYN_L, CYN_D = rgb(248, 250, 255), rgb(120, 214, 250), rgb(206, 244, 255), rgb(76, 170, 222)
RED, RED_D, GRN, GRN_D, GRN_L = rgb(234, 58, 58), rgb(176, 30, 40), rgb(96, 196, 70), rgb(52, 136, 44), rgb(160, 230, 110)
BRN, BRN_D, BRN_L = rgb(140, 88, 50), rgb(92, 56, 30), rgb(200, 146, 94)
BLU, BLU_D, GOLD, GOLD_L, GOLD_D = rgb(70, 130, 240), rgb(40, 84, 190), rgb(255, 192, 40), rgb(255, 238, 150), rgb(206, 140, 20)
PNK = rgb(255, 150, 190)


def ell(v, cx, cy, cz, rx, ry, rz, c):
    """Ellipsoid centred on (cx, cy, cz) (voxel centres), radii in voxels."""
    for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for z in range(int(cz - rz) - 1, int(cz + rz) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2 <= 1:
                    v.v[(x, y, z)] = c


def disc_z(v, cx, cy, z0, z1, r, c):
    """A disc facing the front (axis along z), z0..z1-1."""
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                for z in range(z0, z1):
                    v.v[(x, y, z)] = c


def light_top(v, c_from, c_to):
    """Recolours the exposed top voxels of colour c_from (a highlight)."""
    for (x, y, z), c in list(v.v.items()):
        if c == c_from and (x, y + 1, z) not in v.v:
            v.v[(x, y, z)] = c_to


def front(v, c_from, c_to):
    """Recolours the frontmost (-z) voxels of colour c_from."""
    for (x, y, z), c in list(v.v.items()):
        if c == c_from and (x, y, z - 1) not in v.v:
            v.v[(x, y, z)] = c_to


def drop_cheese():
    """A wedge with a pale rind on top, holes on every face."""
    v = Vox(DU)
    for z in range(-6, 7):
        w = 7 - (z + 6) // 2
        v.box(-w, 0, z, w + 1, 9, z + 1, YEL)
    light_top(v, YEL, YEL_L)
    for x, y, z in ((-4, 6, -6), (2, 3, -6), (4, 7, -6), (-1, 2, -6), (-3, 3, -5), (3, 8, -1), (-2, 8, 2), (5, 5, -4)):
        for dx in (0, 1):
            for dy in (0, 1):
                v.v.pop((x + dx, y + dy, z), None)      # carve the hole
                v.v[(x + dx, y + dy, z + 1)] = YEL_D    # its shadowed back
    return v


def drop_shrimp():
    """A curled shrimp: banded body along an arc, fanned tail, eye, antennae, legs."""
    v = Vox(DU)
    import math as _m
    for i in range(9):
        a = _m.radians(200 - i * 26)
        cx, cy = _m.cos(a) * 5, _m.sin(a) * 5 + 6
        r = 3.2 - i * 0.22
        ell(v, cx, cy, 0, r, r, 2.6, ORG if i % 2 == 0 else ORG_L)
    for dx, dy in ((5, 1), (6, 0), (6, 2), (7, 1)):          # tail fan
        v.box(dx, dy, -2, dx + 1, dy + 1, 3, ORG_D)
    v.box(-6, 8, -3, -5, 9, -2, BLK)                          # eye
    v.box(-5, 9, -3, -4, 10, -2, WHT)
    for i in range(6):                                        # antennae
        v.set(-7 - i // 2, 10 + i, -1, ORG_D)
        v.set(-6 - i // 2, 11 + i, 1, ORG_D)
    for x in (-3, -1, 1):                                     # little legs
        v.box(x, 1, -2, x + 1, 3, -1, ORG_D)
    return v


def drop_tire():
    """A standing tyre: black ring with tread blocks, silver rim, hub and bolts."""
    v = Vox(DU)
    disc_z(v, 0, 7, -3, 3, 7.5, BLK)
    import math as _m
    for k in range(12):                                       # tread blocks round the outside
        a = k * _m.pi / 6
        x, y = round(_m.cos(a) * 7.5), round(_m.sin(a) * 7.5) + 7
        v.box(x, y, -3, x + 1, y + 1, 3, BLK_L)
    disc_z(v, 0, 7, -4, -3, 4.6, GRY)                         # rim (front)
    disc_z(v, 0, 7, -4, -3, 3.2, GRY_L)
    disc_z(v, 0, 7, -5, -4, 1.4, GRY)                         # hub
    for x, y in ((-2, 7), (2, 7), (0, 9), (0, 5)):
        v.set(x, y, -4, BLK_L)                                # bolts
    return v


def drop_ice():
    """An ice cube: pale bevelled edges, a shine streak, a bubble or two."""
    v = Vox(DU)
    v.box(-5, 0, -5, 6, 11, 6, CYN)
    for x in (-5, 5):                                         # bevel the vertical edges
        for z in (-5, 5):
            for y in range(0, 11):
                v.v.pop((x, y, z), None)
    light_top(v, CYN, CYN_L)
    for y in range(1, 10):
        v.set(-4, y, -5, CYN_L)                               # front-left edge highlight
    for i in range(5):
        v.set(-2 + i, 3 + i, -5, WHT)                         # diagonal shine
        v.set(-1 + i, 3 + i, -5, WHT)
    for x, y in ((3, 2), (2, 4)):
        v.set(x, y, -5, CYN_D)                                # bubbles
    return v


def drop_clock():
    """An alarm clock: red body, white face with marks and hands, twin bells, legs."""
    v = Vox(DU)
    disc_z(v, 0, 7, -2, 3, 6.5, RED)
    disc_z(v, 0, 7, -3, -2, 5.2, WHT)
    for x, y in ((0, 11), (0, 3), (-4, 7), (4, 7)):
        v.set(x, y, -3, BLK)                                  # 12 / 6 / 9 / 3
    v.box(0, 7, -4, 1, 11, -3, BLK)                           # minute hand
    v.box(1, 7, -4, 3, 8, -3, BLK)                            # hour hand
    v.set(0, 7, -4, RED_D)
    ell(v, -4, 13, 0, 2.2, 1.6, 2.2, GOLD)                    # bells
    ell(v, 4, 13, 0, 2.2, 1.6, 2.2, GOLD)
    v.box(-1, 13, 0, 2, 14, 1, GOLD_D)                        # hammer
    for x in (-4, 4):
        v.box(x, -1, -1, x + 1, 1, 1, BLK)                    # legs
    light_top(v, RED, rgb(255, 110, 110))
    return v


def drop_banana():
    """A curved banana with a brown stem and tip and a ridge line."""
    v = Vox(DU)
    import math as _m
    for i in range(13):
        a = _m.radians(200 + i * 11.5)
        cx, cy = _m.cos(a) * 8, _m.sin(a) * 8 + 10
        ell(v, cx, cy, 0, 2.2, 2.2, 2.2, YEL)
    light_top(v, YEL, YEL_L)
    import math as _m2
    for i in range(1, 12):
        a = _m2.radians(200 + i * 11.5)
        v.set(round(_m2.cos(a) * 8), round(_m2.sin(a) * 8 + 10), -2, YEL_D)   # ridge
    v.box(6, 6, -1, 8, 9, 1, BRN)                             # stem
    v.box(-8, 6, -1, -7, 7, 1, BRN_D)                         # tip
    return v


def drop_leaf():
    """A pointed leaf, lighter on one half, with a vein and side veins, and a stem."""
    v = Vox(DU)
    for z in range(-7, 8):
        w = int(round(5 * (1 - (z / 7.5) ** 2)))
        v.box(-w, 0, z, w + 1, 2, z + 1, GRN)
        v.box(0, 1, z, w + 1, 2, z + 1, GRN_L)                # lit half
    v.box(0, 2, -6, 1, 3, 8, GRN_D)                           # vein
    for z, s in ((-3, 1), (0, -1), (2, 1), (4, -1), (-1, 1)):
        for k in range(1, 4):
            v.set(s * k, 2, z + k, GRN_D)                     # side veins
    v.box(0, 1, 8, 1, 2, 10, BRN)                             # stem
    return v


def drop_feather():
    """A curved feather: white vane with blue tips, barb lines, grey quill."""
    v = Vox(DU)
    for y in range(0, 15):
        bend = (y * y) // 40
        w = 1 if y < 2 else (3 if y < 12 else 2)
        if y >= 2:
            v.box(-w + bend, y, -1, w + 1 + bend, y + 1, 1, WHT if y < 12 else CYN)
            if y % 3 == 0:
                v.set(-w + bend, y, -1, CYN_L)                # barb lines
                v.set(w + bend, y, -1, CYN_L)
        v.set(bend, y, -2, GRY)                               # the shaft
    v.box(0, -2, -2, 1, 2, -1, GRY_L)                         # quill
    return v


def drop_bean():
    """A coffee bean: glossy brown oval with its S-shaped groove."""
    v = Vox(DU)
    ell(v, 0, 5, 0, 6, 5, 4.5, BRN)
    light_top(v, BRN, BRN_L)
    for z in range(-5, 6):
        x = round(1.2 * (1 if z > 1 else (-1 if z < -1 else 0)))
        v.set(x, 10, z, BRN_D)
        v.set(x, 9, z, BRN_D)
    v.set(-3, 9, -2, rgb(240, 200, 150))                      # shine
    return v


def drop_cup():
    """A cappuccino: white cup on a saucer, coffee with a cream heart, handle, steam."""
    v = Vox(DU)
    for y in range(0, 2):                                     # saucer
        for x in range(-8, 9):
            for z in range(-8, 9):
                if x * x + z * z <= 60:
                    v.v[(x, y, z)] = GRY_L
    v.cylinder(0, 0, 2, 10, 5.5, WHT)                         # cup
    v.cylinder(0, 0, 9, 10, 4.5, BRN)                         # coffee
    for x, z in ((-1, 0), (1, 0), (-2, -1), (2, -1), (-1, -1), (0, -1), (1, -1), (0, 1), (-2, -2), (-1, -2), (1, -2), (2, -2)):
        v.set(x, 9, z, rgb(250, 230, 200))                    # cream heart
    v.box(6, 4, -1, 7, 8, 1, WHT)                             # handle
    v.box(5, 7, -1, 7, 8, 1, WHT)
    v.box(5, 4, -1, 7, 5, 1, WHT)
    for i, (x, z) in enumerate(((0, 0), (1, 0), (0, 0), (-1, 0))):
        v.set(x, 11 + i, z, GRY_L)                            # steam
    return v


def drop_bomb():
    """A cartoon bomb: black ball with a shine, grey cap, curly fuse, glowing spark."""
    v = Vox(DU, glow={YEL, ORG})
    ell(v, 0, 6, 0, 6.5, 6.5, 6.5, BLK)
    for x, y in ((-3, 9), (-4, 8), (-3, 8), (-2, 10)):
        v.set(x, y, -5, BLK_L)                                # shine
    v.cylinder(0, 0, 12, 14, 2, GRY)
    for i, (x, y) in enumerate(((0, 14), (1, 15), (2, 16), (2, 17))):
        v.set(x, y, 0, BRN)                                   # fuse
    v.set(3, 18, 0, ORG)                                      # spark
    v.set(2, 18, 0, YEL)
    v.set(3, 17, 0, YEL)
    v.set(4, 18, 0, YEL)
    v.set(3, 19, 0, YEL)
    return v


def _sneaker(v, upper, upper_d, trim, sole):
    v.box(-8, 0, -3, 8, 2, 3, sole)                           # sole
    v.box(-8, 2, -3, 3, 7, 3, upper)                          # body
    v.box(3, 2, -3, 8, 4, 3, upper)                           # toe
    v.box(5, 2, -3, 8, 3, 3, trim)                            # toe cap
    v.box(-8, 7, -2, -4, 9, 2, upper)                         # collar / heel
    v.box(-8, 5, -3, -7, 9, 3, upper_d)                       # heel tab
    for x in (-3, -1, 1):
        v.box(x, 7, -2, x + 1, 8, 2, trim)                    # laces
    for x in range(-6, 3):                                    # side stripe
        v.set(x, 3 + (x + 6) // 3, -3, trim)
        v.set(x, 3 + (x + 6) // 3, 2, trim)
    light_top(v, upper, lighter(upper, 30))


def drop_shoe():
    """A blue sneaker: white sole and toe cap, stripe, laces, heel tab."""
    v = Vox(DU)
    _sneaker(v, BLU, BLU_D, WHT, WHT)
    return v


def drop_stick():
    """Tung Tung Tung Sahur's wooden bat: knob, thin handle, thick barrel, grain."""
    v = Vox(DU)
    v.box(-1, 0, -9, 1, 2, -8, BRN_D)                         # knob
    v.box(-1, 0, -8, 1, 2, -2, BRN)                           # handle
    v.box(-2, 0, -2, 2, 3, 9, BRN)                            # barrel
    v.box(-2, -1, 1, 2, 4, 9, BRN)
    light_top(v, BRN, BRN_L)
    for z in (0, 3, 6):
        v.box(-1, 4, z, 1, 4 + 1, z + 2, BRN_D)               # grain
    v.box(-2, -1, 9, 2, 4, 10, BRN_L)                         # cut end
    return v


def drop_milk():
    """A milk carton: gable top with a spout, blue label with a white drop."""
    v = Vox(DU)
    v.box(-4, 0, -4, 5, 11, 5, WHT)
    for i in range(4):                                        # gable roof
        v.box(-4 + i, 11 + i, -4, 5 - i, 12 + i, 5, BLU)
    v.box(0, 15, -4, 1, 16, 5, BLU_D)                         # fold
    v.box(-4, 3, -4, 5, 8, -3, BLU)                           # label
    v.box(0, 4, -5, 1, 7, -4, WHT)                            # milk drop
    v.box(-1, 4, -5, 2, 6, -4, WHT)
    return v


def drop_fruit():
    """An orange: dimpled skin, highlight, stem and a leaf."""
    v = Vox(DU)
    ell(v, 0, 6, 0, 6.5, 6.2, 6.5, ORG)
    v.box(-3, 8, -6, -1, 10, -5, ORG_L)                       # highlight
    for x, y, z in ((-3, 3, -6), (2, 5, -6), (4, 2, -5), (-1, 8, -6), (5, 7, -4), (-5, 6, -4)):
        if (x, y, z) in v.v:
            v.v[(x, y, z)] = ORG_D                            # dimples
    v.box(0, 12, 0, 1, 14, 1, BRN)                            # stem
    v.box(1, 13, -1, 4, 14, 2, GRN)                           # leaf
    v.box(2, 14, 0, 4, 15, 1, GRN_D)
    return v


def drop_coconut():
    """A coconut: hairy brown shell (two tones), three eyes, a crack of white."""
    v = Vox(DU)
    ell(v, 0, 6, 0, 6.5, 6.5, 6.5, BRN)
    for (x, y, z), c in list(v.v.items()):
        if x % 3 == 0 and (x, y, z - 1) not in v.v and z < 0:
            v.v[(x, y, z)] = BRN_D                            # fibre stripes on the front
    for x, y in ((-2, 9), (2, 9), (0, 6)):
        v.set(x, y, -7, rgb(60, 36, 20))                      # the eyes
    return v


def drop_bell():
    """A golden bell with a flared lip, top loop, clapper and a red bow."""
    v = Vox(DU, glow={GOLD_L})
    for y in range(0, 12):
        r = 6.5 if y < 2 else max(2.5, 6 - (y - 2) * 0.35)
        v.cylinder(0, 0, y, y + 1, r, GOLD)
    v.cylinder(0, 0, 0, 1, 6.5, GOLD_D)                       # lip shadow
    v.box(-1, 12, 0, 2, 15, 1, GOLD_D)                        # loop
    v.box(0, -2, 0, 1, 0, 1, GOLD_L)                          # clapper
    v.box(-3, 10, -4, 4, 12, -2, RED)                         # bow
    v.box(-1, 9, -5, 2, 13, -4, RED_D)
    return v


def drop_star():
    """A thick five-pointed star, lit facets, glowing centre."""
    v = Vox(DU, glow={GOLD_L})
    import math as _m
    pts = []
    for k in range(10):
        a = _m.pi / 2 + k * _m.pi / 5
        r = 8 if k % 2 == 0 else 3.4
        pts.append((_m.cos(a) * r, _m.sin(a) * r + 8))

    def inside(x, y):
        n, ok = len(pts), False
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                ok = not ok
            j = i
        return ok

    for x in range(-9, 10):
        for y in range(0, 17):
            if inside(x + 0.5, y + 0.5):
                v.box(x, y, -2, x + 1, y + 1, 2, GOLD)
                if x >= 0 and y >= 8:
                    v.set(x, y, -2, GOLD_D)                   # shaded facet
    v.box(-2, 6, -3, 2, 10, -2, GOLD_L)                       # glowing centre
    return v


def drop_watermelon():
    """A watermelon slice: red flesh, seeds, white band, striped green rind."""
    v = Vox(DU)
    for x in range(-8, 9):
        for y in range(0, 9):
            d = (x * x + (y + 0.5) ** 2) ** 0.5 if y >= 0 else 99
            if d <= 8.5 and y >= 0:
                c = RED if d < 6.5 else (WHT if d < 7.5 else GRN)
                if c == GRN and x % 3 == 0:
                    c = GRN_D
                v.box(x, 8 - y, -2, x + 1, 9 - y, 2, c)
    for x, y in ((-3, 6), (0, 5), (3, 6), (-1, 3), (2, 3)):
        v.set(x, y, -3, BLK)                                  # seeds
    return v


def drop_golden_shoe():
    """The golden sneaker: gold upper, bright trim, glowing."""
    v = Vox(DU, glow={GOLD_L})
    _sneaker(v, GOLD, GOLD_D, GOLD_L, GOLD_L)
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
    "Planter": planter,
    "TungHost": tung_host,
    "TungHostArm": tung_host_arm,
    "KoiStatue": koi_statue,
    "BambooShoot": bamboo_shoot,
    "HotTub": hot_tub,
    **FLOWERS,
    **KOIS,
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
