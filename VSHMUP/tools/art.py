"""art.py - NOVA STORM sprites and scenery, drawn with the stock European
CG-ROM (no PCG).  Used by gen.py (-> build/gen_art.inc) and preview.py.

A picture is a list of rows; each row holds space-separated cell tokens:

    .            nothing (transparent)
    SYM FG [BG]  a glyph, foreground colour, optional background colour

SYM is one of the shorthand block glyphs below, or {NNN}: a glyph index in
hex (1xx = the ROM's second bank, attribute bit 7).
Colours: k black, b blue, r red, m magenta, g green, c cyan, y yellow, w white.
"""
import re

SYMS = {
    '#': 0x043,   # full block
    '^': 0x07A,   # top half
    '_': 0x03A,   # bottom half
    '[': 0x07B,   # left half
    ']': 0x03B,   # right half
    'q': 0x056,   # triangle, top-left filled
    'p': 0x042,   # top-right filled
    'b': 0x04D,   # bottom-left filled
    'd': 0x04E,   # bottom-right filled
    'o': 0x18F,   # ball
    '*': 0x06B,   # star burst (bank 0 '*')
    '+': 0x06A,   # plus
    '-': 0x070,   # line at top
    '=': 0x0A1,   # double bar
    '|': 0x0A2,   # double vertical bars
    ':': 0x0F5,   # dotted left pair
    ';': 0x0FA,   # dotted right pair
    '%': 0x1D6,   # wavy
    '@': 0x186,   # small square
    '$': 0x188,   # medal (circled C)
    'x': 0x0FF,   # dotted 2x2
    'v': 0x0F3,   # dotted top pair
    'n': 0x0FC,   # dotted bottom pair
}
COL = {c: i for i, c in enumerate('kbrmgcyw')}
TOK = re.compile(r'^(\{[0-9A-Fa-f]{3}\}|.)([kbrmgcyw])([kbrmgcyw])?$')


def cell(tok):
    """token -> (glyph 0..511, attribute) or None"""
    if tok == '.':
        return None
    m = TOK.match(tok)
    assert m, tok
    s, fg, bg = m.groups()
    g = int(s[1:-1], 16) if s.startswith('{') else SYMS[s]
    a = ((g >> 8) << 7) | (COL[fg] << 4) | (COL[bg] if bg else 0)
    return g & 0xFF, a


def parse(rows):
    """-> list of (dx, dy, char, attr), width, height"""
    out = []
    w = 0
    for y, r in enumerate(rows):
        toks = r.split()
        w = max(w, len(toks))
        for x, t in enumerate(toks):
            c = cell(t)
            if c:
                out.append((x, y, c[0], c[1]))
    return out, w, len(rows)


# ---------------------------------------------------------------- the player
PLAYER = [
    '.  {041}w  .',
    'dc #w      bc',
]
# options (drones) and flame
OPTION = ['{18E}y']
FLAME = [['{1A0}r'], ['{1A0}y']]

# ---------------------------------------------------------------- enemies
# 1-cell ROM invaders/fighters (2 animation frames each)
SPRITES = {
    'DART0': ['{12E}c'], 'DART1': ['{12F}c'],          # diver
    'WASP0': ['{12C}g'], 'WASP1': ['{12D}g'],          # weaver
    'CRAB0': ['{130}m'], 'CRAB1': ['{131}m'],          # formation
    'BUG0': ['{134}y'], 'BUG1': ['{135}y'],            # swarmer
    'SKULL0': ['{136}w'], 'SKULL1': ['{137}w'],        # kamikaze
    'EYE0': ['{138}r'], 'EYE1': ['{139}r'],            # sniper
    'MINE0': ['{18F}r'], 'MINE1': ['{18E}y'],          # space mine
    'FISHL': ['{1F0}c'], 'FISHR': ['{1F1}c'],          # side swoopers
    # 2x1 saucer (bonus carrier)
    'UFO0': ['{1BD}m {1BD}m'], 'UFO1': ['{1BD}y {1BD}y'],
    # 2x2 gunship (drops capsules)
    'GUN0': ['qr pr', '{130}y {130}y'],
    # 2x2 asteroid (tough, splits)
    'ROCK': ['dw #w bw', 'pw {186}kw qw'],
    'ROCKS': ['{047}y'],
    # turret on the station (ground target)
    'TUR0': ['{1B2}r'], 'TUR1': ['{1B2}y'],
    # 3x2 heavy cruiser (mid-boss style)
    'HEAVY': ['dm {186}w bm', '{1C0}m #m {1BF}m'],
    # capsules: letter in a coloured box
}
CAPS = {   # kind: (letter, colours fg on bg)
    'P': ('P', 'wr'), 'V': ('V', 'kc'), 'L': ('L', 'ky'), 'O': ('O', 'wm'),
    'S': ('S', 'kg'), 'B': ('B', 'wb'), 'H': ('H', 'kw'), '1': ('1', 'yr'),
}

