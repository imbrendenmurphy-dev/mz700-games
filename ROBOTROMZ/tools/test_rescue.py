"""test_rescue.py - humans are saved from the 8 cells round them, not from
two cells away.

    py tools/test_rescue.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402
import play  # noqa: E402

B = os.path.join(HERE, '..', 'build')
OBJ, SZ = 0x9000, 32
os.environ['GOD'] = '1'
os.environ['WAVE'] = '5'                # lots of humans


def fresh():
    sym = load_syms(os.path.join(B, 'robogedn.sym'))
    m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
    play.patch(m, sym)
    wv = sym['wait_vblank']
    m.run_until_pc(wv, 10 ** 8)

    def tick(keys=()):
        m.held = set(keys)
        m.step()
        m.run_until_pc(wv, 10 ** 9)
    for _ in range(300):
        tick()
    for _ in range(4):
        tick(['space'])
    while m.mem[sym['state']] != 1:
        tick()
    return m, sym, tick


def humans(m, sym):
    out = []
    for i in range(m.mem[sym['objtop']]):
        o = m.mem[OBJ + i * SZ:OBJ + i * SZ + SZ]
        if 10 <= o[0] <= 12 and o[11] == 0:
            out.append((i, o[2], o[4]))
    return out


def trial(dx, dy):
    m, sym, tick = fresh()
    hs = [h for h in humans(m, sym) if 3 <= h[1] + dx <= 36 and 4 <= h[2] + dy <= 21]
    i, x, y = hs[0]
    o = OBJ + i * SZ
    m.mem[o + 9] = 200                  # hold the human still for this test
    saved0 = m.mem[sym['saved']]
    m.mem[sym['px'] + 1] = x + dx
    m.mem[sym['py'] + 1] = y + dy
    tick()
    tick()
    saved = m.mem[sym['saved']] - saved0
    return saved, m.mem[o]


for dx, dy, want in ((0, 0, 1), (1, 0, 1), (-1, 1, 1), (0, -1, 1), (1, 1, 1), (2, 0, 0), (0, 2, 0)):
    saved, typ = trial(dx, dy)
    print('player at %+d,%+d from a human: saved %d (human now type %d)  %s' % (
        dx, dy, saved, typ, 'ok' if saved == want else 'WRONG'))
    assert saved == want
print('ok')
