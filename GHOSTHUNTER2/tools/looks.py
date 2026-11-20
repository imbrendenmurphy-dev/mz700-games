"""looks.py - how the maze grid looks on the MZ-700 screen.

Walls are drawn with the CG-ROM's centre-line box glyphs on the wall
characters that touch an open character (8-neighbourhood); wall interiors
get a per-style texture.  Glyph codes 100h-1FFh are in the second
character set (attribute bit 7).
"""
from mazes import GW, GH, EMPTY, PELLET, ENERG, WALL, DOOR, HOUSE, TELE, TUNNEL

K, B, R, M, G, C, Y, W = range(8)

# connection bits: 1 up, 2 down, 4 left, 8 right
BOX = {0: 0x0BD, 1: 0x079, 2: 0x079, 3: 0x079, 4: 0x078, 8: 0x078, 12: 0x078,
       10: 0x05C, 6: 0x05D, 9: 0x01C, 5: 0x01D, 7: 0x05E, 11: 0x01E, 14: 0x05F, 13: 0x01F, 15: 0x0BD}

# screen placement: grid (x, y) -> screen (x + XOFF, y + YOFF)
XOFF, YOFF = -1, 1
VIS_X0, VIS_X1 = 1, 40           # grid columns shown (x in [VIS_X0, VIS_X1))
VIS_Y0, VIS_Y1 = 1, 20

PELLET_G = 0x185
ENERG_G = 0x186
TELE_G = 0x184
DOOR_G = 0x078

# wall styles: (line colour, interior glyph, interior fg)
STYLES = {
    1: (G, 0x000, G),            # plain outline
    2: (C, 0x0D0, B),            # filled: dark checker (fg = bg -> solid blue)
    3: (G, 0x0F9, R),            # riveted: red studs
    4: (M, 0x1B8, R),            # railed
    5: (C, 0x0A6, M),            # textured
}


def is_open(v):
    return v != WALL and v != DOOR


def wall_looks(g):
    """per char: display glyph (with bank bit 100h) for walls/door, else 0"""
    out = [[0] * GW for _ in range(GH)]

    def at(x, y):
        if 0 <= y < GH:
            return g[y][x % GW]
        return WALL

    line = [[False] * GW for _ in range(GH)]
    for y in range(GH):
        for x in range(GW):
            v = g[y][x]
            if v == DOOR:
                line[y][x] = True
            elif v == WALL:
                line[y][x] = any(is_open(at(x + dx, y + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                                 if 0 <= x + dx < GW)
    for y in range(GH):
        for x in range(GW):
            if g[y][x] == DOOR:
                out[y][x] = DOOR_G
                continue
            if g[y][x] != WALL:
                continue
            if not line[y][x]:
                out[y][x] = -1           # interior
                continue
            m = 0
            for bit, dx, dy in ((1, 0, -1), (2, 0, 1), (4, -1, 0), (8, 1, 0)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < GW and 0 <= ny < GH and line[ny][nx]:
                    m |= bit
            out[y][x] = BOX[m]
    return out


def cell_look(code, look, style, power=False):
    """-> (glyph incl. bank bit, fg, bg) for one background character"""
    lc, ig, ic = STYLES[style]
    bg = M if power else B
    if power:
        lc, ic = W, (bg if ic == B else C)
    if code == WALL:
        if look == -1:
            return (ig, ic, bg) if ig else (0, lc, bg)
        return (look, lc, bg)
    if code == DOOR:
        return (DOOR_G, R if not power else Y, bg)
    if code == PELLET:
        return (PELLET_G, Y if not power else C, bg)
    if code == ENERG:
        return (ENERG_G, Y if not power else C, bg)
    if code == TELE:
        return (TELE_G, C if not power else Y, bg)
    return (0, W, bg)
