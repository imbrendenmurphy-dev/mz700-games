"""platforms.py - is there any surface Kiko can never stand on?

    py tools/platforms.py [level-code ...]

Runs the reachability search (tools/reach.py) and lists every platform -
a horizontal run of cells Kiko could stand on (solid, plank, chroma or
crumbling with open space above) - on which no reachable resting state was
ever found.  Ground, walls and ceilings no one is meant to stand on show up
too, so each hit needs a look; runs with no headroom at all are skipped.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reach  # noqa: E402
import tiles as TL  # noqa: E402

STAND = TL.F_SOLID | TL.F_ONEWAY


def runs(lm, ri):
    """platform runs in room ri: (row, x0, x1); chroma blocks count in any colour"""
    m = lm.models[ri]
    out = []
    for y in range(1, reach.H):
        x = 0
        while x < reach.W:
            def standable(xx):
                c = m.chroma[y][xx]
                f = TL.F_SOLID if c is not None else m.flags[y][xx]
                if (xx, y) in m.extra:
                    f |= TL.F_ONEWAY
                if not f & STAND or f & (TL.F_HURT | TL.F_SPRING):
                    return False
                above = m.chroma[y - 1][xx]
                fa = 0 if above is not None else m.flags[y - 1][xx]
                return not fa & TL.F_SOLID
            if standable(x):
                x0 = x
                while x < reach.W and standable(x):
                    x += 1
                out.append((y, x0, x - 1))
            else:
                x += 1
    return out


def main(want):
    reach.link_all()
    bad = 0
    for lv in reach.LV.LEVELS:
        if want and lv.code not in want:
            continue
        lm, seen, touched = reach.explore(lv)
        stood = {(s[0], s[1], s[2]) for s in seen}
        found = []
        for ri, r in enumerate(lm.rooms):
            for (y, x0, x1) in runs(lm, ri):
                if not any((ri, x, y - 1) in stood for x in range(x0 - 1, x1 + 1)):
                    # how much headroom does it have at its best column?
                    head = max(sum(1 for k in range(1, 4) if y - k >= 0 and
                                   not lm.models[ri].f(x, y - k, -1) & TL.F_SOLID)
                               for x in range(x0, x1 + 1))
                    found.append((r.key, y, x0, x1, head, r.rows[y][x0:x1 + 1]))
        print('%-5s %-18s %d platform runs never stood on' % (lv.code, lv.name, len(found)))
        for f in found:
            print('        room %s row %2d cols %2d-%2d headroom %d  %r' % f)
        bad += len(found)
    return bad


if __name__ == '__main__':
    sys.exit(1 if main(sys.argv[1:]) else 0)
