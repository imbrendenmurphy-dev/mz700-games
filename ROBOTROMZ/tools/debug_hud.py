"""debug_hud.py - find the tick where something lands in the HUD row or the
score stops being a multiple of 25."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402
import play  # noqa: E402

B = os.path.join(HERE, '..', 'build')
sym = load_syms(os.path.join(B, 'robogedn.sym'))
m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
play.patch(m, sym)
script = play.SCRIPTS[sys.argv[1] if len(sys.argv) > 1 else 'stand']
wv = sym['wait_vblank']
OBJ, SZ = 0x9000, 32
m.run_until_pc(wv, 10 ** 8)


def score():
    s = m.mem[sym['score']:sym['score'] + 3]
    return int('%02X%02X%02X' % (s[2], s[1], s[0]))


def dump():
    for i in range(80):
        o = m.mem[OBJ + i * SZ:OBJ + i * SZ + SZ]
        if o[0]:
            print('  #%2d type %2d x %2d y %2d st %3d tm %3d aux %02X' % (i, o[0], o[2], o[4], o[11], o[9], o[12]))


prev = 0
for t in range(1400):
    m.held = script(t)
    m.step()
    m.run_until_pc(wv, 10 ** 8)
    if m.mem[sym['state']] in (1, 2, 3):
        row0 = m.mem[0xB800:0xB800 + 40]
        bad = [c for c in range(40) if m.mem[0xBC00 + c] & 0x0F == 1]
        sc = score()
        if bad or sc % 25:
            print('tick', t, 'hud cells', bad, 'score', sc, 'prev', prev)
            dump()
            break
        prev = sc
