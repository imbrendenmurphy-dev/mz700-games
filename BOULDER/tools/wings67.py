"""wings67.py - the caves added in UNDERMINED 2.4: wing VI (Crystal Vaults),
wing VII (The Haunted Deep) and the six bonus caves (hidden chambers)
found between the wings.

  VI  CRYSTAL VAULTS  U Geodes          V Seeping Halls     W The Crystal Vault
  VII HAUNTED DEEP    X Shades          Y Catacombs         Z Heart of the Mountain

New things to meet:
  geode  - round; a falling rock cracks it open into a gem
  slime  - rocks and gems resting on it seep through, now and then
  key    - take it and every lock in the cave opens
  lock   - a door that stays shut until the key is taken
  shade  - a ghost that hunts you through empty space (never earth), a
           step every other tick; touch it and you die, drop a rock on it
           and it bursts into gems

A bonus cave is one screen, has a short clock and costs no life: run out
of time or die and the game simply goes on to the next wing.
"""
from caves import Cave, BONUS_THEME

ICY = [('DIRT', 86), ('BOULDER', 8), ('DIAMOND', 1), ('SPACE', 5)]
SPARSE = [('DIRT', 87), ('BOULDER', 8), ('DIAMOND', 0.5), ('SPACE', 4.5)]
AIR = [('SPACE', 100)]


def bonus(letter, name, hint, need, dval, xval, fill, **kw):
    c = Cave(letter, name, hint, need, dval, xval, 60, 100 + ord(letter), fill, intermission=True,
             theme=BONUS_THEME, **kw)
    return c


def hang(c, x, y, e='GEODE', rocks=1):
    """a rock on a plug of earth over a geode (or gem) - dig the plug from the side"""
    c.put(e, x, y)
    c.put('DIRT', x, y - 1)
    for k in range(rocks):
        c.put('BOULDER', x, y - 2 - k)


# ===================================================================== bonus caves
def b1_crystal_rain():
    c = bonus('1', 'CRYSTAL RAIN', 'NO LIVES LOST HERE - GRAB ALL YOU CAN', 30, 15, 30, AIR)
    c.spouts(3, 36, 3)
    c.pins('BRICK', 4, 5, 36, 13, 8, 4)
    c.box('DIRT', 1, 18, 38, 20)
    c.box('DIRT', 1, 15, 2, 17)
    c.put('INBOX', 1, 17).exit(38, 17)
    c.shower(40, 0, 90)
    return c


def b2_butterfly_garden():
    c = bonus('2', 'BUTTERFLY GARDEN', 'DROP A ROCK INTO EVERY PEN', 30, 10, 20,
              [('DIRT', 96), ('SPACE', 4)])
    for bx in (4, 16, 28):
        for by in (6, 15):
            c.box('SPACE', bx, by, bx + 5, by + 3)
            c.rect('BRICK', bx - 1, by - 1, bx + 6, by + 4)
            c.line('SPACE', bx + 2, by - 1, bx + 3, by - 1)
            c.line('DIRT', bx + 2, by - 2, bx + 3, by - 2)
            c.box('BOULDER', bx + 2, by - 3, bx + 3, by - 3)
            c.put('BUTT0', bx + 5, by)
    c.start(1, 1).exit(38, 20)
    return c


def b3_alchemists_vat():
    c = bonus('3', "THE ALCHEMIST'S VAT", 'FEED THE VAT - IT PAYS IN GEMS', 25, 10, 20,
              [('DIRT', 70), ('BOULDER', 30)], magic=45)
    c.line('MAGIC', 2, 11, 37, 11)
    c.box('SPACE', 1, 12, 38, 16)
    c.box('DIRT', 1, 17, 38, 20)
    c.box('DIRT', 1, 1, 3, 10).box('DIRT', 36, 1, 38, 10)
    c.line('BRICK', 1, 11, 1, 11).line('BRICK', 38, 11, 38, 11)
    c.put('DIRT', 1, 11).put('DIRT', 38, 11)
    c.start(2, 2).exit(38, 20)
    return c


