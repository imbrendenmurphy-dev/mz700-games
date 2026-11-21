"""cavelist.py - the 20 caves of ROCKFALL, in five wings of four.

Each wing teaches one idea, varies it, shows it off in a picture cave and
ends in a jewel shower, a collect-em-up where spouts in the ceiling rain
gems (and later rocks):

  I   THE SHALLOWS    A First Light    B Rolling Stones  C The Mountain  D Jewel Shower
  II  FIREFLY DEEPS   E Lanterns       F Butterfly Pens  G The Moth      H Sparkfall
  III MAGIC HALLS     I The Magic Wall J Alchemy Shafts  K Hourglass     L Rock Rain
  IV  GREEN CAVERNS   M The Amoeba     N Creeping Walls  O The Tree      P Ruby Rain
  V   THE CORE        Q Gauntlet       R Twin Vaults     S Treasure Storm T The Core

Caves are bigger than the screen (up to 64 x 32) and scroll; they grow
through the first wing.  The showers are one screen tall and scroll only
sideways, so the spouts are always in sight.

Times are tuned from the solving bot (tools/tune.py); a cave's `script`
holds moves the bot needs for a contraption (see tools/bot.py).
"""
from caves import Cave

EARTHY = [('DIRT', 88), ('BOULDER', 5), ('DIAMOND', 2), ('SPACE', 5)]
AIR = [('SPACE', 100)]


def perch(c, x1, y1, x2, y2, e='BUTT0'):
    """put a creature in the top-right empty cell of a room, facing left, so
    it follows the walls round (a butterfly in open space just spins)"""
    for y in range(y1, y2 + 1):
        for x in range(x2, x1 - 1, -1):
            if c.g[y][x] == 'SPACE':
                c.put(e, x, y)
                return


def dotted(c, e, x1, y1, x2, y2):
    """a line of pegs with gaps, so falling things can get through"""
    n = max(abs(x2 - x1), abs(y2 - y1))
    for i in range(0, n + 1, 2):
        c.put(e, round(x1 + (x2 - x1) * i / max(1, n)), round(y1 + (y2 - y1) * i / max(1, n)))


def drop(c, x, y, rocks=2):
    """a rock stack resting on a plug of earth at (x, y), over whatever is below"""
    c.put('DIRT', x, y)
    for k in range(1, rocks + 1):
        c.put('BOULDER', x, y - k)


def gem_pegs(c, cx, cy, r, step=1):
    """a gem outline drawn in brick pegs"""
    for y in range(cy - r, cy + r + 1, step):
        dx = (r - abs(y - cy)) * 2
        c.put('BRICK', cx - dx, y).put('BRICK', cx + dx, y)


def lantern(c, bx, by):
    """a brick vault of three gems, a firefly under it, rocks on plugs above"""
    c.rect('SPACE', bx, by, bx + 6, by + 4)
    c.box('BRICK', bx + 1, by + 1, bx + 5, by + 3)
    c.line('DIAMOND', bx + 2, by + 2, bx + 4, by + 2)
    c.put('FIRE0', bx + 3, by + 4)
    drop(c, bx + 1, by - 1)
    drop(c, bx + 5, by - 1)


def pen(c, bx, by):
    """a brick pen with a butterfly patrolling it, rocks on earth over a roof slot"""
    c.box('SPACE', bx, by, bx + 5, by + 3)
    c.rect('BRICK', bx - 1, by - 1, bx + 6, by + 4)
    c.line('SPACE', bx + 2, by - 1, bx + 3, by - 1)
    c.line('DIRT', bx, by - 2, bx + 5, by - 2)
    c.box('BOULDER', bx + 2, by - 4, bx + 3, by - 3)
    c.put('BUTT0', bx + 5, by)


