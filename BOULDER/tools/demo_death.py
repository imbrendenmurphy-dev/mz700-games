"""demo_death.py - run attract mode and dump the cave around the player for
the last few ticks before each demo death."""
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402
from dbg import CH  # noqa: E402

fields = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
g = Game()
hist = deque(maxlen=8)
was_dead = 0
for f in range(fields):
    g.run(1)
    if not g.rb('demo'):
        continue
    if f % 2 == 0:
        pa = g.rw('pl_addr') - S['CAVE']
        px, py = pa % 40, pa // 40
        cave = g.cave()
        rows = []
        for y in range(max(0, py - 4), min(22, py + 4)):
            rows.append(''.join(CH[cave[y][x]] for x in range(max(0, px - 7), min(40, px + 8))))
        hist.append((f, px, py, g.rb('ai_keys'), rows))
    d = g.rb('pl_dead')
    if d and not was_dead:
        print('=== death at field', f, 'cave', g.rb('cave_no'))
        for fr, px, py, k, rows in hist:
            print('field', fr, 'player', px, py, 'keys', k)
            print('\n'.join('   ' + r for r in rows))
    was_dead = d
