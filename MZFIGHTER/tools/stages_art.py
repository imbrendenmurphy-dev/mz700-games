"""stages_art.py - the nine stage pictures (320 x 176, screen rows 3-24).

Fighters stand on screen row 22 (picture y 152-159); the floor runs from
about y 128.  Behind the fighters (y 40-128) big flat shapes read best,
because a sprite's edge cells take the paper colour of the cell beneath.
draw(phase) gives the picture at an animation phase.
"""
import math
import random
from stage import Pic, ymask, sky_gradient, W, H
from figure import BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE


def crowd(p, y, x0, x1, step, cols, phase, seed=1, arms=True):
    rnd = random.Random(seed)
    for i, x in enumerate(range(x0, x1, step)):
        c = cols[i % len(cols)]
        up = arms and ((i + phase) % 3 == 0)
        bob = -2 if (i + phase) % 2 == 0 else 0
        p.rect(x, y + 6 + bob, x + step - 2, y + 18, c)
        p.ellipse([x + 1, y + bob, x + step - 3, y + 7 + bob], YELLOW if c != YELLOW else WHITE)
        if up:
            p.rect(x - 1, y - 6 + bob, x + 1, y + 6 + bob, c)


def silhouettes(p, y0, y1, col, phase, step=16, offset=0):
    """a calm crowd: one colour, big heads on a 2-cell grid, every other one
    bobbing (arm raised)"""
    for i, x in enumerate(range(offset, 320, step)):
        up = (i + phase) % 2
        bob = 0 if up else 3
        p.ellipse([x + 3, y0 + bob, x + 13, y0 + 11 + bob], col)
        p.poly([(x, y1), (x + 2, y0 + 12 + bob), (x + 14, y0 + 12 + bob), (x + 16, y1)], col)
        if up:
            p.rect(x + 13, y0 - 4, x + 16, y0 + 14, col)


