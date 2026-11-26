"""harness.py - drive LUMEN in mzemu for tests.

    from harness import Game
    g = Game(seed=0x1234)          # boots, starts a game on a fixed dungeon
    g.warp(3)                      # to zone 3
    g.place(10, 5)                 # move the player (a wait turn refreshes)
    g.keys('RIGHT', 'RIGHT')       # taps, each followed by a few frames
    ram = g.run('shot.png')        # runs everything so far; RAM dump back

Each run replays the whole script from power-on (mzemu is fast), so a
test builds its script step by step and calls run() when it wants to look.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TEST = os.path.join(ROOT, 'test')
EMU = os.path.join(ROOT, '..', 'MZ700onPC', 'mzemu.exe')
sys.path.insert(0, HERE)
import mapdump  # noqa: E402


def syms():
    return mapdump.syms(os.path.join(ROOT, 'build', 'lumen.sym'))


class Game:
    def __init__(self, seed=0x1234, settle=420):
        self.s = syms()
        self.lines = ['sym ../build/lumen.sym', 'crash', 'mzt ../build/LUMEN.MZT', 'frames 60',
                      'poke dbg_seed %d' % (seed & 255), 'poke %d %d' % (self.s['dbg_seed'] + 1, seed >> 8),
                      'tap SPACE', 'frames %d' % settle]

    def add(self, *lines):
        self.lines += list(lines)

    def frames(self, n):
        self.lines.append('frames %d' % n)

    def warp(self, z):
        self.lines += ['poke dbg_warp %d' % (z + 1), 'frames 300']

    def poke(self, name, *vals):
        a = self.s[name] if isinstance(name, str) else name
        for i, v in enumerate(vals):
            self.lines.append('poke %d %d' % (a + i, v))

    def clear_monsters(self):
        """no creatures in the current zone (so they can't get in the way)"""
        for i in range(24):
            self.lines.append('poke %d 0' % (0xA800 + i * 8))

    def place(self, x, y):
        self.poke('px', x, y)
        self.keys('W')

    def keys(self, *ks, gap=14):
        """tap each key, then wait until the game asks for input again"""
        for k in ks:
            self.lines += ['tap %s' % k, 'untilmem in_input 0 %d' % gap, 'untilmem in_input 1 3000', 'frames 4']

    def run(self, shot=None, name='h'):
        lines = list(self.lines)
        if shot:
            lines.append('screen %s 2' % shot)
        lines.append('dumpram %s.bin' % name)
        path = os.path.join(TEST, name + '.txt')
        with open(path, 'w') as f:
            f.write('\n'.join(lines) + '\n')
        r = subprocess.run([EMU, name + '.txt'], cwd=TEST, capture_output=True, text=True)
        if 'crash' in r.stdout.lower() and 'min SP' not in r.stdout:
            print(r.stdout)
        self.out = r.stdout
        return open(os.path.join(TEST, name + '.bin'), 'rb').read()

    def peek(self, ram, name, n=1):
        a = self.s[name]
        return ram[a] if n == 1 else ram[a:a + n]


def tile(ram, x, y):
    return ram[y * 64 + x] & 0x3F


def find_mon(ram, mtype):
    for i in range(24):
        r = ram[0xA800 + i * 8:0xA808 + i * 8]
        if r[0] == mtype:
            return r[1], r[2]
    return None


def find_tiles(ram, t):
    return [(i % 64, i // 64) for i in range(2048) if ram[i] & 0x3F == t]
