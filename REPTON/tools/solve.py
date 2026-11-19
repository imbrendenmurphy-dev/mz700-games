"""solve.py - plays the whole game on the Python model from tools/solution.py.

    py tools/solve.py [region-key ...] [--show] [--save]

The solution is a list of commands per region visit.  A small pilot turns
"go to x,y" into moves: every tick it plans a breadth-first path through
what is passable right now and checks the next few ticks on a copy of the
game, so it never walks under a falling rock or next to a creature.
Writes build/solution.bin (one direction per tick) with --save; that file
drives tools/verify.py (the same run on the Z80 build) and the demo.
"""
import copy
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402
import world  # noqa: E402
from engine import W, H, M, E  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASS = {E[n] for n in ('SPACE', 'EARTH', 'SECRET', 'GEM', 'PIECE', 'CROWN', 'KEY')}
DANGER = {E[n] for n in ('MONSTER', 'SPIRIT0', 'SPIRIT1', 'SPIRIT2', 'SPIRIT3', 'HATCH3', 'FUNGUS')}
STEP = {1: -1, 2: -W, 3: 1, 4: W}
LETTER = {'L': 1, 'U': 2, 'R': 3, 'D': 4, '.': 0}


class Fail(Exception):
    pass


def clone(g):
    c = copy.copy(g)
    c.mem = bytearray(g.mem)
    c.visited = set(g.visited)
    c.events = []
    return c


