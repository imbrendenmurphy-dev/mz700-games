"""cells.py - turn colour pixel art into MZ-700 character cells.

Pixel images are 2-D numpy arrays of colour indices: 0-7 = MZ colours,
TR (8) = transparent.  Each 8x8 cell becomes (glyph 0-511, fg, bg, transparent):
- an empty cell (None),
- an opaque cell (two colours),
- an edge cell: one colour on a transparent background, which takes the
  paper colour of whatever is underneath at run time (attr bit 3).

Sprite cells only use glyphs whose left-right mirror image is also in the ROM
(MIRROR maps each to its twin), so a sprite can face either way exactly.
"""
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mzfont as F  # noqa: E402

TR = 8

_bits = np.array([np.array(F.glyph_bits(g), dtype=np.uint8).reshape(64) for g in range(512)])


def _key(b):
    return bytes(b)


_first = {}
for g in range(512):
    _first.setdefault(_key(_bits[g]), g)

# canonical glyphs (first of duplicates); mirror twins
MIRROR = {}
for g in range(512):
    if _first[_key(_bits[g])] != g:
        continue
    m = _bits[g].reshape(8, 8)[:, ::-1].reshape(64)
    k = _key(m)
    if k in _first:
        MIRROR[g] = _first[k]


def _comps(m):
    m = m.copy()
    n = 0
    for y in range(8):
        for x in range(8):
            if m[y, x]:
                n += 1
                st = [(y, x)]
                m[y, x] = 0
                while st:
                    a, b = st.pop()
                    for c, d in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                        if 0 <= c < 8 and 0 <= d < 8 and m[c, d]:
                            m[c, d] = 0
                            st.append((c, d))
    return n


def _thin(m):
    """pixels of m not covered by any 2x2 square of m"""
    cov = np.zeros((8, 8), bool)
    for y in range(7):
        for x in range(7):
            if m[y:y + 2, x:x + 2].all():
                cov[y:y + 2, x:x + 2] = True
    return int((m.astype(bool) & ~cov).sum())


def is_shape(g):
    m = _bits[g].reshape(8, 8)
    n = int(m.sum())
    if n == 0 or n == 64:
        return True
    return (_comps(m) <= 1 and _comps(1 - m) <= 2 and _thin(m) <= 2 and _thin(1 - m) <= 2)


_AUTO = [0x0, 0x30, 0x31, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x42, 0x43,
         0x4d, 0x4e, 0x56, 0x5b, 0x6c, 0x70, 0x71, 0x74, 0x75, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x1a1,
         0x1a5, 0x1bd, 0x1be, 0x1bf, 0x1c0, 0x1c9, 0x1ca, 0x1d5, 0x1d6, 0xd0, 0x47, 0x13d, 0x13e, 0x13f, 0x140,
         0x160, 0x161, 0x162, 0x163, 0x164, 0x165, 0x1a2, 0x1a3, 0x1a4, 0x1c5, 0x1c6, 0x1c7, 0x1c8, 0x1cb, 0x1cc,
         0x1cd, 0x1ce, 0x1cf, 0x1d0, 0x1d1, 0x1d2, 0x1d3, 0x1d4, 0x1d7, 0x1d8]
_S = set()
for g in _AUTO:
    if g in MIRROR:
        _S.add(g)
        _S.add(MIRROR[g])
_S -= {0x140, 0x142, 0x15d, 0x15e, 0x1c5, 0x1c6, 0x1c7, 0x1c8, 0x1d1, 0x1d2, 0x1d3, 0x1d4, 0x1d7, 0x1d8}
SPRITE_GLYPHS = sorted(g for g in _S if MIRROR[g] in _S)
# avoid letters/digits/odd symbols that read as text in a body: keep shapes
_ALLOW_ALL = set(SPRITE_GLYPHS)

ALL_GLYPHS = sorted(set(_first.values()))


def glyph_array(glyphs):
    return np.array([_bits[g] for g in glyphs], dtype=np.float32)


_SG = glyph_array(SPRITE_GLYPHS)
_AG = glyph_array(ALL_GLYPHS)


def mirror_glyph(g):
    return MIRROR[g]


def _blur(m):
    """3x3 soft blur of a (..., 64) array, for a structural error term."""
    a = m.reshape(m.shape[:-1] + (8, 8))
    p = np.pad(a, [(0, 0)] * (a.ndim - 2) + [(1, 1), (1, 1)], mode='edge')
    s = 0
    for dy in range(3):
        for dx in range(3):
            w = 2.0 if (dy == 1 and dx == 1) else 1.0
            s = s + w * p[..., dy:dy + 8, dx:dx + 8]
    return (s / 10.0).reshape(m.shape)


_SGB = _blur(_SG)
_AGB = _blur(_AG)
_SPRSET = (_SG, _SGB, SPRITE_GLYPHS)
_ANYSET = (_AG, _AGB, ALL_GLYPHS)


