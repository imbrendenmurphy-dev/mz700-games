"""wav.py - record STARHAUL's speaker in the simulator and write WAV files.

    py tools/wav.py SCENE [seconds]      -> build/sound/SCENE.wav

Scenes:
    title   the title screen: the tracker waltz on the tone generator
    launch  start a game: the launch tunnel, then flight
    dock    start a game, then dock at once: docking sound and the waltz
    hyper   start a game, then jump: the hyperspace screen
    death   start a game, then blow up
    demo    the attract demo: flight sounds on the tone generator
    fight   three pirates close ahead, lasers held down: flight effects
    over    blow up and wait for the game-over tune

The speaker follows OUT0 of 8253 counter 0: a control word sets it at once
(mode 0 low, other modes high); in mode 3 with the gate on, counter 0 makes
a square wave of 1108800 / count Hz; with the gate off it stays high.
"""
import os
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402
from mzsim import CPU_HZ  # noqa: E402

CLOCK = 1108800
RATE = 44100


def render(log, t0, t1, init=(0, 0, 0, 1)):
    """OUT0 as samples at RATE between CPU times t0 and t1"""
    fine = 8                                     # sub-samples per output sample
    n = int((t1 - t0) / CPU_HZ * RATE)
    ts = t0 + (np.arange(n * fine) + 0.5) * (CPU_HZ / (RATE * fine))
    out = np.zeros(n * fine, dtype=np.float32)
    mode, count, gate, lvl = init
    running = False
    start = t0
    for t, kind, v in log:                       # the state at t0
        if t >= t0:
            break
        if kind == 'm':
            m = (v >> 1) & 7
            mode = m - 4 if m >= 6 else m
            lvl = 0 if mode == 0 else 1
            running = False
        elif kind == 'n':
            count = v
            running = mode == 3
            start = t
        elif kind == 'g':
            if v and not gate and mode == 3:
                start = t
            gate = v
    ev = [e for e in log if t0 <= e[0] < t1] + [(t1, 'end', 0)]
    seg_t = t0
    for t, kind, v in ev:
        a = np.searchsorted(ts, seg_t)
        b = np.searchsorted(ts, t)
        if b > a:
            if mode == 3 and running and gate:
                per = count or 65536
                clk = (ts[a:b] - start) * (CLOCK / CPU_HZ)
                out[a:b] = ((clk % per) < per / 2).astype(np.float32)
            else:
                out[a:b] = lvl
        seg_t = t
        if kind == 'm':
            m = (v >> 1) & 7
            mode = m - 4 if m >= 6 else m
            lvl = 0 if mode == 0 else 1
            running = False
        elif kind == 'n':
            count = v
            if mode == 3:
                running = True
                start = t
        elif kind == 'g':
            if v and not gate and mode == 3:
                start = t
            gate = v
            if not gate:
                lvl = 1 if mode != 0 else lvl
    s = out.reshape(n, fine).mean(axis=1)
    # the speaker is AC coupled: take out the DC with a gentle high-pass
    y = np.empty_like(s)
    acc = s[0] if n else 0.0
    k = 1.0 - 2 * np.pi * 20 / RATE
    prev = acc
    for i in range(n):
        acc = k * acc + (1 - k) * s[i]
        y[i] = s[i] - acc
    return y


def write(path, y):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.clip(y * 0.9 * 32767, -32767, 32767).astype('<i2')
    w = wave.open(path, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(pcm.tobytes())
    w.close()


def start_game(g):
    g.launch(0)


def scene(name, secs):
    g = Game()
    m = g.m
    if name == 'title':
        g.run(5)
    elif name in ('launch',):
        g.run(60)
        g.run(8, ['space'])
        g.run(80)                                # docked at the home station
        m.spk_log = []
        t0 = m.cpu.t
        g.run(8, ['space'])
        g.run(secs * 50 - 8)
        return m, t0
    elif name == 'fight':
        start_game(g)
        g.run(90)
        mem = m.mem
        ob = S['objects']

        def w16(a, v):
            mem[a] = v & 255
            mem[a + 1] = (v >> 8) & 255
        for k, (x, y, z, t) in enumerate([(-30, 10, 700, 3), (40, -20, 900, 2), (0, 30, 1300, 4)], 1):
            base = ob + 32 * k
            mem[base:base + 32] = mem[ob:ob + 32]
            mem[base] = t
            mem[base + 1] = 0
            w16(base + 2, x)
            w16(base + 4, y)
            w16(base + 6, z)
            mem[base + 26:base + 32] = bytes([0, 2, 0, 200, 0, 0])
        w16(ob + 6, -6000)
        mem[S['spawn_t']] = 255
        t0 = m.cpu.t
        for i in range(int(secs * 50) // 10):
            g.run(10, ['space'] if i % 3 != 2 else [])
        return m, t0
    elif name == 'demo':
        g.run(5)
        g.m.mem[S['att_t']] = 2
        g.m.mem[S['att_t'] + 1] = 0
        g.run(40)
    else:
        start_game(g)
        g.run(90)                                # through the tunnel, into flight
        if name == 'dock':
            m.mem[S['state']] = 1
        elif name == 'hyper':
            m.mem[S['state']] = 3
        elif name in ('death', 'over'):
            m.mem[S['energy']] = 0
            m.mem[S['shield']] = 0
            for k in range(1, 8):                # a shot from nowhere: empty the sky
                m.mem[S['objects'] + 32 * k] = 0
    t0 = m.cpu.t
    g.run(secs * 50)
    return m, t0


if __name__ == '__main__':
    name = sys.argv[1] if len(sys.argv) > 1 else 'title'
    secs = float(sys.argv[2]) if len(sys.argv) > 2 else 12
    m, t0 = scene(name, secs)
    y = render(m.spk_log, t0, m.cpu.t)
    out = os.path.join(ROOT, 'build', 'sound', name + '.wav')
    write(out, y)
    print(out, '%.1f s' % (len(y) / RATE), len(m.spk_log), 'speaker events')
