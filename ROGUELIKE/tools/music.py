"""music.py - LUMEN's tunes and sound effects (src/sound.asm).

All sound is the 8253 tone generator (counter 0 plays a square wave by
itself), so it costs almost no CPU:

* The tracker: one pitch per 50 Hz tick, arranged here in the demoscene
  way - every melody note starts with a one-tick octave pluck, the bass
  falls into each bar with a kick, chord blips mark the off-beats, held
  notes get vibrato and the gaps fill with fading arpeggios.
* Effects: programs of segments stepped about 100 times a second in two
  slots (they take turns when both play).  Segment: frames, divisor,
  divisor change per tick, mode (0 tone, 1 noise, 2 rest, 3 vibrato), arg.

Every tune is original.
"""
CLOCK = 1108800                     # 8253 counter 0 input

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


# chord: bass root, two blip notes
CHORD = {
    'Am': ('A2', 'C4', 'E4'), 'F': ('F2', 'A3', 'C4'), 'C': ('C3', 'E4', 'G4'), 'G': ('G2', 'B3', 'D4'),
    'E': ('E2', 'G#3', 'B3'), 'Dm': ('D3', 'F4', 'A4'), 'E7': ('E2', 'G#3', 'D4'), 'Bb': ('A#2', 'D4', 'F4'),
    'Em': ('E2', 'G3', 'B3'), 'D': ('D3', 'F#4', 'A4'), 'Gm': ('G2', 'A#3', 'D4'), 'A': ('A2', 'C#4', 'E4'),
    'Cm': ('C3', 'D#4', 'G4'), 'Fm': ('F2', 'G#3', 'C4'), 'Ab': ('G#2', 'C4', 'D#4'), 'Eb': ('D#3', 'G4', 'A#4'),
}

# the title: "The Last Lantern" (A minor, 4/4).  Phrase: 16 beat tokens
# (note, '.' rest, '-' hold) over 4 bars, chords one per bar.
TITLE = [
    ('A4 - C5 E5   F5 - E5 D5   E5 - - C5   D5 - B4 G4', 'Am F C G'),
    ('A4 - C5 E5   F5 E5 D5 C5  B4 - G#4 B4  A4 - - .', 'Am F E Am'),
    ('E5 - D5 C5   D5 - C5 B4   C5 - B4 A4   B4 - - .', 'C G Am E'),
    ('A4 - C5 E5   A5 - G5 F5   E5 - D5 B4   A4 - - .', 'F Dm E7 Am'),
    ('. . C5 D5    E5 - - G5    F5 - E5 D5   C5 - - .', 'Am C F C'),
    ('. . B4 C5    D5 - - F5    E5 - D5 C5   B4 - G#4 .', 'Dm G E E'),
    ('A4 - C5 E5   F5 E5 D5 C5  D5 - B4 G#4  A4 - - -', 'Am F E Am'),
]
# game over: a slow fall
OVER = [('E5 - - D5   C5 - B4 -   A4 - G#4 -  A4 - - .', 'Am Dm E Am')]
# victory
WIN = [
    ('C5 - E5 G5   C6 - - G5   A5 - F5 A5   G5 - - .', 'C C F C'),
    ('E5 - G5 C6   D6 - B5 G5  C6 - - E5    C6 - - -', 'C G G C'),
]
# zone arrival: a short call
ZONE = [('E5 A5 - -   . . . .   . . . .   . . . .', 'Am Am Am Am')]


