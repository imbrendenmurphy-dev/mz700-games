"""test_ships.py - fuel as a good, the shipyard and skimming the sun.
py tools/test_ships.py  (screenshots build/shots/s_*.png)"""
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


def w16(a, v):
    m[a] = v & 255
    m[a + 1] = (v >> 8) & 255


def cr():
    return m[S['credits']] | m[S['credits'] + 1] << 8 | m[S['credits'] + 2] << 16


def set_cr(v):
    m[S['credits']] = v & 255
    m[S['credits'] + 1] = (v >> 8) & 255
    m[S['credits'] + 2] = v >> 16


g.run(60)
g.run(8, ['space'])
g.run(80)
check('start: the Kestrel, 7.0 ly, hold 20, top speed 32',
      (m[S['hull']], m[S['fuel']], m[S['holdmax']], m[S['max_speed']]) == (0, 70, 20, 32),
      (m[S['hull']], m[S['fuel']], m[S['holdmax']], m[S['max_speed']]))
check('fuel has a local price and stock', 15 <= m[S['fuel_price']] <= 80 and m[S['fuel_stock']] > 0,
      (m[S['fuel_price']], m[S['fuel_stock']]))
# market: the fuel row
m[S['fuel']] = 30
c0 = cr()
g.run(4, ['2'])
g.run(30)
for _ in range(10):
    g.run(3, ['down'])
    g.run(3)
g.shot('s_market')
check('market shows a FUEL row', 'FUEL' in g.screen_text())
g.run(3, ['right'])
g.run(10)
check('RIGHT on fuel buys a light year at the local price',
      m[S['fuel']] == 40 and c0 - cr() == m[S['fuel_price']], (m[S['fuel']], c0 - cr(), m[S['fuel_price']]))
g.run(3, ['left'])
g.run(10)
check('fuel cannot be sold', m[S['fuel']] == 40)
g.run(4, ['space'])
g.run(30)
# F: fill up
m[S['fuel']] = 0
g.run(4, ['f'])
g.run(20)
check('F fills the tank (as stock and credits allow)', m[S['fuel']] > 0, m[S['fuel']])
# shipyard
set_cr(50000)
g.run(4, ['5'])
g.run(30)
g.run(3, ['down'])
g.run(5)
g.run(3, ['right'])
g.run(10)
g.shot('s_yard_rank')
check('the Swift needs rank Pilot', m[S['hull']] == 0 and 'RANK' in g.screen_text())
m[S['kills']] = 5
g.run(3, ['right'])
g.run(10)
check('with rank: the Swift bought (12 hold, 12.0 ly, speed 44)',
      (m[S['hull']], m[S['holdmax']], m[S['max_fuel']], m[S['max_speed']], m[S['fuel']]) == (1, 12, 120, 44, 120),
      (m[S['hull']], m[S['holdmax']], m[S['max_fuel']], m[S['max_speed']], m[S['fuel']]))
check('paid the price less the trade-in (1100 - 360 cr)', 50000 - cr() == 11000 - 3600, 50000 - cr())
g.shot('s_yard')
g.run(4, ['space'])
g.run(30)
g.shot('s_docked')
# equipment: the fuel scoop (item 8)
m[S['cur_sys']] = m[S['cur_sys']]
g.run(4, ['4'])
g.run(30)
for _ in range(7):
    g.run(3, ['down'])
    g.run(3)
g.run(3, ['right'])
g.run(10)
check('fuel scoop bought (tech allowing)', m[S['has_fscoop']] == 1, m[S['has_fscoop']])
g.run(4, ['space'])
g.run(30)
# the sun: point straight at it, full speed, a low tank
g.run(4, ['1'])
for _ in range(80):
    if m[S['state']] == 0 and m[S['tn_f']] >= 32:
        break
    g.run(5)
g.run(20)
m[S['spawn_t']] = 255
w16(S['sunv'], 0)
w16(S['sunv'] + 2, 0)
w16(S['sunv'] + 4, 16384)
m[S['fuel']] = 10
m[S['speed']] = 44
d0 = m[S['sun_d']] | m[S['sun_d'] + 1] << 8
g.run(60, ['space'])
d1 = m[S['sun_d']] | m[S['sun_d'] + 1] << 8
check('flying at the sun brings it nearer', d1 < d0, (d0, d1))
check('the sun is a long cruise away', d0 - d1 < 1200, d0 - d1)
w16(S['sun_d'], 1800)                  # then on to the edge of the heat
fuel_seen = 0
temp_seen = 0
sh = m[S['shield']]
for i in range(60):
    g.run(5, ['space'])
    fuel_seen = max(fuel_seen, m[S['fuel']])
    temp_seen = max(temp_seen, m[S['temp']])
    if i == 20:
        g.shot('s_sun')
check('skimming with a scoop fills the tank', fuel_seen > 10, fuel_seen)
check('the cabin heats up', temp_seen >= 40, temp_seen)
check('too hot: the shields burn', m[S['shield']] < sh or m[S['state']] == 2, (sh, m[S['shield']], m[S['state']]))
print('all passed' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