def b4_honeycomb():
    c = bonus('4', 'THE HONEYCOMB', 'EVERY CELL HOLDS A LITTLE HONEY', 40, 10, 20,
              [('DIRT', 100)])
    for row, y in enumerate(range(2, 19, 4)):
        off = 3 if row % 2 else 0
        for x in range(2 + off, 36, 6):
            c.rect('BRICK', x, y, x + 4, y + 3)
            c.box('DIAMOND', x + 1, y + 1, x + 3, y + 2)
            c.put('DIRT', x + 2, y + 3)
            c.put('DIRT', x + 2, y)
    c.start(1, 1).exit(38, 20)
    return c


def b5_geode_field():
    c = bonus('5', 'GEODE FIELD', 'A FALLING ROCK CRACKS A GEODE', 24, 10, 20,
              [('DIRT', 96), ('SPACE', 4)])
    for y in (6, 12, 18):
        for x in range(4, 37, 4):
            hang(c, x, y)
    c.start(1, 1).exit(38, 20)
    return c


def b6_treasure_vault():
    c = bonus('6', 'THE TREASURE VAULT', 'ONE KEY OPENS EVERY DOOR', 40, 10, 20,
              [('DIRT', 92), ('BOULDER', 4), ('SPACE', 4)])
    for bx in (4, 15, 26):
        c.rect('STEEL', bx, 3, bx + 8, 9).box('DIAMOND', bx + 1, 4, bx + 7, 8)
        c.put('LOCK', bx + 4, 9)
        c.rect('STEEL', bx, 12, bx + 8, 18).box('DIAMOND', bx + 1, 13, bx + 7, 17)
        c.put('LOCK', bx + 4, 12)
    c.put('KEY', 37, 1)
    c.start(1, 20).exit(38, 20)
    return c


# ===================================================================== VI CRYSTAL VAULTS
def u_geodes():
    c = Cave('U', 'GEODES', 'A FALLING ROCK CRACKS A GEODE OPEN', 34, 15, 25, 160, 21, ICY,
             speed=5, w=64, h=32)
    # geodes hanging under rock columns, like the gems of cave A
    for x, y in ((8, 7), (17, 10), (26, 6), (35, 9), (46, 7), (55, 11), (6, 19), (15, 23),
                 (24, 18), (33, 25), (44, 21), (53, 26), (60, 20)):
        hang(c, x, y, rocks=2)
        c.put('DIRT', x - 1, y).put('DIRT', x + 1, y)
    # a geode shelf: rocks on a ledge above a row of geodes - push them off
    c.box('SPACE', 20, 14, 42, 15).line('BRICK', 20, 16, 42, 16)
    c.line('GEODE', 21, 15, 41, 15, 4)
    c.line('BOULDER', 23, 13, 39, 13, 4).line('DIRT', 23, 14, 39, 14, 4)
    # gem nests among the geodes
    for x, y in ((4, 28), (30, 29), (58, 4)):
        c.box('DIAMOND', x, y, x + 2, y + 1)
    c.start(2, 2).exit(61, 29)
    return c


def v_seeping_halls():
    c = Cave('V', 'SEEPING HALLS', 'ROCKS SEEP THROUGH THE SLIME - WAIT', 36, 15, 25, 180, 22, ICY,
             speed=5, w=64, h=32)
    # three halls stacked, floors of slime: rocks above drip into the halls
    for y0 in (6, 16):
        c.line('SLIME', 6, y0, 57, y0)
        c.box('SPACE', 6, y0 + 1, 57, y0 + 3)
        c.line('BRICK', 5, y0 + 4, 58, y0 + 4)
        c.line('BRICK', 5, y0, 5, y0 + 4).line('BRICK', 58, y0, 58, y0 + 4)
        c.line('BOULDER', 8, y0 - 1, 56, y0 - 1, 3)
        # butterflies patrol the hall, geodes line its floor
        c.put('BUTT0', 57, y0 + 1)
        c.line('GEODE', 11, y0 + 3, 53, y0 + 3, 6)
    # doors into the halls from the side
    c.put('DIRT', 58, 8).put('DIRT', 5, 18)
    c.box('DIRT', 59, 7, 62, 9).box('DIRT', 1, 17, 4, 19)
    # the bottom: gems drip through a slime ceiling into a pit
    c.line('SLIME', 20, 26, 44, 26).line('DIAMOND', 20, 25, 44, 25, 2)
    c.box('SPACE', 20, 27, 44, 29).rect('BRICK', 19, 26, 45, 30).line('SLIME', 20, 26, 44, 26)
    c.put('DIRT', 45, 29)
    c.start(2, 2).exit(61, 29)
    return c


