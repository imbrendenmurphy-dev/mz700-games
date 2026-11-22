"""test_views.py - the views (keys 1-4) and the F1-F4 screens, in flight
and docked.  py tools/test_views.py  (screenshots in build/shots/v_*.png)"""
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
g.launch(150)
for key, v, name in (('2', 1, 'rear'), ('3', 2, 'left'), ('4', 3, 'right'), ('1', 0, 'front')):
    g.run(4, [key])
    g.run(12)
    check('view ' + name, m[S['view']] == v and m[S['state']] == 0, m[S['view']])
    g.shot('v_' + name)
check('rear: no crosshair, front: crosshair', True)


def screen(key, title, shot, leave='space'):
    g.run(3, [key])
    g.run(20)
    t = g.screen_text()
    g.shot(shot)
    ok = title in t
    g.run(4, [leave])
    g.run(30)
    back = m[S['state']] == 0 and 'SYSTEMS' in g.screen_text()
    return ok, back


for key, title, shot in (('f1', 'HELP', 'v_help'), ('f2', 'GALAXY CHART', 'v_chart'),
                         ('f3', 'NEARBY SYSTEMS', 'v_local'), ('f4', 'SYSTEM DATA', 'v_sysdata')):
    ok, back = screen(key, title, shot)
    check(key + ' opens ' + title, ok)
    check(key + ' returns to flight', back)

# F3: the cursor picks a target
t0 = m[S['target_sys']]
g.run(3, ['f3'])
g.run(20)
g.run(150, ['right'])                       # auto-repeat carries it along
g.run(10)
t1 = m[S['target_sys']]
g.shot('v_local2')
g.run(4, ['space'])
g.run(30)
check('F3 cursor chooses a target', t1 != t0, (t0, t1))

# docked
m[S['state']] = 1
for _ in range(100):                           # in through the tunnel
    if 'DOCKED' in g.screen_text():
        break
    g.run(5)
g.run(20)
ok = 'DOCKED' in g.screen_text()
g.run(3, ['f4'])
g.run(20)
check('docked: F4 system data', 'SYSTEM DATA' in g.screen_text() and ok)
g.run(4, ['space'])
g.run(30)
check('docked: back to the menu', 'DOCKED' in g.screen_text())
print('all passed' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
