"""pictures.py - the full-screen pictures of UNDERMINED's attract mode and
ending, drawn in ROM characters, plus the lists of cells the Z80 animates.

    story()     "The Legend": the seven wings in cross-section, down to the heart
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
        return self

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
    """the legend in cross-section: the mountain on the skyline, and under it
    the seven wings as seven strata, a mine zig-zagging down to the heart"""
    import caves
    p = Pic()
    rnd = random.Random(7)
    anim = {'stars': [], 'gems': [], 'lamps': [], 'heart': []}
    # the night sky
    for _ in range(26):
        x, y = rnd.randrange(W), rnd.randrange(0, 6)
        p.put(x, y, STAR if rnd.random() < 0.3 else DOT, rnd.choice((WHITE, WHITE, CYAN, YELLOW)))
        anim['stars'].append(y * W + x)
    p.put(36, 1, ROCK, YELLOW)                                      # the moon
    mountain(p, 10, 0, 6, BLUE, snow=2)
    mountain(p, 22, 3, 6, BLUE, snow=1)
    anim['stars'] = [o for o in anim['stars'] if p.ch[o] in (STAR, DOT)]
    # the pithead: a winding wheel on its frame over the shaft
    p.put(30, 4, ROCK, YELLOW)
    p.put(29, 5, UR, YELLOW).put(31, 5, UL, YELLOW)
    # the turf, then the seven wings' rock, one stratum each, deeper and deeper
    for x in range(W):
        p.put(x, 7, 0x1EE, GREEN)
    bands = (2, 2, 2, 2, 1, 1, 2)
    y = 8
    rows = {}
    for w, h in enumerate(bands):
        g, a = caves.THEMES[w]['dirt']
        for yy in range(y, y + h):
            rows[yy] = w
            for x in range(W):
                p.ch[yy * W + x] = g
                p.at[yy * W + x] = a
        y += h
    # the mine: down the shaft, then back and forth, wing by wing
    path = []                                   # (x, y, face) - 0 left, 1 down, 2 right

    def run(x0, x1, y, face=None):
        st = 1 if x1 >= x0 else -1
        for x in range(x0, x1 + st, st):
            path.append((x, y, face if face is not None else (2 if st > 0 else 0)))

    def down(x, y0, y1):
        for y in range(y0, y1 + 1):
            path.append((x, y, 1))

    run(39, 31, 6)
    down(30, 6, 9)
    run(29, 7, 9)
    down(7, 10, 11)
    run(8, 27, 11)
    down(27, 12, 13)
    run(26, 10, 13)
    down(10, 14, 15)
    run(11, 18, 15)
    down(18, 16, 19)
    run(19, 20, 19)
    for x, y, f in path:
        if y >= 7:
            p.put(x, y, 0, WHITE)
    # the heart: a great gem in its own chamber at the bottom
    for x in range(14, 27):
        p.put(x, 18, 0, WHITE).put(x, 19, 0, WHITE)
    for dx, g in enumerate((UR, FULL, UL)):
        p.put(22 + dx, 18, g, CYAN)
    for dx, g in enumerate((DR, FULL, DL)):
        p.put(22 + dx, 19, g, CYAN)
    anim['heart'] = [o for y in (18, 19) for o in range(y * W + 22, y * W + 25)]
    for x in (15, 16, 26):
        p.put(x, 19, GEM, CYAN)
        anim['gems'].append(19 * W + x)
    # gems in each wing's rock, beside the galleries, in that wing's colours
    for x, y in ((14, 8), (24, 10), (4, 10), (20, 12), (33, 12), (6, 14), (25, 14), (14, 16), (3, 17)):
        th = caves.THEMES[rows[y]]
        p.put(x, y, GEM, th['gem'][1][0])           # (they keep their colour: no glint)
    for x, y in ((18, 9), (16, 11), (20, 13)):
        p.put(x, y, 0x1B1, YELLOW)                                  # lanterns
        anim['lamps'].append(y * W + x)
    anim['walk'] = [(y * W + x) | (f << 14) for x, y, f in path]
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


# the title: UNDER stands on the ground against the night, MINED is dug into
# the earth below it ('#' block, '/' 'Q' 'L' 'J' the rounded corners)
LETTERS = {
    'U': ['#..#', '#..#', '#..#', '#..#', '#..#', '#..#', 'L##J'],
    'N': ['#..#', '##.#', '##.#', '#.##', '#.##', '#..#', '#..#'],
    'D': ['###Q', '#..#', '#..#', '#..#', '#..#', '#..#', '###J'],
    'E': ['####', '#...', '#...', '###.', '#...', '#...', '####'],
    'R': ['###Q', '#..#', '#..#', '###J', '#.Q.', '#.LQ', '#..#'],
    'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'I': ['###', '.#.', '.#.', '.#.', '.#.', '.#.', '###'],
}
SHAPE = {'#': FULL, '/': UR, 'Q': UL, 'L': DR, 'J': DL}
SKY_H, TURF, EARTH_H = 7, 7, 8          # sky rows 0-6, turf row 7, earth rows 8-15


def word(word, y0):
    w = sum(len(LETTERS[c][0]) for c in word) + len(word) - 1
    x = (W - w) // 2
    for ch in word:
        rows = LETTERS[ch]
        for r, row in enumerate(rows):
            for c, v in enumerate(row):
                if v != '.':
                    yield x + c, y0 + r, v
        x += len(rows[0]) + 1


def title():
    p = Pic()
    anim = {'stars': []}
    for y in range(SKY_H):
        for x in range(W):
            p.put(x, y, 0, WHITE, BLUE)
    for x, y in ((2, 1), (5, 4), (1, 6), (33, 1), (36, 4), (38, 2), (34, 6), (3, 3), (7, 6)):
        p.put(x, y, STAR, YELLOW if (x + y) % 3 else WHITE, BLUE)
        anim['stars'].append(y * W + x)
    p.put(37, 0, ROCK, YELLOW, BLUE)                            # the moon
    for x, y, v in word('UNDER', 0):
        p.put(x, y, SHAPE[v], WHITE, BLUE)
    anim['stars'] = [o for o in anim['stars'] if p.ch[o] == STAR]
    for x in range(W):
        p.put(x, TURF, 0x1EE, GREEN)
    for y in range(TURF + 1, TURF + 1 + EARTH_H):
        for x in range(W):
            p.put(x, y, 0xD0, RED)
    for x, y, v in word('MINED', TURF + 1):
        p.put(x, y, 0, WHITE)                                   # dug out of the earth
    p.put(25, 10, GEM, CYAN)
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
    for name, fn in (('title', title), ('story', story), ('daybreak', daybreak)):
        cells, anim = fn()
        preview(cells, os.path.join(root, 'build', 'pic_%s.png' % name))
        print(name, len(rle(cells)), 'bytes packed')