def w_crystal_vault():
    c = Cave('W', 'THE CRYSTAL VAULT', 'FIND THE KEY - THE VAULT AWAITS', 50, 15, 25, 200, 23, SPARSE,
             speed=5, w=64, h=32)
    # the vault: a giant cut crystal drawn in steel, locked
    cx, cy = 32, 16
    for dy in range(-9, 10):
        half = 14 - abs(dy) * 14 // 10 if dy > 0 else 14 - abs(dy) // 2
        c.put('STEEL', cx - half, cy + dy).put('STEEL', cx + half, cy + dy)
        if dy in (-9,):
            c.line('STEEL', cx - half, cy + dy, cx + half, cy + dy)
        for x in range(cx - half + 1, cx + half):
            if dy != -9:
                c.put('DIAMOND' if (x + dy) % 3 == 0 else ('GEODE' if (x - dy) % 5 == 0 else 'SPACE'), x, cy + dy)
    c.line('BOULDER', cx - 10, cy - 8, cx + 10, cy - 8, 2)
    c.put('LOCK', cx, cy - 9).put('LOCK', cx - 1, cy - 9).put('LOCK', cx + 1, cy - 9)
    # the key, far off behind slime and geodes
    c.rect('BRICK', 54, 22, 61, 29).box('SPACE', 55, 23, 60, 28)
    c.put('KEY', 59, 28).line('SLIME', 55, 23, 60, 23).line('BOULDER', 55, 22, 60, 22, 2)
    c.put('DIRT', 54, 27)
    # outer gem pockets with geodes
    for x, y in ((6, 6), (54, 6), (6, 25)):
        c.box('DIAMOND', x, y, x + 2, y + 1)
        hang(c, x + 4, y + 1)
    c.start(2, 2).exit(61, 2)
    return c


# ===================================================================== VII THE HAUNTED DEEP
def x_shades():
    c = Cave('X', 'SHADES', 'LURE IT UNDER A ROCK - SNAP - RUN', 36, 15, 25, 160, 24,
             [('DIRT', 88), ('BOULDER', 8), ('DIAMOND', 1), ('SPACE', 3)], speed=5, w=64, h=32)
    # a shade waits in each crypt; its passage ends under a rock held up by a
    # plug of earth.  Come close and it creeps out to meet you, right under
    # the rock: snap the plug and step away before the burst
    for x, y in ((8, 6), (30, 5), (48, 9), (6, 20), (26, 18), (44, 23)):
        c.box('DIRT', x - 1, y - 3, x + 9, y + 3)
        c.box('SPACE', x, y, x + 3, y + 1)
        c.line('DIAMOND', x, y + 2, x + 3, y + 2)
        c.rect('BRICK', x - 1, y - 1, x + 4, y + 3)
        c.put('SHADE', x + 1, y)
        c.line('SPACE', x + 4, y, x + 6, y)               # the passage out, on its own row
        c.line('BRICK', x + 5, y + 1, x + 6, y + 1)
        c.put('DIRT', x + 6, y - 1).put('BOULDER', x + 6, y - 2).put('BRICK', x + 7, y - 2)
    c.start(2, 2).exit(61, 29)
    # the bot's plan: crush the shades crypt by crypt, then gather
    c.script = [('drop', x + 6, y - 1) for x, y in ((8, 6), (30, 5), (6, 20), (26, 18), (48, 9), (44, 23))]
    return c


