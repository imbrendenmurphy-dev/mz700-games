"""music.py - songs and sound effects for STARHAUL (src/sound.asm).

Two players read these data:

* The 3-voice mixer, used on the title, docked, menu, hyperspace, launch,
  game over and death screens.  Three pulse-width voices are interleaved on
  the 1-bit speaker, as on the VZ300 (writes of 8253 control words drive
  OUT0 low or high).  A voice's duty is its loudness, so notes can pluck and
  fade.  Voice 2 can also play white noise.  It plays only while the program
  waits for a frame, so it is for screens with little work per frame.

* The 8253 tone generator in flight, where the 3D view needs all the CPU.
  Counter 0 plays a square wave by itself.  There are two effect slots,
  stepped about 100 times a second (at both edges of the vertical blank);
  when both are busy they take turns tick by tick, so a laser can sound
  over an explosion.  With no effect playing, the music voices (the auto-dock
  waltz) take turns on it in the same way.

The waltz is an original arrangement of Johann Strauss II's "An der
schoenen blauen Donau" (1866, public domain): the opening waltz theme with
an oom-pah-pah bass and a soft chord pad.
"""
CPU = 3546894                       # Z80 clock (PAL MZ-700)
CLOCK = 1108800                     # 8253 counter 0 input
SAMPLE_T = 216                      # T-states per mixer sample (src/sound.asm)
SR = CPU / SAMPLE_T                 # ~17.2 kHz

NAMES = {'C': 0, 'C#': 1, 'DB': 1, 'D': 2, 'D#': 3, 'EB': 3, 'E': 4, 'F': 5, 'F#': 6, 'GB': 6,
         'G': 7, 'G#': 8, 'AB': 8, 'A': 9, 'A#': 10, 'BB': 10, 'B': 11}


def midi(tok):
    tok = tok.upper()
    n, o = tok[:-1], int(tok[-1])
    return NAMES[n] + 12 * (o + 1)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def step_of(f):
    """mixer phase step (16-bit accumulator per sample) for f Hz"""
    return max(0, min(0x7FFF, round(f * 65536 / SR)))


def div_of(f):
    """8253 divisor for f Hz"""
    return max(2, min(0xFDFF, round(CLOCK / f)))


# note byte n (1..95) = midi n+23 (1 = C1)
NOTE_MIDI0 = 23


def note_byte(tok):
    n = midi(tok) - NOTE_MIDI0
    assert 1 <= n <= 0x5F, tok
    return n


# ------------------------------------------------------------------ instruments
# dstart, decay per tick, floor, flags (bit 0 noise, bit 1 vibrato)
INSTR = {
    'lead':  (0x70, 2, 0x34, 2),
    'bass':  (0x78, 4, 0x10, 0),
    'pah':   (0x46, 5, 0x00, 0),
    'pad':   (0x24, 0, 0x24, 0),
    'slow':  (0x68, 1, 0x30, 2),
    'bell':  (0x60, 3, 0x00, 0),
}
INAMES = list(INSTR)


class Voice:
    """one music voice: a list of (note token or None, ticks, instrument)"""

    def __init__(self):
        self.ev = []

    def add(self, tok, ticks, ins):
        self.ev.append((tok, ticks, ins))

    def encode(self, label, loop):
        out = []
        cur_len = None
        cur_ins = None
        for tok, ticks, ins in self.ev:
            if ins != cur_ins and tok is not None:
                out.append(0x80 + INAMES.index(ins))
                cur_ins = ins
            if ticks != cur_len:
                if ticks <= 32:
                    out.append(0x5F + ticks)
                else:
                    assert ticks < 256
                    out += [0x91, ticks]
                cur_len = ticks
            out.append(0 if tok is None else note_byte(tok))
        lines = ['%s:' % label]
        for i in range(0, len(out), 16):
            lines.append('        db ' + ','.join('%d' % v for v in out[i:i + 16]))
        if loop:
            lines.append('        db 0FEh')
            lines.append('        dw %s' % label)
        else:
            lines.append('        db 0FFh')
        return lines


