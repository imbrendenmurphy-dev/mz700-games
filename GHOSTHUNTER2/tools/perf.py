"""perf.py - late frames during the demo, with and without the VRAM wait model.

    py tools/perf.py [none|all|display] [fields]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

mode = sys.argv[1] if len(sys.argv) > 1 else 'none'
fields = int(sys.argv[2]) if len(sys.argv) > 2 else 1000
g = Game(None if mode == 'none' else mode)
while not (g.rb('demo') and g.rb('pvisible')):
    g.run(10)
d0 = g.rb('drops')
w0 = g.m.waits
f0 = g.rw('framecount')
g.run(fields)
n = (g.rw('framecount') - f0) & 0xFFFF
print('%s: %d game frames in %d fields, %d late, %.1f%% CPU in VRAM waits' % (
    mode, n, fields, (g.rb('drops') - d0) & 0xFF, 100.0 * (g.m.waits - w0) / (fields * 70886)))
