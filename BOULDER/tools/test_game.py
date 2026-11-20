"""test_game.py - scripted rule checks in the simulator.

    py tools/test_game.py [name ...]

Each test starts a game, waits for the player to appear, replaces the cave
with a small hand-drawn layout and checks what the physics does with it.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402
import caves  # noqa: E402

E = caves.E
CODE = {' ': 'SPACE', '.': 'DIRT', '#': 'BRICK', 'M': 'MAGIC', '%': 'STEEL', 'X': 'EXIT', 'x': 'EXITO',
        '@': 'BOULDER', 'D': 'DIAMOND', 'F': 'FIRE0', 'B': 'BUTT3', 'a': 'AMOEBA', 'P': 'PLAYER',
        '=': 'EXPWALL'}
SHOW = {v: k for k, v in CODE.items()}


def started():
    g = Game()
    g.run(50)
    g.run(6, ['space'])
    for _ in range(400):
        g.run(1)
        if g.rb('inbox_time') == 0 and g.rb('pl_dead') == 0:
            pa = g.rw('pl_addr')
            if g.m.mem[pa] & 0x1F == E['PLAYER']:
                return g
    raise RuntimeError('player never appeared')


def setup(g, rows, need=None):
    """rows: list of strings drawn from the top-left inside the border; rest is steel"""
    base = S['CAVE']
    m = g.m.mem
    for i in range(2048):
        m[base + i] = E['STEEL']
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            a = base + (y + 1) * 64 + x + 1
            m[a] = E[CODE[ch]]
            if ch == 'P':
                g.wb('pl_addr', a & 0xFF)
                g.wb('pl_addr', a >> 8, 1)
            if ch in 'Xx':
                g.wb('exit_addr', a & 0xFF)
                g.wb('exit_addr', a >> 8, 1)
    if need is not None:
        g.wb('need', need)
    g.wb('got', 0)
    g.wb('exit_open', 0)
    g.wb('magic_state', 0)
    g.wb('amoeba_conv', 0)


def at(g, x, y):
    v = g.m.mem[S['CAVE'] + (y + 1) * 64 + x + 1] & 0x1F
    return caves.ELEMS[v]


def show(g, w=12, h=8):
    out = []
    for y in range(h):
        s = ''
        for x in range(w):
            n = at(g, x, y)
            s += SHOW.get(n, n[0].lower() if not n[-1].isdigit() else '*')
        out.append(s)
    return '\n'.join(out)


def ticks(g, n, keys=()):
    sp = g.rb('speed')
    g.run(n * sp, keys)


RESULTS = []


def check(name, cond, g=None):
    RESULTS.append((name, cond))
    print('%-40s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond and g is not None:
        print(show(g))


def t_fall():
    g = started()
    setup(g, ['P   @    ', '         ', '         ', '         ', '.........'])
    ticks(g, 6)
    check('boulder falls and lands on dirt', at(g, 4, 3) == 'BOULDER' and at(g, 4, 0) == 'SPACE', g)


def t_roll():
    g = started()
    setup(g, ['P   @    ', '    @    ', '#########'])
    ticks(g, 4)
    check('boulder rolls off a boulder', at(g, 4, 0) == 'SPACE' and at(g, 3, 1) == 'BOULDER', g)


def t_collect():
    g = started()
    setup(g, ['PD.D.....', '.........'], need=5)
    s0 = g.rb('score')
    ticks(g, 4, ['right'])
    check('diamonds collected', g.rb('got') == 2, g)
    check('score went up', g.rb('score') != s0)


def t_exit():
    g = started()
    setup(g, ['PDD X....', '.........'], need=2)
    ticks(g, 3, ['right'])
    check('exit opens', g.rb('exit_open') == 1 and at(g, 4, 0) == 'EXITO', g)
    c0 = g.rb('cave_no')
    ticks(g, 3, ['right'])
    check('player leaves through exit', g.rb('pl_exit') == 1, g)
    g.run(600)
    check('next cave', g.rb('cave_no') == c0 + 1)


def t_snap():
    g = started()
    setup(g, ['PD.......', '.........'], need=9)
    ticks(g, 2, ['right', 'space'])
    check('snap takes diamond without moving', g.rb('got') == 1 and at(g, 0, 0) == 'PLAYER', g)


def t_push():
    g = started()
    setup(g, ['P@   ....', '.........'])
    ticks(g, 30, ['right'])
    check('player pushes boulder', at(g, 0, 0) == 'SPACE' and any(at(g, x, 0) == 'BOULDER' for x in (2, 3, 4)), g)


def t_firefly_crush():
    g = started()
    # a firefly in a vertical shaft under a boulder
    setup(g, ['P.......@#', '######## #', '######## #', '########F#', '##########'])
    exploded = False
    for _ in range(12):
        ticks(g, 1)
        if any(at(g, x, y).startswith('EXP') for x in range(10) for y in range(5)):
            exploded = True
    check('boulder crushes firefly: explosion', exploded, g)
    ticks(g, 6)
    check('explosion clears to space',
          not any(at(g, x, y).startswith(('FIRE', 'EXP')) for x in range(10) for y in range(5)), g)


def t_butterfly():
    g = started()
    setup(g, ['P.......@#', '######## #', '######## #', '########B#', '##########'])
    ticks(g, 16)
    n = sum(at(g, x, y) == 'DIAMOND' for x in range(10) for y in range(4))
    check('butterfly bursts into diamonds (%d)' % n, n >= 5, g)


def t_death():
    g = started()
    setup(g, ['P F......', '.........'])
    lives = g.rb('lives')
    ticks(g, 4)
    check('firefly next to player kills', g.rb('pl_dead') == 1, g)
    g.run(400)
    check('a life is lost', g.rb('lives') == lives - 1)


def t_magic():
    g = started()
    setup(g, ['P   @    ', '         ', 'MMMMMMMMM', '         ', '.........'])
    g.wb('magic_time', 20)
    ticks(g, 8)
    check('magic wall turns boulder to diamond', at(g, 4, 3) == 'DIAMOND' and g.rb('magic_state') == 1, g)


def t_amoeba():
    g = started()
    setup(g, ['P  #####', '   #a  #', '   #####'])
    g.wb('amoeba_fast', 1)
    for _ in range(60):
        ticks(g, 1)
        if at(g, 5, 1) == 'DIAMOND':
            break
    check('trapped amoeba becomes diamonds', at(g, 4, 1) == 'DIAMOND' and at(g, 5, 1) == 'DIAMOND', g)


def t_expwall():
    g = started()
    setup(g, ['P........', '   =     ', '.........'])
    ticks(g, 6)
    check('expanding wall grows', all(at(g, x, 1) == 'EXPWALL' for x in range(9)), g)


def t_timeout():
    g = started()
    setup(g, ['P........', '.........'])
    g.wb('ctime', 2)
    g.run(160)
    check('clock runs out', g.rb('timeout') == 1 and g.rb('ctime') == 0)


def t_fall_kills():
    g = started()
    setup(g, ['    @    ', '         ', '    P    ', '.........'])
    ticks(g, 4)
    check('falling boulder kills', g.rb('pl_dead') == 1, g)


def t_rest_safe():
    g = started()
    setup(g, ['    @    ', '    P    ', '.........'])
    ticks(g, 6)
    check('resting boulder does not kill', g.rb('pl_dead') == 0 and at(g, 4, 0) == 'BOULDER', g)


TESTS = [t_fall, t_roll, t_collect, t_snap, t_exit, t_push, t_firefly_crush, t_butterfly, t_death,
         t_magic, t_amoeba, t_expwall, t_timeout, t_fall_kills, t_rest_safe]

if __name__ == '__main__':
    want = sys.argv[1:]
    for t in TESTS:
        if not want or t.__name__[2:] in want:
            t()
    bad = [n for n, ok in RESULTS if not ok]
    print('%d checks, %d failed' % (len(RESULTS), len(bad)))
    sys.exit(1 if bad else 0)