# ------------------------------------------------------------------ the waltz
# One bar = 3 beats.  Each phrase: 12 beat tokens (a note, '.' silence or
# '-' hold) and the chord of each of its 4 bars.
WALTZ = [
    ('D4 D4 F#4  A4 - -  . A5 A5  . F#5 F#5', 'D D D D'),
    ('D4 D4 F#4  A4 - -  . A5 A5  . G5 G5', 'D D A A'),
    ('C#4 C#4 E4  B4 - -  . B5 B5  . G5 G5', 'A A A A'),
    ('C#4 C#4 E4  B4 - -  . B5 B5  . F#5 F#5', 'A A D D'),
    ('D4 D4 F#4  A4 D5 -  . D6 D6  . A5 A5', 'D D D D'),
    ('D4 D4 F#4  A4 D5 -  . D6 D6  . B5 B5', 'D D G G'),
    ('E4 E4 G4  B4 - -  G#4 A4 -  F#5 - -', 'Em Em E D'),
    ('D5 F#4 -  F#4 E4 B4  A4 - -  D4 . .', 'D A A D'),
]
# chord: bass root, the two "pah" notes, pad note
CHORD = {
    'D': ('D3', 'F#3', 'A3', 'F#4'),
    'A': ('A2', 'C#3', 'E3', 'E4'),
    'G': ('G2', 'B2', 'D3', 'D4'),
    'E': ('E3', 'G#3', 'B3', 'G#4'),
    'Em': ('E3', 'G3', 'B3', 'G4'),
}
BEAT = 14                           # ticks (50 Hz): one bar = 0.84 s


def melody_voice(beats, ins, beat=BEAT, v=None):
    v = v or Voice()
    toks = beats.split()
    i = 0
    while i < len(toks):
        t = toks[i]
        n = 1
        while i + n < len(toks) and toks[i + n] == '-':
            n += 1
        v.add(None if t in '.-' else t, n * beat, ins)
        i += n
    return v


def waltz():
    lead, bass, pad = Voice(), Voice(), Voice()
    for mel, chords in WALTZ:
        assert len(mel.split()) == 12, mel
        melody_voice(mel, 'lead', v=lead)
        for c in chords.split():
            root, p1, p2, pn = CHORD[c]
            bass.add(root, BEAT, 'bass')
            bass.add(p1, BEAT, 'pah')
            bass.add(p2, BEAT, 'pah')
            pad.add(pn, 3 * BEAT, 'pad')
    return [lead, bass, pad], True


def game_over():
    b = 18
    lead = melody_voice('A4 - G4  F4 - E4  D4 - C#4  D4 - -  . . .', 'slow', beat=b)
    bass, pad = Voice(), Voice()
    for root, pn in (('D3', 'F4'), ('A#2', 'D4'), ('A2', 'C#4'), ('D2', 'A3')):
        bass.add(root, 3 * b, 'bass')
        pad.add(pn, 3 * b, 'pad')
    bass.add(None, 3 * b, 'bass')
    pad.add(None, 3 * b, 'pad')
    return [lead, bass, pad], False


def fanfare():
    """docked: a short rising chime before the waltz"""
    lead = melody_voice('G4 C5 E5 G5 - -', 'bell', beat=6)
    bass = melody_voice('C3 - - G3 - -', 'bass', beat=6)
    pad = melody_voice('. E4 - C5 - -', 'pad', beat=6)
    return [lead, bass, pad], False


SONGS = {'SONG_WALTZ': waltz, 'SONG_OVER': game_over}


