"""sheet.py - contact sheet of model views from several flat tiles."""
import math, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model as M

isl = int(sys.argv[1]) if len(sys.argv) > 1 else 0
c = M.gen_corners(isl)
fm = M.gen_fine(c)
flats = [(c[ty][tx], tx, ty) for ty in range(2, 30) for tx in range(2, 30) if M.tile_flat(c, tx, ty) and c[ty][tx] > 0]
flats.sort()
picks = [flats[int(len(flats) * q)] for q in (0.1, 0.4, 0.7, 0.95)]
tiles = []
for lev, tx, ty in picks:
    ang = math.atan2(16 - tx, -(16 - ty))
    hd = int(round(ang / (2 * math.pi) * 32)) % 32
    scr = M.render(fm, tx * 4 + 2, ty * 4 + 2, lev * 4 + M.EYE, hd)
    p = 'build/_t.png'
    M.to_png(scr, p, 1)
    tiles.append(Image.open(p).copy())
    print('lev', lev, 'tile', tx, ty, 'hd', hd)
w, h = tiles[0].size
sheet = Image.new('RGB', (w * 2 + 8, h * 2 + 8), (60, 60, 60))
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % 2) * (w + 8), (i // 2) * (h + 8)))
sheet.save('build/sheet%d.png' % isl)
