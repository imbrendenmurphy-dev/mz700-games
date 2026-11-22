"""logo.py - the NOVA STORM title logo (-> build/gen_logo.inc, build/logo_*.png)

The logo is drawn as an ordinary picture first (320 x 112 pixels, the
MZ-700's 8 colours): slanted letters with cut corners, a colour gradient,
a 3D extrusion and a starburst O.  Then every 8 x 8 piece of it is matched
against the whole ROM character set: the glyph and the foreground /
background colour pair that get the most pixels right.  So the logo is
made of wedges, curves, lines, half blocks and quarter blocks, with two
colours in a cell where an edge or a colour band crosses it.
"""
import os
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
rom = open(os.path.join(ROOT, 'rom', 'mz700fon.int'), 'rb').read()
PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255), (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
K, B, R, M, G, C, Y, W = range(8)

COLS, ROWS = 40, 14                  # the logo's area: rows 0..13


# ------------------------------------------------------------------ letters
# Polygons in character cells (x right, y down).  Every slanted edge is
# 45 degrees from cell corner to cell corner, and the rest are on whole or
# half cells, so the ROM's wedges and half blocks fit them exactly.
def P(*pts):
    return [(pts[i], pts[i + 1]) for i in range(0, len(pts), 2)]


BIG = {     # 6 rows tall
    'N': (6, [P(0, 1, 1, 0, 2, 0, 4, 2, 4, 0, 6, 0, 6, 5, 5, 6, 4, 6, 2, 4, 2, 6, 0, 6)], []),
    'O': (6, [P(1, 0, 5, 0, 6, 1, 6, 5, 5, 6, 1, 6, 0, 5, 0, 1)], [P(2, 2, 4, 2, 4, 4, 2, 4)]),
    'V': (6, [P(0, 0, 2, 0, 2, 2, 3, 3, 4, 2, 4, 0, 6, 0, 6, 3, 3, 6, 0, 3)], []),
    'A': (6, [P(0, 6, 0, 2, 2, 0, 4, 0, 6, 2, 6, 6, 4, 6, 4, 5, 2, 5, 2, 6)], [P(2, 2, 4, 2, 4, 3.5, 2, 3.5)]),
}
SMALL = {   # 5 rows tall
    'S': (5, [P(1, 0, 5, 0, 5, 1, 2, 1, 2, 2, 4, 2, 5, 3, 5, 4, 4, 5, 0, 5, 0, 4, 3, 4, 3, 3, 1, 3, 0, 2, 0, 1)], []),
    'T': (5, [P(0, 0, 5, 0, 5, 1.5, 3.5, 1.5, 3.5, 5, 1.5, 5, 1.5, 1.5, 0, 1.5)], []),
    'O': (5, [P(1, 0, 4, 0, 5, 1, 5, 4, 4, 5, 1, 5, 0, 4, 0, 1)], [P(2, 1, 3, 1, 3, 4, 2, 4)]),
    'R': (5, [P(0, 0, 4, 0, 5, 1, 5, 2, 4, 3, 5, 4, 5, 5, 3, 5, 3, 4, 2, 3, 2, 5, 0, 5)], [P(2, 1, 3, 1, 3, 2, 2, 2)]),
    'M': (6, [P(0, 5, 0, 0, 1, 0, 3, 2, 5, 0, 6, 0, 6, 5, 4, 5, 4, 3, 3, 4, 2, 3, 2, 5)], []),
}

SS = 8          # supersampling


def word_mask(font, word, x0, y0, gap):
    """-> (face mask at SS, list of letter boxes)"""
    m = Image.new('L', (COLS * 8 * SS, ROWS * 8 * SS), 0)
    d = ImageDraw.Draw(m)
    x = x0
    for ch in word:
        w, polys, holes = font[ch]
        def tr(pts):
            return [((x + px) * 8 * SS, (y0 + py) * 8 * SS) for px, py in pts]
        for p in polys:
            d.polygon(tr(p), fill=255)
        for p in holes:
            d.polygon(tr(p), fill=0)
        x += w + gap
    return np.array(m) > 127


def draw():
    H, W_ = ROWS * 8 * SS, COLS * 8 * SS
    img = np.zeros((H, W_), np.uint8)          # palette indices

    def word(font, text, x0, y0, h, gap, bands, ext):
        face = word_mask(font, text, x0, y0, gap)
        ex = np.zeros_like(face)
        for k in range(1, 8 * SS + 1):          # one cell down and right
            ex[k:, k:] |= face[:-k, :-k]
        img[ex & ~face] = ext
        ys = np.arange(H) / (8 * SS) - y0       # in cells from the top
        for yy in range(H):
            col = bands[-1][1]
            for lim, c in bands:
                if ys[yy] < lim:
                    col = c
                    break
            img[yy][face[yy]] = col

    # speed streaks: half-cell bars
    for (x1, x2, y, c) in ((0, 6, 1.5, C), (1, 5.5, 3, B), (0, 5, 4.5, C), (2, 5.5, 6, B)):
        img[int(y * 8 * SS):int((y + .5) * 8 * SS), int(x1 * 8 * SS):int(x2 * 8 * SS)] = c
    word(BIG, 'NOVA', 6, 1, 6, 1, [(1, W), (2.5, Y), (3.5, Y), (5, R), (9, M)], B)
    word(SMALL, 'STORM', 4, 8, 5, 1, [(.5, W), (9, C)], B)
    small = img.reshape(ROWS * 8, SS, COLS * 8, SS)[:, 0, :, 0]     # (exact: edges on the grid)
    return Image.fromarray(np.array(PAL, np.uint8)[small])


# ------------------------------------------------------------------ to glyphs
def quantise(img):
    a = np.array(img).astype(int)
    pal = np.array(PAL)
    d = ((a[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
    return d.argmin(-1)


def glyph_bits():
    g = np.zeros((512, 64), bool)
    for n in range(512):
        for y in range(8):
            b = rom[n * 8 + y]
            for x in range(8):
                g[n, y * 8 + x] = (b >> x) & 1
    return g


# the glyphs the converter may use: blocks, wedges, lines, curves, quarters
CAND = ([0x00] + list(range(0x30, 0x40)) + [0x42, 0x43, 0x4D, 0x4E, 0x56] + list(range(0x70, 0x80))
        + list(range(0xB0, 0xC0)) + list(range(0xD0, 0xE0)) + list(range(0xF0, 0x100))
        + [0x100 + n for n in list(range(0xBC, 0xC0)) + list(range(0xC0, 0xE0))])


def convert(q):
    G = glyph_bits()
    cand = np.array(CAND)
    Gc = G[cand].astype(int)                  # (n, 64)
    cells = []
    for cy in range(ROWS):
        row = []
        for cx in range(COLS):
            pix = q[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8].reshape(64)
            present = sorted(set(pix.tolist()))
            if present == [K]:
                row.append((0, 0))
                continue
            best = None
            cols = set(present) | {K}
            for f in cols:
                for b in cols:
                    mf = (pix != f).astype(int)
                    mb = (pix != b).astype(int)
                    err = Gc @ mf + (1 - Gc) @ mb
                    i = int(err.argmin())
                    e = int(err[i])
                    # (prefer fewer changes: a tiny tie-break for solid glyphs)
                    if best is None or e < best[0]:
                        best = (e, cand[i], f, b)
            e, g, f, b = best
            if g == 0:                         # a plain colour: draw it as a block
                g, f, b = 0x43, b, K
            if f == b:
                g, b = 0x43, K
            row.append((g & 255, ((g >> 8) << 7) | (f << 4) | b))
        cells.append(row)
    return cells


def render(cells):
    im = Image.new('RGB', (COLS * 8, ROWS * 8))
    px = im.load()
    for cy, row in enumerate(cells):
        for cx, (ch, at) in enumerate(row):
            g = ch | ((at & 0x80) << 1)
            fg, bg = PAL[(at >> 4) & 7], PAL[at & 7]
            for y in range(8):
                b = rom[g * 8 + y]
                for x in range(8):
                    px[cx * 8 + x, cy * 8 + y] = fg if (b >> x) & 1 else bg
    return im


def main():
    pic = draw()
    q = quantise(pic)
    Image.fromarray(np.array(PAL, np.uint8)[q]).resize((COLS * 16, ROWS * 16), Image.NEAREST).save(
        os.path.join(ROOT, 'build', 'logo_target.png'))
    cells = convert(q)
    render(cells).resize((COLS * 16, ROWS * 16), Image.NEAREST).save(os.path.join(ROOT, 'build', 'logo_mz.png'))
    # bounding box of used cells
    used = [(y, x) for y in range(ROWS) for x in range(COLS) if cells[y][x] != (0, 0)]
    y0, y1 = min(u[0] for u in used), max(u[0] for u in used)
    x0, x1 = min(u[1] for u in used), max(u[1] for u in used)
    out = ['; generated by tools/logo.py - the title logo: column, row, width, height,',
           '; then (char, attribute) per cell; 0,0 = empty',
           'logo:   db %d,%d,%d,%d' % (x0, y0, x1 - x0 + 1, y1 - y0 + 1)]
    for y in range(y0, y1 + 1):
        vals = []
        for x in range(x0, x1 + 1):
            vals += list(cells[y][x])
        for i in range(0, len(vals), 20):
            out.append('        db ' + ','.join('%03Xh' % v for v in vals[i:i + 20]))
    open(os.path.join(ROOT, 'build', 'gen_logo.inc'), 'w').write('\n'.join(out) + '\n')
    print('logo: %d cells, %dx%d at (%d,%d)' % (len(used), x1 - x0 + 1, y1 - y0 + 1, x0, y0))


if __name__ == '__main__':
    main()
