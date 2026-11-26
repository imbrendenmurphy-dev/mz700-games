"""defs.py - LUMEN's game data in one place (tiles, light, themes, monsters,
items, spells, zones).  build.py turns it into build/gen_data.inc; mock.py
uses it to preview the look in Python.

Glyphs are display codes: 0x000-0x0FF = CG bank 0, 0x100-0x1FF = bank 1
(attribute bit 7).
"""
BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)

# ------------------------------------------------------------------ light hues
# ramp[level] = foreground colour at light level 0..7
HUES = [
    ('WARM',   [0, BLUE, BLUE, RED, RED, YELLOW, YELLOW, WHITE]),
    ('COLD',   [0, BLUE, BLUE, BLUE, CYAN, CYAN, WHITE, WHITE]),
    ('TOXIC',  [0, BLUE, BLUE, GREEN, GREEN, GREEN, YELLOW, WHITE]),
    ('ARCANE', [0, BLUE, BLUE, MAGENTA, MAGENTA, MAGENTA, WHITE, WHITE]),
    ('WHITE',  [0, BLUE, BLUE, CYAN, WHITE, WHITE, WHITE, WHITE]),
    ('BLOOD',  [0, BLUE, BLUE, RED, RED, RED, MAGENTA, YELLOW]),
    ('SUN',    [0, BLUE, RED, YELLOW, YELLOW, YELLOW, WHITE, WHITE]),
    ('SHADOW', [0, BLUE, BLUE, BLUE, MAGENTA, MAGENTA, MAGENTA, WHITE]),
]
HUE = {n: i for i, (n, _) in enumerate(HUES)}

# colour modes (how a tile is coloured by the light that falls on it)
M_LIT = 0      # the light's ramp at every level
M_TINT = 1     # levels 1-2 blue, 3-4 the tile's colour, 5-7 the light's ramp
M_FIX = 2      # levels 1-2 blue, then the tile's colour
M_SELF = 3     # always the tile's colour (it glows)

# tile flags
F_OPAQUE = 0x01
F_SOLID = 0x02
F_LIQUID = 0x04     # flyers cross it
F_BUMP = 0x08       # moving into it does something
F_DOOR = 0x10       # monsters may open / pass
F_FLOORY = 0x20     # counts as floor for generation / items / spawning
F_ANIM = 0x40       # shimmers (alternate glyph on odd ticks)
F_HOT = 0x80        # hurts / ambient particles

