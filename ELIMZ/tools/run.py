"""run.py - run STARHAUL in the MZ-700 simulator with scripted keys.

    py tools/run.py FIELDS [shot_field,...] [--keys "field:key+key,field:-,..."]

Screenshots go to build/shots/run_NNNN.png.  Stops if the PC leaves the
program or the stack runs wild.
"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from mzsim import MZ700, FIELD_T  # noqa: E402


def load_syms():
    syms = {}
    for ln in open(os.path.join(ROOT, 'build', 'starhaul.sym')):
        if ': EQU ' in ln:
            k, v = ln.split(': EQU ')
            syms[k.strip()] = int(v.strip(), 16)
    return syms


S = load_syms()


class Game:
    def __init__(self, vram_wait=None):
        self.m = MZ700(os.path.join(ROOT, 'rom', 'mz700fon.int'))
        self.m.vram_wait = vram_wait
        self.m.load_mzf(os.path.join(ROOT, 'build', 'STARHAUL.MZT'))
        self.end = S['end_of_program']
        self.shots = os.path.join(ROOT, 'build', 'shots')
        os.makedirs(self.shots, exist_ok=True)

    def run(self, fields, keys=()):
        m = self.m
        m.held = set(keys)
        c = m.cpu
        end = c.t + int(fields * FIELD_T)
        lo, hi = 0x1200, self.end
        step = c.step
        while c.t < end:
            step()
            if not (lo <= c.pc < hi):
                if c.pc in (0x21, 0x24, 0x27, 0x2A):
                    self.tape_call(c.pc)
                    continue
                raise RuntimeError('PC escaped to %04X (SP %04X)' % (c.pc, c.sp))
        if not (0xCD00 < c.sp <= 0xCFF0):
            raise RuntimeError('stack pointer %04X' % c.sp)

    tape_hdr = None
    tape_data = None

    def tape_call(self, pc):
        """stand-in for the monitor ROM tape routines (the simulator has no ROM)"""
        m = self.m.mem
        c = self.m.cpu
        size = m[0x1102] | m[0x1103] << 8
        addr = m[0x1104] | m[0x1105] << 8
        ok = True
        if pc == 0x21:
            self.tape_hdr = bytes(m[0x10F0:0x1170])
        elif pc == 0x24:
            self.tape_data = bytes(m[addr:addr + size])
        elif pc == 0x27:
            ok = self.tape_hdr is not None
            if ok:
                m[0x10F0:0x1170] = self.tape_hdr
        elif pc == 0x2A:
            ok = self.tape_data is not None
            if ok:
                m[addr:addr + len(self.tape_data)] = self.tape_data
        c.f = (c.f & ~1) | (0 if ok else 1)
        c.pc = m[c.sp] | m[c.sp + 1] << 8
        c.sp += 2
        c.t += 70886 * 50

    def sync(self, max_fields=10):
        """run on until the next present() has finished (a clean frame)"""
        c = self.m.cpu
        end = c.t + int(max_fields * FIELD_T)
        while c.pc != S['present'] and c.t < end:
            c.step()
        sp = c.sp
        while c.sp <= sp and c.t < end:
            c.step()

    def shot(self, name, sync=True):
        if sync:
            self.sync()
        p = os.path.join(self.shots, name + '.png')
        self.m.screenshot(p)
        return p

    def rb(self, name, off=0):
        return self.m.mem[S[name] + off]

    def rw(self, name):
        return self.m.mem[S[name]] | (self.m.mem[S[name] + 1] << 8)

    def wb(self, name, v, off=0):
        self.m.mem[S[name] + off] = v & 0xFF

    def text(self, row):
        """screen row as rough ASCII"""
        out = ''
        for c in range(40):
            ch = self.m.mem[0xD000 + row * 40 + c]
            if 1 <= ch <= 26:
                out += chr(64 + ch)
            elif 0x20 <= ch <= 0x29:
                out += chr(48 + ch - 0x20)
            elif ch == 0:
                out += ' '
            else:
                out += '.'
        return out

    def screen_text(self):
        return '\n'.join('%2d|%s|' % (r, self.text(r)) for r in range(25))

    def region(self, r=None):
        """the region as element codes, 24 rows of 32"""
        if r is None:
            r = self.rb('region')
        base = S['WORLD'] + r * 768
        return [[self.m.mem[base + y * 32 + x] & 0x3F for x in range(32)] for y in range(24)]


def parse_keys(spec):
    ev = []
    for item in spec.split(','):
        f, k = item.split(':')
        ev.append((int(f), [] if k == '-' else k.split('+')))
    return sorted(ev)


if __name__ == '__main__':
    fields = int(sys.argv[1])
    shots = set()
    keys = []
    args = sys.argv[2:]
    if '--keys' in args:
        i = args.index('--keys')
        keys = parse_keys(args[i + 1])
        args = args[:i] + args[i + 2:]
    if args:
        shots = {int(x) for x in args[0].split(',') if x}
    g = Game()
    t0 = time.time()
    held = []
    for f in range(fields):
        for kf, k in keys:
            if kf == f:
                held = k
        g.run(1, held)
        if f in shots:
            print('shot', g.shot('run_%04d' % f))
    print('%d fields in %.1fs' % (fields, time.time() - t0))
    print(g.screen_text())
