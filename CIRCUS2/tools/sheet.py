"""sheet.py ids... - tile build/shots/run_NNNN.png into build/shots/sheet.png (2 per row, half size)"""
import os
import sys
from PIL import Image
d = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'build', 'shots')
ids = [int(x) for x in sys.argv[1:]]
prefix = 'run_'
ims = [Image.open(os.path.join(d, '%s%04d.png' % (prefix, i))).resize((320, 200)) for i in ids]
rows = (len(ims) + 1) // 2
out = Image.new('RGB', (640, 200 * rows))
for k, im in enumerate(ims):
    out.paste(im, ((k % 2) * 320, (k // 2) * 200))
out.save(os.path.join(d, 'sheet.png'))
