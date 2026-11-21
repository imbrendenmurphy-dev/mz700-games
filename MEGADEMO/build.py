"""build.py - builds SHARP EDGES, a megademo for the Sharp MZ-700.

    py build.py

Generates build/gen_data.inc (logo, fonts, texts, lookup tables, textures,
3D shapes, the soundtrack), assembles src/main.asm with sjasmplus and writes
SHARPEDG.MZT (emulators) and an identical SHARPEDG.MZF (UniCMT / real
hardware) to build/ and release/.

All the words on screen are in this file: INTRO, TITLE_SCROLL, GREETS, CREDITS.
"""
import math
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.join(ROOT, 'tools')
BUILD = os.path.join(ROOT, 'build')
SRC = os.path.join(ROOT, 'src')
REL = os.path.join(ROOT, 'release')
sys.path.insert(0, TOOLS)

import music  # noqa: E402
import crunch  # noqa: E402

NAME = 'SHARPEDG'
TAPE_NAME = 'SHARP EDGES'
LOAD = 0x1200
NL = chr(10)

# ---------------------------------------------------------------- words
INTRO = [   # (row, attr, text) - typed in this order
    (5, 0x70, 'SPRITELESS'),
    (7, 0x50, 'PRESENTS'),
    (11, 0x60, 'A MEGADEMO FOR THE SHARP MZ-700'),
    (15, 0x50, '3.5 MHZ. 4 KB OF VIDEO RAM.'),
    (16, 0x50, 'ONE SQUARE-WAVE BEEPER.'),
    (18, 0x70, 'NO SPRITES. NO SCROLLING. NO MERCY.'),
]

TITLE_SCROLL = ('    WELCOME TO SHARP EDGES ... THE FIRST MEGADEMO BY SPRITELESS ... '
                'EVERYTHING YOU SEE IS 8X8 TEXT CHARACTERS FROM THE CHARACTER ROM, '
                'THE MUSIC IS ONE 8253 TIMER DOING ITS BEST ... '
                'GRAB A DRINK AND TURN IT UP!      ')

GREETS = ('      GREETINGS TO ... GENESIS PROJECT ... FUTURE CREW ... '
          'EVERY SHARP MZ CODER, PAST AND PRESENT ... THE VZ200 GANG ... '
          'ALL SPECCY, CPC AND MSX SCENERS ... AND YOU, FOR WATCHING ON A '
          'MACHINE WITH NO SPRITES!      ')

CREDITS = [
    '',
    '',
    '* SHARP EDGES *',
    '',
    'A SPRITELESS PRODUCTION',
    '',
    '',
    'CODE, GRAPHICS AND MUSIC',
    'CLAUDE',
    '',
    'TESTED ON THE MZ700ONPC EMULATOR',
    '',
    'MADE FOR THE SHARP MZ-700',
    '64 KB RAM - 40X25 TEXT - 8 COLOURS',
    '',
    '',
    'THANKS FOR WATCHING!',
    '',
    '',
    '- THE END -',
]

DOT_NAMES = ['SPHERE', 'CUBE', 'TORUS', 'DOUBLE HELIX', 'MZ', 'STAR']

# ---------------------------------------------------------------- helpers
ASCII = {' ': 0x00, '!': 0x61, '"': 0x62, '#': 0x63, '$': 0x64, '%': 0x65, '&': 0x66, "'": 0x67,
         '(': 0x68, ')': 0x69, '+': 0x6A, '*': 0x6B, ',': 0x2F, '-': 0x2A, '.': 0x2E, '/': 0x2D,
         ':': 0x4F, ';': 0x2C, '=': 0x2B, '?': 0x49, '<': 0x51, '>': 0x57}


def disp(text):
    out = []
    for ch in text:
        if 'A' <= ch <= 'Z':
            out.append(ord(ch) - 64)
        elif '0' <= ch <= '9':
            out.append(0x20 + ord(ch) - 48)
        else:
            out.append(ASCII[ch])
    return out


