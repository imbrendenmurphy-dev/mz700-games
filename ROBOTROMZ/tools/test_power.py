"""test_power.py - power-ups: collect one, check 3-Way fires 3 shots and the
Shield protects (and destroys what it touches).

    py tools/test_power.py
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
os.environ['WAVE'] = '3'
m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
play.patch(m, sym)
wv = sym['wait_vblank']
OBJ, SZ = 0x9000, 32


def w(name):
    return m.mem[sym[name]] | m.mem[sym[name] + 1] << 8


def score():
    s = m.mem[sym['score']:sym['score'] + 3]
    return int('%02X%02X%02X' % (s[2], s[1], s[0]))


def tick(keys=()):
    m.held = set(keys)
    m.step()
    m.run_until_pc(wv, 10 ** 9)


m.run_until_pc(wv, 10 ** 8)
for t in range(300):
    tick()
for t in range(4):
    tick(['space'])
while m.mem[sym['state']] != 1:
    tick()
# make a pickup appear now
m.mem[sym['picktm']] = 1
m.mem[sym['picktm'] + 1] = 0
for t in range(30):
    tick()
pick = None
for i in range(m.mem[sym['objtop']]):
    o = m.mem[OBJ + i * SZ:OBJ + i * SZ + SZ]
    if o[0] == 16 and o[11] == 0:
        pick = (i, o[2], o[4], o[12])
print('pickup:', pick)
assert pick, 'no pickup appeared'
s0 = score()
m.mem[sym['px'] + 1] = pick[1]                  # stand on it
m.mem[sym['py'] + 1] = pick[2]
tick()
tick()
kind = 'SHIELD' if pick[3] else '3-WAY'
print('collected %s: pw3 %d pwsh %d, score +%d' % (kind, w('pw3'), w('pwsh'), score() - s0))
assert (w('pwsh') if pick[3] else w('pw3')) > 0, 'not collected'
assert score() - s0 >= 250

# 3-Way: fire right once and count shots
m.mem[sym['pw3']] = 200
m.mem[sym['pw3'] + 1] = 0
m.mem[sym['firecd']] = 0
tick(['l'])
shots = [m.mem[0xA680 + k * 4] for k in range(12)]
print('shot directions after one 3-Way volley:', [d for d in shots if d])
assert sum(1 for d in shots if d) >= 3, '3-Way did not fire three'
m.screen(2).save(os.path.join(OUT, 'power_3way.png'))

# Shield: stand still and let things come; we must not die while it's up
m.mem[sym['pwsh']] = 250
m.mem[sym['pwsh'] + 1] = 0
s0 = score()
for t in range(240):
    tick()
    assert m.mem[sym['state']] != 2, 'died with the shield up (tick %d)' % t
    if t == 60:
        m.screen(2).save(os.path.join(OUT, 'power_shield.png'))
print('shield held for 240 ticks; score +%d meanwhile' % (score() - s0))
print('HUD:', ''.join(chr(c + 64) if 1 <= c <= 26 else '.' for c in m.mem[0xD000 + 23:0xD000 + 31]))
print('ok')
