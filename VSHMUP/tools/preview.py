"""preview.py - render every picture in art.py to build/art.png"""
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art
HERE = os.path.dirname(os.path.abspath(__file__))
rom = open(os.path.join(HERE, '..', 'rom', 'mz700fon.int'), 'rb').read()
PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255), (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
S = 3


def draw(im, ox, oy, cells):
    px = im.load()
    for dx, dy, ch, at in cells:
        g = ch | ((at & 0x80) << 1)
        fg, bg = PAL[(at >> 4) & 7], PAL[at & 7]
        for y in range(8):
            b = rom[g * 8 + y]
            for x in range(8):
                c = fg if (b >> x) & 1 else bg
                for sy in range(S):
                    for sx in range(S):
                        px[ox + (dx * 8 + x) * S + sx, oy + (dy * 8 + y) * S + sy] = c


items = [('PLAYER', art.PLAYER), ('OPTION', art.OPTION)] + list(art.SPRITES.items()) + \
    list(art.BOSSES.items()) + list(art.PIECES.items())
W = 1500
im = Image.new('RGB', (W, 1100), (30, 30, 30))
d = ImageDraw.Draw(im)
x = y = 10
rowh = 0
for name, rows in items:
    cells, w, h = art.parse(rows)
    pw, ph = w * 8 * S, h * 8 * S
    if x + max(pw, 60) > W:
        x = 10
        y += rowh + 20
        rowh = 0
    d.rectangle([x - 1, y - 1, x + pw, y + ph], fill=(0, 0, 0))
    draw(im, x, y, cells)
    d.text((x, y + ph + 2), name, fill=(255, 255, 0))
    x += max(pw, 60) + 16
    rowh = max(rowh, ph + 12)
im = im.crop((0, 0, W, y + rowh + 20))
im.save(os.path.join(HERE, '..', 'build', 'art.png'))
