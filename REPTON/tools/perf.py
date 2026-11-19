"""perf.py [none|all|display] [fields] - game speed while walking about, with the VRAM wait model.

Starts a game and walks the player around the hub (scrolling the view every
step); reports ticks per second, late frames and CPU time lost to VRAM waits."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

mode = sys.argv[1] if len(sys.argv) > 1 else 'all'
fields = int(sys.argv[2]) if len(sys.argv) > 2 else 600
g = Game(None if mode == 'none' else mode)
g.run(60)
g.run(5, ['space'])
g.run(200)
t0 = g.rw('tick')
d0 = g.rb('drops')
w0 = g.m.waits
moves = ['right', 'down', 'left', 'down', 'right', 'up']
for i in range(fields // 50):
    g.run(50, [moves[i % len(moves)]])
n = (g.rw('tick') - t0) & 0xFFFF
print('%s: %d ticks in %d fields = %.2f ticks/s (target %.2f), %d late frames, %.1f%% CPU in VRAM waits' % (
    mode, n, fields, n * 50 / fields, 50 / 6, (g.rb('drops') - d0) & 0xFF,
    100.0 * (g.m.waits - w0) / (fields * 70886)))
g.shot('perf')
