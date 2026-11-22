"""art.py - small cell blocks: hit sparks, projectiles, banners, timer digits.

A block is  db w, h  then h rows of w (char, attr) pairs; attr bit 3 =
transparent paper, (0, 8) = nothing.
"""
import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cells  # noqa
from figure import TR, BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE  # noqa

FONTDIR = r'C:\Windows\Fonts'


def img_to_block(img, glyphs='sprite'):
    """img: (h*8, w*8) colour indices with TR.  -> (w, h, [(char, attr)])"""
    h, w = img.shape
    assert h % 8 == 0 and w % 8 == 0
    out = []
    for r in range(h // 8):
        for c in range(w // 8):
            blk = img[r * 8:r * 8 + 8, c * 8:c * 8 + 8]
            cell = cells.sprite_cell(blk) if glyphs == 'sprite' else cells.any_cell(blk)
            if not cell:
                out.append((0, 8))
            else:
                g, fg, bg, tr = cell
                a = ((g >> 8) << 7) | (fg << 4) | (8 if tr else bg)
                out.append((g & 255, a))
    return (w // 8, h // 8, out)


def block_lines(label, blk):
    w, h, cl = blk
    lines = ['%s:' % label, '        db %d,%d' % (w, h)]
    flat = []
    for ch, at in cl:
        flat += [ch, at]
    for i in range(0, len(flat), 24):
        lines.append('        db ' + ','.join(str(v) for v in flat[i:i + 24]))
    return lines


def canvas(w, h, ss=4):
    im = Image.new('P', (w * ss, h * ss), TR)
    return im, ImageDraw.Draw(im)


def down(im, w, h, ss=4):
    a = np.array(im, dtype=np.uint8).reshape(h, ss, w, ss).transpose(0, 2, 1, 3).reshape(h, w, ss * ss)
    cnt = np.zeros((h, w, 9), np.int32)
    for c in range(9):
        cnt[:, :, c] = (a == c).sum(2)
    best = cnt[:, :, :8].argmax(2)
    n = cnt[:, :, :8].max(2)
    return np.where(n * 2 >= ss * ss // 2 * 1, best, TR).astype(np.uint8)


# ---------------------------------------------------------------- sparks
def spark(kind, phase):
    W, H = 24, 24
    im, d = canvas(W, H)
    S = 4
    cx, cy = 12 * S, 12 * S
    col_out = YELLOW if kind == 'hit' else CYAN
    col_in = WHITE
    r1 = (11 if phase == 0 else 8) * S
    r0 = (4 if phase == 0 else 2) * S
    n = 8
    pts = []
    for i in range(n * 2):
        a = math.pi * i / n + (0.2 if phase else 0)
        r = r1 if i % 2 == 0 else r0
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=col_out)
    d.ellipse([cx - 4 * S, cy - 4 * S, cx + 4 * S, cy + 4 * S], fill=col_in)
    if phase == 1:
        d.ellipse([cx - 2 * S, cy - 2 * S, cx + 2 * S, cy + 2 * S], fill=TR)
    return img_to_block(down(im, W, H))


# ---------------------------------------------------------------- projectiles
def projectile(style, phase, flip):
    """24 x 16 pixels (3 x 2 cells), travelling right (flip = left)"""
    W, H = 24, 16
    im, d = canvas(W, H)
    S = 4
    st = PROJ_STYLES[style]
    c1, c2, c3 = st['cols']
    shape = st['shape']
    if shape == 'ball':
        # tail
        for i in range(4):
            x = (4 + i * 2 + (phase * 2)) * S
            y = (8 + (2 if (i + phase) % 2 else -2)) * S
            d.ellipse([x - 3 * S, y - 3 * S, x + 3 * S, y + 3 * S], fill=c3)
        d.ellipse([10 * S, 2 * S, 23 * S, 14 * S], fill=c1)
        d.ellipse([14 * S, 5 * S, 21 * S, 11 * S], fill=c2)
    elif shape == 'bolt':
        pts = [(0, 8), (6, 4 + phase * 4), (10, 10 - phase * 4), (15, 3), (19, 12), (23, 7)]
        for i in range(len(pts) - 1):
            a = (pts[i][0] * S, pts[i][1] * S)
            b = (pts[i + 1][0] * S, pts[i + 1][1] * S)
            d.line([a, b], fill=c1, width=4 * S)
        d.ellipse([16 * S, 3 * S, 23 * S, 12 * S], fill=c2)
    elif shape == 'ring':
        d.ellipse([6 * S, 1 * S, 23 * S, 15 * S], fill=c1)
        d.ellipse([10 * S, 4 * S, 20 * S, 12 * S], fill=c2 if phase else TR)
        d.rectangle([0, 6 * S, 7 * S, 10 * S], fill=c3)
    elif shape == 'blade':
        d.polygon([(2 * S, 8 * S), (14 * S, (2 + phase * 2) * S), (23 * S, 8 * S), (14 * S, (14 - phase * 2) * S)], fill=c1)
        d.polygon([(8 * S, 8 * S), (15 * S, 5 * S), (21 * S, 8 * S), (15 * S, 11 * S)], fill=c2)
    a = down(im, W, H)
    if flip:
        a = a[:, ::-1]
    return img_to_block(a)


PROJ_STYLES = {
    'fire': {'shape': 'ball', 'cols': (YELLOW, WHITE, RED)},
    'chi': {'shape': 'ball', 'cols': (CYAN, WHITE, BLUE)},
    'bolt': {'shape': 'bolt', 'cols': (CYAN, WHITE, BLUE)},
    'ring': {'shape': 'ring', 'cols': (MAGENTA, WHITE, RED)},
    'blade': {'shape': 'blade', 'cols': (GREEN, YELLOW, GREEN)},
    'jade': {'shape': 'ball', 'cols': (GREEN, YELLOW, GREEN)},
}


# ---------------------------------------------------------------- text art
def text_image(s, font='impact.ttf', size=None, h_cells=3, cols=(YELLOW, YELLOW, RED, RED), outline=None, pad=1,
               spacing=1):
    """big banner text: one colour per cell row (top to bottom), no outline,
    letters spaced so that each cell holds one colour"""
    H = h_cells * 8
    f = ImageFont.truetype(os.path.join(FONTDIR, font), H * 4 * 13 // 10)
    letters = []
    for ch in s:
        if ch == ' ':
            letters.append(None)
            continue
        tmp = Image.new('L', (H * 8, H * 8), 0)
        d = ImageDraw.Draw(tmp)
        d.text((H, 0), ch, font=f, fill=255)
        letters.append(tmp.crop(tmp.getbbox()))
    caph = max(l.height for l in letters if l is not None)
    sc = (H * 4 - 4) / caph
    parts = []
    for l in letters:
        if l is None:
            parts.append(np.zeros((H, 5), bool))
            continue
        w = max(1, int(round(l.width * sc / 4)))
        hh = max(1, int(round(l.height * sc / 4)))
        im = l.resize((w * 4, hh * 4), Image.LANCZOS).resize((w, hh), Image.BOX)
        m = np.array(im) > 110
        col = np.zeros((H, w + spacing), bool)
        col[H - hh:H, :w] = m
        parts.append(col)
    m = np.concatenate(parts, 1)
    W = ((m.shape[1] + 2 * pad) + 7) // 8 * 8
    a = np.full((H, W), TR, np.uint8)
    ox = (W - m.shape[1]) // 2
    for y in range(H):
        c = cols[min(len(cols) - 1, y * len(cols) // H)]
        for x in np.nonzero(m[y])[0]:
            a[y, ox + x] = c
    return a


def banner(s, cols=(WHITE, YELLOW, YELLOW, RED, RED), **kw):
    """5-row block-font banner, one colour per row"""
    import font5
    rows = font5.bitmap(s)
    w = len(rows[0]) // 2
    out = []
    for r in range(5):
        c = cols[r]
        for x in range(w):
            pair = rows[r][x * 2:x * 2 + 2]
            if pair == '##':
                out.append((0x43, (c << 4) | 8))
            elif pair == '#.':
                out.append((0x7b, (c << 4) | 8))
            elif pair == '.#':
                out.append((0x3b, (c << 4) | 8))
            else:
                out.append((0, 8))
    return (w, 5, out)


DIGIT_GLYPHS = [0, 0x43, 0x7a, 0x3a, 0x7b, 0x3b, 0x5b, 0x6c, 0x42, 0x4d, 0x4e, 0x56, 0x36, 0x37, 0x3e, 0x3f, 0x70,
                0x71, 0x3c, 0x3d]
SEG = {0: 'abcdef', 1: 'bc', 2: 'abged', 3: 'abgcd', 4: 'fgbc', 5: 'afgcd', 6: 'afgedc', 7: 'abc',
       8: 'abcdefg', 9: 'abcdfg'}


D44 = {0: ['####', '#..#', '#..#', '####'], 1: ['.##.', '..#.', '..#.', '..#.'],
       2: ['####', '..##', '##..', '####'], 3: ['####', '.###', '...#', '####'],
       4: ['#..#', '#..#', '####', '...#'], 5: ['####', '##..', '..##', '####'],
       6: ['#...', '####', '#..#', '####'], 7: ['####', '...#', '..#.', '..#.'],
       8: ['####', '####', '#..#', '####'], 9: ['####', '#..#', '####', '...#']}
_q = {}


def _quad_glyphs():
    """2x2 quarter pattern -> best glyph (exact halves, triangles for 1/3 quarters)"""
    if _q:
        return _q
    for k in range(16):
        q = [(k >> i) & 1 for i in range(4)]   # TL TR BL BR
        tgt = np.zeros((8, 8), np.uint8)
        tgt[0:4, 0:4] = q[0]
        tgt[0:4, 4:8] = q[1]
        tgt[4:8, 0:4] = q[2]
        tgt[4:8, 4:8] = q[3]
        best = None
        for g in DIGIT_GLYPHS:
            gp = cells.glyph_pixels(g)
            for inv in (0, 1):
                e = int(np.abs((gp ^ inv) - tgt).sum())
                if best is None or e < best[0]:
                    best = (e, g, inv)
        _q[k] = best[1:]
    return _q


def big_digit(n):
    """2 x 2 cells, a rounded block digit in white on blue"""
    qg = _quad_glyphs()
    rows = D44[n]
    out = []
    for r in range(2):
        for c in range(2):
            k = 0
            for i, (dy, dx) in enumerate(((0, 0), (0, 1), (1, 0), (1, 1))):
                if rows[r * 2 + dy][c * 2 + dx] == '#':
                    k |= 1 << i
            g, inv = qg[k]
            fg, bg = (BLUE, WHITE) if inv else (WHITE, BLUE)
            out.append((g & 255, ((g >> 8) << 7) | (fg << 4) | bg))
    return out


def generate():
    out = ['; generated by tools/art.py']
    for kind in ('hit', 'blk'):
        for ph in range(2):
            out += block_lines('spark_%s%d' % (kind, ph), spark('hit' if kind == 'hit' else 'blk', ph))
    for st in PROJ_STYLES:
        labels = []
        for flip in (0, 1):
            for ph in range(2):
                lb = 'proj_%s_%d%d' % (st, flip, ph)
                labels.append(lb)
                out += block_lines(lb, projectile(st, ph, flip))
        out.append('pa_%s: dw %s' % (st, ','.join(labels)))
    out += banner_asm()
    out.append('big_digits:')
    for n in range(10):
        flat = []
        for ch, at in big_digit(n):
            flat += [ch, at]
        out.append('        db ' + ','.join(str(v) for v in flat))
    return out


BANNERS = [
    ('round1', 'ROUND 1', {}),
    ('round2', 'ROUND 2', {}),
    ('round3', 'ROUND 3', {}),
    ('final', 'FINAL ROUND', {}),
    ('fight', 'FIGHT!', {'cols': (WHITE, WHITE, YELLOW, YELLOW, RED)}),
    ('ko', 'K.O.', {'cols': (YELLOW, YELLOW, RED, RED, RED)}),
    ('time', 'TIME OVER', {}),
    ('draw', 'DRAW GAME', {}),
    ('perfect', 'PERFECT', {'cols': (WHITE, WHITE, CYAN, CYAN, BLUE)}),
    ('youwin', 'YOU WIN', {'cols': (WHITE, YELLOW, YELLOW, GREEN, GREEN)}),
    ('youlose', 'YOU LOSE', {'cols': (WHITE, CYAN, CYAN, BLUE, BLUE)}),
    ('p1win', '1P WINS', {}),
    ('p2win', '2P WINS', {}),
    ('logo1', 'WORLD', {}),
    ('logo2', 'CLASH', {}),
    ('world', 'WARRIORS', {}),
    ('vs', 'VS', {}),
    ('cont', 'CONTINUE', {}),
    ('champ', 'CHAMPION', {}),
    ('best', 'HI SCORES', {}),
]

if __name__ == '__main__':
    print('\n'.join(generate())[:2000])


def preview(out):
    import mzfont as F
    blocks = []
    for kind in ('hit', 'blk'):
        for ph in range(2):
            blocks.append(spark(kind, ph))
    for st in PROJ_STYLES:
        for ph in range(2):
            blocks.append(projectile(st, ph, 0))
    for name, s, kw in BANNERS[:3]:
        blocks.append(banner(s, **kw))
    grid_c = [0] * 1000
    grid_a = [0x01] * 1000
    x, y, rh = 0, 0, 0
    for w, h, cl in blocks:
        if x + w > 40:
            x, y = 0, y + rh + 1
            rh = 0
        for r in range(h):
            for c in range(w):
                ch, at = cl[r * w + c]
                if at == 8 and ch == 0:
                    continue
                o = (y + r) * 40 + x + c
                if o >= 1000:
                    continue
                if at & 8:
                    at = (at & 0xF0) | (grid_a[o] & 7)
                grid_c[o] = ch
                grid_a[o] = at
        x += w + 1
        rh = max(rh, h)
    for i in range(10):
        for k, (ch, at) in enumerate(big_digit(i)):
            o = (23 + k // 2) * 40 + i * 3 + k % 2
            grid_c[o], grid_a[o] = ch, at
    F.render_cells(grid_c, grid_a, scale=2).save(out)


SCHEMES = [(WHITE, YELLOW, YELLOW, RED, RED), (WHITE, WHITE, YELLOW, YELLOW, RED), (YELLOW, YELLOW, RED, RED, RED),
           (WHITE, WHITE, CYAN, CYAN, BLUE), (WHITE, YELLOW, YELLOW, GREEN, GREEN), (WHITE, CYAN, CYAN, BLUE, BLUE),
           (YELLOW, YELLOW, WHITE, WHITE, YELLOW)]


def banner_asm():
    """banners as text: db scheme, "TEXT", 0;  the 5x5 font as 5 bytes per
    character (bit 7 = leftmost, width in the low 3 bits of byte 0's spare)"""
    import font5
    out = []
    sch = {'fight': 1, 'ko': 2, 'perfect': 3, 'youwin': 4, 'youlose': 5, 'logo1': 6, 'logo2': 2, 'vs': 2,
           'world': 1, 'cont': 5, 'champ': 6, 'best': 4}
    for name, s, kw in BANNERS:
        out.append('bn_%s: db %d,"%s",0' % (name, sch.get(name, 0), s))
    out.append('bn_schemes:')
    for sc in SCHEMES:
        out.append('        db ' + ','.join(str(c << 4) for c in sc))
    chars = sorted(font5.F)
    out.append('font5_tab:              ; ASCII 20h-5Fh -> 5 rows (bits 7.. = pixels), width')
    rows = []
    for code in range(0x20, 0x60):
        ch = chr(code)
        g = font5.F.get(ch)
        if g is None:
            rows.append([0, 0, 0, 0, 0, 0])
            continue
        w = len(g[0])
        bb = []
        for r in range(5):
            v = 0
            for x, p in enumerate(g[r]):
                if p == '#':
                    v |= 0x80 >> x
            bb.append(v)
        rows.append(bb + [w])
    for i, bb in enumerate(rows):
        out.append('        db ' + ','.join(str(v) for v in bb))
    return out
