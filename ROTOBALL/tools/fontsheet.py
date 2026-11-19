"""fontsheet.py - draws all 512 glyphs of an MZ-700 CG-ROM image as a labelled PNG.

    py tools/fontsheet.py font.rom out.png
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mzsim import write_png  # noqa: E402

DIGITS = {
    '0': ['111', '101', '101', '101', '111'], '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'], '3': ['111', '001', '111', '001', '111'],
    '4': ['101', '101', '111', '001', '001'], '5': ['111', '100', '111', '001', '111'],
    '6': ['111', '100', '111', '101', '111'], '7': ['111', '001', '010', '010', '010'],
    '8': ['111', '101', '111', '101', '111'], '9': ['111', '101', '111', '001', '111'],
    'A': ['010', '101', '111', '101', '101'], 'B': ['110', '101', '110', '101', '110'],
    'C': ['011', '100', '100', '100', '011'], 'D': ['110', '101', '101', '101', '110'],
    'E': ['111', '100', '110', '100', '111'], 'F': ['111', '100', '110', '100', '100'],
}


def main():
    raw = open(sys.argv[1], 'rb').read()
    cell = 12
    W, H = 2 * (16 * cell + 10) + 20, 16 * cell + 10
    pix = bytearray([40] * (W * H * 3))

    def put(x, y, c):
        i = (y * W + x) * 3
        pix[i:i + 3] = bytes(c)

    def text(x, y, s, c=(255, 200, 0)):
        for ch in s:
            for r, row in enumerate(DIGITS[ch]):
                for k, b in enumerate(row):
                    if b == '1':
                        put(x + k, y + r, c)
            x += 4

    for bank in range(2):
        ox = 10 + bank * (16 * cell + 20)
        for n in range(16):
            text(ox + n * cell + 3, 2, '%X' % n)
            text(ox - 8 if bank == 0 else ox - 6, 10 + n * cell + 2, '%X' % n)
        for code in range(256):
            g = raw[(bank * 256 + code) * 8:(bank * 256 + code) * 8 + 8]
            cx = ox + (code & 15) * cell
            cy = 10 + (code >> 4) * cell
            for y in range(8):
                for x in range(8):
                    on = (g[y] >> x) & 1          # bit 0 = leftmost pixel
                    put(cx + x, cy + y, (255, 255, 255) if on else (0, 0, 90))
    write_png(sys.argv[2], W, H, pix, 3)


if __name__ == '__main__':
    main()
