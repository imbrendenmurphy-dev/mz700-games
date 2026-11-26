"""logo_mocks.py - alternative title logo styles, rendered with the real
CG-ROM (build/logo_mocks.png).  Every cell is a genuine MZ-700 glyph with
one foreground and one background colour, so each mock-up can be built.

    py tools/logo_mocks.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mzfont  # noqa: E402
import logo  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
K, B, R, M, G, C, Y, W = range(8)
TRI = {'tl': 0x56, 'tr': 0x42, 'bl': 0x4D, 'br': 0x4E}


def pixels(art=None):
    art = art or logo.ART
    return {(x, y) for y, r in enumerate(art) for x, c in enumerate(r) if c == '#'}


def to_cells(S, w=None, h=None):
    """sub-pixel set -> {(cx, cy): glyph} using logo.cell_glyph"""
    w = w or max(x for x, _ in S) + 1
    h = h or max(y for _, y in S) + 1
    out = {}
    for cy in range((h + 1) // 2):
        for cx in range((w + 1) // 2):
            q = [(2 * cx, 2 * cy) in S, (2 * cx + 1, 2 * cy) in S, (2 * cx, 2 * cy + 1) in S,
                 (2 * cx + 1, 2 * cy + 1) in S]
            g = logo.cell_glyph(*[int(v) for v in q])
            if g is not None:
                out[(cx, cy)] = g
    return out


class Screen:
    def __init__(self, rows=12):
        self.rows = rows
        self.ch = [0] * (40 * rows)
        self.at = [0] * (40 * rows)

    def put(self, x, y, g, fg, bg=0):
        if 0 <= x < 40 and 0 <= y < self.rows:
            self.ch[y * 40 + x] = g & 255
            self.at[y * 40 + x] = ((g >> 8) << 7) | (fg << 4) | bg

    def text(self, y, s, fg):
        x = (40 - len(s)) // 2
        for i, c in enumerate(mzfont.text_codes(s)):
            self.put(x + i, y, c, fg)

    def image(self):
        return mzfont.render_cells(self.ch, self.at, rows=self.rows, scale=2)


def placed(cells, top):
    w = max(x for x, _ in cells) + 1
    x0 = (40 - w) // 2
    return {(x + x0, y + top): g for (x, y), g in cells.items()}


def bands(y, top, h, cols):
    k = (y - top) * len(cols) // h
    return cols[min(k, len(cols) - 1)]


# ---------------------------------------------------------------- styles
def ember():
    s = Screen()
    cells = placed(to_cells(pixels()), 2)
    for (x, y), g in cells.items():
        s.put(x, y, g, bands(y, 2, 6, [Y, R, M]))
    # the shine passing over the N
    for (x, y), g in cells.items():
        d = abs(31 - x - (y - 2))
        if d <= 3:
            s.put(x, y, g, {Y: W, R: Y, M: R}[bands(y, 2, 6, [Y, R, M])] if d > 1 else W)
    s.text(9, 'A ROGUELIKE OF LIGHT AND SHADOW', Y)
    return s, 'A  EMBER - the current one: fire bands, a sweeping shine'


def italic():
    S = pixels()
    h = max(y for _, y in S) + 1
    T = {(x + (h - 1 - y) // 2 + 1, y) for x, y in S}
    s = Screen()
    cells = placed(to_cells(T), 2)
    for (x, y), g in cells.items():
        s.put(x, y, g, bands(y, 2, 6, [W, Y, R]))
    # a speed-line underline
    for x in range(4, 36):
        s.put(x, 8, 0x3E, R if x % 3 else Y)
    s.text(10, 'A ROGUELIKE OF LIGHT AND SHADOW', Y)
    return s, 'B  ITALIC - slanted (the triangles make smooth slopes)'


def glow():
    S = pixels()
    s = Screen()
    cells = placed(to_cells(S), 3)
    occ = set(cells)
    halo1, halo2 = set(), set()
    for (x, y) in occ:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in occ:
                    halo1.add(p)
    for (x, y) in halo1:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in occ and p not in halo1:
                    halo2.add(p)
    for (x, y) in halo2:
        if (x + y) % 3 == 0:
            s.put(x, y, 0xF1, B)
    for (x, y) in halo1:
        s.put(x, y, 0xD0, B)
    for (x, y), g in cells.items():
        s.put(x, y, g, W if y == 3 else Y if y < 7 else R, R if g != 0x43 else 0)
    s.text(11, 'A ROGUELIKE OF LIGHT AND SHADOW', C)
    return s, 'C  GLOW - white-hot letters in a dithered aura'


def outline():
    S = pixels()
    edge = {(x, y) for (x, y) in S if any((x + dx, y + dy) not in S
                                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    inner = S - edge
    s = Screen()
    ec = placed(to_cells(edge, 80, 12), 2)
    ic = placed(to_cells(inner, 80, 12), 2)
    for (x, y), g in ic.items():
        s.put(x, y, 0xD0, B)
    for (x, y), g in ec.items():
        s.put(x, y, g, W if y < 4 else C, B if (x, y) in ic else 0)
    s.text(9, 'A ROGUELIKE OF LIGHT AND SHADOW', C)
    return s, 'D  ENGRAVED - silver outlines, dithered blue fill'


def lantern():
    s = Screen(14)
    cx = 18                                  # the lantern spans 18..21
    # ring and cap
    s.put(cx + 1, 0, 0x4E, Y)
    s.put(cx + 2, 0, 0x4D, Y)
    s.put(cx, 1, 0x4E, Y)
    s.put(cx + 1, 1, 0x43, Y)
    s.put(cx + 2, 1, 0x43, Y)
    s.put(cx + 3, 1, 0x4D, Y)
    # the glass: a frame of half blocks, a white flame on a red glow
    for y in (2, 3):
        s.put(cx, y, 0x3B, Y)
        s.put(cx + 3, y, 0x7B, Y)
    s.put(cx + 1, 2, 0x4E, W, R)
    s.put(cx + 2, 2, 0x4D, W, R)
    s.put(cx + 1, 3, 0x7A, W, R)
    s.put(cx + 2, 3, 0x7A, W, R)
    # the base
    s.put(cx, 4, 0x42, Y)
    s.put(cx + 1, 4, 0x43, Y)
    s.put(cx + 2, 4, 0x43, Y)
    s.put(cx + 3, 4, 0x56, Y)
    # rays: lines close in, dots further out
    for i, (g, col) in enumerate(((0x34, Y), (0x34, R), (0xF6, R), (0xF1, M))):
        s.put(cx - 2 - i, 2 + (i > 1), g, col)
        s.put(cx + 5 + i, 2 + (i > 1), g, col)
    s.put(cx - 1, 0, 0x77, Y)
    s.put(cx - 2, -0, 0xF1, R)
    s.put(cx + 4, 0, 0x76, Y)
    s.put(cx + 5, 0, 0xF1, R)
    s.put(cx - 1, 4, 0x76, R)
    s.put(cx + 4, 4, 0x77, R)
    cells = placed(to_cells(pixels()), 6)
    for (x, y), g in cells.items():
        d = abs(x - 19.5) + (y - 6) * 1.5
        col = W if d < 4 else Y if d < 9 else R if d < 14 else M
        s.put(x, y, g, col)
    s.text(13, 'A ROGUELIKE OF LIGHT AND SHADOW', Y)
    return s, 'E  LANTERN - an emblem above; letters lit by its distance'


def bevel():
    s = Screen()
    cells = placed(to_cells(pixels()), 2)
    # two colours per cell: the half-block gradient doubles the bands
    seq = [W, W, Y, Y, R, R, M, M, M]
    for (x, y), g in cells.items():
        k = (y - 2) * 2
        top, bot = seq[min(k, 8)], seq[min(k + 1, 8)]
        if g == 0x43:
            s.put(x, y, 0x7A, top, bot)
        elif g == 0x7B:
            s.put(x, y, 0x7B, top)
        else:
            s.put(x, y, g, top)
    s.text(9, 'A ROGUELIKE OF LIGHT AND SHADOW', W)
    return s, 'F  SUNSET - half-block gradient, 12 bands instead of 3'


def main():
    mocks = [f() for f in (ember, italic, glow, outline, lantern, bevel)]
    ims = []
    for scr, label in mocks:
        im = scr.image()
        lab = Image.new('RGB', (im.width, 22), (32, 32, 32))
        ImageDraw.Draw(lab).text((6, 5), label, fill=(255, 255, 0))
        both = Image.new('RGB', (im.width, im.height + 22))
        both.paste(lab, (0, 0))
        both.paste(im, (0, 22))
        ims.append(both)
    w = ims[0].width
    cols = 2
    rows = (len(ims) + 1) // 2
    hs = [max(ims[r * 2 + c].height for c in range(cols) if r * 2 + c < len(ims)) for r in range(rows)]
    sheet = Image.new('RGB', (w * cols + 8, sum(hs) + 8 * rows), (60, 60, 60))
    y = 0
    for r in range(rows):
        for c in range(cols):
            i = r * 2 + c
            if i < len(ims):
                sheet.paste(ims[i], (c * (w + 8), y))
        y += hs[r] + 8
    out = os.path.join(ROOT, 'build', 'logo_mocks.png')
    sheet.save(out)
    print(out, sheet.size)


if __name__ == '__main__':
    main()
