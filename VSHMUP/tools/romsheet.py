# Render the European CG-ROM as a labelled sheet: bank 0 and bank 1, 16x16 each.
import os
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
rom = open(os.path.join(HERE, '..', 'rom', 'mz700fon.int'), 'rb').read()
S = 4
cell = 8 * S + 14
im = Image.new('RGB', (2 * (16 * cell + 30), 16 * cell + 30), (40, 40, 40))
d = ImageDraw.Draw(im)
for bank in range(2):
    ox = bank * (16 * cell + 30) + 24
    d.text((ox, 2), 'bank %d' % bank, fill=(255, 255, 0))
    for c in range(16):
        d.text((ox + c * cell + 10, 12), '%X' % c, fill=(200, 200, 200))
    for r in range(16):
        d.text((ox - 20, 26 + r * cell + 10), '%X_' % r, fill=(200, 200, 200))
        for c in range(16):
            g = bank * 256 + r * 16 + c
            x0 = ox + c * cell
            y0 = 26 + r * cell
            d.rectangle([x0 - 1, y0 - 1, x0 + 8 * S, y0 + 8 * S], fill=(0, 0, 90))
            for y in range(8):
                b = rom[g * 8 + y]
                for x in range(8):
                    if (b >> x) & 1:
                        d.rectangle([x0 + x * S, y0 + y * S, x0 + x * S + S - 1, y0 + y * S + S - 1], fill=(255, 255, 255))
im.save(os.path.join(HERE, '..', 'build', 'romsheet.png'))
