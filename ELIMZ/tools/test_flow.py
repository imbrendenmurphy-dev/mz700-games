"""test_flow.py - smoke test of the whole game in the simulator.

    py tools/test_flow.py

Title -> attract (demo flight, gallery, handbook) -> title; then a game:
launch tunnel, flight, docking (forced), market buy, launch, hyperspace
(forced), arrival, death (forced), game over, back to the title.  Fails if
the PC escapes, the stack runs wild or a screen is not reached.
Screenshots: build/shots/flow_*.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

g = Game()
m = g.m
mem = m.mem
ok = True


def check(name, cond):
    global ok
    print('%-4s %s' % ('ok' if cond else 'FAIL', name))
    ok = ok and cond


def until(cond, limit, step=5):
    n = 0
    while not cond() and n < limit:
        g.run(step)
        n += step
    return cond()


st = lambda: mem[S['state']]          # noqa: E731
mode = lambda: mem[S['snd_mode']]     # noqa: E731

g.run(40)
check('title: the tracker waltz on the tone generator', mode() == 0 and mem[S['trk_on']] == 1)
f0 = mem[S['title_ang']]
g.run(30)
check('title: the ship spins every frame', (mem[S['title_ang']] - f0) & 63 >= 9)
mem[S['att_t']] = 2
mem[S['att_t'] + 1] = 0
check('attract demo flies on the tone generator', until(lambda: mem[S['autoplay']] == 1 and mode() == 0, 200))
g.shot('flow_demo')
mem[S['demo_t']] = 2
mem[S['demo_t'] + 1] = 0
check('demo hands over to the gallery', until(lambda: mem[S['autoplay']] == 0, 300))
check('the waltz plays on through the demo and gallery', mem[S['trk_on']] == 1)
g.run(100)
g.shot('flow_gallery')
g.run(4, ['space'])
t0 = mem[S['title_ang']]
check('a key returns to the title', until(lambda: mem[S['title_ang']] != t0 and mem[S['autoplay']] == 0, 300))
g.run(20)
g.run(8, ['space'])
check('a game starts with the launch tunnel', until(lambda: mem[S['fx_n']] > 0, 60, 2))
g.shot('flow_tunnel')
check('flight after the tunnel', until(lambda: st() == 0 and mode() == 0, 200))
mem[S['state']] = 1
check('docked: the waltz in the mixer', until(lambda: mode() == 1 and mem[S['mus_on']] == 1, 100))
g.run(30)
g.shot('flow_docked')
g.run(6, ['m'])
g.run(30)
cr0 = mem[S['credits']] | (mem[S['credits'] + 1] << 8)
g.run(6, ['right'])
g.run(10)
g.run(6, ['space'])
g.run(30)
g.shot('flow_market')
g.run(6, ['break'])
g.run(30)
g.run(8, ['space'])
check('launch again', until(lambda: st() == 0 and mode() == 0, 300))
mem[S['state']] = 3
check('hyperspace screen', until(lambda: mem[S['fx_n']] > 0 and mode() == 1, 100, 2))
g.shot('flow_hyper')
check('arrival', until(lambda: st() == 0 and mode() == 0 and mem[S['arrive']] == 1, 400))
mem[S['energy']] = 0
mem[S['shield']] = 0
for k in range(1, 8):
    mem[S['objects'] + 32 * k] = 0
check('death sequence in the mixer', until(lambda: mode() == 1, 50, 2))
g.run(30)
g.shot('flow_death')
check('back to the title after game over', until(lambda: mem[S['att_t'] + 1] == 1, 900))
g.shot('flow_title')
print('ALL OK' if ok else 'SOME CHECKS FAILED')
sys.exit(0 if ok else 1)