class Pilot:
    def __init__(self, g, log):
        self.g = g
        self.log = log            # list of directions (the solution)
        self.ticks = 0

    def step(self, d, check=True):
        g = self.g
        ev = g.step(d)
        self.log.append(d)
        self.ticks += 1
        if g.dead:
            raise Fail('died (tick %d, region %s)\n%s' % (len(self.log), g.wd.regions[g.region].key, g.show()))
        return ev

    # ---------------------------------------------------------------- safety
    def safe(self, plan, look=5):
        """does following plan (list of dirs, padded with waits) survive `look` ticks?"""
        c = clone(self.g)
        for i in range(look):
            d = plan[i] if i < len(plan) else 0
            c.step(d)
            if c.dead:
                return False
            if c.region != self.g.region:
                return True
        return True

    def danger_cells(self):
        g = self.g
        b = g.base()
        bad = set()
        for p in range(W, engine.RSZ - W):
            v = g.mem[b + p] & M
            if v in DANGER:
                bad.add(p)
                for d in (1, -1, W, -W):
                    bad.add(p + d)
        return bad

    def bfs(self, goal, into=False, avoid=()):
        """path (list of dirs) from the player to goal (a cell index); with
        into=True the goal itself need not be passable (step into it)"""
        g = self.g
        b = g.base()
        start = g.pos
        bad = self.danger_cells() | set(avoid)
        prev = {start: None}
        q = deque([start])
        while q:
            p = q.popleft()
            if p == goal:
                break
            for d, off in STEP.items():
                n = p + off
                if n in prev:
                    continue
                v = g.mem[b + n] & M
                ok = v in PASS and n not in bad
                if n == goal and into:
                    ok = True
                if ok:
                    prev[n] = (p, d)
                    q.append(n)
        if goal not in prev:
            return None
        path = []
        p = goal
        while prev[p]:
            p, d = prev[p]
            path.append(d)
        return path[::-1]

    def go(self, x, y, into=False, limit=600, avoid=()):
        goal = (y + 1) * W + x + 1
        r0 = self.g.region
        waited = 0
        for _ in range(limit):
            if self.g.region != r0:
                return
            if self.g.pos == goal and not into:
                return
            path = self.bfs(goal, into, avoid)
            if path is None:
                waited += 1
                if waited > 40:
                    raise Fail('no path to %d,%d in %s\n%s' % (x, y, self.g.wd.regions[r0].key, self.g.show()))
                self.step(0)
                continue
            if not path:
                return
            if self.safe(path):
                ev = self.step(path[0])
                if into and len(path) == 1 and ('switch' in ev or 'transport' in ev or 'win' in ev
                                                or 'blocked' in ev or 'gate_shut' in ev):
                    return ev
                continue
            # not safe: wait if that is safe, else try any safe neighbour
            if self.safe([0]):
                self.step(0)
                waited += 1
                if waited > 60:
                    raise Fail('stuck waiting near %d,%d\n%s' % (x, y, self.g.show()))
                continue
            for d in (1, 2, 3, 4):
                if self.safe([d]):
                    self.step(d)
                    break
            else:
                raise Fail('trapped\n' + self.g.show())
        raise Fail('go %d,%d took too long\n%s' % (x, y, self.g.show()))

    def moves(self, s):
        for tok in s.split():
            n = int(tok[1:]) if len(tok) > 1 else 1
            for _ in range(n):
                self.step(LETTER[tok[0]])

    def collect(self, kinds=('GEM', 'PIECE', 'CROWN', 'KEY'), box=None, limit=3000):
        """visit every reachable collectable of the given kinds (nearest first)"""
        want = {E[k] for k in kinds}
        t0 = self.ticks
        while self.ticks - t0 < limit:
            g = self.g
            b = g.base()
            cands = []
            for p in range(engine.RSZ):
                if g.mem[b + p] & M in want:
                    x, y = p % W - 1, p // W - 1
                    if box and not (box[0] <= x <= box[2] and box[1] <= y <= box[3]):
                        continue
                    cands.append(p)
            if not cands:
                return
            best = None
            for p in cands:
                path = self.bfs(p)
                if path is not None and (best is None or len(path) < len(best[1])):
                    best = (p, path)
            if best is None:
                return
            p = best[0]
            self.go(p % W - 1, p // W - 1)
        raise Fail('collect took too long')


def run(solution, keys=None, show=False):
    wd = world.load()
    g = engine.Game(wd)
    log = []
    pl = Pilot(g, log)
    for i, (key, cmds) in enumerate(solution):
        r = wd.regions[g.region].key
        if r != key:
            raise Fail('visit %d: expected to be in %s, in %s' % (i, key, r))
        t0 = len(log)
        for cmd in cmds:
            op = cmd[0]
            if op == 'go':
                pl.go(*cmd[1:])
            elif op == 'into':
                ev = pl.go(cmd[1], cmd[2], into=True)
            elif op == 'mv':
                pl.moves(cmd[1])
            elif op == 'wait':
                for _ in range(cmd[1]):
                    pl.step(0)
            elif op == 'collect':
                pl.collect(*cmd[1:])
            elif op == 'until':
                # wait until a cell holds an element (or limit)
                x, y, el = cmd[1], cmd[2], E[cmd[3]]
                for _ in range(cmd[4] if len(cmd) > 4 else 200):
                    if g.cell((y + 1) * W + x + 1) & M == el:
                        break
                    pl.step(0)
                else:
                    raise Fail('until %s at %d,%d never happened\n%s' % (cmd[3], x, y, g.show()))
            elif op == 'check':
                cmd[1](g)
            else:
                raise ValueError(op)
        gm, pc, cr, mo = g.counts()
        if show:
            print('%-3s %5d ticks  left: %3d gems %2d pieces %d crowns %2d monsters' % (
                key, len(log) - t0, gm, pc, cr, mo))
        if g.won:
            break
    return g, log


def save(log):
    """RLE: dir << 5 | (n - 1)"""
    out = bytearray()
    i = 0
    while i < len(log):
        d = log[i]
        n = 1
        while i + n < len(log) and log[i + n] == d and n < 32:
            n += 1
        out.append(d << 5 | (n - 1))
        i += n
    out.append(0xFF)
    return bytes(out)


if __name__ == '__main__':
    import solution
    try:
        g, log = run(solution.SOLUTION, show=True)
    except Fail as e:
        print('FAILED:', e)
        sys.exit(1)
    gm, pc, cr, mo = g.counts()
    print('%d ticks (%.1f minutes at 8.3 ticks/s), won: %s, left %d gems %d pieces %d crowns %d monsters' % (
        len(log), len(log) / 8.33 / 60, g.won, gm, pc, cr, mo))
    if '--save' in sys.argv:
        with open(os.path.join(ROOT, 'build', 'solution.bin'), 'wb') as f:
            f.write(save(log))
        with open(os.path.join(ROOT, 'build', 'solution_raw.bin'), 'wb') as f:
            f.write(bytes(log))
    sys.exit(0 if g.won else 2)
