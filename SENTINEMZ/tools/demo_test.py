"""demo_test.py - let the AI pilot play an island and log what it does.

    py tools/demo_test.py [island] [fields] [shot_every]

Logs every action (absorb / cairn / shell / move / turn), energy and the
result; screenshots go to build/shots/demo_<island>_NNNN.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S, SENTINEL  # noqa: E402


def main():
    isl = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    fields = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
    every = int(sys.argv[3]) if len(sys.argv) > 3 else 500
    g = Game()
    g.run(2)                                    # start-up code: clears vars, detects VBLANK
    c = g.m.cpu
    c.sp = 0xCFF0 - 2
    g.m.mem[c.sp] = SENTINEL & 255
    g.m.mem[c.sp + 1] = SENTINEL >> 8
    g.wb('demo_n', (isl - 2) & 3)               # run_demo picks demo_n + 1 + 1
    c.pc = S['run_demo']
    log = []
    names = {S['act_absorb']: 'ABSORB', S['act_cairn']: 'CAIRN', S['act_shell']: 'SHELL',
             S['act_move']: 'MOVE', S['lantern_out']: 'LANTERN OUT', S['do_render']: None}
    turns = [0]

    def hook(name):
        def f(gm):
            if name is None:
                return
            log.append((gm.m.field(), name, gm.rw('tgt_t'), gm.rb('energy'), gm.rw('ptile')))
            print('%6d %-12s tgt %4d energy %2d at %4d' % log[-1])
        return f
    for a, n in names.items():
        g.hooks[a] = hook(n)
    end_f = None
    for f in range(fields):
        try:
            g.run(1)
        except RuntimeError as e:
            if c.pc == SENTINEL:
                end_f = f
                break
            raise
        if f % every == every - 1:
            g.shot('demo_%d_%04d' % (isl, f + 1))
    print('result', g.rb('result'), 'ended at field', end_f, 'energy', g.rb('energy'),
          'turns', g.rb('ai_turns'), 'actions', len(log))
    g.shot('demo_%d_end' % isl)


if __name__ == '__main__':
    main()
