"""proto.py - Python model of the segment road renderer, for tuning looks.

    py tools/proto.py   -> build/proto.png (a strip of frames)

Segments are 16 z-units long.  Each frame walks the segments ahead of the
camera (stride 1, then 2, then 4), accumulating curve (x) and keeping a
clip line for hills, and fills the sub-rows each segment covers.
"""
import os
from PIL import Image

PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255), (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
NR = 32          # sub-rows of road area
SEG = 16
C = 6000
CAMH = 33
W = 139          # road half width (world)
RECIP = [255] + [min(255, C // z) for z in range(1, 2048)]


def make_track():
    cur, hgt = [], []
    h = 0
    secs = [(30, 0, 0), (40, 3, 0), (30, 0, 3), (40, -4, -3), (40, 0, 0), (60, 2, 2), (60, -2, -2), (80, 0, 0)]
    for n, c, s in secs:
        for i in range(n):
            k = min(i, n - 1 - i, 8) / 8
            cur.append(round(c * k))
            h += round(s * k)
            hgt.append(h)
    return cur, hgt


def render(cur, hgt, P, px):
    cb = [[None] * 40 for _ in range(NR)]
    s0, frac = divmod(P, SEG)
    L = len(cur)
    hcam = hgt[s0 % L] + (hgt[(s0 + 1) % L] - hgt[s0 % L]) * frac // SEG + CAMH
    x = 0
    dx = -(cur[s0 % L] * frac // SEG)
    ymax = NR
    n = 1
    while n <= 48:
        st = 1 if n < 16 else (2 if n < 32 else 4)
        for k in range(st):          # curve accumulation, every segment
            x += dx
            dx += cur[(s0 + n + k) % L]
        seg = s0 + n
        z = n * SEG - frac
        s = RECIP[z]
        h = hgt[seg % L]
        y = NR - 1 - ((hcam - h) * s >> 8)       # top sub-row of this segment's strip... (horizon at -1)
        y = (hcam - h) * s >> 8                     # sub-rows below horizon
        top = y
        hw = W * s >> 8
        cx = 160 + ((x // 4 - px) * s >> 8)
        if n == 1:
            pcx, phw, py = cx, hw, NR
        if top < ymax:
            stripe = (seg >> 1) & 1
            rows = py - top
            for yy in range(max(top, 0), ymax):
                t = (py - yy) / rows if rows else 1
                hwy = int(phw + (hw - phw) * t)
                cxy = int(pcx + (cx - pcx) * t)
                rw = hwy // 6 + 1
                for c in range(40):
                    p = c * 8 + 4
                    a = abs(p - cxy)
                    if a < hwy:
                        col = 0
                        if stripe and a < max(3, hwy // 20):
                            col = 7
                    elif a < hwy + rw:
                        col = 2 if stripe else 7
                    else:
                        col = 4 if stripe else 5
                    cb[yy][c] = col
            ymax = max(top, 0)
        pcx, phw, py = cx, hw, top
        n += st
    for yy in range(ymax):
        for c in range(40):
            cb[yy][c] = 5
    return cb


def img(cb):
    im = Image.new('RGB', (320, 200))
    p = im.load()
    for y in range(200):
        for x in range(320):
            if y < 72:
                c = PAL[1] if y < 40 else PAL[6]
            else:
                r = (y - 72) // 4
                c = PAL[cb[r][x // 8]]
            p[x, y] = c
    return im


if __name__ == '__main__':
    cur, hgt = make_track()
    frames = []
    for P, px in [(0, 0), (35 * 16, 0), (55 * 16, 60), (100 * 16, -40), (150 * 16, 0), (230 * 16, 0)]:
        frames.append(img(render(cur, hgt, P, px)))
    out = Image.new('RGB', (320 * 3 + 20, 200 * 2 + 10), (40, 40, 40))
    for i, f in enumerate(frames):
        out.paste(f, ((i % 3) * 330, (i // 3) * 210))
    out = out.resize((out.width * 2, out.height * 2), Image.NEAREST)
    here = os.path.dirname(os.path.abspath(__file__))
    out.save(os.path.join(here, '..', 'build', 'proto.png'))
