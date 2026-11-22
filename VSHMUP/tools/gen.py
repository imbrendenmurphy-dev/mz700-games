"""gen.py - NOVA STORM data generator (-> build/gen_art.inc, build/gen_stage.inc)

Sprites and scenery come from art.py, stages are laid out below.
"""
import os
import sys
import random

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art

BUILD = os.path.join(HERE, '..', 'build')


def db(vals, per=16):
    return ['        db ' + ','.join('%03Xh' % (v & 255) for v in vals[i:i + per])
            for i in range(0, len(vals), per)]


# ------------------------------------------------------------------ sprites
def sprite_asm(label, rows):
    cells, w, h = art.parse(rows)
    out = ['%s:   ; %dx%d' % (label, w, h), '        db %d' % len(cells)]
    for dx, dy, ch, at in cells:
        out.append('        db %d,%d,%03Xh,%03Xh' % (dx, dy, ch, at))
    return out, w, h


def piece_asm(label, rows):
    toks = [r.split() for r in rows]
    w = max(len(t) for t in toks)
    h = len(toks)
    out = ['%s:   ; %dx%d (bottom row first: it scrolls in from the top)' % (label, w, h),
           '        db %d,%d' % (w, h)]
    for t in reversed(toks):
        vals = []
        for x in range(w):
            c = art.cell(t[x]) if x < len(t) else None
            vals += [c[0], c[1]] if c else [0, 0]
        out += db(vals, 20)
    return out


# ------------------------------------------------------------------ logo
# logo letters drawn straight in character cells: solid blocks with
# triangle corners (symbols as in art.py)
LOGO_FONT = {
    'N': ['#b.#', '##b#', '#p##', '#.p#', '#..#'],
    'O': ['d##b', '#..#', '#..#', '#..#', 'p##q'],
    'V': ['#..#', '#..#', '#..#', 'pbdq', '.pq.'],
    'A': ['d##b', '#..#', '####', '#..#', '#..#'],
    'S': ['d###', '#...', 'p##b', '...#', '###q'],
    'T': ['####', '.##.', '.##.', '.##.', '.##.'],
    'R': ['###b', '#..#', '###q', '#.pb', '#..#'],
    'M': ['#b.d#', '#p#q#', '#...#', '#...#', '#...#'],
}


def logo_cells(text):
    rows = []
    for y in range(5):
        line = []
        for i, ch in enumerate(text):
            for c in LOGO_FONT[ch][y]:
                line.append(0 if c == '.' else art.SYMS[c])
            if i < len(text) - 1:
                line.append(0)
        rows.append(line)
    return rows


def gen_logo():
    out = []
    for label, text in (('logo1', 'NOVA'), ('logo2', 'STORM')):
        cells = logo_cells(text)
        w = len(cells[0])
        out.append('%s:   ; %d x 5' % (label, w))
        out.append('        db %d' % w)
        for r in cells:
            out += db([g & 255 for g in r], 25)
    return out


# 5x7 letters for the big captions, one per 3 x 4 dotted block characters
BIG = {
    'W': '10001 10001 10001 10101 10101 11011 10001',
    'A': '01110 10001 10001 11111 10001 10001 10001',
    'V': '10001 10001 10001 10001 01010 01010 00100',
    'E': '11111 10000 10000 11110 10000 10000 11111',
    'C': '01111 10000 10000 10000 10000 10000 01111',
    'L': '10000 10000 10000 10000 10000 10000 11111',
    'R': '11110 10001 10001 11110 10100 10010 10001',
    'G': '01111 10000 10000 10011 10001 10001 01111',
    'M': '10001 11011 10101 10101 10001 10001 10001',
    'O': '01110 10001 10001 10001 10001 10001 01110',
    'S': '01111 10000 10000 01110 00001 00001 11110',
    'T': '11111 00100 00100 00100 00100 00100 00100',
    'N': '10001 11001 10101 10011 10001 10001 10001',
    'I': '01110 00100 00100 00100 00100 00100 01110',
    'D': '11110 10001 10001 10001 10001 10001 11110',
    'P': '11110 10001 10001 11110 10000 10000 10000',
    'U': '10001 10001 10001 10001 10001 10001 01110',
    'Y': '10001 10001 01010 00100 00100 00100 00100',
    'K': '10001 10010 10100 11000 10100 10010 10001',
    '0': '01110 10011 10101 10101 11001 10001 01110',
    '1': '00100 01100 00100 00100 00100 00100 01110',
    '2': '01110 10001 00001 00110 01000 10000 11111',
    '3': '11110 00001 00001 01110 00001 00001 11110',
    '4': '00010 00110 01010 10010 11111 00010 00010',
    '5': '11111 10000 11110 00001 00001 10001 01110',
    '6': '00110 01000 10000 11110 10001 10001 01110',
    '7': '11111 00001 00010 00100 01000 01000 01000',
    '8': '01110 10001 10001 01110 10001 10001 01110',
    '9': '01110 10001 10001 01111 00001 00010 01100',
    '!': '00100 00100 00100 00100 00100 00000 00100',
}


