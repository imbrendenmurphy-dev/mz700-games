"""dbg.py - scratch debugging: watch variables frame by frame."""
import bisect
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S, parse_keys  # noqa: E402
from mzsim import FIELD_T  # noqa: E402

labels = sorted((v, k) for k, v in S.items() if 0x1200 <= v < 0x10000 and '.' not in k)
addrs = [a for a, _ in labels]


def name(pc):
    i = bisect.bisect_right(addrs, pc) - 1
    return labels[i][1] if i >= 0 else '?'


if __name__ == '__main__':
    fields = int(sys.argv[1])
    keys = parse_keys(sys.argv[2]) if len(sys.argv) > 2 else []
    watch = sys.argv[3].split(',') if len(sys.argv) > 3 else ['hearts', 'room', 'kx', 'ky']
    g = Game()
    held = []
    prev = None
    for f in range(fields):
        for kf, k in keys:
            if kf == f:
                held = k
        g.m.held = set(held)
        prof = collections.Counter()
        c = g.m.cpu
        end = c.t + FIELD_T
        while c.t < end:
            prof[c.pc] += 1
            c.step()
        cur = tuple(g.rb(w) for w in watch)
        if cur != prev:
            top = collections.Counter()
            for pc, n in prof.items():
                top[name(pc)] += n
            print(f, dict(zip(watch, cur)), top.most_common(3))
            prev = cur
