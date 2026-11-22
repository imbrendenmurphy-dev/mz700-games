"""pictures.py - the full-screen pictures of ROCKFALL's attract mode and
ending, drawn in ROM characters, plus the lists of cells the Z80 animates.

    story()     "The Legend": the mountain by night, its caves lit inside
    daybreak()  the ending: out of the mountain, the sun coming up

Each returns (cells, anim): cells is 1000 (char, attr) pairs for the
40 x 25 screen; anim is a dict of lists of screen offsets (twinkling
stars, glinting gems, ...).  build.py packs the cells as runs of
(count, char, attr) and writes the lists as tables.

    py tools/pictures.py        preview both into build/pic_*.png
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mzfont as F  # noqa: E402

BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)
FULL, UR, UL, DR, DL = 0x43, 0x4E, 0x4D, 0x42, 0x56   # block; slopes filled lower-right / lower-left
GEM, STAR, DOT, ROCK = 0x44, 0x6B, 0x2E, 0x14F
W, H = 40, 25


def at(fg, bg=BLACK):
    return (fg << 4) | bg


class Pic:
    def __init__(self, bg=BLACK):
        self.ch = [0] * (W * H)
        self.at = [at(WHITE, bg)] * (W * H)

    def put(self, x, y, g, fg, bg=BLACK):
        if 0 <= x < W and 0 <= y < H:
            self.ch[y * W + x] = g & 0xFF
            self.at[y * W + x] = ((g >> 8) << 7) | at(fg, bg)

    def get(self, x, y):
        return self.ch[y * W + x]

    def text(self, x, y, s, fg, bg=BLACK):
        for i, v in enumerate(F.text_codes(s)):
            self.ch[y * W + x + i] = v
            self.at[y * W + x + i] = at(fg, bg)

    def cells(self):
        return list(zip(self.ch, self.at))


def mountain(p, cx, top, base, fg, snow=3, bg=BLACK):
    """a peak: rows top..base, one cell wider each side per row; returns its cells"""
    inner = []
    for y in range(top, base + 1):
        k = y - top
        for x in range(cx - k, cx + k + 1):
            if x == cx - k:
                g = UR
            elif x == cx + k:
                g = UL
            else:
                g = FULL
                inner.append((x, y))
            p.put(x, y, g, WHITE if k < snow else fg, bg)
    return inner


def story():
    p = Pic()
    rnd = random.Random(7)
    anim = {'stars': [], 'gems': [], 'lamps': []}
    # the night sky
    for _ in range(34):
        x, y = rnd.randrange(W), rnd.randrange(0, 11)
        p.put(x, y, STAR if rnd.random() < 0.3 else DOT, rnd.choice((WHITE, WHITE, CYAN, YELLOW)))
        anim['stars'].append(y * W + x)
    p.put(33, 2, ROCK, YELLOW)                                      # the moon
    # two peaks; the big one holds the caves
    mountain(p, 30, 6, 17, BLUE, snow=2)
    inner = mountain(p, 13, 3, 17, BLUE, snow=3)
    # tunnels inside the big peak, with gems and a lantern or two
    tunnel = [(13, 8), (12, 9), (13, 9), (14, 9), (14, 10), (15, 10), (16, 10), (16, 11), (16, 12),
              (15, 12), (14, 12), (13, 12), (12, 12), (11, 12), (10, 12), (9, 13), (10, 13), (9, 14),
              (9, 15), (10, 15), (11, 15), (12, 15), (13, 15), (14, 15), (15, 15), (16, 15), (17, 15),
              (18, 15), (19, 15), (20, 15), (21, 16), (20, 16), (22, 16), (23, 17), (22, 17)]
    for x, y in tunnel:
        p.put(x, y, 0, WHITE)
    for x, y in ((12, 9), (16, 11), (10, 12), (9, 14), (13, 15), (18, 15)):
        p.put(x, y, GEM, CYAN)
        anim['gems'].append(y * W + x)
    for x, y in ((14, 10), (11, 15)):
        p.put(x, y, 0x1B1, YELLOW)                                  # lanterns
        anim['lamps'].append(y * W + x)
    # only the stars the mountains left showing twinkle
    anim['stars'] = [o for o in anim['stars'] if p.ch[o] in (STAR, DOT)]
    # the ground, and the way in
    for x in range(W):
        p.put(x, 18, 0xD0, RED)
    for x in (23, 24, 25):
        p.put(x, 17, 0, WHITE)
    # the miner walks home along the ground and into the mountain
    anim['walk'] = [18 * W + x for x in range(39, 24, -1)] + [17 * W + 25, 17 * W + 24, 17 * W + 23]
    return p.cells(), anim


def daybreak():
    p = Pic()
    anim = {'rays': [], 'gems': []}
    # a dawn sky: dark blue above, warmer towards the horizon
    for y in range(0, 15):
        bg = BLUE if y < 9 else (MAGENTA if y < 12 else RED)        # night giving way to sunrise
        for x in range(W):
            p.put(x, y, 0, WHITE, bg)
    # the sun, half risen between the peaks
    for dy, row in enumerate(['  ###  ', ' ##### ', '#######']):
        for dx, c in enumerate(row):
            if c == '#':
                p.put(17 + dx, 11 + dy, FULL, YELLOW, p.at[(11 + dy) * W] & 7)
    for x, y in ((14, 10), (26, 10), (16, 8), (24, 8), (20, 7)):
        p.put(x, y, STAR, YELLOW, p.at[y * W] & 7)
        anim['rays'].append(y * W + x)
    # the mountains in silhouette, in front of the sun
    for cx, top in ((7, 7), (33, 6)):
        for y in range(top, 15):
            k = y - top
            for x in range(cx - k, cx + k + 1):
                bg = p.at[y * W + x] & 7 if 0 <= x < W else BLACK
                g = UR if x == cx - k else (UL if x == cx + k else FULL)
                p.put(x, y, g, BLACK if g == FULL else BLACK, bg)
    # the valley floor, a path, and the miner's sack of gems
    for y in range(15, 18):
        for x in range(W):
            p.put(x, y, 0x1EE, GREEN)
    for x in range(12, 29):
        p.put(x, 16, 0, WHITE)
    for x in (22, 23, 24):
        p.put(x, 15, GEM, CYAN)
        anim['gems'].append(15 * W + x)
    anim['walk'] = [16 * W + x for x in range(12, 29)]              # the miner, heading home
    return p.cells(), anim


def rle(cells):
    """runs of (count, char, attr), ended by a 0 count"""
    out = []
    i = 0
    while i < len(cells):
        j = i
        while j < len(cells) and cells[j] == cells[i] and j - i < 255:
            j += 1
        out += [j - i, cells[i][0], cells[i][1]]
        i = j
    return out + [0]


def preview(cells, path):
    ch = [c for c, a in cells]
    at_ = [a for c, a in cells]
    F.render_cells(ch, at_, W, H, scale=2).save(path)


if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for name, fn in (('story', story), ('daybreak', daybreak)):
        cells, anim = fn()
        preview(cells, os.path.join(root, 'build', 'pic_%s.png' % name))
        print(name, len(rle(cells)), 'bytes packed')