def gen_bigfont():
    chars = ''.join(BIG)
    out = ['bigchars: db "%s",0' % chars, 'bigfont:']
    for ch in chars:
        rows = BIG[ch].split()
        pix = [[0] * 6 for _ in range(8)]
        for y, r in enumerate(rows):
            for x, b in enumerate(r):
                pix[y][x] = b == '1'
        cells = []
        for cy in range(4):
            for cx in range(3):
                tl = pix[cy * 2][cx * 2]
                tr = pix[cy * 2][cx * 2 + 1]
                bl = pix[cy * 2 + 1][cx * 2]
                br = pix[cy * 2 + 1][cx * 2 + 1]
                cells.append(0xF0 + tl + 2 * tr + 4 * bl + 8 * br)
        out.append('        db ' + ','.join('%03Xh' % v for v in cells) + '   ; ' + ch)
    return out


# ------------------------------------------------------------------ stages
EV = {'END': 0, 'WAVE': 1, 'PIECE': 2, 'TUR': 3, 'BOSS': 4, 'MSG': 5, 'SPEED': 6}
TYPES = ['', 'DART', 'WASP', 'CRAB', 'BUG', 'SKULL', 'EYE', 'MINE', 'FISH', 'UFO', 'GUN', 'ROCK',
         'ROCKS', 'TUR', 'HEAVY']
CAPK = {'': 0, 'P': 1, 'V': 2, 'L': 3, 'O': 4, 'S': 5, 'B': 6, 'H': 7, '1': 8, '$': 9}
PIECES = list(art.PIECES)
RND = 255


class Stage:
    def __init__(self, seed):
        self.ev = []
        self.r = random.Random(seed)

    def wave(self, d, typ, n=1, x=RND, dx=0, gap=8, par=0, drop=''):
        self.ev.append((d, [EV['WAVE'], TYPES.index(typ), n, x & 255, dx & 255, gap, par, CAPK[drop]]))

    def piece(self, d, name, x):
        self.ev.append((d, [EV['PIECE'], PIECES.index(name), x]))

    def tur(self, d, x):
        self.ev.append((d, [EV['TUR'], x]))

    def boss(self, d, n):
        self.ev.append((d, [EV['BOSS'], n]))

    def msg(self, d, n):
        self.ev.append((d, [EV['MSG'], n]))

    def speed(self, d, ticks):
        self.ev.append((d, [EV['SPEED'], ticks]))

    def asm(self, label):
        out = ['%s:' % label]
        for d, e in sorted(self.ev, key=lambda t: t[0]):
            out.append('        dw %d' % d)
            out += db(e)
        out.append('        dw 0FFFFh')
        return out


def rocks(st, d0, d1, every=9):
    """an asteroid belt in the scenery"""
    d = d0
    while d < d1:
        name = st.r.choice(['ROCK1', 'ROCK2', 'ROCK3', 'ROCK3'])
        w = len(art.PIECES[name][0].split())
        st.piece(d, name, st.r.randrange(0, 30 - w))
        d += st.r.randrange(every - 3, every + 4)


def nebula(st, d0, d1, every=10):
    d = d0
    while d < d1:
        name = st.r.choice(['NEB1', 'NEB2'])
        st.piece(d, name, st.r.randrange(0, 26))
        d += st.r.randrange(every - 3, every + 4)


