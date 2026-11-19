"""tiles.py - element codes and the 2 x 2 character tile looks for SKINK.

Every map tile is drawn as 2 x 2 character cells.  A cell is a CG-ROM glyph
(0-1FFh, 100h+ = second bank) with a foreground and a background colour.
A look is four cells (TL, TR, BL, BR); an element has 8 animation phases.
Some elements are themed: each region picks one of the THEMES, which
replaces the looks of earth and walls.
"""
BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)

# ---------------------------------------------------------------- elements (6 bits)
ELEMS = [
    'SPACE', 'EARTH', 'WALL', 'CURVL', 'CURVR', 'SECRET', 'STEEL', 'BARRIER',
    'CAGE', 'SAFE', 'SKULL', 'SWITCH', 'SWITCHON', 'GATE', 'TRANS', 'PLAYER',
    # collectables
    'GEM', 'PIECE', 'CROWN', 'KEY',
    # physics objects (rock-like): a falling code is the rest code + 1
    'ROCK', 'ROCKF', 'EGG', 'EGGF',
    # creatures and timers
    'HATCH1', 'HATCH2', 'HATCH3', 'MONSTER', 'SPIRIT0', 'SPIRIT1', 'SPIRIT2', 'SPIRIT3',
    'FUNGUS', 'DECOR', 'COVER',
]
E = {n: i for i, n in enumerate(ELEMS)}
assert len(ELEMS) <= 64
COLLECT = ('GEM', 'PIECE', 'CROWN', 'KEY')


def c(g, fg, bg=BLACK):
    return (g, fg, bg)


def look(tl, tr, bl, br):
    return (tl, tr, bl, br)


def same(lk):
    return [lk] * 8


def solid4(g, fg, bg=BLACK):
    return look(c(g, fg, bg), c(g, fg, bg), c(g, fg, bg), c(g, fg, bg))


BLANK = c(0, WHITE, BLACK)
SPACE_L = look(BLANK, BLANK, BLANK, BLANK)

ROCK_L = look(c(0x1A5, WHITE), c(0x1A1, WHITE), c(0x42, WHITE), c(0x43, WHITE))


def gem(col, spark=None):
    tl = c(0x4E, col)
    if spark == 'tl':
        tl = c(0x6B, WHITE)
    return look(tl, c(0x4D, col), c(0x42, col), c(0x56, col))


GEM_A = [gem(CYAN), gem(CYAN), gem(WHITE), gem(CYAN, 'tl'), gem(CYAN), gem(CYAN), gem(CYAN), gem(CYAN)]
EGG_L = look(c(0x1A5, YELLOW), c(0x1A1, YELLOW), c(0x42, YELLOW), c(0x56, YELLOW))
HATCH = [look(c(0x1A5, YELLOW), c(0x1A1, WHITE), c(0x42, YELLOW), c(0x56, YELLOW)),
         look(c(0x1E9, YELLOW), c(0x1A1, YELLOW), c(0x42, WHITE), c(0x56, YELLOW)),
         look(c(0x1E9, MAGENTA), c(0x1E9, WHITE), c(0x42, MAGENTA), c(0x56, YELLOW))]


def face(top_l, top_r, col, eyes=(0x1D5, 0x1D6), eye_col=None):
    ec = eye_col if eye_col is not None else col
    return look(c(top_l, col), c(top_r, col), c(eyes[0], ec), c(eyes[1], ec))


PLAYER_DOWN = [face(0x1A5, 0x1A1, GREEN)] * 4 + [face(0x1A5, 0x1A1, GREEN)] * 4
# player looks are patched at run time (facing / walking)
PL = {
    'LK_PLIDLE': [face(0x1A5, 0x1A1, GREEN)] * 6 + [face(0x1A5, 0x1A1, GREEN, eye_col=GREEN)] * 1
    + [look(c(0x1A5, GREEN), c(0x1A1, GREEN), c(0x43, GREEN), c(0x43, GREEN))],     # blink
    'LK_PLLEFT': [look(c(0x1A5, GREEN), c(0x1A1, GREEN), c(0x1D5, GREEN), c(0x43, GREEN)),
                  look(c(0x1A5, GREEN), c(0x1A1, GREEN), c(0x1D5, GREEN), c(0x1D6, GREEN))] * 4,
    'LK_PLRIGHT': [look(c(0x1A5, GREEN), c(0x1A1, GREEN), c(0x43, GREEN), c(0x1D6, GREEN)),
                   look(c(0x1A5, GREEN), c(0x1A1, GREEN), c(0x1D5, GREEN), c(0x1D6, GREEN))] * 4,
    'LK_PLUP': [look(c(0x1A5, GREEN), c(0x1A1, GREEN), c(0x43, GREEN), c(0x43, GREEN)),
                look(c(0x1A5, YELLOW), c(0x1A1, YELLOW), c(0x43, GREEN), c(0x43, GREEN))] * 4,
    'LK_PLDEAD': [look(c(0x1A5, c2), c(0x1A1, c2), c(0x1D5, c2), c(0x1D6, c2))
                  for c2 in (WHITE, RED, YELLOW, RED, WHITE, RED, YELLOW, RED)],
}

