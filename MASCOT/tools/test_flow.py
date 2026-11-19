"""test_flow.py - the end of the game: final boss, tally, ending, high score.

    py tools/test_flow.py

Beats the Baron (as test_boss.py does), then lets the game run: level
clear tally, the ending sequence, high-score name entry (types K, I, K)
and the return to the title.  Screenshots: build/shots/flow_*.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import test_boss  # noqa: E402

ok = test_boss.main(4)
g = test_boss.main.game
print('boss beaten:', ok, 'score', ['%02X' % g.rb('score', i) for i in (2, 1, 0)])
for f in range(0, 2400, 100):
    g.run(100)
    g.shot('flow_%04d' % f)
    print(f, g.text(3).strip(), '|', g.text(13).strip(), '|', g.text(22).strip())
    if 'ENTER YOUR NAME' in g.screen_text() or 'HIGH SCORE' in g.screen_text():
        break
# name entry: UP x10 (K), next, UP x8 (I), next, UP x10 (K), next
for ups in (10, 8, 10):
    for i in range(ups):
        g.run(3, ['up'])
        g.run(3)
    g.run(3, ['space'])
    g.run(6)
g.run(150)
g.shot('flow_names')
print(g.screen_text())
from run import S
for i in range(8):
    e = [g.m.mem[S['hiscores'] + i * 6 + k] for k in range(6)]
    print('HS %02X%02X%02X %s' % (e[2], e[1], e[0], bytes(e[3:6]).decode()))
g.run(300)
g.shot('flow_back')
print('back at title:', 'PRESS SPACE' in g.screen_text())
