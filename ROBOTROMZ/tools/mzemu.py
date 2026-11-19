# MZ-700 (PAL) test machine.
#  - Z80 at 3.546895 MHz, 312 lines of 227.2 T (1136 master clocks / 5)
#  - visible lines 0..199, /VBLK (E002h bit 7) low on lines 200..311
#  - VRAM (D000h-DFFFh) accesses only complete inside a per-line access
#    window; outside it the CPU is held in WAIT (on every line, VBLANK too).
#    Default window T 128..191 (63 T, conservative: Takeda's PAL model uses
#    128..208, real NTSC hardware measured 63 T).
#  - keyboard matrix via 8255 (E000h row select, E001h columns active low)
import os
from z80 import Z80
from mzfont import render_cells

LINE_MC = 1136                  # master clocks per line
FRAME_LINES = 312
FRAME_MC = LINE_MC * FRAME_LINES
VIS_LINES = 200

KEYS = {'left': (7, 2), 'right': (7, 3), 'down': (7, 4), 'up': (7, 5),
        'space': (6, 4), 'y': (1, 7), 'z': (1, 6), 'del': (7, 6),
        'cr': (0, 0), 'break': (8, 7), 'shift': (8, 0)}
for _row, _letters in ((2, 'qrstuvwx'), (3, 'ijklmnop'), (4, 'abcdefgh')):
    for _i, _ch in enumerate(_letters):
        KEYS[_ch] = (_row, 7 - _i)


class MZ:
    def __init__(s, mzt, win=(128, 191), inv_vblk=False):
        s.inv_vblk = inv_vblk
        d = open(mzt, 'rb').read()
        size = d[18] | d[19] << 8
        load = d[20] | d[21] << 8
        exe = d[22] | d[23] << 8
        s.mem = bytearray(65536)
        s.mem[load:load + size] = d[128:128 + size]
        s.win0, s.win1 = win
        s.row = 0
        s.held = set()
        s.pend = 0
        s.waits = 0
        s.vram_writes = []      # (t, addr) log when enabled
        s.log_writes = False
        s.cpu = Z80(s.rd, s.wr, lambda p: 0xFF, s.outp)
        s.cpu.pc = exe
        s.cpu.t = 3000          # arbitrary phase

    # ------------------------------------------------ timing helpers
    def now(s):
        return s.cpu.t + s.pend

    def line_pos(s, t):
        mc = (t * 5) % FRAME_MC
        return mc // LINE_MC, (mc % LINE_MC) / 5.0

    def vram_wait(s):
        t = s.now() + 5
        _, x = s.line_pos(t)
        if s.win0 <= x < s.win1:
            return
        if x < s.win0:
            w = s.win0 - x
        else:
            w = LINE_MC / 5.0 - x + s.win0
        w = int(w + 0.999)
        s.pend += w
        s.waits += w

    # ------------------------------------------------ bus
    def rd(s, a):
        if a >= 0xD000:
            if a < 0xE000:
                s.vram_wait()
                return s.mem[a]
            if a < 0xE010:
                return s.io_rd(a)
        return s.mem[a]

    def wr(s, a, v):
        if a >= 0xD000:
            if a < 0xE000:
                s.vram_wait()
                if s.log_writes:
                    s.vram_writes.append((s.now(), a))
                s.mem[a] = v
                return
            if a < 0xE010:
                if a == 0xE000:
                    s.row = v & 0x0F
                return
        s.mem[a] = v

    def outp(s, p, v):
        pass

    def io_rd(s, a):
        line, x = s.line_pos(s.now() + 4)
        if a == 0xE001:
            v = 0xFF
            for k in s.held:
                r, b = KEYS[k]
                if r == s.row:
                    v &= ~(1 << b)
            return v
        if a == 0xE002:
            v = (0x80 if line < VIS_LINES else 0) | 0x50
            return v ^ 0x80 if s.inv_vblk else v
        if a == 0xE008:
            hb = x >= 128
            return (0 if hb else 0x80) | 0x7E
        return 0xFF

    # ------------------------------------------------ running
    def step(s):
        s.pend = 0
        s.cpu.step()
        s.cpu.t += s.pend

    def run_until_pc(s, pc, max_t=10 ** 8):
        c = s.cpu
        end = c.t + max_t
        while c.pc != pc:
            s.pend = 0
            c.step()
            c.t += s.pend
            if c.t > end:
                raise RuntimeError('timeout waiting for PC %04X (at %04X)' % (pc, c.pc))

    def screen(s, scale=2):
        return render_cells(list(s.mem[0xD000:0xD3E8]), list(s.mem[0xD800:0xDBE8]), scale=scale)


def load_syms(path):
    syms = {}
    for ln in open(path):
        if ': EQU ' in ln:
            name, v = ln.split(': EQU ')
            syms[name.strip()] = int(v.strip(), 16)
    return syms

