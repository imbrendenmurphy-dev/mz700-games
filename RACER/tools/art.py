"""art.py - REDLINE's pictures.

Sprites are chunky colour pictures: one letter per cell across and per half
cell (sub-row) down, drawn into the road's half-block attribute picture.
  K black B blue R red M magenta G green C cyan Y yellow W white . clear
Each is scaled down at build time to SIZES (fractions of the master size,
which is how it looks at scale 256, closest to the camera).

The player's car is drawn with ROM characters (CAR_*): each cell is
  glyph letter + foreground + background ('t' = see-through: the road's
  colour under the cell).
"""
SIZES = [0.06, 0.1, 0.15, 0.21, 0.28, 0.37, 0.48, 0.62, 0.8, 0.98]

COL = {'K': 0, 'B': 1, 'R': 2, 'M': 3, 'G': 4, 'C': 5, 'Y': 6, 'W': 7}

SPRITES = {}

SPRITES['PALM'] = """
.GG....GG.
GGGG..GGGG
G.GGGGGG.G
..GGRRGG..
.GG.RR.GG.
G...RR...G
....RR....
.....RR...
.....RR...
.....RR...
.....RR...
....RR....
....RR....
....RR....
...RRR....
...RR.....
...RR.....
...RR.....
...RR.....
...RR.....
....RR....
....RR....
...RRRR...
"""

SPRITES['PINE'] = """
....BB....
....BB....
...BBBB...
...BCBB...
..BBBBBB..
....BB....
...BBBB...
..BBCBBB..
.BBBBBBBB.
...BBBB...
..BBBBCB..
.BBCBBBBB.
BBBBBBBBBB
BBBBBBBBBB
....RR....
....RR....
....RR....
....RR....
"""

SPRITES['SNOWPINE'] = """
....WW....
...WGGW...
...GGGG...
..WGGGGW..
..GGWGGG..
.WGGGGGGW.
...GGGG...
..WGGGWG..
.GGGGGGGG.
WGGWGGGGGW
GGGGGGGGGG
....RR....
....RR....
....RR....
"""

SPRITES['CACTUS'] = """
....GG....
...GGGG...
...GGGG...
G..GGGG...
G..GGGG..G
G..GGGG..G
GG.GGGG..G
.GGGGGG.GG
...GGGGGG.
...GGGG...
...GGGG...
...GGGG...
...GGGG...
...GGGG...
"""

SPRITES['ROCK'] = """
....MMMM....
..MMMMWMMM..
.MMMMMMMWMM.
MMMWMMMMMMMM
MMMMMMMMMMMM
MMMMMMMMMMMM
"""

SPRITES['BUTTE'] = """
..RRRRRRRR..
..RRYRRRRR..
..RRRRRRYR..
..RRRRRRRR..
.RRRRYRRRRR.
.RRRRRRRRRR.
.RRRRRRRRRR.
RRRRRRRRRRRR
RRRRRRRRRRRR
RRRRRRRRRRRR
"""

SPRITES['LAMP'] = """
WWWWW..
YYYYW..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
....W..
...WWW.
"""

SPRITES['TOWER'] = """
BBBBBBBB
BYBYBBYB
BBBBBBBB
BYBBYBYB
BBBBBBBB
BYBYBBBB
BBBBBBBB
BBYBYBYB
BBBBBBBB
BYBYBBYB
BBBBBBBB
BYBBYBYB
BBBBBBBB
BYBYBYBB
BBBBBBBB
BYBYBBYB
BBBBBBBB
BBBBBBBB
"""

SPRITES['TREE'] = """
...GGGG...
.GGGGGGGG.
GGGGYGGGGG
GGGGGGGYGG
GYGGGGGGGG
GGGGGGGGGG
.GGGGYGGG.
..GGGGGG..
....RR....
....RR....
....RR....
....RR....
"""

