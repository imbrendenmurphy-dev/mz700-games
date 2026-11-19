"""glyphtest.py - mock up candidate tile glyphs/colours (build/glyphtest.png)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mzfont as F  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (label, [(glyph, fg, bg), ...])  glyph >= 256 = bank 1
ROWS = [
    ('dirt', [(0xA6, F.RED, F.BLACK), (0xD0, F.RED, F.BLACK), (0x1EE, F.RED, F.BLACK), (0x1EF, F.YELLOW, F.RED),
              (0xA6, F.MAGENTA, F.RED), (0xD0, F.YELLOW, F.RED), (0x1EE, F.YELLOW, F.RED), (0xFF, F.RED, F.BLACK),
              (0x1B7, F.RED, F.BLACK), (0x137, F.RED, F.BLACK), (0xDE, F.RED, F.BLACK)]),
    ('brick', [(0x1B7, F.WHITE, F.RED), (0x177, F.RED, F.WHITE), (0x63, F.WHITE, F.RED), (0x1A1, F.WHITE, F.RED),
               (0x172, F.WHITE, F.RED), (0x1B4, F.RED, F.WHITE), (0x1B4, F.WHITE, F.RED), (0xA3, F.RED, F.WHITE),
               (0x187, F.WHITE, F.RED), (0x1F6, F.WHITE, F.RED)]),
    ('steel', [(0x18B, F.CYAN, F.BLUE), (0x187, F.WHITE, F.BLUE), (0x18A, F.CYAN, F.BLUE), (0x1B4, F.CYAN, F.BLUE),
               (0x1B1, F.WHITE, F.BLUE), (0x186, F.CYAN, F.BLUE), (0x1F6, F.CYAN, F.BLUE)]),
    ('boulder', [(0x14F, F.WHITE, F.BLACK), (0x14E, F.WHITE, F.BLACK), (0x150, F.WHITE, F.BLACK),
                 (0x13E, F.WHITE, F.BLACK), (0x47, F.WHITE, F.BLACK), (0x14F, F.YELLOW, F.BLACK),
                 (0x14F, F.MAGENTA, F.BLACK), (0x14F, F.CYAN, F.BLACK)]),
    ('diamond', [(0x44, F.CYAN, F.BLACK), (0x44, F.WHITE, F.BLACK), (0x6B, F.WHITE, F.BLACK),
                 (0x44, F.YELLOW, F.BLACK), (0x44, F.MAGENTA, F.BLACK), (0x1BF, F.CYAN, F.BLACK),
                 (0x1A6, F.CYAN, F.BLACK), (0x19D, F.CYAN, F.BLACK)]),
    ('player', [(0xC6, F.YELLOW, F.BLACK), (0x143, F.YELLOW, F.BLACK), (0x144, F.YELLOW, F.BLACK),
                (0x145, F.YELLOW, F.BLACK), (0x146, F.YELLOW, F.BLACK), (0x147, F.YELLOW, F.BLACK),
                (0x148, F.YELLOW, F.BLACK), (0xC6, F.WHITE, F.BLACK)]),
    ('firefly', [(0x1B1, F.YELLOW, F.BLACK), (0x1B2, F.YELLOW, F.BLACK), (0x18B, F.YELLOW, F.BLACK),
                 (0x187, F.RED, F.BLACK), (0xF9, F.YELLOW, F.BLACK), (0xF6, F.YELLOW, F.BLACK),
                 (0x186, F.YELLOW, F.BLACK), (0x18C, F.YELLOW, F.BLACK)]),
    ('butterfly', [(0xCB, F.MAGENTA, F.BLACK), (0xCC, F.MAGENTA, F.BLACK), (0xCB, F.CYAN, F.BLACK),
                   (0xCC, F.WHITE, F.BLACK), (0x1A3, F.MAGENTA, F.BLACK), (0x1BB, F.MAGENTA, F.BLACK)]),
    ('amoeba', [(0x19F, F.GREEN, F.BLACK), (0x1B3, F.GREEN, F.BLACK), (0xDF, F.GREEN, F.BLACK),
                (0x1EF, F.GREEN, F.BLACK), (0x1EE, F.GREEN, F.BLACK), (0xA6, F.GREEN, F.BLACK),
                (0x137, F.GREEN, F.BLACK)]),
    ('exit', [(0x18B, F.WHITE, F.BLUE), (0x188, F.WHITE, F.BLACK), (0xC5, F.WHITE, F.BLACK),
              (0x18A, F.YELLOW, F.BLUE), (0x16C, F.WHITE, F.BLACK)]),
    ('boom', [(0x6B, F.WHITE, F.RED), (0x1B3, F.YELLOW, F.RED), (0x137, F.WHITE, F.BLACK),
              (0xA6, F.RED, F.BLACK), (0x19F, F.YELLOW, F.RED), (0x6E, F.YELLOW, F.BLACK)]),
]


def main():
    cols, rows = 40, len(ROWS) * 2 + 1
    ch = [0] * (cols * rows)
    at = [0] * (cols * rows)
    for r, (label, cands) in enumerate(ROWS):
        y = r * 2 + 1
        for i, c in enumerate(F.text_codes(label)):
            ch[y * cols + i] = c
            at[y * cols + i] = 0x70
        for k, (g, fg, bg) in enumerate(cands):
            # a 3x1 strip of the tile so texture shows
            for dx in range(3):
                x = 10 + k * 3 + dx
                if x < cols:
                    ch[y * cols + x] = g & 0xFF
                    at[y * cols + x] = F.attr(g, fg, bg)
    F.render_cells(ch, at, cols, rows, scale=3).save(os.path.join(ROOT, 'build', 'glyphtest.png'))


main()
