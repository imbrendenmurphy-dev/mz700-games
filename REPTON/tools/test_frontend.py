"""test_frontend.py - start a game, open the status screen, save to (simulated) tape,
give up, enter a name, then load the saved game back from the title."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

g = Game()
g.run(60)
g.run(5, ['space'])
g.run(150)                       # reveal
g.run(40, ['right'])
g.run(30, ['down'])
g.run(10)
pos = g.rw('pl_pos')
g.shot('fe_play')
g.run(5, ['space'])
g.run(60)
g.shot('fe_status')
g.run(5, ['s'])
g.run(250)
print('saved bytes:', len(g.tape_data or b''), 'saved pos', g.tape_data[3] | g.tape_data[4] << 8, 'live', g.rw('pl_pos'))
g.run(5, ['n'])                  # any key back to play
g.run(100)
g.run(5, ['break'])
g.run(20)
g.run(5, ['y'])
g.run(80)
g.run(60)
g.shot('fe_after')
from run import S  # noqa: E402
print('records:', [bytes(g.m.mem[S['RECORDS'] + i * 8:S['RECORDS'] + i * 8 + 3]) for i in range(8)])
# load it back
g.shot('fe_before_load'); g.run(5, ['l'])
g.run(300)
g.shot('fe_loaded')
print('loaded: region', g.rb('region'), 'pos', g.rw('pl_pos'), 'expected', pos)
print('demo', g.rb('demo'), 'tape_err?', 'magic', hex(g.rw('save_magic')))
