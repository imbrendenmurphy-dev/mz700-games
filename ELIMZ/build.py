"""build.py - builds STARHAUL for the Sharp MZ-700.

    py build.py

Generates build/gen_*.inc (lookup tables, ship models, music), assembles
src/main.asm with sjasmplus and writes build/STARHAUL.MZT (emulators) plus
an identical STARHAUL.MZF (UniCMT / real hardware); both go to release/.
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

NAME = 'STARHAUL'
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


def gen_models():
    out = ['; generated by build.py - wireframe models',
           '; db nverts, nedges, radius / verts (x,y,z) / edges (i*2, j*2)']
    for name, fn, rad in MODELS:
        v, e = fn()
        for p in v:
            assert math.sqrt(sum(c * c for c in p)) <= 122, (name, p)
        assert len(v) <= 24
        out.append('%s:' % name)
        out.append('        db %d,%d,%d' % (len(v), len(e), rad))
        out.append(db_lines([c for p in v for c in p], 15))
        out.append(db_lines([k * 2 for ed in e for k in ed]))
    return NL.join(out) + NL


# ---------------------------------------------------------------- tables
def gen_tables():
    out = ['; generated by build.py', '        align 256', 'ATOD:', db_lines(atod()),
           '        align 256', 'NOTETAB:']
    nt = music.notetab()
    for i in range(0, 128, 8):
        out.append('        dw ' + ','.join('%d' % v for v in nt[i:i + 8]))
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
    out += ['TITLEFONT:', db_lines(font3_bytes('STARHAUL'))]
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
    r = subprocess.run([asm, '--nologo', '--msg=war', '--sym=../build/starhaul.sym',
                        '--lst=../build/starhaul.lst', 'main.asm'],
                       cwd=SRC, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode:
        sys.exit('assembly failed')
    data = open(os.path.join(BUILD, 'starhaul.bin'), 'rb').read()
    out = mzf(NAME, LOAD, data, LOAD)
    for d in (BUILD, REL):
        for ext in ('MZT', 'MZF'):
            with open(os.path.join(d, NAME + '.' + ext), 'wb') as f:
                f.write(out)
    print('%s: binary %d bytes (%04X-%04X)' % (NAME, len(data), LOAD, LOAD + len(data) - 1))


if __name__ == '__main__':
    main()
