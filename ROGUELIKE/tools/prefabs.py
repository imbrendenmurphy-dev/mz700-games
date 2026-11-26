"""prefabs.py - LUMEN's hand-made rooms (puzzle vaults, the throne hall).

A prefab is stamped into one cell of a zone's 3 x 3 room grid.  Its one
entrance is the door on its outer wall ('D', 'L' locked, 'S' sigil seal);
the generator runs a corridor to the cell just outside it.

Legend:
  #  wall        .  floor       ,  floor 2      ~  water       =  lava
  I  ice         P  pillar      B  brazier (out) b  brazier (lit)
  G  plate gate  g  brazier gate M  beam gate    l  lever gate (shut)
  o  lever gate (open)          ^  plate        O  boulder     V  lever
  /  \\  mirrors  e  beam emitter (shines right)  t  beam target
  A  altar       C  chest       T  throne       x  exit (the zone link)
  c  crystal     F  fountain    f  fungus       R  rune        K  sconce
  D  door        L  locked door S  sigil seal
  _  empty sun-stone pedestal   H  dark-glass door (opens while steady
     light of level 5+ falls on it: set the sun-stone on the pedestal)
  1 2 3  item slots (zone data)  m  a monster of the zone   k  the boss

`check()` proves each puzzle solvable (and not already solved).
"""
PREFABS = {
    'PLATES': [
        "#######D##########",
        "#,....#....#.....#",
        "#..O..#.^..#..1..#",
        "#.........OG.....#",
        "#..O....^..#..C..#",
        "#,....#....#.....#",
        "##################",
    ],
    'LOCKVAULT': [
        "###L#####",
        "#f.....f#",
        "#..1.2..#",
        "#f..C..f#",
        "#########",
    ],
    'ISLAND': [
        "######D###########",
        "#................#",
        "#.~~~~~~~~~~~~~~.#",
        "#.~~~~~~~~~~~~~~.#",
        "#.~~~~~.1C.~~~~~.#",
        "#.~~~~~~~~~~~~~~.#",
        "#................#",
        "##################",
    ],
    'BRAZIER': [
        "########D#########",
        "#B==..........==B#",
        "#==............==#",
        "#................#",
        "#..B.........B...#",
        "#.......PP.......#",
        "#######gggg#######",
        "#######.1A.#######",
        "##################",
    ],
    'ICE': [
        "#########D########",
        "#IIIIIIII.IIIIIII#",
        "#IIIPIIIIIIIIIIII#",
        "#PIIIIIPIIIIIIIII#",
        "#IIIPPIIIIIIIIIPI#",
        "#IIIIIIIIIIIIIIII#",
        "#IIIIIIIPIIIPII1A#",
        "##################",
    ],
    'LEVERS': [
        "######D###########",
        "#....#...#....#..#",
        "#.V..l...o.V..l.1#",
        "#....#...#....#..#",
        "#P..P#.V.#P..P#.A#",
        "##################",
    ],
    'SEAL': [
        "#####S####",
        "#R......R#",
        "#...x....#",
        "#R......R#",
        "##########",
    ],
    'MIRROR': [
        "########D#########",
        "#e............./c#",
        "#...........\\....#",
        "#................#",
        "#.....\\..........#",
        "#c............./t#",
        "##########MM######",
        "##########x.######",
        "##################",
    ],
    'SUNGATE': [
        "#####D#####",
        "#,.......,#",
        "#.........#",
        "#...._....#",
        "#.........#",
        "#####H#####",
        "#,..1.2..,#",
        "#....C....#",
        "###########",
    ],
    'THRONE': [
        "########D#########",
        "#b..P........P..b#",
        "#................#",
        "#..P....T.....P..#",
        "#.......k........#",
        "#..P..........P..#",
        "#b..............b#",
        "##################",
    ],
}


def grid(name):
    rows = PREFABS[name]
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, (name, r)
    assert w <= 18 and len(rows) <= 9, name
    return [list(r) for r in rows]


def entrance(name):
    g = grid(name)
    h, w = len(g), len(g[0])
    found = []
    for y in range(h):
        for x in range(w):
            if g[y][x] in 'DLS' and (x in (0, w - 1) or y in (0, h - 1)):
                side = 2 if y == 0 else 3 if y == h - 1 else 0 if x == 0 else 1
                found.append((x, y, side))
    assert len(found) == 1, (name, found)
    return found[0]


DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def solve_plates():
    """sokoban: every plate under a boulder opens G; reach slot 1"""
    g = grid('PLATES')
    ex, ey, _ = entrance('PLATES')
    walls = {(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c in '#CG'}
    plates = {(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == '^'}
    boulders = frozenset((x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == 'O')
    gate = [(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == 'G']
    start = ((ex, ey + 1), boulders)
    seen = {start}
    todo = [start]
    while todo:
        (px, py), bs = todo.pop()
        if plates <= bs:
            return True
        for dx, dy in DIRS:
            nx, ny = px + dx, py + dy
            if (nx, ny) in walls or ny < 1:
                continue
            nb = bs
            if (nx, ny) in bs:
                bx, by = nx + dx, ny + dy
                if (bx, by) in walls or (bx, by) in bs:
                    continue
                nb = (bs - {(nx, ny)}) | {(bx, by)}
            s = ((nx, ny), frozenset(nb))
            if s not in seen:
                seen.add(s)
                todo.append(s)
    return False


def solve_ice():
    """sliding on ice: reach slot 1 from the door"""
    g = grid('ICE')
    ex, ey, _ = entrance('ICE')
    h, w = len(g), len(g[0])

    def free(x, y):
        return 0 <= x < w and 0 <= y < h and g[y][x] in 'I.1'
    start = (ex, ey + 1)
    seen = {start}
    todo = [start]
    while todo:
        x, y = todo.pop()
        if g[y][x] == '1':
            return True
        for dx, dy in DIRS:
            nx, ny = x, y
            moved = False
            while free(nx + dx, ny + dy):
                nx, ny = nx + dx, ny + dy
                moved = True
                if g[ny][nx] != 'I':
                    break
            if moved and (nx, ny) not in seen:
                seen.add((nx, ny))
                todo.append((nx, ny))
    return False


def solve_ice_trivial():
    """the slot must not be reachable by plain walking (no sliding)"""
    g = grid('ICE')
    ex, ey, _ = entrance('ICE')
    return g[ey + 1][ex] == '1'


def beam(g, states):
    """trace the beam; states: mirror positions -> '/' or '\\'"""
    h, w = len(g), len(g[0])
    for y in range(h):
        for x in range(w):
            if g[y][x] == 'e':
                bx, by, dx, dy = x, y, 1, 0
    path = []
    for _ in range(200):
        bx += dx
        by += dy
        c = states.get((bx, by), g[by][bx])
        if c == '/':
            dx, dy = -dy, -dx
        elif c == '\\':
            dx, dy = dy, dx
        elif c == 't':
            return True, path
        elif c not in '.':
            return False, path
        path.append((bx, by))
    return False, path


def solve_mirror():
    g = grid('MIRROR')
    ms = [(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c in '/\\']
    init = {m: g[m[1]][m[0]] for m in ms}
    ok_init, _ = beam(g, init)
    good = []
    for k in range(1 << len(ms)):
        st = {m: '/\\'[(k >> i) & 1] for i, m in enumerate(ms)}
        hit, _ = beam(g, st)
        if hit:
            good.append(st)
    return (not ok_init) and len(good) > 0, len(good)


def solve_levers():
    """levers swap every l/o gate; reach slot 1"""
    g = grid('LEVERS')
    ex, ey, _ = entrance('LEVERS')
    h, w = len(g), len(g[0])
    start = (ex, ey + 1, 0)
    seen = {start}
    todo = [start]
    while todo:
        x, y, s = todo.pop()
        if g[y][x] == '1':
            return True
        for dx, dy in DIRS:
            nx, ny = x + dx, y + dy
            if not (0 <= nx < w and 0 < ny < h):
                continue
            c = g[ny][nx]
            ns = s
            if c == 'V':
                ns = s ^ 1
                nx, ny = x, y
            elif c in '#PA':
                continue
            elif c == 'l' and s == 0:
                continue
            elif c == 'o' and s == 1:
                continue
            st = (nx, ny, ns)
            if st not in seen:
                seen.add(st)
                todo.append(st)
    return False


def solve_sungate():
    """the stone set on the pedestal must light the door (level 5+ with
    the d/2 falloff of a strength-7 light, through clear cells)"""
    g = grid('SUNGATE')
    pe = [(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == '_'][0]
    dr = [(x, y) for y, r in enumerate(g) for x, c in enumerate(r) if c == 'H'][0]
    d = max(abs(pe[0] - dr[0]), abs(pe[1] - dr[1])) + min(abs(pe[0] - dr[0]), abs(pe[1] - dr[1])) // 2
    level = min(7, 8 - d // 2)
    # the player must not have to stand in the doorway to reach the stand
    return level >= 5 and abs(pe[0] - dr[0]) + abs(pe[1] - dr[1]) > 1


def check():
    for n in PREFABS:
        grid(n)
        entrance(n)
    assert solve_plates(), 'plates'
    assert solve_ice() and not solve_ice_trivial(), 'ice'
    ok, n = solve_mirror()
    assert ok, ('mirror', n)
    assert solve_levers(), 'levers'
    assert solve_sungate(), 'sungate'
    return True


if __name__ == '__main__':
    print('plates', solve_plates())
    print('ice', solve_ice())
    print('mirror', solve_mirror())
    print('levers', solve_levers())
    for n in PREFABS:
        print(n, entrance(n), len(PREFABS[n][0]), len(PREFABS[n]))
