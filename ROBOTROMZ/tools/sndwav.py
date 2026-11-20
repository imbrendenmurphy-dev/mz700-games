"""sndwav.py - render the game's sound to WAV files (from the MZ-700 model).

    py tools/sndwav.py            -> build/sound/*.wav

The model logs every write to 8253 counter 0 and the sound gate; this turns
that into a square wave (tone = 1108800 / divisor Hz), as the MZ-700's
speaker would play it.  Files:
    title.wav       the title tune
    sfx_<name>.wav  each effect on its own
    sfx_tour.wav    all the effects in a row
    game.wav        15 seconds of a scripted game (with the heartbeat)
"""
import os
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402
import play  # noqa: E402

B = os.path.join(HERE, '..', 'build')
OUT = os.path.join(B, 'sound')
CPU = 3546875
RATE = 22050
CLK = 1108800

EFFECTS = [('shoot', 30), ('boom', 50), ('bigboom', 70), ('rescue', 50),
           ('pick', 50), ('zap', 30), ('push', 30), ('efire', 30), ('missile', 30),
           ('shell', 30), ('human', 60), ('mutate', 70), ('spawn', 30),
           ('extra', 80), ('death', 120), ('wave', 100), ('clear', 80),
           ('over', 220), ('beat', 40)]


def render(log, t0, t1, path):
    """log: (t, addr, value) writes; render t0..t1 (T-states) to a WAV."""
    log = sorted(e for e in log if e[0] < t1)
    div, lsb, toggle, gate = 0, 0, 0, 0
    i = 0
    # state at t0
    while i < len(log) and log[i][0] < t0:
        t, a, v = log[i]
        div, lsb, toggle, gate = step(div, lsb, toggle, gate, a, v)
        i += 1
    n = int((t1 - t0) * RATE / CPU)
    phase = 0.0
    frames = bytearray()
    for k in range(n):
        t = t0 + k * CPU / RATE
        while i < len(log) and log[i][0] <= t:
            _, a, v = log[i]
            div, lsb, toggle, gate = step(div, lsb, toggle, gate, a, v)
            i += 1
        s = 0
        if gate and div > 1:
            phase = (phase + CLK / div / RATE) % 1.0
            s = 9000 if phase < 0.5 else -9000
        frames += struct.pack('<h', s)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    return n / RATE


def step(div, lsb, toggle, gate, a, v):
    if a == 0xE007:
        if (v >> 6) == 0:
            toggle = 0
    elif a == 0xE004:
        if toggle == 0:
            lsb = v
            toggle = 1
        else:
            div = lsb | (v << 8)
            if div == 0:
                div = 65536
            toggle = 0
    elif a == 0xE008:
        gate = v & 1
    return div, lsb, toggle, gate


def machine(silent_title=False):
    sym = load_syms(os.path.join(B, 'robogedn.sym'))
    m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
    if silent_title:
        m.mem[sym['sfx_title']] = 0
    m.snd = []
    return m, sym


def ticks(m, sym, n, keys=lambda t: set()):
    wv = sym['wait_vblank']
    for t in range(n):
        m.held = keys(t)
        m.step()
        m.run_until_pc(wv, 10 ** 9)


def main():
    os.makedirs(OUT, exist_ok=True)
    # title tune
    m, sym = machine()
    m.run_until_pc(sym['wait_vblank'], 10 ** 8)
    t0 = m.cpu.t
    ticks(m, sym, 760)
    print('title.wav %.1fs' % render(m.snd, t0, m.cpu.t, os.path.join(OUT, 'title.wav')))

    # each effect, played on a silent title page
    m, sym = machine(silent_title=True)
    m.run_until_pc(sym['wait_vblank'], 10 ** 8)
    ticks(m, sym, 20)
    tour0 = m.cpu.t
    for name, n in EFFECTS:
        addr = sym['sfx_' + name]
        m.mem[sym['sndptr']] = addr & 0xFF
        m.mem[sym['sndptr'] + 1] = addr >> 8
        m.mem[sym['sndpri']] = 9
        m.mem[sym['sndleft']] = 0
        m.mem[sym['ptick']] = 0           # stay on the (silent) title page
        m.mem[sym['ptick'] + 1] = 0
        a = m.cpu.t
        ticks(m, sym, n)
        render(m.snd, a, m.cpu.t, os.path.join(OUT, 'sfx_%s.wav' % name))
        ticks(m, sym, 15)                 # a gap
    print('sfx_tour.wav %.1fs' % render(m.snd, tour0, m.cpu.t, os.path.join(OUT, 'sfx_tour.wav')))

    # a game
    m, sym = machine()
    os.environ.setdefault('SEED', '1234')
    play.patch(m, sym)
    m.run_until_pc(sym['wait_vblank'], 10 ** 8)
    ticks(m, sym, 300)
    for v in (1234 & 255, (1234 >> 8) | 1):
        pass
    m.mem[sym['seed']] = 1234 & 255
    m.mem[sym['seed'] + 1] = (1234 >> 8) | 1
    t0 = m.cpu.t
    ticks(m, sym, 750, lambda t: play.s_play(t + 300))
    print('game.wav %.1fs' % render(m.snd, t0, m.cpu.t, os.path.join(OUT, 'game.wav')))


if __name__ == '__main__':
    main()
