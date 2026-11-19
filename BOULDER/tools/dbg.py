"""dbg.py - start a game, hold keys, and dump the cave as letters each N fields.

    py tools/dbg.py FIELDS EVERY [--keys "field:key,..."]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, parse_keys  # noqa: E402

CH = ' .#M%Xx@oDd>>>>BBBBaP=I1234567?'


def dump(g):
    cave = g.cave()
    for y, row in enumerate(cave):
        print('%2d %s' % (y, ''.join(CH[v] if v < len(CH) else '?' for v in row)))


if __name__ == '__main__':
    fields = int(sys.argv[1])
    every = int(sys.argv[2])
    keys = parse_keys(sys.argv[sys.argv.index('--keys') + 1]) if '--keys' in sys.argv else []
    g = Game()
    held = []
    for f in range(fields):
        for kf, k in keys:
            if kf == f:
                held = k
        g.run(1, held)
        if f % every == every - 1:
            print('field', f, 'pl_addr %04X' % g.rw('pl_addr'), 'got', g.rb('got'), 'dead', g.rb('pl_dead'),
                  'inbox', g.rb('inbox_time'), 'tick_keys', g.rb('tick_keys'))
            dump(g)
