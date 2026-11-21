"""model.py - Python reference model of ZENITH's island generator and
column-raycast renderer.  The Z80 code follows this integer maths step for
step, so the model's PNGs show what the MZ-700 will draw.

    py tools/model.py [island] [heading] [out.png]

Geometry
  corners   33 x 33 integer levels (0 = sea)            -> 32 x 32 tiles
  fine map  128 x 128 sub-cells (4 per tile), byte = f << 2 | shade,
            f = height in half-subcell units (1 level = 4 f = 2 sub-cells)
  screen    40 x VIEW_H "half-block" pixels (each MZ cell = 2 stacked px)
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

W = 80
VIEW_H = 42                 # 21 cell rows
HOR0 = 14                   # horizon row for level gaze
KX = 64                     # columns per unit of depth
K = int(os.environ.get('ZK', '16'))   # half-px rows per 2 f at depth 1 (32 = 1 level is 2 sub-cells)
NC = 33                     # corners per side
FM = 128
SEA, SKY = 1, 0             # colours (MZ: 0 black 1 blue 2 red 3 magenta 4 green 5 cyan 6 yellow 7 white)
PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
       (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]


# ---------------------------------------------------------------- random (same xorshift as the Z80)
class Rng:
    def __init__(self, seed):
        self.s = seed & 0xFFFF or 1

    def next(self):
        s = self.s
        s ^= (s << 7) & 0xFFFF
        s ^= s >> 9
        s ^= (s << 8) & 0xFFFF
        self.s = s
        return s & 0xFF


def gen_corners(island):
    r = Rng(island * 0x2F1B + 0x51C7)
    # coarse 5x5 random grid (every 8 corners), bilinear up to 33x33, plus a little noise
    g = [[r.next() for _ in range(9)] for _ in range(9)]
    h = []
    for y in range(NC):
        gy, fy = y >> 2, y & 3
        row = []
        for x in range(NC):
            gx, fx = x >> 2, x & 3
            gx1, gy1 = min(gx + 1, 8), min(gy + 1, 8)
            v = (g[gy][gx] * (4 - fx) * (4 - fy) + g[gy][gx1] * fx * (4 - fy) +
                 g[gy1][gx] * (4 - fx) * fy + g[gy1][gx1] * fx * fy) >> 4
            row.append(min(255, v + (r.next() & 15)))
        h.append(row)
    # stretch to 0..255 range
    lo = min(min(row) for row in h)
    hi = max(max(row) for row in h)
    span = max(1, hi - lo)
    out = []
    for y in range(NC):
        row = []
        for x in range(NC):
            v = (h[y][x] - lo) * 255 // span
            # island falloff: distance from centre in corners (0..16)
            d = max(abs(x - 16), abs(y - 16))
            fall = 0 if d < 10 else (d - 9) * 36
            v = max(0, v - fall)
            lev = v // 28                      # 0..9
            row.append(lev)
        out.append(row)
    # border corners are sea
    for i in range(NC):
        out[0][i] = out[NC - 1][i] = out[i][0] = out[i][NC - 1] = 0
    # plateaus: two passes where each inner corner takes the most common level
    # of its 3x3 neighbourhood (ties: lower level)
    for _ in range(1):
        nxt = [row[:] for row in out]
        for y in range(1, NC - 1):
            for x in range(1, NC - 1):
                cnt = [0] * 16
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        cnt[out[y + dy][x + dx]] += 1
                best = 0
                for v in range(16):
                    if cnt[v] > cnt[best]:
                        best = v
                nxt[y][x] = best
        out = nxt
    return out


def tile_flat(c, tx, ty):
    a = c[ty][tx]
    return a == c[ty][tx + 1] == c[ty + 1][tx] == c[ty + 1][tx + 1]


def gen_fine(c):
    """fine map bytes: f<<2 | shade.  shade 0 flat, 1 flat stud, 2 slope lit, 3 slope dark"""
    fm = bytearray(FM * FM)
    for ty in range(32):
        for tx in range(32):
            h00, h10, h01, h11 = c[ty][tx], c[ty][tx + 1], c[ty + 1][tx], c[ty + 1][tx + 1]
            flat = h00 == h10 == h01 == h11
            # light from the west/north: slope lit if terrain rises towards +x/+y
            lit = (h10 + h11) - (h00 + h01) + (h01 + h11) - (h00 + h10) <= 0
            for sy in range(4):
                for sx in range(4):
                    # bilinear at sub-cell centre (sx+.5)/4 -> weights in eighths
                    fx, fy = 2 * sx + 1, 2 * sy + 1
                    v = (h00 * (8 - fx) * (8 - fy) + h10 * fx * (8 - fy) + h01 * (8 - fx) * fy + h11 * fx * fy)
                    f = (v * 4 + 32) >> 6            # levels*4, /64 weights
                    if flat:
                        shade = 1 if (sx == 1 and sy == 1) else 0     # one stud per tile
                    elif os.environ.get('ZCON', '1') == '1':
                        shade = 3 if (f & 3) == 0 else 2     # contour band at each whole level
                    else:
                        shade = 2 if lit else 3
                    fm[(ty * 4 + sy) * FM + tx * 4 + sx] = (f << 2) | shade
    return fm


# palettes: [flat, flat edge, slope lit, slope dark]
PALETTE = [int(ch) for ch in os.environ.get('ZPAL', '4053')]   # near: flat, flat edge, slope lit, slope dark
FARPAL = [PALETTE[0], PALETTE[0], PALETTE[2], PALETTE[3]]      # beyond NEARZ: no grid lines
NEARZ = 48
EYE = 6


def colour(b, z=0):
    if b < 4:
        return SEA
    return (PALETTE if z < NEARZ else FARPAL)[b & 3]


# depth steps in sub-cells (fixed point 8.8 handled as floats here, rounded like the Z80 tables)
def depth_steps():
    zs = []
    z = 1.0
    while z < 16:
        zs.append(z)
        z += 0.5
    while z < 48:
        zs.append(z)
        z += 1
    while z < 128:
        zs.append(z)
        z += 2
    return zs


ZS = depth_steps()


def render(fm, px, py, eye, heading, hor=HOR0):
    """px,py in sub-cells (float), eye in f units, heading 0..31 (0 = +y north... see below)"""
    import math
    a = heading * 2 * math.pi / 32
    fx, fy = math.sin(a), -math.cos(a)            # heading 0 looks to -y (north)
    rx, ry = -fy, fx
    scr = [[SKY] * W for _ in range(VIEW_H)]
    for c in range(W):
        t = (c - 39.5) / KX
        dx, dy = fx + rx * t, fy + ry * t
        ybuf = VIEW_H
        x, y = px, py
        zprev = 0
        for z in ZS:
            x = px + dx * z
            y = py + dy * z
            xi, yi = int(x), int(y)
            if not (0 <= xi < FM and 0 <= yi < FM):
                # sea to the horizon
                for yy in range(hor, ybuf):
                    if 0 <= yy < VIEW_H:
                        scr[yy][c] = SEA
                ybuf = min(ybuf, hor)
                break
            b = fm[yi * FM + xi]
            f = b >> 2
            ys = hor + int((eye - f) * K / 2 / z)
            if ys < ybuf:
                col = colour(b, z)
                for yy in range(max(ys, 0), ybuf):
                    scr[yy][c] = col
                ybuf = max(ys, 0)
                if ybuf == 0:
                    break
        else:
            for yy in range(hor, ybuf):
                if 0 <= yy < VIEW_H:
                    scr[yy][c] = SEA
    return scr


PATS = {(0,0,0,0),(1,1,1,1),(1,1,0,0),(0,0,1,1),(1,0,1,0),(0,1,0,1),(1,0,0,1),(0,1,1,0)}


def cell(p):
    """2x2 colours -> what the MZ can show (fg/bg + one of 8 patterns)"""
    cnt = {}
    for v in p:
        cnt[v] = cnt.get(v, 0) + 1
    order = sorted(cnt, key=lambda v: (-cnt[v], v))
    a = order[0]
    b = order[1] if len(order) > 1 else a
    bits = tuple(1 if v == a else 0 for v in p)
    if bits not in PATS:
        bits = (1, 1, 1, 1)
    return [a if q else b for q in bits]


def to_png(scr, path, scale=2):
    img = Image.new('RGB', (W * 4, VIEW_H * 4))
    for y in range(0, VIEW_H, 2):
        for x in range(0, W, 2):
            q = cell([scr[y][x], scr[y][x + 1], scr[y + 1][x], scr[y + 1][x + 1]])
            for i, (ox, oy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
                img.paste(PAL[q[i]], ((x + ox) * 4, (y + oy) * 4, (x + ox) * 4 + 4, (y + oy) * 4 + 4))
    img = img.resize((W * 4 * scale, VIEW_H * 4 * scale), Image.NEAREST)
    img.save(path)


def overview(c, path):
    img = Image.new('RGB', (NC * 8, NC * 8))
    for y in range(NC):
        for x in range(NC):
            v = c[y][x] * 22
            img.paste((v, v, 255 if c[y][x] == 0 else v), (x * 8, y * 8, x * 8 + 8, y * 8 + 8))
    img.save(path)


if __name__ == '__main__':
    isl = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    hd = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, 'build', 'model.png')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    c = gen_corners(isl)
    fm = gen_fine(c)
    # start on the lowest flat inland tile near the south
    best = None
    for ty in range(4, 28):
        for tx in range(4, 28):
            if tile_flat(c, tx, ty) and c[ty][tx] > 0:
                k = (c[ty][tx], -ty)
                if best is None or k < best[0]:
                    best = (k, tx, ty)
    _, tx, ty = best
    lev = c[ty][tx]
    print('start tile', tx, ty, 'level', lev)
    scr = render(fm, tx * 4 + 2, ty * 4 + 2, lev * 4 + EYE, hd)
    to_png(scr, out)
    overview(c, out.replace('.png', '_map.png'))
    print(out)
