"""glyphs.py - print glyphs as ASCII art.   py tools/glyphs.py 030-03F 1A0-1AF"""
import os
import sys

ROM = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'rom', 'mz700fon.int'), 'rb').read()


def rows(g):
    return [''.join('#' if (ROM[g * 8 + y] >> x) & 1 else '.' for x in range(8)) for y in range(8)]


for spec in sys.argv[1:]:
    a, b = (int(x, 16) for x in spec.split('-'))
    for base in range(a, b + 1, 8):
        gs = list(range(base, min(base + 8, b + 1)))
        print('   '.join('%03X     ' % g for g in gs))
        R = [rows(g) for g in gs]
        for y in range(8):
            print('   '.join(r[y] for r in R))
        print()