# name, flags, glyph, bright glyph (level >= 6), mode, colour, bg (when lit),
#   light (level, hue) or None, ambient particle kind or None
# Tiles 1-3 (WALL, FLOOR, FLOOR2) take their look from the zone's theme.
TILES = [
    ('ROCK',     F_OPAQUE | F_SOLID,           0x043, 0x043, M_TINT, BLUE, 0, None, None),
    ('WALL',     F_OPAQUE | F_SOLID,           0x043, 0x043, M_TINT, BLUE, 0, None, None),
    ('FLOOR',    F_FLOORY,                     0x185, 0x185, M_LIT, BLUE, 0, None, None),
    ('FLOOR2',   F_FLOORY,                     0x0F6, 0x0F6, M_LIT, BLUE, 0, None, None),
    ('DOOR',     F_OPAQUE | F_SOLID | F_BUMP | F_DOOR, 0x18B, 0x18B, M_FIX, YELLOW, 0, None, None),
    ('OPEN',     F_DOOR,                       0x052, 0x052, M_FIX, YELLOW, 0, None, None),
    ('LOCKED',   F_OPAQUE | F_SOLID | F_BUMP,  0x18B, 0x18B, M_FIX, RED, 0, None, None),
    ('SEAL',     F_OPAQUE | F_SOLID | F_BUMP,  0x18E, 0x18E, M_SELF, MAGENTA, 0, (3, 'ARCANE'), None),
    ('WATER',    F_SOLID | F_LIQUID | F_ANIM,  0x0A5, 0x093, M_FIX, CYAN, BLUE, None, 'DRIP'),
    ('LAVA',     F_SOLID | F_LIQUID | F_ANIM | F_HOT, 0x0A5, 0x093, M_SELF, RED, 0, (2, 'BLOOD'), 'BUBBLE'),
    ('ICE',      F_FLOORY,                     0x0D0, 0x0D0, M_FIX, CYAN, 0, None, None),
    ('OBSIDIAN', F_FLOORY,                     0x0F9, 0x0F9, M_TINT, MAGENTA, 0, None, None),
    ('PILLAR',   F_OPAQUE | F_SOLID,           0x047, 0x047, M_TINT, WHITE, 0, None, None),
    ('FUNGUS',   F_FLOORY,                     0x046, 0x046, M_SELF, GREEN, 0, (4, 'TOXIC'), 'SPORE'),
    ('CRYSTAL',  F_OPAQUE | F_SOLID,                      0x044, 0x044, M_SELF, CYAN, 0, (5, 'COLD'), 'GLINT'),
    ('BRAZOFF',  F_SOLID | F_BUMP,             0x174, 0x174, M_FIX, WHITE, 0, None, None),
    ('BRAZON',   F_SOLID,                      0x174, 0x174, M_SELF, YELLOW, 0, (7, 'WARM'), 'EMBER'),
    ('SCONCE',   F_OPAQUE | F_SOLID,           0x041, 0x041, M_SELF, YELLOW, 0, (6, 'WARM'), 'EMBER'),
    ('EXIT',     F_FLOORY,                     0x164, 0x164, M_SELF, WHITE, 0, (3, 'WHITE'), None),
    ('GATEP',    F_SOLID,                      0x0A2, 0x0A2, M_FIX, WHITE, 0, None, None),
    ('GATEB',    F_SOLID,                      0x0A2, 0x0A2, M_FIX, YELLOW, 0, None, None),
    ('GATEM',    F_SOLID,                      0x0A2, 0x0A2, M_FIX, CYAN, 0, None, None),
    ('GATEL',    F_SOLID,                      0x0A2, 0x0A2, M_FIX, MAGENTA, 0, None, None),
    ('GATEOPEN', F_FLOORY,                     0x0F0, 0x0F0, M_TINT, WHITE, 0, None, None),
    ('PLATE',    F_FLOORY,                     0x188, 0x188, M_FIX, MAGENTA, 0, None, None),
    ('BOULDER',  F_SOLID | F_BUMP,             0x08E, 0x08E, M_FIX, WHITE, 0, None, None),
    ('PLATEB',   F_SOLID | F_BUMP,             0x08E, 0x08E, M_FIX, YELLOW, 0, None, None),
    ('LEVER',    F_SOLID | F_BUMP,             0x02D, 0x02D, M_FIX, YELLOW, 0, None, None),
    ('GATELO',   F_FLOORY,                     0x0F0, 0x0F0, M_TINT, MAGENTA, 0, None, None),
    ('MIRRORA',  F_SOLID | F_BUMP,             0x02D, 0x02D, M_FIX, CYAN, 0, None, None),
    ('MIRRORB',  F_SOLID | F_BUMP,             0x059, 0x059, M_FIX, CYAN, 0, None, None),
    ('EMITTER',  F_SOLID,                      0x189, 0x189, M_SELF, WHITE, 0, (4, 'SUN'), 'GLINT'),
    ('TARGET',   F_SOLID,                      0x184, 0x184, M_FIX, YELLOW, 0, None, None),
    ('TARGETON', F_SOLID,                      0x189, 0x189, M_SELF, YELLOW, 0, (6, 'SUN'), 'GLINT'),
    ('WEB',      F_SOLID | F_BUMP,             0x06B, 0x06B, M_FIX, WHITE, 0, None, None),
    ('BOOKS',    F_OPAQUE | F_SOLID,           0x175, 0x175, M_TINT, RED, 0, None, None),
    ('ALTAR',    F_SOLID | F_BUMP,             0x17B, 0x17B, M_FIX, WHITE, 0, None, None),
    ('STATUE',   F_OPAQUE | F_SOLID,           0x144, 0x144, M_TINT, WHITE, 0, None, None),
    ('CHEST',    F_SOLID | F_BUMP,             0x0C5, 0x0C5, M_FIX, YELLOW, 0, None, None),
    ('CHESTO',   F_SOLID,                      0x0C5, 0x0C5, M_FIX, RED, 0, None, None),
    ('FOUNTAIN', F_SOLID | F_BUMP,             0x0AF, 0x0AF, M_SELF, CYAN, 0, (4, 'COLD'), 'DRIP'),
    ('DRYFONT',  F_SOLID,                      0x0AF, 0x0AF, M_FIX, WHITE, 0, None, None),
    ('BONES',    F_FLOORY,                     0x0E2, 0x0E2, M_FIX, WHITE, 0, None, None),
    ('CARPET',   F_FLOORY,                     0x0D0, 0x0D0, M_FIX, RED, 0, None, None),
    ('RUNE',     F_FLOORY,                     0x1A6, 0x1A6, M_SELF, MAGENTA, 0, (3, 'ARCANE'), 'MAGIC'),
    ('THRONE',   F_SOLID,                      0x17C, 0x17C, M_FIX, MAGENTA, 0, None, None),
    ('TRAP',     F_FLOORY,                     0x185, 0x185, M_LIT, BLUE, 0, None, None),
    ('TRAPSEEN', F_FLOORY,                     0x0FC, 0x0FC, M_FIX, RED, 0, None, None),
    # multi-cell objects (gen.asm OBJECTS): a round 2 x 2 column, a 3 x 3
    # column (corners + COLMID), a statue on its plinth, a great brazier
    ('COLTL',    F_OPAQUE | F_SOLID,           0x04E, 0x04E, M_TINT, WHITE, 0, None, None),
    ('COLTR',    F_OPAQUE | F_SOLID,           0x04D, 0x04D, M_TINT, WHITE, 0, None, None),
    ('COLBL',    F_OPAQUE | F_SOLID,           0x042, 0x042, M_TINT, WHITE, 0, None, None),
    ('COLBR',    F_OPAQUE | F_SOLID,           0x056, 0x056, M_TINT, WHITE, 0, None, None),
    ('COLMID',   F_OPAQUE | F_SOLID,           0x043, 0x043, M_TINT, WHITE, 0, None, None),
    ('STATUEB',  F_OPAQUE | F_SOLID,           0x147, 0x147, M_TINT, WHITE, 0, None, None),
    ('URNTL',    F_SOLID,                      0x1D5, 0x1D5, M_SELF, YELLOW, 0, (6, 'WARM'), 'EMBER'),
    ('URNTR',    F_SOLID,                      0x1D6, 0x1D6, M_SELF, YELLOW, 0, (6, 'WARM'), None),
    ('URNBL',    F_SOLID,                      0x1D7, 0x1D7, M_FIX, RED, 0, None, None),
    ('URNBR',    F_SOLID,                      0x1D8, 0x1D8, M_FIX, RED, 0, None, None),
    # the sun-stone: an empty stand, the stone on its stand (a steady
    # light), and dark-glass doors that open only while steady light
    # (level 5+ in SLIGHT) falls on them
    ('PEDESTAL', F_SOLID | F_BUMP,             0x163, 0x163, M_FIX, WHITE, 0, None, None),
    ('PEDLIT',   F_SOLID | F_BUMP,             0x18F, 0x18F, M_SELF, YELLOW, 0, (7, 'SUN'), 'GLINT'),
    ('LDOOR',    F_OPAQUE | F_SOLID | F_BUMP,  0x1B9, 0x1B9, M_FIX, MAGENTA, 0, None, None),
    ('LDOPEN',   F_DOOR,                       0x1B7, 0x1B7, M_TINT, YELLOW, 0, None, None),
]
T = {t[0]: i for i, t in enumerate(TILES)}
assert len(TILES) <= 64

