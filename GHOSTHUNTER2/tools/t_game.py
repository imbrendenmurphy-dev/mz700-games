import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S
g = Game()
g.run(60)
g.run(4, ['space'])
g.run(60)
g.shot('g_start')
g.run(300)
g.shot('g_ready')
print(g.screen_text())
for k, n in (('left', 60), ('up', 40), ('right', 80), ('down', 40)):
    g.run(n, [k])
    print(k, g.actor(0)[:4], 'score', g.m.mem[S['score']:S['score']+3].hex(), 'pellets', g.rw('pellets'))
g.shot('g_play')
for i in range(1, 5):
    print('ghost', i, g.actor(i)[:14])
