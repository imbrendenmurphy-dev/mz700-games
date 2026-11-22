"""music.py - NOVA STORM's tunes and sound effects (-> build/gen_music.inc)

One square-wave voice: 8253 counter 0 plays by itself, so sound costs
almost no CPU.  Two players read these data (src/sound.asm):

* The tracker: a pitch per 50 Hz tick, arranged here at build time in the
  demoscene way - a falling kick into the bass on beats 1 and 3, a click
  of a snare on 2 and 4, plucked melody notes (an octave up for the first
  tick) with vibrato when held, and 50 Hz chord arpeggios filling every
  gap in the tune.
* Effects: two slots stepped ~100 times a second; when both are busy they
  take turns, and while either plays the music waits.

All the music is original.
"""
CLOCK = 1108800                     # 8253 counter 0 input (Hz)

NAMES = {'C': 0, 'C#': 1, 'DB': 1, 'D': 2, 'D#': 3, 'EB': 3, 'E': 4, 'F': 5, 'F#': 6, 'GB': 6,
         'G': 7, 'G#': 8, 'AB': 8, 'A': 9, 'A#': 10, 'BB': 10, 'B': 11}


def midi(tok):
    tok = tok.upper()
    n, o = tok[:-1], int(tok[-1])
    return NAMES[n] + 12 * (o + 1)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def cents(m, c):
    return hz(m) * 2 ** (c / 1200)


def div_of(f):
    return max(2, min(0xFDFF, round(CLOCK / f)))


def chord(name):
    """'Am' -> (root midi in octave 2, [third, fifth] offsets)"""
    minor = name.endswith('m')
    r = name[:-1] if minor else name
    root = NAMES[r.upper()] + 36            # octave 2
    return root, [0, 3 if minor else 4, 7]


