"""proto_sprite.py - try the glyph matcher on a mascot design (preview only)."""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glyphmatch as gm  # noqa: E402

PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
       (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]

KIKO = [
    "........................",
    "..............GGGGG.....",
    "............GGGGGGGGG...",
    "...........GGWWWWGGGGG..",
    "...........GWWWWWWGGGGG.",
    "...........GWWGGWWGGGGGG",
    "....GGGG...GWWGGWWGGGGGG",
    "...GG..GG..GGWWWWGGGGGW.",
    "..GG.GG.GGGGGGWWGGGWWW..",
    "..GG.GGG.GGGGGGGGGGGG...",
    "..GG..GGGGGGGGGGGGGGG...",
    "...GG...GGGWWWWWWGGG....",
    "....GGGGGGGGGGGGGGG.....",
    ".........GG....GG.......",
    "........GG....GG........",
    ".......GGGG..GGGG.......",
]


def render(cells, sky, scale=4):
    h, w = len(cells), len(cells[0])
    im = Image.new('RGB', (w * 8, h * 8), PAL[sky])
    px = im.load()
    for cy, row in enumerate(cells):
        for cx, (g, fg, bg) in enumerate(row):
            b = sky if bg == gm.T else bg
            for y in range(8):
                bits = gm.ROM[g * 8 + y]
                for x in range(8):
                    px[cx * 8 + x, cy * 8 + y] = PAL[fg] if (bits >> x) & 1 else PAL[b]
    return im.resize((w * 8 * scale, h * 8 * scale), Image.NEAREST)


def render_src(img, sky, scale=4):
    h, w = len(img), len(img[0])
    im = Image.new('RGB', (32, 24), PAL[sky])
    for y in range(h):
        for x in range(w):
            if img[y][x] != gm.T:
                im.putpixel((x, y), PAL[img[y][x]])
    return im.resize((32 * scale, 24 * scale), Image.NEAREST)


if __name__ == '__main__':
    body = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    sky = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    img = gm.parse_art(KIKO, {'.': gm.T, 'G': body, 'W': 7})
    tiles = [render_src(img, sky)]
    for dy in (0, 4):
        for dx in (0, 2, 4, 6):
            cells = gm.convert(img, dx, dy, 4, 3)
            print(dx, dy, [['%03X' % c[0] for c in r] for r in cells])
            tiles.append(render(cells, sky))
    W = sum(t.width for t in tiles) + 8 * len(tiles)
    out = Image.new('RGB', (W, tiles[0].height), (40, 40, 40))
    x = 0
    for t in tiles:
        out.paste(t, (x, 0))
        x += t.width + 8
    out.save(os.path.join(os.path.dirname(__file__), '..', 'build', 'proto_sprite.png'))
