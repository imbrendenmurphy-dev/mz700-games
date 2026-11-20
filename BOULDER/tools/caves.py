"""caves.py - element codes, tile looks and the 16 caves of ROCKFALL.

Every cave is 40 x 22 cells with a steel border, drawn by a seeded random
fill plus drawing operations (lines, boxes, points), the way the classic
cave games did it.  The build packs the 38 x 20 interior as 4-bit codes.
"""
import random

W, H = 40, 22

# ---------------------------------------------------------------- run-time element codes (5 bits)
ELEMS = ['SPACE', 'DIRT', 'BRICK', 'MAGIC', 'STEEL', 'EXIT', 'EXITO', 'BOULDER', 'BOULDERF',
         'DIAMOND', 'DIAMONDF', 'FIRE0', 'FIRE1', 'FIRE2', 'FIRE3', 'BUTT0', 'BUTT1', 'BUTT2',
         'BUTT3', 'AMOEBA', 'PLAYER', 'EXPWALL', 'INBOX', 'EXP1', 'EXP2', 'EXP3', 'EXP4',
         'DEX1', 'DEX2', 'DEX3', 'DEX4', 'SHOWER']
E = {n: i for i, n in enumerate(ELEMS)}
assert len(ELEMS) == 32

# ---------------------------------------------------------------- packed (4-bit) cave codes
PACK = ['SPACE', 'DIRT', 'BRICK', 'MAGIC', 'STEEL', 'EXIT', 'BOULDER', 'DIAMOND',
        'FIRE0', 'BUTT3', 'AMOEBA', 'EXPWALL', 'INBOX', 'SHOWER', 'BUTT0']
PACKIDX = {n: i for i, n in enumerate(PACK)}

# ---------------------------------------------------------------- looks
BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)


def cell(g, fg, bg=BLACK):
    """(display char, attribute) - glyphs >= 100h come from the second bank"""
    return (g & 0xFF, ((g >> 8) << 7) | (fg << 4) | bg)


def same(c):
    return [c] * 8


