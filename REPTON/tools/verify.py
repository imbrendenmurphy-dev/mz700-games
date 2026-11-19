"""verify.py - play the saved solution (build/solution_raw.bin) on the Z80 build.

    py tools/verify.py [--check]

Runs the game in the simulator in turbo mode, feeding one direction per
tick at tick_hook.  With --check the Python model runs alongside and the
whole world is compared after every tick (slower).  Succeeds when the game
reports the Sun Gate passed (won = 1).
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crosscheck import Pair  # noqa: E402
from run import S  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = open(os.path.join(ROOT, 'build', 'solution_raw.bin'), 'rb').read()
check = '--check' in sys.argv
p = Pair()
t0 = time.time()
g = p.g
for i, d in enumerate(log):
    if check and i < len(log) - 1:
        p.tick(d)
    else:
        g.wb('tick_dir', d)
        p.n += 1
        if i == len(log) - 1:
            break
        p.until_hook(400)
    if i % 500 == 0:
        print('tick %5d  region %d  gems left %d  (%.0fs)' % (i, g.rb('region'), g.rw('gems_left'), time.time() - t0))
# the last tick: run until the game notices the win
c = g.m.cpu
end = c.t + 400 * 70886
while c.t < end and not g.rb('won'):
    c.step()
print('ticks %d, won %d, deaths %d, gems left %d, pieces left %d, monsters left %d' % (
    len(log), g.rb('won'), g.rw('deaths'), g.rw('gems_left'), g.rb('pieces_left'), g.rb('mons_left')))
g.shot('verify_end')
sys.exit(0 if g.rb('won') else 1)
