"""verify.py - check the renderer's invariants every tick of a scripted game.

    py tools/verify.py [script] [ticks]      (WAVE=n, GOD=1 as for play.py)

After each flush:  VRAM == W (chars and attributes), and every live object
is either visible in its cell (it owns it) or hidden under another object
that is really in that cell.  A hidden object may lag by one tick.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402
import play  # noqa: E402

B = os.path.join(HERE, '..', 'build')
OBJ, SZ = 0x9000, 32
WCH, WAT, OCC = 0xB800, 0xBC00, 0xC800


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else 'play'
    ticks = int(sys.argv[2]) if len(sys.argv) > 2 else 1500
    script = play.SCRIPTS[name]
    sym = load_syms(os.path.join(B, 'robogedn.sym'))
    m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
    play.patch(m, sym)
    cp = sym['check_pause']
    bad_v = bad_o = checked = 0
    lag = {}
    wv = sym['wait_vblank']
    m.run_until_pc(wv, 10 ** 9)
    for t in range(ticks):
        m.held = script(t)
        m.step()
        c = m.cpu
        while c.pc != wv and c.pc != cp:     # one tick: to the next wait,
            m.step()                          # or to just after the flush
        if c.pc == wv:
            continue
        mem = m.mem
        # 1. VRAM equals W
        dv = [i for i in range(1000) if mem[0xD000 + i] != mem[WCH + i] or mem[0xD800 + i] != mem[WAT + i]]
        if dv:
            bad_v += 1
            if bad_v <= 5:
                print('tick %d: %d cells VRAM != W, e.g. %s' % (t, len(dv), dv[:6]))
        # 2. objects visible or properly covered (state PLAY/INTRO/CLEAR)
        if mem[sym['state']] in (0, 1, 3):
            top = mem[sym['objtop']]
            pos = {}
            for i in range(top):
                o = mem[OBJ + i * SZ:OBJ + i * SZ + SZ]
                if o[0] and o[0] != 14:
                    pos[i + 1] = o[4] * 40 + o[2]
            for oid, ofs in pos.items():
                if mem[OBJ + (oid - 1) * SZ] in (10, 11, 12):
                    continue            # humans may hide under robots
                owner = mem[OCC + ofs]
                checked += 1
                ok = owner == oid or pos.get(owner) == ofs
                if not ok:
                    lag[oid] = lag.get(oid, 0) + 1
                    if lag[oid] >= 3:
                        bad_o += 1
                        if bad_o <= 5:
                            o = mem[OBJ + (oid - 1) * SZ:OBJ + (oid - 1) * SZ + SZ]
                            print('tick %d: object %d type %d at %d,%d not shown (owner %d, drawn %d)' %
                                  (t, oid, o[0], o[2], o[4], owner, o[23]))
                else:
                    lag[oid] = 0
        m.run_until_pc(sym['wait_vblank'], 10 ** 9)
    print('%d ticks: VRAM mismatches %d, missing objects %d (of %d checks)' % (ticks, bad_v, bad_o, checked))


if __name__ == '__main__':
    main()