SPACE_C = cell(0x00, WHITE, BLACK)
DIRT_C = cell(0xD0, RED, BLACK)
BRICK_C = cell(0x1F6, RED, WHITE)
STEEL_C = cell(0x18A, CYAN, BLUE)
BOULDER_C = cell(0x14F, WHITE)
DIAM = [cell(0x44, c) for c in (CYAN, CYAN, WHITE, YELLOW, CYAN, CYAN, MAGENTA, WHITE)]
DIAM[2] = cell(0x6B, WHITE)          # sparkle
FIRE = [cell(0x1B1 if i % 2 == 0 else 0x1B2, YELLOW if i // 2 % 2 == 0 else RED) for i in range(8)]
BUTT = [cell(0xCB if i % 2 == 0 else 0xCC, MAGENTA if i // 2 % 2 == 0 else CYAN) for i in range(8)]
AMOEBA = [cell(0x19F if i % 4 < 2 else 0x1B3, GREEN) for i in range(8)]
EXITO = [cell(0x18B, WHITE, BLUE) if i % 2 == 0 else cell(0x18B, YELLOW, BLACK) for i in range(8)]
INBOX = [cell(0x18B, WHITE, BLUE) if i % 2 == 0 else STEEL_C for i in range(8)]
MAGIC_ON = [cell(0x1F6, c, BLACK) for c in (WHITE, CYAN, BLUE, MAGENTA, RED, YELLOW, GREEN, CYAN)]
EXP = [cell(0x6B, YELLOW, RED), cell(0x1B3, WHITE, RED), cell(0x1B3, YELLOW), cell(0x19F, RED)]
DEX = [cell(0x6B, WHITE, MAGENTA), cell(0x1B3, WHITE, MAGENTA), cell(0x1B3, CYAN), cell(0x44, WHITE, BLUE)]
COVER_C = cell(0x1B2, BLUE, BLACK)
PL_IDLE = cell(0x144, YELLOW)
PL_LEFT = [cell(0x143, YELLOW) if i % 2 == 0 else cell(0x144, YELLOW) for i in range(8)]
PL_RIGHT = [cell(0x145, YELLOW) if i % 2 == 0 else cell(0x144, YELLOW) for i in range(8)]
PL_TAP = [PL_IDLE] * 4 + [cell(0x144, WHITE)] * 4

LOOK = {
    'SPACE': same(SPACE_C), 'DIRT': same(DIRT_C), 'BRICK': same(BRICK_C), 'MAGIC': same(BRICK_C),
    'STEEL': same(STEEL_C), 'EXIT': same(STEEL_C), 'EXITO': EXITO, 'BOULDER': same(BOULDER_C),
    'BOULDERF': same(BOULDER_C), 'DIAMOND': DIAM, 'DIAMONDF': same(cell(0x44, CYAN)),
    'AMOEBA': AMOEBA, 'PLAYER': same(PL_IDLE), 'EXPWALL': same(BRICK_C), 'INBOX': INBOX,
    'SHOWER': [cell(0x1BC, c, BLUE) for c in (CYAN, CYAN, WHITE, WHITE, CYAN, CYAN, YELLOW, YELLOW)],
}
for d in range(4):
    LOOK['FIRE%d' % d] = FIRE
    LOOK['BUTT%d' % d] = BUTT
for i in range(4):
    LOOK['EXP%d' % (i + 1)] = same(EXP[i])
    LOOK['DEX%d' % (i + 1)] = same(DEX[i])

# extra looks patched in at run time
EXTRA = {
    'LK_MAGICON': MAGIC_ON, 'LK_BRICK': same(BRICK_C), 'LK_PLIDLE': same(PL_IDLE),
    'LK_PLLEFT': PL_LEFT, 'LK_PLRIGHT': PL_RIGHT, 'LK_PLTAP': PL_TAP,
    'LK_STEEL': same(STEEL_C), 'LK_EXITO': EXITO, 'LK_COVER': same(COVER_C),
}


# ---------------------------------------------------------------- cave drawing
class Cave:
    def __init__(self, letter, name, hint, need, dval, xval, time, seed, fill,
                 magic=0, amoeba=0, speed=6, intermission=False):
        self.letter, self.name, self.hint = letter, name, hint
        self.need, self.dval, self.xval, self.time = need, dval, xval, time
        self.magic, self.amoeba, self.speed = magic, amoeba, speed
        self.shrate, self.shhaz, self.shmax = 0, 0, 0
        self.g = [['DIRT'] * W for _ in range(H)]
        rnd = random.Random(seed)
        names = [n for n, _ in fill]
        weights = [w for _, w in fill]
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                self.g[y][x] = rnd.choices(names, weights)[0]
        self.rnd = rnd
        self.border()

    def border(self):
        for x in range(W):
            self.g[0][x] = self.g[H - 1][x] = 'STEEL'
        for y in range(H):
            self.g[y][0] = self.g[y][W - 1] = 'STEEL'

    def put(self, e, x, y):
        if 0 < x < W - 1 and 0 < y < H - 1:
            self.g[y][x] = e
        return self

    def line(self, e, x1, y1, x2, y2, step=1):
        n = max(abs(x2 - x1), abs(y2 - y1))
        dx = (x2 > x1) - (x2 < x1)
        dy = (y2 > y1) - (y2 < y1)
        for i in range(0, n + 1, step):
            self.put(e, x1 + dx * i, y1 + dy * i)
        return self

    def rect(self, e, x1, y1, x2, y2):
        self.line(e, x1, y1, x2, y1).line(e, x1, y2, x2, y2)
        self.line(e, x1, y1, x1, y2).line(e, x2, y1, x2, y2)
        return self

    def box(self, e, x1, y1, x2, y2):
        for y in range(y1, y2 + 1):
            self.line(e, x1, y, x2, y)
        return self

    def ellipse(self, e, cx, cy, rx, ry, ring=False):
        """filled ellipse, or just its rim (ring)"""
        def inside(x, y):
            return ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if not inside(x, y):
                    continue
                if ring and all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    continue
                self.put(e, x, y)
        return self

    LEGEND = {' ': 'SPACE', '.': 'DIRT', '#': 'BRICK', '%': 'STEEL', 'M': 'MAGIC', 'o': 'BOULDER',
              '*': 'DIAMOND', 'F': 'FIRE0', 'B': 'BUTT3', 'b': 'BUTT0', 'a': 'AMOEBA', '=': 'EXPWALL',
              'X': 'EXIT', 'P': 'INBOX', 'v': 'SHOWER'}

    def stamp(self, x, y, rows):
        """draw a little picture; '~' leaves a cell as it is"""
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch != '~':
                    self.put(self.LEGEND[ch], x + dx, y + dy)
        return self

    def pins(self, e, x1, y1, x2, y2, dx, dy):
        """staggered pegs: a row every dy, a peg every dx, odd rows shifted"""
        for k, y in enumerate(range(y1, y2 + 1, dy)):
            off = (dx // 2) if k % 2 else 0
            for x in range(x1 + off, x2 + 1, dx):
                self.put(e, x, y)
        return self

    def spouts(self, x1, x2, step, y=1):
        for x in range(x1, x2 + 1, step):
            self.put('SHOWER', x, y)
        return self

    def mixbox(self, x1, y1, x2, y2, fill):
        names = [n for n, _ in fill]
        weights = [w for _, w in fill]
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                self.put(self.rnd.choices(names, weights)[0], x, y)
        return self

    def shower(self, rate, hazard, count):
        self.shrate, self.shhaz, self.shmax = rate, hazard, count
        return self

    def scatter(self, e, n, x1=1, y1=1, x2=W - 2, y2=H - 2, onto=('DIRT',)):
        k = 0
        while k < n:
            x = self.rnd.randint(x1, x2)
            y = self.rnd.randint(y1, y2)
            if self.g[y][x] in onto:
                self.g[y][x] = e
                k += 1
        return self

    def start(self, x, y):
        # a safe pocket: no boulders right above the start
        for yy in range(y - 1, y + 2):
            for xx in range(x - 1, x + 2):
                if self.g[yy][xx] in ('BOULDER', 'DIAMOND', 'FIRE0', 'BUTT3', 'BUTT0', 'AMOEBA') and 0 < yy < H - 1:
                    self.g[yy][xx] = 'DIRT'
        self.put('INBOX', x, y)
        return self

    def exit(self, x, y):
        self.g[y][x] = 'EXIT'
        return self

    def count(self, e):
        return sum(row.count(e) for row in self.g)

    def reach(self):
        """flood fill from the inbox through everything a player can dig or
        push through; returns (reachable diamonds + 9 per reachable butterfly,
        exit reachable?, boulders reachable)"""
        walls = ('BRICK', 'STEEL', 'MAGIC', 'EXPWALL')
        sx, sy = next((x, y) for y in range(H) for x in range(W) if self.g[y][x] == 'INBOX')
        seen = {(sx, sy)}
        todo = [(sx, sy)]
        while todo:
            x, y = todo.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in seen and self.g[n[1]][n[0]] not in walls:
                    seen.add(n)
                    todo.append(n)
        gems = sum(1 for (x, y) in seen if self.g[y][x] == 'DIAMOND')
        gems += 9 * sum(1 for (x, y) in seen if self.g[y][x] in ('BUTT3', 'BUTT0'))
        rocks = sum(1 for (x, y) in seen if self.g[y][x] == 'BOULDER')
        return gems, any(self.g[y][x] == 'EXIT' for (x, y) in seen), rocks, seen

    def check(self):
        assert self.count('INBOX') == 1, self.letter
        assert self.count('EXIT') == 1, self.letter
        avail = self.count('DIAMOND') + 9 * (self.count('BUTT3') + self.count('BUTT0'))
        if self.count('MAGIC'):
            avail += self.count('BOULDER') // 2
        if self.count('AMOEBA'):
            avail += 20
        avail += self.shmax * (256 - self.shhaz) // 256
        if self.shmax and self.count('MAGIC'):
            avail += self.shmax * self.shhaz // 256
        if avail < self.need * 1.15:
            print('warning: cave %s may be short of gems (%d for %d)' % (self.letter, avail, self.need))
        return avail


def caves():
    """the 20 caves, in play order (designs in tools/cavelist.py)"""
    import cavelist
    cs = [f() for f in cavelist.CAVES]
    try:
        from solutions import SOLUTIONS             # clocks tuned by tools/tune.py
    except ImportError:
        SOLUTIONS = {}
    for c in cs:
        c.border()
        if c.letter in SOLUTIONS and not getattr(c, 'untuned', False):
            c.time = SOLUTIONS[c.letter]['time']
    return cs


def pack(c):
    """38 x 20 interior, two cells per byte (high nibble first)"""
    vals = [PACKIDX[c.g[y][x]] for y in range(1, H - 1) for x in range(1, W - 1)]
    out = []
    for i in range(0, len(vals), 2):
        out.append((vals[i] << 4) | vals[i + 1])
    return out
