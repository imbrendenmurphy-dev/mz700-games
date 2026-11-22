"""crosscheck.py - the Z80 program and the Python model, tick by tick.

    py tools/crosscheck.py [caves] [ticks] [seed]

For each cave: start a game there in turbo mode, then feed the same random
(but sensible) keys to both, and compare the whole cave and the counters
after every tick.  Any difference is printed and the run stops.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game as Z80Game, S  # noqa: E402
import engine  # noqa: E402

FIELDS = ('got', 'exit_open', 'magic_state', 'amoeba_conv', 'ctime', 'pl_dead', 'pl_exit',
          'shower_left', 'inbox_time', 'magic_time', 'amoeba_fast')


def bcd(b):
    return (b >> 4) * 10 + (b & 15)


class Pair:
    def __init__(self, index):
        self.index = index
        z = Z80Game()
        z.run(30)
        z.wb('start_cave', index)
        z.wb('turbo', 1)
        z.run(10, ['space'])
        z.m.held = set()                    # let go, or a front-end page (the ending) waits forever
        self.z = z
        self.until_hook(2000)
        self.p = engine.Game(index)
        self.n = 0

    def until_hook(self, max_fields):
        c = self.z.m.cpu
        hook = S['tick_hook']
        end = c.t + max_fields * 70886
        step = c.step
        # leave the hook first if we are sitting on it
        if c.pc == hook:
            step()
        while c.pc != hook:
            if c.t > end:
                raise RuntimeError('tick_hook not reached (pc %04X)' % c.pc)
            step()

    def tick(self, keys):
        """one tick on both; returns a list of differences"""
        self.z.wb('tick_dir', keys)
        self.until_hook(4000)           # long after an exit: time bonus, cover, next cave card
        self.p.tick(keys)
        self.n += 1
        return self.diff()

    def z_cave(self):
        b = S['CAVE']
        return list(self.z.m.mem[b:b + 2048])

    def diff(self):
        out = []
        zc = self.z_cave()
        for i, (a, b) in enumerate(zip(zc, self.p.g)):
            if a != b:
                out.append('cell %d,%d: z80 %02X model %02X' % (i % 64, i // 64, a, b))
                if len(out) > 8:
                    break
        z = self.z
        for f in FIELDS:
            a, b = z.rb(f), getattr(self.p, f)
            if a != b:
                out.append('%s: z80 %d model %d' % (f, a, b))
        if z.rw('cseed') != self.p.cseed:
            out.append('cseed: z80 %04X model %04X' % (z.rw('cseed'), self.p.cseed))
        if z.rw('pl_addr') - S['CAVE'] != self.p.pl_addr and not self.p.pl_dead:
            out.append('pl_addr: z80 %d model %d' % (z.rw('pl_addr') - S['CAVE'], self.p.pl_addr))
        zs = bcd(z.rb('score')) + 100 * bcd(z.rb('score', 1)) + 10000 * bcd(z.rb('score', 2))
        if zs != self.p.score:
            out.append('score: z80 %d model %d' % (zs, self.p.score))
        return out


KEYS = [0, engine.K_UP, engine.K_DOWN, engine.K_LEFT, engine.K_RIGHT]


def run(index, n, seed):
    rnd = random.Random(seed)
    p = Pair(index)
    d = p.diff()
    if d:
        print('cave %d differs at load:' % index, d)
        return False
    k = 0
    for t in range(n):
        if t % 6 == 0:
            k = rnd.choice(KEYS)
            if rnd.random() < 0.1:
                k |= engine.K_FIRE
        d = p.tick(k)
        if d:
            print('cave %d tick %d (keys %d) differs:' % (index, p.n, k))
            print('  ' + '\n  '.join(d))
            return False
        if p.p.pl_dead or p.p.timeout or p.p.pl_exit:
            break
    print('cave %d: %d ticks agree%s' % (index, p.n, ' (player died)' if p.p.pl_dead else ''))
    return True


if __name__ == '__main__':
    cs = [int(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else list(range(16))
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 400
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    ok = all([run(c, n, seed + c) for c in cs])
    sys.exit(0 if ok else 1)
