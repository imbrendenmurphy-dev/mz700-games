"""bot.py - a look-ahead player for the Python model; writes cave solutions.

    py tools/bot.py [letters] [--show]

For every move it plans a path with a breadth-first search, then plays the
path in a copy of the world (the model is exact) and keeps it only if the
player arrives alive and is still alive after waiting a while.  Targets are
the nearest diamonds until the exit opens, then the exit.  When no diamond
can be reached safely it digs out the earth under a resting rock to bring
it down, or waits for the cave to change (showers, amoeba, creatures).

Caves may give a short script (cave.script) of moves to run first, for
contraptions the search would not find: ('go', x, y), ('key', 'L', n),
('wait', n), ('snap', 'L').
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caves as C  # noqa: E402
import engine as EN  # noqa: E402

W = C.W
DIRKEY = {-1: EN.K_LEFT, 1: EN.K_RIGHT, -W: EN.K_UP, W: EN.K_DOWN}
NAMEKEY = {'L': EN.K_LEFT, 'R': EN.K_RIGHT, 'U': EN.K_UP, 'D': EN.K_DOWN}
CREATURES = set(range(EN.FIRE0, EN.AMOEBA))
LOOK = 10                     # ticks to survive standing still after a move


class Stuck(Exception):
    pass


def danger_cells(g):
    d = set()
    for i, v in enumerate(g.g):
        if (v & 31) in CREATURES:
            for o in (0, -1, 1, -W, W):
                d.add(i + o)
                for o2 in (-1, 1, -W, W):
                    if g.g[i + o] == 0:
                        d.add(i + o + o2)
    return d


def passable(g, i):
    m = g.g[i] & 31
    if m in (EN.SPACE, EN.DIRT, EN.DIAMOND):
        return True
    return m == EN.EXITO


def bfs(g, avoid):
    start = g.pl_addr
    prev = {start: None}
    order = []
    q = [start]
    for i in q:
        for o in (-1, 1, -W, W):
            n = i + o
            if n in prev or n in avoid or not passable(g, n):
                continue
            prev[n] = i
            order.append(n)
            if (g.g[n] & 31) != EN.EXITO:
                q.append(n)
    return prev, order


def path_to(prev, t):
    p = []
    while prev[t] is not None:
        p.append(t)
        t = prev[t]
    return p[::-1]


def gem_count(g):
    """gems the player has or can get at: collected, lying where the player
    can dig to them, falling, or being born from a butterfly"""
    n = g.got
    prev, order = bfs(g, set())
    for i in order:
        if (g.g[i] & 31) == EN.DIAMOND:
            n += 1
    for v in g.g:
        m = v & 31
        if m == EN.DIAMONDF or EN.DEX1 <= m <= EN.DEX4:
            n += 1
    return n


def survives(g, n=LOOK):
    """alive after standing still n ticks - and not shut in by rocks"""
    s = g.clone()
    for _ in range(n):
        s.tick(0)
        if s.pl_dead:
            return False
        if s.pl_exit:
            return True
    return len(bfs(s, set())[1]) >= 4


def walk(g, path, look=LOOK):
    """play the path on a copy: (keys, new world) or None"""
    s = g.clone()
    keys = []
    for nxt in path:
        k = DIRKEY[nxt - s.pl_addr]
        for _ in range(3):
            s.tick(k)
            keys.append(k)
            if s.pl_dead or s.timeout:
                return None
            if s.pl_addr == nxt or s.pl_exit:
                break
        else:
            return None
        if s.pl_exit:
            return keys, s
    if look and not survives(s, look):
        return None
    return keys, s


class Bot:
    def __init__(self, index, cave=None, max_ticks=4000):
        self.g = EN.Game(index, cave)
        self.keys = []
        self.max_ticks = max_ticks
        self.idle = 0

    def commit(self, keys, s):
        self.keys += keys
        self.g = s
        if len(self.keys) > self.max_ticks:
            raise Stuck('too long')

    def tick(self, k=0):
        self.g.tick(k)
        self.keys.append(k)

    def born(self):
        while self.g.inbox_time or (self.g.g[self.g.pl_addr] & 31) != EN.PLAYER:
            self.tick()

    # ---------------------------------------------------------------- script
    def run_script(self, script):
        for step in script:
            op = step[0]
            if op == 'go':
                self.go(step[1] + step[2] * W)
            elif op == 'key':
                for _ in range(step[2]):
                    self.tick(NAMEKEY[step[1]])
            elif op == 'snap':
                self.tick(NAMEKEY[step[1]] | EN.K_FIRE)
            elif op == 'wait':
                for _ in range(step[1]):
                    self.tick()
            if self.g.pl_dead:
                raise Stuck('script killed the player at %r' % (step,))

    def go(self, target):
        for _ in range(200):
            if self.g.pl_addr == target:
                return
            prev, _ = bfs(self.g, danger_cells(self.g))
            if target in prev:
                r = walk(self.g, path_to(prev, target))
                if r:
                    return self.commit(*r)
            self.wait()
        raise Stuck('cannot reach %d,%d' % (target % W, target // W))

    # ---------------------------------------------------------------- moves
    def wait(self):
        """stand still a tick, or step somewhere safe"""
        if survives(self.g, LOOK + 1):
            self.tick()
            return
        for o in (-1, 1, -W, W):
            n = self.g.pl_addr + o
            if passable(self.g, n):
                r = walk(self.g, [n])
                if r:
                    return self.commit(*r)
        self.tick()

    def step(self):
        g = self.g
        danger = danger_cells(g)
        # first try paths that leave the rocks where they are (earth holding
        # up a rock is a contraption: don't waste it by walking through)
        plugs = {i for i, v in enumerate(g.g) if (v & 31) == EN.DIRT
                 and (g.g[i - W] & 31) in (EN.BOULDER, EN.DIAMOND)}
        for avoid in (danger | plugs, danger):
            prev, order = bfs(g, avoid)
            if g.exit_open:
                targets = [i for i in order if (g.g[i] & 31) == EN.EXITO]
            else:
                targets = [i for i in order if (g.g[i] & 31) == EN.DIAMOND][:16]
            for t in targets:
                r = walk(g, path_to(prev, t))
                if r:
                    self.idle = 0
                    return self.commit(*r)
            if self.idle < 2:
                break                       # give the cave a moment before using the plugs
        prev, order = bfs(g, danger)
        # a timed drop: snap away the earth under a rock from beside it
        if self.idle >= 2 and self.try_drops(prev, order):
            self.idle = 0
            return
        # bring a rock down: earth with a resting rock or diamond on top
        if self.idle >= 3:
            sites = [i for i in order if (g.g[i] & 31) == EN.DIRT
                     and (g.g[i - W] & 31) in (EN.BOULDER, EN.DIAMOND)]
            for t in sites[:12]:
                p = path_to(prev, t)
                r = walk(g, p)
                if r:
                    keys, s = r
                    # and step off again sideways
                    for o in (-1, 1):
                        n = s.pl_addr + o
                        if passable(s, n) and n != p[-2 if len(p) > 1 else -1]:
                            r2 = walk(s, [n])
                            if r2:
                                self.idle = 0
                                return self.commit(keys + r2[0], r2[1])
                    self.idle = 0
                    return self.commit(keys, s)
        self.idle += 1
        self.wait()

    def try_drops(self, prev, order, waits=24, settle=36):
        """for every plug of earth holding up a rock: walk beside it, wait k
        ticks, snap it away, let things settle; keep the best gain in gems"""
        g = self.g
        before = gem_count(g)
        best = None
        tried = 0
        for site in order:
            if (g.g[site] & 31) != EN.DIRT or (g.g[site - W] & 31) not in (EN.BOULDER, EN.DIAMOND):
                continue
            for side in (-1, 1):
                a = site + side                     # stand here, snap towards the site
                if a == g.pl_addr:
                    base = ([], g.clone())
                elif a in prev:
                    base = walk(g, path_to(prev, a), look=0)
                else:
                    continue
                if not base:
                    continue
                tried += 1
                keys0, s0 = base
                k = DIRKEY[-side] | EN.K_FIRE
                for wait in range(waits + 1):
                    s = s0.clone()
                    ok = True
                    for _ in range(wait):
                        s.tick(0)
                        if s.pl_dead:
                            ok = False
                            break
                    if not ok:
                        break
                    s.tick(k)
                    if (s.g[site] & 31) == EN.DIRT:
                        continue                    # the snap did not happen
                    t = s.clone()
                    for _ in range(settle):
                        t.tick(0)
                        if t.pl_dead:
                            ok = False
                            break
                    if not ok or not survives(t):
                        continue
                    gain = gem_count(t) - before
                    if gain > 0 and (best is None or gain > best[0]):
                        best = (gain, keys0 + [0] * wait + [k], s)
                if tried >= 16:
                    break
            if tried >= 16:
                break
        if best:
            self.commit(best[1], best[2])
            return True
        return False

    def play(self, script=()):
        self.born()
        self.run_script(script)
        while not self.g.pl_exit:
            if self.g.pl_dead or self.g.timeout:
                raise Stuck('died' if self.g.pl_dead else 'out of time')
            if self.idle > 400:
                raise Stuck('nothing to do')
            self.step()
        return self.keys


SHOWCH = {EN.SPACE: ' ', EN.DIRT: '.', EN.BRICK: '#', EN.MAGIC: 'M', EN.STEEL: '%', EN.EXIT: 'X',
          EN.EXITO: 'x', EN.BOULDER: 'o', EN.BOULDERF: 'O', EN.DIAMOND: '*', EN.DIAMONDF: '+',
          EN.AMOEBA: 'a', EN.PLAYER: 'P', EN.EXPWALL: '=', EN.INBOX: 'I', EN.SHOWER: 'v'}


def show(g):
    rows = []
    for y in range(C.H):
        r = ''
        for x in range(W):
            m = g.g[y * W + x] & 31
            r += SHOWCH.get(m, 'F' if EN.FIRE0 <= m < EN.BUTT0 else 'B' if m < EN.AMOEBA else '!')
        rows.append(r)
    return '\n'.join(rows)


def solve(c, index):
    b = Bot(index, c)
    try:
        keys = b.play(getattr(c, 'script', ()))
        return True, keys, b.g
    except Stuck as e:
        return False, str(e), b.g


if __name__ == '__main__':
    cs = C.caves()
    want = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else None
    for i, c in enumerate(cs):
        if want and c.letter not in want:
            continue
        ok, res, g = solve(c, i)
        tps = g.tps
        if ok:
            secs = len(res) / tps
            print('%s %-18s CLEARED in %4d ticks (%3d s of %3d), %2d/%2d gems' % (
                c.letter, c.name, len(res), secs, c.time, g.got, c.need))
        else:
            print('%s %-18s FAILED (%s) after %d ticks, %2d/%2d gems' % (
                c.letter, c.name, res, g.ticks, g.got, c.need))
            if '--show' in sys.argv:
                print(show(g))