SPRITES['MILL'] = """
W.......W
.W.....W.
..W...W..
...WWW...
...WRW...
..W.W.W..
.W.WWW.W.
W..WWW..W
...WWW...
..WWWWW..
..WRRRW..
..WWWWW..
..WWBWW..
..WWBWW..
"""

SPRITES['UMBR'] = """
....RWRW....
..RWRWRWRW..
.RWRWRWRWRW.
RWRWRWRWRWRW
.....W......
.....W......
.....W......
.....W......
"""

SPRITES['BUSH'] = """
..GGGG..
.GGYGGG.
GGGGGGYG
GGGGGGGG
"""

SPRITES['SIGNL'] = """
YYYYYYYY
YKKYYYYY
KKYKKKKY
YKKYYYYY
YYYYYYYY
...WW...
...WW...
...WW...
...WW...
"""

SPRITES['SIGNR'] = """
YYYYYYYY
YYYYYKKY
YKKKKYKK
YYYYYKKY
YYYYYYYY
...WW...
...WW...
...WW...
...WW...
"""

SPRITES['POST'] = """
WWW
WRW
WWW
WRW
WWW
WRW
WWW
WRW
WWW
WRW
WWW
WRW
WWW
WRW
WWW
WRW
WWW
WRW
WWW
WRW
"""

# traffic, from behind (a body colour letter 'x' is replaced per variant)
CAR = """
...xxxxxx...
..xKKKKKKx..
.xxxxxxxxxx.
xRRxxWWxxRRx
xxxxxxxxxxxx
KKK......KKK
"""

TRUCK = """
.WWWWWWWWWW.
.WWWWWWWWWW.
.WKWWWWWWKW.
.WWWWWWWWWW.
.WWWWWWWWWW.
.WWWWWWWWWW.
.WWWWWWWWWW.
.RWWWWWWWWR.
.KKKKKKKKKK.
.KK......KK.
"""

CARVARS = {'CARB': 'B', 'CARY': 'Y', 'CARG': 'G', 'CARW': 'W', 'CARM': 'M', 'CARC': 'C'}
SPRITES['TRUCK'] = TRUCK
for k, c in CARVARS.items():
    SPRITES[k] = CAR.replace('x', c)

# sprite sizes in the world: the master is drawn at scale 256 - most are
# their natural size; traffic is fitted to the player's car
SCALE = {'TRUCK': 1.3}

# ---------------------------------------------------------------- the player's car
# 12 cells x 4 rows.  Glyphs: ' ' see-through, '#' full, '^' upper half,
# '_' lower half, '<' left half, '>' right half,
# '/' lower-right triangle, '\\' lower-left, 'L' upper-left, 'J' upper-right
GLYPH = {'#': 0x43, '^': 0x7A, '_': 0x3A, '<': 0x7B, '>': 0x3B,
         '/': 0x4E, 'd': 0x4D, '\\': 0x4D, 'L': 0x56, 'J': 0x42, '=': 0x3E, '-': 0x7E}

# each row: glyphs, foregrounds, backgrounds (t = see-through)
CAR_STRAIGHT = [
    ('  /______d  ', 'RRRRRRRRRRRR', 'tttttttttttt'),
    (' /#^^^^^^#d ', 'RRRKKKKKKRRR', 'ttRRRRRRRRtt'),
    ('############', 'RYYRRWWRRYYR', 'RRRRRRRRRRRR'),
    ('<>^^^^^^^^<>', 'WKRRRRRRRRKW', 'KttttttttttK'),
]
CAR_LEFT = [
    (' /______d   ', 'RRRRRRRRRRRR', 'tttttttttttt'),
    (' /#^^^^^^#d ', 'RRKKKKKKRRRR', 'ttRRRRRRRRtt'),
    ('############', 'RYYRRWWRRYYR', 'RRRRRRRRRRRR'),
    ('<>^^^^^^^^<>', 'WKRRRRRRRRKW', 'KttttttttttK'),
]
CAR_RIGHT = [
    ('   /______d ', 'RRRRRRRRRRRR', 'tttttttttttt'),
    (' /#^^^^^^#d ', 'RRRRKKKKKKRR', 'ttRRRRRRRRtt'),
    ('############', 'RYYRRWWRRYYR', 'RRRRRRRRRRRR'),
    ('<>^^^^^^^^<>', 'WKRRRRRRRRKW', 'KttttttttttK'),
]


