"""test_joy.py - the MZ-1X03 joystick, on the simulator's joystick model.

    py tools/test_joy.py

Opens the joystick page from the title (J), turns the stick on, checks the
measured pulse lengths, starts a game with fire 1 and plays 1-1 with the
stick: run right / left, jump (fire 1), tongue (fire 2), colour (up +
fire 2).  Repeats the play part with the MZRaku timing, and checks that an
empty port or stuck-low lines move nothing.  Screenshots: build/shots/joy_*.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

fails = []


def check(name, ok, info=''):
    print('%-44s %s %s' % (name, 'ok' if ok else 'FAIL', info))
    if not ok:
        fails.append(name)


def to_game(model, joy):
    g = Game(vram=True)
    g.m.joy_model = model
    g.m.joy = joy
    g.run(40)
    g.run(3, ['j'])
    g.run(10)
    g.run(3, ['j'])                 # joystick on
    g.run(10)
    g.run(3, ['space'])             # back to the title
    g.run(20)
    return g


def stick(g, fields, **kw):
    if g.m.joy is not None:
        g.m.joy = dict(x=0, y=0)
        g.m.joy.update(kw)
    g.run(fields)


def play(model):
    g = to_game(model, dict(x=0, y=0))
    check(model + ': title says joystick on', 'JOYSTICK ON' in g.text(19), g.text(19).strip())
    stick(g, 3, f1=True)            # fire 1 starts the game
    stick(g, 300)
    h = g.hero()
    check(model + ': fire 1 starts a game', g.rb('demo') == 0 and h['lives'] > 0, str(h))
    # the stick must move Kiko exactly as the cursor keys do (1-1 starts
    # with a bumble coming at him, so compare with a keyboard run)
    k = to_game(model, dict(x=0, y=0))
    k.m.joy = dict(x=0, y=0)
    k.run(3, ['space'])
    k.run(300)
    xs_s, xs_k = [], []
    for d, key in ((-1, 'left'),) * 30 + ((1, 'right'),) * 40:
        stick(g, 1, x=d)
        k.run(1, [key])
        xs_s.append(g.hero()['x'])
        xs_k.append(k.hero()['x'])
    check(model + ': stick left/right = cursor keys', xs_s == xs_k and min(xs_s) < xs_s[0] - 2
          and max(xs_s[30:]) > min(xs_s) + 2, 'stick %s' % xs_s[::5])
    if xs_s != xs_k:
        print('   keys  %s' % xs_k[::5])
    for i in range(100):
        stick(g, 1)
        if g.hero()['gnd'] and g.hero()['vy'] == 0:
            break
    y0 = g.hero()['y']
    ys = []
    for i in range(12):
        stick(g, 1, f1=True)
        ys.append(g.hero()['y'])
    check(model + ': fire 1 jumps', min(ys) < y0 - 2, 'y %d -> min %d' % (y0, min(ys)))
    stick(g, 60)
    t = []
    for i in range(6):
        stick(g, 1, f2=True)
        t.append(g.rb('htngst'))
    check(model + ': fire 2 shoots the tongue', any(t), str(t))
    stick(g, 40)
    g.wb('howned', 7)               # all three colours (1-1 has only green)
    c0 = g.rb('hcol')
    sw = []
    for i in range(6):
        stick(g, 1, y=-1, f2=True)
        sw.append(g.rb('hcol'))
    stick(g, 10)
    check(model + ': up + fire 2 changes colour', any(c != c0 for c in sw + [g.rb('hcol')]),
          '%d -> %s' % (c0, sw))
    g.shot('joy_play_' + model)
    return g


# the joystick page
g = Game(vram=True)
g.m.joy = dict(x=0, y=0)
g.run(40)
check('title offers J', 'J. JOYSTICK' in g.text(19), g.text(19).strip())
g.run(3, ['j'])
g.run(10)
g.shot('joy_page_off')
check('J opens the joystick page', 'JOYSTICK' in g.text(2) and 'OFF' in g.text(5), g.text(5).strip())
g.run(3, ['j'])
g.run(10)
check('J turns it on', 'ON' in g.text(5) and g.rb('joy_on') & 1, g.text(5).strip())
w = [g.rb('joy_w', i) for i in range(4)]
check('centred pulses ~16 lines, port 2 empty', 12 <= w[0] <= 18 and 12 <= w[1] <= 18 and w[2] == w[3] == 0, str(w))
g.m.joy = dict(x=1, y=-1, f1=True)
g.run(10)
g.shot('joy_page_on')
w = [g.rb('joy_w', i) for i in range(4)]
check('right ~32 lines, up ~0', 25 <= w[0] <= 34 and w[1] <= 1, str(w))
print(g.text(13))
check('test row lights RIGHT, UP, F1', 'RIGHT' in g.text(13), '%02X' % g.rb('joy_seen_k'))
check('seen as right+up+jump', g.rb('joy_seen_k') == 0x08 | 0x01 | 0x10, '%02X' % g.rb('joy_seen_k'))
g.m.joy = dict(x=0, y=0)
g.run(10)
g.run(3, ['space'])
g.run(30)
check('SPACE goes back to the title', 'PRESS SPACE' in g.screen_text() or 'JOYSTICK ON' in g.text(19))

play('mister')
play('mzraku')

# nothing plugged in / lines stuck low: the stick must not move Kiko
for model, joy in (('mister', None), ('stuck0', dict(x=0, y=0))):
    g = to_game(model, joy)
    g.run(3, ['space'])
    g.run(300)
    h0 = g.hero()
    g.run(150)
    h1 = g.hero()
    check('%s: Kiko stays put' % ('empty port' if joy is None else 'stuck lines'),
          abs(h0['x'] - h1['x']) <= 1 and h1['gnd'] and g.rb('htngst') == 0, '%s -> %s' % (h0, h1))

print('FAILED: ' + ', '.join(fails) if fails else 'all joystick checks passed')
sys.exit(1 if fails else 0)