def db(vals, per=16):
    return NL.join('        db ' + ','.join('%d' % (v & 0xFF) for v in vals[i:i + per])
                   for i in range(0, len(vals), per))


def dw(vals, per=8):
    return NL.join('        dw ' + ','.join('%s' % v for v in vals[i:i + per])
                   for i in range(0, len(vals), per))


def rom_font():
    p = os.path.join(ROOT, '..', 'MZ700onPC', 'roms', 'mz700fon.int')
    return open(p, 'rb').read()


def find_glyph(font, pred):
    """bank-0 code whose 8x8 bitmap matches pred(x, y) best (bit 0 = left)."""
    best, bc = None, -1
    for c in range(256):
        score = 0
        for y in range(8):
            b = font[c * 8 + y]
            for x in range(8):
                if bool(b & (1 << x)) == pred(x, y):
                    score += 1
        if score > bc:
            best, bc = c, score
    return best, bc


# ---------------------------------------------------------------- the logo
LOGO_LETTERS = {
    'S': ['a####b', '##....', '##....', 'd####b', '....##', '....##', 'd####c'],
    'H': ['##..##', '##..##', '##..##', '######', '##..##', '##..##', '##..##'],
    'A': ['a####b', '##..##', '##..##', '######', '##..##', '##..##', '##..##'],
    'R': ['#####b', '##..##', '##..##', '#####c', '##.a#.', '##..##', '##..##'],
    'P': ['#####b', '##..##', '##..##', '#####c', '##....', '##....', '##....'],
    'E': ['a#####', '##....', '##....', '####..', '##....', '##....', 'd#####'],
    'D': ['#####b', '##..##', '##..##', '##..##', '##..##', '##..##', '#####c'],
    'G': ['a####b', '##....', '##....', '##.###', '##..##', '##..##', 'd####c'],
}


def logo(tri):
    rows = [[0] * 40 for _ in range(18)]
    code = {'#': 0x43, '.': 0, 'a': tri['a'], 'b': tri['b'], 'c': tri['c'], 'd': tri['d']}
    for word, top in (('SHARP', 1), ('EDGES', 9)):
        x = 1
        for ch in word:
            for y, line in enumerate(LOGO_LETTERS[ch]):
                for i, c in enumerate(line):
                    rows[top + y][x + i] = code[c]
            x += 8
    ink = [0x70] * 18
    for top in (1, 9):
        for y, v in enumerate([0x70, 0x70, 0x60, 0x60, 0x60, 0x60, 0x60]):
            ink[top + y] = v
    return [v for r in rows for v in r], ink


