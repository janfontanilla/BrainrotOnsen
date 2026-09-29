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
    for y in range(2, 11, 3):
        v.box(-1, y, -1, 0, y + 1, 0, TRUNK_D)
    for i in range(4):  # right branch
        v.box(1 + i, 9 + i, -1, 2 + i, 10 + i, 1, TRUNK)
        v.box(1 + i, 8 + i, -1, 2 + i, 9 + i, 0, TRUNK_D)
    for i in range(3):  # left branch
        v.box(-2 - i, 10 + i, -1, -1 - i, 11 + i, 1, TRUNK)
    for i in range(3):  # back branch
        v.box(-1, 9 + i, -2 - i, 1, 10 + i, -1 - i, TRUNK)

    def clump(cx, cy, cz, w, h, colour):
        """A rounded block of blossom with lighter top, nubs and a few hanging petals."""
        x0, z0 = cx - w // 2, cz - w // 2
        v.box(x0 + 1, cy, z0, x0 + w - 1, cy + h, z0 + w, colour)
        v.box(x0, cy, z0 + 1, x0 + w, cy + h, z0 + w - 1, colour)
        v.box(x0 + 1, cy + h, z0 + 1, x0 + w - 1, cy + h + 1, z0 + w - 1, lighter(colour, 16))
        for _ in range(3):  # nubs
            nx = rng.randint(x0 + 1, x0 + w - 3)
            nz = rng.randint(z0 + 1, z0 + w - 3)
            v.box(nx, cy + h + 1, nz, nx + 2, cy + h + 2, nz + 2, lighter(colour, 22))
        for _ in range(3):  # hanging blossoms
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
LAMP_GLOW, LAMP_FRAME = rgb(255, 224, 150), rgb(96, 68, 44)


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
        v.set(x, h // 3, z, BAMBOO_D)
        v.set(x, 2 * h // 3, z, BAMBOO_D)
        v.set(x, h - 2, z, BAMBOO_L)
        # leaf tuft
        v.box(x - 1, h - 1, z, x + 2, h, z + 1, LEAF)
        v.box(x, h - 1, z - 1, x + 1, h, z + 2, LEAF)
    return v


PROPS = {
    "CherryTree": cherry_tree,
    "StoneLantern": stone_lantern,
    "Torii": torii,
    "Bamboo": bamboo,
}


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
