"""music.py - songs and sound effects for ZENITH (one 8253 square voice).

Tracker format and player are shared with the other MZ-700 games
(src/sound.asm): each row lasts `speed` fields and holds a lead note, a
bass note, a drum and an effect byte.  All tunes here are original.
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


def pattern_rows(L, B, D, F):
    n = len(L)
    assert len(B) == n and len(D) == n and len(F) == n, (len(L), len(B), len(D), len(F))
    out = []
    for i in range(n):
        out += [note_byte(L[i]), note_byte(B[i]), DRUM[D[i]], F[i]]
    return out + [0xFF]


def bars(lead, bass, drums, fx=None):
    """16-row patterns written as whitespace-separated tokens"""
    L, B, D = lead.split(), bass.split(), list(drums.replace(' ', ''))
    F = fx if fx is not None else [0] * len(L)
    return pattern_rows(L, B, D, F)


def shimmer(lead):
    """octave arpeggio on held notes"""
    toks = lead.split()
    fx = []
    run = 0
    for t in toks:
        run = run + 1 if t == '-' else 0
        fx.append(3 if run >= 2 else 0)
    return fx


# ------------------------------------------------------------------ title theme
# "Summit" - A minor, slow and wide.  4 phrases of 16 rows.
TITLE = [
    ('A4 - - - C5 - E5 - D5 - - - C5 - B4 -',
     'A2 - A3 - A2 - A3 - G2 - G3 - G2 - G3 -',
     'k.h.s.h.k.h.s.h.'),
    ('A4 - - - E5 - - - G5 - F5 - E5 - - -',
     'F2 - F3 - F2 - F3 - E2 - E3 - E2 - E3 -',
     'k.h.s.h.k.h.s.hh'),
    ('C5 - - - B4 - A4 - G4 - - - A4 - B4 -',
     'C3 - C4 - C3 - C4 - G2 - G3 - G2 - G3 -',
     'k.h.s.h.k.h.s.h.'),
    ('C5 - B4 - G#4 - - - A4 - - - - - . .',
     'E2 - E3 - E2 - E3 - A2 - A3 - A2 - . .',
     'k.h.s.h.k.h.s.s.'),
    ('E5 - - - A5 - - - G5 - E5 - D5 - C5 -',
     'A2 - E3 - A3 - E3 - C3 - G3 - C4 - G3 -',
     'k.h.s.h.k.h.s.h.'),
    ('D5 - - - F5 - E5 - D5 - C5 - B4 - - -',
     'D3 - A3 - D4 - A3 - G2 - D3 - G3 - D3 -',
     'k.h.s.h.k.h.s.hh'),
    ('C5 - E5 - A5 - - - B5 - G#5 - E5 - - -',
     'F2 - C3 - F3 - C3 - E2 - B2 - E3 - B2 -',
     'k.h.s.h.k.h.s.h.'),
    ('A5 - - - - - - - E5 - - - A4 - . .',
     'A2 - E3 - A3 - E3 - A2 - - - A2 - . .',
     'k.h.s.h.k...s.k.'),
]


def title_song():
    pats = []
    for lead, bass, drums in TITLE:
        b = bass.split()[:16]
        pats.append(bars(lead, ' '.join(b), drums, shimmer(lead)))
    return dict(speed=7, pats=pats, loop=True)


# quiet in-game ostinato (bass only, sparse) - plays under the effects
def ambient_song():
    pats = []
    for root, fifth in (('A2', 'E3'), ('F2', 'C3'), ('G2', 'D3'), ('E2', 'B2')):
        lead = '. - - - - - - - - - - - - - - -'
        bass = ' '.join([root, '-', '-', '-', fifth, '-', '-', '-', root, '-', '-', '-', '.', '-', '-', '-'])
        drums = '................'
        pats.append(bars(lead, bass, drums))
    return dict(speed=10, pats=pats, loop=True)


def jingle(notes, bass, speed, arp=0):
    lead = notes.split() + ['.']
    b = (bass.split() + ['-'] * len(lead))[:len(lead) - 1] + ['.']
    n = len(lead)
    return dict(speed=speed, pats=[pattern_rows(lead, b, ['.'] * n, [arp] * n)], loop=False)


SONGS = {}


def build_songs():
    SONGS['SONG_TITLE'] = title_song()
    SONGS['SONG_AMBIENT'] = ambient_song()
    SONGS['SONG_CLEAR'] = jingle('A4 C5 E5 A5 - - G5 - A5 - - - - -', 'A2 - - - - - E3 - A3', 5, 1)
    SONGS['SONG_OVER'] = jingle('E5 - D5 - C5 - B4 - - - A4 - - - - - - -', 'A3 - G3 - F3 - E3 - - - A2', 7, 2)
    SONGS['SONG_START'] = jingle('E4 A4 C5 E5 - - - .', 'A2', 4)


# ------------------------------------------------------------------ effects (one word per 50 Hz tick)
REST = 0xFE00


def div(f):
    return max(2, min(0xFDFF, round(CLOCK / f)))


def noise(band):
    return 0xFF00 | band


def sweep(f0, f1, ticks):
    return [div(f0 * (f1 / f0) ** (i / max(1, ticks - 1))) for i in range(ticks)]


SFX = {
    'SFX_ABSORB': sweep(300, 2400, 10),
    'SFX_BUILD': [noise(6), div(180), div(160), noise(10)],
    'SFX_SHELL': [div(f) for f in (880, 1320, 1760, 1760, 2640)],
    'SFX_MOVE': sweep(2000, 200, 8) + [REST] + sweep(200, 2000, 8),
    'SFX_DENY': [div(140), REST, div(140), REST],
    'SFX_TURN': [div(3000)],
    'SFX_CURSOR': [div(4000)],
    'SFX_WARN': [div(1400), div(1400), REST, div(1000), div(1000), REST],
    'SFX_DRAIN': [noise(3), div(220), noise(5)],
    'SFX_BOOM': [noise(n) for n in (0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32)],
    'SFX_SWEEP': [div(2200), REST, REST, div(2600)],
    'SFX_RISE': sweep(150, 3000, 30),
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
