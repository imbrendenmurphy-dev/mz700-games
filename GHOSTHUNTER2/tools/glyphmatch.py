"""glyphmatch.py - convert small hi-res colour pixel art into MZ-700 cells.

Each 8x8 cell of the (shifted) image is matched against a curated set of
CG-ROM glyphs: the cell gets one glyph, a foreground colour and a background
colour.  The background may be TRANSPARENT (-1): at run time the engine
takes it from the room tile underneath.  Error is counted in pixels, with
a penalty for losing silhouette (sprite pixel shown as background) so the
shape survives.
"""
import os

ROMF = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'rom', 'mz700fon.int')
ROM = open(ROMF, 'rb').read()
T = -1   # transparent


def glyph_mask(g):
    """64-bit int, bit (y*8+x) set where the glyph has a foreground pixel"""
    m = 0
    for y in range(8):
        b = ROM[g * 8 + y]
        for x in range(8):
            if (b >> x) & 1:
                m |= 1 << (y * 8 + x)
    return m


# curated "shape" glyphs: no letters, digits or punctuation
EXCLUDE = set(range(0x01, 0x30)) | set(range(0x81, 0x9B)) | set(range(0x101, 0x11B)) | {
    0x49, 0x4F, 0x52, 0x54, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A,
    0x2E, 0x2F, 0x2C, 0x2A, 0x2B, 0x2D, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4,
    0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF}
CANDIDATES = [g for g in range(512) if g not in EXCLUDE]
MASKS = {g: glyph_mask(g) for g in range(512)}
FULL = (1 << 64) - 1


def popcount(v):
    return bin(v).count('1')


def match_cell(pix, allowed=None):
    """pix: 64 colour values (T or 0-7).  Returns (glyph, fg, bg, err)."""
    cols = sorted(set(pix))
    if cols == [T]:
        return 0, 0, T, 0
    planes = {c: sum(1 << i for i, p in enumerate(pix) if p == c) for c in cols}
    sprite = sum(1 << i for i, p in enumerate(pix) if p != T)
    best = None
    cand = allowed or CANDIDATES
    pairs = []
    for fg in cols:
        if fg == T:
            continue
        for bg in cols + ([T] if T not in cols else []):
            if bg != fg:
                pairs.append((fg, bg))
        if len(cols) == 1:
            pairs.append((fg, fg))
    for fg, bg in pairs:
        pf = planes.get(fg, 0)
        pb = planes.get(bg, 0) if bg != fg else 0
        for g in cand:
            m = MASKS[g]
            # pixels shown as fg that aren't fg, and shown as bg that aren't bg
            e = popcount(m & ~pf) + popcount(~m & FULL & ~pb)
            if bg == T:
                # sprite pixels lost to transparency cost extra
                e += popcount(~m & FULL & sprite)
            elif T in cols:
                # background pixels painted over: mild cost (box around sprite)
                e += 0
            if best is None or e < best[3] or (e == best[3] and g < best[0]):
                best = (g, fg, bg, e)
    return best


def parse_art(lines, palette):
    """lines of chars -> 2D list of colours (palette maps char -> colour or T)"""
    return [[palette[ch] for ch in ln] for ln in lines]


def convert(img, dx, dy, wcells, hcells, allowed=None):
    """img: rows of colours; place at pixel offset (dx, dy) inside a
    wcells x hcells grid.  Returns rows of (glyph, fg, bg)."""
    H, W = len(img), len(img[0])
    out = []
    for cy in range(hcells):
        row = []
        for cx in range(wcells):
            pix = []
            for y in range(8):
                for x in range(8):
                    sx, sy = cx * 8 + x - dx, cy * 8 + y - dy
                    pix.append(img[sy][sx] if 0 <= sx < W and 0 <= sy < H else T)
            g, fg, bg, e = match_cell(pix, allowed)
            row.append((g, fg, bg))
        out.append(row)
    return out
