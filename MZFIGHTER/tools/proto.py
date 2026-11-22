"""proto.py - look test: a fighter in a few poses, pixel art vs. MZ cells."""
import sys
import os
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import figure as FG  # noqa
from figure import Build, Costume, Pose, BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE  # noqa
import cells  # noqa
import mzfont as F  # noqa

PALRGB = F.PAL + [(90, 90, 90)]


def to_cells(img, shift=0):
    """img: (H, W) indices with the anchor at FG.AX.  Returns dict (col,row)->cell
    with col relative to the anchor cell, row relative to the ground row."""
    h, w = img.shape
    # pad so that pixel AX + shift lands on a cell boundary
    left = (8 - (FG.AX + shift) % 8) % 8
    pad = np.full((h, w + 16), FG.TR, np.uint8)
    pad[:, left:left + w] = img
    ax = FG.AX + left
    top = (FG.AY % 8)
    out = {}
    for r in range(h // 8 + 1):
        for cc in range((w + 16) // 8):
            y0 = FG.AY - (r + 1) * 8
            if y0 < 0:
                continue
            blk = pad[y0:y0 + 8, cc * 8:cc * 8 + 8]
            if blk.shape != (8, 8):
                continue
            cell = cells.sprite_cell(blk)
            if cell:
                out[(cc - (ax - shift) // 8, r)] = cell
    return out


def stage_bg():
    """a test stage: sky, mountains, floor - as cells"""
    ch = [[None] * 40 for _ in range(25)]
    for r in range(25):
        for c in range(40):
            if r < 14:
                ch[r][c] = (0, 0, BLUE if r < 8 else MAGENTA)
            elif r < 16:
                ch[r][c] = (0xF5 if (c + r) % 3 else 0, GREEN, CYAN)
            else:
                ch[r][c] = (0x7a, RED, YELLOW) if r == 23 else ((0, 0, GREEN) if r < 23 else (0x7e, RED, MAGENTA))
    return ch


def render(grid):
    chars = []
    attrs = []
    for r in range(25):
        for c in range(40):
            g, fg, bg = grid[r][c]
            chars.append(g & 255)
            attrs.append(((g >> 8) << 7) | (fg << 4) | bg)
    return F.render_cells(chars, attrs, scale=1)


def place(grid, cl, col, row, flip=False):
    for (c, r), (g, fg, bg, tr) in cl.items():
        if flip:
            c = -c - 1
            g = cells.mirror_glyph(g)
        x, y = col + c, row - r
        if 0 <= x < 40 and 0 <= y < 25:
            if tr:
                bg = grid[y][x][2]
            grid[y][x] = (g, fg, bg)


def pix_image(img, scale=1):
    h, w = img.shape
    im = Image.new('RGB', (w, h))
    im.putdata([PALRGB[v] for v in img.reshape(-1)])
    return im.resize((w * scale, h * scale), Image.NEAREST)


if __name__ == '__main__':
    import fighters as FT
    name = sys.argv[1] if len(sys.argv) > 1 else 'kenji'
    ftr = FT.FIGHTERS[name]
    poses = sys.argv[2].split(',') if len(sys.argv) > 2 else ['stance', 'punch', 'kick', 'crouch']
    grid = stage_bg()
    col = 5
    pix = []
    for i, pn in enumerate(poses):
        img, J = FG.draw_figure(ftr.build, ftr.costume, FT.pose(ftr, pn))
        pix.append(pix_image(img[30:, 20:140], 1))
        cl = to_cells(img, 0)
        place(grid, cl, col, 22, flip=(i % 2 == 1 and len(poses) == 2))
        col += 10 if len(poses) < 4 else 9
    im = render(grid)
    out = Image.new('RGB', (max(640, 124 * len(pix)), 400 + 110), (40, 40, 40))
    out.paste(im.resize((640, 400), Image.NEAREST), (0, 0))
    x = 0
    for p in pix:
        out.paste(p, (x, 404))
        x += 124
    out.save(sys.argv[3] if len(sys.argv) > 3 else '../build/proto.png')
