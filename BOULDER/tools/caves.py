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
         'DEX1', 'DEX2', 'DEX3', 'DEX4', 'COVER']
E = {n: i for i, n in enumerate(ELEMS)}
assert len(ELEMS) == 32

# ---------------------------------------------------------------- packed (4-bit) cave codes
PACK = ['SPACE', 'DIRT', 'BRICK', 'MAGIC', 'STEEL', 'EXIT', 'BOULDER', 'DIAMOND',
        'FIRE0', 'BUTT3', 'AMOEBA', 'EXPWALL', 'INBOX']
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
    'COVER': same(COVER_C),
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
    'LK_STEEL': same(STEEL_C), 'LK_EXITO': EXITO,
}


# ---------------------------------------------------------------- cave drawing
class Cave:
    def __init__(self, letter, name, hint, need, dval, xval, time, seed, fill,
                 magic=0, amoeba=0, speed=6, intermission=False):
        self.letter, self.name, self.hint = letter, name, hint
        self.need, self.dval, self.xval, self.time = need, dval, xval, time
        self.magic, self.amoeba, self.speed = magic, amoeba, speed
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
                if self.g[yy][xx] in ('BOULDER', 'DIAMOND', 'FIRE0', 'BUTT3', 'AMOEBA') and 0 < yy < H - 1:
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
        gems += 9 * sum(1 for (x, y) in seen if self.g[y][x] == 'BUTT3')
        rocks = sum(1 for (x, y) in seen if self.g[y][x] == 'BOULDER')
        return gems, any(self.g[y][x] == 'EXIT' for (x, y) in seen), rocks, seen

    def check(self):
        assert self.count('INBOX') == 1, self.letter
        assert self.count('EXIT') == 1, self.letter
        avail = self.count('DIAMOND') + 9 * self.count('BUTT3')
        if self.count('MAGIC'):
            avail += self.count('BOULDER') // 3
        if self.count('AMOEBA'):
            avail += 20
        assert avail >= self.need * 1.15, (self.letter, avail, self.need)
        return avail


