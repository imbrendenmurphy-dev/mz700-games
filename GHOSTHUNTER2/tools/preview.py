"""preview.py - render every maze (and the style variants) to build/maze_X.png."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mazes  # noqa: E402
import looks  # noqa: E402
import mzfont  # noqa: E402

OUT = os.path.join(HERE, '..', 'build')
os.makedirs(OUT, exist_ok=True)


def screen(g, style, power=False, actors=()):
    ch = [0] * 1000
    at = [0x71] * 1000
    lk = looks.wall_looks(g)
    for y in range(looks.VIS_Y0, looks.VIS_Y1):
        for x in range(looks.VIS_X0, looks.VIS_X1):
            gl, fg, bg = looks.cell_look(g[y][x], lk[y][x], style, power)
            i = (y + looks.YOFF) * 40 + x + looks.XOFF
            ch[i] = gl & 0xFF
            at[i] = ((gl >> 8) << 7) | (fg << 4) | bg
    for (x, y, gl, fg) in actors:
        i = (y + looks.YOFF) * 40 + x + looks.XOFF
        ch[i] = gl & 0xFF
        at[i] = ((gl >> 8) << 7) | (fg << 4) | (at[i] & 7)
    return ch, at


if __name__ == '__main__':
    acts = [(20, 14, 0x14C, 6), (20, 6, 0x136, 2), (17, 10, 0x136, 4), (20, 10, 0x136, 3),
            (23, 10, 0x138, 5)]
    for name, title, g, style in mazes.all_grids():
        ch, at = screen(g, style, actors=acts)
        hud = mzfont.text_codes('000090  HI 010000  L01')
        for i, c in enumerate(hud):
            ch[i] = c
            at[i] = 0x61
        mzfont.render_cells(ch, at).save(os.path.join(OUT, 'maze_%s.png' % name))
        ch, at = screen(g, style, power=True, actors=acts)
        mzfont.render_cells(ch, at).save(os.path.join(OUT, 'maze_%s_power.png' % name))
    print('ok')
