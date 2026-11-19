"""music.py - songs and sound effects for ROCKFALL (one 8253 square voice).

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


# ------------------------------------------------------------------ title: "The Sun Mosaic"
def bass_bar(root, style=0):
    """16 rows of bass: octave bounce (0), walking (1) or long notes (2)"""
    r1 = root
    r2 = root[:-1] + str(int(root[-1]) + 1)
    if style == 0:
        return '%s - %s - %s - %s - %s - %s - %s - %s -' % (r1, r1, r2, r1, r1, r1, r2, r1)
    if style == 1:
        return '%s - - %s - - %s - %s - - %s - - %s -' % (r1, r2, r1, r2, r1, r2)
    return '%s - - - - - - - %s - - - - - - -' % (r1, r1)


DR_A = 'k . h . s . h h k . h . s . h .'
DR_B = 'k . h . s . h . k h k . s . s s'
DR_C = 'k . . . h . . . s . . . h . . .'
DR_D = 'k . . . . . . . . . . . . . . .'

# (lead, bass root, bass style, drums)
VERSE = [
    ('A4 - C5 - E5 - - - D5 - C5 - B4 - G4 -', 'A2', 1, DR_C),
    ('A4 - - - E5 - - - A5 - G5 - E5 - - -', 'F2', 1, DR_C),
    ('D5 - - - F5 - E5 - D5 - C5 - B4 - C5 -', 'D2', 1, DR_C),
    ('E5 - - - - - - - . . B4 - C5 - D5 -', 'E2', 1, DR_B),
    ('A4 - C5 - E5 - A5 - G5 - E5 - C5 - E5 -', 'A2', 0, DR_A),
    ('F5 - - - E5 - D5 - C5 - - - A4 - - -', 'F2', 0, DR_A),
    ('G4 - B4 - D5 - G5 - F5 - D5 - B4 - G4 -', 'G2', 0, DR_A),
    ('A4 - - - - - - - . . E5 - G#5 - B5 -', 'E2', 0, DR_B),
]
CHORUS = [
    ('C6 - - - B5 - A5 - G5 - - - E5 - - -', 'C3', 0, DR_A),
    ('F5 - - - G5 - A5 - C6 - - - A5 - - -', 'F2', 0, DR_A),
    ('B5 - - - A5 - G5 - D5 - - - G5 - - -', 'G2', 0, DR_A),
    ('E5 - - - G#5 - B5 - E6 - - - D6 - - -', 'E2', 0, DR_B),
    ('A5 - - - C6 - - - E6 - D6 - C6 - B5 -', 'A2', 0, DR_A),
    ('A5 - G5 - F5 - - - D5 - - - F5 - A5 -', 'D2', 0, DR_A),
    ('G#5 - - - B5 - - - E6 - - - B5 - G#5 -', 'E2', 0, DR_A),
    ('A5 - - - - - - - - - - - . . . .', 'A2', 2, DR_C),
]


def shimmer(lead):
    """octave arpeggio on the tail of long held notes"""
    fx = [0] * 16
    run = 0
    for k, tok in enumerate(lead.split()):
        run = run + 1 if tok == '-' else 0
        if run >= 3:
            fx[k] = 3
    return fx


def title_song():
    pats = []
    # intro: minor chord stabs over a slow bass
    for root, chord, arp in (('A2', 'A4', 2), ('F2', 'F4', 1), ('D2', 'D5', 2), ('E2', 'E4', 1)):
        lead = '%s - - - - - %s - - - . . %s - . .' % (chord, chord, chord)
        pats.append(pattern(lead, bass_bar(root, 2), DR_D, arp))
    loop_from = len(pats)
    for lead, root, st, dr in VERSE + CHORUS:
        pats.append(pattern(lead, bass_bar(root, st), dr, shimmer(lead)))
    return dict(speed=6, pats=pats, loop_from=loop_from, loop=True)


def jingle(lead, bass, drums, speed=5, fx=None):
    return dict(speed=speed, pats=[pattern(lead, bass, drums, fx)], loop=False)


SONGS = {}


def build_songs():
    SONGS['SONG_TITLE'] = title_song()
    SONGS['SONG_ENTER'] = jingle('A4 - C5 - E5 - A5 - - - - - .',
                                 'A2 - - - - - - - - - - - .',
                                 'k . . . h . . . s . . . .', speed=4, fx=[0] * 8 + [2] * 5)
    SONGS['SONG_WIN'] = dict(speed=6, loop=True, loop_from=0, pats=[
        pattern(lead, bass_bar(root, 0), DR_A, shimmer(lead)) for lead, root, st, dr in CHORUS])
    SONGS['SONG_OVER'] = jingle(
        'E5 - - - D5 - - - C5 - - - B4 - - - A4 - - - - - - - .',
        'A2 - - - G2 - - - F2 - - - E2 - - - A2 - - - - - - - .',
        'k . . . s . . . k . . . s . . . k . . . . . . . .', speed=8)


# ------------------------------------------------------------------ effects
REST = 0xFE00


def div(f):
    return max(2, min(0xFDFF, round(CLOCK / f)))


def noise(band):
    return 0xFF00 | band


def sweep(f0, f1, ticks):
    return [div(f0 * (f1 / f0) ** (i / max(1, ticks - 1))) for i in range(ticks)]


SFX = {
    'SFX_LAND': [noise(5), noise(8)],
    'SFX_GEM': sweep(1319, 2637, 4),
    'SFX_DIG': [noise(0)],
    'SFX_PUSH': [noise(6), div(110)],
    'SFX_CRUSH': [noise(1), div(90), noise(2), div(70), noise(3), div(55), noise(5), REST, noise(7)],
    'SFX_HATCH': [div(400), div(300), div(500), div(250), div(600)],
    'SFX_CAGE': [div(1568), div(1976), div(2349), div(3136), REST, div(2349), div(3136), div(3951)],
    'SFX_PIECE': [div(784), div(988), div(1175), div(1568), div(1175), div(1568), div(1976), div(2349), div(2349)],
    'SFX_CROWN': [div(1047), div(1319), div(1568), div(2093), REST, div(2093), div(2637), div(3136), div(4186)],
    'SFX_KEY': [div(2093), div(2637), div(2093), div(2637), div(3136)],
    'SFX_TRANS': sweep(200, 3000, 12) + sweep(3000, 200, 12),
    'SFX_SWITCH': [div(300), div(300), noise(4), div(150), div(150), noise(6), div(100)],
    'SFX_BUMP': [div(120), div(100)],
    'SFX_DEATH': sweep(1500, 60, 30),
    'SFX_REVEAL': [noise(i % 3) for i in range(16)],
    'SFX_CLICK': [div(3000)],
    'SFX_TICK': [div(1500)],
}


def gen_asm():
    build_songs()
    out = ['; generated by tools/music.py']
    for name, s in SONGS.items():
        out.append('%s:' % name)
        out.append('        db %d' % s['speed'])
        names = ['%s_p%d' % (name, i) for i in range(len(s['pats']))]
        if s.get('loop_from') is not None and s.get('loop'):
            if s['loop_from']:
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

