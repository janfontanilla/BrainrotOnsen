"""Generates the seamless map textures in assets/textures/ (toy-brick / studded
look matching the Capybara Onsen screenshots in reference/).

    python tools/make_textures.py

Outputs 256x256 PNGs that tile without seams. They must be uploaded to Roblox
(Creator Dashboard > Assets > Images, or Studio's Asset Manager > Bulk Import);
the resulting asset IDs go into src/shared/Config/Textures.luau. See
assets/textures/README.md.
"""

import os
import random
from PIL import Image, ImageDraw

SIZE = 256
CELL = 64  # one "stud" cell; a tile is 4 x 4 cells
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")


def shade(color, amount):
    return tuple(max(0, min(255, c + amount)) for c in color)


def studded(base, seam, top, light, dark, name):
    """Square cells separated by seams, each with a raised rounded stud."""
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    for cy in range(0, SIZE, CELL):
        for cx in range(0, SIZE, CELL):
            d.rectangle([cx, cy, cx + CELL - 1, cy + CELL - 1], outline=seam, width=2)
            x0, y0, x1, y1 = cx + 13, cy + 13, cx + CELL - 14, cy + CELL - 14
            # shadow (bottom right), stud body, highlight (top left)
            d.rounded_rectangle([x0 + 3, y0 + 3, x1 + 3, y1 + 3], radius=8, fill=dark)
            d.rounded_rectangle([x0, y0, x1, y1], radius=8, fill=top)
            d.rounded_rectangle([x0 + 2, y0 + 2, x1 - 6, y1 - 6], radius=6, fill=light)
            d.rounded_rectangle([x0 + 4, y0 + 4, x1 - 4, y1 - 4], radius=6, fill=top)
    img.save(os.path.join(OUT, name))


def water(name):
    base = (72, 192, 234)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    for cy in range(0, SIZE, CELL):
        for cx in range(0, SIZE, CELL):
            d.rectangle([cx, cy, cx + CELL - 1, cy + CELL - 1], outline=(58, 176, 220), width=2)
            d.rounded_rectangle([cx + 16, cy + 16, cx + CELL - 17, cy + CELL - 17], radius=6, fill=(98, 210, 246))
            d.rounded_rectangle([cx + 18, cy + 18, cx + CELL - 22, cy + CELL - 22], radius=5, fill=(120, 224, 252))
    # A few pale ripple strokes, wrapped so the tile stays seamless.
    rng = random.Random(7)
    for _ in range(9):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        length = rng.randrange(22, 44)
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                d.line([x + ox, y + oy, x + ox + length, y + oy - 5], fill=(190, 240, 255), width=3)
    img.save(os.path.join(OUT, name))


def stone(name):
    base, mortar = (150, 152, 162), (98, 100, 112)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    rng = random.Random(3)
    brick_w, brick_h = 128, 64
    for row in range(SIZE // brick_h):
        offset = (brick_w // 2) if row % 2 else 0
        for col in range(-1, SIZE // brick_w + 1):
            x0 = col * brick_w + offset
            y0 = row * brick_h
            tone = rng.randrange(-9, 10)
            for ox in (0, SIZE):
                d.rectangle([x0 + ox, y0, x0 + ox + brick_w - 1, y0 + brick_h - 1], fill=shade(base, tone))
                d.line([x0 + ox + 2, y0 + 2, x0 + ox + brick_w - 4, y0 + 2], fill=shade(base, tone + 22), width=3)
                d.rectangle([x0 + ox, y0, x0 + ox + brick_w - 1, y0 + brick_h - 1], outline=mortar, width=3)
                # one stud per brick
                cx, cy = x0 + ox + brick_w // 2, y0 + brick_h // 2
                d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=shade(base, tone - 22))
                d.ellipse([cx - 13, cy - 15, cx + 11, cy + 9], fill=shade(base, tone + 16))
    img.save(os.path.join(OUT, name))


def pegboard(name):
    base = (194, 146, 92)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    for x in range(0, SIZE, CELL):
        d.line([x, 0, x, SIZE], fill=(158, 112, 64), width=3)
    for y in range(16, SIZE, 32):
        for x in range(16, SIZE, 32):
            d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(132, 92, 52))
            d.arc([x - 6, y - 6, x + 6, y + 6], 20, 160, fill=(216, 172, 120), width=2)
    img.save(os.path.join(OUT, name))


def cliff(name):
    base = (120, 134, 150)
    img = Image.new("RGB", (SIZE, SIZE), base)
    d = ImageDraw.Draw(img)
    rng = random.Random(11)
    for _ in range(46):
        w, h = rng.choice([32, 48, 64, 96]), rng.choice([24, 32, 48])
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        tone = rng.randrange(-16, 17)
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                d.rectangle([x + ox, y + oy, x + ox + w, y + oy + h], fill=shade(base, tone), outline=shade(base, -26), width=2)
                d.line([x + ox + 2, y + oy + 2, x + ox + w - 2, y + oy + 2], fill=shade(base, tone + 20), width=2)
    img.save(os.path.join(OUT, name))


def arrow(name):
    """A green chevron pointing along the tile's -Y (up) with a soft outline, RGBA."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(28, 150), (128, 60), (228, 150), (228, 200), (128, 110), (28, 200)]
    d.polygon(pts, fill=(255, 255, 255, 235), outline=(60, 170, 60, 255))
    d.line(pts + [pts[0]], fill=(70, 180, 70, 255), width=8, joint="curve")
    img.save(os.path.join(OUT, name))


def main():
    os.makedirs(OUT, exist_ok=True)
    studded((100, 192, 66), (84, 168, 54), (112, 204, 78), (146, 226, 108), (72, 150, 48), "grass.png")
    water("water.png")
    stone("stone.png")
    pegboard("pegboard.png")
    cliff("cliff.png")
    arrow("arrow.png")
    print("Wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
