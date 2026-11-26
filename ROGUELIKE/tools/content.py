"""content.py - LUMEN's creatures, items, spells and zones."""
from defs import BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE  # noqa: F401

# ------------------------------------------------------------------ monsters
AI = {n: i for i, n in enumerate(['CHASE', 'ERRATIC', 'RANGED', 'PHASE', 'SWIM', 'AMBUSH', 'TURRET',
                                   'NPC', 'BOSS', 'FLEE'])}
MF_FLY = 0x01        # crosses water and lava
MF_FIRE = 0x02       # immune to fire
MF_COLD = 0x04       # immune to cold (and freezing)
MF_UNDEAD = 0x08
MF_SHADE = 0x10      # seen only in bright light; burnt by flares
MF_POISON = 0x20     # its bite poisons
MF_DRAIN = 0x40      # its touch drinks lantern oil
MF_BURST = 0x80      # bursts into a spore cloud when it dies

# name, glyph, colour, hp, atk, def, speed (energy per turn, 2 = normal),
#   ai, flags, xp, light (S, hue) or None, bolt (ranged kind) or None,
#   disguise glyph (ambushers) or None
MONSTERS = [
    ('RAT',        0x1F2, RED,     4,  2, 0, 3, 'CHASE',   0,                         2, None, None, None),
    ('BAT',        0x0CB, MAGENTA, 3,  2, 0, 4, 'ERRATIC', MF_FLY,                    2, None, None, None),
    ('SKELETON',   0x1F6, WHITE,   9,  4, 1, 2, 'CHASE',   MF_UNDEAD,                 5, None, None, None),
    ('ZOMBIE',     0x143, GREEN,  15,  5, 1, 1, 'CHASE',   MF_UNDEAD,                 6, None, None, None),
    ('SPIDER',     0x11E, RED,     6,  3, 0, 3, 'CHASE',   MF_POISON,                 4, None, None, None),
    ('SLIME',      0x14E, GREEN,  11,  3, 0, 1, 'CHASE',   MF_POISON,                 4, (2, 'TOXIC'), None, None),
    ('SPORELING',  0x13C, YELLOW,  5,  2, 0, 2, 'CHASE',   MF_BURST,                  4, (2, 'TOXIC'), None, None),
    ('BEETLE',     0x12C, CYAN,   10,  4, 3, 2, 'CHASE',   0,                         6, None, None, None),
    ('WISP',       0x150, YELLOW,  4,  0, 0, 3, 'FLEE',    MF_FLY,                    3, (4, 'SUN'), None, None),
    ('DROWNED',    0x145, CYAN,   13,  5, 1, 2, 'CHASE',   MF_UNDEAD | MF_COLD,       6, None, None, None),
    ('EEL',        0x1F0, CYAN,    9,  5, 0, 3, 'SWIM',    MF_FLY,                    6, None, None, None),
    ('FROGLING',   0x12E, GREEN,   7,  4, 0, 3, 'ERRATIC', 0,                         5, None, None, None),
    ('CRAB',       0x133, RED,    11,  4, 3, 2, 'CHASE',   0,                         6, None, None, None),
    ('IMP',        0x12D, RED,     9,  4, 1, 3, 'RANGED',  MF_FIRE | MF_FLY,          8, (3, 'WARM'), 'FIRE', None),
    ('FLAMELING',  0x1F4, YELLOW, 16,  6, 2, 2, 'CHASE',   MF_FIRE | MF_FLY,         12, (5, 'WARM'), None, None),
    ('GOLEM',      0x1F7, WHITE,  28,  8, 4, 1, 'CHASE',   MF_FIRE,                  15, None, None, None),
    ('SALAMANDER', 0x1F1, RED,    12,  6, 1, 3, 'CHASE',   MF_FIRE | MF_FLY,         10, (2, 'BLOOD'), None, None),
    ('WRAITH',     0x137, CYAN,   14,  6, 1, 2, 'PHASE',   MF_COLD | MF_UNDEAD,      12, (2, 'COLD'), None, None),
    ('ICESPIDER',  0x11E, CYAN,   12,  6, 1, 3, 'CHASE',   MF_COLD | MF_POISON,      10, None, None, None),
    ('YETI',       0x135, WHITE,  26,  9, 2, 2, 'CHASE',   MF_COLD,                  16, None, None, None),
    ('ICEWISP',    0x150, CYAN,    5,  0, 0, 3, 'FLEE',    MF_FLY | MF_COLD,          3, (4, 'COLD'), None, None),
    ('SHADE',      0x136, MAGENTA, 14, 7, 0, 3, 'CHASE',   MF_SHADE | MF_UNDEAD | MF_DRAIN, 14, None, None, None),
    ('MIMIC',      0x13B, YELLOW, 20,  8, 2, 2, 'AMBUSH',  0,                        15, None, None, 0x0C5),
    ('BOOKWING',   0x0CC, YELLOW,  8,  4, 0, 4, 'ERRATIC', MF_FLY,                    8, None, None, None),
    ('LICH',       0x138, MAGENTA, 24, 6, 2, 2, 'RANGED',  MF_UNDEAD | MF_COLD,      20, (3, 'ARCANE'), 'ARCANE', None),
    ('GARGOYLE',   0x12F, WHITE,  22,  8, 4, 2, 'AMBUSH',  MF_FLY,                   16, None, None, 0x144),
    ('GEODE',      0x1F7, CYAN,   32, 10, 5, 1, 'CHASE',   MF_COLD,                  22, (3, 'COLD'), None, None),
    ('EYE',        0x0CF, MAGENTA, 18, 8, 1, 2, 'TURRET',  MF_FLY,                   18, (3, 'ARCANE'), 'ARCANE', None),
    ('KNIGHT',     0x1F5, WHITE,  30, 10, 4, 2, 'CHASE',   0,                        24, None, None, None),
    ('DARKKNIGHT', 0x1F5, MAGENTA, 34, 11, 4, 2, 'CHASE',  MF_UNDEAD | MF_DRAIN,     28, None, None, None),
    ('KING',       0x139, WHITE,  90, 10, 3, 2, 'BOSS',    MF_UNDEAD | MF_FIRE | MF_COLD | MF_DRAIN, 250, None,
     'ARCANE', None),
    # friendly folk (bump to talk)
    ('HERMIT',     0x144, YELLOW,  99, 0, 9, 0, 'NPC',     0,                         0, (3, 'WARM'), None, None),
    ('TRADER',     0x141, GREEN,   99, 0, 9, 0, 'NPC',     0,                         0, (3, 'WARM'), None, None),
    ('SAGE',       0x144, CYAN,    99, 0, 9, 0, 'NPC',     0,                         0, (3, 'COLD'), None, None),
    ('SMITH',      0x141, RED,     99, 0, 9, 0, 'NPC',     0,                         0, (4, 'WARM'), None, None),
    ('SEER',       0x0C9, WHITE,   99, 0, 9, 0, 'NPC',     0,                         0, (3, 'COLD'), None, None),
    ('GHOST',      0x137, WHITE,   99, 0, 9, 0, 'NPC',     0,                         0, (3, 'ARCANE'), None, None),
    ('ORACLE',     0x0CD, YELLOW,  99, 0, 9, 0, 'NPC',     0,                         0, (4, 'SUN'), None, None),
]
MON = {m[0]: i + 1 for i, m in enumerate(MONSTERS)}       # 0 = no monster
BOLTS = {'FIRE': 0, 'FROST': 1, 'ARCANE': 2, 'LIGHT': 3, 'SPARK': 4}

