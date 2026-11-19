"""fontzoom.py FIRST LAST [out.png] - big labelled sheet of a glyph range (hex)."""
import os
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROM = open(os.path.join(HERE, '..', 'rom', 'mz700fon.int'), 'rb').read()
a, b = int(sys.argv[1], 16), int(sys.argv[2], 16)
out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, '..', 'build', 'fontzoom.png')
S = 5
CW = 8 * S + 4
n = b - a + 1
cols = 16
rows = (n + cols - 1) // cols
im = Image.new('RGB', (cols * CW, rows * (CW + 12)), (50, 50, 50))
d = ImageDraw.Draw(im)
for i in range(n):
    g = a + i
    x0, y0 = (i % cols) * CW, (i // cols) * (CW + 12)
    d.text((x0 + 2, y0), '%03X' % g, fill=(255, 255, 0))
    for y in range(8):
        bits = ROM[g * 8 + y]
        for x in range(8):
            c = (255, 255, 255) if (bits >> x) & 1 else (0, 0, 110)
            d.rectangle([x0 + x * S, y0 + 12 + y * S, x0 + x * S + S - 1, y0 + 12 + y * S + S - 1], fill=c)
im.save(out)
