"""test_joystick.py - the MZ-1X03 joystick option, with the simulator's
stick model: J cycles the option on the title, a button starts a game,
the range is learned, and STICK and PADDLE both move the seesaw."""
import sys
sys.path.insert(0, 'tools')
from run import Game, S

g = Game()
m = g.m
g.run(120)
assert g.rb('joy_mode') == 0
for want in (1, 2, 0, 1):
    g.run(3, ['j'])
    g.run(10)
    assert g.rb('joy_mode') == want, ('J', want, g.rb('joy_mode'))
g.shot('joy_title')
print('title option ok')

m.joy = {'x': 128, 'fire': False}
g.run(10)
assert g.rb('joy_x') > 0, 'no X pulse measured'
print('centre reads', g.rb('joy_x'))
m.joy['fire'] = True                    # a button starts the game
g.run(4)
m.joy['fire'] = False
ok = m.run_until_pc(S['play_act'], max_t=70886 * 3000)
assert ok, 'the button did not start a game'
print('button starts a game ok')

for x in (0, 255, 128):                 # waggle once to learn the range
    m.joy['x'] = x
    g.run(4)
lo, hi = g.rb('joy_min'), g.rb('joy_max')
print('learned range', lo, hi)
assert hi - lo > 100


def see():
    return g.rb('see_x', 1)


g.run(20)
s0 = see()
m.joy['x'] = 255
g.run(20)
s1 = see()
m.joy['x'] = 0
g.run(20)
s2 = see()
m.joy['x'] = 128
g.run(10)
s3 = see()
g.run(20)
s4 = see()
print('stick: centre %d, right %d, left %d, centre %d -> %d' % (s0, s1, s2, s3, s4))
assert s1 > s0 + 20 and s2 < s1 - 20 and s3 == s4
print('stick mode ok')

t0 = g.rb('tilt')
g.run(30)
m.joy['fire'] = True
g.run(3)
m.joy['fire'] = False
g.run(6)
print('tilt %d -> %d' % (t0, g.rb('tilt')))

g.wb('joy_mode', 2)                     # paddle: position = seesaw
for x in (20, 230, 128):
    m.joy['x'] = x
    g.run(90)
    jx = g.rb('joy_x')
    want = 16 + (jx - lo) * 128 // (hi - lo)
    lim = (g.rb('see_hw') + 4, 155 - g.rb('see_hw'))
    aim = max(min(want, lim[1]), lim[0])
    print('paddle x %d (count %d) -> seesaw %d (aim %d)' % (x, jx, see(), aim))
    assert abs(see() - aim) <= 6
g.shot('joy_paddle')
print('paddle mode ok')
print('late frames', g.rb('drops'))
