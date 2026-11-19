"""perf.py - frame-rate check under the VRAM wait model.

    py tools/perf.py [level] [fields] [--novram]

Starts a game at the given level (default 0) with the demo pilot driving,
and counts dropped frames (frames whose work did not finish inside one
50 Hz field) using the conservative VRAM wait model: every VRAM access is
held until the 63-T window of a scan line.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith('--')]
level = int(args[0]) if args else 0
fields = int(args[1]) if len(args) > 1 else 1500
g = Game(vram='--novram' not in sys.argv)
g.run(40)
g.wb('start_level', level)
g.wb('demo', 1)                     # pilot drives; hearts are not lost
# start the game from the attract loop: poke the title to exit
g.run(5, ['space'])
g.run(30)
g.wb('demo', 1)
d0 = g.rb('drops')
f0 = g.rb('fieldcnt')
rooms = set()
for i in range(fields):
    g.run(1)
    rooms.add(g.rb('room'))
    if i % 300 == 299:
        print('field %d room %d drops %d' % (i + 1, g.rb('room'), g.rb('drops') - d0))
print('rooms visited', sorted(rooms), 'dropped frames', g.rb('drops') - d0, 'of', fields,
      'VRAM wait T total', g.m.waits)
