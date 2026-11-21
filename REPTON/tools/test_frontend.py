"""test_frontend.py - start a game, move, open the status screen, go back,
give up, enter a name for the records, and return to the title."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

g = Game()
g.run(60)
g.shot('fe_title')
g.run(5, ['space'])
g.run(150)                       # reveal
g.run(40, ['right'])
g.run(30, ['down'])
g.run(10)
g.shot('fe_play')
pos = g.rw('pl_pos')
g.run(5, ['space'])
g.run(60)
g.shot('fe_status')
print('status row 23:', g.text(23).strip())
g.run(5, ['n'])                  # any key back to play
g.run(100)
print('back in play:', g.rw('pl_pos') == pos)
g.run(5, ['break'])
g.run(20)
g.run(5, ['y'])
g.run(80)
g.run(60)
g.shot('fe_after')
print('records:', [bytes(g.m.mem[S['RECORDS'] + i * 8:S['RECORDS'] + i * 8 + 3]) for i in range(8)])
g.run(400)
g.shot('fe_title2')
print('title row 16:', g.text(16).strip())
