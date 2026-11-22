"""filled_mock.py - what would ARGOSY look like with hidden lines removed
or with filled, shaded polygons?  A mock-up at the MZ-700's real limits.

    py tools/filled_mock.py      -> build/shots/mock_filled.png

The same scene (a Mantis close by, a Dart, a Hauler, the planet) drawn
three ways, top to bottom, each a 40 x 18 cell view:
  1. today's wireframe in the dotted quarter blocks (80 x 36 dots)
  2. the same wireframe with hidden lines removed (back faces culled)
  3. filled and flat shaded: each cell is one CG-ROM glyph (blank, full,
     half blocks, corner triangles or the checker) in one ink and one
     paper colour, picked to match a high-resolution render best
  4. a hybrid: hidden-line ships over a filled planet in calm colours
     (night side blue on black, a thin lit crescent)
"""
import itertools
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import build  # noqa: E402
from mzsim import write_png  # noqa: E402

PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255), (0, 255, 0), (0, 255, 255), (255, 255, 0),
       (255, 255, 255)]
BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)
CW, CH = 40, 18                     # cells
SS = 8                              # pixels per cell side (as on screen)

raw = open(os.path.join(ROOT, 'rom', 'mz700fon.int'), 'rb').read()


def glyph(code):
    """8x8 list of 0/1, leftmost pixel in bit 0"""
    return [[(raw[code * 8 + r] >> c) & 1 for c in range(8)] for r in range(8)]


# ------------------------------------------------------------------ geometry
def hull_faces(v):
    """faces of the convex hull as (i, j, k) with outward normals"""
    cx = [sum(p[a] for p in v) / len(v) for a in range(3)]
    faces = []
    for i, j, k in itertools.combinations(range(len(v)), 3):
        a, b, c = v[i], v[j], v[k]
        u = [b[t] - a[t] for t in range(3)]
        w = [c[t] - a[t] for t in range(3)]
        n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
        if sum(x * x for x in n) < 1e-6:
            continue
        side = [sum(n[t] * (p[t] - a[t]) for t in range(3)) for p in v]
        if all(s <= 1e-6 for s in side):
            pass
        elif all(s >= -1e-6 for s in side):
            n = [-x for x in n]
            j, k = k, j
        else:
            continue
        if sum(n[t] * (a[t] - cx[t]) for t in range(3)) < 0:
            continue
        faces.append(((i, j, k), n))
    return faces


def rot(p, yaw, pitch, roll):
    x, y, z = p
    c, s = math.cos(roll), math.sin(roll)
    x, y = x * c - y * s, x * s + y * c
    c, s = math.cos(pitch), math.sin(pitch)
    y, z = y * c - z * s, y * s + z * c
    c, s = math.cos(yaw), math.sin(yaw)
    x, z = x * c + z * s, -x * s + z * c
    return (x, y, z)


F = 90.0                            # focal length in dots


def project(p):
    x, y, z = p
    return (40 + F * x / z, 18 - F * y / z)


# a ship in the scene: model, colour ramp (dark .. lit), place, orientation
SCENE = [
    (build.hauler, (BLUE, YELLOW, WHITE), (260, 60, 1500), (2.4, 0.3, 0.2)),
    (build.dart, (MAGENTA, RED, YELLOW), (-60, -10, 700), (0.9, 0.35, -0.5)),
    (build.mantis, (BLUE, MAGENTA, WHITE), (-150, 40, 520), (-0.6, -0.25, 0.4)),
]
PLANET = ((170, -120, 1100), 300)   # centre, radius
LIGHT = (-0.55, 0.65, -0.5)         # towards the light
ln = math.sqrt(sum(x * x for x in LIGHT))
LIGHT = tuple(x / ln for x in LIGHT)


def ship_world(fn, place, ori):
    v, e = fn()
    w = [rot(p, *ori) for p in v]
    w = [(p[0] + place[0], p[1] + place[1], p[2] + place[2]) for p in w]
    return v, e, w


# ------------------------------------------------------------------ high-resolution render (colour indices)
W, H = CW * SS, CH * SS