# ---------------------------------------------------------------- 0 JAPAN
def japan(phase):
    p = Pic()
    sky_gradient(p, [(0, BLUE, BLUE, 0), (16, BLUE, MAGENTA, 2), (32, MAGENTA, MAGENTA, 0), (48, MAGENTA, RED, 2),
                     (64, RED, RED, 0), (80, RED, YELLOW, 2), (96, YELLOW, YELLOW, 0)])
    p.ellipse([196, 20, 236, 60], YELLOW)                      # the sun
    p.poly([(70, 120), (150, 48), (176, 48), (264, 120)], BLUE)   # the mountain
    p.poly([(134, 64), (150, 48), (176, 48), (192, 64), (180, 60), (170, 68), (160, 60), (146, 68)], WHITE)
    p.rect(0, 104, W, 128, MAGENTA)                            # far hills
    p.poly([(0, 104), (60, 94), (130, 104)], MAGENTA)
    p.poly([(190, 104), (260, 92), (320, 102), (320, 104)], MAGENTA)
    x = 30                                                     # pagoda
    for w, y in [(52, 112), (44, 92), (36, 72), (28, 54)]:
        p.rect(x - w // 2 + 6, y - 2, x + w // 2 - 6, y + 18, RED)
        p.poly([(x - w // 2 - 4, y + 2), (x, y - 10), (x + w // 2 + 4, y + 2), (x + w // 2, y + 6), (x - w // 2, y + 6)],
               BLACK)
    p.rect(x - 1, 32, x + 2, 46, BLACK)
    p.rect(264, 72, 272, 128, RED)                             # torii
    p.rect(300, 72, 308, 128, RED)
    p.poly([(248, 64), (322, 64), (320, 72), (250, 72)], BLACK)
    p.rect(256, 80, 316, 86, RED)
    for cx in (96, 224):                                       # cherry trees
        p.rect(cx - 3, 80, cx + 3, 128, BLACK)
        p.ellipse([cx - 34, 56, cx + 34, 96], MAGENTA)
        p.ellipse([cx - 22, 48, cx + 18, 74], WHITE)
    p.band(128, 176, YELLOW)                                   # the deck
    p.rect(0, 128, W, 133, RED)
    for y in (144, 160):
        p.rect(0, y, W, y + 2, RED)
    rnd = random.Random(7)                                     # petals
    for k in range(7):
        x0 = rnd.randrange(0, 320)
        y0 = rnd.randrange(0, 40)
        y = (y0 + phase * 8) % 48
        x = (x0 + phase * 4) % 320
        p.rect(x, y, x + 4, y + 4, WHITE if k % 2 else MAGENTA)
    return p.a


# ---------------------------------------------------------------- 1 BRAZIL
def brazil(phase):
    p = Pic()
    sky_gradient(p, [(0, CYAN, CYAN, 0), (40, CYAN, WHITE, 1)])
    p.ellipse([20, 14, 52, 46], YELLOW)
    p.poly([(150, 104), (190, 30), (214, 26), (236, 50), (250, 104)], GREEN)   # sugarloaf
    p.poly([(214, 104), (262, 60), (286, 58), (320, 90), (320, 104)], GREEN)
    p.line([(214, 28), (270, 60)], BLACK, 1)                                   # cable car
    p.rect(238 + (phase % 4) * 6, 40 + (phase % 4) * 4, 246 + (phase % 4) * 6, 46 + (phase % 4) * 4, RED)
    p.rect(0, 96, W, 112, BLUE)                                                # the sea
    for i in range(0, 320, 48):
        x = (i + phase * 6) % 336 - 8
        p.rect(x, 100 + (i // 48 % 2) * 6, x + 12, 102 + (i // 48 % 2) * 6, WHITE)
    for x, h in ((26, 60), (300, 70)):                                         # palms
        p.poly([(x - 3, 128), (x + 3, 128), (x + 9, 128 - h), (x + 5, 128 - h)], RED)
        for a in (-60, -20, 20, 60, 110):
            r = math.radians(a)
            tip = (x + 7 + 30 * math.sin(r), 128 - h + 18 - 22 * math.cos(r) * 0.6)
            p.poly([(x + 5, 128 - h), (x + 9, 128 - h + 2), tip], GREEN)
    p.rect(0, 112, W, 128, YELLOW)                                             # sand + crowd
    silhouettes(p, 108, 128, GREEN, phase, offset=48)
    p.rect(0, 112, 48, 128, YELLOW)
    p.rect(288, 112, W, 128, YELLOW)
    p.band(128, 176, YELLOW)
    p.dither(ymask(128, 176), YELLOW, WHITE, 1)
    p.rect(0, 128, W, 131, WHITE)
    return p.a


# ---------------------------------------------------------------- 2 USA
def usa(phase):
    p = Pic()
    sky_gradient(p, [(0, BLACK, BLACK, 0), (40, BLACK, BLUE, 1), (64, BLUE, BLACK, 2), (88, BLUE, BLUE, 0)])
    rnd = random.Random(5)
    x = 0
    k = 0
    while x < 320:                                                             # the skyline
        w = rnd.randrange(24, 48)
        top = rnd.randrange(24, 80)
        p.rect(x, top, x + w - 2, 128, BLACK)
        for wy in range(top + 6, 120, 10):
            for wx in range(x + 4, x + w - 8, 8):
                lit = rnd.random() < 0.45
                if lit and phase and ((wx * 7 + wy * 3 + phase) % 29 == 0):
                    lit = False
                if lit:
                    p.rect(wx, wy, wx + 4, wy + 4, YELLOW)
        x += w
        k += 1
    p.rect(132, 20, 136, 48, BLACK)                                            # spire
    # the neon sign
    on = phase % 2 == 0
    p.rect(110, 44, 210, 70, RED if on else BLACK)
    p.rect(114, 48, 206, 66, BLACK)
    for i, cx in enumerate(range(124, 204, 20)):
        p.ellipse([cx - 6, 50, cx + 6, 64], MAGENTA if (on or i % 2) else BLUE)
    # the roof: water tower and rail
    p.rect(260, 70, 300, 104, RED)
    p.poly([(256, 70), (280, 56), (304, 70)], RED)
    p.rect(264, 104, 268, 128, BLACK)
    p.rect(292, 104, 296, 128, BLACK)
    p.band(128, 176, BLUE)
    p.dither(ymask(128, 176), BLUE, CYAN, 1)
    p.rect(0, 128, W, 132, WHITE)
    for x in range(0, 320, 32):
        p.rect(x, 116, x + 3, 128, WHITE)
    p.rect(0, 116, W, 119, WHITE)
    return p.a


# ---------------------------------------------------------------- 3 CHINA
def china(phase):
    p = Pic()
    sky_gradient(p, [(0, BLACK, BLACK, 0), (32, BLACK, MAGENTA, 1), (56, MAGENTA, MAGENTA, 0)])
    # shop fronts: flat panels, one sign each
    cols = [RED, GREEN, RED, BLUE, RED]
    for i, x in enumerate(range(0, 320, 64)):
        p.rect(x, 40, x + 62, 128, cols[i])
        p.rect(x + 16, 52, x + 46, 76, YELLOW if i % 2 == 0 else WHITE)
        p.poly([(x - 4, 44), (x + 31, 26), (x + 66, 44)], BLACK)              # roofs
    # lanterns swing
    for i, x in enumerate(range(24, 320, 40)):
        dx = (2 if (phase + i) % 2 else -2)
        p.line([(x, 0), (x + dx, 14)], BLACK, 1)
        p.ellipse([x + dx - 9, 12, x + dx + 9, 30], RED)
        p.rect(x + dx - 5, 18, x + dx + 5, 24, YELLOW)
    p.rect(0, 0, W, 3, BLACK)
    silhouettes(p, 104, 128, BLACK, 0)
    p.band(128, 176, RED)
    p.dither(ymask(128, 176), RED, MAGENTA, 1)
    p.rect(0, 128, W, 132, YELLOW)
    return p.a


# ---------------------------------------------------------------- 4 RUSSIA
def russia(phase):
    p = Pic()
    sky_gradient(p, [(0, BLUE, BLUE, 0), (48, BLUE, CYAN, 1), (72, BLUE, CYAN, 2)])
    p.rect(0, 80, W, 128, RED)                                                 # the wall
    for x in range(0, 320, 16):
        p.rect(x, 72, x + 8, 80, RED)
    domes = [(70, 40, YELLOW, GREEN), (120, 28, RED, WHITE), (170, 20, GREEN, YELLOW), (220, 30, CYAN, RED),
             (264, 44, MAGENTA, YELLOW)]
    for cx, top, c1, c2 in domes:                                              # the cathedral
        p.rect(cx - 12, top + 26, cx + 12, 112, WHITE)
        p.ellipse([cx - 16, top + 4, cx + 16, top + 34], c1)
        p.poly([(cx - 6, top + 8), (cx, top - 8), (cx + 6, top + 8)], c1)
        for k in range(-12, 16, 8):
            p.rect(cx + k - 1, top + 10, cx + k + 1, top + 32, c2)
        p.rect(cx - 1, top - 14, cx + 1, top - 6, YELLOW)
        p.rect(cx - 4, top + 50, cx + 4, top + 62, BLUE)
    p.band(128, 176, CYAN)
    p.dither(ymask(132, 176), CYAN, WHITE, 1)
    p.rect(0, 128, W, 132, WHITE)
    rnd = random.Random(11)                                                    # snow
    for k in range(16):
        x0 = rnd.randrange(0, 320)
        y0 = rnd.randrange(0, 128)
        y = (y0 + phase * 6) % 128
        x = (x0 + int(4 * math.sin((y + k) / 9))) % 316
        p.rect(x, y, x + 3, y + 3, WHITE)
    return p.a


# ---------------------------------------------------------------- 5 MEXICO
def mexico(phase):
    p = Pic()
    p.band(0, 176, BLACK)
    # the stands: two tiers of silhouettes, a row of lights above
    for x in range(4, 320, 16):
        p.rect(x, 4, x + 6, 8, YELLOW if (x // 16 + phase) % 2 else RED)
    silhouettes(p, 20, 56, BLUE, 0, offset=8)
    silhouettes(p, 50, 84, RED, phase)
    # the ring
    p.band(110, 176, CYAN)
    p.rect(0, 110, W, 114, WHITE)
    for y, c in ((84, RED), (96, WHITE), (108, BLUE)):
        p.rect(0, y, W, y + 3, c)
    for x in (4, 312):
        p.rect(x, 80, x + 6, 128, YELLOW)
    p.rect(0, 128, W, 132, WHITE)
    p.dither(ymask(132, 176), CYAN, WHITE, 1)
    return p.a


# ---------------------------------------------------------------- 6 THAILAND
def thailand(phase):
    p = Pic()
    sky_gradient(p, [(0, MAGENTA, MAGENTA, 0), (24, MAGENTA, YELLOW, 1), (48, MAGENTA, YELLOW, 2),
                     (72, YELLOW, YELLOW, 0)])
    # the golden temple
    cx = 160
    p.poly([(cx - 70, 104), (cx, 10), (cx + 70, 104)], YELLOW)
    p.poly([(cx - 40, 104), (cx, 30), (cx + 40, 104)], RED)
    p.poly([(cx - 22, 104), (cx, 50), (cx + 22, 104)], YELLOW)
    p.rect(cx - 2, 0, cx + 2, 12, YELLOW)
    for x in (60, 260):
        p.poly([(x - 30, 104), (x, 50), (x + 30, 104)], RED)
        p.poly([(x - 16, 104), (x, 66), (x + 16, 104)], YELLOW)
    for x in (10, 110, 210, 300):                                              # palms
        p.rect(x, 60, x + 4, 104, BLACK)
        p.ellipse([x - 16, 52, x + 20, 68], GREEN)
    # the river: shimmer and a boat
    p.rect(0, 100, W, 128, BLUE)
    for i in range(0, 320, 20):
        x = (i + phase * 5) % 330 - 5
        p.rect(x, 106 + (i // 20 % 3) * 6, x + 8, 107 + (i // 20 % 3) * 6, CYAN)
    bx = (phase * 10) % 360 - 40
    p.poly([(bx, 112), (bx + 40, 112), (bx + 34, 120), (bx + 6, 120)], RED)
    p.ellipse([bx + 14, 104, bx + 24, 112], YELLOW)
    p.band(128, 176, RED)
    p.dither(ymask(128, 176), RED, YELLOW, 1)
    p.rect(0, 128, W, 131, YELLOW)
    return p.a


# ---------------------------------------------------------------- 7 INDIA
def india(phase):
    p = Pic()
    sky_gradient(p, [(0, CYAN, CYAN, 0), (56, CYAN, WHITE, 1)])
    cx = 160                                                                   # the palace
    p.rect(cx - 90, 60, cx + 90, 120, RED)                                     # red sandstone
    p.ellipse([cx - 36, 16, cx + 36, 80], WHITE)                               # marble dome
    p.rect(cx - 36, 56, cx + 36, 64, RED)
    p.poly([(cx - 4, 18), (cx, 4), (cx + 4, 18)], YELLOW)
    for x in (cx - 110, cx + 104):                                             # minarets
        p.rect(x, 20, x + 8, 120, RED)
        p.ellipse([x - 3, 12, x + 11, 26], WHITE)
    for x in range(cx - 80, cx + 80, 28):                                      # arches
        p.rect(x + 4, 84, x + 20, 120, BLACK)
        p.ellipse([x + 4, 76, x + 20, 92], BLACK)
    p.rect(cx - 90, 60, cx + 90, 64, YELLOW)
    # gardens and a fountain
    p.rect(0, 112, W, 128, GREEN)
    for x in (30, 290):
        h = 10 + (phase % 2) * 4
        p.rect(x - 2, 112 - h, x + 2, 112, CYAN)
        p.ellipse([x - 8, 112 - h - 6, x + 8, 112 - h + 4], WHITE)
    # peacock
    p.ellipse([96, 104, 116, 120], BLUE)
    p.ellipse([84, 94 if phase % 2 else 98, 108, 118], GREEN)
    p.band(128, 176, RED)
    p.dither(ymask(132, 176), RED, MAGENTA, 1)
    p.rect(0, 128, W, 131, WHITE)
    return p.a


# ---------------------------------------------------------------- 8 BOSS
def fortress(phase):
    p = Pic()
    flash = phase == 0
    sky_gradient(p, [(0, BLACK, BLACK, 0), (40, BLACK, MAGENTA, 1), (80, BLACK, RED, 1)])
    if flash:                                                                  # lightning
        p.line([(250, 0), (238, 30), (252, 34), (230, 80)], WHITE, 3)
        pass
    # the fortress
    p.rect(60, 40, 260, 128, MAGENTA)
    for x in range(60, 260, 20):
        p.rect(x, 32, x + 12, 40, MAGENTA)
    p.rect(140, 10, 180, 128, BLUE)
    p.poly([(132, 14), (160, -10), (188, 14)], RED)
    p.rect(150, 70, 170, 128, BLACK)
    p.ellipse([150, 60, 170, 80], BLACK)
    for x in (80, 220):
        p.rect(x, 60, x + 12, 76, YELLOW if (phase + x) % 3 else RED)
    # lava below
    p.band(112, 128, RED)
    for i in range(0, 320, 16):
        if (i // 16 + phase) % 3 == 0:
            p.rect(i, 114, i + 8, 118, YELLOW)
    p.band(128, 176, BLACK)
    p.dither(ymask(128, 176), BLACK, BLUE, 1)
    p.rect(0, 128, W, 131, MAGENTA)
    return p.a


# layers: (region c0, r0, c1, r1 in picture cells), phases, period in frames
STAGE_LIST = [
    ('japan', japan, [((0, 0, 40, 6), 6, 3)]),
    ('brazil', brazil, [((0, 12, 40, 16), 2, 8), ((26, 4, 40, 8), 4, 12)]),
    ('usa', usa, [((13, 5, 27, 9), 2, 12), ((0, 2, 40, 16), 3, 40)]),
    ('china', china, [((0, 0, 40, 4), 2, 10)]),
    ('russia', russia, [((0, 0, 40, 16), 4, 4)]),
    ('mexico', mexico, [((0, 0, 40, 11), 2, 8)]),
    ('thailand', thailand, [((0, 12, 40, 16), 4, 5)]),
    ('india', india, [((0, 11, 40, 15), 2, 10)]),
    ('fortress', fortress, [((26, 0, 34, 11), 3, 12), ((0, 13, 40, 15), 3, 10)]),
]
