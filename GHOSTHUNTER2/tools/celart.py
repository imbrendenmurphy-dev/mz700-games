"""celart.py - cell-art DSL shared by sprites, tiles and screens.

A picture is rows of whitespace-separated tokens, one token per cell:

    .            empty / transparent (cell not drawn)
    GGG:F/B      glyph GGG (hex, 000-1FF; 1xx = bank 1), fg F, bg B
    GGG:F        same with a transparent background (sprites only)

Colour letters: K black, B blue, R red, M magenta, G green, C cyan,
Y yellow, W white.  '.' as bg = transparent.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROM = open(os.path.join(HERE, '..', 'rom', 'mz700fon.int'), 'rb').read()
PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
       (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
CL = {'K': 0, 'B': 1, 'R': 2, 'M': 3, 'G': 4, 'C': 5, 'Y': 6, 'W': 7}
TR = -1


def tok(t):
    """token -> (glyph, fg, bg) or None"""
    if t == '.':
        return None
    g, _, c = t.partition(':')
    fg, _, bg = c.partition('/')
    return int(g, 16), CL[fg or 'W'], (CL[bg] if bg and bg != '.' else TR)


def parse(text):
    rows = [ln.split() for ln in text.strip('\n').split('\n') if ln.strip()]
    w = max(len(r) for r in rows)
    return [[tok(t) for t in r] + [None] * (w - len(r)) for r in rows]


def mirror_glyph_table():
    """glyph -> glyph whose bitmap is its left-right mirror (or None)"""
    pics = {}
    for g in range(512):
        pics.setdefault(ROM[g * 8:g * 8 + 8], g)
    rev = {}
    for g in range(512):
        m = bytes(int('{:08b}'.format(b)[::-1], 2) for b in ROM[g * 8:g * 8 + 8])   # bit-reverse
        rev[g] = pics.get(m)
    return rev


MIRROR = mirror_glyph_table()


def mirror(pic, override=None):
    """left-right mirror of a picture; glyphs without a mirror image are
    looked up in override {glyph: glyph} or raise"""
    out = []
    for row in pic:
        nr = []
        for c in reversed(row):
            if c is None:
                nr.append(None)
                continue
            g, fg, bg = c
            m = (override or {}).get(g, MIRROR[g])
            if m is None:
                m = g                    # no exact mirror: keep the glyph
            nr.append((m, fg, bg))
        out.append(nr)
    return out


def draw(im, pic, cx, cy, bgcol=None):
    px = im.load()
    for y, row in enumerate(pic):
        for x, c in enumerate(row):
            if c is None:
                continue
            g, fg, bg = c
            X, Y = (cx + x) * 8, (cy + y) * 8
            if X < 0 or Y < 0 or X + 8 > im.width or Y + 8 > im.height:
                continue
            for yy in range(8):
                bits = ROM[g * 8 + yy]
                for xx in range(8):
                    if (bits >> xx) & 1:
                        px[X + xx, Y + yy] = PAL[fg]
                    elif bg != TR:
                        px[X + xx, Y + yy] = PAL[bg]


def sheet(pics, sky=1, gap=1, scale=4, cols=8):
    """preview image of several pictures on a sky colour"""
    w = max(len(p[0]) for p in pics) + gap
    h = max(len(p) for p in pics) + gap
    n = len(pics)
    cw = min(cols, n)
    im = Image.new('RGB', (cw * w * 8 + 8, ((n + cw - 1) // cw) * h * 8 + 8), PAL[sky])
    for i, p in enumerate(pics):
        draw(im, p, (i % cw) * w + 1, (i // cw) * h + 1)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)
