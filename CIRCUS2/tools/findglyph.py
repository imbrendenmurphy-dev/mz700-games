"""findglyph.py - best CG-ROM matches for 8x8 target shapes (used while designing tiles)."""
import sys
import mzfont

ALL = [mzfont.glyph_bits(g) for g in range(512)]


def best(target, n=6):
    t = [[1 if ch == '#' else 0 for ch in row] for row in target]
    sc = []
    for g in range(512):
        b = ALL[g]
        d = sum(b[y][x] != t[y][x] for y in range(8) for x in range(8))
        sc.append((d, g))
    sc.sort()
    return sc[:n]


def disc(cx, cy, r):
    return [''.join('#' if (x + .5 - cx) ** 2 + (y + .5 - cy) ** 2 <= r * r else '.' for x in range(8)) for y in range(8)]


if __name__ == '__main__':
    r = float(sys.argv[1]) if len(sys.argv) > 1 else 7.5
    for name, (cx, cy) in (('TL', (8, 8)), ('TR', (0, 8)), ('BL', (8, 0)), ('BR', (0, 0))):
        print(name, ['%03X:%d' % (g, d) for d, g in best(disc(cx, cy, r))])
