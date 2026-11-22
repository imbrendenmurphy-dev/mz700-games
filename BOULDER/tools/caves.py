"""caves.py - element codes, tile looks and the cave drawing kit of UNDERMINED.

A cave is w x h cells (40 x 22, one screen, up to 64 x 32) with a steel
border, drawn by a seeded random fill plus drawing operations (lines,
boxes, points), the way the classic cave games did it.  In the game every
cave lives in a 64 x 32 map (row stride 64); the screen shows a 40 x 22
window that scrolls when the player nears its edge.  The build stores the
interior Huffman-coded.
"""
import random

W, H = 40, 22                 # one screen: the smallest cave
MW, MH = 64, 32               # the map in memory: the largest cave

# ---------------------------------------------------------------- run-time element codes (5 bits)
ELEMS = ['SPACE', 'DIRT', 'BRICK', 'MAGIC', 'STEEL', 'EXIT', 'EXITO', 'BOULDER', 'BOULDERF',
         'DIAMOND', 'DIAMONDF', 'FIRE0', 'FIRE1', 'FIRE2', 'FIRE3', 'BUTT0', 'BUTT1', 'BUTT2',
         'BUTT3', 'AMOEBA', 'PLAYER', 'EXPWALL', 'INBOX', 'EXP1', 'EXP2', 'EXP3', 'EXP4',
         'DEX1', 'DEX2', 'DEX3', 'DEX4', 'SHOWER',
         # 6-bit codes from 2.4 on
         'GEODE', 'LOCK', 'KEY', 'SLIME', 'SHADE']
E = {n: i for i, n in enumerate(ELEMS)}
assert len(ELEMS) <= 64
PHASES = 4                    # animation phases (ANIMIDX = phase << 6 | element)

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
    return [c] * PHASES


SPACE_C = cell(0x00, WHITE, BLACK)
FIRE = [cell(0x1B1 if i % 2 == 0 else 0x1B2, YELLOW if i < 2 else RED) for i in range(4)]
BUTT = [cell(0xCB if i % 2 == 0 else 0xCC, MAGENTA if i < 2 else CYAN) for i in range(4)]
EXP = [cell(0x6B, YELLOW, RED), cell(0x1B3, WHITE, RED), cell(0x1B3, YELLOW), cell(0x19F, RED)]
DEX = [cell(0x6B, WHITE, MAGENTA), cell(0x1B3, WHITE, MAGENTA), cell(0x1B3, CYAN), cell(0x44, WHITE, BLUE)]
PL_IDLE = cell(0x144, YELLOW)
PL_LEFT = [cell(0x143, YELLOW) if i % 2 == 0 else cell(0x144, YELLOW) for i in range(4)]
PL_RIGHT = [cell(0x145, YELLOW) if i % 2 == 0 else cell(0x144, YELLOW) for i in range(4)]
PL_TAP = [PL_IDLE] * 2 + [cell(0x144, WHITE)] * 2
GEODE_C = [cell(0x18E, MAGENTA), cell(0x18E, MAGENTA), cell(0x18E, WHITE), cell(0x18E, MAGENTA)]
KEY_C = [cell(0x1FE, YELLOW), cell(0x1FE, YELLOW), cell(0x1FE, WHITE), cell(0x1FE, YELLOW)]
LOCK_C = same(cell(0x1B9, YELLOW))
SLIME_C = [cell(0xD4, CYAN), cell(0xD3, CYAN), cell(0xD4, GREEN), cell(0xD3, GREEN)]
SHADE_C = [cell(0x136, WHITE), cell(0x139, WHITE), cell(0x136, CYAN), cell(0x139, CYAN)]

