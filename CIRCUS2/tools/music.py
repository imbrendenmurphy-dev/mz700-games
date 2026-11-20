"""music.py - songs and sound effects for CIRCUS 2 (one 8253 square voice).

Songs are tracker-style: each row lasts `speed` fields (50 Hz) and holds a
lead note, a bass note, a drum and an effect.  The player gives the voice
to the drum, then a short bass pluck, then the lead (see src/sound.asm).

The tunes are the VZ300 game's own: the two-voice circus march, the act
jingle (the original Circus tune, reharmonised), the BRAVO fanfare and the
sad trombone, rearranged for one voice with drums.
"""
CLOCK = 1108800
NOTE_BASE = 20                      # NOTETAB index = midi - NOTE_BASE

NAMES = {'C': 0, 'C#': 1, 'DB': 1, 'D': 2, 'D#': 3, 'EB': 3, 'E': 4, 'F': 5, 'F#': 6, 'GB': 6,
         'G': 7, 'G#': 8, 'AB': 8, 'A': 9, 'A#': 10, 'BB': 10, 'B': 11}


def midi(tok):
    tok = tok.upper().replace('S', '#')
    n, o = tok[:-1], int(tok[-1])
    return NAMES[n] + 12 * (o + 1)


def notetab():
    vals = []
    for i in range(128):
        m = i + NOTE_BASE
        f = 440.0 * 2 ** ((m - 69) / 12)
        d = round(CLOCK / f)
        vals.append(max(2, min(65535, d)))
    vals[0] = 0
    return vals


def note_byte(tok):
    if tok == '-':
        return 0
    if tok == '.':
        return 1
    idx = midi(tok) - NOTE_BASE
    assert 1 <= idx < 127, tok
    return idx + 1


DRUM = {'.': 0, 'k': 1, 's': 2, 'h': 3}


def pattern_rows(L, B, D, F):
    n = len(L)
    assert len(B) == n and len(D) == n and len(F) == n, (len(L), len(B), len(D), len(F))
    out = []
    for i in range(n):
        out += [note_byte(L[i]), note_byte(B[i]), DRUM[D[i]], F[i]]
    return out + [0xFF]


def expand(events, unit):
    """[(note, dur), ...] with dur in VZ ticks -> row tokens (unit ticks per row)"""
    out = []
    for note, dur in events:
        n = max(1, round(dur / unit))
        if note == 'RST':
            out += ['.'] + ['-'] * (n - 1)
        else:
            out += [note] + ['-'] * (n - 1)
    return out


def parse(s):
    toks = s.split()
    return [(toks[i], int(toks[i + 1])) for i in range(0, len(toks), 2)]


# ------------------------------------------------------------------ the VZ tunes (note, ticks @ 25 Hz)
TITLE_LEAD = parse('''
E5 4 D#5 4 E5 4 C5 4  A4 4 G#4 4 A4 4 F4 4  D4 4 F4 4 A4 4 C5 4  B4 8 G4 8
D5 4 C#5 4 D5 4 B4 4  G4 4 F#4 4 G4 4 E4 4  C4 4 E4 4 G4 4 B4 4  C5 8 RST 8
G5 4 E5 4 C5 4 E5 4  G5 8 E5 8  F5 4 D5 4 B4 4 D5 4  F5 8 D5 8
E5 4 F5 4 G5 4 A5 4  G5 4 F5 4 E5 4 D5 4  C5 4 E5 4 D5 4 B4 4  C5 8 C4 8''')
# bass roots, one per beat (the VZ "oom-pah" voice without its rests)
TITLE_BASS = '''C3 G2 F2 C3 D3 A2 G2 D3 G2 D3 C3 G2 C3 G2 C3 G2
C3 G2 C3 E3 G2 D3 G2 B2 C3 G2 G2 D3 G2 B2 C3 G2'''.split()

JINGLE_LEAD = parse('''C5 4 A5 5 G5 2 F5 4 G5 4 F5 4 D5 4 C5 4 A4 7 RST 4
C5 4 D5 4 G5 4 F5 4 E5 4 D5 4 E5 4 F5 10''')
JINGLE_BASS = parse('F2 8 C3 8 F2 8 C3 8 F2 8 C3 7 A#2 8 C3 8 C3 8 F2 9')

CLEAR_LEAD = parse('C5 3 E5 3 G5 3 C6 9 G5 3 C6 14')
CLEAR_BASS = parse('C3 9 G2 9 C3 17')

OVER_LEAD = parse('G4 8 F#4 8 F4 8 E4 24')
OVER_BASS = parse('C3 8 B2 8 A#2 8 A2 24')


def bass_line(events, unit, n):
    """bass tokens from (note, ticks) events, padded / cut to n rows"""
    toks = expand(events, unit)
    toks = (toks + ['-'] * n)[:n]
    return toks


SONGS = {}


