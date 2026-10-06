"""Generates the seamless map textures in assets/textures/ (toy-brick / studded
look matching the Capybara Onsen screenshots in reference/).

    python tools/make_textures.py

Outputs 256x256 PNGs that tile without seams. They must be uploaded to Roblox
(Creator Dashboard > Assets > Images, or Studio's Asset Manager > Bulk Import);
the resulting asset IDs go into src/shared/Config/Textures.luau. See
assets/textures/README.md.
"""

import math
import os
import random
from PIL import Image, ImageDraw

SIZE = 256
CELL = 64  # one "stud" cell; a tile is 4 x 4 cells
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")


def shade(color, amount):
    return tuple(max(0, min(255, c + amount)) for c in color)


def bevel(d, box, face, light, dark, width=4, sunken=False):
    """One tile element in the shared toy-brick style: a flat face with a light edge on
    the top/left and a dark edge on the bottom/right (swapped when sunken)."""
    x0, y0, x1, y1 = box
    hi, lo = (dark, light) if sunken else (light, dark)
    d.rectangle(box, fill=face)
    d.rectangle([x0, y0, x1, y0 + width - 1], fill=hi)
    d.rectangle([x0, y0, x0 + width - 1, y1], fill=hi)
    d.rectangle([x0, y1 - width + 1, x1, y1], fill=lo)
    d.rectangle([x1 - width + 1, y0, x1, y1], fill=lo)


# Every tile below uses the same grid (64 px = 2 studs at 8 studs per tile), the same
# bevel and the same inset-square motif, so the surfaces read as one set of bricks
# that only differ in colour (like Capybara Onsen), not a mix of unrelated patterns.


def grass(name):
    # Calm lime with small, low-contrast studs (2026-10-06: was neon green with big,
    # high-contrast squares, the loudest surface on screen; see docs/visual-overhaul.md).
    base = (126, 196, 74)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    for cy in range(0, SIZE, CELL):
        for cx in range(0, SIZE, CELL):
            bevel(d, [cx + 16, cy + 16, cx + CELL - 17, cy + CELL - 17], (134, 204, 82), (152, 216, 98), (112, 180, 64), width=3)
    img.save(os.path.join(OUT, name))


