"""logo.py - LUMEN's title logo, built from CG-ROM shape glyphs.

The letters are drawn at twice the character resolution (each cell is
2 x 2 sub-pixels) and each cell becomes the glyph that fits it best:
a block, a half block, or one of the four 45-degree triangles (so stroke
ends and corners get diagonal cuts).  The colouring is a class per cell:

  1..3  letter cells: the lantern sweep's ramp, darker toward the bottom
        (rows 0-1 class 1, rows 2-4 class 2, rows 5+ class 3)
  4     the drop shadow: a dither in a fixed dim colour

`py tools/logo.py` writes build/logo_preview*.png; build.py calls gen_asm().
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mzfont  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# sub-pixel art, 16 rows (8 cells).  '#' = set.
ART = [
    "###.........###......###..###........###..##########..###......###",
    "###.........###......###..####......####..##########..####.....###",
    "###.........###......###..#####....#####..###.........#####....###",
    "###.........###......###..###.##..##.###..###.........###.##...###",
    "###.........###......###..###..####..###..########....###..##..###",
    "###.........###......###..###...##...###..########....###...##.###",
    "###.........###......###..###........###..###.........###....#####",
    "###.........###......###..###........###..###.........###.....####",
    "###.........###......###..###........###..###.........###......###",
    "###......#..###......###..###........###..###.........###......###",
    "##########...##########...###........###..##########..###......###",
    ".#########....########....###........###..##########..###......###",
]

# corner patterns of a 2 x 2 cell (TL, TR, BL, BR) -> glyph
TRI_TL, TRI_TR, TRI_BL, TRI_BR = 0x056, 0x042, 0x04D, 0x04E


def cell_glyph(tl, tr, bl, br):
    n = tl + tr + bl + br
    if n == 0:
        return None
    if n == 4:
        return 0x043
    if n == 2:
        if tl and tr:
            return 0x07A
        if bl and br:
            return 0x03A
        if tl and bl:
            return 0x07B
        if tr and br:
            return 0x03B
        return 0x043
    if n == 3:
        if not br:
            return TRI_TL
        if not bl:
            return TRI_TR
        if not tr:
            return TRI_BL
        return TRI_BR
    # one sub-pixel: the triangle on that corner
    return TRI_TL if tl else TRI_TR if tr else TRI_BL if bl else TRI_BR


def cells():
    w = max(len(r) for r in ART)
    w += w & 1
    rows = [r.ljust(w, '.') for r in ART]
    if len(rows) & 1:
        rows.append('.' * w)
    H, W = len(rows) // 2, w // 2
    out = [[(None, 0)] * W for _ in range(H)]

    def px(x, y):
        return 1 if rows[y][x] == '#' else 0
    for cy in range(H):
        for cx in range(W):
            g = cell_glyph(px(2 * cx, 2 * cy), px(2 * cx + 1, 2 * cy), px(2 * cx, 2 * cy + 1),
                           px(2 * cx + 1, 2 * cy + 1))
            if g is not None:
                cls = 1 if cy < 2 else 2 if cy < 4 else 3
                out[cy][cx] = (g, cls)
    return out


# ---------------------------------------------------------------- the glow
# The letters sit inside an aura two cells deep: a ring of blue dither
# round them (class 4) and, beyond it, a ring of positions where single
# dots twinkle (class 5: a dot shows where (x + y + phase) % 3 == 0).
# Letter classes 1-3 are the bands: the top row white-hot, then yellow,
# then red; cells that are not solid blocks get a red background.
GLYPHS = [None, 0x43, 0x7A, 0x3A, 0x7B, 0x3B, 0x56, 0x42, 0x4D, 0x4E, 0xD0, 0xF1]
BANDS = [None, [7, 7, 7], [6, 7, 7], [2, 6, 7]]
PAD = 2


def glow_cells():
    """[(glyph, class, red_bg)] rows, the letters inset by PAD cells"""
    cs = cells()
    H, W = len(cs) + 2 * PAD, len(cs[0]) + 2 * PAD
    out = [[(None, 0, 0)] * W for _ in range(H)]
    occ = set()
    for y, row in enumerate(cs):
        for x, (g, _) in enumerate(row):
            if g is None:
                continue
            cls = 1 if y == 0 else 2 if y < 4 else 3
            out[y + PAD][x + PAD] = (g, cls, 0 if g == 0x43 else 1)
            occ.add((x + PAD, y + PAD))

    def ring(src, exclude):
        r = set()
        for (x, y) in src:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    p = (x + dx, y + dy)
                    if p not in exclude and 0 <= p[0] < W and 0 <= p[1] < H:
                        r.add(p)
        return r
    h1 = ring(occ, occ)
    h2 = ring(h1, occ | h1)
    for (x, y) in h1:
        out[y][x] = (0xD0, 4, 0)
    for (x, y) in h2:
        out[y][x] = (0xF1, 5, 0)
    return out


def attr_of(cls, red, x, y, sweep):
    if cls == 4 or cls == 5:
        return 1 << 4
    d = abs(sweep - x - y)
    g = 2 if d <= 1 else 1 if d <= 3 else 0
    return (BANDS[cls][g] << 4) | (2 if red else 0)


def preview(sweep=12, path=None, phase=0):
    cs = glow_cells()
    H, W = len(cs), len(cs[0])
    chars, attrs = [0] * (40 * (H + 2)), [0] * (40 * (H + 2))
    x0 = (40 - W) // 2
    for y in range(H):
        for x in range(W):
            g, cls, red = cs[y][x]
            if g is None or (cls == 5 and (x + y + phase) % 3):
                continue
            i = (y + 1) * 40 + x0 + x
            chars[i] = g & 255
            attrs[i] = attr_of(cls, red, x, y, sweep)
    im = mzfont.render_cells(chars, attrs, rows=H + 2, scale=3)
    im.save(path or os.path.join(ROOT, 'build', 'logo_preview.png'))


def gen_asm():
    """one byte a cell: glyph index (bits 0-3), class (4-6), red ground (7)"""
    cs = glow_cells()
    H, W = len(cs), len(cs[0])
    out = ['; generated by tools/logo.py - the title logo (glow style)',
           'LOGO_W equ %d' % W, 'LOGO_H equ %d' % H,
           'LOGO_GLYPHS: db ' + ','.join('%d' % (g or 0) for g in GLYPHS), 'LOGO:']
    for row in cs:
        vals = []
        for g, cls, red in row:
            vals.append(0 if g is None else GLYPHS.index(g) | (cls << 4) | (red << 7))
        out.append('        db ' + ','.join('%d' % v for v in vals))
    return chr(10).join(out) + chr(10)


if __name__ == '__main__':
    from PIL import Image
    ims = []
    for k, sw in enumerate((6, 20, 34)):
        p = os.path.join(ROOT, 'build', 'logo_preview_%d.png' % sw)
        preview(sw, p, k)
        ims.append(Image.open(p))
    w, h = ims[0].size
    o = Image.new('RGB', (w, h * 3))
    for i, im in enumerate(ims):
        o.paste(im, (0, i * h))
    o.save(os.path.join(ROOT, 'build', 'logo_cmp.png'))
    cs = glow_cells()
    print('%d x %d cells' % (len(cs[0]), len(cs)))