def _best(G, GB, target, weight, allow_inv):
    """target: 64 floats in [0,1] (1 = fg).  Returns (cost, glyph index, inverted)."""
    tb = _blur(target[None, :])[0]
    e = (np.abs(G - target[None, :]) * weight[None, :]).sum(1) + 1.5 * (np.abs(GB - tb[None, :]) * weight[None, :]).sum(1)
    i = int(np.argmin(e))
    best = (float(e[i]), i, False)
    if allow_inv:
        e2 = (np.abs((1 - G) - target[None, :]) * weight[None, :]).sum(1) + 1.5 * (np.abs((1 - GB) - tb[None, :]) * weight[None, :]).sum(1)
        j = int(np.argmin(e2))
        if e2[j] < best[0]:
            best = (float(e2[j]), j, True)
    return best


_cache = {}


def any_cell(px):
    """like sprite_cell, but any glyph (no mirroring needed)"""
    return sprite_cell(px, _ANYSET)


def sprite_cell(px, gs=None):
    """px: 8x8 colour indices (TR = transparent).  Returns None or
    (glyph, fg, bg, transparent)."""
    if gs is None:
        gs = _SPRSET
    _SG, _SGB, SPRITE_GLYPHS = gs
    flat = px.reshape(64)
    key = flat.tobytes() + bytes([len(SPRITE_GLYPHS) & 255])
    if key in _cache:
        return _cache[key]
    opaque = flat != TR
    n_op = int(opaque.sum())
    if n_op <= 3:
        _cache[key] = None
        return None
    counts = np.bincount(flat[opaque], minlength=8)
    order = [int(c) for c in np.argsort(-counts) if counts[c] > 0]
    best = None
    # edge mode: one colour C over the paper underneath
    ones = np.ones(64, np.float32)
    for C in order[:2]:
        target = opaque.astype(np.float32)
        w = ones.copy()
        w[(flat != C) & opaque] = 0.6  # other fighter colours: filled but wrong colour
        cost, gi, inv = _best(_SG, _SGB, target, w, False)
        cost += 0.6 * float(((flat != C) & opaque).sum()) * 0.5
        if best is None or cost < best[0]:
            best = (cost, (SPRITE_GLYPHS[gi], C, 0, True))
    # opaque mode: two fighter colours, transparent pixels become one of them
    if len(order) >= 1:
        n_tr = 64 - n_op
        cands = []
        if len(order) >= 2:
            cands.append((order[0], order[1]))
        else:
            cands.append((order[0], order[0]))
        for A, B in cands:
            target = (flat == A).astype(np.float32)
            w = ones.copy()
            w[~opaque] = 0.0
            other = opaque & (flat != A) & (flat != B)
            w[other] = 0.5
            cost, gi, inv = _best(_SG, _SGB, target, w, True)
            cost += 0.9 * n_tr
            fg, bg = (B, A) if inv else (A, B)
            if A == B:
                cell = (0x43, A, A, False)
            else:
                cell = (SPRITE_GLYPHS[gi], fg, bg, False)
            if cost < best[0]:
                best = (cost, cell)
    # empty
    if n_op <= 10 and float(n_op) * 1.1 < best[0]:
        best = (n_op, None)
    _cache[key] = best[1]
    return best[1]


def bg_cell(px, glyphs='all', paper_bias=0.0):
    """Opaque background cell: 8x8 colour indices 0-7 -> (glyph, fg, bg)."""
    flat = px.reshape(64)
    counts = np.bincount(flat, minlength=8)
    order = [int(c) for c in np.argsort(-counts) if counts[c] > 0]
    if len(order) == 1:
        return (0, 0, order[0])
    if glyphs == 'all':
        G, GB, GL = (_AG, _AGB, ALL_GLYPHS)
    elif glyphs == 'sprite':
        G, GB, GL = (_SG, _SGB, SPRITE_GLYPHS)
    else:
        GL = list(glyphs)
        G = glyph_array(GL)
        GB = _blur(G)
    best = None
    for A, B in [(order[0], order[1])] + ([(order[0], order[2]), (order[1], order[2])] if len(order) > 2 else []):
        target = (flat == A).astype(np.float32)
        w = np.ones(64, np.float32)
        other = (flat != A) & (flat != B)
        w[other] = 0.5
        cost, gi, inv = _best(G, GB, target, w, True)
        cost += 0.5 * float(other.sum())
        fg, bg = (B, A) if inv else (A, B)
        if bg != order[0]:
            cost += paper_bias     # prefer the majority colour as paper (sprite edges take it)
        if best is None or cost < best[0]:
            best = (cost, (GL[gi], fg, bg))
    return best[1]


def glyph_pixels(g):
    return _bits[g].reshape(8, 8)
