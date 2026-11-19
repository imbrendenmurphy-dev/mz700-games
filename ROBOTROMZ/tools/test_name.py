"""test_name.py - play until game over, type initials, check the table.

    py tools/test_name.py

The default table is lowered so any score gets in.  Types R, O, B, a DEL,
then B and RETURN, so the entry should read "ROB".
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402
import play  # noqa: E402

B = os.path.join(HERE, '..', 'build')
OUT = os.path.join(B, 'shots')
sym = load_syms(os.path.join(B, 'robogedn.sym'))
m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
for i in range(8):                       # every default score 000000
    for j in range(3):
        m.mem[sym['hisc_init'] + i * 8 + j] = 0
wv = sym['wait_vblank']
m.run_until_pc(wv, 10 ** 8)


def tick(keys):
    m.held = set(keys)
    m.step()
    m.run_until_pc(wv, 10 ** 9)


t = 0
while m.cpu.pc != sym['enter_name'] and t < 20000:
    m.held = play.s_play(t)
    m.step()
    c = m.cpu
    while c.pc != wv and c.pc != sym['enter_name']:
        m.step()
    t += 1
print('name entry reached at tick', t)
for _ in range(30):
    tick([])
m.screen(2).save(os.path.join(OUT, 'name_0.png'))
for k in ('r', 'o', 'x', 'del', 'b'):   # a typo, rubbed out
    tick([k])
    for _ in range(6):
        tick([])
m.screen(2).save(os.path.join(OUT, 'name_1.png'))
for _ in range(80):
    tick([])
for _ in range(120):                    # heroes page
    tick([])
m.screen(2).save(os.path.join(OUT, 'name_2.png'))
tab = m.mem[0xA6A0:0xA6A0 + 64]
for i in range(8):
    e = tab[i * 8:i * 8 + 8]
    print(i + 1, bytes(e[3:6]).decode('ascii', 'replace'), '%02X%02X%02X' % (e[2], e[1], e[0]), 'W%d' % e[6])
