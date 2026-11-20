"""shots.py - README screenshots (docs/*.png): title, an act card, act 1, act 5, act 7, a bonus round."""
import os
import shutil
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
docs = os.path.join(ROOT, 'docs')
os.makedirs(docs, exist_ok=True)


def keep(g, name):
    shutil.copy(g.shot('doc_' + name), os.path.join(docs, name + '.png'))


g = Game()
g.run(170)
keep(g, 'title')


def play_act(act, card_name=None, fields=900):
    g = Game()
    g.run(60)
    g.m.held = {'space'}
    g.m.run_until_pc(S['wait_release'], max_t=70886 * 50)
    g.m.held = set()
    g.m.run_until_pc(S['act_setup'], max_t=70886 * 200)
    g.wb('act', act - 1)
    g.wb('autoplay', 1)
    if card_name:
        g.m.run_until_pc(S['curtain_open'], max_t=70886 * 400)
        g.run(60)
        keep(g, card_name)
    g.m.run_until_pc(S['play_act'], max_t=70886 * 2000)
    g.run(fields)
    return g


keep(play_act(1, 'card', 700), 'play')
keep(play_act(5, None, 500), 'act5')
keep(play_act(7, None, 600), 'act7')
keep(play_act(4, None, 500), 'bonus')
print('docs/ updated')