# ===================================================================== I THE SHALLOWS
def a_first_light():
    c = Cave('A', 'FIRST LIGHT', 'NEVER STAND UNDER A ROCK YOU FREED', 24, 10, 15, 150, 1,
             [('DIRT', 86), ('BOULDER', 10), ('SPACE', 4)], w=64, h=32)
    # chandeliers: three rocks hanging over a gem - take it from the side
    for x, y in ((10, 6), (19, 9), (28, 5), (37, 8), (48, 13), (57, 16), (6, 16),
                 (14, 24), (27, 26), (40, 22), (52, 22)):
        c.stamp(x - 1, y - 3, ['.o.', '.o.', '.o.', '.*.', '...'])
    # the cellar: a rock-laden earth roof, and a door low on its left
    c.box('BOULDER', 16, 13, 36, 13)
    c.box('DIRT', 17, 14, 35, 14)
    c.rect('BRICK', 16, 14, 36, 18)
    c.box('SPACE', 17, 15, 35, 17)
    c.line('DIAMOND', 18, 17, 34, 17, 2)
    c.put('DIRT', 16, 17).put('DIRT', 15, 17)
    # the attic, up in the far corner: the same again, its door on the right
    c.box('BOULDER', 44, 3, 58, 3)
    c.box('DIRT', 45, 4, 57, 4)
    c.rect('BRICK', 44, 4, 58, 8)
    c.box('SPACE', 45, 5, 57, 7)
    c.line('DIAMOND', 46, 7, 56, 7, 2)
    c.put('DIRT', 58, 7).put('DIRT', 59, 7)
    # the last corridor: a gem under every rock, and no way back (step back and it seals)
    c.box('DIRT', 33, 27, 38, 30).line('BOULDER', 39, 28, 55, 28)
    c.line('DIAMOND', 39, 29, 55, 29, 2)
    c.line('DIRT', 40, 29, 54, 29, 2)
    c.put('DIRT', 38, 29).line('BRICK', 39, 30, 55, 30)
    # the exit vault: in from the corridor, or down through a door in its roof
    c.rect('BRICK', 56, 25, 62, 30)
    c.box('SPACE', 57, 26, 61, 29)
    c.put('DIRT', 56, 29)
    c.box('DIRT', 58, 21, 60, 24).put('DIRT', 59, 25)
    c.put('DIAMOND', 4, 4).put('DIAMOND', 6, 7).put('DIAMOND', 2, 9).put('DIRT', 4, 3).put('DIRT', 6, 6)
    c.start(2, 2).exit(61, 29)
    return c


def b_rolling_stones():
    c = Cave('B', 'ROLLING STONES', 'ROCKS ROLL OFF GEMS, ROCKS AND BRICK', 36, 10, 15, 150, 2,
             [('DIRT', 80), ('BOULDER', 12), ('SPACE', 8)], w=60, h=28)
    # gem heaps in hollows, roofed with rocks: take a corner and the rest rolls
    for cx, cy in ((10, 7), (30, 6), (50, 7)):
        c.ellipse('SPACE', cx, cy, 7, 3)
        c.line('BRICK', cx - 7, cy + 3, cx + 7, cy + 3)
        c.line('DIAMOND', cx - 3, cy + 2, cx + 3, cy + 2)
        c.line('BOULDER', cx - 2, cy + 1, cx + 2, cy + 1)
        c.line('BOULDER', cx - 1, cy, cx + 1, cy)
        c.put('BOULDER', cx, cy - 1)
    # pillars of rock and gem on brick pegs: dig down beside one and it rolls into your shaft
    for k, x in enumerate(range(22, 47, 4)):
        top = 13 + (k % 2) * 2
        c.put('BRICK', x, top + 6)
        for j in range(6):
            c.put('BOULDER' if j % 2 == 0 else 'DIAMOND', x, top + j)
        c.line('DIRT', x - 1, top - 1, x - 1, top + 6).line('DIRT', x + 1, top - 1, x + 1, top + 6)
    # a brick slope with rocks at the top, held by one plug of earth, and gems at its foot
    for k in range(9):
        c.put('BRICK', 4 + k, 18 + k).box('SPACE', 5 + k, 18, 13, 17 + k)
    c.line('SPACE', 5, 18, 13, 18)
    c.box('BOULDER', 5, 16, 7, 17)
    c.line('DIRT', 5, 18, 7, 18)
    c.line('DIAMOND', 14, 26, 17, 26)
    # the exit up on a brick ledge, under a pile that rolls when you take the gems below it
    c.box('SPACE', 50, 21, 57, 25)
    c.line('BRICK', 50, 23, 56, 23)
    c.line('DIAMOND', 51, 25, 57, 25)
    c.line('BOULDER', 52, 22, 55, 22).line('BOULDER', 53, 21, 54, 21)
    c.start(2, 2).exit(57, 22)
    return c