MONSTER = [face(0x163, 0x163, MAGENTA), face(0x163, 0x163, MAGENTA),
           face(0x163, 0x163, MAGENTA, eyes=(0x1D5, 0x1D6)), face(0x163, 0x163, RED)] * 2
SPIRIT = [face(0x4E, 0x4D, col) for col in (WHITE, CYAN, WHITE, CYAN, CYAN, WHITE, CYAN, BLUE)]
SKULL_L = solid4(0x139, WHITE)
KEY_A = [look(c(0x184, YELLOW), c(0x1B7, YELLOW), BLANK, BLANK)] * 6 + \
        [look(c(0x184, WHITE), c(0x1B7, WHITE), BLANK, BLANK)] * 2
SAFE_L = look(c(0x18B, WHITE, RED), c(0x18B, WHITE, RED), c(0x18B, WHITE, RED), c(0x186, YELLOW, RED))
CAGE_L = solid4(0x1B4, CYAN)
BARRIER_L = solid4(0x175, YELLOW, RED)
CROWN_A = [look(c(0x163, col), c(0x163, col), c(0x7A, col), c(0x7A, col)) for col in
           (YELLOW, YELLOW, YELLOW, WHITE, YELLOW, YELLOW, RED, YELLOW)]


def piece(k):
    cols = [YELLOW, RED, MAGENTA, WHITE]
    a, b, cc, d = (cols[(k + i) % 4] for i in range(4))
    return look(c(0x4E, a), c(0x43, b), c(0x43, cc), c(0x56, d))