def shade_colour(ramp, inten, x, y):
    """5 levels from a 3-colour ramp: solid, checker, solid, checker, solid"""
    lv = max(0, min(4, int(inten * 5)))
    lo, hi = (ramp[0], ramp[0]), (ramp[0], ramp[1])
    pairs = [(ramp[0], ramp[0]), (ramp[0], ramp[1]), (ramp[1], ramp[1]), (ramp[1], ramp[2]), (ramp[2], ramp[2])]
    a, b = pairs[lv]
    return a if (x + y) % 2 == 0 else b


def render_filled(scene=None, planet_ramp=(BLUE, GREEN, CYAN), lift=0.15, light=None):
    scene = SCENE if scene is None else scene
    lt = LIGHT if light is None else light
    img = [[BLACK] * W for _ in range(H)]
    zb = [[1e9] * W for _ in range(H)]
    # stars
    for sx, sy in ((30, 10), (120, 30), (200, 14), (300, 40), (60, 90), (250, 120), (20, 130), (310, 100)):
        img[sy][sx] = WHITE
    # planet: a lit sphere
    (pcx, pcy, pcz), pr = PLANET
    for py in range(H):
        for px in range(W):
            x = (px / SS * 2 - 40) / F * pcz       # back to world units at the planet's depth
            y = (18 - py / SS * 2) / F * pcz
            dx, dy = x - pcx, y - pcy
            d2 = dx * dx + dy * dy
            if d2 < pr * pr:
                dz = -math.sqrt(pr * pr - d2)
                n = (dx / pr, dy / pr, dz / pr)
                inten = max(0.0, sum(n[t] * lt[t] for t in range(3)))
                img[py][px] = shade_colour(planet_ramp, lift + (1 - lift) * inten, px // 2, py // 2)
                zb[py][px] = pcz + dz
    for fn, ramp, place, ori in scene:
        v, e, w = ship_world(fn, place, ori)
        for (i, j, k), n in hull_faces(w):
            a, b, c = w[i], w[j], w[k]
            if sum(n[t] * a[t] for t in range(3)) >= 0:
                continue                            # facing away
            nl = math.sqrt(sum(x * x for x in n))
            inten = max(0.0, sum(n[t] / nl * LIGHT[t] for t in range(3)))
            pts = [project(p) for p in (a, b, c)]
            pts = [(x * SS / 2, y * SS / 2) for x, y in pts]
            zf = (a[2] + b[2] + c[2]) / 3
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            for py in range(max(0, int(min(ys))), min(H, int(max(ys)) + 1)):
                for px in range(max(0, int(min(xs))), min(W, int(max(xs)) + 1)):
                    qx, qy = px + 0.5, py + 0.5
                    s1 = (pts[1][0] - pts[0][0]) * (qy - pts[0][1]) - (pts[1][1] - pts[0][1]) * (qx - pts[0][0])
                    s2 = (pts[2][0] - pts[1][0]) * (qy - pts[1][1]) - (pts[2][1] - pts[1][1]) * (qx - pts[1][0])
                    s3 = (pts[0][0] - pts[2][0]) * (qy - pts[2][1]) - (pts[0][1] - pts[2][1]) * (qx - pts[2][0])
                    if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0):
                        if zf < zb[py][px]:
                            zb[py][px] = zf
                            img[py][px] = shade_colour(ramp, 0.2 + 0.8 * inten, px // 2, py // 2)
    return img


CANDIDATES = [0x00, 0x43, 0x7A, 0x3A, 0x7B, 0x3B, 0x4D, 0x4E, 0x56, 0x42, 0xEF]
GLYPHS = {c: glyph(c) for c in CANDIDATES}


def cdist(a, b):
    return sum((x - y) ** 2 for x, y in zip(PAL[a], PAL[b]))


DIST = [[cdist(a, b) for b in range(8)] for a in range(8)]


def to_cells(img):
    """best glyph + ink + paper per cell"""
    cells = []
    for cy in range(CH):
        row = []
        for cx in range(CW):
            blk = [img[cy * SS + r][cx * SS:(cx + 1) * SS] for r in range(SS)]
            used = sorted(set(c for r in blk for c in r))
            best = None
            for g, bm in GLYPHS.items():
                for ink in used:
                    for paper in used:
                        err = 0
                        for r in range(SS):
                            br = blk[r]
                            gr = bm[r]
                            for c in range(SS):
                                err += DIST[br[c]][ink if gr[c] else paper]
                        if best is None or err < best[0]:
                            best = (err, g, ink, paper)
            row.append(best[1:])
        cells.append(row)
    return cells


# ------------------------------------------------------------------ wireframes (dot level, as the game draws)
def line_dots(p, q, dots):
    (x0, y0), (x1, y1) = p, q
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / n
        x = int(round(x0 + (x1 - x0) * t))
        y = int(round(y0 + (y1 - y0) * t))
        if 0 <= x < 80 and 0 <= y < 36:
            dots[(x, y)] = dots.get('col')


def render_wire(hidden, planet=True):
    dots = {}
    cols = {}

    def plot(x, y, col):
        if 0 <= x < 80 and 0 <= y < 36:
            cols[(x, y)] = col
    for sx, sy in ((30, 10), (120, 30), (200, 14), (300, 40), (60, 90), (250, 120), (20, 130), (310, 100)):
        plot(sx * 2 // SS, sy * 2 // SS, WHITE)
    (pcx, pcy, pcz), pr = PLANET
    cx, cy = project((pcx, pcy, pcz))
    rr = F * pr / pcz
    for i in range(120 if planet else 0):
        a = 2 * math.pi * i / 120
        plot(int(round(cx + rr * math.cos(a))), int(round(cy + rr * math.sin(a))), GREEN)
    for fn, ramp, place, ori in SCENE:
        v, e, w = ship_world(fn, place, ori)
        vis = None
        if hidden:
            vis = set()
            for (i, j, k), n in hull_faces(w):
                if sum(n[t] * w[i][t] for t in range(3)) < 0:
                    vis |= {frozenset((i, j)), frozenset((j, k)), frozenset((k, i))}
        for i, j in e:
            if vis is not None and frozenset((i, j)) not in vis:
                continue
            p, q = project(w[i]), project(w[j])
            n = int(max(abs(q[0] - p[0]), abs(q[1] - p[1]))) + 1
            for s in range(n + 1):
                t = s / n
                plot(int(round(p[0] + (q[0] - p[0]) * t)), int(round(p[1] + (q[1] - p[1]) * t)), ramp[1])
    cells = []
    for cy_ in range(CH):
        row = []
        for cx_ in range(CW):
            nib = 0
            col = BLACK
            for b, (dx, dy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
                c = cols.get((cx_ * 2 + dx, cy_ * 2 + dy))
                if c is not None:
                    nib |= 1 << b
                    col = c
            row.append((0xF0 | nib, col, BLACK) if nib else (0x00, BLACK, BLACK))
        cells.append(row)
    return cells


def paint(cells, rgb, y0):
    for cy in range(CH):
        for cx in range(CW):
            g, ink, paper = cells[cy][cx]
            bm = glyph(g)
            for r in range(8):
                for c in range(8):
                    col = PAL[ink if bm[r][c] else paper]
                    p = ((y0 + cy * 8 + r) * CW * 8 + cx * 8 + c) * 3
                    rgb[p:p + 3] = bytes(col)


def hybrid():
    bl = (-0.75, 0.45, 0.75)                     # lit from behind: a crescent
    n = math.sqrt(sum(x * x for x in bl))
    base = to_cells(render_filled(scene=[], planet_ramp=(BLACK, BLUE, CYAN), lift=0.0,
                                  light=tuple(x / n for x in bl)))
    wire = render_wire(True, planet=False)
    for cy in range(CH):
        for cx in range(CW):
            if wire[cy][cx][0] != 0:
                g, ink, _ = wire[cy][cx]
                paper = base[cy][cx][2] if base[cy][cx][0] == 0 else base[cy][cx][2]
                base[cy][cx] = (g, ink, paper if paper != ink else BLACK)
    return base


if __name__ == '__main__':
    gap = 8
    Ht = 4 * CH * 8 + 3 * gap
    rgb = bytearray([40]) * (CW * 8 * Ht * 3)
    paint(render_wire(False), rgb, 0)
    paint(render_wire(True), rgb, CH * 8 + gap)
    paint(to_cells(render_filled()), rgb, 2 * (CH * 8 + gap))
    paint(hybrid(), rgb, 3 * (CH * 8 + gap))
    out = os.path.join(ROOT, 'build', 'shots', 'mock_filled.png')
    write_png(out, CW * 8, Ht, bytes(rgb), scale=2)
    print(out)
