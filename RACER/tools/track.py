"""track.py - REDLINE's courses, themes and skylines.

The route is a pyramid of 15 courses in 5 tiers (1, 2, 3, 4, 5 courses):
at the end of each course the road forks, left to the easier course
below, right to the harder one.  Tier 5 courses end at a goal.

A course is a list of sections (length, curve, slope, objmode):
  curve    target curve rate (+ = right); the builder eases towards it
           one step a segment
  slope    target height change per segment, in 1/4 units (eased too)
  objmode  0 none; low nibble p: an object every 4p segments;
           bit 4 left, bit 5 right (both: alternate), bit 6 the theme's
           second object;  bit 7: a bend sign (bit 6 = right bend)
"""
import random

BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)
L, R, B2, SIGN = 0x10, 0x20, 0x40, 0x80

# objects (TRK_OBJ values): index into SPRTAB from 1
OBJECTS = ['SIGNL', 'SIGNR', 'PALM', 'PINE', 'SNOWPINE', 'CACTUS', 'ROCK', 'BUTTE', 'LAMP',
           'TOWER', 'TREE', 'MILL', 'UMBR', 'BUSH', 'POST']
CARS = ['CARB', 'CARY', 'CARG', 'CARW', 'CARM', 'CARC', 'TRUCK']

# name, grass A/B, rumble A/B, road, lines, far land, sky rows (7 attrs: fg,bg),
# skyline kind, object A, object B, traffic (most cars, gap fields, min speed, spread, lane changes)
THEMES = {
    'COAST':  dict(name='SUNSET COAST', grass=(YELLOW, WHITE), rumble=(RED, WHITE), road=BLACK, lines=1,
                   far=CYAN, sky=[(WHITE, BLUE)] * 2 + [(WHITE, BLUE), (YELLOW, MAGENTA), (YELLOW, MAGENTA),
                                                         (BLUE, CYAN), (BLUE, CYAN)],
                   skyline='islands', obja='PALM', objb='UMBR', traffic=(4, 70, 600, 255, 1)),
    'FOREST': dict(name='PINE FOREST', grass=(GREEN, CYAN), rumble=(RED, WHITE), road=BLACK, lines=1,
                   far=GREEN, sky=[(WHITE, CYAN)] * 4 + [(BLUE, CYAN)] * 3,
                   skyline='hills', obja='PINE', objb='BUSH', traffic=(5, 60, 640, 255, 1)),
    'DESERT': dict(name='DESERT RUN', grass=(YELLOW, RED), rumble=(WHITE, RED), road=BLACK, lines=0,
                   far=YELLOW, sky=[(WHITE, BLUE)] * 3 + [(WHITE, CYAN)] * 1 + [(RED, CYAN)] * 3,
                   skyline='mesas', obja='CACTUS', objb='ROCK', traffic=(3, 90, 700, 255, 0)),
    'FIELDS': dict(name='WINDMILL FIELDS', grass=(GREEN, YELLOW), rumble=(RED, WHITE), road=BLACK, lines=1,
                   far=GREEN, sky=[(WHITE, BLUE)] * 4 + [(GREEN, BLUE)] * 3,
                   skyline='hills', obja='TREE', objb='MILL', traffic=(5, 55, 640, 255, 1)),
    'CANYON': dict(name='RED CANYON', grass=(RED, MAGENTA), rumble=(YELLOW, WHITE), road=BLACK, lines=0,
                   far=RED, sky=[(YELLOW, MAGENTA)] * 2 + [(YELLOW, RED)] * 2 + [(MAGENTA, RED)] * 3,
                   skyline='mesas', obja='BUTTE', objb='ROCK', traffic=(4, 70, 700, 255, 1)),
    'CITY':   dict(name='NEON CITY', grass=(BLUE, BLACK), rumble=(MAGENTA, WHITE), road=BLACK, lines=1,
                   far=BLUE, sky=[(WHITE, BLACK)] * 4 + [(BLUE, BLACK)] * 3,
                   skyline='city', obja='LAMP', objb='TOWER', traffic=(7, 40, 560, 255, 1)),
    'ALPINE': dict(name='ALPINE PASS', grass=(WHITE, CYAN), rumble=(RED, WHITE), road=BLACK, lines=1,
                   far=WHITE, sky=[(WHITE, BLUE)] * 4 + [(WHITE, BLUE)] * 3,
                   skyline='peaks', obja='SNOWPINE', objb='POST', traffic=(4, 70, 600, 255, 1)),
    'NIGHT':  dict(name='MIDNIGHT HIGHWAY', grass=(BLUE, BLACK), rumble=(YELLOW, BLACK), road=BLACK, lines=1,
                   far=BLACK, sky=[(WHITE, BLACK)] * 4 + [(MAGENTA, BLACK)] * 3,
                   skyline='city', obja='LAMP', objb='POST', traffic=(6, 45, 680, 255, 1)),
}

