"""tilesheet.py - render every element look and a sample scene per theme (build/tiles_*.png)."""
import os
import sys
from PIL import Image
import mzfont
import tiles

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def draw_look(px, lk, ox, oy, S=2):
    for k, (g, fg, bg) in enumerate(lk):
        b = mzfont.glyph_bits(g)
        for y in range(8):
            for x in range(8):
                col = mzfont.PAL[fg] if b[y][x] else mzfont.PAL[bg]
                X = ox + (k % 2) * 8 + x
                Y = oy + (k // 2) * 8 + y
                for a in range(S):
                    for bb in range(S):
                        px[X * S + a, Y * S + bb] = col


names = [n for n in tiles.ELEMS]
im = Image.new('RGB', (2 * (8 * 20), 2 * (len(names) * 18)), (50, 50, 50))
px = im.load()
for i, n in enumerate(names):
    for p in range(8):
        draw_look(px, tiles.LOOK[n][p], p * 20, i * 18)
im.save(os.path.join(ROOT, 'build', 'tiles_all.png'))

SCENE = [
    '##########',
    '#..@.D..*#',
    '#.@@ d  K#',
    '#(  o  )S#',
    '#..T.P.C.#',
    '#.M.Z.X.f#',
    '#~~|=.^.G#',
    '##########',
]
LEG = {'#': 'STEEL', '.': 'EARTH', ' ': 'SPACE', '@': 'ROCK', 'D': 'GEM', 'd': 'CROWN', '*': 'PIECE',
       'K': 'KEY', '(': 'CURVL', ')': 'CURVR', 'o': 'EGG', 'S': 'SAFE', 'T': 'TRANS', 'P': 'PLAYER',
       'C': 'CAGE', 'M': 'MONSTER', 'Z': 'SPIRIT0', 'X': 'SKULL', 'f': 'FUNGUS', '~': 'WALL',
       '|': 'BARRIER', '=': 'SWITCH', '^': 'DECOR', 'G': 'GATE'}
im = Image.new('RGB', (2 * 2 * 10 * 16 + 20, 2 * 4 * 8 * 16 + 40), (50, 50, 50))
px = im.load()
for t, th in enumerate(tiles.THEMES):
    tl = tiles.themed_looks(th)
    ox = (t % 2) * 168
    oy = (t // 2) * 132
    for y, row in enumerate(SCENE):
        for x, ch in enumerate(row):
            n = LEG[ch]
            lk = tl[n] if n in tl else tiles.LOOK[n][0]
            draw_look(px, lk, ox + x * 16, oy + y * 16)
im.save(os.path.join(ROOT, 'build', 'tiles_scene.png'))
