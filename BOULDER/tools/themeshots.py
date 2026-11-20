"""themeshots.py - one in-game screenshot per wing from the Z80 build
(build/shots/wing_N.png) plus a strip of all five (build/wings.png)."""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crosscheck import Pair  # noqa: E402
from run import ROOT  # noqa: E402

CAVES = [int(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else [1, 6, 9, 13, 17]
ims = []
for n, i in enumerate(CAVES):
    p = Pair(i)
    for _ in range(12):
        p.tick(0)
    p.z.wb('turbo', 0)
    p.z.run(4)
    ims.append(Image.open(p.z.shot('wing_%d' % n)))
w, h = ims[0].size
strip = Image.new('RGB', (w, h * len(ims)))
for n, im in enumerate(ims):
    strip.paste(im, (0, n * h))
strip.save(os.path.join(ROOT, 'build', 'wings.png'))
print('build/wings.png')
