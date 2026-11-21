"""test_joystick.py - the MZ-1X03 joystick option on the Z80 build.

Switches the joystick on with J on the title, starts a game with fire,
moves Skink with the stick, and checks the pulse counts, the speed with
the joystick on, and that an unplugged joystick option stays harmless
while it is off.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

ok = True


def check(cond, what):
    global ok
    print(('ok   ' if cond else 'FAIL ') + what)
    ok = ok and cond


def centre(g):
    g.m.joy = {'x': 128, 'y': 128, 'fire': False}


g = Game()
centre(g)
g.run(60)
check('JOYSTICK OFF' in g.text(17), 'title shows "J  JOYSTICK OFF": %r' % g.text(17).strip())
g.run(5, ['j'])
g.run(5)
check(g.rb('joy_on') == 1 and 'JOYSTICK ON' in g.text(17), 'J switches it on: %r' % g.text(17).strip())
g.run(5, ['j'])
g.run(5)
check(g.rb('joy_on') == 0, 'J again switches it off')
g.run(5, ['j'])
g.run(10)
check(g.rb('joy_on') == 1, 'and on again')

# pulse counts for the three stick positions
counts = {}
for name, x, y in (('left/up', 0, 0), ('centre', 128, 128), ('right/down', 255, 255)):
    g.m.joy = {'x': x, 'y': y, 'fire': False}
    g.run(4)
    counts[name] = (g.rb('joy_raw'), g.rb('joy_raw', 1), g.rb('joy_bits'))
print('pulse counts (x, y, bits):', counts)
check(counts['centre'][2] == 0, 'centre gives no direction')
check(counts['left/up'][2] == 0x05, 'full left and up give LEFT+UP')
check(counts['right/down'][2] == 0x0A, 'full right and down give RIGHT+DOWN')
# thresholds sit a quarter of the way from the centre (positions 64 / 192)
for x, want in ((60, 4), (70, 0), (186, 0), (196, 8)):
    g.m.joy = {'x': x, 'y': 128, 'fire': False}
    g.run(4)
    check(g.rb('joy_bits') == want, 'x=%d -> bits %d (got %d, count %d)' % (
        x, want, g.rb('joy_bits'), g.rb('joy_raw')))

# fire starts a game
centre(g)
g.run(5)
g.m.joy['fire'] = True
g.run(5)
g.m.joy['fire'] = False
g.run(200)                       # the reveal
check(g.rb('demo') == 0 and g.rw('tick') > 0, 'fire on the title starts a game (tick %d)' % g.rw('tick'))

# the stick moves Skink
start = g.rw('pl_pos')
g.m.joy = {'x': 255, 'y': 128, 'fire': False}
g.run(40)
centre(g)
g.run(10)
moved = g.rw('pl_pos') - start
check(moved > 0 and moved < 32, 'stick right moves Skink right (%d cells)' % moved)
start = g.rw('pl_pos')
g.m.joy = {'x': 128, 'y': 255, 'fire': False}
g.run(30)
centre(g)
g.run(10)
moved = g.rw('pl_pos') - start
check(moved > 0 and moved % 32 == 0, 'stick down moves Skink down (%d rows)' % (moved // 32))

# speed with the joystick on (pushing against walls keeps the view busy)
t0 = g.rw('tick')
g.m.joy = {'x': 0, 'y': 128, 'fire': False}
g.run(300)
rate = (g.rw('tick') - t0) / 6.0
check(rate > 8.0, 'speed with the joystick on: %.2f ticks a second (target 8.33)' % rate)

# off by default: an unplugged socket (all lines high) does nothing
g2 = Game()
g2.run(60)
g2.run(5, ['space'])
g2.run(200)
start = g2.rw('pl_pos')
g2.run(50)
check(g2.rb('joy_on') == 0 and g2.rw('pl_pos') == start, 'joystick off by default: Skink stays put')

print('ALL OK' if ok else 'SOME CHECKS FAILED')
sys.exit(0 if ok else 1)
