"""sheet.py FIGHTER - every frame of a fighter: pixel art over MZ cells."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import figure as FG, fighters as FT, proto
import mzfont as F

def main(name, out):
    f = FT.FIGHTERS[name]
    n = len(FT.FRAMES)
    per = 5
    rowsn = (n + per - 1) // per
    sheet = Image.new('RGB', (per * 2 * 130, rowsn * 140), (50, 50, 50))
    for i, pn in enumerate(FT.FRAMES):
        img, J = FG.draw_figure(f.build, f.costume, FT.pose(f, pn))
        x = (i % per) * 260
        y = (i // per) * 140
        sheet.paste(proto.pix_image(img[0:136, 15:145]), (x, y))
        cl = proto.to_cells(img, 0)
        grid = [[(0, 0, F.BLUE if r < 20 else F.GREEN) for c in range(16)] for r in range(17)]
        for (c, r), (g, fg, bg, tr) in cl.items():
            xx, yy = 8 + c, 16 - r
            if 0 <= xx < 16 and 0 <= yy < 17:
                if tr:
                    bg = grid[yy][xx][2]
                grid[yy][xx] = (g, fg, bg)
        chars = [grid[r][c][0] & 255 for r in range(17) for c in range(16)]
        attrs = [((grid[r][c][0] >> 8) << 7) | (grid[r][c][1] << 4) | grid[r][c][2] for r in range(17) for c in range(16)]
        im = F.render_cells(chars, attrs, cols=16, rows=17, scale=1)
        sheet.paste(im.crop((0, 0, 128, 136)), (x + 130, y))
    sheet.save(out)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else '../build/sheet.png')