def station(st, d0, d1, turrets=True):
    """decks with turrets, pylons and girders"""
    d = d0
    while d < d1:
        k = st.r.randrange(4)
        if k == 0:
            x = st.r.choice([0, 24])
            st.piece(d, 'DECK', x)
            if turrets:
                st.tur(d, x + st.r.choice([0, 2, 3, 5]))
            d += 5
        elif k == 1:
            x = st.r.randrange(2, 22)
            st.piece(d, 'HULL', x)
            if turrets:
                st.tur(d + 1, x + 2)
            d += 7
        elif k == 2:
            st.piece(d, 'PYLON', st.r.randrange(1, 29))
            d += 4
        else:
            st.piece(d, 'GIRD', st.r.randrange(1, 29))
            st.piece(d, 'GIRD', st.r.randrange(1, 29))
            d += 3


def stage1():
    st = Stage(11)
    st.speed(0, 4)
    rocks(st, 20, 150, 12)
    st.piece(40, 'MOON', 22)
    st.wave(10, 'DART', 4, 4, 6, 10)
    st.wave(30, 'WASP', 5, 6, 0, 8, 4)
    st.wave(50, 'DART', 4, 25, -6, 10)
    st.wave(62, 'GUN', 1, 13, 0, 1, 0, 'P')
    st.wave(80, 'CRAB', 5, 5, 4, 6, 5)
    st.wave(100, 'WASP', 5, 20, 0, 8, 5)
    st.wave(110, 'UFO', 1, 0, 0, 1, 3, '$')
    st.wave(125, 'DART', 6, RND, 0, 6, 1)
    st.wave(140, 'ROCK', 3, RND, 0, 30)
    st.wave(150, 'GUN', 1, 6, 0, 1, 0, 'V')
    st.wave(165, 'CRAB', 5, 21, -4, 6, 4)
    rocks(st, 170, 320, 8)
    st.wave(185, 'BUG', 6, 0, 0, 6, 0)
    st.wave(200, 'BUG', 6, 29, 0, 6, 0)
    st.wave(215, 'ROCK', 4, RND, 0, 24)
    st.wave(230, 'GUN', 1, 20, 0, 1, 0, 'O')
    st.wave(240, 'WASP', 6, 8, 0, 6, 6)
    st.wave(250, 'WASP', 6, 20, 0, 6, 6)
    st.wave(268, 'DART', 6, 2, 5, 5, 1)
    st.wave(280, 'UFO', 1, 29, 0, 1, 2, '$')
    st.wave(290, 'CRAB', 6, 3, 4, 5, 6)
    st.wave(305, 'EYE', 2, 8, 12, 20, 6)
    st.wave(320, 'GUN', 1, 13, 0, 1, 0, 'B')
    st.wave(330, 'DART', 8, RND, 0, 5, 1)
    st.msg(352, 1)
    st.boss(360, 0)
    return st


def stage2():
    st = Stage(22)
    st.speed(0, 4)
    nebula(st, 5, 330, 9)
    st.piece(60, 'PLANET', 2)
    st.piece(220, 'PLANET', 20)
    st.wave(10, 'WASP', 5, 5, 0, 8, 5)
    st.wave(22, 'WASP', 5, 24, 0, 8, 5)
    st.wave(40, 'FISH', 4, 0, 0, 10, 3)
    st.wave(55, 'GUN', 1, 14, 0, 1, 0, 'L')
    st.wave(70, 'BUG', 7, 0, 0, 5, 0)
    st.wave(80, 'BUG', 7, 29, 0, 5, 0)
    st.wave(95, 'MINE', 4, RND, 0, 15)
    st.wave(110, 'EYE', 2, 6, 16, 25, 5)
    st.wave(125, 'FISH', 4, 29, 0, 10, 4)
    st.wave(135, 'UFO', 1, 0, 0, 1, 2, '$')
    st.wave(145, 'CRAB', 6, 3, 4, 5, 5)
    st.wave(160, 'GUN', 1, 7, 0, 1, 0, 'P')
    st.wave(170, 'MINE', 5, RND, 0, 12)
    st.wave(185, 'SKULL', 4, RND, 0, 15)
    st.wave(200, 'WASP', 8, 15, 0, 5, 8)
    st.wave(215, 'GUN', 1, 22, 0, 1, 0, 'S')
    st.wave(230, 'EYE', 3, 5, 9, 15, 7)
    st.wave(245, 'FISH', 6, 0, 0, 7, 5)
    st.wave(255, 'FISH', 6, 29, 0, 7, 8)
    st.wave(270, 'UFO', 1, 29, 0, 1, 2, '$')
    st.wave(280, 'BUG', 8, 0, 0, 4, 0)
    st.wave(290, 'BUG', 8, 29, 0, 4, 0)
    st.wave(305, 'GUN', 1, 13, 0, 1, 0, 'H')
    st.wave(315, 'SKULL', 6, RND, 0, 10)
    st.msg(352, 1)
    st.boss(360, 1)
    return st