def parse(txt):
    rows = [r for r in txt.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    return [r.ljust(w, '.') for r in rows]


def scale(img, f):
    h0, w0 = len(img), len(img[0])
    w, h = max(1, round(w0 * f)), max(1, round(h0 * f))
    out = []
    for j in range(h):
        y0, y1 = j * h0 / h, (j + 1) * h0 / h
        row = ''
        for i in range(w):
            x0, x1 = i * w0 / w, (i + 1) * w0 / w
            cnt = {}
            tot = 0
            for y in range(int(y0), max(int(y0) + 1, int(-(-y1 // 1)))):
                for x in range(int(x0), max(int(x0) + 1, int(-(-x1 // 1)))):
                    c = img[min(y, h0 - 1)][min(x, w0 - 1)]
                    cnt[c] = cnt.get(c, 0) + 1
                    tot += 1
            solid = {k: v for k, v in cnt.items() if k != '.'}
            if not solid or cnt.get('.', 0) > tot * 0.7:
                row += '.'
            else:
                row += max(solid, key=lambda k: solid[k])
        out.append(row)
    return out


# ---------------------------------------------------------------- the car as a picture
# 48 x 16 blocks (each block 2 x 2 pixels, so a cell is 4 x 4 blocks);
# converted to the best ROM character per cell by car_cells()
CARPIC = """
..............RRRRRRRRRRRRRRRRRRRR..............
............RRRRRRRRRRRRRRRRRRRRRRRR............
..........RRRRCCCCCCCCCCCCCCCCCCCCRRRR..........
........RRRRCCCCCCCCCCCCCCCCCCCCCCCCRRRR........
......RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR......
....RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR....
..RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR..
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
RRYYYYYYYYRRRRRRRRRRWWWWWWWWRRRRRRRRRRYYYYYYYYRR
RRYYYYYYYYRRRRRRRRRRWWWWWWWWRRRRRRRRRRYYYYYYYYRR
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
KKKKKKKKRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRKKKKKKKK
KKKKKKKK................................KKKKKKKK
KKKKKKKK................................KKKKKKKK
KKKKKKKK................................KKKKKKKK
"""


def car_shift(pic, dx):
    rows = parse(pic)
    out = []
    for i, r in enumerate(rows):
        if i < 6:
            r = ('.' * max(0, dx) + r)[:len(r)] if dx > 0 else (r[-dx:] + '.' * (-dx))
        out.append(r)
    return out


def car_cells(rows, rom):
    """-> 4 rows of 12 (glyph, fg, bg|'t') choosing the closest ROM glyph"""
    cands = list(range(0, 0x100))
    masks = {}
    for g in cands:
        m = []
        for y in range(8):
            b = rom[g * 8 + y]
            m.append([(b >> x) & 1 for x in range(8)])
        masks[g] = m
    out = []
    for cr in range(4):
        row = []
        for cc in range(12):
            px = [[rows[cr * 4 + y // 2][cc * 4 + x // 2] for x in range(8)] for y in range(8)]
            cols = {}
            for y in range(8):
                for x in range(8):
                    cols[px[y][x]] = cols.get(px[y][x], 0) + 1
            if list(cols) == ['.']:
                row.append(None)
                continue
            best = None
            keys = list(cols)
            pairs = [(a, b) for a in keys for b in keys] if len(keys) > 1 else [(keys[0], keys[0])]
            for g in (0x43, 0x00, 0x7A, 0x3A, 0x7B, 0x3B, 0x4D, 0x4E, 0x56, 0x42, 0x3E, 0x7E, 0x3F, 0x7F,
                      0x3C, 0x7C, 0x5B) + tuple(range(0xF0, 0x100)):
                m = masks[g]
                for fgc, bgc in pairs:
                    if fgc == '.':
                        continue
                    err = 0
                    for y in range(8):
                        for x in range(8):
                            want = px[y][x]
                            got = fgc if m[y][x] else bgc
                            if want != got:
                                err += 1
                    if best is None or err < best[0]:
                        best = (err, g, fgc, bgc)
            err, g, fgc, bgc = best
            if g == 0x00:
                if bgc == '.':
                    row.append(None)
                    continue
                g, fgc = 0x43, bgc
            row.append((g, COL[fgc], 't' if bgc == '.' else COL[bgc]))
        out.append(row)
    return out


def to_cells(rows, rom, bw, bh, glyphs=None):
    """picture (letters = colours, '.' = clear) -> rows of cells (glyph, fg, bg|'t')
    with bw x bh picture blocks per 8x8 cell; picks the closest glyph"""
    if glyphs is None:
        glyphs = (0x43, 0x00, 0x7A, 0x3A, 0x7B, 0x3B, 0x4D, 0x4E, 0x56, 0x42, 0x3E, 0x7E, 0x3F, 0x7F)
    masks = {}
    for g in glyphs:
        masks[g] = [[(rom[g * 8 + y] >> x) & 1 for x in range(8)] for y in range(8)]
    ncr, ncc = len(rows) // bh, len(rows[0]) // bw
    out = []
    for cr in range(ncr):
        row = []
        for cc in range(ncc):
            px = [[rows[cr * bh + y * bh // 8][cc * bw + x * bw // 8] for x in range(8)] for y in range(8)]
            keys = sorted(set(c for r in px for c in r))
            if keys == ['.']:
                row.append(None)
                continue
            pairs = [(a, b) for a in keys for b in keys] if len(keys) > 1 else [(keys[0], keys[0])]
            best = None
            for g in glyphs:
                m = masks[g]
                for fgc, bgc in pairs:
                    if fgc == '.':
                        continue
                    err = sum(1 for y in range(8) for x in range(8) if px[y][x] != (fgc if m[y][x] else bgc))
                    if best is None or err < best[0]:
                        best = (err, g, fgc, bgc)
            err, g, fgc, bgc = best
            if g == 0x00:
                if bgc == '.':
                    row.append(None)
                    continue
                g, fgc = 0x43, bgc
            row.append((g, COL[fgc], 't' if bgc == '.' else COL[bgc]))
        out.append(row)
    return out


LOGO_FONT = {
    'R': ["######..", "#######.", "##...##.", "##...##.", "######..", "#####...", "##.##...", "##..##..", "##...##.", "##...###"],
    'E': ["#######.", "#######.", "##......", "##......", "######..", "######..", "##......", "##......", "#######.", "#######."],
    'D': ["#####...", "######..", "##..###.", "##...##.", "##...##.", "##...##.", "##...##.", "##..###.", "######..", "#####..."],
    'L': ["##......", "##......", "##......", "##......", "##......", "##......", "##......", "##......", "#######.", "#######."],
    'I': ["######..", "######..", "..##....", "..##....", "..##....", "..##....", "..##....", "..##....", "######..", "######.."],
    'N': ["##...##.", "###..##.", "####.##.", "##.####.", "##..###.", "##...##.", "##...##.", "##...##.", "##...##.", "##...##."],
}


def logo_pic(word='REDLINE'):
    """the title: italic block letters, 10 half-cells tall"""
    rows = ['' for _ in range(10)]
    for ch in word:
        for y in range(10):
            rows[y] += LOGO_FONT[ch][y] + '..'
    w = len(rows[0]) + 4
    out = []
    for y in range(10):
        sh = (9 - y) * 4 // 9                   # lean to the right
        out.append(('.' * sh + rows[y]).ljust(w, '.')[:w])
    # even width
    if len(out[0]) % 2:
        out = [r + '.' for r in out]
    return [r.replace('#', 'R') for r in out]
