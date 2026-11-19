"""run.py - run KIKO in the MZ-700 simulator with scripted keys.

    py tools/run.py FIELDS [shot_field,...] [--keys "field:key+key,field:-,..."]
                    [--vram] [--prefix name]

Screenshots go to build/shots/<prefix>_NNNN.png.  Stops if the PC leaves
the program or the stack runs wild.  --vram turns on the conservative
VRAM wait model (every access waits for the 63-T window of a line).
"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from mzsim import MZ700, FIELD_T  # noqa: E402


def load_syms():
    syms = {}
    for ln in open(os.path.join(ROOT, 'build', 'kiko.sym')):
        if ': EQU ' in ln:
            k, v = ln.split(': EQU ')
            syms[k.strip()] = int(v.strip(), 16)
    return syms


S = load_syms()


class Game:
    def __init__(self, vram=False):
        self.m = MZ700(os.path.join(ROOT, 'rom', 'mz700fon.int'))
        self.m.load_mzf(os.path.join(ROOT, 'build', 'KIKO.MZT'))
        if vram:
            self.m.vram_wait = 'all'
        self.end = S['end_of_program']
        self.shots = os.path.join(ROOT, 'build', 'shots')
        os.makedirs(self.shots, exist_ok=True)
        self.fields = 0

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
                raise RuntimeError('PC escaped to %04X (SP %04X) at field %d' % (c.pc, c.sp, self.fields))
        if not (0xB800 < c.sp <= 0xC000):
            raise RuntimeError('stack pointer %04X' % c.sp)
        self.fields += fields

    def shot(self, name):
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

    def hero(self):
        sv = lambda v: v - 256 if v > 127 else v  # noqa: E731
        vy = self.rw('hvy')
        vy = vy - 65536 if vy > 32767 else vy
        return dict(x=self.rb('kx'), y=self.rb('ky'), vx=sv(self.rb('hvx')), vy=vy,
                    gnd=self.rb('hgnd'), st=self.rb('hstate'), room=self.rb('room'),
                    hearts=self.rb('hearts'), lives=self.rb('lives'), gems=self.rb('gems'))


def parse_keys(spec):
    ev = []
    for item in spec.split(','):
        f, k = item.split(':')
        ev.append((int(f), [] if k == '-' else k.split('+')))
    return sorted(ev)


if __name__ == '__main__':
    args = sys.argv[1:]
    vram = '--vram' in args
    if vram:
        args.remove('--vram')
    prefix = 'run'
    if '--prefix' in args:
        i = args.index('--prefix')
        prefix = args[i + 1]
        args = args[:i] + args[i + 2:]
    keys = []
    if '--keys' in args:
        i = args.index('--keys')
        keys = parse_keys(args[i + 1])
        args = args[:i] + args[i + 2:]
    fields = int(args[0])
    shots = {int(x) for x in args[1].split(',') if x} if len(args) > 1 else set()
    g = Game(vram)
    t0 = time.time()
    held = []
    for f in range(fields):
        for kf, k in keys:
            if kf == f:
                held = k
        g.run(1, held)
        if f in shots:
            print('shot', g.shot('%s_%04d' % (prefix, f)), g.hero())
    print('%d fields in %.1fs, drops %d' % (fields, time.time() - t0, g.rb('drops')))
    print(g.screen_text())