# ------------------------------------------------------------------ items
IK = {n: i for i, n in enumerate(['GOLD', 'HPOT', 'MPOT', 'OIL', 'MAP', 'TELE', 'BOMB', 'KEY', 'SIGIL',
                                   'BOOK', 'WEAPON', 'ARMOUR'])}
SPELLS = [('FIREBOLT', 2), ('FROST', 3), ('FLARE', 3), ('HEAL', 4), ('BLINK', 3), ('LIGHTNING', 6)]
SP = {s[0]: i for i, s in enumerate(SPELLS)}
# weapons: name, min, max, element (0 none 1 fire 2 cold 3 light), light (S, hue)
WEAPONS = [
    ('DAGGER', 1, 4, 0, None), ('SWORD', 2, 6, 0, None), ('MACE', 3, 7, 0, None), ('AXE', 3, 9, 0, None),
    ('SPEAR', 4, 8, 0, None), ('WARHAMMER', 5, 11, 0, None), ('FLAMEBRAND', 4, 10, 1, (3, 'WARM')),
    ('FROSTBLADE', 4, 10, 2, (3, 'COLD')), ('SUNBLADE', 7, 13, 3, (4, 'SUN')),
]
# armours: name, defence, MP bonus
ARMOURS = [('RAGS', 0, 0), ('LEATHER', 1, 0), ('SCALE', 2, 0), ('CHAIN', 3, 0), ('PLATE', 5, 0),
           ('MAGEROBE', 1, 6), ('SHADOWCLOAK', 3, 4)]
# items: name, glyph, colour, kind, value (spell / weapon / armour / sigil bit), price
ITEMS = [
    ('GOLD',     0x064, YELLOW,  'GOLD', 0, 0),
    ('HPOTION',  0x151, RED,     'HPOT', 0, 20),
    ('MPOTION',  0x151, MAGENTA, 'MPOT', 0, 20),
    ('OIL',      0x153, YELLOW,  'OIL', 0, 12),
    ('MAPSCROLL', 0x049, WHITE,  'MAP', 0, 30),
    ('TELESCROLL', 0x049, CYAN,  'TELE', 0, 25),
    ('BOMB',     0x13E, RED,     'BOMB', 0, 25),
    ('KEY',      0x1FE, YELLOW,  'KEY', 0, 0),
    ('EMBERSIGIL', 0x183, RED,   'SIGIL', 1, 0),
    ('FROSTSIGIL', 0x183, CYAN,  'SIGIL', 2, 0),
    ('SHADOWSIGIL', 0x183, MAGENTA, 'SIGIL', 4, 0),
]
for _i, _s in enumerate(SPELLS):
    ITEMS.append(('BOOK_' + _s[0], 0x1FB, [YELLOW, CYAN, WHITE, GREEN, MAGENTA, WHITE][_i], 'BOOK', _i, 60))