def c_mountain():
    c = Cave('C', 'THE MOUNTAIN', 'GEMS SLEEP INSIDE THE MOUNTAIN', 30, 10, 20, 180, 3, AIR, w=64, h=32)
    X = 32

    def hw(y):
        return int((y - 4) * 1.3)
    for y in range(4, 26):
        c.mixbox(X - hw(y), y, X + hw(y), y, [('DIRT', 86), ('BOULDER', 6), ('DIAMOND', 8)])
    for y in range(4, 8):                                        # snowcap
        c.line('DIAMOND', X - hw(y), y, X + hw(y), y)
    c.line('DIAMOND', 17, 22, 26, 13).line('DIAMOND', 47, 22, 38, 13)   # seams
    c.line('DIRT', X - 20, 19, X + 20, 19)                       # a ledge of plain earth
    c.mixbox(1, 26, 62, 30, [('DIRT', 90), ('BOULDER', 4), ('DIAMOND', 6)])
    c.ellipse('BRICK', 53, 6, 4, 3).ellipse('SPACE', 55, 5, 4, 3)   # the moon
    # nothing round on the open slopes, so nothing rolls before you arrive
    for y in range(8, 26):
        for x in (X - hw(y), X + hw(y)):
            if c.g[y][x] in ('BOULDER', 'DIAMOND'):
                c.put('DIRT', x, y)
    c.start(2, 25).exit(61, 25)
    return c


def d_jewel_shower():
    c = Cave('D', 'JEWEL SHOWER', 'CATCH THE GEMS - MIND YOUR HEAD', 75, 5, 10, 180, 4, AIR, w=64, h=24)
    c.spouts(4, 60, 4)
    gem_pegs(c, 32, 10, 3)                                       # a giant gem drawn in pegs
    gem_pegs(c, 32, 10, 6, 2)
    gem_pegs(c, 11, 9, 3)
    gem_pegs(c, 52, 9, 3)
    c.pins('BRICK', 3, 6, 60, 14, 28, 4)
    c.box('DIRT', 1, 21, 62, 22)
    for x in range(7, 58, 6):
        c.line('BRICK', x, 19, x, 20)                            # bins
    c.box('DIRT', 1, 17, 2, 20)
    c.put('INBOX', 1, 20).exit(62, 20)
    c.shower(14, 0, 240)
    return c


# ===================================================================== II FIREFLY DEEPS
def e_lanterns():
    c = Cave('E', 'LANTERNS', 'CRUSH A FIREFLY TO BLAST ITS VAULT', 30, 15, 20, 180, 5,
             [('DIRT', 86), ('BOULDER', 6), ('DIAMOND', 3), ('SPACE', 5)], w=64, h=32)
    for bx in (6, 28, 50):
        for by in (4, 14, 24):
            lantern(c, bx, by)
    c.start(2, 10).exit(61, 20)
    return c


def f_butterfly_pens():
    c = Cave('F', 'BUTTERFLY PENS', 'A CRUSHED BUTTERFLY MAKES NINE GEMS', 40, 15, 25, 180, 6,
             [('DIRT', 78), ('BOULDER', 7), ('DIAMOND', 5), ('SPACE', 10)], w=64, h=32)
    for bx in (4, 19, 34, 49):
        for by in (6, 16, 26):
            pen(c, bx, by)
    c.start(29, 12).exit(62, 30)
    return c


def g_moth():
    c = Cave('G', 'THE MOTH', 'BUTTERFLIES SLEEP IN ITS WINGS', 40, 10, 20, 200, 7,
             [('DIRT', 90), ('BOULDER', 4), ('DIAMOND', 3), ('SPACE', 3)], w=64, h=32)
    wings = ((17, 11, 11, 6), (46, 11, 11, 6), (21, 24, 8, 3), (42, 24, 8, 3))
    for cx, cy, rx, ry in wings:
        c.ellipse('SPACE', cx, cy, rx, ry)
        c.ellipse('BRICK', cx, cy, rx, ry, ring=True)
        c.put('DIAMOND', cx - 4, cy).put('DIAMOND', cx + 4, cy)  # eyespots
    c.box('STEEL', 31, 5, 32, 27)                                # body
    c.line('BRICK', 30, 4, 26, 1).line('BRICK', 33, 4, 37, 1)    # antennae
    # roof slots over each wing, with rocks on earth above
    for sx, top in ((14, 5), (20, 5), (43, 5), (49, 5), (18, 21), (45, 21)):
        c.put('SPACE', sx, top)
        drop(c, sx, top - 1)
    for cx, cy, rx, ry in wings:
        perch(c, cx - rx, cy - ry, cx + rx, cy)
    c.box('DIRT', 1, 29, 62, 30)                                 # the way round, under the moth
    c.put('DIAMOND', 8, 30).put('DIAMOND', 55, 30)
    c.start(2, 15).exit(61, 15)
    return c


