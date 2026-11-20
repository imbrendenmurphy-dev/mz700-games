"""verify.py - play every recorded solution on the Z80 build in the simulator.

    py tools/verify.py [letters]

For each cave: start a game there in turbo mode and feed the solution one
tick at a time at tick_hook, with the Python model running alongside and
the whole cave compared after every tick.  Passes when the Z80 program
reports the player out through the exit (pl_exit) with no difference.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crosscheck import Pair  # noqa: E402
import caves as C  # noqa: E402
import solutions  # noqa: E402
import tune  # noqa: E402


def verify(index, letter):
    keys = tune.unrle(solutions.SOLUTIONS[letter]['keys'])
    p = Pair(index)
    ncaves = len(C.caves())
    for n, k in enumerate(keys):
        d = p.tick(k)
        if p.p.pl_exit:
            # the model is out; the Z80 has finished the cave and is
            # already in the next one when it next reaches tick_hook
            ok = p.z.rb('cave_no') == (index + 1) % ncaves and p.z.rb('lives') >= 3
            print('cave %s: %s after %d ticks, %d gems, score %d' % (
                letter, 'WON' if ok else 'NOT WON on the Z80', p.n, p.p.got, p.p.score))
            return ok
        if d:
            print('cave %s tick %d differs:\n  %s' % (letter, n + 1, '\n  '.join(d)))
            return False
    print('cave %s: the solution ran out without a win' % letter)
    return False


if __name__ == '__main__':
    want = sys.argv[1] if len(sys.argv) > 1 else None
    t0 = time.time()
    ok = True
    for i, c in enumerate(C.caves()):
        if want and c.letter not in want:
            continue
        ok = verify(i, c.letter) and ok
    print('%s in %.0f s' % ('all verified' if ok else 'FAILURES', time.time() - t0))
    sys.exit(0 if ok else 1)