# ---------------------------------------------------------------- bosses
BOSSES = {
    # stage 1: the Warden, a battle cruiser
    'WARDEN': [
        '.   .   dm  #m  #m  #m  #m  bm  .   .',
        'dr  #r  #m  {186}y #m  #m  {186}y #m  #r  br',
        '#r  {1B2}w #m  #m  {13D}c {13B}c #m  #m  {1B2}w #r',
        'pr  qr  {1BE}m #m  #m  #m  #m  {1BE}m pr  qr',
        '.   .   .   {1A0}y .   .   {1A0}y .   .   .',
    ],
    # stage 2: the Hive Mother
    'HIVE': [
        '.   .   dg  #g  #g  #g  bg  .   .',
        '.   dg  %y  %y  %y  %y  %y  bg  .',
        'dg  #g  {188}r #g  {13E}m #g  {188}r #g  bg',
        'pg  #g  #g  %y  %y  %y  #g  #g  qg',
        '.   pg  {1BE}g #g  #g  #g  {1BE}g qg  .',
        '.   .   {12C}y .   {12C}y .   {12C}y .   .',
    ],
    # stage 3: the Dock Fortress
    'FORT': [
        '{1B1}w {1B1}w {1B1}w {1B1}w {1B1}w {1B1}w {1B1}w {1B1}w {1B1}w {1B1}w',
        '#b  {1B2}r #b  #b  dc  bc  #b  #b  {1B2}r #b',
        '#b  #b  #b  dc  {13E}r {13E}r bc  #b  #b  #b',
        '#b  {1B2}r #b  pc  #c  #c  qc  #b  {1B2}r #b',
        '{1BE}w .   {1BE}w .   {1BE}w {1BE}w .   {1BE}w .   {1BE}w',
    ],
    # stage 4: the Twin Claw
    'CLAW': [
        'dr  br  .   .   .   .   .   .   dr  br',
        '#r  #y  br  .   dm  bm  .   dr  #y  #r',
        'pr  #r  #r  #m  #m  #m  #m  #r  #r  qr',
        '.   pr  #m  {138}w #m  #m  {138}w #m  qr  .',
        '.   .   pm  #m  {1BE}r {1BE}r #m  qm  .   .',
    ],
    # stage 5: the Overmind
    'MIND': [
        '.   .   .   dc  #c  #c  #c  bc  .   .   .',
        '.   dc  #c  #b  #b  #b  #b  #b  #c  bc  .',
        'dc  #c  #b  #w  #w  #w  #w  #w  #b  #c  bc',
        '#c  #b  #w  #w  #r  {18F}y #r  #w  #w  #b  #c',
        'pc  #c  #b  #w  #w  #w  #w  #w  #b  #c  qc',
        '.   pc  #c  #b  #b  #b  #b  #b  #c  qc  .',
        '.   .   .   pc  {1A0}m {1A0}m {1A0}m qc  .   .   .',
    ],
}

# ---------------------------------------------------------------- scenery
# Scenery pieces scroll down with the stage (one row every few ticks).
PIECES = {
    'ROCK1': ['db #b bb', 'pb #b qb'],
    'ROCK2': ['.  db bb', 'db #b #b', '#b #b qb', 'pb qb .'],
    'ROCK3': ['db bb', 'pb qb'],
    'PLANET': [
        '.  .  dm #m #m bm .  .',
        '.  dm #m #m #m #m bm .',
        'dm #m #r #m #m #m #m bm',
        '#m #r #r #m #m #m #m #m',
        '#m #m #m #m #m #r #m #m',
        'pm #m #m #m #r #r #m qm',
        '.  pm #m #m #m #m qm .',
        '.  .  pm #m #m qm .  .',
    ],
    'MOON': ['.  dw bw', 'dw #w #w bw', 'pw #w {186}b qw', '.  pw qw'],
    'NEB1': ['.  xb xb .', 'xb xb xb xb', '.  xb xb xb', '.  .  xb .'],
    'NEB2': ['xm xm .  .', 'xm xm xm .', '.  xm xm xm', '.  .  xm .'],
    'GIRD': ['{0A2}b', '{1B1}c', '{0A2}b'],
    'DECK': ['{1B1}c {1B1}c {1B1}c {1B1}c {1B1}c {1B1}c',
             '#b    {1D9}w #b    #b    {1DB}w #b'],
    'PYLON': ['{0A2}c', '{0A2}c', '{1B1}w', '{0A2}c', '{0A2}c'],
    'HULL': ['db #b #b #b #b bb', '#b {186}c #b #b {186}c #b', '#b #b #b #b #b #b', 'pb #b #b #b #b qb'],
    'COMET': ['{0F5}c', '{0FA}w', 'oc'],
    'CORE1': ['{1B1}m {1B1}m {1B1}m', '{0A2}m %r {0A2}m', '{1B1}m {1B1}m {1B1}m'],
}