for _i, _w in enumerate(WEAPONS):
    ITEMS.append((_w[0], 0x15B, [WHITE, WHITE, WHITE, WHITE, WHITE, WHITE, RED, CYAN, YELLOW][_i], 'WEAPON', _i,
                  [0, 30, 45, 60, 70, 100, 140, 140, 0][_i]))
for _i, _a in enumerate(ARMOURS):
    ITEMS.append((_a[0], 0x149, [WHITE, YELLOW, WHITE, CYAN, WHITE, MAGENTA, MAGENTA][_i], 'ARMOUR', _i,
                  [0, 25, 50, 80, 130, 90, 0][_i]))
IT = {it[0]: i + 1 for i, it in enumerate(ITEMS)}         # 0 = no item

# ------------------------------------------------------------------ zones
ST_CAVE, ST_WATER, ST_LAVA, ST_PILLARS, ST_FUNGUS, ST_CRYSTAL, ST_BOOKS, ST_BONES = [1 << _i for _i in range(8)]
# name, theme, style, wall light (tile, count), monster pool (4), count (lo, hi),
#   loot pool (4), prefabs [(name, item slots)], links [(dest, 'room' | prefab)], npc
ZONES = [
    ('THE HOLLOW CRYPT', 'CRYPT', ST_PILLARS | ST_BONES, ('SCONCE', 7),
     ['RAT', 'BAT', 'SKELETON', 'SPIDER'], (8, 11), ['HPOTION', 'OIL', 'GOLD', 'SWORD'],
     [('PLATES', ['KEY', 'MPOTION'])], [(1, 'room'), (2, 'room')], 'HERMIT'),
    ('FUNGAL GROTTO', 'GROTTO', ST_CAVE | ST_FUNGUS | ST_WATER, ('FUNGUS', 0),
     ['SLIME', 'SPORELING', 'BEETLE', 'WISP'], (9, 12), ['HPOTION', 'OIL', 'GOLD', 'LEATHER'],
     [('LOCKVAULT', ['BOOK_FLARE', 'GOLD']), ('SUNGATE', ['SHADOWCLOAK', 'OIL'])], [(0, 'room'), (3, 'room')], 'TRADER'),
    ('DROWNED HALLS', 'DROWNED', ST_WATER | ST_PILLARS, ('CRYSTAL', 5),
     ['DROWNED', 'EEL', 'FROGLING', 'CRAB'], (9, 12), ['MPOTION', 'OIL', 'GOLD', 'MACE'],
     [('ISLAND', ['KEY'])], [(0, 'room'), (4, 'room')], 'SAGE'),
    ('EMBER FORGE', 'FORGE', ST_LAVA | ST_PILLARS, ('SCONCE', 6),
     ['IMP', 'FLAMELING', 'GOLEM', 'SALAMANDER'], (9, 12), ['HPOTION', 'BOMB', 'GOLD', 'AXE'],
     [('BRAZIER', ['EMBERSIGIL']), ('LOCKVAULT', ['FLAMEBRAND', 'HPOTION'])], [(1, 'room'), (5, 'room')],
     'SMITH'),
    ('FROST VAULT', 'FROST', ST_CAVE | ST_WATER | ST_CRYSTAL, ('CRYSTAL', 7),
     ['WRAITH', 'ICESPIDER', 'YETI', 'ICEWISP'], (9, 12), ['MPOTION', 'OIL', 'GOLD', 'CHAIN'],
     [('ICE', ['FROSTSIGIL']), ('SUNGATE', ['SUNBLADE', 'MPOTION'])], [(2, 'room'), (5, 'room')], 'SEER'),
    ('SHADOW LIBRARY', 'LIBRARY', ST_BOOKS, ('RUNE', 3),
     ['SHADE', 'MIMIC', 'BOOKWING', 'LICH'], (10, 13), ['HPOTION', 'MAPSCROLL', 'OIL', 'MAGEROBE'],
     [('LEVERS', ['SHADOWSIGIL']), ('SEAL', [])], [(3, 'room'), (4, 'room'), (6, 'SEAL')], 'GHOST'),
    ('CRYSTAL SANCTUM', 'SANCTUM', ST_CRYSTAL | ST_PILLARS, ('CRYSTAL', 8),
     ['GEODE', 'EYE', 'KNIGHT', 'GARGOYLE'], (10, 13), ['HPOTION', 'MPOTION', 'TELESCROLL', 'WARHAMMER'],
     [('MIRROR', [])], [(5, 'room'), (7, 'MIRROR')], 'ORACLE'),
    ('THE HOLLOW THRONE', 'THRONE', ST_PILLARS | ST_BONES, ('SCONCE', 3),
     ['DARKKNIGHT', 'SHADE', 'LICH', 'KNIGHT'], (8, 10), ['HPOTION', 'MPOTION', 'OIL', 'PLATE'],
     [('THRONE', [])], [(6, 'room')], None),
]