def h_sparkfall():
    c = Cave('H', 'SPARKFALL', 'GEMS AND ROCKS RAIN TOGETHER', 70, 5, 10, 180, 8, AIR, w=64, h=24)
    c.spouts(3, 61, 4)
    c.pins('BRICK', 4, 6, 60, 14, 8, 4)
    c.box('DIRT', 1, 18, 62, 22)
    for x0 in (6, 29, 52):                                       # firefly rings in the floor
        c.rect('SPACE', x0, 18, x0 + 5, 20)
        c.line('BRICK', x0 + 1, 19, x0 + 4, 19)
        c.put('FIRE0', x0, 19)
    c.box('DIRT', 1, 14, 2, 17)
    c.put('INBOX', 1, 17).exit(62, 17)
    c.shower(16, 45, 250)
    return c


# ===================================================================== III MAGIC HALLS
def i_magic_wall():
    c = Cave('I', 'THE MAGIC WALL', 'FALLING ROCKS PASS THROUGH AS GEMS', 40, 5, 10, 180, 9,
             [('DIRT', 60), ('BOULDER', 28), ('DIAMOND', 3), ('SPACE', 9)], magic=60, w=64, h=32)
    c.line('MAGIC', 5, 16, 58, 16)
    c.line('BRICK', 4, 3, 4, 16).line('BRICK', 59, 3, 59, 16)
    c.box('DIRT', 1, 15, 3, 17).box('DIRT', 60, 15, 62, 17)
    c.box('SPACE', 5, 17, 58, 18)
    c.box('DIRT', 5, 19, 58, 30)
    c.scatter('DIAMOND', 10, 1, 19, 62, 30)
    c.start(31, 2).exit(61, 30)
    return c


def j_alchemy_shafts():
    c = Cave('J', 'ALCHEMY SHAFTS', 'OPEN THE SHAFTS FROM THE GALLERY', 50, 5, 10, 180, 10,
             [('DIRT', 90), ('BOULDER', 5), ('DIAMOND', 2), ('SPACE', 3)], magic=60, w=64, h=32)
    c.line('DIRT', 1, 14, 62, 14)                                # the gallery
    c.line('MAGIC', 2, 15, 61, 15)
    c.box('DIRT', 1, 14, 1, 17).put('BRICK', 62, 15)
    c.box('SPACE', 2, 16, 61, 17)                                # the hall
    c.mixbox(1, 18, 62, 30, [('DIRT', 92), ('BOULDER', 4), ('DIAMOND', 4)])
    for sx in range(5, 60, 6):
        c.line('BRICK', sx - 1, 2, sx - 1, 13).line('BRICK', sx + 1, 2, sx + 1, 13)
        c.line('BOULDER', sx, 2, sx, 13)
    c.start(2, 2).exit(61, 29)
    return c


def k_hourglass():
    c = Cave('K', 'HOURGLASS', 'LET THE SANDS OF STONE RUN THROUGH', 50, 5, 10, 180, 11,
             [('DIRT', 92), ('BOULDER', 3), ('DIAMOND', 3), ('SPACE', 2)], magic=50, w=64, h=32)
    X = 31
    c.line('BRICK', X - 12, 2, X + 12, 2)                        # lid
    for y in range(3, 14):                                       # top bulb, full of stone
        k = 13 - y
        c.line('BOULDER', X - k, y, X + k, y)
        c.put('BRICK', X - k - 1, y).put('BRICK', X + k + 1, y)
    c.put('DIRT', X, 14).put('BRICK', X + 1, 14).put('DIRT', X - 1, 14)   # the plug, reached from the left
    c.put('MAGIC', X, 15).put('BRICK', X - 1, 15).put('BRICK', X + 1, 15)
    for y in range(16, 28):                                      # bottom bulb, empty
        k = y - 16
        c.line('SPACE', X - k, y, X + k, y)
        c.put('BRICK', X - k - 1, y).put('BRICK', X + k + 1, y)
    c.line('BRICK', X - 13, 28, X + 13, 28)
    for dx in (-12, 12):                                         # doors in the bottom bulb
        c.put('DIRT', X + dx, 27)
        xs = range(X + dx - 3, X + dx) if dx < 0 else range(X + dx + 1, X + dx + 4)
        for y in range(22, 28):                                  # no loose rocks over a door
            for x in xs:
                if c.g[y][x] == 'BOULDER':
                    c.put('DIRT', x, y)
    c.start(2, 14).exit(61, 29)
    c.script = [('go', X - 1, 14), ('snap', 'R')]
    return c


