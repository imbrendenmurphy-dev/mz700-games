"""gen_data.py - generates tables, levels, sounds and unrolled code for Rotoball.

Writes build/gen_*.inc, which the sources in src/ include.
"""
import math
import os

import levels
import sfx

VIEW_CHARS = 23          # view is 23x23 characters = 46x46 blocks
VIEW_X = 1               # screen column / row of the view's top-left corner
VIEW_Y = 1
VIEW_C = VIEW_CHARS // 2 # centre character (the ball)
SAMPLES = 2 * VIEW_CHARS # blocks per row
CHARBUF = 0xC000         # back buffer, 32-byte row stride
MAP_PAGE = 0x60          # map row R lives at page MAP_PAGE+R, column = low byte
MAP_ROWS = 96
MAZE_ROW0 = 20           # where levels are placed inside the solid map
MAZE_COL0 = 40

# rainbow used for the view's wall colours (foreground, black background)
RAINBOW = [1, 3, 2, 6, 4, 5, 7, 5]


def page_table(name, vals):
    out = ['    align 256', name + ':']
    for i in range(0, len(vals), 16):
        out.append('    db ' + ','.join('%d' % (v & 0xFF) for v in vals[i:i + 16]))
    return '\n'.join(out)


def gen_tables():
    sinv = [round(128 * math.sin(2 * math.pi * a / 256)) for a in range(256)]
    sin8 = [round(127 * math.sin(2 * math.pi * a / 256)) for a in range(256)]
    sq = [n * n // 4 for n in range(256)]
    t = [page_table('SINL', [v & 0xFF for v in sinv]),
         page_table('SINH', [(v >> 8) & 0xFF for v in sinv]),
         page_table('SIN8', [v & 0xFF for v in sin8]),
         page_table('SQL', [v & 0xFF for v in sq]),
         page_table('SQH', [v >> 8 for v in sq]),
         page_table('STRIP', [(RAINBOW[i % 8] << 4) for i in range(48)]),
         # frame marquee: 128 rainbow entries, then 128 white (bomb / death flash)
         page_table('STRIP2', [(RAINBOW[i % 8] << 4) for i in range(128)] + [0x70] * 128)]
    t.append('ROW40:\n    dw ' + ','.join(str(r * 40) for r in range(25)))
    t.append('ROW32:\n    dw ' + ','.join(str(r * 32) for r in range(25)))
    return '\n\n'.join(t) + '\n'


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
    """Round the row's start point to the nearest half cell (RT already has the
    +1/4 cell rounding offset added), pick the delta list for that half-cell
    phase, and load SP (list), HL (map pointer), HL' (output)."""
    out = ['    ld hl,(RTx)']
    if lower:
        out += ['    ld de,(Vx)', '    add hl,de']
    out += ['    ld a,l', '    and 80h', '    rlca', '    ld c,a', '    ld b,h',
            '    ld hl,(RTy)']
    if lower:
        out += ['    ld de,(Vy)', '    add hl,de']
    out += ['    ld a,l', '    and 80h', '    rlca', '    rlca', '    or c',
            '    ld c,h', '    add a,a', '    add a,lo(LISTPTR)', '    ld l,a', '    ld h,hi(LISTPTR)',
            '    ld a,(hl)', '    inc l', '    ld h,(hl)', '    ld l,a', '    ld sp,hl', '    ld h,c', '    ld l,b',
            '    exx', '    ld hl,(outptr)', '    exx']
    return '\n'.join(out) + '\n'


def gen_listentry():
    """Delta list builder body, repeated SAMPLES-1 times. Walks from the last
    sample back to sample 0 adding U; pushes d = floor(old) - floor(new) so
    pops come out in order. main HL = u, BC = Ux; shadow HL' = v, BC' = Uy."""
    one = ['    ld d,h', '    add hl,bc', '    ld a,d', '    sub h', '    ld e,a', '    rla', '    sbc a,a',
           '    exx', '    ld d,h', '    add hl,bc', '    add a,d', '    sub h', '    exx', '    ld d,a',
           '    push de']
    return '\n'.join(one * (SAMPLES - 1)) + '\n'


def gen_blit():
    out = ['; copy back buffer to VRAM (chars only)']
    for r in range(VIEW_CHARS):
        out.append('    ld hl,0%04Xh' % (CHARBUF + r * 32))
        out.append('    ld de,0%04Xh' % (0xD000 + (r + VIEW_Y) * 40 + VIEW_X))
        out += ['    ldi'] * VIEW_CHARS
    return '\n'.join(out) + '\n'


def gen_border():
    """Marquee round the view frame: walk the perimeter clockwise taking
    successive STRIP2 entries. Expects HL -> STRIP2 + phase (or the white half)."""
    left, top = VIEW_X - 1, VIEW_Y - 1
    right, bottom = VIEW_X + VIEW_CHARS, VIEW_Y + VIEW_CHARS
    out = ['; frame marquee', '    ld de,0%04Xh' % (0xD800 + top * 40 + left)]
    out += ['    ldi'] * (right - left + 1)
    cells = [(right, y) for y in range(top + 1, bottom)] + \
            [(x, bottom) for x in range(right, left - 1, -1)] + \
            [(left, y) for y in range(bottom - 1, top, -1)]
    for x, y in cells:
        out += ['    ld a,(hl)', '    inc l', '    ld (0%04Xh),a' % (0xD800 + y * 40 + x)]
    return '\n'.join(out) + '\n'


def gen_colours():
    """Four routines, colgrp0-3; group k recolours view rows k, k+4, k+8...
    Row r copies 25 attributes from STRIP+((r+cphase)&7): diagonal rainbow."""
    out = ['; colour-cycle a quarter of the view rows']
    for k in range(4):
        out.append('colgrp%d:' % k)
        for r in range(k, VIEW_CHARS, 4):
            out += ['    ld a,(cphase)', '    add a,%d' % (r & 7), '    and 7', '    ld l,a',
                    '    ld h,hi(STRIP)', '    ld de,0%04Xh' % (0xD800 + (r + VIEW_Y) * 40 + VIEW_X)]
            out += ['    ldi'] * VIEW_CHARS
        out.append('    ret')
    return '\n'.join(out) + '\n'


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bdir = os.path.join(root, 'build')
    os.makedirs(bdir, exist_ok=True)
    lvl, _ = levels.asm()
    const = '\n'.join([
        'VIEW_CHARS = %d' % VIEW_CHARS,
        'VIEW_X = %d' % VIEW_X,
        'VIEW_Y = %d' % VIEW_Y,
        'VIEW_C = %d' % VIEW_C,
        'LIST_BYTES = %d' % (2 * SAMPLES),
        'CHARBUF = 0%04Xh' % CHARBUF,
        'MAP_PAGE = 0%02Xh' % MAP_PAGE,
        'MAP_ROWS = %d' % MAP_ROWS,
        'MAZE_ROW0 = %d' % MAZE_ROW0,
        'MAZE_COL0 = %d' % MAZE_COL0,
    ]) + '\n'
    files = {
        'gen_const.inc': const,
        'gen_tables.inc': gen_tables(),
        'gen_levels.inc': lvl,
        'gen_sfx.inc': sfx.asm(),
        'gen_pass_lower.inc': gen_pass(True),
        'gen_pass_upper.inc': gen_pass(False),
        'gen_row_lower.inc': gen_rowsetup(True),
        'gen_row_upper.inc': gen_rowsetup(False),
        'gen_listentry.inc': gen_listentry(),
        'gen_blit.inc': gen_blit(),
        'gen_colours.inc': gen_colours(),
        'gen_border.inc': gen_border(),
    }
    for name, text in files.items():
        with open(os.path.join(bdir, name), 'w', newline='\n') as f:
            f.write(text)


if __name__ == '__main__':
    main()
