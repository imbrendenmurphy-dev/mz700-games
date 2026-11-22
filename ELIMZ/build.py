"""build.py - builds ARGOSY for the Sharp MZ-700.

    py build.py

Generates build/gen_*.inc (lookup tables, ship models, music), assembles
src/main.asm with sjasmplus and writes build/ARGOSY.MZT (emulators) plus
an identical ARGOSY.MZF (UniCMT / real hardware); both go to release/.
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
import galaxy  # noqa: E402

NAME = 'ARGOSY'
LOAD = 0x1200
NL = chr(10)


def db_lines(vals, per=16):
    return NL.join('        db ' + ','.join('%d' % (v & 0xFF) for v in vals[i:i + per])
                   for i in range(0, len(vals), per))


def dw_lines(vals, per=8):
    return NL.join('        dw ' + ','.join('%s' % v for v in vals[i:i + per])
                   for i in range(0, len(vals), per))


# ---------------------------------------------------------------- text
ASCII = {' ': 0x00, '!': 0x61, '"': 0x62, '#': 0x63, '$': 0x64, '%': 0x65, '&': 0x66, "'": 0x67,
         '(': 0x68, ')': 0x69, '+': 0x6A, '*': 0x6B, ',': 0x2F, '-': 0x2A, '.': 0x2E, '/': 0x2D,
         ':': 0x4F, ';': 0x2C, '=': 0x2B, '?': 0x49, '<': 0x51, '>': 0x57, '[': 0x52, ']': 0x54}


def atod():
    t = [0] * 256
    for c in range(256):
        ch = chr(c)
        if 'A' <= ch <= 'Z':
            t[c] = c - 64
        elif 'a' <= ch <= 'z':
            t[c] = c - 96 + 0x80
        elif '0' <= ch <= '9':
            t[c] = 0x20 + c - 48
        elif ch in ASCII:
            t[c] = ASCII[ch]
        elif c >= 0x80:
            t[c] = c
    return t


# ---------------------------------------------------------------- 3x5 title font
FONT3 = {
    'A': ['###', '#.#', '###', '#.#', '#.#'], 'H': ['#.#', '#.#', '###', '#.#', '#.#'],
    'L': ['#..', '#..', '#..', '#..', '###'], 'R': ['##.', '#.#', '##.', '#.#', '#.#'],
    'S': ['###', '#..', '###', '..#', '###'], 'T': ['###', '.#.', '.#.', '.#.', '.#.'],
    'U': ['#.#', '#.#', '#.#', '#.#', '###'], ' ': ['...'] * 5,
}


# the title logo: letters 5 x 5 cells in CG-ROM block glyphs, bold with
# cut corners.  # full block, L R lower-left / lower-right triangles,
# l r upper-left / upper-right, ^ _ upper / lower half block.
LOGO_GLYPH = {'#': 0x43, 'L': 0x4D, 'R': 0x4E, 'l': 0x56, 'r': 0x42, '^': 0x7A, '_': 0x3A, ' ': 0}
LOGO_FONT = {
    'A': [' R#L ', 'R# #L', '#####', '#   #', '#   #'],
    'R': ['####L', '#   #', '####l', '# r#L', '#  r#'],
    'G': ['R###^', '#    ', '# ###', '#   #', 'r###l'],
    'O': ['R###L', '#   #', '#   #', '#   #', 'r###l'],
    'S': ['R###^', '#    ', 'r###L', '    #', '_###l'],
    'Y': ['#   #', 'r# #l', ' r#l ', '  #  ', '  #  '],
}


def logo_cells(word):
    """5 rows of 6-cell letters (a gap after each): glyph codes, row by row"""
    out = []
    for r in range(5):
        for ch in word:
            out += [LOGO_GLYPH[c] for c in LOGO_FONT[ch][r]] + [0]
    return out


def font3_bytes(word):
    out = []
    for ch in word:
        g = FONT3[ch]
        for row in g:
            out.append(sum(1 << (2 - i) for i, c in enumerate(row) if c == '#'))
    return out


# ---------------------------------------------------------------- ship models
# vertices in model units (x right, y up, z = nose), |v| <= 120
def hexring(z, r, n=6, phase=0.0):
    return [(round(r * math.cos(phase + 2 * math.pi * i / n)), round(r * math.sin(phase + 2 * math.pi * i / n)), z)
            for i in range(n)]


def station():
    front = hexring(60, 92, phase=math.pi / 6)
    back = hexring(-60, 92, phase=math.pi / 6)
    hub = hexring(-60, 40, phase=math.pi / 6)
    slot = [(-40, -16, 60), (40, -16, 60), (40, 16, 60), (-40, 16, 60)]
    v = front + back + hub + slot
    e = []
    for i in range(6):
        e += [(i, (i + 1) % 6), (6 + i, 6 + (i + 1) % 6), (i, 6 + i), (12 + i, 12 + (i + 1) % 6)]
    e += [(18, 19), (19, 20), (20, 21), (21, 18)]
    return v, e


def dart():
    v = [(0, 0, 70), (-56, -4, -34), (56, -4, -34), (0, 22, -30), (0, -12, -34), (-18, 4, -34), (18, 4, -34)]
    e = [(0, 1), (0, 2), (0, 3), (0, 4), (1, 3), (2, 3), (1, 4), (2, 4), (5, 6)]
    return v, e


def mantis():
    v = [(-34, 0, 64), (34, 0, 64), (0, 0, 20), (-26, 14, -44), (26, 14, -44), (26, -14, -44), (-26, -14, -44),
         (0, 24, -20)]
    e = [(0, 2), (1, 2), (0, 3), (0, 6), (1, 4), (1, 5), (3, 4), (4, 5), (5, 6), (6, 3), (2, 7), (3, 7), (4, 7)]
    return v, e


def hauler():
    v = [(-36, -24, -70), (36, -24, -70), (36, 24, -70), (-36, 24, -70),
         (-36, -24, 40), (36, -24, 40), (36, 24, 40), (-36, 24, 40),
         (-20, -12, 72), (20, -12, 72), (20, 12, 72), (-20, 12, 72)]
    e = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7),
         (8, 9), (9, 10), (10, 11), (11, 8), (4, 8), (5, 9), (6, 10), (7, 11)]
    return v, e


def warden():
    v = [(0, 0, 66), (-44, 0, -18), (44, 0, -18), (0, 0, -46), (0, 18, -12), (-44, 0, 34), (44, 0, 34)]
    e = [(0, 1), (0, 2), (1, 3), (2, 3), (4, 0), (4, 1), (4, 2), (4, 3), (1, 5), (2, 6)]
    return v, e


def seeker():
    v = [(0, 0, 26), (-7, -7, -18), (7, -7, -18), (7, 7, -18), (-7, 7, -18)]
    e = [(0, 1), (0, 2), (0, 3), (0, 4), (1, 2), (2, 3), (3, 4), (4, 1)]
    return v, e


def raptor():
    v = [(0, 0, 90), (-100, 0, -40), (100, 0, -40), (0, 0, -50), (0, 26, -20), (0, -16, -30),
         (-40, 0, -60), (40, 0, -60)]
    e = [(0, 1), (0, 2), (1, 6), (6, 3), (3, 7), (7, 2), (4, 0), (4, 1), (4, 2), (4, 3), (5, 0), (5, 1), (5, 2)]
    return v, e


def rock():
    v = [(0, 62, 4), (4, -56, -6), (58, 2, 10), (-60, 6, -8), (8, -6, 64), (-10, 4, -58),
         (36, 38, 30), (-34, 36, -38), (40, -36, -34), (-38, -40, 34)]
    e = [(0, 2), (0, 3), (0, 4), (0, 5), (1, 2), (1, 3), (1, 4), (1, 5), (2, 4), (4, 3), (3, 5), (5, 2),
         (6, 0), (6, 2), (6, 4), (7, 0), (7, 3), (7, 5), (8, 1), (8, 2), (8, 5), (9, 1), (9, 3), (9, 4)]
    return v, e


def canister():
    c = 14
    v = [(x, y, z) for z in (-c, c) for (x, y) in ((-c, -c), (c, -c), (c, c), (-c, c))]
    e = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]
    return v, e


MODELS = [('MDL_STATION', station, 120), ('MDL_DART', dart, 72), ('MDL_MANTIS', mantis, 76),
          ('MDL_RAPTOR', raptor, 110), ('MDL_HAULER', hauler, 100), ('MDL_WARDEN', warden, 70),
          ('MDL_ROCK', rock, 66), ('MDL_SEEKER', seeker, 30), ('MDL_CANISTER', canister, 26)]


def hull_planes(v):
    """the planes of the convex hull: [(unit normal, d)], outward"""
    import itertools
    cx = [sum(p[a] for p in v) / len(v) for a in range(3)]
    planes = []
    for i, j, k in itertools.combinations(range(len(v)), 3):
        a, b_, c = v[i], v[j], v[k]
        u = [b_[t] - a[t] for t in range(3)]
        w = [c[t] - a[t] for t in range(3)]
        n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
        ln = math.sqrt(sum(x * x for x in n))
        if ln < 1e-6:
            continue
        n = [x / ln for x in n]
        d = sum(n[t] * a[t] for t in range(3))
        if sum(n[t] * cx[t] for t in range(3)) > d:
            n = [-x for x in n]
            d = -d
        if any(sum(n[t] * p[t] for t in range(3)) > d + 0.5 for p in v):
            continue                            # not a hull plane
        if any(abs(d - d2) < 0.5 and sum(x * y for x, y in zip(n, n2)) > 0.9999 for n2, d2 in planes):
            continue
        planes.append((n, d))
    return planes


def model_faces(v, e):
    """faces as (nx, ny, nz bytes at unit 64, d = n.v0 word) and, per edge,
    the (up to two) faces it lies on; FF = none (always drawn)"""
    planes = hull_planes(v)
    faces = []
    for n, d in planes:
        nb = [round(x * 64) for x in n]
        faces.append((nb, round(d * 64)))
    ef = []
    for i, j in e:
        on = [k for k, (n, d) in enumerate(planes)
              if all(abs(sum(n[t] * v[q][t] for t in range(3)) - d) < 1.0 for q in (i, j))]
        on = (on + [0xFF, 0xFF])[:2]
        ef.append(on)
    return faces, ef


def gen_models():
    out = ['; generated by build.py - wireframe models',
           '; db nverts, nedges, radius / verts (x,y,z) / edges (i*2, j*2)',
           '; then db nfaces / faces: nx, ny, nz (unit 64), dw d = n.v (model',
           '; units * 64) / per edge: the two faces it lies on (FF = none)']
    for name, fn, rad in MODELS:
        v, e = fn()
        for p in v:
            assert math.sqrt(sum(c * c for c in p)) <= 122, (name, p)
        assert len(v) <= 24
        faces, ef = model_faces(v, e)
        assert len(faces) <= 32, (name, len(faces))
        out.append('%s:' % name)
        out.append('        db %d,%d,%d' % (len(v), len(e), rad))
        out.append(db_lines([c for p in v for c in p], 15))
        out.append(db_lines([k * 2 for ed in e for k in ed]))
        out.append('        db %d' % len(faces))
        for nb, d in faces:
            out.append('        db %d,%d,%d' % tuple(x & 0xFF for x in nb))
            out.append('        dw %d' % (d & 0xFFFF))
        out.append(db_lines([f for pair in ef for f in pair]))
    return NL.join(out) + NL


# ---------------------------------------------------------------- tables
def gen_tables():
    out = ['; generated by build.py', '        align 256', 'ATOD:', db_lines(atod())]
    # quarter squares: f(n - 256) = (n-256)^2 / 4, n = 0..511 ; lo bytes then hi bytes
    q = [((n - 256) * (n - 256)) // 4 for n in range(512)]
    out += ['        align 256', 'QSQLO:', db_lines([v & 255 for v in q]),
            'QSQHI:', db_lines([v >> 8 for v in q])]
    # pixel row tables (36 rows, PIX stride 64): YLO page, YHI page
    ylo = [0] * 256
    yhi = [0] * 256
    for y in range(36):
        a = 0xA000 + (y >> 1) * 64
        ylo[y] = a & 255
        yhi[y] = a >> 8
    out += ['        align 256', 'YLO:', db_lines(ylo), 'YHI:', db_lines(yhi)]
    out += ['LOGO:', db_lines(logo_cells('ARGOSY'))]
    # the title's spinning ship: 64 orientations (side, roof, nose; unit
    # 4000h), a turn about the vertical, seen from a little above
    spin = []
    th = math.radians(22)
    for k in range(64):
        an = 2 * math.pi * k / 64
        c, s_ = math.cos(an), math.sin(an)
        for x, y, z in ((c, 0, -s_), (0, 1, 0), (s_, 0, c)):
            y2 = y * math.cos(th) - z * math.sin(th)
            z2 = y * math.sin(th) + z * math.cos(th)
            spin += [round(v * 0x4000) & 0xFFFF for v in (x, y2, z2)]
    out += ['SPIN:', db_lines([(v >> 8) & 255 for v in spin], 9)]
    # explosion particle offsets (-8..8)
    import random
    rnd = random.Random(7)
    parts = []
    for i in range(16):
        a = rnd.random() * 2 * math.pi
        r = 3 + rnd.random() * 5
        parts += [round(r * math.cos(a)), round(r * math.sin(a))]
    out += ['DEBRIS:', db_lines(parts)]
    return NL.join(out) + NL


# ---------------------------------------------------------------- output
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

    def write(name, text):
        with open(os.path.join(BUILD, name), 'w') as f:
            f.write(text)

    write('gen_tables.inc', gen_tables())
    write('gen_models.inc', gen_models())
    write('gen_galaxy.inc', galaxy.gen_asm(db_lines)[0])
    write('gen_music.inc', music.gen_asm())
    asm = os.path.join(TOOLS, 'sjasmplus', 'sjasmplus.exe')
    r = subprocess.run([asm, '--nologo', '--msg=war', '--sym=../build/argosy.sym',
                        '--lst=../build/argosy.lst', 'main.asm'],
                       cwd=SRC, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode:
        sys.exit('assembly failed')
    data = open(os.path.join(BUILD, 'argosy.bin'), 'rb').read()
    out = mzf(NAME, LOAD, data, LOAD)
    for d in (BUILD, REL):
        for ext in ('MZT', 'MZF'):
            with open(os.path.join(d, NAME + '.' + ext), 'wb') as f:
                f.write(out)
    print('%s: binary %d bytes (%04X-%04X)' % (NAME, len(data), LOAD, LOAD + len(data) - 1))


if __name__ == '__main__':
    main()