def title_song():
    lead = expand(TITLE_LEAD, 2)            # speed 4: a row is 2 VZ ticks
    n = len(lead)
    assert n == 128, n
    bass = []
    for root in TITLE_BASS:                 # a beat = 4 rows: oom (root) . pah (fifth up) .
        bass += [root, '-', '-', '-']
    drums = []
    for bar in range(n // 16):
        drums += list('k.h.s.h.k.h.s.hh' if bar % 4 == 3 else 'k.h.s.h.k.h.s.h.')
    fx = [0] * n
    run = 0
    for k, t in enumerate(lead):            # octave shimmer on held notes
        run = run + 1 if t == '-' else 0
        if run >= 2:
            fx[k] = 3
    pats = []
    for p in range(0, n, 32):
        pats.append(pattern_rows(lead[p:p + 32], bass[p:p + 32], drums[p:p + 32], fx[p:p + 32]))
    return dict(speed=4, pats=pats, loop=True, loop_from=0)


def jingle(lead_ev, bass_ev, speed, drums=None, unit=1, fx=0):
    lead = expand(lead_ev, unit) + ['.']
    n = len(lead)
    bass = bass_line(bass_ev, unit, n - 1) + ['.']
    if drums is None:
        drums = ['.'] * n
    else:
        drums = (list(drums) * n)[:n]
    F = fx if isinstance(fx, list) else [fx] * n
    return dict(speed=speed, pats=[pattern_rows(lead, bass, drums, F[:n])], loop=False)


def build_songs():
    SONGS['SONG_TITLE'] = title_song()
    # the act jingle: 1 row = 1 VZ tick (2 fields)
    SONGS['SONG_ACT'] = jingle(JINGLE_LEAD, JINGLE_BASS, 2, drums='k...h...s...h...')
    SONGS['SONG_CLEAR'] = jingle(CLEAR_LEAD, CLEAR_BASS, 2, drums='k..h..s..h..', fx=[0] * 9 + [1] * 40)
    SONGS['SONG_OVER'] = jingle(OVER_LEAD, OVER_BASS, 3)
    # high-score fanfare
    hs = parse('G4 3 C5 3 E5 3 G5 6 E5 3 G5 12')
    SONGS['SONG_HISCORE'] = jingle(hs, parse('C3 6 G2 6 C3 18'), 2, drums='k..h..', fx=[0] * 12 + [1] * 30)


# ------------------------------------------------------------------ effects (one word per 50 Hz tick)
REST = 0xFE00


def div(f):
    return max(2, min(0xFDFF, round(CLOCK / f)))


def noise(band):
    return 0xFF00 | band


def sweep(f0, f1, ticks):
    return [div(f0 * (f1 / f0) ** (i / max(1, ticks - 1))) for i in range(ticks)]


SFX = {
    'SFX_FLIP': [div(1800), div(2400)],
    'SFX_JUMP': sweep(300, 700, 6),
    'SFX_LAUNCH': sweep(180, 1400, 10) + [div(1400)],
    'SFX_WALL': [div(150), div(150)],
    'SFX_BONK': [div(330), div(330), div(220), div(220), div(330), div(330)],
    'SFX_SPLAT': [noise(1), noise(2), noise(3), noise(4), noise(5), noise(6), noise(8), noise(10), noise(12)],
    'SFX_BOOM': [noise(0), noise(1), noise(2), noise(3), noise(4), noise(5), noise(6), noise(8), noise(10),
                 noise(12), noise(14), noise(16)],
    'SFX_CLANG': [div(2600), div(2500), div(2600), div(2500), div(1800), div(1750)],
    'SFX_POWER': [div(f) for f in (523, 523, 659, 659, 784, 784, 1047, 1047, 1319, 1319, 1568, 1568)],
    'SFX_1UP': [div(f) for f in (784, 784, 1047, 1047, 1319, 1319, 784, 784, 1047, 1047, 1568, 1568, 1568, 1568)],
    'SFX_HOOP': sweep(400, 1600, 8),
    'SFX_THROW': [div(700), div(700), div(500), div(500)],
    'SFX_CLICK': [div(3000)],
    'SFX_STEP': [div(900)],
}


def gen_asm():
    build_songs()
    out = ['; generated by tools/music.py']
    for name, s in SONGS.items():
        out.append('%s:' % name)
        out.append('        db %d' % s['speed'])
        names = ['%s_p%d' % (name, i) for i in range(len(s['pats']))]
        out.append('        dw ' + ','.join(names))
        out.append('        dw %d' % (0 if s['loop'] else 1))
        for n, p in zip(names, s['pats']):
            out.append('%s:' % n)
            for i in range(0, len(p), 16):
                out.append('        db ' + ','.join('%d' % v for v in p[i:i + 16]))
    for name, words in SFX.items():
        out.append('%s:' % name)
        out.append('        dw ' + ','.join('%d' % w for w in words) + ',0')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    print(gen_asm()[:400])
