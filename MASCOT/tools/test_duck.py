"""test_duck.py - DOWN ducks on a plank; DOWN + JUMP drops through it.

    py tools/test_duck.py

Starts 1-2, puts Kiko on the left plank in room A and checks that holding
DOWN ducks him without dropping, that the low tongue works there, that
DOWN + jump drops him through, and that a plain jump still jumps.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402
import levels as LV  # noqa: E402

fails = []


def check(name, ok, info=''):
    print('%-40s %s %s' % (name, 'ok' if ok else 'FAIL', info))
    if not ok:
        fails.append(name)


lv = [i for i, l in enumerate(LV.LEVELS) if l.code == '1-2'][0]
rows = LV.LEVELS[lv].byname['A'].rows if hasattr(LV.LEVELS[lv], 'byname') else None
py = [y for y, r in enumerate(rows) if r[5:12] == '=======' and r[4] == ' '][0]


def on_plank():
    g = Game(vram=True)
    g.run(60)
    g.wb('start_level', lv)
    g.run(10, ['space'])
    g.run(150)
    g.wb('kx', 7)
    g.wb('ky', py - 1)
    g.run(20)
    h = g.hero()
    assert h['gnd'] and h['y'] == py - 1, h
    return g


g = on_plank()
ys, ducks = [], []
for i in range(40):
    g.run(1, ['down'])
    ys.append(g.hero()['y'])
    ducks.append(g.rb('hduck'))
check('DOWN on a plank: stays on it', set(ys) == {py - 1}, str(sorted(set(ys))))
check('DOWN on a plank: ducks', all(ducks[2:]), str(ducks[:8]))
g.shot('duck_plank')
t = []
for i in range(8):
    g.run(1, ['down', 'x'])
    t.append(g.rb('htngst'))
check('ducked tongue on a plank', any(t) and g.hero()['y'] == py - 1, str(t))
g.run(30)

g = on_plank()
g.run(2, ['down'])
g.run(2, ['down', 'z'])
ys = []
for i in range(25):
    g.run(1, ['down'])
    ys.append(g.hero()['y'])
check('DOWN + jump drops through', max(ys) > py and min(ys) >= py - 1, str(ys[::3]))

g = on_plank()
ys = []
for i in range(15):
    g.run(1, ['z'])
    ys.append(g.hero()['y'])
check('jump alone still jumps', min(ys) < py - 3, str(ys[::3]))

print('FAILED: ' + ', '.join(fails) if fails else 'all duck checks passed')
sys.exit(1 if fails else 0)
