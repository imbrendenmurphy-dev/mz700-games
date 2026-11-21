"""run.py - run ZENITH in the MZ-700 simulator.

    py tools/run.py FIELDS [shot_field,...] [--keys "field:key+key,field:-,..."]

As a library: Game() loads build/ZENITH.MZT and the symbol table;
Game.call('label') runs one subroutine to its return (unit tests);
Game.run(fields, keys) runs the whole machine.  Screenshots go to
build/shots/.
"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import mzsim  # noqa: E402
from mzsim import MZ700, FIELD_T  # noqa: E402

mzsim.KEYS.update({'t': (2, 4), 'u': (2, 3), 'v': (2, 2), 'w': (2, 1), 'g': (4, 1),
                   'i': (3, 7), 'k': (3, 5), 'x': (2, 0), 'q': (2, 7), 'y': (1, 7)})


def load_syms():
    syms = {}
    for ln in open(os.path.join(ROOT, 'build', 'zenith.sym')):
        if ': EQU ' in ln:
            k, v = ln.split(': EQU ')
            syms[k.strip()] = int(v.strip(), 16)
    return syms


S = load_syms()
SENTINEL = 0x1100                   # a 'halt' return address for call()


class Game:
    def __init__(self, vram_wait=None):
        self.m = MZ700(os.path.join(ROOT, 'rom', 'mz700fon.int'))
        self.m.vram_wait = vram_wait
        self.m.load_mzf(os.path.join(ROOT, 'build', 'ZENITH.MZT'))
        self.end = S['end_of_program']
        self.shots = os.path.join(ROOT, 'build', 'shots')
        os.makedirs(self.shots, exist_ok=True)
        self.hooks = {}

    # ------------------------------------------------------------ running
    def run(self, fields, keys=()):
        m = self.m
        m.held = set(keys)
        c = m.cpu
        end = c.t + int(fields * FIELD_T)
        lo, hi = 0x1200, self.end
        step = c.step
        hooks = self.hooks
        while c.t < end:
            if hooks and c.pc in hooks:
                hooks[c.pc](self)
            step()
            if not (lo <= c.pc < hi):
                raise RuntimeError('PC escaped to %04X (SP %04X)' % (c.pc, c.sp))
        if not (0xCD00 < c.sp <= 0xCFF0):
            raise RuntimeError('stack pointer %04X' % c.sp)

    def boot(self, fields=2):
        """run the start-up code until the front end is waiting"""
        self.run(fields)

    def call(self, label, max_t=400_000_000, **regs):
        c = self.m.cpu
        c.sp = 0xCFF0
        c.sp -= 2
        self.m.mem[c.sp] = SENTINEL & 255
        self.m.mem[c.sp + 1] = SENTINEL >> 8
        c.pc = S[label] if isinstance(label, str) else label
        for k, v in regs.items():
            setattr(c, k, v)
        t0 = c.t
        step = c.step
        while c.pc != SENTINEL:
            step()
            if c.t - t0 > max_t:
                raise RuntimeError('%s did not return (PC %04X)' % (label, c.pc))
            if not (0x1200 <= c.pc < self.end) and c.pc != SENTINEL:
                raise RuntimeError('PC escaped to %04X in %s' % (c.pc, label))
        return c.t - t0

    # ------------------------------------------------------------ memory
    def rb(self, name, off=0):
        return self.m.mem[(S[name] if isinstance(name, str) else name) + off]

    def rw(self, name, off=0):
        a = (S[name] if isinstance(name, str) else name) + off
        return self.m.mem[a] | (self.m.mem[a + 1] << 8)

    def wb(self, name, v, off=0):
        self.m.mem[(S[name] if isinstance(name, str) else name) + off] = v & 0xFF

    def ww(self, name, v, off=0):
        a = (S[name] if isinstance(name, str) else name) + off
        self.m.mem[a] = v & 255
        self.m.mem[a + 1] = (v >> 8) & 255

    def shot(self, name):
        p = os.path.join(self.shots, name + '.png')
        self.m.screenshot(p)
        return p

    def text(self, row):
        out = ''
        for c in range(40):
            ch = self.m.mem[0xD000 + row * 40 + c]
            if 1 <= ch <= 26:
                out += chr(64 + ch)
            elif 0x81 <= ch <= 0x9A:
                out += chr(96 + ch - 0x80)
            elif 0x20 <= ch <= 0x29:
                out += chr(48 + ch - 0x20)
            elif ch == 0:
                out += ' '
            else:
                out += '.'
        return out

    def screen_text(self):
        return '\n'.join('%2d|%s|' % (r, self.text(r)) for r in range(25))


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
