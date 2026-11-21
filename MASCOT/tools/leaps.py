"""leaps.py - how much timing slack does each deadly jump give?

    py tools/leaps.py [level-code ...] [--all]

For every platform edge with a deadly fall beyond it (walking off the edge
loses a life), Kiko starts still at the far end of the platform and runs at
it, holding the direction; the jump button is pressed on frame t and held.
Every t from the first step to the end of the coyote time is tried.  The
window is the number of take-off frames that land him somewhere safe that
is not the platform he left (another platform, a spring, the next room).
A jump no take-off frame makes is retried with a colour change in the air
(chroma blocks): the window then counts take-offs that work with some swap
time, and 'swap N frames' is the most swap times that work for one take-off.

Edges with a window under SAFE frames are listed (all of them with --all).
Each colour Kiko can have in that world is tried (chroma blocks), and the
best window is kept.  Moving platforms are not tried (not counted as
landing spots, not as starting points).  Uses the movement copy in
tools/reach.py, so it ignores enemies.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reach  # noqa: E402
import levels as LV  # noqa: E402
import tiles as TL  # noqa: E402

SAFE = 6            # frames (50 a second)
STAND = TL.F_SOLID | TL.F_ONEWAY


def platforms(m, col):
    """standable runs (row, x0, x1); moving-platform paths are left out"""
    out = []
    for y in range(1, reach.H):
        x = 0
        while x < reach.W:
            def ok(xx):
                f = m.f(xx, y, col)
                return (f & STAND and not f & (TL.F_HURT | TL.F_SPRING) and (xx, y) not in m.extra
                        and not (m.f(xx, y - 1, col) & TL.F_SOLID))
            if ok(x):
                x0 = x
                while x < reach.W and ok(x):
                    x += 1
                out.append((y, x0, x - 1))
            else:
                x += 1
    return out


def fly(lm, ri, x, y, col, d, t, hold=30, swap=None):
    """run in direction d (1 or -1) from (x, y); jump on frame t (None: never);
    swap = (frame, colour): change colour then (one press, optimistic)"""
    s = reach.Sim(lm, ri, x, y, col)
    s.gnd = True
    key = 8 if d > 0 else 4
    left = False
    for f in range(400):
        k = key
        if t is not None and t <= f < t + hold:
            k |= 16
        if swap and f == swap[0]:
            s.col = swap[1]
        r = s.step(k)
        if r == 'dead' or s.dead:
            return 'dead'
        if not s.gnd:
            left = True
        if r == 'room':
            return ('room', s.room)
        if left and s.gnd:
            return ('land', s.room, s.x, s.y)
        if t is None and f > 200:
            return 'stuck'
    return 'stuck'


def safe_landing(r, ri, y, x0, x1):
    return (r != 'dead' and r != 'stuck'
            and not (r[0] == 'land' and r[1] == ri and r[3] == y - 1 and x0 - 1 <= r[2] <= x1))


def swap_window(lm, ri, sx, y, x0, x1, col, d):
    """a jump that needs a colour change in the air: take-off frames that work
    with some swap time, and the most swap frames that work for one take-off"""
    good, most = [], 0
    for t in range(0, 120):
        n = 0
        for c in lm.colours:
            if c == col:
                continue
            for k in range(0, 45):
                if safe_landing(fly(lm, ri, sx, y - 1, col, d, t, swap=(t + k, c)), ri, y, x0, x1):
                    n += 1
        if n:
            good.append(t)
            most = max(most, n)
        elif t > 60 and not good:
            break
        elif good and t > good[-1] + 3:
            break
    return good, most


def edges(lv, col):
    lm = reach.LevelModel(lv)
    out = []
    for ri, room in enumerate(lv.rooms):
        m = lm.models[ri]
        for (y, x0, x1) in platforms(m, col):
            for d in (1, -1):
                sx = x0 if d > 0 else x1 - 1
                if x1 - x0 < 1:
                    sx = x0
                if fly(lm, ri, sx, y - 1, col, d, None) != 'dead':
                    continue                    # walking off is safe
                res = []
                for t in range(0, 120):
                    r = fly(lm, ri, sx, y - 1, col, d, t)
                    res.append(r)
                    if r == 'dead' and t > 0 and res[-2] == 'dead' and len(res) > 30:
                        break
                good = [t for t, r in enumerate(res) if safe_landing(r, ri, y, x0, x1)]
                if not good and len(lm.colours) > 1:
                    good, sw = swap_window(lm, ri, sx, y, x0, x1, col, d)
                    res = [('swap %d frames' % sw,)] if good else res
                out.append((room.key, y, x0, x1, d, len(good), res, good))
    return out


def main():
    reach.link_all()
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    show_all = '--all' in sys.argv
    worst = []
    for lv in LV.LEVELS:
        if args and lv.code not in args:
            continue
        best = {}
        for col in reach.LevelModel(lv).colours:      # each colour Kiko can have
            for e in edges(lv, col):
                k = e[:5]
                if k not in best or e[5] > best[k][5]:
                    best[k] = e
        for (rk, y, x0, x1, d, n, res, good) in sorted(best.values(), key=lambda e: e[:5]):
            if n >= SAFE and not show_all:
                continue
            where = [r for r in res if r != 'dead' and r != 'stuck']
            if where and len(where[0]) == 1:
                where = [where[0][0]]
            print('%s %s row %2d x%2d-%2d %s  window %2d frames  %s' % (
                lv.code, rk, y, x0, x1, 'right' if d > 0 else 'left ', n,
                sorted(set((r[0], r[2], r[3]) if isinstance(r, tuple) and r[0] == 'land' else r for r in where), key=str)[:4]))
            worst.append(n)
    print('%d deadly edges listed' % len(worst))


if __name__ == '__main__':
    main()
