"""test_puzzles.py - solve every vault on the Z80 build (mzemu).

    py tools/test_puzzles.py [seed]

For each puzzle the test finds the prefab in RAM (by its gate or emitter),
solves it in Python from the prefab's layout (prefabs.py) and plays the
solution with key taps, teleporting the player between moves where the
route doesn't matter.  It checks the gate opens / the prize is reachable.
"""
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harness as H  # noqa: E402
import defs as D  # noqa: E402
import content as C  # noqa: E402
import prefabs as P  # noqa: E402

T = D.T
KEY = {(1, 0): 'RIGHT', (-1, 0): 'LEFT', (0, 1): 'DOWN', (0, -1): 'UP'}
results = []


def check(name, ok, info=''):
    results.append((name, ok))
    print('%-10s %s %s' % (name, 'ok' if ok else 'FAILED', info))


def origin(ram, name, ch, tile):
    """map position of the prefab's top-left, found by a tile it holds"""
    g = P.grid(name)
    rel = [(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == ch][0]
    for x, y in H.find_tiles(ram, tile):
        return x - rel[0], y - rel[1]
    return None


def sokoban_moves():
    g = P.grid('PLATES')
    ex, ey, _ = P.entrance('PLATES')
    walls = {(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c in '#CGD'}
    plates = {(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == '^'}
    bs = frozenset((x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == 'O')
    start = ((ex, ey + 1), bs)
    prev = {start: None}
    q = deque([start])
    while q:
        st = q.popleft()
        (px, py), bs = st
        if plates <= bs:
            path = []
            while prev[st]:
                st, d = prev[st]
                path.append(d)
            return path[::-1], (ex, ey + 1)
        for d in KEY:
            nx, ny = px + d[0], py + d[1]
            if (nx, ny) in walls:
                continue
            nb = bs
            if (nx, ny) in bs:
                b2 = (nx + d[0], ny + d[1])
                if b2 in walls or b2 in bs:
                    continue
                nb = frozenset((bs - {(nx, ny)}) | {b2})
            s2 = ((nx, ny), nb)
            if s2 not in prev:
                prev[s2] = (st, d)
                q.append(s2)
    return None, None


def ice_moves():
    g = P.grid('ICE')
    ex, ey, _ = P.entrance('ICE')
    h, w = len(g), len(g[0])

    def free(x, y):
        return 0 <= x < w and 0 <= y < h and g[y][x] in 'I.1'
    s = (ex, ey + 1)
    prev = {s: None}
    q = deque([s])
    while q:
        x, y = q.popleft()
        if g[y][x] == '1':
            path = []
            st = (x, y)
            while prev[st]:
                st, d = prev[st]
                path.append(d)
            return path[::-1], s
        for d in KEY:
            nx, ny = x, y
            moved = False
            while free(nx + d[0], ny + d[1]):
                nx, ny = nx + d[0], ny + d[1]
                moved = True
                if g[ny][nx] != 'I':
                    break
            if moved and (nx, ny) not in prev:
                prev[(nx, ny)] = ((x, y), d)
                q.append((nx, ny))
    return None, None


def lever_moves():
    g = P.grid('LEVERS')
    ex, ey, _ = P.entrance('LEVERS')
    h, w = len(g), len(g[0])
    s = (ex, ey + 1, 0)
    prev = {s: None}
    q = deque([s])
    while q:
        st = q.popleft()
        x, y, k = st
        if g[y][x] == '1':
            path = []
            while prev[st]:
                st, d = prev[st]
                path.append(d)
            return path[::-1], (ex, ey + 1)
        for d in KEY:
            nx, ny = x + d[0], y + d[1]
            c = g[ny][nx]
            nk = k
            if c == 'V':
                nk, nx, ny = k ^ 1, x, y
            elif c in '#PA' or (c == 'l' and k == 0) or (c == 'o' and k == 1):
                continue
            s2 = (nx, ny, nk)
            if s2 not in prev:
                prev[s2] = (st, d)
                q.append(s2)
    return None, None


def main(seed):
    # ---- plates (zone 0)
    g = H.Game(seed)
    ram = g.run(name='p0')
    o = origin(ram, 'PLATES', 'G', T['GATEP'])
    moves, start = sokoban_moves()
    g.poke('hp', 250, 250)
    g.clear_monsters()
    g.place(o[0] + start[0], o[1] + start[1])
    for d in moves:
        g.keys(KEY[d], gap=10)
    ram = g.run('t_plates.png', name='p1')
    gx, gy = o[0] + 11, o[1] + 3
    check('plates', H.tile(ram, gx, gy) == T['GATEOPEN'], '(%d pushes/steps)' % len(moves))

    # ---- braziers (zone 3): firebolts at the far ones, bumps at the near
    g = H.Game(seed)
    g.warp(3)
    ram = g.run(name='p2')
    o = origin(ram, 'BRAZIER', 'A', T['ALTAR'])
    grid = P.grid('BRAZIER')
    g.poke('hp', 250, 250)
    g.clear_monsters()
    for (bx, by) in [(x, y) for y, r in enumerate(grid) for x, c in enumerate(r) if c == 'B']:
        # stand two below it (row 3/5 is open floor) and cast up, or bump from below
        sx, sy = bx, by + 1
        while grid[sy][sx] != '.':
            sy += 1
        g.poke('mp', 20, 20)
        g.place(o[0] + sx, o[1] + sy)
        if sy == by + 1:
            g.keys('UP', gap=20)
        else:
            g.keys('SPACE', gap=10)
            g.keys('UP', gap=60)
    ram = g.run('t_braziers.png', name='p3')
    gx, gy = o[0] + 7, o[1] + 6
    check('braziers', H.tile(ram, gx, gy) == T['GATEOPEN'],
          'unlit left: %d' % len(H.find_tiles(ram, T['BRAZOFF'])))

    # ---- ice (zone 4)
    g = H.Game(seed)
    g.warp(4)
    ram = g.run(name='p4')
    o = origin(ram, 'ICE', 'A', T['ALTAR'])
    moves, start = ice_moves()
    g.poke('hp', 250, 250)
    g.clear_monsters()
    g.place(o[0] + start[0], o[1] + start[1])
    for d in moves:
        g.keys(KEY[d], gap=40)
    ram = g.run('t_ice.png', name='p5')
    px, py = g.peek(ram, 'px'), g.peek(ram, 'py')
    slot = [(x, y) for y, r in enumerate(P.grid('ICE')) for x, c in enumerate(r) if c == '1'][0]
    check('ice', (px - o[0], py - o[1]) == slot, '(%d slides) at %d,%d sigils %d' % (
        len(moves), px - o[0], py - o[1], g.peek(ram, 'sigils')))

    # ---- levers (zone 5)
    g = H.Game(seed)
    g.warp(5)
    ram = g.run(name='p6')
    o = origin(ram, 'LEVERS', 'A', T['ALTAR'])
    moves, start = lever_moves()
    g.poke('hp', 250, 250)
    g.clear_monsters()
    g.place(o[0] + start[0], o[1] + start[1])
    for d in moves:
        g.keys(KEY[d], gap=12)
    ram = g.run('t_levers.png', name='p7')
    check('levers', g.peek(ram, 'sigils') & 4 != 0, '(%d moves)' % len(moves))

    # ---- seal (zone 5): with all three sigils
    g = H.Game(seed)
    g.warp(5)
    ram = g.run(name='p8')
    o = origin(ram, 'SEAL', 'S', T['SEAL'])
    g.poke('sigils', 7)
    g.place(o[0] + 5, o[1] - 1)
    g.keys('DOWN', gap=30)
    g.keys('DOWN', 'DOWN', gap=20)
    ram = g.run('t_seal.png', name='p9')
    check('seal', H.tile(ram, o[0] + 5, o[1]) == T['OPEN'])

    # ---- mirrors (zone 6)
    g = H.Game(seed)
    g.warp(6)
    ram = g.run(name='pa')
    o = origin(ram, 'MIRROR', 'e', T['EMITTER'])
    for (mx, my) in [(15, 1), (15, 5)]:
        g.place(o[0] + mx - 1, o[1] + my)
        g.keys('RIGHT', gap=30)
    ram = g.run('t_mirror.png', name='pb')
    check('mirror', H.tile(ram, o[0] + 10, o[1] + 6) == T['GATEOPEN'],
          'beam cells %d' % g.peek(ram, 'beam_n'))

    # ---- the sun-stone: lift it in the crypt, carry it to the Grotto's
    # sun gate, set it down (the dark glass opens), pass, take it back
    g = H.Game(seed)
    g.poke('hp', 250, 250)
    ram = g.run(name='pc')
    st = H.find_tiles(ram, T['PEDLIT'])
    check('stone', len(st) == 1, 'at %s' % (st,))
    sx, sy = st[0]
    for d in KEY:
        if D.TILES[H.tile(ram, sx - d[0], sy - d[1])][1] & D.F_FLOORY:
            break
    g.clear_monsters()
    g.place(sx - d[0], sy - d[1])
    g.keys(KEY[d], gap=30)
    g.frames(10)
    ram = g.run('t_stone.png', name='pd')
    check('lift', g.peek(ram, 'relic') == 1 and H.tile(ram, sx, sy) == T['PEDESTAL'],
          'torch %d hue %02X' % (g.peek(ram, 'torch'), g.peek(ram, 'torch_hue')))
    g.warp(1)
    ram = g.run(name='pe')
    o = origin(ram, 'SUNGATE', 'H', T['LDOOR'])
    g.clear_monsters()
    g.place(o[0] + 5, o[1] + 4)
    g.keys('DOWN', gap=20)                   # the shut door stops you
    ram = g.run(name='pf')
    shut = g.peek(ram, 'py') == o[1] + 4
    g.keys('UP', gap=30)                     # set the stone on its stand
    g.keys('DOWN', 'DOWN', gap=20)
    ram = g.run('t_sungate.png', name='pg')
    check('sungate', shut and H.tile(ram, o[0] + 5, o[1] + 5) == T['LDOPEN']
          and g.peek(ram, 'py') == o[1] + 6 and g.peek(ram, 'relic') == 0)
    g.keys('UP', 'UP', gap=20)
    g.keys('UP', gap=30)                     # lift it again: the glass shuts
    ram = g.run(name='ph')
    check('retake', H.tile(ram, o[0] + 5, o[1] + 5) == T['LDOOR'] and g.peek(ram, 'relic') == 1)
    return all(ok for _, ok in results)


if __name__ == '__main__':
    ok = main(int(sys.argv[1], 0) if len(sys.argv) > 1 else 0x1234)
    print('ALL OK' if ok else 'SOME FAILED')
    sys.exit(0 if ok else 1)