# ---------------------------------------------------------------- themes
# Every wing has its own rock type: earth, wall, steel frame, boulders,
# gems and amoeba change glyph and colour.  A theme is a whole look table
# that cave_load copies over ANIMIDX / LOOKIDX, so the renderer is unchanged.
# gem = (glyph, colour cycle of 8 phases, colour while falling)
THEMES = [
    dict(name='RED EARTH',                                       # I  The Shallows
         dirt=cell(0xD0, RED), brick=cell(0x1F6, RED, WHITE), steel=cell(0x18A, CYAN, BLUE),
         rock=cell(0x14F, WHITE), gem=(0x44, (CYAN, CYAN, WHITE, YELLOW, CYAN, CYAN, MAGENTA, WHITE), CYAN),
         amoeba=(GREEN, BLACK), cover=cell(0x1B2, BLUE)),
    dict(name='BLUE SLATE',                                      # II Firefly Deeps
         dirt=cell(0x1EF, BLUE), brick=cell(0x176, CYAN, BLUE), steel=cell(0x1B4, WHITE, BLUE),
         rock=cell(0x14F, WHITE), gem=(0x44, (GREEN, GREEN, WHITE, YELLOW, GREEN, GREEN, CYAN, WHITE), GREEN),
         amoeba=(GREEN, BLACK), cover=cell(0x1B2, CYAN, BLUE)),
    dict(name='AMETHYST',                                        # III Magic Halls
         dirt=cell(0xA6, MAGENTA), brick=cell(0x166, YELLOW, MAGENTA), steel=cell(0x18F, WHITE, MAGENTA),
         rock=cell(0x14F, CYAN), gem=(0x44, (YELLOW, YELLOW, WHITE, GREEN, YELLOW, YELLOW, CYAN, WHITE), YELLOW),
         amoeba=(GREEN, BLACK), cover=cell(0x1B2, MAGENTA)),
    dict(name='MOSS',                                            # IV Green Caverns
         dirt=cell(0x1EE, GREEN), brick=cell(0x1F6, YELLOW, RED), steel=cell(0x18A, YELLOW, GREEN),
         rock=cell(0x14F, WHITE), gem=(0x44, (RED, RED, WHITE, MAGENTA, RED, RED, YELLOW, WHITE), RED),
         amoeba=(YELLOW, GREEN), cover=cell(0x1B2, GREEN)),
    dict(name='MAGMA',                                           # V  The Core
         dirt=cell(0x1EF, YELLOW, RED), brick=cell(0x1F6, WHITE, BLACK), steel=cell(0x1FA, YELLOW, RED),
         rock=cell(0x14F, WHITE), gem=(0x44, (CYAN, CYAN, WHITE, WHITE, CYAN, CYAN, GREEN, WHITE), CYAN),
         amoeba=(GREEN, BLACK), cover=cell(0x1B2, RED)),
    dict(name='ICE',                                             # VI Crystal Vaults
         dirt=cell(0x1EE, CYAN), brick=cell(0x176, WHITE, CYAN), steel=cell(0x18F, CYAN, BLUE),
         rock=cell(0x14F, WHITE), gem=(0x44, (MAGENTA, MAGENTA, WHITE, YELLOW, MAGENTA, MAGENTA, WHITE, WHITE), MAGENTA),
         amoeba=(GREEN, BLACK), cover=cell(0x1B2, CYAN)),
    dict(name='BONE',                                            # VII The Haunted Deep
         dirt=cell(0x1EF, MAGENTA), brick=cell(0x166, WHITE, BLUE), steel=cell(0x1B4, MAGENTA, BLUE),
         rock=cell(0x14F, YELLOW), gem=(0x44, (GREEN, GREEN, WHITE, CYAN, GREEN, GREEN, YELLOW, WHITE), GREEN),
         amoeba=(GREEN, BLACK), cover=cell(0x1B2, MAGENTA)),
    dict(name='GOLD',                                            # the bonus caves
         dirt=cell(0x1EE, YELLOW), brick=cell(0x1F6, YELLOW, RED), steel=cell(0x18A, YELLOW, BLUE),
         rock=cell(0x14F, WHITE), gem=(0x44, (CYAN, CYAN, WHITE, MAGENTA, CYAN, CYAN, GREEN, WHITE), CYAN),
         amoeba=(GREEN, BLACK), cover=cell(0x1B2, YELLOW)),
]
BONUS_THEME = 7


