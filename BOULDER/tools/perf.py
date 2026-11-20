"""perf.py - game speed in the demo, with and without the VRAM wait model.

    py tools/perf.py [none|all|display] [fields]

Starts the demo directly (cave B), then counts physics ticks and late frames.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

mode = sys.argv[1] if len(sys.argv) > 1 else 'none'
fields = int(sys.argv[2]) if len(sys.argv) > 2 else 1000
g = Game(None if mode == 'none' else mode)
# skip the attract pages: run until the demo cave is playing
while not (g.rb('demo') and g.rb('inbox_time') == 0):
    g.run(10)
t0 = g.rw('demo_ticks')
d0 = g.rb('drops')
w0 = g.m.waits
g.run(fields)
n = g.rw('demo_ticks') - t0
speed = g.rb('speed')
print('%s: %d ticks in %d fields = %.2f ticks/s (target %.2f), %d late frames, %.1f%% CPU in VRAM waits' % (
    mode, n, fields, n * 50 / fields, 50 / speed, (g.rb('drops') - d0) & 0xFF,
    100.0 * (g.m.waits - w0) / (fields * 70886)))
