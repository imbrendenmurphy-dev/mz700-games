"""profile.py - measures where the T-states go per frame in the simulator.

    py tools/profile.py [fields] [keys...]

Reports T-states spent inside each top-level routine called from the main loop
(using the symbol table), and idle time spent waiting for vertical blank.
"""
import os
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from mzsim import MZ700, FIELD_T  # noqa: E402


def main():
    fields = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    keys = sys.argv[2:]
    S = {}
    for line in open(os.path.join(ROOT, 'build', 'rotoball.sym')):
        k, v = line.split()
        S[k] = int(v, 16)
    m = MZ700()
    m.load_mzf(os.path.join(ROOT, 'build', 'ROTOBALL.MZF'))
    m.run_fields(30)
    m.held = set(keys)
    addrs = sorted((v, k) for k, v in S.items() if v < 0x6000)
    import bisect
    starts = [a for a, _ in addrs]

    def name(pc):
        i = bisect.bisect_right(starts, pc) - 1
        return addrs[i][1] if i >= 0 else '?'

    cost = defaultdict(int)
    frames = 0
    c = m.cpu
    end = c.t + fields * FIELD_T
    while c.t < end:
        pc = c.pc
        if pc == S['frame']:
            frames += 1
        t0 = c.t
        c.step()
        cost[name(pc)] += c.t - t0
    total = sum(cost.values())
    print('%d frames in %d fields; per frame:' % (frames, fields))
    for k, v in sorted(cost.items(), key=lambda kv: -kv[1])[:20]:
        print('  %-16s %8d T  %5.1f%%' % (k, v // max(frames, 1), 100 * v / total))
    print('  budget for 3 fields: %d T' % (3 * FIELD_T))


if __name__ == '__main__':
    main()
