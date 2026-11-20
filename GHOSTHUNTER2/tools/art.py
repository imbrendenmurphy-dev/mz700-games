"""art.py - title screen and big sprites, as MZ-700 character cells.

Pixel art (one letter per pixel: . transparent, k b r m g c y w colours)
is cut into 8x8 cells and each cell is matched against the CG-ROM by
glyphmatch.py.  The logo letters use a hand-made block font.

Cells are (glyph 0-1FF, fg, bg) with bg -1 = transparent.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glyphmatch as gm  # noqa: E402

T = -1
K, B, R, M, G, C, Y, W = range(8)
PAL = {'.': T, 'k': K, 'b': B, 'r': R, 'm': M, 'g': G, 'c': C, 'y': Y, 'w': W}


def art(text):
    rows = [r.strip() for r in text.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    return [[PAL[ch] for ch in r.ljust(w, '.')] for r in rows]


def cells(text, wc=None, hc=None, dx=0, dy=0, allowed=None):
    img = art(text)
    wc = wc or (len(img[0]) + 7) // 8
    hc = hc or (len(img) + 7) // 8
    return gm.convert(img, dx, dy, wc, hc, allowed)


def recolour(cl, mapping):
    return [[(g, mapping.get(f, f), mapping.get(b, b)) for (g, f, b) in row] for row in cl]


# ------------------------------------------------------------------ big sprites (3x3)
# hand-built from block glyphs: (glyph, fg, bg) rows, None = not drawn
def _c(g, f, b=T):
    return (g, f, b)


def big_ghost(col, frame, eyes=W):
    legs = 0x147 if frame == 0 else 0x148
    return [[_c(0x04E, col), _c(0x043, col), _c(0x04D, col)],
            [_c(0x043, col), _c(0x171, eyes, col), _c(0x043, col)],
            [_c(legs, col), _c(legs, col), _c(legs, col)]]


def big_hero(frame, left=False):
    if frame == 0:          # mouth open
        r1 = [_c(0x043, Y), _c(0x189, Y), _c(0x056, Y)]
        r2 = [_c(0x042, Y), _c(0x043, Y), _c(0x04D, Y)]
    else:
        r1 = [_c(0x043, Y), _c(0x189, Y), _c(0x043, Y)]
        r2 = [_c(0x042, Y), _c(0x043, Y), _c(0x056, Y)]
    rows = [[_c(0x04E, R), _c(0x043, R), _c(0x04D, R)], r1, r2]
    if left:
        mir = {0x04E: 0x04D, 0x04D: 0x04E, 0x042: 0x056, 0x056: 0x042}
        rows = [[_c(mir.get(g, g), f, b) for (g, f, b) in row[::-1]] for row in rows]
    return rows


def big_sprites():
    s = {}
    for name, col in (('BG_RED', R), ('BG_GREEN', G), ('BG_MAG', M), ('BG_CYAN', C), ('BG_BLUE', B)):
        for f in range(2):
            s['%s%d' % (name, f)] = big_ghost(col, f)
    for f in range(2):
        s['BH_R%d' % f] = big_hero(f)
        s['BH_L%d' % f] = big_hero(f, True)
    return s


# ------------------------------------------------------------------ logo font
BLK = {'#': 0x043, '.': None, '/': 0x04E, '\\': 0x04D, 'L': 0x042, 'J': 0x056}
FONT = {
    'G': ['/##\\', '#...', '#.##', '#..#', 'L##J'],
    'H': ['#..#', '#..#', '####', '#..#', '#..#'],
    'O': ['/##\\', '#..#', '#..#', '#..#', 'L##J'],
    'S': ['/###', '#...', 'L##\\', '...#', '###J'],
    'T': ['####', '.##.', '.##.', '.##.', '.##.'],
    'U': ['#..#', '#..#', '#..#', '#..#', 'L##J'],
    'N': ['#\\.#', '##\\#', '#L##', '#.L#', '#..#'],
    'E': ['####', '#...', '###.', '#...', '####'],
    'R': ['###\\', '#..#', '###J', '#.L\\', '#..#'],
}


def logo_word(word, colours):
    """-> rows of cells for a word in the block font; colours per font row"""
    rows = []
    for y in range(5):
        row = []
        for i, ch in enumerate(word):
            for t in FONT[ch][y]:
                g = BLK[t]
                row.append(None if g is None else (g, colours[y], T))
            if i < len(word) - 1:
                row.append(None)
        rows.append(row)
    return rows


# ------------------------------------------------------------------ title picture
TWO = ['/####\\', '##..##', '.../#J', '../#J.', './#J..', '/#J...', '######']
MOON = [[(0x04E, Y), (0x043, Y), (0x043, Y), (0x04D, Y)],
        [(0x043, Y), (0x18A, Y), (0x043, Y), (0x189, Y)],
        [(0x042, Y), (0x043, Y), (0x043, Y), (0x056, Y)]]
TOMB = [[(0x04E, C), (0x04D, C)], [(0x043, C), (0x043, C)]]
TREE = [[(0x077, G), (0x079, G), (0x076, G), None],
        [None, (0x077, G), (0x01E, G), (0x076, G)],
        [None, None, (0x079, G), None],
        [None, (0x04E, G), (0x043, G), (0x04D, G)]]
GROUND_ROW = 22                     # the chase runs on rows 19..21
HILL_ROW = 17


def title_picture():
    """25 rows of 40 cells: (glyph, fg, bg) with bg K for the sky"""
    pic = [[(0, W, K) for _ in range(40)] for _ in range(25)]

    def put(cl, cx, cy, sky=K):
        for y, row in enumerate(cl):
            for x, c in enumerate(row):
                if c is None:
                    continue
                g, f = c[0], c[1]
                b = c[2] if len(c) > 2 else T
                if 0 <= cx + x < 40 and 0 <= cy + y < 25:
                    pic[cy + y][cx + x] = (g, f, sky if b == T else b)

    import random
    rnd = random.Random(7)
    stars = []
    while len(stars) < 30:
        x, y = rnd.randrange(40), rnd.randrange(0, 16)
        if pic[y][x][0] or (x, y) in stars:
            continue
        stars.append((x, y))
    for (x, y) in stars:
        pic[y][x] = (rnd.choice([0x02E, 0x02E, 0x06B]), rnd.choice([W, W, Y, C]), K)
    put(logo_word('GHOST', [Y, Y, R, R, R]), 1, 1)
    put(logo_word('HUNTER', [Y, Y, R, R, R]), 1, 7)
    two = [[None if t == '.' else (BLK[t], Y if y < 2 else R) for t in r] for y, r in enumerate(TWO)]
    put(two, 32, 5)
    put(MOON, 35, 0)
    # graveyard hill and the ground
    for x in range(4, 30):
        pic[HILL_ROW][x] = (0x043, G, K)
    pic[HILL_ROW][3] = (0x04E, G, K)
    pic[HILL_ROW][30] = (0x04D, G, K)
    for x in range(40):
        pic[HILL_ROW + 1][x] = (0x043, G, K)
    for (tx, ty) in ((6, 15), (12, 15), (20, 15), (26, 15)):
        put(TOMB, tx, ty)
    put(TREE, 34, 14)
    for x in range(40):
        pic[GROUND_ROW][x] = (0x07A, G, K)
    # remember which stars survived the art
    stars = [(x, y) for (x, y) in stars if pic[y][x][0] in (0x02E, 0x06B)]
    return pic, stars


if __name__ == '__main__':
    import mzfont
    pic, _ = title_picture()
    ch = []
    at = []
    for row in pic:
        for g, f, b in row:
            ch.append(g & 0xFF)
            at.append(((g >> 8) << 7) | (f << 4) | (b & 7))
    mzfont.render_cells(ch, at).save(os.path.join(HERE, '..', 'build', 'title_art.png'))
    sp = big_sprites()
    ch = [0] * 1000
    at = [0x11] * 1000
    for i, (n, cl) in enumerate(sp.items()):
        ox, oy = (i % 8) * 4 + 1, (i // 8) * 4 + 1
        for y, row in enumerate(cl):
            for x, c in enumerate(row):
                if c is None:
                    continue
                g, f, b = c
                ch[(oy + y) * 40 + ox + x] = g & 0xFF
                at[(oy + y) * 40 + ox + x] = ((g >> 8) << 7) | (f << 4) | (B if b == T else b)
    mzfont.render_cells(ch, at).save(os.path.join(HERE, '..', 'build', 'big_sprites.png'))
    print('ok')
