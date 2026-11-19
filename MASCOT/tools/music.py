"""music.py - KIKO's songs and sound effects (one 8253 square-wave voice).

Songs are tracker-style: each row lasts `speed` ticks (50 Hz) and holds a
lead note, a bass note, a drum and an effect.  The player gives the voice
to the drum, then a short bass pluck, then the lead (see src/sound.asm).

Tokens in the pattern strings, one per row (16th note):
    A4 C#5 ...  note        -   hold        .   off
Drums: k kick, s snare, h hat, . none.   Effects per row: 0 none,
1 major / 2 minor / 3 octave arpeggio, 4 = lead/bass alternate.
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
    D = drums.split()
    n = max(len(L), len(B), len(D))
    # jingles: shorter parts are padded (notes held, drums silent)
    L += ['-'] * (n - len(L))
    B += ['-'] * (n - len(B))
    D += ['.'] * (n - len(D))
    if fx is None:
        F = [0] * n
    elif isinstance(fx, list):
        F = (fx + [0] * n)[:n]
    else:
        F = [fx] * n
    out = []
    for i in range(n):
        out += [note_byte(L[i]), note_byte(B[i]), DRUM[D[i]], F[i]]
    return out + [0xFF]


def shimmer(lead, arp=3, after=2):
    """arpeggio effect on the tail of notes held for `after` rows or more"""
    toks = lead.split()
    fx = [0] * len(toks)
    run = 0
    for k, t in enumerate(toks):
        run = run + 1 if t == '-' else 0
        if run >= after:
            fx[k] = arp
    return fx


def bass_bounce(*roots):
    """one bar per root: root - oct - root - oct ... (8th notes)"""
    out = []
    for r in roots:
        o = r[:-1] + str(int(r[-1]) + 1)
        out.append('%s - %s - %s - %s - %s - %s - %s - %s -' % (r, o, r, o, r, o, r, o))
    return ' '.join(out)


def bass_walk(*roots):
    """root on 1 and 3 with a fifth pickup"""
    out = []
    for r in roots:
        m = midi(r)
        names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        fifth = m + 7
        f = '%s%d' % (names[fifth % 12], fifth // 12 - 1)
        out.append('%s - - - %s - - - %s - - - %s - %s -' % (r, f, r, f, r))
    return ' '.join(out)


def bars(n, s):
    return ' '.join([s] * n)


DR_POP = 'k . h . s . h . k . h k s . h .'
DR_POP2 = 'k . h . s . h . k . k . s . s s'
DR_HALF = 'k . . . s . . . k . . . s . . .'
DR_DRIVE = 'k . h k s . h . k . h k s . h h'
DR_WALTZ = 'k . . . h . . . h . . . k . . . h . . . h . . .'
DR_NONE = '. . . . . . . . . . . . . . . .'

SONGS = {}


def song(name, speed, pats, loop=True, loop_from=0):
    SONGS[name] = dict(speed=speed, pats=pats, loop=loop, loop_from=loop_from)


def P(lead, bass, drums, fx=None):
    return pattern(lead, bass, drums, fx)


def build_songs():
    # ---------------------------------------------------------- title: "Kiko's Theme"
    A1 = 'C5 - E5 - G5 - - - A5 - G5 - E5 - C5 -'
    A2 = 'D5 - - - F5 - E5 - D5 - - - B4 - G4 -'
    A3 = 'C5 - E5 - G5 - - - C6 - B5 - A5 - G5 -'
    A4 = 'A5 - G5 - E5 - D5 - C5 - - - - - - -'
    B1 = 'E5 - F5 - G5 - E5 - A5 - G5 - F5 - E5 -'
    B2 = 'D5 - E5 - F5 - D5 - G5 - F5 - E5 - D5 -'
    B3 = 'C5 - D5 - E5 - G5 - C6 - - - B5 - A5 -'
    B4 = 'G5 - - - A5 - B5 - C6 - - - - - - -'
    title = [P(A1, bass_bounce('C3'), DR_POP, shimmer(A1)),
             P(A2, bass_bounce('G2'), DR_POP, shimmer(A2)),
             P(A3, bass_bounce('F2'), DR_POP, shimmer(A3)),
             P(A4, bass_bounce('C3'), DR_POP2, shimmer(A4, 1)),
             P(B1, bass_bounce('A2'), DR_POP, shimmer(B1)),
             P(B2, bass_bounce('D3'), DR_POP, shimmer(B2)),
             P(B3, bass_bounce('F2'), DR_POP, shimmer(B3)),
             P(B4, bass_bounce('G2'), DR_POP2, shimmer(B4, 1))]
    intro = [P('C5 - - - - - - - G4 - - - - - - -', bass_bounce('C3'), DR_HALF, [1] * 16),
             P('F4 - - - - - - - G4 - - - B4 - D5 -', bass_bounce('G2'), DR_HALF, [1] * 8 + [0] * 8)]
    song('SONG_TITLE', 6, intro + title, loop_from=2)

    # ---------------------------------------------------------- world 1: meadow polka
    M1 = 'G4 - C5 - E5 - C5 - G4 - C5 - E5 - G5 -'
    M2 = 'F5 - E5 - D5 - C5 - D5 - - - G4 - - -'
    M3 = 'G4 - B4 - D5 - B4 - G4 - B4 - D5 - F5 -'
    M4 = 'E5 - D5 - C5 - B4 - C5 - - - . - - -'
    M5 = 'A4 - C5 - F5 - - - E5 - D5 - C5 - A4 -'
    M6 = 'G4 - C5 - E5 - - - D5 - C5 - B4 - G4 -'
    M7 = 'F4 - A4 - D5 - - - C5 - B4 - A4 - B4 -'
    M8 = 'C5 - - - G4 - - - C5 - . - - - - -'
    song('SONG_MEADOW', 7, [
        P(M1, bass_bounce('C3'), DR_POP), P(M2, bass_bounce('G2'), DR_POP),
        P(M3, bass_bounce('G2'), DR_POP), P(M4, bass_bounce('C3'), DR_POP2),
        P(M5, bass_bounce('F2'), DR_POP, shimmer(M5)), P(M6, bass_bounce('C3'), DR_POP, shimmer(M6)),
        P(M7, bass_bounce('D3'), DR_POP, shimmer(M7)), P(M8, bass_bounce('G2'), DR_POP2, shimmer(M8, 1))])

    # ---------------------------------------------------------- world 2: cavern groove (A minor)
    C1 = 'A4 - - C5 - - E5 - D5 - C5 - A4 - - -'
    C2 = 'G4 - - B4 - - D5 - C5 - B4 - G4 - - -'
    C3 = 'F4 - - A4 - - C5 - E5 - D5 - C5 - A4 -'
    C4 = 'E5 - - - D#5 - - - E5 - - - . - - -'
    CB = 'A2 - A2 - A3 - A2 - G2 - G2 - G3 - E2 -'
    song('SONG_CAVE', 6, [
        P(C1, bass_walk('A2'), DR_DRIVE, shimmer(C1, 2)), P(C2, bass_walk('G2'), DR_DRIVE, shimmer(C2, 1)),
        P(C3, bass_walk('F2'), DR_DRIVE, shimmer(C3, 1)), P(C4, bass_walk('E2'), DR_DRIVE, shimmer(C4, 1)),
        P(C1, CB, DR_DRIVE, shimmer(C1, 2)), P(C2, bass_walk('G2'), DR_DRIVE, shimmer(C2, 1)),
        P('F5 - E5 - D5 - C5 - B4 - C5 - D5 - E5 -', bass_walk('F2'), DR_DRIVE),
        P('A4 - - - - - - - E4 - - - A4 - - -', bass_walk('E2'), DR_POP2, [2] * 16)])

    # ---------------------------------------------------------- world 3: cloud waltz (F major, 3/4)
    W1 = 'C5 - - - F5 - - - A5 - - - G5 - - - F5 - - - E5 - - -'
    W2 = 'D5 - - - G5 - - - A#5 - - - A5 - - - G5 - - - F5 - - -'
    W3 = 'E5 - - - G5 - - - C6 - - - A#5 - - - A5 - - - G5 - - -'
    W4 = 'F5 - - - - - - - - - - - C5 - - - - - - - . - - -'

    def wb(r, a, b):
        return '%s - - - %s - - - %s - - - %s - - - %s - - - %s - - -' % (r, a, b, r, a, b)
    song('SONG_CLOUDS', 5, [
        P(W1, wb('F2', 'A3', 'C4'), DR_WALTZ, shimmer(W1, 1)), P(W2, wb('G2', 'A#3', 'D4'), DR_WALTZ, shimmer(W2, 2)),
        P(W3, wb('C3', 'E3', 'G3'), DR_WALTZ, shimmer(W3, 1)), P(W4, wb('F2', 'A3', 'C4'), DR_WALTZ, shimmer(W4, 1)),
        P('A5 - - - G5 - - - F5 - - - D5 - - - E5 - - - F5 - - -', wb('D3', 'F3', 'A3'), DR_WALTZ),
        P('G5 - - - - - - - E5 - - - C5 - - - D5 - - - E5 - - -', wb('C3', 'E3', 'G3'), DR_WALTZ, shimmer(W4, 1)),
        P('F5 - - - A5 - - - C6 - - - A#5 - - - G5 - - - E5 - - -', wb('A#2', 'D3', 'F3'), DR_WALTZ),
        P('F5 - - - - - - - - - - - - - - - - - . - - - - -', wb('F2', 'A3', 'C4'), DR_WALTZ, [1] * 24)])

    # ---------------------------------------------------------- world 4: grey castle march (D minor)
    K1 = 'D5 - - D5 - - D5 - F5 - - - E5 - D5 -'
    K2 = 'C#5 - - C#5 - - C#5 - E5 - - - D5 - C#5 -'
    K3 = 'D5 - F5 - A5 - - - A#5 - A5 - G5 - F5 -'
    K4 = 'E5 - - - A4 - - - C#5 - E5 - A5 - - -'
    song('SONG_CASTLE', 7, [
        P(K1, 'D2 - D3 - D2 - D3 - D2 - D3 - D2 - D3 -', DR_HALF, shimmer(K1, 2)),
        P(K2, 'A1 - A2 - A1 - A2 - A1 - A2 - A1 - A2 -', DR_HALF, shimmer(K2, 1)),
        P(K3, 'A#1 - A#2 - A#1 - A#2 - G1 - G2 - G1 - G2 -', DR_POP, shimmer(K3, 2)),
        P(K4, 'A1 - A2 - A1 - A2 - A1 - A2 - A1 - A2 -', DR_POP2, shimmer(K4, 1))])

    # ---------------------------------------------------------- boss: urgent ostinato (E minor)
    song('SONG_BOSS', 5, [
        P('E5 - G5 - E5 - G5 - F#5 - A5 - F#5 - A5 -', 'E2 - E3 - E2 - E3 - D2 - D3 - D2 - D3 -', DR_DRIVE),
        P('G5 - B5 - G5 - B5 - A5 - C6 - B5 - A5 -', 'C2 - C3 - C2 - C3 - D2 - D3 - B1 - B2 -', DR_DRIVE),
        P('E5 - - - B4 - - - E5 - - - G5 - F#5 -', 'E2 - E3 - E2 - E3 - E2 - E3 - E2 - E3 -', DR_DRIVE, [2] * 16),
        P('D#5 - - - F#5 - - - B5 - - - A5 - F#5 -', 'B1 - B2 - B1 - B2 - B1 - B2 - B1 - B2 -', DR_POP2, [1] * 16)])

    # ---------------------------------------------------------- final boss (D minor, faster)
    song('SONG_FINAL', 4, [
        P('D5 - F5 - A5 - F5 - D5 - F5 - A5 - D6 -', 'D2 - D3 - D2 - D3 - D2 - D3 - D2 - D3 -', DR_DRIVE),
        P('C#6 - A5 - E5 - A5 - C#6 - A5 - E5 - C#5 -', 'A1 - A2 - A1 - A2 - A1 - A2 - A1 - A2 -', DR_DRIVE),
        P('A#5 - - - A5 - - - G5 - - - F5 - - -', 'A#1 - A#2 - A#1 - A#2 - G1 - G2 - G1 - G2 -', DR_DRIVE, [2] * 16),
        P('E5 - - - F5 - - - E5 - - - C#5 - - -', 'A1 - A2 - A1 - A2 - A1 - A2 - A1 - A2 -', DR_POP2, [1] * 16)])

    # ---------------------------------------------------------- jingles
    song('SONG_START', 5, [P('C5 - E5 - G5 - C6 - - - G5 - C6 - - - - - . .',
                             'C3 - - - - - - - - - - - C3 - - - - - . .',
                             'k . h . s . h . k . . . s . . . . . . .', [0] * 12 + [1] * 8)], loop=False)
    song('SONG_CLEAR', 4, [P('G4 - C5 - E5 - G5 - C6 - - - E5 - G5 - C6 - - - - - - - - - - - . .',
                             'C3 - - - - - - - G2 - - - - - - - C3 - - - - - - - - - - - . .',
                             'k . h . s . h . k . h . s . h . k . . . s . . . . . . . . .',
                             [0] * 18 + [1] * 12)], loop=False)
    song('SONG_DEATH', 5, [P('C5 - B4 - A#4 - A4 - G#4 - - - - - .',
                             'C3 - - - - - - - F2 - - - - - .',
                             'k . . . . . . . s . . . . . .')], loop=False)
    song('SONG_GAMEOVER', 8, [P('C5 - - - G4 - - - E4 - - - A4 - - - B4 - - - A4 - - - G#4 - - - - - - - .',
                                'C3 - - - G2 - - - C3 - - - F2 - - - G2 - - - F2 - - - E2 - - - - - - - .',
                                'k . . . s . . . k . . . s . . . k . . . s . . . k . . . . . . . .')],
         loop=False)
    song('SONG_PRISM', 4, [P('C5 - E5 - G5 - C6 - E6 - G6 - - - - - C6 - E6 - G6 - - - - - - - - - .',
                             'C3 - - - - - - - G2 - - - - - - - C3 - - - - - - - - - - - - - .',
                             'k . h . s . h . k . h . s . h . k . h . s . h . k . . . . . . . .',
                             [0] * 14 + [1] * 4 + [0] * 6 + [1] * 9)], loop=False)
    E1 = 'E5 - - - D5 - C5 - D5 - - - G4 - - -'
    E2 = 'E5 - - - F5 - G5 - A5 - - - G5 - - -'
    song('SONG_ENDING', 7, [
        P(E1, bass_walk('C3'), DR_HALF, shimmer(E1, 1)), P('F5 - - - E5 - D5 - C5 - - - - - - -', bass_walk('F2'), DR_HALF, [1] * 16),
        P(E2, bass_walk('A2'), DR_HALF, shimmer(E2, 2)), P('F5 - E5 - D5 - B4 - C5 - - - - - - -', bass_walk('G2'), DR_HALF, [1] * 16)]
        + SONGS['SONG_TITLE']['pats'][2:])


# ------------------------------------------------------------------ effects
REST = 0xFE00


def div(f):
    return max(2, min(0xFDFF, round(CLOCK / f)))


def noise(band):
    return 0xFF00 | band


def sweep(f0, f1, ticks):
    return [div(f0 * (f1 / f0) ** (i / max(1, ticks - 1))) for i in range(ticks)]


SFX = {
    'SFX_JUMP': sweep(300, 900, 6),
    'SFX_SPRING': sweep(200, 1600, 12),
    'SFX_LAND': [noise(3), div(110)],
    'SFX_STOMP': [noise(1)] + sweep(900, 200, 5),
    'SFX_TONGUE': sweep(1500, 2600, 3) + sweep(2600, 1200, 3),
    'SFX_GULP': [div(400), div(300), REST, div(600), div(900), div(1300)],
    'SFX_GEM': [div(1568), div(1568), div(2093), div(2093), div(2637)],
    'SFX_HURT': [noise(2), div(200), noise(3), div(150), noise(4), div(120)],
    'SFX_SWAP': [div(523), div(659), div(784), div(1047), div(1319), div(1568)],
    'SFX_DENY': [div(140), div(140), REST, div(140), div(140)],
    'SFX_ONEUP': [div(659), div(784), div(1319), div(1047), div(1175), div(1568), div(1568), div(2093)],
    'SFX_APPLE': [div(784), div(988), div(1175), div(1568)],
    'SFX_GOLDEN': sweep(600, 2400, 10) + [div(2400), REST, div(2400), REST, div(3200)],
    'SFX_BOSSHIT': [noise(0), noise(1), div(300), noise(2), div(200), noise(3), div(150), noise(4)],
    'SFX_SHOOT': [noise(1)] + sweep(800, 300, 4),
    'SFX_CRUMBLE': [noise(2), REST, noise(3), REST, noise(4)],
    'SFX_SELECT': [div(1800), div(2400)],
    'SFX_PAUSE': [div(1000), REST, div(800), REST, div(1200)],
    'SFX_BOOM': [noise(1), noise(1), noise(2), noise(2), noise(3), noise(3), noise(4), REST,
                 noise(5), REST, noise(6), REST, REST, noise(7)],
    'SFX_BUMP': [noise(4), div(90)],
    'SFX_DROP': sweep(1200, 300, 8),
    'SFX_BLIP': [div(2000)],
}


def gen_asm():
    build_songs()
    out = ['; generated by tools/music.py']
    for name, s in SONGS.items():
        out.append('%s:' % name)
        out.append('        db %d' % s['speed'])
        names = ['%s_p%d' % (name, i) for i in range(len(s['pats']))]
        lf = s.get('loop_from', 0)
        if s['loop'] and lf:
            out.append('        dw ' + ','.join(names[:lf]))
            out.append('%s_loop:' % name)
            out.append('        dw ' + ','.join(names[lf:]))
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
