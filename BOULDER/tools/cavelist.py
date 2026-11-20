"""cavelist.py - the 20 caves of ROCKFALL, in five wings of four.

Each wing teaches one idea, varies it, shows it off in a picture cave (seen
whole - every cave fits the screen) and ends in a jewel shower, a
collect-em-up where spouts in the ceiling rain gems (and later rocks):

  I   THE SHALLOWS    A First Light    B Rolling Stones  C The Mountain  D Jewel Shower
  II  FIREFLY DEEPS   E Lanterns       F Butterfly Pens  G The Moth      H Sparkfall
  III MAGIC HALLS     I The Magic Wall J Alchemy Shafts  K Hourglass     L Rock Rain
  IV  GREEN CAVERNS   M The Amoeba     N Creeping Walls  O The Tree      P Emerald Rain
  V   THE CORE        Q Gauntlet       R Twin Vaults     S Treasure Storm T The Core

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


# ===================================================================== I THE SHALLOWS
def a_first_light():
    c = Cave('A', 'FIRST LIGHT', 'DIG THE EARTH AND GATHER THE GEMS', 10, 10, 15, 120, 1,
             [('DIRT', 90), ('BOULDER', 4), ('DIAMOND', 2), ('SPACE', 4)])
    # hollows with gems lying on their floors
    for cx, cy, rx in ((8, 5, 4), (21, 4, 5), (32, 7, 4), (13, 11, 5), (28, 13, 5), (8, 17, 4), (21, 18, 4)):
        c.box('SPACE', cx - rx, cy - 1, cx + rx, cy)
        c.line('DIAMOND', cx - rx + 1, cy, cx + rx - 1, cy, 2)
    c.start(2, 2).exit(37, 19)
    return c


def b_rolling_stones():
    c = Cave('B', 'ROLLING STONES', 'ROCKS ROLL OFF ANYTHING ROUND', 15, 10, 15, 130, 2, EARTHY)
    for px, py in ((7, 6), (19, 6), (31, 6), (13, 14), (25, 14)):
        c.line('BRICK', px - 4, py + 1, px + 4, py + 1)          # shelf
        for k, w in enumerate((0, 1, 2)):                        # a pyramid of rocks on it
            c.line('BOULDER', px - w, py - 2 + k, px + w, py - 2 + k)
        c.line('DIAMOND', px - 3, py + 2, px + 3, py + 2)        # gems under the shelf
    # push lesson: a rock in a tunnel, gems behind it
    c.line('SPACE', 3, 19, 14, 19).put('BOULDER', 7, 19).line('DIAMOND', 12, 19, 14, 19)
    c.start(2, 2).exit(37, 20)
    return c


def c_mountain():
    c = Cave('C', 'THE MOUNTAIN', 'GEMS SLEEP INSIDE THE MOUNTAIN', 20, 10, 20, 150, 3, AIR)
    for y in range(3, 18):
        hw = int((y - 3) * 1.3)
        c.mixbox(20 - hw, y, 20 + hw, y, [('DIRT', 86), ('BOULDER', 6), ('DIAMOND', 8)])
    for y in range(3, 6):                                        # snowcap
        hw = int((y - 3) * 1.3)
        c.line('DIAMOND', 20 - hw, y, 20 + hw, y)
    c.line('DIAMOND', 9, 15, 15, 9).line('DIAMOND', 31, 15, 25, 9)   # seams
    c.line('DIRT', 20 - 13, 13, 20 + 13, 13)
    c.mixbox(1, 18, 38, 20, [('DIRT', 90), ('BOULDER', 4), ('DIAMOND', 6)])
    c.ellipse('BRICK', 33, 4, 2, 1).ellipse('SPACE', 34, 3, 2, 1)   # the moon
    # nothing round on the open slopes, so nothing rolls before you arrive
    for y in range(3, 18):
        hw = int((y - 3) * 1.3)
        for x in (20 - hw, 20 + hw):
            if c.g[y][x] in ('BOULDER', 'DIAMOND') and y > 5:
                c.put('DIRT', x, y)
    c.start(2, 17).exit(37, 17)
    return c


def d_jewel_shower():
    c = Cave('D', 'JEWEL SHOWER', 'CATCH THE GEMS - MIND YOUR HEAD', 50, 5, 10, 150, 4, AIR)
    c.spouts(4, 36, 4)
    for r in (3, 6):                                             # a giant gem drawn in pegs
        for y in range(10 - r, 10 + r + 1, 2 if r == 6 else 1):
            dx = (r - abs(y - 10)) * 2
            c.put('BRICK', 19 - dx, y).put('BRICK', 20 + dx, y)
    c.pins('BRICK', 3, 7, 36, 13, 34, 3)
    c.box('DIRT', 1, 19, 38, 20)
    for x in range(7, 34, 6):
        c.line('BRICK', x, 17, x, 18)                            # bins
    c.box('DIRT', 1, 15, 2, 18)
    c.put('INBOX', 1, 18).exit(38, 18)
    c.shower(14, 0, 160)
    return c


# ===================================================================== II FIREFLY DEEPS
def e_lanterns():
    c = Cave('E', 'LANTERNS', 'CRUSH A FIREFLY TO BLAST ITS VAULT', 18, 15, 20, 160, 5,
             [('DIRT', 86), ('BOULDER', 6), ('DIAMOND', 3), ('SPACE', 5)])
    for bx, by in ((4, 4), (16, 4), (28, 4), (4, 13), (16, 13), (28, 13)):
        c.rect('SPACE', bx, by, bx + 6, by + 4)
        c.box('BRICK', bx + 1, by + 1, bx + 5, by + 3)
        c.line('DIAMOND', bx + 2, by + 2, bx + 4, by + 2)        # the vault
        c.put('FIRE0', bx + 3, by + 4)
        drop(c, bx + 1, by - 1)
        drop(c, bx + 5, by - 1)
    c.start(2, 11).exit(37, 11)
    return c


def f_butterfly_pens():
    c = Cave('F', 'BUTTERFLY PENS', 'A CRUSHED BUTTERFLY MAKES NINE GEMS', 20, 15, 25, 160, 6,
             [('DIRT', 78), ('BOULDER', 7), ('DIAMOND', 5), ('SPACE', 10)])
    for bx in (3, 12, 21, 30):
        for by in (5, 14):
            c.box('SPACE', bx, by, bx + 5, by + 3)
            c.rect('BRICK', bx - 1, by - 1, bx + 6, by + 4)
            c.line('SPACE', bx + 2, by - 1, bx + 3, by - 1)        # a slot in the roof
            c.line('DIRT', bx, by - 2, bx + 5, by - 2)
            c.box('BOULDER', bx + 2, by - 4, bx + 3, by - 3)     # rocks on earth above it
            c.put('BUTT0', bx + 5, by)                           # patrols the walls
    c.start(20, 10).exit(38, 20)
    return c


def g_moth():
    c = Cave('G', 'THE MOTH', 'BUTTERFLIES SLEEP IN ITS WINGS', 25, 10, 20, 170, 7,
             [('DIRT', 90), ('BOULDER', 4), ('DIAMOND', 3), ('SPACE', 3)])
    wings = ((11, 8, 7, 4), (28, 8, 7, 4), (13, 16, 5, 2), (26, 16, 5, 2))
    for cx, cy, rx, ry in wings:
        c.ellipse('SPACE', cx, cy, rx, ry)
        c.ellipse('BRICK', cx, cy, rx, ry, ring=True)
        c.put('DIAMOND', cx - 3, cy).put('DIAMOND', cx + 3, cy)  # eyespots
    c.box('STEEL', 19, 4, 20, 18)                                # body
    c.line('BRICK', 18, 3, 16, 1).line('BRICK', 21, 3, 23, 1)    # antennae
    # roof slots over each wing, with rocks on earth above
    for sx, top in ((8, 5), (14, 5), (25, 5), (31, 5)):
        c.put('SPACE', sx, top)
        drop(c, sx, top - 1)
    for sx, top in ((10, 15), (29, 15)):
        c.put('SPACE', sx, top)
        drop(c, sx, top - 1)
    for cx, cy, rx, ry in wings:
        perch(c, cx - rx, cy - ry, cx + rx, cy)
    c.box('DIRT', 1, 19, 38, 20)                                 # the way round, under the moth
    c.put('DIAMOND', 6, 20).put('DIAMOND', 33, 20)
    c.start(2, 11).exit(37, 11)
    return c


def h_sparkfall():
    c = Cave('H', 'SPARKFALL', 'GEMS AND ROCKS RAIN TOGETHER', 45, 5, 10, 160, 8, AIR)
    c.spouts(3, 37, 4)
    c.pins('BRICK', 4, 6, 36, 14, 8, 4)
    c.box('DIRT', 1, 18, 38, 20)
    for x0 in (4, 29):                                           # firefly rings in the floor
        c.rect('SPACE', x0, 18, x0 + 5, 20)
        c.line('BRICK', x0 + 1, 19, x0 + 4, 19)
        c.put('FIRE0', x0, 19)
    c.box('DIRT', 1, 14, 2, 17)
    c.put('INBOX', 1, 17).exit(38, 17)
    c.shower(16, 45, 170)
    return c


# ===================================================================== III MAGIC HALLS
def i_magic_wall():
    c = Cave('I', 'THE MAGIC WALL', 'FALLING ROCKS PASS THROUGH AS GEMS', 30, 5, 10, 150, 9,
             [('DIRT', 60), ('BOULDER', 28), ('DIAMOND', 3), ('SPACE', 9)], magic=60)
    c.line('MAGIC', 5, 11, 34, 11)
    c.line('BRICK', 4, 3, 4, 11).line('BRICK', 35, 3, 35, 11)
    c.box('DIRT', 1, 10, 3, 12).box('DIRT', 36, 10, 38, 12)
    c.box('SPACE', 5, 12, 34, 13)
    c.box('DIRT', 5, 14, 34, 20)
    c.scatter('DIAMOND', 6, 1, 14, 38, 20)
    c.start(19, 2).exit(37, 20)
    return c


def j_alchemy_shafts():
    c = Cave('J', 'ALCHEMY SHAFTS', 'OPEN THE SHAFTS FROM THE GALLERY', 32, 5, 10, 160, 10,
             [('DIRT', 90), ('BOULDER', 5), ('DIAMOND', 2), ('SPACE', 3)], magic=50)
    c.line('DIRT', 1, 10, 38, 10)                                # the gallery
    c.line('MAGIC', 2, 11, 37, 11)
    c.box('DIRT', 1, 10, 1, 13).put('BRICK', 38, 11)
    c.box('SPACE', 2, 12, 37, 13)                                # the hall
    c.mixbox(1, 14, 38, 20, [('DIRT', 92), ('BOULDER', 4), ('DIAMOND', 4)])
    for sx in (5, 11, 17, 23, 29, 35):
        c.line('BRICK', sx - 1, 2, sx - 1, 9).line('BRICK', sx + 1, 2, sx + 1, 9)
        c.line('BOULDER', sx, 2, sx, 9)
    c.start(2, 2).exit(37, 19)
    return c


def k_hourglass():
    c = Cave('K', 'HOURGLASS', 'LET THE SANDS OF STONE RUN THROUGH', 35, 5, 10, 150, 11,
             [('DIRT', 92), ('BOULDER', 3), ('DIAMOND', 3), ('SPACE', 2)], magic=40)
    X = 19
    c.line('BRICK', X - 7, 2, X + 7, 2)                          # lid
    for y in range(3, 10):                                       # top bulb, full of stone
        k = 9 - y
        c.line('BOULDER', X - k, y, X + k, y)
        c.put('BRICK', X - k - 1, y).put('BRICK', X + k + 1, y)
    c.put('DIRT', X, 10).put('BRICK', X + 1, 10).put('DIRT', X - 1, 10)   # the plug, reached from the left
    c.put('MAGIC', X, 11).put('BRICK', X - 1, 11).put('BRICK', X + 1, 11)
    for y in range(12, 20):                                      # bottom bulb, empty
        k = y - 12
        c.line('SPACE', X - k, y, X + k, y)
        c.put('BRICK', X - k - 1, y).put('BRICK', X + k + 1, y)
    c.line('BRICK', X - 9, 20, X + 9, 20)
    c.put('DIRT', X - 8, 19)                                     # a door in the bottom bulb
    c.start(2, 10).exit(37, 19)
    c.script = [('go', X - 1, 10), ('snap', 'R')]
    return c


def l_rock_rain():
    c = Cave('L', 'ROCK RAIN', 'MAGIC TURNS THE STONE RAIN TO GEMS', 45, 5, 10, 160, 12, AIR, magic=120)
    c.spouts(3, 36, 3)
    c.pins('BRICK', 4, 5, 36, 8, 8, 3)
    c.line('MAGIC', 1, 11, 38, 11)
    c.box('DIRT', 1, 17, 38, 20)
    c.put('INBOX', 2, 16).exit(37, 16)
    c.shower(20, 190, 130)
    return c


# ===================================================================== IV GREEN CAVERNS
def m_amoeba():
    c = Cave('M', 'THE AMOEBA', 'THE AMOEBA SPREADS - GATHER QUICKLY', 25, 10, 20, 150, 13,
             [('DIRT', 84), ('BOULDER', 6), ('DIAMOND', 6), ('SPACE', 4)], amoeba=25)
    c.box('SPACE', 16, 16, 24, 18)
    c.put('AMOEBA', 18, 17).put('AMOEBA', 22, 17)
    c.line('DIAMOND', 3, 4, 12, 8).line('DIAMOND', 36, 4, 27, 8)
    c.start(2, 2).exit(37, 2)
    return c


def n_creeping_walls():
    c = Cave('N', 'CREEPING WALLS', 'WALLS GROW INTO ANY GAP BESIDE THEM', 25, 15, 25, 150, 14,
             [('DIRT', 84), ('BOULDER', 7), ('DIAMOND', 5), ('SPACE', 4)])
    for y in (5, 10, 15):
        c.line('EXPWALL', 6, y, 33, y)
        c.line('DIAMOND', 8, y + 2, 31, y + 2, 3)
    c.start(2, 2).exit(37, 19)
    return c


def o_tree():
    c = Cave('O', 'THE TREE', 'PICK THE FRUIT BEFORE THE ROOTS SPREAD', 30, 10, 20, 170, 15, AIR, amoeba=40)
    c.ellipse('DIRT', 19.5, 6, 14, 4)                            # the crown
    c.mixbox(8, 4, 31, 8, [('DIRT', 60), ('DIAMOND', 28), ('BOULDER', 12)])
    c.ellipse('DIRT', 19.5, 6, 14, 4, ring=True)
    c.box('BRICK', 18, 10, 21, 17)                               # trunk
    c.line('BRICK', 17, 10, 13, 8).line('BRICK', 22, 10, 26, 8)  # boughs
    c.mixbox(1, 17, 38, 20, [('DIRT', 90), ('DIAMOND', 6), ('BOULDER', 4)])
    c.box('BRICK', 18, 17, 21, 17)
    c.put('AMOEBA', 12, 19).put('AMOEBA', 27, 19)                # the roots
    c.start(2, 16).exit(37, 16)
    return c


def p_emerald_rain():
    c = Cave('P', 'EMERALD RAIN', 'GATHER THE RAIN BEFORE THE AMOEBA DOES', 40, 5, 10, 160, 16, AIR, amoeba=20)
    c.spouts(4, 36, 4)
    for cx in (12, 27):                                          # two leaves, veined
        for y in range(4, 13):
            for x in range(cx - 8, cx + 9):
                inside = ((x - cx) / 7.5) ** 2 + ((y - 8) / 3.5) ** 2 <= 1
                edge = inside and ((x - cx) / 6.5) ** 2 + ((y - 8) / 2.5) ** 2 > 1
                if edge and (x + y) % 2 == 0:
                    c.put('BRICK', x, y)
        dotted(c, 'BRICK', cx - 5, 8, cx + 5, 8)
    c.box('DIRT', 1, 16, 38, 20)
    c.put('AMOEBA', 10, 17).put('AMOEBA', 29, 17)
    c.box('DIRT', 1, 12, 2, 15)
    c.put('INBOX', 1, 15).exit(38, 15)
    c.shower(14, 20, 150)
    return c


# ===================================================================== V THE CORE
def q_gauntlet():
    c = Cave('Q', 'GAUNTLET', 'FIREFLIES GUARD THE TUNNELS', 30, 15, 25, 170, 17,
             [('DIRT', 80), ('BOULDER', 10), ('DIAMOND', 7), ('SPACE', 3)], speed=5)
    for i, y in enumerate((4, 8, 12, 16)):
        c.line('BRICK', 1, y, 38, y)
        gap = 35 if i % 2 == 0 else 2
        c.line('DIRT', gap, y, gap + 2, y)
        c.line('SPACE', 3, y + 1, 36, y + 1)
        c.put('FIRE0', 10 + i * 6, y + 1)
        for dx in (8, 26):                                       # rocks over a plug in the roof
            drop(c, dx - i * 2, y)
    c.start(2, 2).exit(37, 20)
    return c


def r_twin_vaults():
    c = Cave('R', 'TWIN VAULTS', 'FEED THE VAULTS THEIR STONES', 35, 10, 20, 170, 18,
             [('DIRT', 64), ('BOULDER', 22), ('DIAMOND', 4), ('SPACE', 10)], magic=40)
    for x0 in (3, 23):
        c.rect('STEEL', x0, 13, x0 + 13, 20).box('DIAMOND', x0 + 1, 18, x0 + 12, 19)
        c.box('SPACE', x0 + 1, 14, x0 + 12, 17)
        c.line('MAGIC', x0 + 3, 13, x0 + 10, 13)
        c.put('BUTT3', x0 + 6, 15)
    c.put('DIRT', 3, 17).put('DIRT', 36, 17)
    c.start(19, 2).exit(19, 20)
    return c


def s_treasure_storm():
    c = Cave('S', 'TREASURE STORM', 'THE LAST RAIN - GEMS, ROCKS AND WINGS', 60, 5, 10, 180, 19, AIR,
             magic=60, speed=5)
    c.spouts(3, 37, 3)
    crown = [(7, 6), (12, 11), (15, 8), (19, 4), (23, 8), (26, 11), (31, 6)]
    for (x1, y1), (x2, y2) in zip(crown, crown[1:]):             # a crown drawn in pegs
        dotted(c, 'BRICK', x1, y1, x2, y2)
    dotted(c, 'BRICK', 7, 13, 31, 13)
    for x, y in crown[::2]:
        c.put('BRICK', x, y)
    c.put('BUTT3', 10, 9).put('BUTT3', 28, 9)
    c.line('MAGIC', 26, 16, 37, 16)
    c.box('DIRT', 1, 18, 38, 20)
    c.box('DIRT', 1, 14, 2, 17)
    c.put('INBOX', 1, 17).exit(38, 17)
    c.shower(18, 70, 200)
    return c


def t_core():
    c = Cave('T', 'THE CORE', 'EVERYTHING YOU HAVE LEARNED', 50, 20, 30, 200, 20,
             [('DIRT', 72), ('BOULDER', 15), ('DIAMOND', 7), ('SPACE', 6)], magic=40, speed=5)
    c.rect('STEEL', 14, 8, 25, 14).box('DIAMOND', 15, 12, 24, 13).box('SPACE', 15, 9, 24, 11)
    c.line('MAGIC', 17, 8, 22, 8)
    c.put('DIRT', 25, 13)
    for bx, by in ((3, 3), (29, 3)):                             # firefly lanterns
        c.rect('SPACE', bx, by, bx + 6, by + 4)
        c.box('BRICK', bx + 1, by + 1, bx + 5, by + 3)
        c.line('DIAMOND', bx + 2, by + 2, bx + 4, by + 2)
        c.put('FIRE0', bx + 3, by + 4)
        drop(c, bx + 1, by - 1)
        drop(c, bx + 5, by - 1)
    c.box('SPACE', 4, 16, 9, 18).rect('BRICK', 3, 15, 10, 19).line('SPACE', 6, 15, 7, 15)
    c.line('DIRT', 4, 14, 9, 14).box('BOULDER', 6, 12, 7, 13).put('BUTT0', 9, 16)
    c.line('EXPWALL', 12, 18, 27, 18)
    c.start(19, 2).exit(38, 20)
    return c


CAVES = [a_first_light, b_rolling_stones, c_mountain, d_jewel_shower,
         e_lanterns, f_butterfly_pens, g_moth, h_sparkfall,
         i_magic_wall, j_alchemy_shafts, k_hourglass, l_rock_rain,
         m_amoeba, n_creeping_walls, o_tree, p_emerald_rain,
         q_gauntlet, r_twin_vaults, s_treasure_storm, t_core]
