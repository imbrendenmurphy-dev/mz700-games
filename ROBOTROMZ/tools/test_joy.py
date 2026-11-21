"""test_joy.py - the MZ-1X03 joysticks: twin-stick and one-stick modes.

    py tools/test_joy.py

Uses the MZ-700 model's MZ-1X03 pair (see mzemu.joy_bits).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mzemu  # noqa: E402
from mzemu import MZ, load_syms  # noqa: E402

for k, rb in (('1', (5, 7)), ('2', (5, 6)), ('3', (5, 5))):
    mzemu.KEYS.setdefault(k, rb)
B = os.path.join(HERE, '..', 'build')
OUT = os.path.join(B, 'shots')
DIRS = {0: '-', 1: 'U', 2: 'D', 4: 'L', 8: 'R', 5: 'UL', 9: 'UR', 6: 'DL', 10: 'DR'}


def machine(mode_key):
    sym = load_syms(os.path.join(B, 'robogedn.sym'))
    m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
    m.mem[sym['player_die']] = 0xC9      # invincible, to keep the test simple
    wv = sym['wait_vblank']
    m.run_until_pc(wv, 10 ** 8)

    def tick(keys=()):
        m.held = set(keys)
        m.step()
        m.run_until_pc(wv, 10 ** 9)
    for _ in range(60):
        tick()
    for _ in range(3):
        tick([mode_key])
    tick()
    return m, sym, tick


def check(label, got, want):
    print('%-44s %-4s %s' % (label, got, 'ok' if got == want else 'WRONG (want %s)' % want))
    assert got == want


# ---- twin sticks
m, sym, tick = machine('2')
check('mode after pressing 2', m.mem[sym['ctlmode']], 1)
for _ in range(3):
    tick(['ja_fire'])                    # a fire button starts the game
for _ in range(10):
    tick()
check('fire button started a game (state INTRO)', m.mem[sym['state']], 0)
while m.mem[sym['state']] != 1:
    tick()
x0 = m.mem[sym['px'] + 1]
for _ in range(20):
    tick(['ja_right', 'jb_up', 'jb_left'])
check('stick A right -> move', DIRS[m.mem[sym['mkeys']]], 'R')
check('stick B up+left -> fire', DIRS[m.mem[sym['fkeys']]], 'UL')
check('player moved right', m.mem[sym['px'] + 1] > x0, True)
shots = [m.mem[sym['SHOTS'] + 4 * k] for k in range(12)] if 'SHOTS' in sym else []
check('shots flying up-left (direction 8)', 8 in shots, True)
for _ in range(6):
    tick(['ja_down'])
check('stick A down', DIRS[m.mem[sym['mkeys']]], 'D')
check('stick B centred -> no fire', DIRS[m.mem[sym['fkeys']]], '-')
for _ in range(6):
    tick(['ja_down', 'w'])
check('keyboard still works too (W cancels down)', DIRS[m.mem[sym['mkeys']]], '-')
m.screen(2).save(os.path.join(OUT, 'joy_twin.png'))

# ---- one stick: hold fire to shoot the way you face, and strafe
m, sym, tick = machine('3')
check('mode after pressing 3', m.mem[sym['ctlmode']], 2)
for _ in range(3):
    tick(['ja_fire'])
while m.mem[sym['state']] != 1:
    tick()
for _ in range(8):
    tick(['ja_left'])
check('one stick: moving left, not firing', DIRS[m.mem[sym['fkeys']]], '-')
for _ in range(8):
    tick(['ja_down', 'ja_fire'])
check('fire held: shoots the way you faced (left)', DIRS[m.mem[sym['fkeys']]], 'L')
check('... while strafing down', DIRS[m.mem[sym['mkeys']]], 'D')
for _ in range(8):
    tick(['ja_down'])
for _ in range(4):
    tick(['ja_fire'])
check('released, moved down, fire: shoots down', DIRS[m.mem[sym['fkeys']]], 'D')

# ---- keyboard mode ignores the sticks
m, sym, tick = machine('1')
check('mode after pressing 1', m.mem[sym['ctlmode']], 0)
for _ in range(4):
    tick(['space'])
while m.mem[sym['state']] != 1:
    tick()
for _ in range(6):
    tick(['ja_right', 'jb_up'])
check('keyboard mode: sticks ignored (move)', DIRS[m.mem[sym['mkeys']]], '-')
check('keyboard mode: sticks ignored (fire)', DIRS[m.mem[sym['fkeys']]], '-')
print('ok')
