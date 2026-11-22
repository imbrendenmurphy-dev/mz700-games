"""test_keys.py - the ZX Spectrum Elite key layout in flight and docked.
py tools/test_keys.py"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok  ' if ok else 'FAIL') + ' ' + name + ('  ' + str(info) if info else ''))
    if not ok:
        fails += 1


g = Game()
m = g.m.mem
g.launch(60)
m[S['spawn_t']] = 255


def held(keys, n=8):
    seen = 0
    for _ in range(n):
        g.run(1, keys)
        seen |= m[S['keys']]
    g.run(4)
    return seen


check('N rolls left', held(['n']) & 1)
check('M rolls right', held(['m']) & 2)
check('S dives', held(['s']) & 4)
check('X climbs', held(['x']) & 8)
check('A fires lasers', held(['a']) & 0x10 and m[S['heat']] > 0, m[S['heat']])
s0 = m[S['speed']]
g.run(20, ['space'])
check('SPACE speeds up', m[S['speed']] > s0, (s0, m[S['speed']]))
s1 = m[S['speed']]
g.run(20, ['shift'])
check('SHIFT slows down', m[S['speed']] < s1, (s1, m[S['speed']]))
g.run(4, ['c'])
g.run(10)
check('C: docking computer (none fitted)', 'NO' in g.text(0) or 'DOCK' in g.text(0), g.text(0).strip())
def w16(a, v):
    m[a] = v & 255
    m[a + 1] = (v >> 8) & 255


def r16s(a):
    v = m[a] | m[a + 1] << 8
    return v - 65536 if v > 32767 else v


g.run(6, ['j'])
g.run(4)
check('J near the station: mass locked', 'MASS LOCKED' in g.text(0), g.text(0).strip())
for k in range(1, 8):
    m[S['objects'] + 32 * k] = 0
w16(S['objects'] + 6, -30000)                  # the station far behind
w16(S['planet'] + 4, 30000)
z0 = r16s(S['planet'] + 4)
g.run(10, ['j'])
z1 = r16s(S['planet'] + 4)
check('J in open space: the jump drive rushes us on', z0 - z1 > 3000, (z0, z1))
g.run(4, ['ctrl'])
g.run(20)
check('CTRL freezes', 'PAUSED' in g.text(0))
g.run(4, ['q'])
g.run(10)
g.run(4, ['ctrl'])
g.run(20)
check('Q while frozen: sound off', m[S['snd_mute']] == 1)
g.run(4, ['ctrl'])
g.run(10)
g.run(4, ['s'])
g.run(10)
g.run(4, ['space'])
g.run(20)
check('S while frozen: sound on, SPACE goes on', m[S['snd_mute']] == 0)
g.run(4, ['i'])
g.run(20)
check('I: galactic chart', 'GALAXY' in g.screen_text())
g.run(4, ['space'])
g.run(30)
g.run(4, ['o'])
g.run(20)
check('O: local chart', 'NEARBY' in g.screen_text())
g.run(4, ['space'])
g.run(30)
g.run(4, ['p'])
g.run(20)
check('P: data on the system', 'SYSTEM DATA' in g.screen_text())
g.run(4, ['space'])
g.run(30)
m[S['state']] = 1
for _ in range(100):
    if 'DOCKED' in g.screen_text():
        break
    g.run(5)
g.run(20)
g.run(4, ['2'])
g.run(30)
check('docked 2: buy (the market)', 'MARKET' in g.screen_text())
g.run(4, ['space'])
g.run(30)
g.run(4, ['4'])
g.run(30)
check('docked 4: equip', 'EQUIP' in g.screen_text())
g.run(4, ['space'])
g.run(30)
g.run(4, ['1'])
for _ in range(80):
    if m[S['state']] == 0 and m[S['tn_f']] >= 32:
        break
    g.run(5)
check('docked 1: launch', m[S['state']] == 0)
print('all passed' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