def stage3():
    st = Stage(33)
    st.speed(0, 4)
    station(st, 10, 330)
    st.wave(15, 'DART', 5, 3, 5, 8, 1)
    st.wave(35, 'CRAB', 6, 3, 4, 5, 4)
    st.wave(55, 'GUN', 1, 14, 0, 1, 0, 'O')
    st.wave(70, 'EYE', 3, 4, 10, 15, 6)
    st.wave(90, 'WASP', 6, 15, 0, 6, 7)
    st.wave(110, 'UFO', 1, 0, 0, 1, 3, '$')
    st.wave(120, 'DART', 8, RND, 0, 5, 1)
    st.wave(140, 'HEAVY', 1, 13, 0, 1, 2, 'P')
    st.wave(180, 'GUN', 1, 5, 0, 1, 0, 'B')
    st.wave(190, 'GUN', 1, 22, 0, 1, 0, 'L')
    st.wave(205, 'CRAB', 6, 22, -4, 5, 6)
    st.wave(220, 'SKULL', 5, RND, 0, 12)
    st.wave(240, 'EYE', 3, 22, -8, 12, 5)
    st.wave(255, 'BUG', 8, 0, 0, 4, 0)
    st.wave(265, 'UFO', 1, 29, 0, 1, 2, '$')
    st.wave(275, 'DART', 8, 2, 3, 4, 1)
    st.wave(290, 'GUN', 1, 13, 0, 1, 0, 'P')
    st.wave(305, 'WASP', 8, 8, 2, 4, 6)
    st.wave(320, 'CRAB', 7, 2, 4, 4, 5)
    st.msg(352, 1)
    st.boss(360, 2)
    return st


def stage4():
    st = Stage(44)
    st.speed(0, 3)
    d = 8
    while d < 340:
        st.piece(d, 'COMET', st.r.randrange(0, 30))
        d += st.r.randrange(4, 9)
    rocks(st, 20, 330, 11)
    st.wave(10, 'ROCK', 3, RND, 0, 20)
    st.wave(30, 'FISH', 5, 0, 0, 8, 4)
    st.wave(45, 'GUN', 1, 14, 0, 1, 0, 'P')
    st.wave(60, 'SKULL', 5, RND, 0, 12)
    st.wave(80, 'ROCK', 4, RND, 0, 16)
    st.wave(95, 'MINE', 6, RND, 0, 10)
    st.wave(110, 'EYE', 3, 5, 10, 14, 5)
    st.wave(125, 'UFO', 1, 0, 0, 1, 3, '$')
    st.wave(135, 'BUG', 8, 29, 0, 4, 0)
    st.wave(150, 'GUN', 1, 7, 0, 1, 0, 'O')
    st.wave(165, 'HEAVY', 1, 13, 0, 1, 2, 'S')
    st.wave(200, 'ROCK', 5, RND, 0, 12)
    st.wave(215, 'SKULL', 6, RND, 0, 10)
    st.wave(230, 'FISH', 6, 29, 0, 6, 6)
    st.wave(245, 'GUN', 1, 22, 0, 1, 0, 'B')
    st.wave(255, 'CRAB', 7, 2, 4, 4, 5)
    st.wave(270, 'MINE', 6, RND, 0, 8)
    st.wave(285, 'UFO', 1, 29, 0, 1, 2, '$')
    st.wave(295, 'DART', 10, RND, 0, 4, 1)
    st.wave(310, 'GUN', 1, 13, 0, 1, 0, 'H')
    st.wave(320, 'EYE', 4, 3, 7, 10, 6)
    st.msg(352, 1)
    st.boss(360, 3)
    return st


