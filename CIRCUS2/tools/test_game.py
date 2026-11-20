"""test_game.py [difficulty] [max_fields] - the pilot plays a real game from the title.

Starts a game with SPACE, then lets the demo pilot steer (autoplay) at full
speed (turbo).  Logs every act, life lost and the final result, checks the
compositor invariant (no object cells left behind) and keeps screenshots of
each act in build/shots/game_*.png."""
import sys
import time
sys.path.insert(0, 'tools')
from run import Game, S

diff = int(sys.argv[1]) if len(sys.argv) > 1 else 1
maxf = int(sys.argv[2]) if len(sys.argv) > 2 else 60000
immortal = '--immortal' in sys.argv
g = Game()
g.hit_game_over = False
_go = S['game_over']
_run = g.run


def run_watch(fields, keys=()):
    c = g.m.cpu
    g.m.held = set(keys)
    end = c.t + int(fields * 70886)
    while c.t < end:
        c.step()
        if c.pc == _go:
            g.hit_game_over = True
        elif not (0x1200 <= c.pc < g.end):
            raise RuntimeError('PC escaped to %04X' % c.pc)


g.run = run_watch
g.run(60)
g.wb('difficulty', diff)
g.run(4, ['space'])
g.run(4)
g.wb('autoplay', 1)
g.wb('turbo', 1)
t0 = time.time()
last = None
f = 0
seen = set()
while f < maxf:
    g.run(25)
    f += 25
    if immortal and g.rb('lives') < 3:
        g.wb('lives', 5)
    act, enc, lives = g.rb('act'), g.rb('encore'), g.rb('lives')
    sc = '%02X%02X%02X' % (g.rb('score'), g.rb('score', 1), g.rb('score', 2))
    state = (act, enc, lives)
    if state != last:
        print('field %6d act %d encore %d lives %d score %s left %d' % (f, act + 1, enc, lives, sc,
                                                                       g.rb('balloons_left')))
        last = state
    if enc >= 1 and act >= 1 and immortal:
        print('reached the encore')
        break
    if (act, enc) not in seen and g.rb('balloons_total') and g.rb('balloons_left') < g.rb('balloons_total') // 2:
        seen.add((act, enc))
        g.shot('game_act%d_%d' % (act + 1, enc))
    if g.hit_game_over:
        print('game over at field', f, 'score', sc, 'act', act + 1, 'encore', enc)
        break
print('%d fields in %.0fs, drops %d' % (f, time.time() - t0, g.rb('drops')))
g.shot('game_end')
