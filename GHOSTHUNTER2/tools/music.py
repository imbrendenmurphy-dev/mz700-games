"""music.py - songs and sound effects for GHOST HUNTER 2 (one 8253 square voice).

Songs are tracker-style: each row lasts `speed` ticks (50 Hz) and holds a
lead note, a bass note, a drum and an effect.  The player gives the voice
to the drum, then a short bass pluck, then the lead (see src/sound.asm).

Tokens in the pattern strings, one per row (16th note):
    A4 C#5 ...  note        -   hold        .   off
Drums: k kick, s snare, h hat, . none.   Effects per row: 0-3 arpeggio,
4 = lead/bass alternate.
"""
CLOCK = 1108800
NOTE_BASE = 20                      # NOTETAB index = midi - NOTE_BASE

NAMES = {'C': 0, 'C#': 1, 'DB': 1, 'D': 2, 'D#': 3, 'EB': 3, 'E': 4, 'F': 5, 'F#': 6, 'GB': 6,
         'G': 7, 'G#': 8, 'AB': 8, 'A': 9, 'A#': 10, 'BB': 10, 'B': 11}


def midi(tok):
    tok = tok.upper()
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


def pattern(lead, bass, drums, fx=None):
    L = lead.split()
    B = bass.split()
    D = drums.split() if ' ' in drums.strip() else list(drums.replace(' ', ''))
    n = len(L)
    assert len(B) == n and len(D) == n, (len(L), len(B), len(D), lead[:30])
    F = [0] * n if fx is None else (fx if isinstance(fx, list) else [fx] * n)
    out = []
    for i in range(n):
        out += [note_byte(L[i]), note_byte(B[i]), DRUM[D[i]], F[i]]
    return out + [0xFF]


# ------------------------------------------------------------------ songs
# The tunes of the VZ300 original (one row per eighth note), arranged for
# the single voice: bass plucks, drums and arpeggio shimmer on held notes.
TITLE_M = """
A4 - E4 A4 C5 - B4 A4  G4 - D4 G4 B4 - A4 G4  F4 - A4 C5 F5 - E5 D5  E5 - - D#5 E5 - . .
A4 - E4 A4 C5 - B4 A4  G4 - D4 G4 B4 - D5 F5  E5 D5 C5 B4 A4 G#4 A4 B4  A4 - - - . . . .
C5 - C5 D5 E5 - C5 -  D5 - D5 E5 F5 - D5 -  E5 - G5 - F5 - E5 D5  C5 - B4 - G#4 - E4 -
A4 C5 E5 A5 G#5 - E5 -  F5 E5 D5 C5 B4 - G#4 -  A4 - E5 - C5 - B4 G#4  A4 - - - . . . .
"""
TITLE_ROOTS = "A G F E A G E A C D E E A D E A".split()


def bass_bar8(root):
    lo, hi = root + '2', root + '3'
    return [lo, '-', hi, '-', lo, lo, hi, '-']


def shimmer(toks, arp=3):
    fx = []
    run = 0
    for t in toks:
        run = run + 1 if t == '-' else 0
        fx.append(arp if run >= 2 else 0)
    return fx


def bars(lead_text, n=8):
    t = lead_text.split()
    assert len(t) % n == 0, len(t)
    return [t[i:i + n] for i in range(0, len(t), n)]


def title_song():
    pats = []
    # intro: thunder rumble and minor stabs under a held A
    intro = [('A4 - - - . . E4 -', 'A2 - - - A2 - - -', 'k . . . s . . .', 2),
             ('F4 - - - . . E4 -', 'F2 - - - E2 - - -', 'k . . . s . s s', 1)]
    for lead, bass, dr, arp in intro:
        pats.append(pattern(lead, bass, dr, [arp] * 8))
    loop_from = len(pats)
    lead_bars = bars(TITLE_M)
    for i, lb in enumerate(lead_bars):
        root = TITLE_ROOTS[i]
        dr = 'k . s . k k s .' if i % 4 != 3 else 'k . s . k s s s'
        if i < 4:
            dr = 'k . h . s . h .'
        pats.append(pattern(' '.join(lb), ' '.join(bass_bar8(root)), dr, shimmer(lb)))
    return dict(speed=7, pats=pats, loop_from=loop_from, loop=True)


def pad(text, n, fill='-'):
    t = text.split()
    return ' '.join(t + [fill] * (n - len(t)))


def jingle(lead, bass, drums=None, speed=5, fx=None, loop=False):
    n = len(lead.split())
    bass = pad(bass, n, '.')
    drums = pad(drums or ' '.join('.' * n), n, '.')
    return dict(speed=speed, pats=[pattern(lead, bass, drums, fx)], loop=loop)


SONGS = {}


