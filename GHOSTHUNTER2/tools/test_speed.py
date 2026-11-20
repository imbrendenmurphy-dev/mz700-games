"""test_speed.py - the 1/2/3 speed setting on the title and how fast the
hero crosses the maze at each setting.

    py tools/test_speed.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

A_X, A_ACC = 0, None


def chars_per_second(g, frames=200):
    """count player steps over some frames (godmode, held left/right)"""
    steps = 0
    last = (g.m.mem[S['actors']], g.m.mem[S['actors'] + 1])
    key = 'left'
    for _ in range(frames):
        g.run(1, [key])
        pos = (g.m.mem[S['actors']], g.m.mem[S['actors'] + 1])
        if pos != last:
            steps += 1
            last = pos
        else:
            key = 'right' if key == 'left' else 'left'
    return steps * 50.0 / frames


g = Game()
g.run(30)
for k, name in (('1', 'SLOW'), ('3', 'FAST'), ('2', 'NORMAL')):
    g.run(3, [k])
    g.run(10)
    print('key', k, '-> speedsel', g.rb('speedsel'))
    g.shot('speed_title_%s' % name.lower())
    assert g.rb('speedsel') == {'1': 0, '2': 1, '3': 2}[k]

for sel in (0, 1, 2):
    g = Game()
    g.run(30)
    g.wb('speedsel', sel)
    g.run(4, ['space'])
    while g.rb('pvisible') == 0:
        g.run(5)
    g.wb('godmode', 1)
    print('speedsel %d: hero %.1f chars/s (was 12.9)' % (sel, chars_per_second(g)))
