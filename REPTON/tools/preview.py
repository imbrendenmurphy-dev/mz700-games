"""preview.py [KEYS] - render whole regions to build/region_K.png (as on screen, 2 x 2 cells a tile)."""
import os
import sys
from PIL import Image
import mzfont
import tiles
import world
from engine import W, H

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def render_region(cells, theme, scale=1):
    tl = tiles.themed_looks(tiles.THEMES[theme])
    im = Image.new('RGB', (W * 16, H * 16))
    px = im.load()
    for p, v in enumerate(cells):
        n = tiles.ELEMS[v & 0x3F]
        lk = tl[n] if n in tl else tiles.LOOK[n][0]
        if n == 'PLAYER':
            lk = tiles.EXTRA['LK_PLIDLE'][0]
        ox, oy = (p % W) * 16, (p // W) * 16
        for k, (g, fg, bg) in enumerate(lk):
            b = mzfont.glyph_bits(g)
            for y in range(8):
                for x in range(8):
                    px[ox + (k % 2) * 8 + x, oy + (k // 2) * 8 + y] = mzfont.PAL[fg] if b[y][x] else mzfont.PAL[bg]
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    return im


if __name__ == '__main__':
    wd = world.load()
    want = sys.argv[1] if len(sys.argv) > 1 else None
    for r in wd.regions:
        if want and r.key not in want:
            continue
        cells = list(r.cells)
        if r.start:
            cells[r.start] = tiles.E['PLAYER']
        render_region(cells, r.theme).save(os.path.join(ROOT, 'build', 'region_%s.png' % r.key))
        print('build/region_%s.png  %s' % (r.key, r.name))
