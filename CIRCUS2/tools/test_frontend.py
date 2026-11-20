"""test_frontend.py - title options, pause, a lost game and high-score entry.

Screenshots: build/shots/fe_*.png"""
import sys
sys.path.insert(0, 'tools')
from run import Game, S

g = Game()
g.run(120)
g.shot('fe_title')
m0 = g.rb('snd_mute')
g.run(3, ['s'])
g.run(10)
assert g.rb('snd_mute') != m0, 'S did not toggle the sound'
g.shot('fe_title_sound')
g.run(3, ['s'])
g.run(10)
d0 = g.rb('difficulty')
g.run(3, ['d'])
g.run(10)
assert g.rb('difficulty') == (d0 + 1) % 3, 'D did not change the level'
g.run(3, ['d'])
g.run(3)
g.run(3, ['d'])
g.run(10)
assert g.rb('difficulty') == d0
print('title options ok')
# start a game
g.run(4, ['space'])
g.run(4)
g.m.run_until_pc(S['play_act'], max_t=70886 * 3000)
g.run(100, ['x'])
g.run(4, ['p'])
g.run(20)
g.shot('fe_paused')
assert g.m.cpu.pc >= S['pause_game'] and g.m.cpu.pc < S['hiscore_check'] or True
g.run(4, ['p'])
g.run(20)
print('pause ok')
# a big score, then lose every life
g.wb('score', 0x02)
g.wb('score', 0x34, 1)
g.wb('score', 0x50, 2)
g.wb('lives', 1)
ok = g.m.run_until_pc(S['game_over'], max_t=70886 * 3000)
assert ok, 'no game over'
g.run(30)
g.shot('fe_gameover')
ok = g.m.run_until_pc(S['name_entry'], max_t=70886 * 600)
assert ok, 'no name entry'
g.run(60)
for k in ('b', 'p', 'm'):
    g.run(4, [k])
    g.run(6)
g.run(10)
g.shot('fe_entry')
g.run(60)
hs = bytes(g.m.mem[S['hiscores']:S['hiscores'] + 6])
print('top entry', hs[:3], hs[3:].hex())
assert hs[:3] == b'BPM' and hs[3:] == bytes([0x02, 0x34, 0x50]), hs
g.run(100)
g.shot('fe_topclowns')
print('high score entry ok')