# ------------------------------------------------------------------ mixer effects (50 Hz ticks)
# segment: frames, step(2), step change per tick(2), duty, duty change, mode, arg
#   mode 0 tone, 1 noise (voice 2 only: arg unused), 2 rumble (the step gets
#   a random 0 .. arg*256+255 added every tick)
def mseg(frames, f0, f1=None, duty=0x60, duty1=None, mode=0, arg=0):
    s0 = step_of(f0)
    s1 = step_of(f1 if f1 is not None else f0)
    df = round((s1 - s0) / frames) & 0xFFFF
    d1 = duty if duty1 is None else duty1
    dd = max(-128, min(127, round((d1 - duty) / frames))) & 0xFF
    out = []
    while frames > 0:
        n = min(frames, 255)
        out += [n, s0 & 255, s0 >> 8, df & 255, df >> 8, duty, dd, mode, arg]
        frames -= n
    return out


def msweep(frames, f0, f1, duty, duty1, parts=4, mode=0, arg=0):
    """exponential pitch sweep as a few linear pieces"""
    out = []
    fr = [frames // parts + (1 if i < frames % parts else 0) for i in range(parts)]
    f = f0
    d = duty
    for i, n in enumerate(fr):
        fn = f0 * (f1 / f0) ** ((i + 1) / parts)
        dn = duty + (duty1 - duty) * (i + 1) / parts
        out += mseg(n, f, fn, round(d), round(dn), mode, arg)
        f, d = fn, dn
    return out


def mnoise(frames, duty, duty1=None):
    return mseg(frames, 4000, None, duty, duty1, mode=1)


MSFX = {
    # name: (voice 0, voice 1, voice 2) programs
    'BEEP': (None, None, mseg(2, 1320, None, 0x50, 0x20) + mseg(2, 1760, None, 0x30, 0x08)),
    'BUY': (None, None, mseg(3, 1568, None, 0x60, 0x30) + mseg(8, 2093, None, 0x58, 0x04)),
    'OUCH': (None, None, mseg(4, 180, 150, 0x80, 0x50, mode=2, arg=0) + mseg(6, 120, 100, 0x60, 0x08, mode=2)),
    'DOCK': (mseg(3, 70, 50, 0x80, 0x40, mode=2, arg=0) + mseg(6, 45, 40, 0x50, 0x00, mode=2),
             None,
             mnoise(3, 0x08, 0x40) + mnoise(30, 0x40, 0x02)),
    'JUMP': (msweep(80, 80, 2600, 0x40, 0x78, 6) + mseg(28, 60, 40, 0x80, 0x00, mode=2, arg=1),
             msweep(80, 120, 3900, 0x20, 0x60, 6) + msweep(20, 3000, 200, 0x60, 0x00, 3),
             mnoise(60, 0x04, 0x60) + mnoise(20, 0x60, 0x20) + mnoise(28, 0x70, 0x00)),
    'LAUNCH': (msweep(45, 180, 1100, 0x30, 0x60, 4) + msweep(10, 1100, 700, 0x60, 0x00, 2),
               mseg(55, 55, 70, 0x60, 0x10, mode=2, arg=0),
               mnoise(15, 0x04, 0x50) + mnoise(40, 0x50, 0x00)),
    'DEATH': (mseg(10, 90, 60, 0x80, 0x70, mode=2, arg=2) + mseg(90, 60, 30, 0x70, 0x00, mode=2, arg=1),
              msweep(70, 500, 40, 0x70, 0x00, 5),
              mnoise(8, 0x80, 0x78) + mnoise(110, 0x78, 0x00)),
    'SAVE': (mseg(4, 1047, None, 0x50, 0x30), mseg(4, 1319, None, 0x40, 0x30) + mseg(10, 1568, None, 0x50, 0x00),
             None),
}


# ------------------------------------------------------------------ flight effects (~100 Hz ticks)
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


HSFX = {
    'LASER': hseg(2, 3000, None, 3, 3) + hsweep(12, 2400, 520, 3, 3, 3),
    'HIT': hnoise(3, 0, 1) + hseg(6, 700, 220, 3, 4) + hnoise(3, 2, 3),
    'BOOM': hnoise(4, 0, 1) + hnoise(8, 2, 3) + hnoise(16, 5, 7) + hnoise(26, 10, 15) + hnoise(30, 20, 31),
    'OUCH': hnoise(3, 3, 3) + hseg(4, 130, None, 3, 3) + hnoise(3, 6, 7) + hseg(4, 95, None, 3, 3)
            + hnoise(8, 12, 15),
    'ZAP': hnoise(4, 4, 3) + hsweep(26, 300, 1700, 3, 3, 3) + hnoise(6, 1, 1),
    'ALARM': (hseg(12, 880, None, 3, 5) + hseg(12, 620, None, 3, 5)) * 4,
    'WARN': hseg(6, 1400, None, 3, 6) + hrest(5) + hseg(6, 1400, None, 3, 6) + hrest(10),
    'CRASH': hnoise(6, 2, 7) + hnoise(14, 8, 15) + hnoise(24, 18, 31),
    'SCOOP': hseg(5, 660, None, 3, 4) + hseg(5, 880, None, 3, 4) + hseg(5, 1320, None, 3, 4)
             + hseg(10, 1760, None, 3, 4),
    'JAM': hsweep(30, 1400, 300, 3, 3, 2) + hnoise(6, 1, 3),
    'BEEP': hseg(5, 1320, None, 0) + hseg(4, 1760, None, 0),
    'KILL': hnoise(3, 0, 1) + hseg(4, 1047, None, 3, 4) + hseg(8, 1568, None, 3, 4),
    'BUY': hseg(4, 1568, None, 3, 5) + hseg(10, 2093, None, 3, 5),
    'SAVE': hseg(6, 1047, None, 3, 5) + hseg(6, 1319, None, 3, 5) + hseg(14, 1568, None, 3, 5),
    'DOCK': hnoise(6, 6, 7) + hsweep(24, 220, 70, 3, 3, 3) + hnoise(10, 16, 15),
    'JUMP': hsweep(70, 90, 2600, 7, 3, 3) + hnoise(10, 2, 3) + hnoise(24, 12, 15),
    'LAUNCH': hsweep(40, 180, 1100, 4, 3, 3) + hsweep(14, 1100, 600, 2, 3, 3),
    'DEATH': hnoise(8, 1, 3) + hnoise(20, 6, 7) + hnoise(40, 14, 15) + hnoise(60, 26, 31),
}

# every effect the game names: SFX_x -> (flight program, mixer program)
SFX = ['LASER', 'HIT', 'BOOM', 'OUCH', 'ZAP', 'ALARM', 'WARN', 'CRASH', 'SCOOP', 'JAM', 'BEEP', 'KILL',
       'BUY', 'DOCK', 'JUMP', 'LAUNCH', 'DEATH', 'SAVE']


# ------------------------------------------------------------------ the tracker
# One square-wave channel, a pitch per 50 Hz tick, as demoscene players
# on the MZ-700 do it (Genesis Project's "Sharper" is the model): every
# note starts with a one-tick octave pluck, the "oom" is a falling kick
# into the bass note, each "pah" a quick two-note chord blip, held notes
# get a slow vibrato, and gaps in the tune fill with a fading arpeggio.
def cents(m, c):
    return hz(m) * 2 ** (c / 1200)


def tracker_waltz():
    """-> a list of frequencies (None = silence), one per tick"""
    beat = BEAT
    bar = 3 * beat
    mel = []                                     # (start tick, ticks, midi or None)
    t = 0
    chords = []
    for phrase, chs in WALTZ:
        toks = phrase.split()
        i = 0
        while i < len(toks):
            n = 1
            while i + n < len(toks) and toks[i + n] == '-':
                n += 1
            tok = toks[i]
            mel.append((t, n * beat, None if tok in '.-' else midi(tok)))
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

    # rhythm: the oom (a kick falling into the root) and the pahs
    for b, c in enumerate(chords):
        root, p1, p2, _ = CHORD[c]
        r = midi(root)
        t0 = b * bar
        put(t0, hz(r + 24))
        put(t0 + 1, hz(r + 12))
        put(t0 + 2, hz(r))
        put(t0 + 3, cents(r, -30))
        for k in (1, 2):
            tb = t0 + k * beat
            put(tb, hz(midi(p1) + 12))
            put(tb + 1, hz(midi(p2) + 12))
    # the tune: plucked, with vibrato on held notes
    prev = None
    for start, ln, m in mel:
        if m is None:
            prev = None
            continue
        k = start
        while k < start + ln and used[k]:
            k += 1
        if prev == m and k - 1 >= start and not used[k - 1]:
            out[k - 1] = None                   # a gap between repeated notes
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
    # rests in the tune: an arpeggio of the bar's chord that fades out
    for b, c in enumerate(chords):
        root, p1, p2, pn = CHORD[c]
        arp = [midi(root) + 24, midi(p1) + 12, midi(p2) + 12]
        for k in range(bar):
            tk = b * bar + k
            if used[tk]:
                continue
            kb = k % beat
            if kb < 9:
                out[tk] = hz(arp[tk % 3])
                used[tk] = True
    return out


def tracker_over():
    """the game-over tune: a slow falling line over a bass note a bar,
    each note plucked, held ones with vibrato; it does not loop"""
    b = 18
    mel = 'A4 - G4  F4 - E4  D4 - C#4  D4 - -  . . .'.split()
    roots = ['D3', 'A#2', 'A2', 'D2', None]
    out = []
    i = 0
    notes = []
    while i < len(mel):
        n = 1
        while i + n < len(mel) and mel[i + n] == '-':
            n += 1
        notes.append((None if mel[i] in '.-' else midi(mel[i]), n * b))
        i += n
    t = 0
    for m, ln in notes:
        for k in range(ln):
            tk = t + k
            bar, kb = divmod(tk, 3 * b)
            root = roots[bar] if bar < len(roots) else None
            if root and kb < 3:                     # the bass, a note a bar
                out.append(hz(midi(root) + (12 if kb == 0 else 0)))
            elif m is None:
                out.append(None)
            elif k == 0 or (k <= 3 and out and out[-1] is None):
                out.append(hz(m + 12))              # pluck
            elif k >= 10:
                out.append(cents(m, (0, 15, 22, 15, 0, -15, -22, -15)[(k // 2) % 8]))
            else:
                out.append(hz(m))
        t += ln
    return out


def tracker_stream(freqs, label):
    """compress per-tick frequencies: a divisor table plus a byte stream"""
    divs = [0 if f is None else div_of(f) for f in freqs]
    table = sorted(set(d for d in divs if d))
    assert len(table) <= 0xDF, len(table)
    idx = {d: i + 1 for i, d in enumerate(table)}
    stream = []
    i = 0
    while i < len(divs):
        v = idx.get(divs[i], 0)
        n = 1
        while i + n < len(divs) and divs[i + n] == divs[i] and n < 32:
            n += 1
        stream.append(v)
        if n > 1:
            stream.append(0xE0 + n - 2)
        i += n
    stream.append(0xFF)
    return table, stream


def db(vals, per=18):
    return ['        db ' + ','.join('%d' % v for v in vals[i:i + per]) for i in range(0, len(vals), per)]


def gen_asm():
    out = ['; generated by tools/music.py']
    songs = [('TRK_WALTZ', tracker_waltz(), True), ('TRK_OVER', tracker_over(), False)]
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
            stream += [0, 0xE0 + 30, 0xFE]           # silence, then stop
        out.append('%s:' % label)
        out += db(stream)
    for name in SFX:
        out.append('SFX_%s:' % name)
        out += db(HSFX[name])
        out.append('        db 0')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    s = gen_asm()
    print(s[:1500])
    print(len(s), 'chars')