def build_songs():
    SONGS['SONG_TITLE'] = title_song()
    SONGS['SONG_START'] = jingle('A4 C5 E5 A5 G#5 E5 B4 G#4 A4 - - - E5 - A5 - - - . .',
                                 'A2 - - - E2 - - - A2 - - - E3 - A2 - - - . .',
                                 'k . h . k . h . k . s . k . s . s s . .', speed=5,
                                 fx=[0] * 14 + [2] * 6)
    SONGS['SONG_CLEAR'] = jingle('E5 G5 C6 - G5 C6 - - .', 'C3 - G3 - C4 - - - .',
                                 'k . s . k . s . .', speed=4, fx=[0, 0, 0, 1, 0, 1, 1, 1, 0])
    SONGS['SONG_DEATH'] = jingle('E5 D#5 D5 C#5 C5 B4 A#4 A4 G#4 G4 F#4 F4 E4 - D4 - - - C#4 - - - C4 - - - - - - .',
                                 '.', speed=3)
    SONGS['SONG_OVER'] = jingle('G4 - - F#4 - - F4 - - E4 - - - - - .', 'G2 - - F#2 - - F2 - - E2 - - - - - .',
                                'k . . s . . k . . s . . k . . .', speed=9, fx=[0] * 9 + [2] * 7)
    SONGS['SONG_INTER'] = jingle('C5 E5 G5 E5 F5 A5 G5 E5  D5 F5 E5 C5 D5 B4 C5 .  C5 E5 G5 C6 B5 G5 A5 F5  G5 E5 D5 B4 C5 - . .',
                                 'C3 . G2 . F2 . G2 .  D3 . G2 . C3 . G2 .  C3 . E3 . F3 . D3 .  G2 . G2 . C3 - . .',
                                 'k h s h k h s h k h s h k h s h k h s h k h s h k h s h k . s .', speed=6, loop=True)
    SONGS['SONG_BONUS'] = jingle('A4 C5 E5 C5 A4 C5 E5 A5 G4 B4 D5 B4 G4 B4 D5 G5',
                                 'A2 . A2 . A2 . A2 . G2 . G2 . G2 . G2 .',
                                 'k h s h k h s h k h s h k h s s', speed=4, loop=True)
    SONGS['SONG_HISCORE'] = jingle('C5 E5 G5 C6 B5 G5 C6 - - - . .', 'C3 - G3 - E3 - C3 - - - . .',
                                   'k . s . k . s . k . . .', speed=5, fx=[0] * 7 + [1] * 5)
    SONGS['SONG_SUPER'] = jingle('C5 E5 G5 C6 G5 E5 C5 . C6 - . .', '.', 'k . s . k . s . k . . .', speed=3)


# ------------------------------------------------------------------ effects
REST = 0xFE00


def div(f):
    return max(2, min(0xFDFF, round(CLOCK / f)))


def noise(band):
    return 0xFF00 | band


def sweep(f0, f1, ticks):
    return [div(f0 * (f1 / f0) ** (i / max(1, ticks - 1))) for i in range(ticks)]


SFX = {
    'SFX_WAKA1': [div(620), div(470), div(360)],
    'SFX_WAKA2': [div(360), div(470), div(620)],
    'SFX_POWER': sweep(220, 880, 6) + sweep(220, 880, 6) + sweep(220, 1200, 8),
    'SFX_EATG': sweep(300, 2400, 14),
    'SFX_ITEM': [div(1760), div(2217), div(2637), div(3520)],
    'SFX_PUP': sweep(500, 1500, 6) + sweep(700, 2000, 6),
    'SFX_TELE': sweep(3000, 300, 12),
    'SFX_SHIELD': [noise(1), noise(2), noise(3), REST, noise(5), noise(6)],
    'SFX_THUNDER': [noise(1), noise(1), noise(2), noise(1), noise(3), noise(2), noise(4), noise(3),
                    noise(5), noise(4), noise(6), REST, noise(7), REST, noise(7), noise(8)],
    'SFX_TICK': [div(2200)],
    'SFX_FREEZE': sweep(4000, 800, 14),
    'SFX_POP': [div(1500), div(1200)],
    'SFX_SPAWN': sweep(800, 2400, 8),
    'SFX_LIFE': [div(523), div(659), div(784), div(1047), div(1319), div(1568), div(2093), div(2093)],
    'SFX_CLICK': [div(3000)],
    'SFX_LETTER': [div(1800), div(2400)],
}


def gen_asm():
    build_songs()
    out = ['; generated by tools/music.py']
    for name, s in SONGS.items():
        out.append('%s:' % name)
        out.append('        db %d' % s['speed'])
        names = ['%s_p%d' % (name, i) for i in range(len(s['pats']))]
        if s.get('loop_from'):
            out.append('        dw ' + ','.join(names[:s['loop_from']]))
            out.append('%s_loop:' % name)
            out.append('        dw ' + ','.join(names[s['loop_from']:]))
            out.append('        dw 0FFFFh, %s_loop' % name)
        else:
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