def arrange(sixteenth, bars, drums=True, arp_fill=0.7, loop=True):
    """bars: list of (chord name, melody 'N:len ...' in 16ths) -> per-tick Hz"""
    s16 = sixteenth
    bar = 16 * s16
    total = bar * len(bars)
    out = [None] * total
    used = [False] * total

    def put(k, f):
        if 0 <= k < total:
            out[k] = f
            used[k] = True

    # melody note list
    mel = []
    for b, (ch, line) in enumerate(bars):
        t = b * bar
        n16 = 0
        for tok in line.split():
            note, ln = tok.split(':')
            ln = int(ln)
            mel.append((t + n16 * s16, ln * s16, None if note == '.' else midi(note)))
            n16 += ln
        assert n16 == 16, (b, line, n16)
    # drums: kick into the bass on 1 and 3, a snare click on 2 and 4
    if drums:
        for b, (ch, _) in enumerate(bars):
            root, iv = chord(ch)
            t0 = b * bar
            for beat in range(4):
                tb = t0 + beat * 4 * s16
                if beat in (0, 2):
                    put(tb, hz(root + 24))
                    put(tb + 1, hz(root + 12))
                    put(tb + 2, hz(root))
                else:
                    put(tb, 2600)
    # melody
    prev = None
    for start, ln, m in mel:
        if m is None:
            prev = None
            continue
        k = start
        while k < start + ln and used[k]:
            k += 1
        if prev == m and k - 1 >= 0 and not used[k - 1] and out[k - 1] is not None:
            out[k - 1] = None
        age = 0
        first = True
        for tk in range(k, start + ln):
            if used[tk]:
                continue
            if first:
                f = hz(m + 12)
                first = False
            elif age >= 10:
                f = cents(m, (0, 12, 18, 12, 0, -12, -18, -12)[(age // 2) % 8])
            else:
                f = hz(m)
            out[tk] = f
            used[tk] = True
            age += 1
        prev = m
    # gaps: 50 Hz arpeggio of the bar's chord, pulsing with the beat
    for b, (ch, _) in enumerate(bars):
        root, iv = chord(ch)
        arp = [root + 24 + iv[0], root + 24 + iv[1], root + 24 + iv[2]]
        for k in range(bar):
            tk = b * bar + k
            if used[tk]:
                continue
            kb = k % (4 * s16)
            if kb < int(4 * s16 * arp_fill):
                out[tk] = hz(arp[tk % 3])
    return out


# ------------------------------------------------------------------ songs
TITLE = [   # A minor, heroic
    ('Am', 'A4:2 C5:2 E5:4 D5:2 C5:2 B4:2 C5:2'),
    ('F', 'A4:6 F4:2 A4:2 C5:2 F5:4'),
    ('C', 'E5:4 G5:4 E5:2 D5:2 C5:4'),
    ('G', 'D5:6 B4:2 G4:4 .:4'),
    ('Am', 'A4:2 C5:2 E5:4 A5:4 G5:2 E5:2'),
    ('F', 'F5:4 E5:2 D5:2 C5:4 A4:4'),
    ('G', 'B4:2 D5:2 G5:4 F5:2 E5:2 D5:4'),
    ('E', 'E5:8 G#4:4 B4:4'),
    ('F', 'C5:4 F5:4 A5:6 G5:2'),
    ('G', 'G5:4 D5:4 B5:6 A5:2'),
    ('Am', 'A5:4 E5:4 C5:4 E5:4'),
    ('Am', 'A5:12 .:4'),
    ('F', 'A5:2 G5:2 F5:4 E5:2 F5:2 A5:4'),
    ('G', 'B5:2 A5:2 G5:4 F5:2 G5:2 B5:4'),
    ('E', 'G#5:4 B5:4 E6:8'),
    ('E', 'E6:4 D6:2 B5:2 G#5:4 E5:4'),
]

STAGE = [   # D minor, driving
    ('Dm', 'D5:2 .:2 D5:2 F5:2 A5:4 G5:2 F5:2'),
    ('Dm', 'E5:2 F5:2 D5:4 .:8'),
    ('Bb', 'D5:2 .:2 D5:2 F5:2 Bb5:4 A5:2 G5:2'),
    ('C', 'A5:2 G5:2 E5:4 C5:4 .:4'),
    ('Dm', 'D5:2 .:2 D5:2 F5:2 A5:4 C6:4'),
    ('Dm', 'A5:2 F5:2 D5:4 .:8'),
    ('Bb', 'F5:4 D5:4 Bb5:4 A5:2 G5:2'),
    ('A', 'A5:4 E5:4 C#5:4 A4:4'),
    ('Gm', 'G5:6 F5:2 E5:4 D5:4'),
    ('Gm', 'Bb5:6 A5:2 G5:8'),
    ('Dm', 'A5:6 G5:2 F5:4 E5:4'),
    ('Dm', 'D5:8 .:8'),
    ('Bb', 'D5:2 F5:2 Bb5:4 A5:2 G5:2 F5:4'),
    ('C', 'E5:2 G5:2 C6:4 Bb5:2 A5:2 G5:4'),
    ('A', 'A5:4 C#6:4 E6:8'),
    ('A', 'E6:2 .:2 C#6:2 .:2 A5:2 .:2 E5:4'),
]

STAGE2 = [  # G minor, darker (stages 3-5)
    ('Gm', 'G4:2 .:2 Bb4:2 D5:2 G5:4 F5:2 D5:2'),
    ('Eb', 'Eb5:4 D5:2 C5:2 Bb4:4 .:4'),
    ('Gm', 'G4:2 .:2 Bb4:2 D5:2 G5:4 A5:2 Bb5:2'),
    ('D', 'A5:4 F#5:4 D5:4 .:4'),
    ('Cm', 'C5:2 Eb5:2 G5:4 F5:2 Eb5:2 D5:4'),
    ('Gm', 'D5:2 Bb4:2 G4:4 .:8'),
    ('Eb', 'G5:4 Bb5:4 Eb6:4 D6:2 C6:2'),
    ('D', 'D6:8 A5:4 F#5:4'),
]

BOSS = [    # E phrygian ostinato, tense
    ('Em', 'E4:2 E5:2 E4:2 D5:2 E4:2 C5:2 E4:2 B4:2'),
    ('F', 'F4:2 F5:2 F4:2 E5:2 F4:2 C5:2 F4:2 A4:2'),
    ('Em', 'E4:2 E5:2 E4:2 D5:2 E4:2 C5:2 E4:2 B4:2'),
    ('F', 'F4:2 A4:2 C5:2 F5:2 E5:2 C5:2 A4:2 F4:2'),
    ('G', 'G4:2 G5:2 G4:2 F5:2 G4:2 D5:2 G4:2 B4:2'),
    ('F', 'F4:2 F5:2 F4:2 E5:2 F4:2 C5:2 F4:2 A4:2'),
    ('Em', 'E5:4 B4:4 G4:4 E4:4'),
    ('F', 'F4:4 A4:4 C5:4 F5:2 E5:2'),
]

CLEAR = [   # stage clear fanfare (does not loop)
    ('C', 'C5:2 E5:2 G5:2 C6:10'),
    ('Bb', 'Bb5:2 .:2 Bb5:2 .:2 Bb5:2 C6:6'),
    ('C', 'C6:16'),
]

OVER = [    # game over (does not loop)
    ('Am', 'E5:4 D5:4 C5:4 B4:4'),
    ('E', 'A4:8 G#4:4 E4:4'),
    ('Am', 'A4:16'),
]

START = [   # into a stage (does not loop)
    ('Dm', 'D5:2 F5:2 A5:2 D6:6 .:4'),
]

SONGS = [
    ('TRK_TITLE', arrange(5, TITLE), True),
    ('TRK_STAGE', arrange(4, STAGE), True),
    ('TRK_STAGE2', arrange(4, STAGE2), True),
    ('TRK_BOSS', arrange(3, BOSS, arp_fill=0.5), True),
    ('TRK_CLEAR', arrange(4, CLEAR, drums=False), False),
    ('TRK_OVER', arrange(6, OVER, drums=False), False),
    ('TRK_START', arrange(4, START, drums=False), False),
]


# ------------------------------------------------------------------ effects (~100 Hz ticks)
# segment: frames, divisor(2), divisor change per tick(2), mode, arg
#   mode 0 tone, 1 noise (divisor high byte = band, arg = random mask on
#   it, the low byte random), 2 rest, 3 vibrato (divisor +- divisor>>arg)
def hseg(frames, f0, f1=None, mode=0, arg=0):
    d0 = div_of(f0)
    d1 = div_of(f1 if f1 is not None else f0)
    dd = round((d1 - d0) / frames) & 0xFFFF
    return [frames, d0 & 255, d0 >> 8, dd & 255, dd >> 8, mode, arg]


def hsweep(frames, f0, f1, parts=3, mode=0, arg=0):
    out = []
    fr = [frames // parts + (1 if i < frames % parts else 0) for i in range(parts)]
    f = f0
    for i, n in enumerate(fr):
        fn = f0 * (f1 / f0) ** ((i + 1) / parts)
        out += hseg(n, f, fn, mode, arg)
        f = fn
    return out


def hnoise(frames, band, mask=0):
    return [frames, 0, band, 0, 0, 1, mask]


def hrest(frames):
    return [frames, 0, 0, 0, 0, 2, 0]


def notes(seq, frames, mode=3, arg=5):
    out = []
    for n in seq.split():
        out += hseg(frames, hz(midi(n)), None, mode, arg)
    return out


HSFX = {
    'SHOT': hsweep(3, 2600, 1300, 2),
    'LASER': hseg(3, 1700, 1200, 3, 3),
    'HIT': hnoise(1, 0, 1) + hseg(1, 500),
    'POP': hnoise(2, 0, 1) + hnoise(4, 2, 3) + hnoise(6, 5, 7),
    'BOOM': hnoise(3, 0, 1) + hnoise(6, 2, 3) + hnoise(12, 6, 7) + hnoise(18, 14, 15),
    'BIGBOOM': hnoise(4, 0, 3) + hseg(4, 90, 50) + hnoise(10, 4, 7) + hnoise(24, 10, 15)
               + hnoise(40, 20, 31) + hnoise(30, 40, 31),
    'CAPS': hsweep(10, 500, 2400, 3, 3, 4) + notes('C6 E6 G6 C7', 4),
    'MEDAL': notes('B6 E7', 4, 0) + hseg(10, hz(midi('E7')), None, 3, 6),
    'POWER': notes('C5 E5 G5 C6 E6 G6 C7', 3) + hseg(12, hz(midi('C7')), None, 3, 4),
    'BOMB': hnoise(4, 0, 3) + hsweep(30, 120, 1800, 4, 3, 3) + hnoise(20, 2, 7) + hnoise(40, 12, 31),
    'DIE': hnoise(6, 1, 3) + hsweep(60, 900, 70, 5, 3, 3) + hnoise(30, 10, 15) + hnoise(40, 24, 31),
    'ONEUP': (notes('G5 C6 E6 G6', 4) + hrest(3)) * 2 + hseg(20, hz(midi('C7')), None, 3, 5),
    'WARN': (hseg(14, 1000, None, 3, 5) + hseg(14, 700, None, 3, 5)) * 4,
    'SHIELD': hseg(4, 300, 900, 3, 3) + hnoise(4, 1, 3),
    'START': hsweep(40, 150, 1500, 4, 3, 3) + hsweep(16, 1500, 3000, 2, 3, 3),
    'TYPE': hnoise(1, 0, 0),
    'SELECT': hseg(3, 1320) + hseg(4, 1760),
    'EBIG': hsweep(5, 400, 150, 2, 3, 3),
    'SPLIT': hnoise(2, 1, 3) + hsweep(8, 300, 100, 2),
    'TALLY': hseg(2, 2200),
    'SPAWN': hsweep(10, 200, 900, 2, 3, 3),
}


def db(vals, per=18):
    return ['        db ' + ','.join('%d' % v for v in vals[i:i + per]) for i in range(0, len(vals), per)]


def gen_asm():
    out = ['; generated by tools/music.py']
    divs = sorted(set(div_of(f) for _, fr, _ in SONGS for f in fr if f))
    assert len(divs) <= 0xDF, len(divs)
    idx = {d: i + 1 for i, d in enumerate(divs)}
    out.append('TRK_TAB:')
    for i in range(0, len(divs), 12):
        out.append('        dw ' + ','.join('%d' % v for v in divs[i:i + 12]))
    for label, fr, loop in SONGS:
        vals = [idx[div_of(f)] if f else 0 for f in fr]
        stream = []
        i = 0
        while i < len(vals):
            n = 1
            while i + n < len(vals) and vals[i + n] == vals[i] and n < 32:
                n += 1
            stream.append(vals[i])
            if n > 1:
                stream.append(0xE0 + n - 2)
            i += n
        if loop:
            stream.append(0xFF)
        else:
            stream += [0, 0xE0 + 30, 0xFE]
        out.append('%s:' % label)
        out += db(stream)
    for name, prog in HSFX.items():
        out.append('SFX_%s:' % name)
        out += db(prog + [0], 21)
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    p = os.path.join(here, '..', 'build', 'gen_music.inc')
    open(p, 'w').write(gen_asm())
    print('music: %d bytes of source' % os.path.getsize(p))
