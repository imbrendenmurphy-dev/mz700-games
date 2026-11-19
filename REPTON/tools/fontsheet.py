"""fontsheet.py - render both CG-ROM banks as a labelled sheet (build/font_bankN.png)."""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mzfont  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 4
for bank in (0, 1):
    im = Image.new('RGB', (40 + 16 * 12 * S, 20 + 16 * 12 * S), (40, 40, 40))
    d = ImageDraw.Draw(im)
    for i in range(16):
        d.text((40 + i * 12 * S + 10, 4), '%X' % i, fill=(255, 255, 0))
        d.text((8, 20 + i * 12 * S + 14), '%X0' % i, fill=(255, 255, 0))
    for g in range(256):
        bits = mzfont.glyph_bits(g + 256 * bank)
        ox = 40 + (g % 16) * 12 * S
        oy = 20 + (g // 16) * 12 * S
        for y in range(8):
            for x in range(8):
                c = (255, 255, 255) if bits[y][x] else (0, 0, 90)
                d.rectangle([ox + x * S, oy + y * S, ox + x * S + S - 1, oy + y * S + S - 1], fill=c)
    im.save(os.path.join(ROOT, 'build', 'font_bank%d.png' % bank))