# the pyramid: tier by tier, left to right
ROUTE = [
    ['COAST'],
    ['FOREST', 'DESERT'],
    ['FIELDS', 'CANYON', 'CITY'],
    ['FOREST', 'ALPINE', 'DESERT', 'NIGHT'],
    ['FIELDS', 'ALPINE', 'CANYON', 'CITY', 'NIGHT'],
]
GOALS = ['VILLAGE GREEN', 'GLACIER LAKE', 'CANYON RIM', 'HARBOUR LIGHTS', 'DAWN TOWER']


def course(tier, idx, seed):
    rnd = random.Random(seed)
    diff = tier + idx * 0.6
    secs = [(56, 0, 0, 0)]                 # a straight start (no objects: the join)
    total = 56
    target = 560 + tier * 50
    dens = 0x02
    while total < target:
        kind = rnd.random()
        ln = rnd.randint(18, 44)
        if kind < 0.3:                      # straight, maybe hilly
            hill = rnd.choice([0, 0, 2, -2, 3, -3]) if diff > 0.5 else rnd.choice([0, 2, -2])
            secs.append((ln, 0, hill, dens | L | R | (B2 if rnd.random() < 0.3 else 0)))
        elif kind < 0.85:                   # a bend
            mag = rnd.randint(1, min(6, 2 + int(diff)))
            cv = mag if rnd.random() < 0.5 else -mag
            if mag >= 3:                    # warn of it
                secs.append((12, 0, 0, SIGN | 0x01 | (B2 if cv > 0 else 0)))
                total += 12
            hill = rnd.choice([0, 0, 0, 2, -2])
            om = dens | (R if cv > 0 else L) | (B2 if rnd.random() < 0.4 else 0)
            secs.append((ln, cv, hill, om))
        else:                               # an S
            mag = rnd.randint(2, min(6, 3 + int(diff)))
            secs.append((ln // 2 + 8, mag, 0, dens | L | R))
            secs.append((ln // 2 + 8, -mag, 0, dens | L | R))
            ln += 16
        total += ln
    # a calm run to the checkpoint
    secs.append((40, 0, 0, 0x01 | L | R))
    return secs


def build_runtime(secs):
    """model of the asm builder: eased curve and slope -> curves, heights"""
    cur, hgt = [], []
    c = s = h = 0
    for ln, cv, sl, om in secs:
        for i in range(ln):
            c += (cv > c) - (cv < c)
            s += (sl > s) - (sl < s)
            h += s
            cur.append(c)
            hgt.append(h >> 2)
    return cur, hgt


def stages():
    out = []
    for t, row in enumerate(ROUTE):
        for i, th in enumerate(row):
            seed = 1000 + t * 10 + i
            while True:
                secs = course(t, i, seed)
                cur, hgt = build_runtime(secs)
                if max(hgt) < 110 and min(hgt) > -110 and len(cur) <= 960:
                    break
                seed += 100
            out.append((t, i, th, secs))
    return out


def skyline(kind, seed):
    """64 heights in eighths of the 3 skyline rows (0..24)"""
    rnd = random.Random(seed)
    hs = []
    if kind == 'islands':
        hs = [0] * 64
        for cx, w, hh in [(6, 7, 9), (22, 4, 5), (40, 9, 12), (55, 3, 4)]:
            for x in range(cx - w, cx + w + 1):
                d = abs(x - cx) / (w + 0.5)
                hs[x % 64] = max(hs[x % 64], round(hh * (1 - d * d)))
    elif kind == 'hills':
        for x in range(64):
            import math
            hs.append(round(8 + 5 * math.sin(x / 64 * 2 * math.pi * 2) + 3 * math.sin(x / 64 * 2 * math.pi * 5 + 1)))
    elif kind == 'peaks':
        hs = [4] * 64
        for cx, hh in [(5, 22), (18, 16), (30, 23), (44, 14), (54, 20)]:
            for x in range(cx - 12, cx + 13):
                hs[x % 64] = max(hs[x % 64], hh - abs(x - cx) * 2)
    elif kind == 'mesas':
        hs = [2] * 64
        for cx, w, hh in [(8, 5, 14), (26, 3, 9), (40, 8, 18), (57, 2, 7)]:
            for x in range(cx - w, cx + w + 1):
                hs[x % 64] = hh
    elif kind == 'city':
        x = 0
        while x < 64:
            w = rnd.randint(2, 4)
            hh = rnd.choice([6, 9, 12, 15, 18, 22])
            for k in range(w):
                if x + k < 64:
                    hs.append(hh)
            x += w
        hs = hs[:64]
    return hs


# skyline cells from heights: rows 0..2 (top..bottom), each 8 units tall
def skyline_chars(hs, kind):
    rows = [[0] * 64 for _ in range(3)]
    for r in range(3):
        lo = (2 - r) * 8                    # the band's bottom
        for x in range(64):
            a, b = hs[x], hs[(x + 1) % 64]
            p, q = hs[(x - 1) % 64], hs[x]
            h = hs[x]
            if h >= lo + 8:
                ch = 0x43
                if kind in ('islands', 'hills', 'peaks'):
                    # slopes at the top
                    left, right = hs[(x - 1) % 64], hs[(x + 1) % 64]
                    if h < lo + 12:
                        if left < lo + 8 <= right:
                            ch = 0x4E       # rising: lower-right triangle
                        elif right < lo + 8 <= left:
                            ch = 0x4D
            elif h >= lo + 4:
                left, right = hs[(x - 1) % 64], hs[(x + 1) % 64]
                ch = 0x3A                   # lower half
                if kind in ('islands', 'hills', 'peaks'):
                    if left < h < right or (left < h and right >= lo + 8):
                        ch = 0x4E
                    elif right < h < left or (right < h and left >= lo + 8):
                        ch = 0x4D
            elif h > lo:
                ch = 0x3E                   # a sliver
                if kind == 'city':
                    ch = 0x7E
            else:
                ch = 0
            if kind == 'city' and ch == 0x43 and (x * 7 + r * 3) % 5 == 0:
                ch = 0x47 if r else 0x43    # a lit window... (round dot)
            rows[r][x] = ch
    return rows


CLOUDS = [
    "                ___         ##_                     _##__       ",
    "     _####_   _#####_      #####                  _#######_     ",
    "    #########                             __                    ",
    "                                        _####_                  ",
]
STARS = [
    "  .        .      +     .          .     .   +        .     .   ",
    "      +         .           .  +              .   .        +    ",
    " .        .          .            .     +           .        .  ",
    "                                                                ",
]


def cloud_chars(night):
    pat = STARS if night else CLOUDS
    m = {' ': 0, '#': 0x43, '_': 0x3A, '.': 0x2E, '+': 0x6A}
    return [[m[c] for c in row.ljust(64)[:64]] for row in pat]


def attr(fg, bg):
    return (fg << 4) | bg


def gen_asm(stg):
    import art
    out = ['; generated by tools/track.py: themes, skies, courses']
    names = list(THEMES)
    # skies (64-aligned rows)
    out.append('        align 64')
    for k, th in THEMES.items():
        night = k in ('CITY', 'NIGHT')
        rows = cloud_chars(night) + skyline_chars(skyline(th['skyline'], len(k)), th['skyline'])
        out.append('SKY_%s:' % k)
        for r in rows:
            out.append('        db ' + ','.join('%d' % v for v in r))
        out.append('        db ' + ','.join('%d' % attr(*a) for a in th['sky']))
        out.append('        align 64')
    # themes
    out.append('THEMES:')
    for k, th in THEMES.items():
        ga, gb = th['grass']
        ra, rb = th['rumble']
        out.append('TH_%s:' % k)
        out.append('        db %d,%d,%d,%d,%d' % (ga, ra, th['road'], WHITE, 0xFF if th['lines'] else 0))
        out.append('        db %d,%d,%d,%d,0' % (gb, rb, th['road'], th['road']))
        out.append('        db %d' % th['far'])
        out.append('        db %d,%d' % (OBJECTS.index(th['obja']) + 1, OBJECTS.index(th['objb']) + 1))
        out.append('        dw SKY_%s, TN_%s' % (k, k))
        mx, gap, vmin, var, lc = th['traffic']
        out.append('        db %d,%d' % (mx, gap))
        out.append('        dw %d' % vmin)
        out.append('        db %d,%d' % (var, lc))
    for k, th in THEMES.items():
        out.append('TN_%s: db "%s",0' % (k, th['name']))
    # stages: course, theme, children
    out.append('STAGES:')
    idx = 0
    for t, i, th, secs in stg:
        if t < 4:
            left = idx + t + 1
            right = left + 1
        else:
            left = right = 0xFF
        out.append('        dw CRS_%d, TH_%s' % (idx, th))
        out.append('        db %d,%d,%d' % (left, right, t))
        idx += 1
    # the route map: short names and where they go (row, column)
    short = {'COAST': 'COAST', 'FOREST': 'FOREST', 'DESERT': 'DESERT', 'FIELDS': 'FIELDS',
             'CANYON': 'CANYON', 'CITY': 'CITY', 'ALPINE': 'ALPINE', 'NIGHT': 'NIGHT'}
    out.append('ROUTEMAP:')
    lines = []
    for t, i, th, secs in stg:
        nm = short[th]
        x = 20 + round((i - t / 2) * 8)
        row = 9 + 3 * t
        out.append('        db %d,%d,"%s",0' % (row, x - len(nm) // 2, nm))
        if t < 4:
            lines.append((row + 1, x - 2, 0x76))
            lines.append((row + 1, x + 1, 0x77))
    out.append('        db 0FFh')
    out.append('ROUTELINES:')
    for r, c, g in lines:
        out.append('        db %d,%d,%d' % (r, c, g))
    out.append('        db 0FFh')
    for n, g in enumerate(GOALS):
        out.append('GOAL_%d: db "%s",0' % (n, g))
    out.append('GOALS:  dw ' + ','.join('GOAL_%d' % n for n in range(5)))
    for n, (t, i, th, secs) in enumerate(stg):
        out.append('CRS_%d:' % n)
        for ln, cv, sl, om in secs:
            out.append('        db %d,%d,%d,%d' % (ln, cv & 255, sl & 255, om))
        out.append('        db 0')
    return out