def stage5():
    st = Stage(55)
    st.speed(0, 4)
    d = 6
    while d < 335:
        if st.r.random() < 0.5:
            st.piece(d, 'CORE1', st.r.choice([0, 3, 24, 27]))
        else:
            x = st.r.randrange(2, 22)
            st.piece(d, 'HULL', x)
            st.tur(d + 1, x + 2)
        d += st.r.randrange(6, 10)
    st.wave(10, 'CRAB', 7, 2, 4, 4, 5)
    st.wave(30, 'GUN', 1, 14, 0, 1, 0, 'P')
    st.wave(45, 'SKULL', 6, RND, 0, 10)
    st.wave(60, 'EYE', 4, 3, 7, 10, 6)
    st.wave(80, 'BUG', 8, 0, 0, 4, 0)
    st.wave(90, 'BUG', 8, 29, 0, 4, 0)
    st.wave(105, 'GUN', 1, 6, 0, 1, 0, 'L')
    st.wave(110, 'GUN', 1, 22, 0, 1, 0, 'V')
    st.wave(125, 'HEAVY', 1, 13, 0, 1, 3, 'O')
    st.wave(165, 'UFO', 1, 0, 0, 1, 3, '$')
    st.wave(175, 'MINE', 6, RND, 0, 8)
    st.wave(190, 'WASP', 8, 8, 2, 4, 8)
    st.wave(205, 'FISH', 6, 0, 0, 6, 6)
    st.wave(215, 'GUN', 1, 13, 0, 1, 0, 'B')
    st.wave(225, 'DART', 10, RND, 0, 3, 1)
    st.wave(240, 'HEAVY', 1, 6, 0, 1, 2, 'P')
    st.wave(280, 'SKULL', 8, RND, 0, 8)
    st.wave(295, 'UFO', 1, 29, 0, 1, 2, '$')
    st.wave(305, 'EYE', 4, 3, 7, 10, 6)
    st.wave(318, 'GUN', 1, 13, 0, 1, 0, 'H')
    st.msg(352, 1)
    st.boss(360, 4)
    return st


def gen_stages():
    out = []
    stages = [stage1(), stage2(), stage3(), stage4(), stage5()]
    for i, st in enumerate(stages):
        out += st.asm('stage%d' % (i + 1))
    out.append('stagetab: dw ' + ','.join('stage%d' % (i + 1) for i in range(len(stages))))
    return out


def main():
    os.makedirs(BUILD, exist_ok=True)
    out = ['; generated by tools/gen.py']
    # sprites
    o, w, h = sprite_asm('SPR_PLAYER', art.PLAYER)
    out += o
    o, w, h = sprite_asm('SPR_OPTION', art.OPTION)
    out += o
    dims = {}
    for name, rows in art.SPRITES.items():
        o, w, h = sprite_asm('SPR_' + name, rows)
        out += o
        dims[name] = (w, h)
        out.append('SW_%s equ %d' % (name, w))
        out.append('SH_%s equ %d' % (name, h))
    for name, rows in art.BOSSES.items():
        o, w, h = sprite_asm('BOSS_' + name, rows)
        out += o
        out.append('BW_%s equ %d' % (name, w))
        out.append('BH_%s equ %d' % (name, h))
    # scenery pieces
    tab = []
    for i, (name, rows) in enumerate(art.PIECES.items()):
        out += piece_asm('PC_' + name, rows)
        out.append('PN_%s equ %d' % (name, i))
        tab.append('PC_' + name)
    out.append('piecetab: dw ' + ','.join(tab))
    # capsules: char, attribute for kinds 1..9
    caps = []
    for k, (letter, cols) in art.CAPS.items():
        code = ord(letter) - ord('A') + 1 if letter.isalpha() else 0x21
        caps += [code, (art.COL[cols[0]] << 4) | art.COL[cols[1]]]
    caps += [0x88, 0xE0]          # medal: bank 2 circled C, yellow
    out.append('captab:')
    out += db(caps)
    out += gen_logo()
    out += gen_bigfont()
    open(os.path.join(BUILD, 'gen_art.inc'), 'w').write('\n'.join(out) + '\n')
    open(os.path.join(BUILD, 'gen_stage.inc'), 'w').write('\n'.join(['; generated by tools/gen.py'] + gen_stages()) + '\n')
    print('gen: ok')


if __name__ == '__main__':
    main()
