"""profile.py - T-states per routine during play (VRAM waits included).

    py tools/profile.py [script] [ticks]
"""
import bisect
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402
import play  # noqa: E402

B = os.path.join(HERE, '..', 'build')


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else 'play'
    ticks = int(sys.argv[2]) if len(sys.argv) > 2 else 900
    script = play.SCRIPTS[name]
    sym = load_syms(os.path.join(B, 'robogedn.sym'))
    funcs = sorted((v, k) for k, v in sym.items() if '.' not in k and 0x1200 <= v < 0xA000)
    addrs = [a for a, _ in funcs]
    m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
    play.patch(m, sym)
    wv = sym['wait_vblank']
    m.run_until_pc(wv, 10 ** 8)
    prof = Counter()
    seed = os.environ.get('SEED')
    for t in range(ticks):
        m.held = script(t)
        if seed and t == 300:
            m.mem[sym['seed']] = int(seed) & 0xFF
            m.mem[sym['seed'] + 1] = (int(seed) >> 8) | 1
        m.step()
        prof_on = m.mem[sym['state']] == 1 and t > 520
        while m.cpu.pc != wv:
            pc = m.cpu.pc
            t0 = m.cpu.t
            m.step()
            if prof_on:
                i = bisect.bisect_right(addrs, pc) - 1
                prof[funcs[i][1]] += m.cpu.t - t0
    tot = sum(prof.values())
    for k, v in prof.most_common(25):
        print('%-20s %9d  %5.1f%%' % (k, v, 100.0 * v / tot))


if __name__ == '__main__':
    main()