def caves():
    C = []

    # A - gentle introduction: walls with gaps, scattered treasure
    c = Cave('A', 'FIRST DIG', 'DIG FOR DIAMONDS - MIND THE ROCKS', 12, 10, 15, 150, 101,
             [('DIRT', 66), ('BOULDER', 12), ('DIAMOND', 6), ('SPACE', 16)])
    for y, gaps in ((6, (8, 25)), (11, (15, 33)), (16, (5, 22))):
        c.line('BRICK', 1, y, 38, y)
        for gx in gaps:
            c.line('DIRT', gx, y, gx + 2, y)
    c.start(3, 3).exit(37, 19)
    C.append(c)

    # B - fireflies circling brick blocks; drop rocks on them to blast in
    c = Cave('B', 'FIREFLY RINGS', 'BOULDERS CAN CRUSH FIREFLIES', 16, 12, 20, 150, 202,
             [('DIRT', 72), ('BOULDER', 15), ('DIAMOND', 5), ('SPACE', 8)])
    for bx, by in ((6, 4), (17, 4), (28, 4), (6, 13), (17, 13), (28, 13)):
        c.rect('SPACE', bx, by, bx + 6, by + 4)
        c.rect('BRICK', bx + 1, by + 1, bx + 5, by + 3)
        c.box('DIAMOND', bx + 2, by + 2, bx + 4, by + 2)
        c.put('FIRE0', bx + 3, by + 4)
        c.line('BOULDER', bx + 1, by - 1, bx + 5, by - 1, 2)
    c.start(2, 10).exit(37, 10)
    C.append(c)

    # C - butterflies in pens: crush them for nine diamonds each
    c = Cave('C', 'BUTTERFLY PENS', 'A CRUSHED BUTTERFLY MAKES DIAMONDS', 20, 15, 25, 160, 303,
             [('DIRT', 76), ('BOULDER', 9), ('DIAMOND', 5), ('SPACE', 10)])
    for bx in (3, 12, 21, 30):
        for by in (5, 14):
            # a pen with a slot in its roof; two stacks of rocks stand on
            # earth above the slot - dig the earth away from the side
            c.box('SPACE', bx, by, bx + 5, by + 3)
            c.rect('BRICK', bx - 1, by - 1, bx + 6, by + 4)
            c.line('SPACE', bx + 2, by - 1, bx + 3, by - 1)
            c.line('DIRT', bx, by - 2, bx + 5, by - 2)
            c.box('BOULDER', bx + 2, by - 4, bx + 3, by - 3)
            c.put('BUTT3', bx + 1, by + 2)
    c.start(20, 10).exit(38, 20)
    C.append(c)

    # D - the amoeba spreads; diamonds are plenty, but hurry
    c = Cave('D', 'GREEN TIDE', 'THE AMOEBA SPREADS - BE QUICK', 20, 10, 20, 140, 404,
             [('DIRT', 70), ('BOULDER', 12), ('DIAMOND', 8), ('SPACE', 10)], amoeba=40)
    c.box('SPACE', 17, 9, 22, 12)
    c.put('AMOEBA', 19, 10).put('AMOEBA', 20, 11)
    c.line('BRICK', 10, 5, 29, 5).line('BRICK', 10, 16, 29, 16)
    c.start(2, 2).exit(37, 19)
    C.append(c)

    # E - magic wall turns falling boulders into diamonds
    c = Cave('E', 'MAGIC WALL', 'ROCKS FALLING THROUGH MAGIC TURN TO GEMS', 30, 5, 10, 150, 505,
             [('DIRT', 60), ('BOULDER', 28), ('DIAMOND', 3), ('SPACE', 9)], magic=30)
    # a magic wall across the middle, earth passages down at either end;
    # rocks dug loose above fall through into the hall below as diamonds
    c.line('MAGIC', 5, 11, 34, 11)
    c.line('BRICK', 4, 3, 4, 11).line('BRICK', 35, 3, 35, 11)
    c.box('DIRT', 1, 10, 3, 12).box('DIRT', 36, 10, 38, 12)
    c.box('SPACE', 5, 12, 34, 13)
    c.box('DIRT', 5, 14, 34, 20)
    c.scatter('DIAMOND', 6, 1, 14, 38, 20)
    c.start(19, 2).exit(37, 20)
    C.append(c)

    # F - rubble pyramids hiding diamonds
    c = Cave('F', 'ROCKY HILLS', 'DIG UNDER THE HILLS WITH CARE', 25, 10, 20, 150, 606,
             [('DIRT', 80), ('BOULDER', 6), ('DIAMOND', 6), ('SPACE', 8)])
    for px in (6, 16, 26):
        for k in range(6):
            c.line('BOULDER', px - k, 4 + k, px + k, 4 + k)
        c.line('DIAMOND', px - 3, 11, px + 3, 11)
        c.line('BRICK', px - 6, 12, px + 6, 12)
    c.line('BRICK', 1, 17, 30, 17)
    c.scatter('DIAMOND', 6, 1, 13, 38, 20)
    c.start(36, 2).exit(1, 20)
    C.append(c)

    # G - winding corridors patrolled by fireflies
    c = Cave('G', 'SNAKE TUNNELS', 'FIREFLIES PATROL THE TUNNELS', 22, 15, 25, 160, 707,
             [('DIRT', 76), ('BOULDER', 12), ('DIAMOND', 6), ('SPACE', 6)])
    for i, y in enumerate((4, 8, 12, 16)):
        c.line('BRICK', 1, y, 38, y)
        gap = 35 if i % 2 == 0 else 2
        c.line('SPACE', gap, y, gap + 2, y)
        c.line('SPACE', 2, y + 1, 37, y + 1)
        c.put('FIRE0', 10 + i * 6, y + 1)
    c.start(2, 2).exit(37, 20)
    C.append(c)

    # H - expanding walls seal you in if you are careless
    c = Cave('H', 'CREEPING WALLS', 'WALLS GROW INTO EMPTY SPACE', 20, 15, 30, 150, 808,
             [('DIRT', 74), ('BOULDER', 12), ('DIAMOND', 7), ('SPACE', 7)])
    for y in (5, 10, 15):
        c.line('EXPWALL', 10, y, 29, y)
        c.put('SPACE', 9, y).put('SPACE', 30, y)
    c.line('BRICK', 19, 1, 19, 4)
    c.start(2, 2).exit(37, 20)
    C.append(c)

    # I - shafts of diamonds capped by boulders
    c = Cave('I', 'DIAMOND SHAFTS', 'OPEN A SHAFT FROM THE SIDE', 30, 10, 15, 160, 909,
             [('DIRT', 78), ('BOULDER', 10), ('DIAMOND', 2), ('SPACE', 10)])
    for sx in range(4, 37, 5):
        c.line('BRICK', sx - 1, 6, sx - 1, 18).line('BRICK', sx + 1, 6, sx + 1, 18)
        c.line('DIAMOND', sx, 9, sx, 17).line('BOULDER', sx, 6, sx, 8)
        c.put('DIRT', sx, 18)
    c.start(2, 2).exit(37, 2)
    C.append(c)

    # J - butterflies loose near the amoeba
    c = Cave('J', 'BUTTERFLY GARDEN', 'BUTTERFLIES BURST ON THE AMOEBA', 40, 10, 15, 180, 1010,
             [('DIRT', 72), ('BOULDER', 10), ('DIAMOND', 4), ('SPACE', 14)], amoeba=60)
    c.box('SPACE', 4, 4, 35, 6)
    c.box('SPACE', 4, 15, 35, 17)
    for x in (8, 16, 24, 32):
        c.put('BUTT3', x, 5).put('BUTT3', x - 4, 16)
    c.put('AMOEBA', 20, 11)
    c.start(2, 11).exit(37, 11)
    C.append(c)

    # K - a deep mine packed with rock
    c = Cave('K', 'DEEP MINE', 'LOOSE ROCK EVERYWHERE - TREAD LIGHTLY', 30, 15, 25, 140, 1111,
             [('DIRT', 58), ('BOULDER', 26), ('DIAMOND', 9), ('SPACE', 7)], speed=5)
    for x in (10, 20, 30):
        c.line('BRICK', x, 3, x, 18)
        c.put('DIRT', x, 10)
    c.start(2, 20).exit(37, 1)
    C.append(c)

    # L - two vaults, one magic wall
    c = Cave('L', 'TWIN VAULTS', 'FEED THE MAGIC TO OPEN THE VAULTS', 35, 10, 20, 170, 1212,
             [('DIRT', 64), ('BOULDER', 22), ('DIAMOND', 4), ('SPACE', 10)], magic=40)
    c.rect('STEEL', 3, 13, 16, 20).box('DIAMOND', 4, 18, 15, 19).box('SPACE', 4, 14, 15, 17)
    c.rect('STEEL', 23, 13, 36, 20).box('DIAMOND', 24, 18, 35, 19).box('SPACE', 24, 14, 35, 17)
    c.line('MAGIC', 6, 13, 13, 13).line('MAGIC', 26, 13, 33, 13)
    c.put('BRICK', 9, 20).put('BRICK', 30, 20)
    c.put('DIRT', 3, 18).put('DIRT', 36, 18)
    c.start(19, 2).exit(19, 20)
    C.append(c)

    # M - steel pillars, fireflies in the open
    c = Cave('M', 'STEEL FOREST', 'FIREFLIES ROAM AMONG THE PILLARS', 30, 12, 20, 160, 1313,
             [('DIRT', 66), ('BOULDER', 14), ('DIAMOND', 8), ('SPACE', 12)])
    for y in range(4, 19, 5):
        for x in range(5, 36, 6):
            c.box('STEEL', x, y, x + 1, y + 1)
    c.box('SPACE', 14, 8, 25, 13)
    c.put('FIRE0', 15, 8).put('FIRE0', 24, 13).put('FIRE0', 19, 10)
    c.start(2, 2).exit(37, 20)
    C.append(c)

    # N - rings of fireflies and butterflies side by side
    c = Cave('N', 'CROSSFIRE', 'TELL FIREFLY FROM BUTTERFLY', 45, 10, 20, 180, 1414,
             [('DIRT', 72), ('BOULDER', 16), ('DIAMOND', 4), ('SPACE', 8)])
    for i, bx in enumerate((3, 12, 21, 30)):
        for j, by in enumerate((3, 12)):
            c.rect('SPACE', bx, by, bx + 6, by + 5)
            c.box('BRICK', bx + 2, by + 2, bx + 4, by + 3)
            c.put('BUTT3' if (i + j) % 2 == 0 else 'FIRE0', bx, by + 2)
            c.line('BOULDER', bx, by - 1, bx + 6, by - 1, 3)
    c.start(10, 10).exit(29, 10)
    C.append(c)

    # O - the slow amoeba under a sky of rock
    c = Cave('O', 'SLOW GROWTH', 'TRAP THE AMOEBA AND IT TURNS TO GEMS', 24, 15, 25, 200, 1515,
             [('DIRT', 66), ('BOULDER', 20), ('DIAMOND', 4), ('SPACE', 10)], amoeba=120)
    c.rect('BRICK', 14, 8, 25, 15)
    c.box('DIRT', 15, 9, 24, 14)
    c.put('DIRT', 19, 8).put('DIRT', 20, 8)
    c.put('AMOEBA', 19, 11)
    c.start(2, 2).exit(37, 20)
    C.append(c)

    # P - finale: a bit of everything
    c = Cave('P', 'THE CORE', 'THE HEART OF THE MOUNTAIN', 50, 20, 30, 200, 1616,
             [('DIRT', 62), ('BOULDER', 20), ('DIAMOND', 8), ('SPACE', 10)], magic=30, amoeba=80, speed=5)
    c.line('MAGIC', 2, 8, 12, 8)
    c.rect('SPACE', 26, 3, 36, 8).box('BRICK', 27, 4, 35, 7).put('FIRE0', 26, 5)
    c.rect('SPACE', 26, 13, 36, 18).box('BRICK', 27, 14, 35, 17).put('BUTT3', 26, 15).put('BUTT3', 36, 16)
    c.line('EXPWALL', 3, 14, 20, 14).put('SPACE', 2, 14)
    c.put('AMOEBA', 10, 19)
    c.start(19, 10).exit(1, 1)
    C.append(c)

    for c in C:
        c.border()
    # caves that set the exit into the border
    return C


def pack(c):
    """38 x 20 interior, two cells per byte (high nibble first)"""
    vals = [PACKIDX[c.g[y][x]] for y in range(1, H - 1) for x in range(1, W - 1)]
    out = []
    for i in range(0, len(vals), 2):
        out.append((vals[i] << 4) | vals[i + 1])
    return out
