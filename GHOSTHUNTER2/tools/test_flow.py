"""test_flow.py - scripted checks of the game flow in the simulator.

    py tools/test_flow.py [case ...]

Cases: power, items, death, clear, bonus, inter, over.  Each starts a game
from the title, pokes the state it needs and takes screenshots
(build/shots/flow_*.png).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

GRID = 0xA000
A_X, A_Y, A_DIR, A_ST = 0, 1, 2, 7
ST_ACT, ST_FRT, ST_EYES = 2, 3, 4


def started():
    g = Game()
    g.run(30)
    g.run(4, ['space'])
    while g.rb('pvisible') == 0:          # wait for READY! to finish
        g.run(5)
    return g


def poke_actor(g, i, off, v):
    g.m.mem[S['actors'] + 16 * i + off] = v & 0xFF


def actor(g, i, off):
    return g.m.mem[S['actors'] + 16 * i + off]


def set_cell(g, x, y, code):
    g.m.mem[GRID + y * 64 + x] = code
    g.m.mem[GRID + 0x600 + y * 64 + x] = code


def status(g, tag):
    print('%-10s level %d lives %d score %s pellets %d fright %d super %d palette %d' % (
        tag, g.rb('level'), g.rb('lives'), g.m.mem[S['score']:S['score'] + 3].hex(),
        g.rw('pellets'), g.rb('frighttim'), g.rb('supertim'), g.rb('palette')))


def case_power():
    g = started()
    g.wb('godmode', 1)
    x, y = actor(g, 0, A_X), actor(g, 0, A_Y)
    set_cell(g, x - 1, y, 2)                 # an energiser just ahead (player starts going left)
    g.run(12)
    status(g, 'energiser')
    assert g.rb('frighttim') > 0, 'no fright'
    g.run(20)
    g.shot('flow_power')
    # put a frightened ghost on the player: it must be eaten
    for i in range(1, 5):
        if actor(g, i, A_ST) == ST_FRT:
            poke_actor(g, i, A_X, actor(g, 0, A_X))
            poke_actor(g, i, A_Y, actor(g, 0, A_Y))
            break
    g.run(3)
    g.shot('flow_eat')
    status(g, 'ate ghost')
    assert any(actor(g, i, A_ST) == ST_EYES for i in range(1, 5)), 'ghost not eaten'
    g.run(400)
    status(g, 'later')
    g.shot('flow_power_end')


def case_items():
    g = started()
    g.wb('godmode', 1)
    for it in range(12):
        g.wb('itemspr', it)
        g.wb('itemtim', 200)
        g.run(2)
        if it == 5:
            g.shot('flow_item_star')
        poke_actor(g, 0, A_X, 20)
        poke_actor(g, 0, A_Y, 14)
        g.run(3)
        status(g, 'item %d' % it)
        g.run(30)
        if it in (0, 2, 3, 4):
            g.shot('flow_item_%d' % it)
        for t in ('speedtim', 'freezetim', 'decoytim', 'x2tim', 'shieldtim', 'supertim'):
            g.wb(t, 0)


def case_death():
    g = started()
    g.run(20)
    poke_actor(g, 1, A_X, actor(g, 0, A_X))
    poke_actor(g, 1, A_Y, actor(g, 0, A_Y))
    poke_actor(g, 1, A_ST, ST_ACT)
    g.run(80)
    g.shot('flow_death')
    while g.rb('pvisible') == 0:
        g.run(5)
    status(g, 'after death')
    assert g.rb('lives') == 2


def case_clear(level=1, name='clear', inter=0):
    g = started()
    g.wb('godmode', 1)
    g.wb('level', level)
    g.wb('intermission', inter)
    g.wb('pellets', 1)
    g.wb('pellets', 0, 1)
    g.run(30)
    g.shot('flow_%s' % name)
    status(g, name)
    return g


def case_inter():
    g = case_clear(2, 'inter1', 1)
    g.run(300)
    g.shot('flow_inter1_a')
    g.run(200)
    g.shot('flow_inter1_b')
    g = case_clear(5, 'inter2', 2)
    g.run(300)
    g.shot('flow_inter2_a')
    g.run(150)
    g.shot('flow_inter2_b')


def case_bonus():
    g = case_clear(3, 'buffet')
    g.run(330)
    g.shot('flow_buffet_banner')
    g.run(400)
    g.shot('flow_buffet')
    status(g, 'buffet')
    g = case_clear(7, 'panic')
    g.run(330)
    g.shot('flow_panic_banner')
    g.run(400)
    g.shot('flow_panic')
    status(g, 'panic')


def case_over():
    g = started()
    g.wb('lives', 1)
    g.wb('extragiven', 1)
    g.m.mem[S['score']:S['score'] + 3] = bytes([0x02, 0x34, 0x50])
    g.run(20)
    poke_actor(g, 1, A_X, actor(g, 0, A_X))
    poke_actor(g, 1, A_Y, actor(g, 0, A_Y))
    poke_actor(g, 1, A_ST, ST_ACT)
    g.run(300)
    g.shot('flow_gameover')
    g.run(300)
    g.shot('flow_entry')
    for k in ('up', 'up', 'space', 'down', 'space', 'up', 'up', 'up', 'cr'):
        g.run(6, [k])
        g.run(6)
    g.run(150)
    g.shot('flow_after_entry')
    print(g.m.mem[S['HITAB']:S['HITAB'] + 30].hex())


CASES = {'power': case_power, 'items': case_items, 'death': case_death, 'clear': case_clear,
         'inter': case_inter, 'bonus': case_bonus, 'over': case_over}

if __name__ == '__main__':
    for c in (sys.argv[1:] or list(CASES)):
        print('==', c)
        CASES[c]()
