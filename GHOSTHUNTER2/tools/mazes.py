"""mazes.py - the six Ghost Hunter 2 mazes, converted to the MZ-700 char grid.

The VZ300 original stores each maze as 21 x 11 cells (left half given,
mirrored).  On the MZ-700 every cell becomes a character at (2cx, 2cy) and
the characters in between are "connectors": a 41 x 21 character maze with
1-character corridors, which suits the CG-ROM's 8x8 chomper and ghost
glyphs.  The game logic works on this character grid directly.

Grid codes (shared with the Z80 code):
    0 empty path   1 pellet   2 energiser   3 wall   4 door   5 house
    6 teleporter   7 tunnel (empty, ghosts slow down)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

GW, GH = 41, 21                 # character grid
STRIDE = 64                     # bytes per grid row in RAM

EMPTY, PELLET, ENERG, WALL, DOOR, HOUSE, TELE, TUNNEL = range(8)

# (name, title, left half 11 columns x 11 rows, wall style) - from the VZ300 gen.py
MAZES = [
    ('A', 'CLASSIC', ['###########', '#o........#', '#.##.####.#', '#..........', '#.##.#.##--',
                      'T....#.#GGG', '#.##.#.####', '#....#....P', '#.##.####.#', '#o........#',
                      '###########'], 1),
    ('B', 'CROSSROADS', ['###########', '#o....#....', '#.###.#.##.', '#..........', '##.##.###--',
                         'T......#GGG', '#.##.#.####', '#.#..#....P', '#.#.###.##.', '#o.........',
                         '###########'], 2),
    ('C', 'TELEPORT HALL', ['###########', '#X...#...o.', '#.##.#.#.#.', '#.#........', '#.#.##.##--',
                            'T...#..#GGG', '#.#.#.#####', '#.#.......P', '#.##.#.##.#', '#o...#...X#',
                            '###########'], 3),
    ('D', 'PILLARS', ['###########', '#o........#', '#.#.##.##.#', '#.#........', '#...##.##--',
                      '##.#...#GGG', '#..#.#.####', '#.#..#....P', '#.#.##.##.#', '#o.......o.',
                      '###########'], 4),
    ('E', 'PLAZAS', ['###########', '#o..#.....#', '#.#.#.###.#', '#..........', '#.#.#.###--',
                     'T.#.#.##GGG', '#.....#####', '##.#......P', '#..#.#.####', '#o...#.....',
                     '###########'], 5),
    ('F', 'PORTAL RUN', ['###########', '#....X#o...', '#.###.#.##.', '#.#........', '#.#.##.##--',
                         'T...#..#GGG', '###.#.#####', '#......#..P', '#.####.#.#.', '#o...X.....',
                         '###########'], 4),
]


def cells(half):
    rows = []
    for r in half:
        assert len(r) == 11
        rows.append(r[:10] + r[10] + r[9::-1])
    return rows


PATHC = ' .oPTX'          # cell characters an actor can stand on


def char_grid(half):
    """VZ cells -> list of GH rows of GW codes"""
    c = cells(half)
    H, W = len(c), len(c[0])

    def cell(cx, cy):
        if 0 <= cy < H:
            return c[cy][cx % W]
        return '#'

    g = [[WALL] * GW for _ in range(GH)]
    for y in range(GH):
        for x in range(GW):
            cx, cy = x // 2, y // 2
            if x % 2 == 0 and y % 2 == 0:
                ch = cell(cx, cy)
                g[y][x] = {'#': WALL, '.': PELLET, 'o': ENERG, ' ': EMPTY, 'P': EMPTY, 'T': TUNNEL,
                           'X': TELE, 'G': HOUSE, '-': DOOR}[ch]
            elif y % 2 == 0:                      # horizontal connector
                a, b = cell(cx, cy), cell(cx + 1, cy)
                if a in PATHC and b in PATHC:
                    g[y][x] = PELLET if (a in '.o' and b in '.o') else (TUNNEL if 'T' in (a, b) else EMPTY)
                elif a == 'G' and b == 'G':
                    g[y][x] = HOUSE
                elif a == '-' and b == '-':
                    g[y][x] = DOOR
            elif x % 2 == 0:                      # vertical connector
                a, b = cell(cx, cy), cell(cx, cy + 1)
                if a in PATHC and b in PATHC:
                    g[y][x] = PELLET if (a in '.o' and b in '.o') else EMPTY
            else:                                 # between four cells: open plaza
                q = [cell(cx, cy), cell(cx + 1, cy), cell(cx, cy + 1), cell(cx + 1, cy + 1)]
                if all(k in PATHC for k in q):
                    g[y][x] = PELLET if all(k in '.o' for k in q) else EMPTY
    # the door replaces the top line of the ghost house: door cells -> wall,
    # the row between door and house -> door
    doors = [(x, y) for y in range(GH) for x in range(GW) if g[y][x] == DOOR]
    for x, y in doors:
        g[y][x] = WALL
    for x, y in doors:
        g[y + 1][x] = DOOR
    return g


def check(g, name):
    """every path char reachable from the start, no dead ends"""
    def path(v):
        return v in (EMPTY, PELLET, ENERG, TELE, TUNNEL)
    start = (20, 14)
    assert path(g[14][20]), name
    seen = {start}
    st = [start]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = (x + dx) % GW, y + dy
            if 0 <= ny < GH and path(g[ny][nx]) and (nx, ny) not in seen:
                seen.add((nx, ny))
                st.append((nx, ny))
    allp = {(x, y) for y in range(GH) for x in range(GW) if path(g[y][x])}
    assert allp == seen, (name, sorted(allp - seen))
    for (x, y) in allp:
        n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= y + dy < GH and path(g[y + dy][(x + dx) % GW]))
        assert n >= 2, (name, 'dead end', x, y)
    return len(allp)


def all_grids():
    out = []
    for name, title, half, style in MAZES:
        g = char_grid(half)
        check(g, name)
        out.append((name, title, g, style))
    return out


if __name__ == '__main__':
    for name, title, g, style in all_grids():
        print(name, title, sum(r.count(PELLET) + r.count(ENERG) for r in g), 'pellets')
        for r in g:
            print(''.join(' .o#-GXt'[v] for v in r))