# ------------------------------------------------------------------ themes
# wall glyph, floor glyph, floor bright glyph, floor2 glyph,
#   wall colour, floor colour, floor2 colour, wall mode
THEMES = {
    'CRYPT':   (0x0D0, 0x185, 0x185, 0x0F6, BLUE,    BLUE,    WHITE,   M_TINT),
    'GROTTO':  (0x0A6, 0x185, 0x185, 0x0F9, GREEN,   BLUE,    GREEN,   M_TINT),
    'DROWNED': (0x176, 0x185, 0x185, 0x0F6, CYAN,    BLUE,    CYAN,    M_TINT),
    'FORGE':   (0x177, 0x185, 0x185, 0x0F9, RED,     BLUE,    RED,     M_TINT),
    'FROST':   (0x0D0, 0x185, 0x185, 0x0F6, CYAN,    BLUE,    WHITE,   M_TINT),
    'LIBRARY': (0x175, 0x185, 0x185, 0x0D0, YELLOW,  BLUE,    RED,     M_TINT),
    'SANCTUM': (0x165, 0x185, 0x185, 0x0F6, MAGENTA, BLUE,    MAGENTA, M_TINT),
    'THRONE':  (0x0D0, 0x185, 0x185, 0x0F9, MAGENTA, BLUE,    RED,     M_TINT),
}

