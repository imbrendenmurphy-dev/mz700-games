"""gallery.py - render candidate 2x2 tiles: each arg 'TL,TR,BL,BR:fg/bg' (hex codes, +100 = bank 2)."""
import sys
from PIL import Image
import mzfont
S = 4
tiles = sys.argv[2:]
out = sys.argv[1]
im = Image.new('RGB', (len(tiles) * 20 * S, 20 * S), (60, 60, 60))
px = im.load()
for i, spec in enumerate(tiles):
    codes, col = spec.split(':')
    cs = [int(c, 16) for c in codes.split(',')]
    cols = col.split(',')
    for k in range(4):
        fg, bg = [int(v) for v in cols[k % len(cols)].split('/')]
        b = mzfont.glyph_bits(cs[k])
        ox = i * 20 + 2 + (k % 2) * 8
        oy = 2 + (k // 2) * 8
        for y in range(8):
            for x in range(8):
                c = mzfont.PAL[fg] if b[y][x] else mzfont.PAL[bg]
                for a in range(S):
                    for bb in range(S):
                        px[(ox + x) * S + a, (oy + y) * S + bb] = c
im.save(out)
