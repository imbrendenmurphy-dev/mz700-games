"""levels.py - generates Rotoball's levels.

Each level is a maze of 3-cell-wide corridors (pitch 4) with caverns knocked
through, plus objects placed in maze cells. Output is assembler data:

    LEVELTAB: dw level pointers
    level:    db wbytes, rows, startx, starty
              db packed wall bits (MSB = leftmost, 1 = wall), wbytes*rows
              db type, x, y, axis, speed   per object
              db 0
"""
import random
from collections import deque

CELL = 4
T_GEM, T_EXIT, T_MINE, T_CRAWLER, T_BOMB, T_SHIELD = 1, 2, 3, 4, 5, 6

# (maze cells w, h, seed, gems, mines, crawlers, bombs, shields, extra openings, crawler speed)
LEVELS = [
    (6, 5, 11, 4, 0, 0, 0, 0, 4, 14),
    (7, 6, 23, 5, 2, 1, 1, 0, 6, 14),
    (8, 7, 37, 6, 3, 2, 0, 1, 8, 16),
    (10, 8, 41, 7, 4, 3, 1, 0, 10, 16),
    (12, 10, 53, 8, 6, 4, 1, 1, 14, 18),
    (14, 12, 67, 10, 8, 6, 2, 0, 18, 18),
    (16, 13, 71, 10, 9, 7, 2, 1, 22, 20),
    (16, 14, 89, 12, 10, 9, 2, 2, 26, 22),
]


def make_level(cw, ch, seed, n_gem, n_mine, n_crawl, n_bomb, n_shield, n_open, speed):
    rnd = random.Random(seed)
    W, H = cw * CELL + 1, ch * CELL + 1
    wall = [[1] * W for _ in range(H)]
    links = {(x, y): set() for x in range(cw) for y in range(ch)}

    def carve_cell(cx, cy):
        for y in range(cy * CELL + 1, cy * CELL + CELL):
            for x in range(cx * CELL + 1, cx * CELL + CELL):
                wall[y][x] = 0

    def carve_between(a, b):
        (ax, ay), (bx, by) = a, b
        links[a].add(b)
        links[b].add(a)
        if ax == bx:
            y = max(ay, by) * CELL
            for x in range(ax * CELL + 1, ax * CELL + CELL):
                wall[y][x] = 0
        else:
            x = max(ax, bx) * CELL
            for y in range(ay * CELL + 1, ay * CELL + CELL):
                wall[y][x] = 0

    seen = {(0, 0)}
    stack = [(0, 0)]
    carve_cell(0, 0)
    while stack:
        x, y = stack[-1]
        nb = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= x + dx < cw and 0 <= y + dy < ch and (x + dx, y + dy) not in seen]
        if not nb:
            stack.pop()
            continue
        n = rnd.choice(nb)
        seen.add(n)
        carve_cell(*n)
        carve_between((x, y), n)
        stack.append(n)
    for _ in range(n_open):
        x, y = rnd.randrange(cw), rnd.randrange(ch)
        n = rnd.choice([(x + 1, y), (x, y + 1)])
        if n[0] < cw and n[1] < ch:
            carve_between((x, y), n)

    # distances from the start cell: exit goes in the farthest one
    dist = {(0, 0): 0}
    q = deque([(0, 0)])
    while q:
        c = q.popleft()
        for n in links[c]:
            if n not in dist:
                dist[n] = dist[c] + 1
                q.append(n)
    exit_cell = max(dist, key=lambda c: (dist[c], c))
    free = [c for c in dist if c != exit_cell and dist[c] >= 1]
    rnd.shuffle(free)
    near_start = {c for c in dist if dist[c] <= 1}

    objs = []

    def centre(c):
        return c[0] * CELL + 2, c[1] * CELL + 2

    ex, ey = centre(exit_cell)
    objs.append((T_EXIT, ex, ey, 0, 0))
    used = set()

    def take(avoid_start):
        for c in free:
            if c in used or (avoid_start and c in near_start):
                continue
            used.add(c)
            return c
        return None

    for _ in range(n_gem):
        c = take(False)
        if c:
            objs.append((T_GEM,) + centre(c) + (0, 0))
    for _ in range(n_crawl):
        c = take(True)
        if c:
            # patrol along the corridor's main direction
            horiz = any(n[1] == c[1] for n in links[c])
            vert = any(n[0] == c[0] for n in links[c])
            axis = 0 if horiz and (not vert or rnd.random() < 0.5) else 1
            sp = speed if rnd.random() < 0.5 else -speed
            objs.append((T_CRAWLER,) + centre(c) + (axis, sp & 0xFF))
    for _ in range(n_mine):
        c = take(True)
        if c:
            ox, oy = rnd.choice(((1, 1), (3, 1), (1, 3), (3, 3)))
            objs.append((T_MINE, c[0] * CELL + ox, c[1] * CELL + oy, 0, 0))
    for _ in range(n_bomb):
        c = take(False)
        if c:
            objs.append((T_BOMB,) + centre(c) + (0, 0))
    for _ in range(n_shield):
        c = take(False)
        if c:
            objs.append((T_SHIELD,) + centre(c) + (0, 0))

    wbytes = (W + 7) // 8
    bits = []
    for row in wall:
        row = row + [1] * (wbytes * 8 - W)
        for b in range(wbytes):
            v = 0
            for i in range(8):
                v = (v << 1) | row[b * 8 + i]
            bits.append(v)
    sx, sy = centre((0, 0))
    return wbytes, H, sx, sy, bits, objs, wall


def asm():
    out = ['NUM_LEVELS = %d' % len(LEVELS), 'LEVELTAB:']
    out.append('    dw ' + ','.join('level%d' % i for i in range(len(LEVELS))))
    total = 0
    for i, p in enumerate(LEVELS):
        wb, h, sx, sy, bits, objs, _ = make_level(*p)
        assert len(objs) <= 48
        out.append('level%d:' % i)
        out.append('    db %d,%d,%d,%d' % (wb, h, sx, sy))
        for k in range(0, len(bits), 16):
            out.append('    db ' + ','.join(str(v) for v in bits[k:k + 16]))
        for o in objs:
            out.append('    db %d,%d,%d,%d,%d' % o)
        out.append('    db 0')
        total += 4 + len(bits) + 5 * len(objs) + 1
    return '\n'.join(out) + '\n', total


if __name__ == '__main__':
    for i, p in enumerate(LEVELS):
        wb, h, sx, sy, bits, objs, wall = make_level(*p)
        grid = [['#' if c else '.' for c in r] for r in wall]
        sym = {T_GEM: 'g', T_EXIT: 'E', T_MINE: 'm', T_CRAWLER: 'c', T_BOMB: 'B', T_SHIELD: 'S'}
        for o in objs:
            grid[o[2]][o[1]] = sym[o[0]]
        grid[sy][sx] = '@'
        print('level', i + 1)
        print('\n'.join(''.join(r) for r in grid))
    print('bytes:', asm()[1])
