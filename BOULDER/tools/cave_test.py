"""cave_test.py - let the demo pilot play caves and report how it went.

    py tools/cave_test.py LETTERS [tries]

For each cave: start a game there, hand the controls to the pilot (with
no demo time limit) and play one life.  Reports diamonds, exit, outcome.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from collections import deque  # noqa: E402
from run import Game, S  # noqa: E402
from dbg import CH  # noqa: E402
import caves  # noqa: E402

NEED = {c.letter: c.need for c in caves.caves()}


def play(letter, seed):
    g = Game()
    g.run(30)
    g.wb('start_cave', ord(letter) - 65)
    g.m.mem[0x10000 - 1] = 0
    g.wb('seed', seed)
    g.run(10, ['space'])
    while g.rb('inbox_time') != 16:          # wait for cave_load in cave_play
        g.run(5)
    while g.rb('fieldcnt') == 0:
        g.run(1)
    g.run(40)
    g.wb('demo', 1)
    best = 0
    hist = deque(maxlen=6)
    for f in range(12000):
        g.run(1)
        g.wb('demo_ticks', 0)
        g.wb('demo_ticks', 0, 1)
        best = max(best, g.rb('got'))
        if os.environ.get('SHOTS') and f % int(os.environ['SHOTS']) == 0:
            g.shot('ct_%s_%05d' % (letter, f))
        if g.rb('pl_exit'):
            return 'CLEARED', best, g.rb('ctime')
        if os.environ.get('DEATHS') and f % 2 == 0:
            pa = g.rw('pl_addr') - S['CAVE']
            px, py = pa % 40, pa // 40
            cv = g.cave()
            rows = [''.join(CH[cv[y][x]] for x in range(max(0, px - 7), min(40, px + 8)))
                    for y in range(max(0, py - 3), min(22, py + 4))]
            hist.append((f, px, py, g.rb('ai_keys'), rows))
        if g.rb('pl_dead'):
            for fr, px, py, k, rows in hist:
                print('field', fr, 'player', px, py, 'keys', k)
                print('\n'.join('   ' + r for r in rows))
            return 'died', best, g.rb('ctime')
        if g.rb('timeout'):
            return 'timeout', best, 0
    return 'stuck', best, g.rb('ctime')


if __name__ == '__main__':
    tries = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    for L in sys.argv[1]:
        for t in range(tries):
            res, got, left = play(L, 0x1234 + 977 * t)
            print('cave %s try %d: %-8s %2d/%2d diamonds, %3d s left' % (L, t + 1, res, got, NEED[L], left),
                  flush=True)