def y_catacombs():
    c = Cave('Y', 'CATACOMBS', 'THE DEAD WALK THE OLD PASSAGES', 40, 15, 25, 200, 25,
             [('DIRT', 85), ('BOULDER', 10), ('DIAMOND', 1), ('SPACE', 4)], speed=5, w=64, h=32)
    # old passages (open space) in a grid of brick tombs
    for y in range(5, 28, 6):
        c.line('SPACE', 4, y, 59, y)
    for x in range(4, 60, 11):
        c.line('SPACE', x, 5, x, 27)
    for ty in range(6, 27, 6):
        for tx in range(5, 56, 11):
            c.box('BRICK', tx, ty, tx + 9, ty + 4)
            c.box('DIAMOND', tx + 3, ty + 1, tx + 6, ty + 3)
            c.put('LOCK', tx + 4, ty)
            c.put('LOCK', tx + 5, ty + 4)
    # shades walk the passages; rocks overhang the crossings
    for x, y in ((15, 11), (37, 17), (48, 23), (26, 5)):
        c.put('SHADE', x, y)
    for x in range(4, 60, 11):
        c.put('BOULDER', x, 2).put('DIRT', x, 3).put('DIRT', x, 4)
    c.box('DIRT', 1, 1, 3, 4)
    c.put('KEY', 60, 29).box('DIRT', 56, 28, 62, 30)
    c.start(1, 1).exit(62, 1)
    return c


def crypt(c, x, y):
    """a shade in a brick crypt; its passage ends under a rock on a plug of earth"""
    c.box('DIRT', x - 1, y - 3, x + 9, y + 3)
    c.box('SPACE', x, y, x + 3, y + 1)
    c.line('DIAMOND', x, y + 2, x + 3, y + 2)
    c.rect('BRICK', x - 1, y - 1, x + 4, y + 3)
    c.put('SHADE', x + 1, y)
    c.line('SPACE', x + 4, y, x + 6, y)
    c.line('BRICK', x + 5, y + 1, x + 6, y + 1)
    c.put('DIRT', x + 6, y - 1).put('BOULDER', x + 6, y - 2).put('BRICK', x + 7, y - 2)
    return ('drop', x + 6, y - 1)


def z_heart():
    c = Cave('Z', 'HEART OF THE MOUNTAIN', 'THE LAST TREASURE - AND ITS KEEPERS', 50, 20, 30, 220, 26,
             [('DIRT', 82), ('BOULDER', 11), ('DIAMOND', 1), ('SPACE', 6)], magic=40, speed=5, w=64, h=32)
    # the heart: two lobes and a point, outlined in steel; gem-studded earth
    # within, and geodes hanging under rocks
    cx, cy = 32, 13

    def inside(x, y):
        u, v = (x - cx) / 13.0, -(y - cy) / 9.0
        return (u * u + v * v - 1) ** 3 - u * u * v * v * v <= 0
    for y in range(2, 30):
        for x in range(14, 51):
            if inside(x, y):
                edge = not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge:
                    c.put('STEEL', x, y)
                else:
                    c.put('DIAMOND' if (x + y) % 4 == 0 and x % 2 == 0 else 'DIRT', x, y)
    for x, y in ((24, 9), (40, 9), (28, 14), (36, 14), (32, 19), (20, 7), (44, 7)):
        hang(c, x, y)
    for x in (31, 32, 33):                             # the doors at the top of the cleft
        for y in range(2, 12):
            if c.g[y][x] == 'STEEL':
                c.put('LOCK', x, y)
                for yy in range(1, y):
                    c.put('DIRT', x, yy)
                break
    # its keepers wait in crypts around it; a firefly lantern on the way
    script = [crypt(c, 2, 8), crypt(c, 52, 6), crypt(c, 52, 22)]
    c.rect('SPACE', 3, 21, 9, 25).box('BRICK', 4, 22, 8, 24).line('DIAMOND', 5, 23, 7, 23)
    c.put('FIRE0', 6, 25).put('BOULDER', 4, 20).put('DIRT', 4, 21).put('BOULDER', 8, 20).put('DIRT', 8, 21)
    c.line('MAGIC', 15, 30, 48, 30)
    c.put('KEY', 2, 29).box('DIRT', 1, 27, 4, 30).put('KEY', 2, 29)
    c.start(2, 2).exit(61, 2)
    c.script = script[:1]
    return c
