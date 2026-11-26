"""mock.py - preview LUMEN's lighting and tiles in Python (build/mock.png).

A hand-drawn test map is lit with the same model the Z80 renderer uses:
rays from the player (FOV, radius R), the torch falling off with distance,
static lights (braziers, crystals, fungus) with their own rays, and the
colour ramps from defs.py.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import defs  # noqa: E402
import mzfont  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = 16


def bres(tx, ty):
    """cells from (0,0) to (tx,ty), excluding the origin"""
    out = []
    n = max(abs(tx), abs(ty))
    for k in range(1, n + 1):
        out.append((round(tx * k / n), round(ty * k / n)))
    return out


def rays(r):
    tg = []
    for i in range(-r, r + 1):
        tg += [(i, -r), (i, r), (-r, i), (r, i)]
    return [bres(x, y) for x, y in sorted(set(tg))]


RAYS = rays(R)


def dist(dx, dy):
    return int(round(math.hypot(dx, dy)))


MAP_TXT = """
################################################################
################################################################
#######.........######################################.......###
#######.........######################......##########.......###
#######..P...P..######################......######~~~~...C...###
#######.........................................##~~~~.......###
#######..P...P..######################......######~~~~.......###
#######....!....######################.,,,..##########.......###
#############.###########################.######################
#############.#####........b............#.######################
#############.#####.ff.....=..==..=.....#.######################
#############.#####.f.......@.......o...+.#######.......########
#############.#####........*.....r......#.#######...B...########
#############.#####......................................#######
#############.##########################.########.......########
#############.##########################.#######################
#############............................#######################
################################################################
################################################################
################################################################
################################################################
################################################################
################################################################
"""
SYM = {'#': 'WALL', '.': 'FLOOR', ',': 'FLOOR2', 'P': 'PILLAR', '!': 'BRAZON', '~': 'WATER',
       'C': 'CRYSTAL', 'f': 'FUNGUS', '=': 'LAVA', '+': 'DOOR', 'B': 'BRAZOFF', 'b': 'BONES', '@': 'FLOOR',
       'o': 'FLOOR', 'r': 'FLOOR', '*': 'FLOOR'}


def main(theme='CRYPT', torch=8, out='mock.png', at=None):
    rows = [r for r in MAP_TXT.strip('\n').split('\n')]
    H, W = len(rows), len(rows[0])
    tmap = [[defs.T[SYM[c]] for c in row] for row in rows]
    px = py = 0
    mons = []
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == '@':
                px, py = x, y
            if c in 'or*':
                mons.append((x, y, c))

    if at:
        px, py = at

    def opaque(x, y):
        return not (0 <= x < W and 0 <= y < H) or defs.TILES[tmap[y][x]][1] & defs.F_OPAQUE

    # static light
    slight = [[(0, 0)] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            li = defs.TILES[tmap[y][x]][7]
            if not li:
                continue
            lv, hue = li[0], defs.HUE[li[1]]
            cells = {(x, y)}
            for ray in rays(lv):
                for dx, dy in ray:
                    cells.add((x + dx, y + dy))
                    if opaque(x + dx, y + dy):
                        break
            for cx, cy in cells:
                if 0 <= cx < W and 0 <= cy < H:
                    level = lv - dist(cx - x, cy - y) + (1 if lv > 2 else 0)
                    level = min(7, level)
                    if level > slight[cy][cx][0]:
                        slight[cy][cx] = (level, hue)
    # FOV
    vis = {(px, py): 0}
    for ray in RAYS:
        for dx, dy in ray:
            vis[(px + dx, py + dy)] = dist(dx, dy)
            if opaque(px + dx, py + dy):
                break
    th = defs.THEMES[theme]
    chars, attrs = [0] * 1000, [0] * 1000
    vx = max(0, min(W - 40, px - 20))
    vy = max(0, min(H - 20, py - 10))
    for y in range(20):
        for x in range(40):
            mx, my = vx + x, vy + y
            if not (0 <= mx < W and 0 <= my < H):
                continue
            t = tmap[my][mx]
            name, fl, g, gb, mode, col, bg, li, amb = defs.TILES[t]
            if name == 'WALL':
                g = gb = th[0]
                col, mode = th[4], th[7]
            elif name == 'FLOOR':
                g, gb, col = th[1], th[2], th[5]
                mode = defs.M_LIT
            elif name == 'FLOOR2':
                g = gb = th[3]
                col = th[6]
            if (mx, my) not in vis:
                lev = 0
                hue = 0
            else:
                d = vis[(mx, my)]
                lev, hue = slight[my][mx]
                tl = torch - d
                if d <= 1:
                    tl = max(tl, 1)
                if tl > lev:
                    lev, hue = min(7, tl), 0
            if lev == 0:
                continue
            ramp = defs.HUES[hue][1]
            if mode == defs.M_LIT:
                fg = ramp[lev]
            elif mode == defs.M_TINT:
                fg = defs.BLUE if lev <= 2 else (col if lev <= 4 else ramp[lev])
            elif mode == defs.M_FIX:
                fg = defs.BLUE if lev <= 2 else col
            else:
                fg = col
            gg = gb if lev >= 6 else g
            b = bg if lev >= 2 else 0
            i = y * 40 + x
            chars[i] = gg & 0xFF
            attrs[i] = ((gg >> 8) << 7) | (fg << 4) | b
    for mx, my, c in mons:
        i = (my - vy) * 40 + (mx - vx)
        g, col = {'o': (0x13C, GREEN), 'r': (0x152, RED), '*': (0x06B, YELLOW)}[c] if False else \
            {'o': (0x137, defs.GREEN), 'r': (0x152, defs.RED), '*': (0x06B, defs.YELLOW)}[c]
        chars[i] = g & 0xFF
        attrs[i] = ((g >> 8) << 7) | (col << 4)
    i = (py - vy) * 40 + (px - vx)
    chars[i] = 0xCA
    attrs[i] = defs.WHITE << 4
    hud = mzfont.text_codes('HP 23/30  MP 8/12  OIL 74  GOLD 120')
    for k, c in enumerate(hud):
        chars[21 * 40 + 1 + k] = c
        attrs[21 * 40 + 1 + k] = defs.WHITE << 4
    im = mzfont.render_cells(chars, attrs, scale=3)
    im.save(os.path.join(ROOT, 'build', out))


if __name__ == '__main__':
    for th in defs.THEMES:
        main(th, out='mock_%s.png' % th.lower())
    main('CRYPT', 5, 'mock_braz.png', (11, 3))
    main('FROST', 5, 'mock_cry.png', (55, 2))