# ---------------------------------------------------------------- big font
BIG = {
    'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'C': ['.####', '#....', '#....', '#....', '#....', '#....', '.####'],
    'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
    'G': ['.####', '#....', '#....', '#.###', '#...#', '#...#', '.###.'],
    'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'I': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '#####'],
    'J': ['..###', '...#.', '...#.', '...#.', '...#.', '#..#.', '.##..'],
    'K': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
    'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
    'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'N': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
    'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
    'Q': ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'],
    'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
    'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'V': ['#...#', '#...#', '#...#', '#...#', '.#.#.', '.#.#.', '..#..'],
    'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
    'X': ['#...#', '.#.#.', '..#..', '..#..', '..#..', '.#.#.', '#...#'],
    'Y': ['#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'Z': ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
    '0': ['.###.', '#..##', '#.#.#', '#.#.#', '##..#', '#...#', '.###.'],
    '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    '2': ['.###.', '#...#', '....#', '..##.', '.#...', '#....', '#####'],
    '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
    '4': ['#..#.', '#..#.', '#..#.', '#####', '...#.', '...#.', '...#.'],
    '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
    '6': ['.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.'],
    '7': ['#####', '....#', '...#.', '..#..', '..#..', '..#..', '..#..'],
    '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
    '9': ['.###.', '#...#', '#...#', '.####', '....#', '....#', '.###.'],
    ' ': ['.....'] * 7,
    '.': ['.....'] * 5 + ['.##..', '.##..'],
    ',': ['.....'] * 4 + ['.##..', '.##..', '.#...'],
    '!': ['..#..'] * 5 + ['.....', '..#..'],
    '?': ['.###.', '#...#', '....#', '..##.', '..#..', '.....', '..#..'],
    '-': ['.....'] * 3 + ['#####'] + ['.....'] * 3,
    "'": ['..#..', '..#..'] + ['.....'] * 5,
    ':': ['.....', '.##..', '.##..', '.....', '.##..', '.##..', '.....'],
}


def big_font():
    out = []
    for c in range(32, 96):
        g = BIG.get(chr(c), BIG['?'] if chr(c) != ' ' else BIG[' '])
        for x in range(5):
            out.append(sum(1 << y for y in range(7) if g[y][x] == '#'))
    return out


# ---------------------------------------------------------------- tables
def sine():
    return [int(round(127 * math.sin(i * 2 * math.pi / 256))) & 0xFF for i in range(256)]


def qsq():
    q = [n * n // 4 for n in range(256)]
    return [v & 0xFF for v in q] + [v >> 8 for v in q]


def palette(bands):
    out = []
    for col, w in bands:
        out += [col] * w
    assert len(out) == 256, len(out)
    return [c << 4 for c in out] + out


PALETTES = [
    [(0, 40), (1, 30), (3, 20), (2, 20), (6, 16), (7, 8), (6, 16), (2, 20), (3, 20), (1, 30), (0, 36)],
    [(0, 40), (1, 40), (5, 24), (7, 12), (5, 24), (1, 40), (0, 40), (1, 36)],
    [(0, 48), (4, 30), (5, 20), (7, 10), (5, 20), (4, 30), (0, 48), (1, 50)],
    [(0, 64), (1, 48), (3, 16), (7, 8), (3, 16), (1, 48), (0, 56)],
]


def rotex():
    pages = []
    for v in range(16):
        row = []
        for u in range(16):
            c = 1 if ((u >> 3) ^ (v >> 3)) & 1 else 0
            if u % 8 == 0 or v % 8 == 0:
                c = 5
            if u % 8 in (3, 4) and v % 8 in (3, 4):
                c = 6 if c == 1 else 3
            row.append(c)
        pages.append(row * 16)
    top = [c << 4 for p in pages for c in p]
    return top + [c for p in pages for c in p]


def tunnel():
    idx = [0] * 2000
    for y in range(50):
        for x in range(40):
            dx = (x - 19.5) * 2.0
            dy = (y - 24.5)
            a = (math.atan2(dy, dx) / (2 * math.pi)) % 1.0
            r = max(0.5, math.hypot(dx, dy))
            d = int(160.0 / r)
            v = (int(a * 32) & 31) << 3 | (d & 7)
            idx[((y // 2) * 40 + x) * 2 + (y & 1)] = v
    tex = []
    for p in range(8):
        page = []
        for v in range(256):
            ang, dep = v >> 3, (v + p) & 7       # depth shifted by p
            c = 1 if ((ang >> 2) ^ (dep >> 2)) & 1 else 0
            if dep == 0:
                c = 5
            if ang % 4 == 0 and c == 1:
                c = 3
            page.append(c)
        tex += [c << 4 for c in page] + page
    hole = []
    for dr in range(-2, 3):
        for dc in range(-4, 4):
            if (dc + 0.5) ** 2 / 16.0 + dr ** 2 / 6.25 <= 1.0:
                hole.append('ABUF+%d' % ((12 + dr) * 40 + 20 + dc))
    hole.append('8000h')
    return idx, tex, hole


def shapes():
    S = []
    # sphere
    pts = []
    for i in range(64):
        y = 1 - 2 * (i + 0.5) / 64
        r = math.sqrt(1 - y * y)
        a = i * math.pi * (3 - math.sqrt(5))
        pts.append((44 * r * math.cos(a), 44 * y, 44 * r * math.sin(a)))
    S.append(pts)
    # cube: corners + 4 points on each edge
    pts = []
    c = [(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    pts += c
    for i, a in enumerate(c):
        for b in c[i + 1:]:
            if sum(p != q for p, q in zip(a, b)) == 1:
                for k in range(1, 5):
                    t = k / 5.0
                    pts.append(tuple(p + (q - p) * t for p, q in zip(a, b)))
    pts += [(0, 0, 0)] * 0 + c                        # 56 + 8 duplicates
    pts = [(31 * x, 31 * y, 31 * z) for x, y, z in pts]
    S.append(pts)
    # torus
    pts = []
    for i in range(16):
        for j in range(4):
            u = i * 2 * math.pi / 16
            v = j * 2 * math.pi / 4 + i * 0.4
            R = 30 + 12 * math.cos(v)
            pts.append((R * math.cos(u), 12 * math.sin(v), R * math.sin(u)))
    S.append(pts)
    # double helix
    pts = []
    for i in range(32):
        a = i * 2 * math.pi / 16
        y = -42 + i * 84 / 31.0
        pts.append((26 * math.cos(a), y, 26 * math.sin(a)))
        pts.append((-26 * math.cos(a), y, -26 * math.sin(a)))
    S.append(pts)
    # the letters MZ, flat
    strokes = [((-44, 28), (-44, -28)), ((-44, -28), (-30, 0)), ((-30, 0), (-16, -28)),
               ((-16, -28), (-16, 28)), ((4, -28), (44, -28)), ((44, -28), (4, 28)),
               ((4, 28), (44, 28))]
    lens = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in strokes]
    tot = sum(lens)
    pts = []
    for (a, b), ln in zip(strokes, lens):
        n = max(2, int(round(64 * ln / tot)))
        for k in range(n):
            t = k / float(n - 1)
            pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 0))
    pts = (pts + pts)[:64] if len(pts) < 64 else pts[:64]
    S.append(pts)
    # star
    pts = []
    for i in range(64):
        a = i * 2 * math.pi / 64
        r = 44 if (i % 8) < 1 else (44 - 26 * min(i % 8, 8 - i % 8) / 4.0)
        pts.append((r * math.cos(a), r * math.sin(a), 10 * math.sin(a * 3)))
    S.append(pts)
    # the start: a small flat ring
    S.append([(6 * math.cos(i * 0.098), 0, 6 * math.sin(i * 0.098)) for i in range(64)])
    out = []
    for pts in S:
        assert len(pts) == 64, len(pts)
        for p in pts:
            assert math.sqrt(sum(v * v for v in p)) < 62, p
            out += [int(round(v)) & 0xFF for v in p]
    proj = [int(round(64 * 220.0 / (220 + (i - 64)))) for i in range(128)]
    assert max(proj) < 128
    return out, proj, len(S)


def centre(text, width=40):
    pad = (width - len(text)) // 2
    return ' ' * pad + text + ' ' * (width - len(text) - pad)


# ---------------------------------------------------------------- main
def gen():
    font = rom_font()
    tri = {}
    tri['a'], _ = find_glyph(font, lambda x, y: x + y >= 7)          # lower right
    tri['b'], _ = find_glyph(font, lambda x, y: x <= y)              # lower left
    tri['c'], _ = find_glyph(font, lambda x, y: x + y <= 7)          # upper left
    tri['d'], _ = find_glyph(font, lambda x, y: x >= y)              # upper right
    print('triangles', {k: hex(v) for k, v in tri.items()})

    m = music.build()
    L = []
    w = L.append
    w('; generated by build.py - do not edit')
    for name, bar in m['starts']:
        w('BAR_%s equ %d' % (name.upper(), bar))
    w('MUS_LOOP equ 0')
    w('NSHAPES equ %d' % shapes()[2])
    w('DOTM equ CBUF')
    w('DOTA equ ABUF')

    # ---- page aligned tables
    w('        ALIGN 256')
    w('SINE:'); w(db(sine()))
    w('QSQ:'); w(db(qsq()))
    w('PALS:')
    for p in PALETTES:
        w(db(palette(p)))
    w('ROTEX:'); w(db(rotex()))
    w('ROTEXB equ ROTEX+4096')
    idx, ttex, hole = tunnel()
    w('TUNTEX:'); w(db(ttex))
    w('TUNIDX:'); w(db(idx))
    w('tun_hole:'); w(dw(hole))

    # ---- logo + texts
    lm, ink = logo(tri)
    w('logo_rowtab:'); w(dw(['logo_row%d' % r for r in range(18)]))
    for r in range(18):
        cells = [(x, lm[r * 40 + x]) for x in range(40) if lm[r * 40 + x]]
        w('logo_row%d: db %d' % (r, len(cells)))
        for x, c in cells:
            w('        dw CBUF+%d' % (r * 40 + x))
            w('        db %d' % c)
    w('logo_arowtab:'); w(dw(['logo_arow%d' % r for r in range(18)]))
    for r in range(18):
        cells = [x for x in range(40) if lm[r * 40 + x]]
        w('logo_arow%d: db %d' % (r, len(cells)))
        if cells:
            w(dw(['ABUF+%d' % (r * 40 + x) for x in cells]))
    w('logo_map:'); w(db(lm, 40))
    w('logo_ink:'); w(db(ink))
    w('title_scroll:'); w(db(disp(TITLE_SCROLL) + [0xFF]))
    w('intro_text:')
    for row, attr, text in INTRO:
        col = (40 - len(text)) // 2
        w('        dw %d' % (row * 40 + col))
        w('        db %d' % attr)
        w(db(disp(text) + [0xFF]))
    w('        dw 0FFFFh')
    w('big_font:'); w(db(big_font()))
    w('greet_text:'); w(db([ord(c) for c in GREETS] + [0]))
    et = []
    for i in range(25):
        et += disp(centre(CREDITS[i] if i < len(CREDITS) else ''))
    w('end_text:'); w(db(et, 40))

    # ---- dots
    sh, proj, n = shapes()
    w('kf_caption:'); w(db(disp(centre('KEFRENS BARS WITHOUT A RASTER INTERRUPT')) + [0xFF]))
    w('rz_cap1:'); w(db(disp(centre('- ROTOZOOMER -')) + [0xFF]))
    w('rz_cap2:'); w(db(disp(centre('40 X 50 PIXELS FROM 1000 ATTRIBUTE BYTES')) + [0xFF]))
    w('dot_shapes:'); w(db(sh, 12))
    pt = []
    for zb in range(16):
        z = zb * 8 - 64 + 4
        f = 64 * 220.0 / (220 + z)
        for i in range(128):
            v = i if i < 64 else i - 128
            pt.append(int(round(v * f / 128.0)) & 0xFF)
    L.insert(L.index('ROTEX:'), 'PROJT:' + NL + db(pt))
    kpos = [int(round(11.5 + 11.5 * math.sin(i * 2 * math.pi / 256))) for i in range(256)]
    kpos2 = [int(round(11.5 + 11.5 * math.sin(i * 2 * math.pi / 128))) for i in range(256)]
    assert max(kpos) + max(kpos2) <= 46
    L.insert(L.index('ROTEX:'), 'KPOS:' + NL + db(kpos) + NL + db(kpos2))
    srow = []
    for a in range(256):
        sv = int(round(127 * math.sin(a * 2 * math.pi / 256)))
        srow.append(40 * [1, 1, 2, 3, 3, 4, 5, 5][(sv + 128) >> 5])
    L.insert(L.index('ROTEX:'), 'TI_SROW:' + NL + db([v & 255 for v in srow]) + NL +
             db([v >> 8 for v in srow]))
    w('dots_names:')
    for nm in DOT_NAMES:
        w(db(disp(centre(nm, 19)) + [0xFF]))
    assert len(DOT_NAMES) == n - 1
    w('dots_title:'); w(db(disp('- VECTOR DOTS -') + [0xFF]))

    # ---- music
    w('mus_periods:'); w(dw(m['periods']))
    w('mus_drums:')
    for cnt, mask, base, keep in m['drums']:
        w('        db %d, %d, %d, %d, %d, %d, 0, 0' % (cnt, mask & 0xFF, mask >> 8,
                                                    base & 0xFF, base >> 8, keep))
    # rows: unique 12-byte rows
    rows = []
    bar_rows = []
    for b in m['bars']:
        ids = []
        for r in range(16):
            row = b[r * 12:r * 12 + 12]
            if row not in rows:
                rows.append(row)
            ids.append(rows.index(row))
        bar_rows.append(ids)
    w('mus_bars:')
    for ids in bar_rows:
        w(dw(['mrow%d' % i for i in ids], 16))
    w('mus_order:'); w(db(m['order'] + [0xFF]))
    for i, row in enumerate(rows):
        w('mrow%d: db %s' % (i, ','.join(str(v) for v in row)))
    print('music: %d bars, %d rows, %d bytes' % (len(m['bars']), len(rows),
                                                 len(rows) * 12 + len(bar_rows) * 32 + len(m['order'])))
    with open(os.path.join(BUILD, 'gen_data.inc'), 'w') as f:
        f.write(NL.join(L) + NL)


def mzf(name, load, data, exe):
    hdr = bytearray(128)
    hdr[0] = 0x01
    fn = name.encode('ascii')[:16] + b'\x0d'
    hdr[1:1 + len(fn)] = fn
    for i in range(1 + len(fn), 18):
        hdr[i] = 0x0d
    hdr[18:20] = len(data).to_bytes(2, 'little')
    hdr[20:22] = load.to_bytes(2, 'little')
    hdr[22:24] = exe.to_bytes(2, 'little')
    return bytes(hdr) + data


def main():
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(REL, exist_ok=True)
    gen()
    asm = os.path.join(TOOLS, 'sjasmplus', 'sjasmplus.exe')
    r = subprocess.run([asm, '--nologo', '--msg=war', '--sym=../build/megademo.sym',
                        '--lst=../build/megademo.lst', 'main.asm'],
                       cwd=SRC, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode:
        sys.exit('assembly failed')
    data = open(os.path.join(BUILD, 'megademo.bin'), 'rb').read()
    print('%d bytes, 1200h-%04Xh' % (len(data), LOAD + len(data) - 1))
    with open(os.path.join(BUILD, 'MEGADEMO_RAW.MZT'), 'wb') as f:
        f.write(mzf(TAPE_NAME, LOAD, data, LOAD))
    # crunch: the stub unpacks in place from the top of RAM
    packed = crunch.pack(data)
    assert crunch.unpack(packed) == data
    assert crunch.check_in_place(packed, LOAD, 0xD000 - len(packed)), 'packed data overlaps'
    with open(os.path.join(BUILD, 'megademo.pak'), 'wb') as f:
        f.write(packed)
    r = subprocess.run([asm, '--nologo', '--msg=war', '--sym=../build/stub.sym', 'stub.asm'],
                       cwd=SRC, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode:
        sys.exit('stub assembly failed')
    data = open(os.path.join(BUILD, 'stub.bin'), 'rb').read()
    print('tape file: %d bytes after crunching' % len(data))
    out = mzf(TAPE_NAME, LOAD, data, LOAD)
    for d in (BUILD, REL):
        for ext in ('MZT', 'MZF'):
            with open(os.path.join(d, NAME + '.' + ext), 'wb') as f:
                f.write(out)


if __name__ == '__main__':
    main()
