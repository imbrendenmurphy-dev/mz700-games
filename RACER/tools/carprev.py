"""carprev.py - the player's car frames over road and grass -> build/car.png"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art
HERE = os.path.dirname(os.path.abspath(__file__))
rom = open(os.path.join(HERE, '..', 'rom', 'mz700fon.int'), 'rb').read()
PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255), (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
S = 4
frames = [art.car_cells(art.car_shift(art.CARPIC, d), rom) for d in (0, -2, 2)]
im = Image.new('RGB', (3 * (14 * 8 * S) + 40, 2 * 6 * 8 * S + 20), (40, 40, 40))
px = im.load()
for fi, fr in enumerate(frames):
    for ui, under in enumerate((0, 4)):
        ox, oy = fi * (14 * 8 * S + 20), ui * (6 * 8 * S + 20)
        for r in range(6):
            for c in range(14):
                g, fg, bg = 0x7A, under, under
                if 1 <= r <= 4 and 1 <= c <= 12:
                    cell = fr[r - 1][c - 1]
                    if cell:
                        g, fg, bg = cell
                        bg = under if bg == 't' else bg
                for y in range(8):
                    b = rom[g * 8 + y]
                    for x in range(8):
                        col = PAL[fg if (b >> x) & 1 else bg]
                        for sy in range(S):
                            for sx in range(S):
                                px[ox + (c * 8 + x) * S + sx, oy + (r * 8 + y) * S + sy] = col
im.save(os.path.join(HERE, '..', 'build', 'car.png'))
