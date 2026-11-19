"""fontsheet.py - draw both 256-glyph sets of the CG-ROM as a labelled sheet.

    py tools/fontsheet.py            -> build/fontsheet.png
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROM = open(os.path.join(HERE, '..', 'rom', 'mz700fon.int'), 'rb').read()
S = 3
CW = 8 * S + 6
im = Image.new('RGB', (34 * CW, 2 * 17 * CW + 20), (60, 60, 60))
d = ImageDraw.Draw(im)
for bank in range(2):
    oy = bank * (17 * CW + 20)
    for i in range(16):
        d.text((CW * (i + 1) + 6, oy), '%X' % i, fill=(255, 255, 0))
        d.text((2, oy + CW * (i + 1) + 6), '%X' % i, fill=(255, 255, 0))
    for g in range(256):
        r, c = g >> 4, g & 15
        x0, y0 = CW * (c + 1), oy + CW * (r + 1)
        for y in range(8):
            b = ROM[(bank * 256 + g) * 8 + y]
            for x in range(8):
                col = (255, 255, 255) if (b >> x) & 1 else (0, 0, 90)
                d.rectangle([x0 + x * S, y0 + y * S, x0 + x * S + S - 1, y0 + y * S + S - 1], fill=col)
os.makedirs(os.path.join(HERE, '..', 'build'), exist_ok=True)
im.save(os.path.join(HERE, '..', 'build', 'fontsheet.png'))
