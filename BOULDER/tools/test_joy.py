"""test_joy.py - the MZ-1X03 joystick on the simulator: J on the title
switches it on, every stick position and button reads right, a button
starts a game, and the stick walks the player.

    py tools/test_joy.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

UP, DOWN, LEFT, RIGHT, FIRE = 1, 2, 4, 8, 16
fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print('%-34s %s' % (name, 'ok' if ok else 'FAILED (got %02X, want %02X)' % (got, want)))


z = Game()
z.run(60)
check('joystick off at start', z.rb('joy_on'), 0)
z.m.joy = [128, 128, 0, 0]
z.run(3, ['j'])
z.run(3)
check('J switches it on', z.rb('joy_on'), 1)
z.m.screenshot(os.path.join(z.shots, 'joy_title.png'))
for name, joy, want in (('centred', [128, 128, 0, 0], 0),
                        ('left', [10, 128, 0, 0], LEFT),
                        ('right', [245, 128, 0, 0], RIGHT),
                        ('up', [128, 10, 0, 0], UP),
                        ('down', [128, 245, 0, 0], DOWN),
                        ('up + left', [0, 0, 0, 0], UP | LEFT),
                        ('down + right', [255, 255, 0, 0], DOWN | RIGHT),
                        ('a little off centre', [100, 160, 0, 0], 0),
                        ('SW1 + down', [128, 245, 1, 0], FIRE | DOWN)):
    z.m.joy = joy
    z.run(3)
    check('stick ' + name, z.rb('joy_bits'), want)
# that button started the game; then walk right with the stick
z.m.joy = [128, 128, 0, 0]
z.run(250)
check('a button starts a game', z.rb('demo'), 0)
z.m.joy = [10, 128, 0, 1]
z.run(10)
check('stick SW2 + left (in the game)', z.rb('joy_bits'), FIRE | LEFT)
z.m.joy = [128, 128, 0, 0]
z.run(3)
a = z.rw('pl_addr')
z.m.joy = [250, 128, 0, 0]
z.run(40)
b = z.rw('pl_addr')
check('stick right walks the player', 1 if b > a else 0, 1)
z.m.screenshot(os.path.join(z.shots, 'joy_game.png'))
# switched off again, an unplugged port does nothing
z2 = Game()
z2.run(60)
z2.m.joy = [0, 0, 1, 1]
z2.run(30)
check('off: the port is ignored', z2.rb('joy_bits'), 0)
print('%d failed' % fails)
sys.exit(1 if fails else 0)
