"""play.py - run ROBOGEDDON in the headless MZ-700 model with scripted keys.

    py tools/play.py [script] [ticks]

Scripts are in this file (SCRIPTS).  Prints per-tick busy time (scan lines
from the start of vertical blank until the game waits again), overruns, and
saves screenshots to build/shots/.
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms, LINE_MC  # noqa: E402

B = os.path.join(HERE, '..', 'build')
OUT = os.path.join(B, 'shots')


def hold(*k):
    return set(k)


def s_title(t):
    return set()


def s_play(t):
    """Start a game, then run about, shooting in circles."""
    if 300 <= t < 304:
        return hold('space')
    if t < 520:
        return set()
    k = set()
    phase = (t // 40) % 8
    mv = [('w',), ('w', 'd'), ('d',), ('s', 'd'), ('s',), ('s', 'a'), ('a',), ('w', 'a')][phase]
    fire = [('i',), ('i', 'l'), ('l',), ('k', 'l'), ('k',), ('k', 'j'), ('j',), ('i', 'j')][(t // 9) % 8]
    k.update(mv)
    k.update(fire)
    return k


def s_stand(t):
    """Start a game and stand still, spraying shots."""
    if 300 <= t < 304:
        return hold('space')
    if t < 520:
        return set()
    return set([('i',), ('l',), ('k',), ('j',), ('up',), ('right',), ('down',), ('left',)][(t // 6) % 8])


def s_idle(t):
    """Start a game and do nothing: die three times, game over, title."""
    return hold('space') if 300 <= t < 304 else set()


def s_pause(t):
    """Play, pause (RETURN) at 700, resume at 800, pause at 900, quit (Q)."""
    if 300 <= t < 304:
        return hold('space')
    if t in (700, 701, 800, 801, 900, 901):
        return hold('cr')
    if t in (1000, 1001):
        return hold('q')
    return s_stand(t) if 520 <= t < 700 else set()


SCRIPTS = {'title': s_title, 'play': s_play, 'stand': s_stand, 'idle': s_idle,
           'pause': s_pause}


def patch(m, sym):
    if os.environ.get('WAVE'):          # patch "ld a,1 / ld (wave),a" in new_game
        w = sym['wave']
        pat = bytes([0x3E, 0x01, 0x32, w & 0xFF, w >> 8])
        i = m.mem.find(pat, sym['new_game'])
        assert 0 < i - sym['new_game'] < 40
        m.mem[i + 1] = int(os.environ['WAVE'])
    if os.environ.get('GOD'):
        m.mem[sym['player_die']] = 0xC9


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else 'play'
    ticks = int(sys.argv[2]) if len(sys.argv) > 2 else 1500
    shots = set(int(x) for x in sys.argv[3].split(',')) if len(sys.argv) > 3 else set()
    script = SCRIPTS[name]
    os.makedirs(OUT, exist_ok=True)
    sym = load_syms(os.path.join(B, 'robogedn.sym'))
    m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
    LT = LINE_MC / 5.0
    patch(m, sym)
    wv = sym['wait_vblank']
    stats = []
    t0 = time.time()
    m.run_until_pc(wv, 10 ** 8)
    last = None
    for t in range(ticks):
        m.held = script(t)
        # leave wait_vblank: run until it returns (PC back in the caller)
        start = m.cpu.t
        m.step()
        m.run_until_pc(wv, 10 ** 8)
        # time between two waits, less the idle loop the first one spun
        slack = m.mem[sym['slack']] | m.mem[sym['slack'] + 1] << 8
        busy = (m.cpu.t - start - slack * 33) / LT
        st = m.mem[sym['state']]
        stats.append((t, busy, st, m.mem[sym['wave']], m.mem[sym['alive']], m.mem[sym['lives']]))
        if t in shots or (not shots and t % 250 == 0):
            m.screen(2).save(os.path.join(OUT, '%s_%04d.png' % (name, t)))
    el = time.time() - t0
    drops = m.mem[sym['drops']] | m.mem[sym['drops'] + 1] << 8
    print('%d ticks in %.1fs   drops %d' % (ticks, el, drops))
    print(' tick  lines  state wave alive lives')
    for s in stats:
        if s[0] % 100 == 0:
            print('%5d  %5.0f  %4d %4d %5d %5d' % s)
    play = [s[1] for s in stats if s[2] == 1]
    if play:
        print('PLAY ticks %d: busy avg %.0f max %.0f lines (312 per field), over: %d' %
              (len(play), sum(play) / len(play), max(play), sum(1 for b in play if b > 312)))
    sc = m.mem[sym['score']:sym['score'] + 3]
    print('score %02X%02X%02X' % (sc[2], sc[1], sc[0]))


if __name__ == '__main__':
    main()