def l_rock_rain():
    c = Cave('L', 'ROCK RAIN', 'MAGIC TURNS THE STONE RAIN TO GEMS', 60, 5, 10, 180, 12, AIR,
             magic=150, w=64, h=24)
    c.spouts(3, 60, 3)
    c.pins('BRICK', 4, 5, 60, 8, 8, 3)
    c.line('MAGIC', 1, 11, 62, 11)
    c.box('DIRT', 1, 17, 62, 22)
    c.put('INBOX', 2, 16).exit(61, 16)
    c.shower(20, 190, 180)
    return c


# ===================================================================== IV GREEN CAVERNS
def m_amoeba():
    c = Cave('M', 'THE AMOEBA', 'THE AMOEBA SPREADS - GATHER QUICKLY', 35, 10, 20, 180, 13,
             [('DIRT', 84), ('BOULDER', 6), ('DIAMOND', 6), ('SPACE', 4)], amoeba=30, w=56, h=28)
    c.box('SPACE', 23, 22, 32, 24)
    c.put('AMOEBA', 25, 23).put('AMOEBA', 30, 23)
    c.line('DIAMOND', 3, 4, 16, 10).line('DIAMOND', 52, 4, 39, 10)
    c.line('DIAMOND', 4, 22, 14, 17).line('DIAMOND', 51, 22, 41, 17)
    c.start(2, 2).exit(53, 2)
    return c


def n_creeping_walls():
    c = Cave('N', 'CREEPING WALLS', 'WALLS GROW INTO ANY GAP BESIDE THEM', 40, 15, 25, 180, 14,
             [('DIRT', 84), ('BOULDER', 7), ('DIAMOND', 5), ('SPACE', 4)], w=64, h=32)
    for y in (6, 12, 18, 24):
        c.line('EXPWALL', 8, y, 55, y)
        c.line('DIAMOND', 10, y + 2, 53, y + 2, 3)
    c.start(2, 2).exit(61, 29)
    return c


def o_tree():
    c = Cave('O', 'THE TREE', 'PICK THE FRUIT BEFORE THE ROOTS SPREAD', 50, 10, 20, 200, 15, AIR,
             amoeba=40, w=64, h=32)
    c.ellipse('DIRT', 31.5, 9, 22, 7)                            # the crown
    c.mixbox(13, 5, 50, 13, [('DIRT', 60), ('DIAMOND', 28), ('BOULDER', 12)])
    c.ellipse('DIRT', 31.5, 9, 22, 7, ring=True)
    c.box('BRICK', 29, 17, 34, 27)                               # trunk
    c.line('BRICK', 28, 17, 21, 13).line('BRICK', 35, 17, 42, 13)   # boughs
    c.mixbox(1, 27, 62, 30, [('DIRT', 90), ('DIAMOND', 6), ('BOULDER', 4)])
    c.box('BRICK', 29, 27, 34, 27)
    c.put('AMOEBA', 20, 29).put('AMOEBA', 43, 29)                # the roots
    c.start(2, 26).exit(61, 26)
    return c


def p_ruby_rain():
    c = Cave('P', 'RUBY RAIN', 'GATHER THE RAIN BEFORE THE AMOEBA DOES', 60, 5, 10, 180, 16, AIR,
             amoeba=20, w=64, h=24)
    c.spouts(4, 60, 4)
    for cx in (12, 32, 52):                                      # three leaves, veined
        for y in range(4, 13):
            for x in range(cx - 8, cx + 9):
                inside = ((x - cx) / 7.5) ** 2 + ((y - 8) / 3.5) ** 2 <= 1
                edge = inside and ((x - cx) / 6.5) ** 2 + ((y - 8) / 2.5) ** 2 > 1
                if edge and (x + y) % 2 == 0:
                    c.put('BRICK', x, y)
        dotted(c, 'BRICK', cx - 5, 8, cx + 5, 8)
    c.box('DIRT', 1, 17, 62, 22)
    c.put('AMOEBA', 16, 18).put('AMOEBA', 47, 18)
    c.box('DIRT', 1, 13, 2, 16)
    c.put('INBOX', 1, 16).exit(62, 16)
    c.shower(14, 20, 220)
    return c


