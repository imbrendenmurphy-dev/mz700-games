"""build.py - builds ZENITH for the Sharp MZ-700.

    py build.py

Generates build/gen_*.inc (lookup tables, sprites, music), assembles
src/main.asm with sjasmplus and writes build/ZENITH.MZT (emulators) plus
an identical ZENITH.MZF (UniCMT / real hardware); both go to release/.
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

NAME = 'ZENITH'
LOAD = 0x1200
NL = chr(10)

KX = 64                 # columns per sub-cell of sideways offset at depth 1
NSTEP = 102


def db_lines(vals, per=16):
    return NL.join('        db ' + ','.join('%d' % (v & 0xFF) for v in vals[i:i + per])
                   for i in range(0, len(vals), per))


def dw_lines(vals, per=8):
    return NL.join('        dw ' + ','.join('%d' % (v & 0xFFFF) for v in vals[i:i + per])
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
    'Z': ['###', '..#', '.#.', '#..', '###'], 'E': ['###', '#..', '##.', '#..', '###'],
    'N': ['#.#', '###', '###', '###', '#.#'], 'I': ['###', '.#.', '.#.', '.#.', '###'],
    'T': ['###', '.#.', '.#.', '.#.', '.#.'], 'H': ['#.#', '#.#', '###', '#.#', '#.#'],
}


def font3_bytes(word):
    out = []
    for ch in word:
        for row in FONT3[ch]:
            out.append(sum(1 << (2 - i) for i, c in enumerate(row) if c == '#'))
    return out


# ---------------------------------------------------------------- view geometry
def step_z():
    zs = [1 + 0.5 * i for i in range(31)]                 # 0..30   z 1..16
    zs += [16 + (i - 30) for i in range(31, 63)]          # 31..62  z 17..48
    zs += [48 + 2 * (i - 62) for i in range(63, NSTEP)]   # 63..101 z 50..126
    assert len(zs) == NSTEP
    return zs


ZS = step_z()


def step_s():
    out = []
    for i, z in enumerate(ZS):
        s = round(128 / z) if i <= 30 else round(2048 / z)
        assert 1 <= s <= 128
        out.append(s)
    return out


def zstep():
    """sub-cell depth (int) -> first step index at or beyond it"""
    t = []
    for zi in range(256):
        k = next((i for i, z in enumerate(ZS) if z >= zi), NSTEP - 1)
        t.append(k)
    return t


def dirtab():
    """per heading: dx0, dy0, ddx, ddy (column ray directions), Fx, Fy, Rx, Ry - 4.12 fixed"""
    out = []
    for h in range(32):
        a = h * 2 * math.pi / 32
        fx, fy = math.sin(a), -math.cos(a)
        rx, ry = -fy, fx
        dx0 = fx + rx * (-39.5 / KX)
        dy0 = fy + ry * (-39.5 / KX)
        out += [round(dx0 * 4096), round(dy0 * 4096), round(rx / KX * 4096), round(ry / KX * 4096),
                round(fx * 4096), round(fy * 4096), round(rx * 4096), round(ry * 4096)]
    return out


# ---------------------------------------------------------------- sprites
# Drawn at reference depth z = 8 sub-cells (scale 8/z).  Digits are MZ
# colours, '.' transparent, 'L' the lantern's lamp colour (lamp_col).
SPRITES = {
    'SPR_SHARD': ['..7..',
                  '.757.',
                  '75557',
                  '.555.',
                  '.515.',
                  '..5..',
                  '..1..'],
    'SPR_CAIRN': ['6666666666',
                  '6222622262',
                  '2222222222',
                  '2262222622'],
    'SPR_SHELL': ['..77..',
                  '.7557.',
                  '.7557.',
                  '..77..',
                  '.7777.',
                  '777777',
                  '.7777.',
                  '.7..7.',
                  '.7..7.'],
    'SPR_LANTERN': ['..LLL..',
                    '.LL7LL.',
                    '..LLL..',
                    '...7...',
                    '..727..',
                    '..777..',
                    '..272..',
                    '..777..',
                    '.72227.',
                    '.77777.',
                    '.72227.',
                    '.77777.',
                    '7222227',
                    '7777777',
                    '7222227',
                    '7777777'],
    'SPR_WISP': ['.3.3.',
                 '33333',
                 '.373.',
                 '33333',
                 '.3.3.'],
}


def gen_sprites():
    out = ['; generated by build.py - sprites: db w, h / rows of colour bytes (8 = clear, 9 = lamp)']
    for name, rows in SPRITES.items():
        w, h = len(rows[0]), len(rows)
        assert all(len(r) == w for r in rows), name
        out.append('%s:' % name)
        out.append('        db %d,%d' % (w, h))
        data = []
        for r in rows:
            for ch in r:
                data.append(8 if ch == '.' else 9 if ch == 'L' else int(ch))
        out.append(db_lines(data))
    return NL.join(out) + NL


# ---------------------------------------------------------------- tables
def gen_tables():
    out = ['; generated by build.py', '        align 256', 'ATOD:', db_lines(atod()),
           '        align 256', 'NOTETAB:']
    nt = music.notetab()
    for i in range(0, 128, 8):
        out.append('        dw ' + ','.join('%d' % v for v in nt[i:i + 8]))
    q = [(n * n) // 4 for n in range(256)]
    out += ['        align 256', 'QLO:', db_lines([v & 255 for v in q]),
            'QHI:', db_lines([v >> 8 for v in q])]
    out += ['ZSTEP:', db_lines(zstep())]
    out += ['STEPS_S:', db_lines(step_s())]
    out += ['DIRTAB:', dw_lines(dirtab())]
    out += ['TITLEFONT:', db_lines(font3_bytes('ZENITH'))]
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
    write('gen_sprites.inc', gen_sprites())
    write('gen_music.inc', music.gen_asm())
    asm = os.path.join(TOOLS, 'sjasmplus', 'sjasmplus.exe')
    r = subprocess.run([asm, '--nologo', '--msg=war', '--sym=../build/zenith.sym',
                        '--lst=../build/zenith.lst', 'main.asm'],
                       cwd=SRC, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode:
        sys.exit('assembly failed')
    data = open(os.path.join(BUILD, 'zenith.bin'), 'rb').read()
    out = mzf(NAME, LOAD, data, LOAD)
    for d in (BUILD, REL):
        for ext in ('MZT', 'MZF'):
            with open(os.path.join(d, NAME + '.' + ext), 'wb') as f:
                f.write(out)
    print('%s: binary %d bytes (%04X-%04X)' % (NAME, len(data), LOAD, LOAD + len(data) - 1))


if __name__ == '__main__':
    main()
