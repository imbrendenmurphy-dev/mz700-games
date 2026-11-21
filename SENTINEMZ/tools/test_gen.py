"""test_gen.py - the Z80 island generator must match tools/model.py exactly.

    py tools/test_gen.py [islands...]
"""
import os
import sys

os.environ['ZCON'] = '0'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model as M  # noqa: E402
from run import Game, S  # noqa: E402


def check(island):
    g = Game()
    g.wb('island', island)
    t = g.call('gen_island')
    corn = S['CORN2']
    c = M.gen_corners(island)
    bad = 0
    for y in range(33):
        for x in range(33):
            if g.rb(corn + y * 33 + x) != c[y][x]:
                if bad < 5:
                    print('  corner', x, y, 'z80', g.rb(corn + y * 33 + x), 'model', c[y][x])
                bad += 1
    fm = M.gen_fine(c)
    fbad = sum(1 for i in range(128 * 128) if g.rb(0x8000 + i) != fm[i])
    flats = sum(1 for i in range(1024) if g.rb(S['TILEF'] + i) & 0x10)
    sees = sum(1 for i in range(1024) if g.rb(S['TILEF'] + i) & 0x08)
    objs = sum(1 for i in range(1024) if g.rb(S['OBJ'] + i))
    print('island %d: %.2f s gen, corners bad %d, fine bad %d, flats %d, lantern sees %d, objects %d, '
          'player %d, lantern %d' % (island, t / 3546875, bad, fbad, flats, sees, objs,
                                     g.rw('ptile'), g.rw('lant_t')))
    return bad == 0 and fbad == 0


if __name__ == '__main__':
    isl = [int(a) for a in sys.argv[1:]] or [1, 2, 3, 7]
    ok = all([check(i) for i in isl])
    print('OK' if ok else 'MISMATCH')
    sys.exit(0 if ok else 1)
