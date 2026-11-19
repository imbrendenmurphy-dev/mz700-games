"""gen_data.py - generates tables, the test maze and unrolled code for Rotoball.

Writes build/gen_*.inc, which src/rotoball.asm includes.
"""
import math
import os
import random

VIEW_CHARS = 25          # view is 25x25 characters = 50x50 blocks
VIEW_X = 1               # screen column of the view's left edge
CHARBUF = 0xC000         # back buffer, 32-byte row stride
MAP_PAGE = 0x60          # map row R lives at page MAP_PAGE+R, column = low byte
MAP_ROWS = 96
MAZE_ROW0 = 20           # playable area inside the solid map
MAZE_COL0 = 40
MAZE_W = 64
MAZE_H = 56
CELL = 4                 # maze corridor pitch: 3 open + 1 wall


def page_table(name, vals):
    out = ['    align 256', name + ':']
    for i in range(0, len(vals), 16):
        out.append('    db ' + ','.join('%d' % (v & 0xFF) for v in vals[i:i + 16]))
    return '\n'.join(out)


def gen_tables():
    sinv = [round(128 * math.sin(2 * math.pi * a / 256)) for a in range(256)]
    t = [page_table('SINL', [v & 0xFF for v in sinv]),
         page_table('SINH', [(v >> 8) & 0xFF for v in sinv])]
    # colour strip: rainbow foreground on black, period 8, long enough for 25+8
    seq = [1, 3, 2, 6, 4, 5, 7, 5]
    strip = [(seq[i % 8] << 4) for i in range(48)]
    t.append(page_table('STRIP', strip))
    return '\n\n'.join(t) + '\n'


def gen_maze():
    rnd = random.Random(700)
    cw, ch = MAZE_W // CELL, MAZE_H // CELL
    wall = [[1] * MAZE_W for _ in range(MAZE_H)]
    seen = [[False] * cw for _ in range(ch)]

    def carve_cell(cx, cy):
        for y in range(cy * CELL + 1, cy * CELL + CELL):
            for x in range(cx * CELL + 1, cx * CELL + CELL):
                wall[y][x] = 0

    def carve_between(ax, ay, bx, by):
        if ax == bx:   # vertical neighbours: open the wall row between them
            y = max(ay, by) * CELL
            for x in range(ax * CELL + 1, ax * CELL + CELL):
                wall[y][x] = 0
        else:
            x = max(ax, bx) * CELL
            for y in range(ay * CELL + 1, ay * CELL + CELL):
                wall[y][x] = 0

    stack = [(0, 0)]
    seen[0][0] = True
    carve_cell(0, 0)
    while stack:
        x, y = stack[-1]
        nb = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
              if 0 <= x + dx < cw and 0 <= y + dy < ch and not seen[y + dy][x + dx]]
        if not nb:
            stack.pop()
            continue
        nx, ny = rnd.choice(nb)
        seen[ny][nx] = True
        carve_cell(nx, ny)
        carve_between(x, y, nx, ny)
        stack.append((nx, ny))
    # knock out extra walls for loops and a couple of open caverns
    for _ in range(40):
        x, y = rnd.randrange(cw - 1), rnd.randrange(ch)
        carve_between(x, y, x + 1, y)
    for cx, cy, w, h in ((5, 5, 3, 2), (10, 9, 2, 3)):
        for y in range(cy * CELL + 1, (cy + h) * CELL):
            for x in range(cx * CELL + 1, (cx + w) * CELL):
                wall[y][x] = 0
    # pack: 8 bytes per row, MSB = leftmost column, 1 = wall
    data = []
    for row in wall:
        for b in range(0, MAZE_W, 8):
            v = 0
            for i in range(8):
                v = (v << 1) | row[b + i]
            data.append(v)
    lines = ['MAZEBITS:']
    for i in range(0, len(data), 16):
        lines.append('    db ' + ','.join('%d' % v for v in data[i:i + 16]))
    # ball starts in the middle of maze cell (1,0)
    sx = MAZE_COL0 + CELL + 2
    sy = MAZE_ROW0 + 2
    return '\n'.join(lines) + '\n', sx, sy, wall


# One map sample: SP walks a per-frame list of pointer deltas, HL is the map
# pointer (H = row page, L = column), the wall bit (bit 7) is shifted into C.
SAMPLE = ['    pop de', '    add hl,de', '    ld a,(hl)', '    rla', '    rl c']


def gen_pass(lower):
    """Rows are drawn right to left: lower row gives BR,BL then upper gives TR,TL,
    so C ends as bit0=TL bit1=TR bit2=BL bit3=BR - the F0h-FFh block code.
    The output pointer lives in the shadow HL."""
    out = ['; unrolled render pass (%s block row), %d chars' % ('lower' if lower else 'upper', VIEW_CHARS)]
    for _ in range(VIEW_CHARS):
        if lower:
            out += SAMPLE + SAMPLE + ['    ld a,c', '    exx', '    ld (hl),a', '    dec l', '    exx']
        else:
            out += ['    exx', '    ld a,(hl)', '    exx', '    ld c,a'] + SAMPLE + SAMPLE + \
                   ['    ld a,c', '    or 0F0h', '    exx', '    ld (hl),a', '    dec l', '    exx']
    return '\n'.join(out) + '\n'