def theme_looks(t):
    """(LOOK, EXTRA) for theme t: element looks, and the looks patched in at run time"""
    th = THEMES[t]
    steel, brick, rock = th['steel'], th['brick'], th['rock']
    sbg = steel[1] & 7
    glyph, cyc, fall = th['gem']
    cyc = cyc[0::2]
    diam = [cell(glyph, c) for c in cyc]
    diam[1] = cell(glyph, WHITE)                    # a glint (a star every fourth frame was too much)
    afg, abg = th['amoeba']
    amoeba = [cell(0x19F if i % 2 == 0 else 0x1B3, afg, abg) for i in range(4)]
    exito = [cell(0x18B, WHITE, BLUE) if i % 2 == 0 else cell(0x18B, YELLOW, BLACK) for i in range(4)]
    inbox = [cell(0x18B, WHITE, BLUE) if i % 2 == 0 else steel for i in range(4)]
    magic_on = [cell(0x1F6, c, BLACK) for c in (WHITE, CYAN, MAGENTA, YELLOW)]
    look = {
        'SPACE': same(SPACE_C), 'DIRT': same(th['dirt']), 'BRICK': same(brick), 'MAGIC': same(brick),
        'STEEL': same(steel), 'EXIT': same(steel), 'EXITO': exito, 'BOULDER': same(rock),
        'BOULDERF': same(rock), 'DIAMOND': diam, 'DIAMONDF': same(cell(glyph, fall)),
        'AMOEBA': amoeba, 'PLAYER': same(PL_IDLE), 'EXPWALL': same(brick), 'INBOX': inbox,
        'SHOWER': [cell(0x1BC, c, sbg if sbg != c else BLACK)
                   for c in (fall, WHITE, fall, YELLOW)],
        'GEODE': GEODE_C, 'KEY': KEY_C, 'LOCK': LOCK_C, 'SLIME': SLIME_C, 'SHADE': SHADE_C,
    }
    for d in range(4):
        look['FIRE%d' % d] = FIRE
        look['BUTT%d' % d] = BUTT
    for i in range(4):
        look['EXP%d' % (i + 1)] = same(EXP[i])
        look['DEX%d' % (i + 1)] = same(DEX[i])
    extra = {
        'LK_MAGICON': magic_on, 'LK_BRICK': same(brick), 'LK_PLIDLE': same(PL_IDLE),
        'LK_PLLEFT': PL_LEFT, 'LK_PLRIGHT': PL_RIGHT, 'LK_PLTAP': PL_TAP,
        'LK_STEEL': same(steel), 'LK_EXITO': exito, 'LK_COVER': same(th['cover']),
    }
    return look, extra


LOOK, EXTRA = theme_looks(0)


# ---------------------------------------------------------------- cave drawing
class Cave:
    def __init__(self, letter, name, hint, need, dval, xval, time, seed, fill,
                 magic=0, amoeba=0, speed=6, intermission=False, w=W, h=H, theme=None):
        assert W <= w <= MW and H <= h <= MH, (letter, w, h)
        self.letter, self.name, self.hint = letter, name, hint
        self.need, self.dval, self.xval, self.time = need, dval, xval, time
        self.magic, self.amoeba, self.speed = magic, amoeba, speed
        self.shrate, self.shhaz, self.shmax = 0, 0, 0
        self.w, self.h, self.theme = w, h, theme
        self.flags = 1 if intermission else 0       # bit 0: bonus cave (no life lost)
        # the cave's own random sequence: A-Z keep 0-25 (A-T as in 2.3), bonus caves 26+
        self.seed_ix = ord(letter) - 65 if 'A' <= letter <= 'Z' else 26 + ord(letter) - 49
        self.g = [['DIRT'] * w for _ in range(h)]
        rnd = random.Random(seed)
        names = [n for n, _ in fill]
        weights = [wt for _, wt in fill]
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                self.g[y][x] = rnd.choices(names, weights)[0]
        self.rnd = rnd
        self.border()

    def border(self):
        w, h = self.w, self.h
        for x in range(w):
            self.g[0][x] = self.g[h - 1][x] = 'STEEL'
        for y in range(h):
            self.g[y][0] = self.g[y][w - 1] = 'STEEL'

    def put(self, e, x, y):
        if 0 < x < self.w - 1 and 0 < y < self.h - 1:
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
              'X': 'EXIT', 'P': 'INBOX', 'v': 'SHOWER', 'g': 'GEODE', 'L': 'LOCK', 'k': 'KEY',
              's': 'SLIME', 'S': 'SHADE'}

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

    def scatter(self, e, n, x1=1, y1=1, x2=None, y2=None, onto=('DIRT',)):
        x2 = self.w - 2 if x2 is None else x2
        y2 = self.h - 2 if y2 is None else y2
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
                if self.g[yy][xx] in ('BOULDER', 'DIAMOND', 'FIRE0', 'BUTT3', 'BUTT0', 'AMOEBA') and 0 < yy < self.h - 1:
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
        sx, sy = next((x, y) for y in range(self.h) for x in range(self.w) if self.g[y][x] == 'INBOX')
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
        avail = self.count('DIAMOND') + 9 * (self.count('BUTT3') + self.count('BUTT0') + self.count('SHADE'))
        avail += self.count('GEODE')
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