# ===================================================================== V THE CORE
def q_gauntlet():
    c = Cave('Q', 'GAUNTLET', 'FIREFLIES GUARD THE TUNNELS', 45, 15, 25, 200, 17,
             [('DIRT', 80), ('BOULDER', 10), ('DIAMOND', 7), ('SPACE', 3)], speed=5, w=64, h=32)
    c.mixbox(1, 1, 62, 3, [('DIRT', 88), ('DIAMOND', 8), ('SPACE', 4)])   # the way in: no loose rocks
    for i, y in enumerate((4, 8, 12, 16, 20, 24)):
        c.line('BRICK', 1, y, 62, y)
        gap = 59 if i % 2 == 0 else 2
        c.line('DIRT', gap, y, gap + 2, y)
        c.line('SPACE', 3, y + 1, 60, y + 1)
        c.put('FIRE0', 10 + i * 8, y + 1)
        for dx in (14, 44):                                      # rocks over a plug in the roof
            drop(c, dx - i * 2, y)
    c.start(2, 2).exit(61, 30)
    return c


def r_twin_vaults():
    c = Cave('R', 'TWIN VAULTS', 'FEED THE VAULTS THEIR STONES', 50, 10, 20, 200, 18,
             [('DIRT', 64), ('BOULDER', 22), ('DIAMOND', 4), ('SPACE', 10)], magic=40, w=64, h=32)
    for x0 in (6, 38):
        c.rect('STEEL', x0, 21, x0 + 19, 30).box('DIAMOND', x0 + 1, 28, x0 + 18, 29)
        c.box('SPACE', x0 + 1, 22, x0 + 18, 27)
        c.line('MAGIC', x0 + 3, 21, x0 + 16, 21)
        c.put('BUTT3', x0 + 9, 24)
    c.put('DIRT', 6, 26).put('DIRT', 57, 26)
    c.start(31, 2).exit(31, 30)
    return c


def s_treasure_storm():
    c = Cave('S', 'TREASURE STORM', 'THE LAST RAIN - GEMS, ROCKS AND WINGS', 90, 5, 10, 200, 19, AIR,
             magic=60, speed=5, w=64, h=26)
    c.spouts(3, 61, 3)
    crown = [(11, 7), (19, 13), (24, 9), (31, 4), (38, 9), (43, 13), (51, 7)]
    for (x1, y1), (x2, y2) in zip(crown, crown[1:]):             # a crown drawn in pegs
        dotted(c, 'BRICK', x1, y1, x2, y2)
    dotted(c, 'BRICK', 11, 16, 51, 16)
    for x, y in crown[::2]:
        c.put('BRICK', x, y)
    c.put('BUTT3', 16, 11).put('BUTT3', 46, 11)
    c.line('MAGIC', 44, 19, 61, 19)
    c.box('DIRT', 1, 21, 62, 24)
    c.box('DIRT', 1, 17, 2, 20)
    c.put('INBOX', 1, 20).exit(62, 20)
    c.shower(18, 70, 250)
    return c


def t_core():
    c = Cave('T', 'THE CORE', 'EVERYTHING YOU HAVE LEARNED', 70, 20, 30, 220, 20,
             [('DIRT', 72), ('BOULDER', 15), ('DIAMOND', 7), ('SPACE', 6)], magic=40, speed=5, w=64, h=32)
    c.rect('STEEL', 24, 12, 39, 20).box('DIAMOND', 25, 18, 38, 19).box('SPACE', 25, 13, 38, 17)
    c.line('MAGIC', 27, 12, 36, 12)
    c.put('DIRT', 39, 19)
    for bx, by in ((4, 3), (53, 3), (4, 22)):                    # firefly lanterns
        lantern(c, bx, by)
    pen(c, 50, 24)
    c.line('EXPWALL', 16, 28, 47, 28)
    c.start(31, 2).exit(62, 30)
    return c


CAVES = [a_first_light, b_rolling_stones, c_mountain, d_jewel_shower,
         e_lanterns, f_butterfly_pens, g_moth, h_sparkfall,
         i_magic_wall, j_alchemy_shafts, k_hourglass, l_rock_rain,
         m_amoeba, n_creeping_walls, o_tree, p_ruby_rain,
         q_gauntlet, r_twin_vaults, s_treasure_storm, t_core]
