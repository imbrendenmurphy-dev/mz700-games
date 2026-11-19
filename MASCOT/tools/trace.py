"""trace.py - run until the PC escapes, then show the last instructions.

    py tools/trace.py FIELDS [--keys ...]
"""
import bisect
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S, parse_keys  # noqa: E402
from mzsim import FIELD_T  # noqa: E402

labels = sorted((v, k) for k, v in S.items() if 0x1200 <= v < 0x10000)
addrs = [a for a, _ in labels]


def name(pc):
    i = bisect.bisect_right(addrs, pc) - 1
    if i < 0:
        return '%04X' % pc
    a, k = labels[i]
    return '%04X %s+%d' % (pc, k, pc - a)


args = sys.argv[1:]
keys = []
if '--keys' in args:
    i = args.index('--keys')
    keys = parse_keys(args[i + 1])
    args = args[:i] + args[i + 2:]
fields = int(args[0])
g = Game()
m = g.m
c = m.cpu
ring = collections.deque(maxlen=int(os.environ.get('RING', '60')))
held = []
end_prog = S['end_of_program']
for f in range(fields):
    for kf, k in keys:
        if kf == f:
            held = k
    m.held = set(held)
    end = c.t + FIELD_T
    while c.t < end:
        ring.append((c.pc, c.sp))
        c.step()
        if not (0x1200 <= c.pc < end_prog):
            rl = list(ring)
            bad = os.environ.get('BAD')
            if bad:
                lo, hi = (int(x, 16) for x in bad.split('-'))
                k = next(i for i, (p, s) in enumerate(rl) if lo <= p < hi)
                rl = rl[max(0, k - 40):k + 2]
            for pc, sp in rl:
                print(name(pc), 'SP %04X' % sp)
            print('escaped to %04X at field %d' % (c.pc, f))
            sys.exit(1)
print('ok', g.hero())
