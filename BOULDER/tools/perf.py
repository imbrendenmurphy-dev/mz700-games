"""perf.py - game speed in a cave, with the VRAM wait model.

    py tools/perf.py [cave letter] [fields] [none|all|display]

Starts a game in the cave, walks the player right (so the window scrolls)
and counts physics ticks against the target rate.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

letter = sys.argv[1] if len(sys.argv) > 1 else 'C'
fields = int(sys.argv[2]) if len(sys.argv) > 2 else 500
mode = sys.argv[3] if len(sys.argv) > 3 else 'all'
g = Game(None if mode == 'none' else mode)
g.run(30)
g.wb('start_cave', ord(letter) - 65)
g.run(10, ['space'])
while not (g.rb('inbox_time') == 0 and g.rb('pl_dead') == 0 and g.rb('cave_no') == ord(letter) - 65):
    g.run(10)
t0 = g.rw('ticks')
w0 = g.m.waits
vx0 = g.rb('view_x')
for _ in range(fields // 25):
    g.run(25, ['right'])
n = (g.rw('ticks') - t0) & 0xFFFF
speed = g.rb('speed')
print('cave %s %s: %d ticks in %d fields = %.2f ticks/s (target %.2f), %.1f%% CPU in VRAM waits, view x %d -> %d' % (
    letter, mode, n, fields, n * 50 / fields, 50 / speed,
    100.0 * (g.m.waits - w0) / (fields * 70886), vx0, g.rb('view_x')))