# ------------------------------------------------------------------ particles
# kind: glyph sequence (oldest last), colour sequence, vy start (1/16 cell/frame),
#   gravity, spread
PARTICLES = {
    'EMBER':  ([0x185, 0x0F1, 0x185], [YELLOW, RED, RED], -3, 0, 2),
    'SPARK':  ([0x06B, 0x185, 0x0F1], [WHITE, YELLOW, RED], 0, 0, 0),
    'SMOKE':  ([0x0F6, 0x0F9, 0x0F1], [WHITE, BLUE, BLUE], -2, 0, 1),
    'FROST':  ([0x06B, 0x185, 0x0F1], [WHITE, CYAN, BLUE], 0, 0, 0),
    'POISON': ([0x184, 0x185, 0x0F1], [GREEN, GREEN, BLUE], -1, 0, 1),
    'HEAL':   ([0x06A, 0x185, 0x0F1], [WHITE, GREEN, GREEN], -3, 0, 1),
    'MAGIC':  ([0x06B, 0x185, 0x0F1], [WHITE, MAGENTA, MAGENTA], -1, 0, 2),
    'BLOOD':  ([0x185, 0x0F1, 0x0F1], [RED, RED, MAGENTA], -3, 1, 3),
    'DRIP':   ([0x185, 0x0F1, 0x0F1], [CYAN, BLUE, BLUE], 1, 1, 0),
    'SPORE':  ([0x0F1, 0x185, 0x0F1], [GREEN, YELLOW, GREEN], -1, 0, 2),
    'GOLD':   ([0x06B, 0x185, 0x0F1], [YELLOW, WHITE, YELLOW], -2, 0, 2),
    'GLINT':  ([0x06B, 0x185, 0x0F1], [WHITE, CYAN, BLUE], 0, 0, 0),
    'BUBBLE': ([0x184, 0x185, 0x0F1], [YELLOW, RED, RED], -2, 0, 0),
    'BOLT':   ([0x043, 0x06B, 0x185], [WHITE, CYAN, BLUE], 0, 0, 0),
    'DARK':   ([0x0F9, 0x0F6, 0x0F1], [MAGENTA, BLUE, BLUE], -1, 0, 2),
}
