"""test_joy.py - the MZ-1X03 joystick option in the simulator.

    py tools/test_joy.py

Plugs a simulated stick into socket A, socket B (with the polarity
flipped) or nowhere, switches it on with J on the title, and checks the
calibration, the directions and both fire switches in flight and on the
mixer screens.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402

fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok  ' if ok else 'FAIL') + ' ' + name + ('  ' + str(info) if info else ''))
    if not ok:
        fails += 1


def rb(g, name, off=0):
    return g.m.mem[S[name] + off]


def plug_and_enable(joy):
    g = Game()
    g.m.joy = joy
    g.run(10)
    g.run(3, ['j'])
    g.run(30)
    return g


def flight_dirs(g, frames=40):
    """joystick K_ bits seen by the flight code over a few frames"""
    seen = 0
    for _ in range(frames):
        g.run(1)
        seen |= rb(g, 'keys')
    return seen


for port, inv in (('A', False), ('B', True), ('A', True), ('B', False)):
    tag = 'socket %s%s' % (port, ' inverted' if inv else '')
    joy = dict(x=128, y=128, sw1=False, sw2=False, port=port, inv=inv)
    g = plug_and_enable(joy)
    check(tag + ': on', rb(g, 'joy_on') == 1)
    lo, hi = rb(g, 'joy_lo'), rb(g, 'joy_hi')
    check(tag + ': limits', 5 <= lo < 12 < hi <= 30, (lo, hi, rb(g, 'joy_lo', 1), rb(g, 'joy_hi', 1)))
    check(tag + ': message', 'JOYSTICK ON' in g.screen_text(), '')
    # menus (mixer mode): the stick moves the title? no - check joy_dirs
    joy['x'] = 0
    g.run(12)
    check(tag + ': mixer left', rb(g, 'joy_dirs') == 1, rb(g, 'joy_dirs'))
    joy['x'] = 128
    g.run(12)
    check(tag + ': mixer centre', rb(g, 'joy_dirs') == 0, rb(g, 'joy_dirs'))
    for _ in range(2):                             # SW1: to the station, then out
        joy['sw1'] = True
        g.run(6)
        joy['sw1'] = False
        g.run(100)
    for _ in range(80):
        if rb(g, 'state') == 0 and rb(g, 'snd_mode') == 0 and rb(g, 'tn_f') >= 32:
            break
        g.run(5)
    g.run(30)
    check(tag + ': SW1 launched', rb(g, 'state') == 0 and rb(g, 'snd_mode') == 0,
          (rb(g, 'state'), rb(g, 'snd_mode')))
    if port == 'A' and not inv:
        for (x, y), want in (((255, 128), 2), ((0, 128), 1), ((128, 0), 4), ((128, 255), 8), ((128, 128), 0)):
            joy['x'], joy['y'] = x, y
            g.run(20)                          # a frame or two to read it and use it
            seen = flight_dirs(g, 20)
            check('flight stick %d,%d' % (x, y), seen & 15 == want, seen)
        # every flight frame should get a fresh reading
        joy['x'] = 0
        f0 = rb(g, 'frame')
        changes = 0
        for _ in range(60):
            g.m.mem[S['joy_dirs']] = 0x80
            g.run(1)
            if g.m.mem[S['joy_dirs']] != 0x80:
                changes += 1
        frames = (rb(g, 'frame') - f0) & 255
        check('flight readings', changes >= frames * 0.8, '%d readings, %d frames in 60 fields' % (changes, frames))
        joy['x'] = 128
        g.run(5)
        joy['sw1'] = True
        g.run(10)
        check('SW1 fires lasers', rb(g, 'heat') > 0, rb(g, 'heat'))
        joy['sw1'] = False
        g.run(10)
        joy['sw2'] = True
        g.run(4)
        m_held = rb(g, 'mkey') & 8
        joy['sw2'] = False
        g.run(4)
        check('SW2 works as M (seeker)', m_held and not rb(g, 'mkey') & 8)

# the cost in flight: frames in 300 fields with and without the stick
counts = []
for joy in (None, dict(x=128, y=128, port='A')):
    g = Game()
    g.m.joy = joy
    g.run(10)
    if joy:
        joy['x'] = joy['y'] = 128
        g.run(3, ['j'])
        g.run(30)
    else:
        g.run(33)
    g.run(8, ['space'])
    g.run(80)
    g.run(8, ['space'])
    g.run(300)
    f0 = rb(g, 'frame')
    g.run(300)
    counts.append((rb(g, 'frame') - f0) & 255)
check('flight frame rate kept', counts[1] >= counts[0] * 0.95, 'frames in 300 fields: keys %d, stick on %d' % tuple(counts))

g = Game()
g.run(10)
g.run(3, ['j'])
g.run(30)
check('no stick: stays off', rb(g, 'joy_on') == 0)
check('no stick: message', 'NO JOYSTICK' in g.screen_text())

g = plug_and_enable(dict(x=128, y=128, port='A'))
g.run(3, ['j'])
g.run(10)
check('J again: off', rb(g, 'joy_on') == 0 and 'JOYSTICK OFF' in g.screen_text())

print('all passed' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
