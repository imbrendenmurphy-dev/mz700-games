"""sheet.py - all caves on one contact sheet (build/caves_sheet.png)."""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caves  # noqa: E402
from preview import render  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cs = caves.caves()
cols = 4
tw, th = 320, 200
rows = (len(cs) + cols - 1) // cols
sheet = Image.new('RGB', (cols * (tw + 8), rows * (th + 8)), (40, 40, 40))
for i, c in enumerate(cs):
    im = render(c).resize((tw, th), Image.NEAREST)
    sheet.paste(im, ((i % cols) * (tw + 8) + 4, (i // cols) * (th + 8) + 4))
sheet.save(os.path.join(ROOT, 'build', 'caves_sheet.png'))
print('build/caves_sheet.png')