def stone(name):
    # Light neutral grey blocks, soft edges, a small inset stud (2026-10-06: was dark
    # blue-slate bricks with a big inset square; Capybara Onsen's stone is light grey).
    base, mortar = (190, 190, 194), (160, 160, 166)
    img = Image.new("RGB", (SIZE, SIZE), mortar)
    d = ImageDraw.Draw(img)
    brick_w, brick_h = 128, 64
    for row in range(SIZE // brick_h):
        offset = (brick_w // 2) if row % 2 else 0
        for col in range(-1, SIZE // brick_w + 1):
            x0 = col * brick_w + offset
            y0 = row * brick_h
            for ox in (0, SIZE, -SIZE):
                bx = x0 + ox
                bevel(d, [bx + 2, y0 + 2, bx + brick_w - 3, y0 + brick_h - 3], base, (206, 206, 210), (168, 168, 174), width=3)
                for sx in (bx + brick_w // 4, bx + 3 * brick_w // 4):
                    bevel(d, [sx - 10, y0 + 22, sx + 9, y0 + brick_h - 23], (198, 198, 202), (212, 212, 216), (174, 174, 180), width=3)
    img.save(os.path.join(OUT, name))


def water(name):
    base = (84, 206, 240)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    for cy in range(0, SIZE, CELL):
        for cx in range(0, SIZE, CELL):
            bevel(d, [cx + 10, cy + 10, cx + CELL - 11, cy + CELL - 11], (92, 212, 244), (112, 222, 250), (78, 196, 232), width=3)
    # White stream streaks along +U (the flow direction), wavy, wrapped to stay seamless.
    rng = random.Random(7)
    for _ in range(12):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        length = rng.randrange(40, 90)
        phase = rng.random() * 6.28
        pts = [(x + i, y + 3 * math.sin(phase + i / 9)) for i in range(0, length, 3)]
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                d.line([(px + ox, py + oy) for px, py in pts], fill=(214, 248, 255), width=3)
    img.save(os.path.join(OUT, name))


def pegboard(name):
    base = (198, 152, 98)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    for x in range(0, SIZE, 128):  # board seams
        bevel(d, [x, 0, x + 127, SIZE - 1], base, (220, 176, 122), (160, 116, 68), width=3)
    for cy in range(0, SIZE, CELL):
        for cx in range(0, SIZE, CELL):
            bevel(d, [cx + 22, cy + 22, cx + CELL - 23, cy + CELL - 23], (120, 82, 48), (170, 126, 78), (96, 64, 36), sunken=True)
    img.save(os.path.join(OUT, name))


def cliff(name):
    """At 16 studs per tile: 32 px cells are 2 studs, matching the other tiles."""
    # Neutral, slightly warm grey (2026-10-06: was green-grey; tinted by the parts it
    # read blue-green next to the new light stone).
    base = (196, 194, 188)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    for cy in range(0, SIZE, 32):
        for cx in range(0, SIZE, 32):
            bevel(d, [cx + 1, cy + 1, cx + 30, cy + 30], base, (210, 208, 202), (176, 174, 168), width=2)
            bevel(d, [cx + 12, cy + 12, cx + 19, cy + 19], (190, 188, 182), (206, 204, 198), (172, 170, 164), width=2, sunken=True)
    img.save(os.path.join(OUT, name))


def arrow(name):
    """A green chevron pointing along the tile's -Y (up) with a soft outline, RGBA."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(28, 150), (128, 60), (228, 150), (228, 200), (128, 110), (28, 200)]
    d.polygon(pts, fill=(255, 255, 255, 235), outline=(60, 170, 60, 255))
    d.line(pts + [pts[0]], fill=(70, 180, 70, 255), width=8, joint="curve")
    img.save(os.path.join(OUT, name))


def planks(name):
    """Wooden boards two studs wide along U, staggered joints, one sunken inset each."""
    base = (178, 118, 64)
    img = Image.new("RGB", (SIZE, SIZE), (132, 84, 44))
    d = ImageDraw.Draw(img)
    for row in range(SIZE // CELL):
        y0 = row * CELL
        offset = 64 if row % 2 else 0
        for col in range(-1, 3):
            x0 = col * 128 + offset
            for ox in (0, SIZE, -SIZE):
                bx = x0 + ox
                bevel(d, [bx + 2, y0 + 2, bx + 125, y0 + CELL - 3], base, (206, 148, 92), (140, 90, 48))
                bevel(d, [bx + 44, y0 + 20, bx + 83, y0 + CELL - 21], (166, 108, 58), (200, 142, 88), (132, 84, 44), sunken=True)
    img.save(os.path.join(OUT, name))


def onsen_symbol(name):
    """The hot-spring mark (a bowl with three wavy steam lines), white on transparent, RGBA."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)
    d.arc([36, 120, 220, 236], 0, 180, fill=white, width=16)
    d.arc([36, 150, 220, 206], 180, 360, fill=white, width=12)
    for x in (88, 128, 168):
        pts = []
        for i in range(0, 41):
            t = i / 40
            pts.append((x + 12 * math.sin(t * 6.283), 150 - t * 120))
        d.line(pts, fill=white, width=14, joint="curve")
    img.save(os.path.join(OUT, name))


def ui_studs(name):
    """HUD button overlay (Capybara Onsen's studded buttons): one translucent beveled
    stud per 64 px tile, white highlight and black shadow on transparent. Tiled over
    a button's colour."""
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = 14, 14, 49, 49
    d.rectangle([x0 + 3, y0 + 3, x1 + 3, y1 + 3], fill=(0, 0, 0, 55))      # shadow
    d.rectangle([x0, y0, x1, y1], fill=(255, 255, 255, 40))                 # face
    d.rectangle([x0, y0, x1, y0 + 3], fill=(255, 255, 255, 110))            # top light
    d.rectangle([x0, y0, x0 + 3, y1], fill=(255, 255, 255, 90))
    img.save(os.path.join(OUT, name))


def aura_icon(name):
    """The Aura currency icon: a faceted purple gem with a dark outline, 128 px RGBA."""
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline = [(64, 6), (118, 50), (64, 122), (10, 50)]
    d.polygon(outline, fill=(58, 20, 90, 255))
    inner = [(64, 16), (106, 50), (64, 110), (22, 50)]
    d.polygon(inner, fill=(176, 96, 246, 255))
    d.polygon([(64, 16), (106, 50), (64, 50)], fill=(214, 160, 255, 255))
    d.polygon([(64, 16), (22, 50), (64, 50)], fill=(236, 200, 255, 255))
    d.polygon([(22, 50), (64, 50), (64, 110)], fill=(150, 70, 220, 255))
    d.line([(38, 38), (52, 26)], fill=(255, 255, 255, 230), width=6)
    img.save(os.path.join(OUT, name))


def main():
    os.makedirs(OUT, exist_ok=True)
    grass("grass.png")
    water("water.png")
    stone("stone.png")
    pegboard("pegboard.png")
    cliff("cliff.png")
    arrow("arrow.png")
    planks("planks.png")
    onsen_symbol("onsen.png")
    ui_studs("ui_studs.png")
    aura_icon("aura_icon.png")
    print("Wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