def wing(letter):
    """0-6: A-D, E-H, I-L, M-P, Q-T, then U-W and X-Z"""
    k = ord(letter) - 65
    return k // 4 if k < 20 else 5 + (k - 20) // 3


def caves():
    """the 20 caves, in play order (designs in tools/cavelist.py)"""
    import cavelist
    cs = [f() for f in cavelist.CAVES]
    try:
        from solutions import SOLUTIONS             # clocks tuned by tools/tune.py
    except ImportError:
        SOLUTIONS = {}
    for i, c in enumerate(cs):
        if getattr(c, 'theme', None) is None:
            c.theme = wing(c.letter)                 # one rock type per wing
        c.border()
        if c.letter in SOLUTIONS and not getattr(c, 'untuned', False):
            c.time = SOLUTIONS[c.letter]['time']
    return cs


def pack(c):
    """the (w-2) x (h-2) interior, Huffman coded: [tree length] [tree]
    [bits].  Tree node k is 2 bytes at offset 2k (root first); a child is
    a node offset, or 80h + element code for a leaf.  Bits high first."""
    import heapq
    vals = [E[c.g[y][x]] for y in range(1, c.h - 1) for x in range(1, c.w - 1)]
    freq = {}
    for v in vals:
        freq[v] = freq.get(v, 0) + 1
    heap = [(n, k, ('leaf', v)) for k, (v, n) in enumerate(sorted(freq.items()))]
    heapq.heapify(heap)
    k = len(heap)
    if len(heap) == 1:
        n, _, leaf = heap[0]
        heap = [(n, 0, ('node', leaf, leaf))]
    while len(heap) > 1:
        n1, _, a = heapq.heappop(heap)
        n2, _, b = heapq.heappop(heap)
        heapq.heappush(heap, (n1 + n2, k, ('node', a, b)))
        k += 1
    root = heap[0][2]
    nodes, codes = [], {}

    def lay(t, prefix):
        """breadth of the tree into the node table; returns the child byte"""
        if t[0] == 'leaf':
            codes[t[1]] = prefix
            return 0x80 | t[1]
        i = len(nodes)
        nodes.append(None)
        nodes[i] = (lay(t[1], prefix + '0'), lay(t[2], prefix + '1'))
        return 2 * i

    lay(root, '')
    tree = [b for pair in nodes for b in pair]
    assert len(tree) < 128
    bits = ''.join(codes[v] for v in vals)
    bits += '0' * (-len(bits) % 8)
    data = [int(bits[i:i + 8], 2) for i in range(0, len(bits), 8)]
    return [len(tree)] + tree + data


def unpack(c, data):
    """decode pack() output the way the Z80 does (for the build's self-check)"""
    n = data[0]
    tree, bits = data[1:1 + n], data[1 + n:]
    out, node, pos = [], 0, 0
    total = (c.w - 2) * (c.h - 2)
    while len(out) < total:
        b = (bits[pos // 8] >> (7 - pos % 8)) & 1
        pos += 1
        v = tree[node + b]
        if v & 0x80:
            out.append(v & 0x3F)
            node = 0
        else:
            node = v
    return out