PIECE_A = [piece(k // 2) for k in range(8)]
TRANS_A = [solid4(0x18A, fg, bg) for fg, bg in
           ((CYAN, BLUE), (WHITE, BLUE), (WHITE, CYAN), (BLUE, CYAN),
            (MAGENTA, BLUE), (WHITE, MAGENTA), (CYAN, MAGENTA), (WHITE, BLUE))]
SWITCH_L = look(c(0x77, WHITE), BLANK, c(0x1BB, RED), c(0x1BC, RED))
SWITCHON_L = look(BLANK, c(0x76, WHITE), c(0x1BB, GREEN), c(0x1BC, GREEN))
FUNGUS_A = [look(c(0x19F, GREEN), c(0x1B3, GREEN), c(0x1B3, GREEN), c(0x19F, GREEN)),
            look(c(0x1B3, GREEN), c(0x19F, GREEN), c(0x19F, GREEN), c(0x1B3, GREEN))] * 4
GATE_SHUT = look(c(0x1A5, BLUE), c(0x1A1, BLUE), c(0x18B, WHITE, BLUE), c(0x18B, WHITE, BLUE))
GATE_OPEN = [look(c(0x1A5, col), c(0x1A1, col), c(0x1B3, WHITE, col), c(0x1B3, WHITE, col)) for col in
             (YELLOW, RED, YELLOW, WHITE, YELLOW, RED, MAGENTA, RED)]
COVER_L = solid4(0x1B2 if False else 0xD0, BLUE)

# ---------------------------------------------------------------- themes
# each theme: earth look, wall look, wall-corner colour (fg of the triangle,
# drawn in the brick colour), steel look, decoration look


def theme(name, earth, wall, corner, steel, decor):
    return dict(name=name, EARTH=earth, WALL=wall, CORNER=corner, STEEL=steel, DECOR=decor)


def earth(fg, g1=0xA6, g2=0xEF, bg=BLACK):
    return look(c(g1, fg, bg), c(g2, fg, bg), c(g2, fg, bg), c(g1, fg, bg))


def brick(fg, bg, g=0x1F6):
    return solid4(g, fg, bg)


THEMES = [
    theme('SUNLIT', earth(YELLOW), brick(RED, YELLOW), YELLOW, solid4(0x18A, BLUE, BLACK),
          look(c(0x163, GREEN), c(0x163, GREEN), c(0x175, GREEN), c(0x175, GREEN))),
    theme('LOAM', earth(RED), brick(RED, WHITE), WHITE, solid4(0x18A, CYAN, BLACK),
          look(c(0x1E9, RED), BLANK, BLANK, c(0x1E9, RED))),
    theme('MOSS', earth(GREEN), brick(GREEN, BLUE, 0x1B4), BLUE, solid4(0x18A, GREEN, BLACK),
          look(c(0x19F, GREEN), BLANK, BLANK, c(0x19F, GREEN))),
    theme('ICE', earth(CYAN), brick(WHITE, CYAN, 0x18A), CYAN, solid4(0x18A, BLUE, BLACK),
          look(c(0x6B, WHITE), BLANK, BLANK, c(0x6B, CYAN))),
    theme('CRYSTAL', earth(MAGENTA), brick(MAGENTA, BLUE), BLUE, solid4(0x18A, MAGENTA, BLACK),
          look(c(0x4E, MAGENTA), c(0x4D, MAGENTA), BLANK, BLANK)),
    theme('EMBER', earth(RED, bg=BLACK, g1=0xEF, g2=0xA6), brick(YELLOW, RED, 0x177), RED,
          solid4(0x18A, YELLOW, BLACK), look(c(0x1E9, YELLOW), BLANK, BLANK, c(0x1E9, RED))),
    theme('DEEP', earth(BLUE), brick(BLUE, WHITE), WHITE, solid4(0x18A, CYAN, BLACK),
          look(c(0x6B, BLUE), BLANK, BLANK, c(0x6B, BLUE))),
    theme('GOLD', earth(YELLOW, g1=0xEF, g2=0xA6), brick(YELLOW, MAGENTA), MAGENTA,
          solid4(0x18A, YELLOW, BLACK), look(c(0x163, YELLOW), BLANK, BLANK, c(0x163, YELLOW))),
]
THEMED = ('EARTH', 'WALL', 'CURVL', 'CURVR', 'SECRET', 'STEEL', 'DECOR')


def themed_looks(th):
    w = th['WALL']
    cl = list(w)
    cl[0] = c(0x4E, th['CORNER'] if w[0][2] == BLACK else w[0][2], BLACK)
    cr = list(w)
    cr[1] = c(0x4D, th['CORNER'] if w[1][2] == BLACK else w[1][2], BLACK)
    return {'EARTH': th['EARTH'], 'WALL': w, 'CURVL': tuple(cl), 'CURVR': tuple(cr),
            'SECRET': w, 'STEEL': th['STEEL'], 'DECOR': th['DECOR']}


# ---------------------------------------------------------------- per-element animation
LOOK = {
    'SPACE': same(SPACE_L), 'BARRIER': same(BARRIER_L), 'CAGE': same(CAGE_L), 'SAFE': same(SAFE_L),
    'SKULL': same(SKULL_L), 'SWITCH': same(SWITCH_L), 'SWITCHON': same(SWITCHON_L),
    'GATE': same(GATE_SHUT), 'TRANS': TRANS_A, 'PLAYER': PL['LK_PLIDLE'],
    'GEM': GEM_A, 'PIECE': PIECE_A, 'CROWN': CROWN_A, 'KEY': KEY_A,
    'ROCK': same(ROCK_L), 'ROCKF': same(ROCK_L), 'EGG': same(EGG_L), 'EGGF': same(EGG_L),
    'HATCH1': same(HATCH[0]), 'HATCH2': same(HATCH[1]), 'HATCH3': [HATCH[2], HATCH[1]] * 4,
    'MONSTER': MONSTER, 'FUNGUS': FUNGUS_A, 'COVER': same(COVER_L),
}
for d in range(4):
    LOOK['SPIRIT%d' % d] = SPIRIT
_t0 = themed_looks(THEMES[0])
for k in THEMED:
    LOOK[k] = same(_t0[k])

# run-time looks that are patched in (8 phases each)
EXTRA = dict(PL)
EXTRA['LK_GATEOPEN'] = GATE_OPEN
EXTRA['LK_GATESHUT'] = same(GATE_SHUT)
