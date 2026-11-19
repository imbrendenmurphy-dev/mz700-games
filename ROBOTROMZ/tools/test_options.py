"""test_options.py - T (trainer) and M (sound modes) on the title page."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402

B = os.path.join(HERE, '..', 'build')
OUT = os.path.join(B, 'shots')
sym = load_syms(os.path.join(B, 'robogedn.sym'))
m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
wv = sym['wait_vblank']


def tick(keys=()):
    m.held = set(keys)
    m.step()
    m.run_until_pc(wv, 10 ** 9)


m.run_until_pc(wv, 10 ** 8)
for t in range(100):
    tick()
modes = []
for k in ('t', None, 'm', None, 'm', None, 'm', None):
    for _ in range(3):
        tick([k] if k else [])
    modes.append((m.mem[sym['trainer']], m.mem[sym['soundopt']], m.mem[sym['sndon']]))
print('trainer, sound option, sound on after T, M, M, M:', modes[1::2])
m.screen(2).save(os.path.join(OUT, 'options_title.png'))
for _ in range(4):
    tick(['space'])
lives = []
for t in range(1800):                   # stand still: get killed a few times
    tick()
    if t % 300 == 0:
        lives.append(m.mem[sym['lives']])
print('lives over time in trainer mode:', lives, 'state', m.mem[sym['state']])
m.screen(2).save(os.path.join(OUT, 'options_trainer.png'))