def tracker(phrases, beat, kick=True, blips=True, fill=True, oct_up=0):
    """-> a list of frequencies (None = silence), one per tick"""
    bar = 4 * beat
    mel, chords = [], []
    t = 0
    for phrase, chs in phrases:
        toks = phrase.split()
        assert len(toks) == 16, phrase
        i = 0
        while i < len(toks):
            n = 1
            while i + n < len(toks) and toks[i + n] == '-':
                n += 1
            tok = toks[i]
            mel.append((t, n * beat, None if tok in '.-' else midi(tok) + oct_up))
            t += n * beat
            i += n
        chords += chs.split()
    total = t
    out = [None] * total
    used = [False] * total

    def put(k, f):
        if 0 <= k < total:
            out[k] = f
            used[k] = True

    for b, c in enumerate(chords):
        root, p1, p2 = CHORD[c]
        r = midi(root)
        t0 = b * bar
        if kick:
            put(t0, hz(r + 24))
            put(t0 + 1, hz(r + 12))
            put(t0 + 2, hz(r))
            put(t0 + 3, cents(r, -40))
            put(t0 + 2 * beat, hz(r + 12))
            put(t0 + 2 * beat + 1, hz(r))
        if blips:
            for k in (1, 3):
                tb = t0 + k * beat
                put(tb, hz(midi(p1) + 12))
                put(tb + 1, hz(midi(p2) + 12))
    prev = None
    for start, ln, m in mel:
        if m is None:
            prev = None
            continue
        k = start
        while k < start + ln and used[k]:
            k += 1
        if prev == m and k - 1 >= start and not used[k - 1]:
            out[k - 1] = None
        age = 0
        first = True
        for tk in range(k, start + ln):
            if used[tk]:
                continue
            if first:
                f = hz(m + 12)
                first = False
            elif age >= 9:
                f = cents(m, (0, 14, 20, 14, 0, -14, -20, -14)[(age // 2) % 8])
            else:
                f = hz(m)
            out[tk] = f
            used[tk] = True
            age += 1
        prev = m
    if fill:
        for b, c in enumerate(chords):
            root, p1, p2 = CHORD[c]
            arp = [midi(root) + 24, midi(p1) + 12, midi(p2) + 12]
            for k in range(bar):
                tk = b * bar + k
                if tk < total and not used[tk] and (k % beat) < beat - 3:
                    out[tk] = hz(arp[tk % 3])
                    used[tk] = True
    return out


# ------------------------------------------------------------------ effects
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


SFX = {
    'HIT': hnoise(2, 0, 1) + hseg(4, 900, 300, 3, 4),
    'MISS': hsweep(6, 1200, 1600, 2, 0),
    'HURT': hnoise(3, 3, 3) + hseg(5, 160, 110, 3, 3) + hnoise(4, 8, 7),
    'KILL': hnoise(3, 0, 1) + hseg(4, 1047, None, 3, 4) + hseg(6, 1568, None, 3, 4),
    'FIRE': hnoise(3, 1, 1) + hsweep(14, 400, 1400, 3, 3, 3) + hnoise(6, 2, 3),
    'FROST': hsweep(16, 2600, 1800, 3, 3, 2) + hseg(6, 3200, None, 3, 2),
    'ZAP': hnoise(4, 0, 0) + hsweep(10, 3000, 600, 3, 3, 2) + hnoise(10, 0, 1),
    'BOOM': hnoise(4, 0, 1) + hnoise(8, 2, 3) + hnoise(16, 5, 7) + hnoise(26, 10, 15) + hnoise(20, 20, 31),
    'PICKUP': hseg(4, 1319, None, 0) + hseg(6, 1976, None, 0),
    'GOLD': hseg(3, 1568, None, 0) + hseg(3, 2093, None, 0) + hseg(6, 2637, None, 3, 5),
    'DOOR': hnoise(3, 6, 3) + hseg(6, 220, 180, 3, 4),
    'GATE': hseg(8, 523, None, 3, 5) + hseg(8, 659, None, 3, 5) + hseg(8, 784, None, 3, 5) +
            hseg(20, 1047, None, 3, 5),
    'LEVEL': hsweep(20, 400, 1600, 4, 3, 4) + hseg(8, 1600, None, 3, 4) + hseg(16, 2093, None, 3, 4),
    'DRINK': hseg(4, 600, 900, 0) + hrest(2) + hseg(4, 700, 1000, 0) + hrest(2) + hseg(6, 800, 1200, 0),
    'BLINK': hsweep(20, 300, 3000, 4, 3, 2),
    'HEAL': hseg(6, 784, None, 3, 5) + hseg(6, 988, None, 3, 5) + hseg(14, 1175, None, 3, 5),
    'DENY': hseg(6, 180, None, 0) + hrest(3) + hseg(8, 150, None, 0),
    'STAIRS': hsweep(30, 1200, 200, 5, 3, 3),
    'FLARE': hsweep(12, 800, 2400, 3, 3, 3) + hnoise(8, 0, 1),
    'PUSH': hnoise(6, 12, 7),
    'BURN': hnoise(4, 2, 3) + hsweep(14, 300, 900, 3, 3, 3),
    'CHEST': hseg(4, 330, None, 0) + hseg(4, 440, None, 0) + hseg(8, 660, None, 3, 4),
    'LEVER': hnoise(2, 1, 0) + hseg(5, 500, 400, 0),
    'BEAM': hseg(30, 1760, None, 3, 6),
    'POISON': hnoise(6, 4, 7) + hseg(8, 250, 200, 3, 3),
    'TALK': hseg(2, 880, None, 0) + hrest(2) + hseg(2, 990, None, 0),
    'SPLASH': hnoise(10, 3, 7) + hnoise(10, 8, 15),
    'BOSS': hsweep(40, 90, 60, 3, 3, 3) + hnoise(20, 14, 15),
}


def db(vals, per=18):
    return ['        db ' + ','.join('%d' % v for v in vals[i:i + per]) for i in range(0, len(vals), per)]


def gen_asm():
    out = ['; generated by tools/music.py']
    songs = [('TRK_TITLE', tracker(TITLE, 12), True),
             ('TRK_OVER', tracker(OVER, 20, blips=False), False),
             ('TRK_WIN', tracker(WIN, 10), True),
             ('TRK_ZONE', tracker(ZONE, 8, kick=False, blips=False, fill=False), False)]
    divs = sorted(set(div_of(f) for _, fr, _ in songs for f in fr if f))
    assert len(divs) <= 0xDF, len(divs)
    idx = {d: i + 1 for i, d in enumerate(divs)}
    out.append('TRK_TAB:')
    for i in range(0, len(divs), 12):
        out.append('        dw ' + ','.join('%d' % v for v in divs[i:i + 12]))
    for label, fr, loop in songs:
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
    for name, prog in SFX.items():
        out.append('SFX_%s:' % name)
        out += db(prog)
        out.append('        db 0')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    s = gen_asm()
    print(len(s), 'chars')
