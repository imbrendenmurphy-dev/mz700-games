"""scrollshot.py - walk the player through a cave on the Z80 build and
screenshot the window as it scrolls (build/scroll.png, frames side by side).

    py tools/scrollshot.py [cave letter] [key] [ticks per frame] [frames]
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crosscheck import Pair  # noqa: E402
import engine  # noqa: E402
from run import ROOT  # noqa: E402

letter = sys.argv[1] if len(sys.argv) > 1 else 'C'
key = {'L': engine.K_LEFT, 'R': engine.K_RIGHT, 'U': engine.K_UP, 'D': engine.K_DOWN}[
    sys.argv[2] if len(sys.argv) > 2 else 'R']
step = int(sys.argv[3]) if len(sys.argv) > 3 else 12
frames = int(sys.argv[4]) if len(sys.argv) > 4 else 4
p = Pair(ord(letter) - 65)
ims = []
for f in range(frames):
    for _ in range(step if f else 2):
        p.tick(key)
    p.z.wb('turbo', 0)
    p.z.run(30)                     # let the window glide
    print('frame %d: player %s view %d,%d' % (f, p.p.player_xy(), p.z.rb('view_x'), p.z.rb('view_y')))
    ims.append(Image.open(p.z.shot('scroll_%d' % f)))
    p.z.wb('turbo', 1)
    p.until_hook(400)
w, h = ims[0].size
strip = Image.new('RGB', (w * 2, h * ((len(ims) + 1) // 2)))
for n, im in enumerate(ims):
    strip.paste(im, ((n % 2) * w, (n // 2) * h))
strip.save(os.path.join(ROOT, 'build', 'scroll.png'))
print('build/scroll.png')