def gen_rowsetup(lower):
    """Round the row's start point to the nearest half cell, pick the delta list
    for that half-cell phase, and load SP (list), HL (map pointer), HL' (output)."""
    out = ['    ld hl,(RTx)']
    if lower:
        out += ['    ld de,(Vx)', '    add hl,de']
    out += ['    ld de,64', '    add hl,de', '    ld a,l', '    and 80h', '    rlca', '    ld c,a', '    ld b,h',
            '    ld hl,(RTy)']
    if lower:
        out += ['    ld de,(Vy)', '    add hl,de']
    out += ['    ld de,64', '    add hl,de', '    ld a,l', '    and 80h', '    rlca', '    rlca', '    or c',
            '    ld c,h', '    add a,a', '    add a,lo(LISTPTR)', '    ld l,a', '    ld h,hi(LISTPTR)', '    ld a,(hl)', '    inc l',
            '    ld h,(hl)', '    ld l,a', '    ld sp,hl', '    ld h,c', '    ld l,b',
            '    exx', '    ld hl,(outptr)', '    exx']
    return '\n'.join(out) + '\n'


def gen_listentry():
    """Delta list builder body, repeated 49 times. Walks from sample 49 back to
    sample 0 adding U; pushes d = floor(old) - floor(new) so pops come out in order.
    main HL = u, BC = Ux; shadow HL' = v, BC' = Uy."""
    one = ['    ld d,h', '    add hl,bc', '    ld a,d', '    sub h', '    ld e,a', '    rla', '    sbc a,a',
           '    exx', '    ld d,h', '    add hl,bc', '    add a,d', '    sub h', '    exx', '    ld d,a',
           '    push de']
    return '\n'.join(one * 49) + '\n'


def gen_blit():
    out = ['; copy back buffer to VRAM (chars only)']
    for r in range(VIEW_CHARS):
        out.append('    ld hl,0%04Xh' % (CHARBUF + r * 32))
        out.append('    ld de,0%04Xh' % (0xD000 + r * 40 + VIEW_X))
        out += ['    ldi'] * VIEW_CHARS
    return '\n'.join(out) + '\n'


def gen_colours():
    # (cphase) = 0-7. Each row copies 25 rainbow attributes from STRIP+((row+phase)&7),
    # then paints both border columns with the next strip entry.
    out = ['; colour-cycle the view and its border']
    for r in range(VIEW_CHARS):
        out += ['    ld a,(cphase)', '    add a,%d' % (r & 7), '    and 7', '    ld l,a', '    ld h,hi(STRIP)',
                '    ld de,0%04Xh' % (0xD800 + r * 40 + VIEW_X)]
        out += ['    ldi'] * VIEW_CHARS
        out += ['    ld a,(hl)', '    ld (de),a', '    ld (0%04Xh),a' % (0xD800 + r * 40)]
    return '\n'.join(out) + '\n'


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bdir = os.path.join(root, 'build')
    os.makedirs(bdir, exist_ok=True)
    maze, sx, sy, _ = gen_maze()
    const = '\n'.join([
        'VIEW_CHARS = %d' % VIEW_CHARS,
        'VIEW_X = %d' % VIEW_X,
        'CHARBUF = 0%04Xh' % CHARBUF,
        'MAP_PAGE = 0%02Xh' % MAP_PAGE,
        'MAP_ROWS = %d' % MAP_ROWS,
        'MAZE_ROW0 = %d' % MAZE_ROW0,
        'MAZE_COL0 = %d' % MAZE_COL0,
        'MAZE_W = %d' % MAZE_W,
        'MAZE_H = %d' % MAZE_H,
        'START_X = %d' % sx,
        'START_Y = %d' % sy,
    ]) + '\n'
    files = {
        'gen_const.inc': const,
        'gen_tables.inc': gen_tables(),
        'gen_maze.inc': maze,
        'gen_pass_lower.inc': gen_pass(True),
        'gen_pass_upper.inc': gen_pass(False),
        'gen_row_lower.inc': gen_rowsetup(True),
        'gen_row_upper.inc': gen_rowsetup(False),
        'gen_listentry.inc': gen_listentry(),
        'gen_blit.inc': gen_blit(),
        'gen_colours.inc': gen_colours(),
    }
    for name, text in files.items():
        with open(os.path.join(bdir, name), 'w', newline='\n') as f:
            f.write(text)


if __name__ == '__main__':
    main()
