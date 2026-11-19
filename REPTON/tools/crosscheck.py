"""crosscheck.py - run the Z80 game and the Python model side by side.

    py tools/crosscheck.py [ticks] [seed] [--script file]

Starts a game in the simulator (turbo mode: no frame waits, one tick per
frame), feeds the same direction to both at every tick (random walk, or a
recorded input script), and after every tick compares the whole world,
the region, the player position, the tick counter, the switch flags and
the derived counts.  Any difference stops with a report.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402
import engine  # noqa: E402
import world  # noqa: E402


class Pair:
    def __init__(self):
        self.g = Game()
        self.wd = world.load()
        self.py = engine.Game(self.wd)
        g = self.g
        g.run(30)
        g.run(5, ['space'])
        g.m.held = set()
        self.until_hook(200)
        g.wb('turbo', 1)
        self.n = 0

    def until_hook(self, fields=50):
        """run the Z80 until it reaches tick_hook (start of a tick's scan)"""
        c = self.g.m.cpu
        hook = S['tick_hook']
        end = c.t + int(fields * 70886)
        step = c.step
        while c.t < end:
            step()
            if c.pc == hook:
                return True
        raise RuntimeError('tick_hook not reached (pc %04X)' % c.pc)

    def tick(self, d):
        g, py = self.g, self.py
        g.wb('tick_dir', d)
        ev = py.step(d)
        if py.dead:
            py.deaths += 1
            py.restore()
        self.n += 1
        self.until_hook(400)          # the Z80 finishes the tick (and any transition)
        self.compare(ev)
        return ev

    def compare(self, ev):
        g, py = self.g, self.py
        mem = g.m.mem
        w = S['WORLD']
        bad = []
        n = len(py.mem)
        z = mem[w:w + n]
        if bytes(z) != bytes(py.mem):
            diffs = [i for i in range(n) if z[i] != py.mem[i]]
            i = diffs[0]
            bad.append('world differs at %d places, first region %d (%d,%d): z80 %02X py %02X' % (
                len(diffs), i // 768, i % 32, (i % 768) // 32, z[i], py.mem[i]))
        if g.rb('region') != py.region:
            bad.append('region z80 %d py %d' % (g.rb('region'), py.region))
        if g.rw('pl_pos') != py.pos:
            bad.append('pos z80 %d py %d' % (g.rw('pl_pos'), py.pos))
        if g.rw('tick') != py.tick:
            bad.append('tick z80 %d py %d' % (g.rw('tick'), py.tick))
        if g.rw('sw_flags') != py.flags:
            bad.append('flags z80 %d py %d' % (g.rw('sw_flags'), py.flags))
        gm, pc, cr, mo = py.counts()
        zc = (g.rw('gems_left'), g.rb('pieces_left'), g.rb('crowns_left'), g.rb('mons_left'))
        if zc != (gm, pc, cr, mo):
            bad.append('counts z80 %s py %s' % (zc, (gm, pc, cr, mo)))
        if bad:
            print('MISMATCH after tick %d (events %s):' % (self.n, ev))
            for b in bad:
                print('  ' + b)
            print('python region:')
            print(py.show())
            print('z80 region:')
            from world import CHAR
            from tiles import ELEMS
            r = g.rb('region')
            print('\n'.join(''.join(CHAR.get(ELEMS[v] if v < len(ELEMS) else 'COVER', '?') for v in row)
                            for row in g.region(r)))
            g.shot('mismatch')
            sys.exit(1)


def random_walk(p, ticks, seed):
    rnd = random.Random(seed)
    d = 0
    stats = {}
    for i in range(ticks):
        if rnd.random() < 0.25:
            d = rnd.choice([0, 1, 2, 3, 4, 1, 3, 4])
        ev = p.tick(d)
        for e in ev:
            stats[e] = stats.get(e, 0) + 1
    return stats


if __name__ == '__main__':
    ticks = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    p = Pair()
    st = random_walk(p, ticks, seed)
    print('%d ticks agree; events: %s' % (ticks, st))
