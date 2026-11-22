"""music.py - the WARDSTONE score and sound effects (build/gen_music.inc).

The player (src/sound.asm) synthesises one 8253 square wave from compact
rows at 50 Hz: per row a lead note, a chord and rhythm flags.  Out of those
it shares each tick between a kick that falls into the chord root, snare and
hat noise, bass plucks, two-note "pah" blips, a plucked lead with vibrato and
decay, and a chord arpeggio that fills the gaps - so a tune needs about 3
bytes per sixteenth instead of a byte per tick.

Patterns are 16 rows:  lead tokens ('.' hold, '-' rest, 'A4' ...),
chords ('Dm' for the whole pattern or 'Dm Bb' for two halves), and a
rhythm line of 16 characters: k kick, s snare, h hat, p pah, b bass pluck,
x kick + pah ... '.' nothing.
"""
PIT_CLOCK = 17734475 / 16
NOTE_BASE = 23                     # index 1 = MIDI 24 (C1)
NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(s):
    n = NAMES[s[0]]
    i = 1
    if s[i:i + 1] == '#':
        n += 1
        i += 1
    elif s[i:i + 1] == 'b':
        n -= 1
        i += 1
    return 12 * (int(s[i:]) + 1) + n


def idx(s):
    v = midi(s) - NOTE_BASE
    assert 1 <= v <= 95, s
    return v


def divisors():
    out = [0]
    for i in range(1, 96):
        m = i + NOTE_BASE
        f = 440.0 * 2 ** ((m - 69) / 12.0)
        out.append(min(65535, int(round(PIT_CLOCK / f))))
    return out


# chords: root, third, fifth in the bass octave (the player lifts them)
CHORDS = {}


def chord(name):
    if name in CHORDS:
        return CHORDS[name]
    root = name.rstrip('m7do+')
    minor = name[len(root):].startswith('m')
    dim = name.endswith('dim')
    r = midi(root + '2')
    if r < midi('F#2'):
        pass
    else:
        r -= 12 if r > midi('B2') else 0
    third = r + (3 if (minor or dim) else 4)
    fifth = r + (6 if dim else 7)
    CHORDS[name] = (r - NOTE_BASE, third - NOTE_BASE, fifth - NOTE_BASE)
    return CHORDS[name]


RHY = {'.': 0, 'k': 1, 's': 2, 'h': 3, 'p': 4, 'b': 8, 'x': 5, 'q': 6, 'B': 9}


def pattern(lead, chords, rhythm):
    toks = lead.split()
    assert len(toks) == 16, (lead, len(toks))
    assert len(rhythm) == 16, rhythm
    chs = chords.split()
    rows = []
    for i in range(16):
        t = toks[i]
        n = 0 if t == '.' else (0x7F if t == '-' else idx(t))
        c = 0
        if i == 0:
            c = chs[0]
        elif i == 8 and len(chs) == 2:
            c = chs[1]
        elif len(chs) == 4 and i % 4 == 0:
            c = chs[i // 4]
        rows.append([n, c, RHY[rhythm[i]]])
    return rows


E = '. . . . . . . . . . . . . . . .'      # no lead
R = '- . . . . . . . . . . . . . . .'      # lead off


# ---------------------------------------------------------------- tunes
# each: (name, ticks per row, arpeggio ticks per row, loop index, [patterns])
def tunes():
    T = []
    # --- title: D minor, heroic
    ri = 'k...s...k.k.s..h'
    rb = 'b.......b...p...'
    T.append(('title', 6, 4, 2, [
        pattern(E, 'Dm Bb', rb), pattern(E, 'C A', rb),
        pattern('D5 . . . A4 . D5 . F5 . E5 . D5 . C5 .', 'Dm', ri),
        pattern('D5 . . . F5 . A5 . G5 . F5 . E5 . . .', 'Bb', ri),
        pattern('E5 . . . G5 . C6 . Bb5 . A5 . G5 . E5 .', 'C', ri),
        pattern('C#5 . . . E5 . . . A4 . . . - . . .', 'A', 'k...s...k...s.ss'),
        pattern('G5 . . F5 . . D5 . . . Bb4 . D5 . . .', 'Gm Dm', ri),
        pattern('F5 . . E5 . . C5 . . . A4 . C5 . . .', 'Bb F', ri),
        pattern('D5 . E5 . F5 . G5 . A5 . . . G5 . F5 .', 'Gm A', ri),
        pattern('D5 . . . . . . . - . . . . . . .', 'Dm', 'k...s...k...s.hh'),
    ]))
    # --- the Ossuary: A minor, slow, hollow
    rp = 'b.......b.......'
    T.append(('ossuary', 9, 6, 0, [
        pattern(E, 'Am', rp), pattern(E, 'F', rp),
        pattern('E5 . . . . . D5 . C5 . . . B4 . . .', 'Am', rp),
        pattern('C5 . . . . . A4 . . . . . - . . .', 'F', rp),
        pattern('A4 . . . C5 . . . E5 . . . D5 . . .', 'Dm', rp),
        pattern('B4 . . . . . G#4 . . . . . - . . .', 'E', 'b.......b...h...'),
        pattern(E, 'Am E', rp), pattern(E, 'F E', rp),
    ]))
    # --- the Mossway: E dorian, a lilting walk
    rm = 'b..p..b.p..b..p.'
    T.append(('mossway', 7, 5, 0, [
        pattern(E, 'Em', rm), pattern(E, 'A', rm),
        pattern('B4 . . E5 . . F#5 . G5 . . F#5 . . E5 .', 'Em', rm),
        pattern('C#5 . . . . . A4 . . . . . - . . .', 'A', rm),
        pattern('G5 . . F#5 . . E5 . D5 . . B4 . . . .', 'G D', rm),
        pattern('E5 . . . . . . . - . . . . . . .', 'Em A', rm),
        pattern('B4 . D5 . E5 . . . F#5 . E5 . D5 . B4 .', 'Em', rm),
        pattern('A4 . . . B4 . . . - . . . . . . .', 'D Em', rm),
    ]))
    # --- the Drowned Library: C# minor music box, arpeggios high
    rl = 'b.......p.......'
    T.append(('library', 8, 7, 0, [
        pattern(E, 'C#m', rl), pattern(E, 'A', rl),
        pattern('G#5 . . . . . E5 . . . C#5 . . . . .', 'C#m', rl),
        pattern('A5 . . . G#5 . . . F#5 . . . E5 . . .', 'A', rl),
        pattern('F#5 . . . . . A5 . . . G#5 . . . . .', 'F#m', rl),
        pattern('G#5 . . . . . . . - . . . . . . .', 'G#', rl),
        pattern(E, 'C#m B', rl), pattern(E, 'A G#', rl),
    ]))
    # --- the Ember Forge: D phrygian, driving
    rf = 'k..hs..hk.khs..h'
    T.append(('forge', 6, 4, 0, [
        pattern(E, 'Dm', rf), pattern(E, 'Eb', rf),
        pattern('D5 . . . Eb5 . D5 . C5 . . . A4 . . .', 'Dm', rf),
        pattern('Bb4 . . . C5 . . . Eb5 . . . D5 . . .', 'Eb', rf),
        pattern('F5 . . . Eb5 . D5 . Eb5 . . . D5 . C5 .', 'Cm Dm', rf),
        pattern('D5 . . . . . . . - . . . . . . .', 'Dm', 'k..hs..hk.k.s.ss'),
    ]))
    # --- the Hollow Throne: C minor, slow and heavy
    rt = 'k.......s.......'
    T.append(('throne', 10, 7, 0, [
        pattern(E, 'Cm', rt), pattern(E, 'Ab', rt),
        pattern('G5 . . . . . Ab5 . G5 . . . Eb5 . . .', 'Cm', rt),
        pattern('F5 . . . Eb5 . . . D5 . . . . . . .', 'Ab G', rt),
        pattern('C5 . . . Eb5 . . . G5 . . . F#5 . . .', 'Cm', rt),
        pattern('G5 . . . . . . . - . . . . . . .', 'G', 'k.......s...s.s.'),
    ]))
    # --- a guardian wakes: A minor, fast
    rb2 = 'k.hsk.hsk.hsk.ss'
    T.append(('boss', 5, 3, 0, [
        pattern('A4 . C5 . E5 . A5 . G5 . E5 . C5 . E5 .', 'Am', rb2),
        pattern('F5 . E5 . D5 . C5 . B4 . C5 . D5 . B4 .', 'F E', rb2),
        pattern('A4 . C5 . E5 . A5 . B5 . C6 . B5 . A5 .', 'Am Dm', rb2),
        pattern('G#5 . . . E5 . . . B4 . . . G#4 . . .', 'E', 'k.hsk.hsk.k.s.ss'),
    ]))
    # --- death: a falling line, no loop
    T.append(('death', 12, 0, 0xFF, [
        pattern('A4 . . . G4 . . . F4 . . . E4 . . .', 'Dm Bb', 'b.......b.......'),
        pattern('D4 . . . C#4 . . . D4 . . . . . . -', 'A Dm', 'b.......b.......'),
    ]))
    # --- the end: C major, warm
    rv = 'b...p...b...p...'
    T.append(('ending', 7, 5, 0, [
        pattern('E5 . . . G5 . . . C6 . . . B5 . A5 .', 'C', rv),
        pattern('G5 . . . . . E5 . F5 . . . D5 . . .', 'Am F', rv),
        pattern('E5 . D5 . C5 . . . D5 . E5 . G5 . . .', 'C G', rv),
        pattern('C5 . . . . . . . - . . . . . . .', 'F C', rv),
    ]))
    return T


TUNE_NAMES = ['title', 'ossuary', 'mossway', 'library', 'forge', 'throne', 'boss', 'death', 'ending']
TUNE_ALIASES = {'STAGE0': 1}


# ---------------------------------------------------------------- effects (100 Hz)
def n(s, k=1):
    return [idx(s)] * k


def NZ(kind, k=1):
    return [0x80 + kind] * k


SIL = [0x7F]


def run(notes, k):
    out = []
    for s in notes.split():
        out += n(s, k)
    return out


SFX = [
    ('WHOOSH', NZ(4, 2) + SIL),
    ('WHOOSH2', NZ(4, 3) + NZ(0, 1) + SIL),
    ('HIT', NZ(3, 2) + n('C3', 1) + n('G2', 2) + NZ(1, 2)),
    ('HIT2', NZ(2, 2) + n('A2', 2) + n('E2', 2) + NZ(3, 2)),
    ('BLOCK', n('C6', 1) + n('G5', 2) + NZ(0, 2)),
    ('GRAB', n('C3', 2) + n('E3', 2) + NZ(3, 3)),
    ('FIRE', NZ(4, 3) + run('C5 G4 E4 C4 G3 E3 C3', 1) + NZ(5, 3) + SIL),
    ('UPPER', run('C3 E3 G3 C4 E4 G4 C5', 1) + NZ(4, 2)),
    ('SPIN', run('C4 G4 C4 G4 C4 G4', 1) + NZ(4, 2)),
    ('RUSH', NZ(5, 3) + run('G2 C3 G2 C3', 1)),
    ('FLURRY', NZ(3, 1) + n('E4', 1) + NZ(3, 1)),
    ('JUMP', run('C3 E3 G3', 1)),
    ('LAND', NZ(5, 2)),
    ('THUD', NZ(2, 4) + run('C2 A1 F1', 2)),
    ('ROUND', n('G4', 6) + SIL + n('C5', 10)),
    ('FIGHT', run('C5 E5 G5', 2) + n('C6', 12)),
    ('KO', NZ(2, 6) + run('C4 B3 A3 G3 F3 E3 D3 C3 B2 A2 G2 F2', 2) + NZ(5, 8)),
    ('WIN', run('C5 E5 G5 C6', 4) + SIL + n('C6', 14)),
    ('MOVE', n('C5', 2)),
    ('SELECT', run('G5 C6', 3) + n('E6', 8)),
    ('COIN', run('B5 E6', 3)),
]


def gen_asm():
    import tunes as TU
    T = TU.tunes()
    TUNE_NAMES = TU.TUNE_NAMES
    TUNE_ALIASES = TU.TUNE_ALIASES
    out = ['; generated by tools/music.py']
    d = divisors()
    out.append('mus_div:')
    for i in range(0, 96, 12):
        out.append('        dw ' + ','.join(str(v) for v in d[i:i + 12]))
    # chords: index from 1
    allch = []
    pats = []
    tune_lines = []
    for name, tpr, arpl, loop, patlist in T:
        order = []
        for p in patlist:
            rows = []
            for nn, c, f in p:
                ci = 0
                if c:
                    chord(c)
                    if c not in allch:
                        allch.append(c)
                    ci = allch.index(c) + 1
                rows += [nn, ci, f]
            if rows in pats:
                order.append(pats.index(rows))
            else:
                pats.append(rows)
                order.append(len(pats) - 1)
        tune_lines.append('tune_%s:' % name)
        tune_lines.append('        db %d,%d,%d' % (tpr, arpl, 0 if loop == 0xFF else loop))
        tune_lines.append('        db ' + ','.join(str(o) for o in order) + ',0FFh')
    for i, name in enumerate(TUNE_NAMES):
        out.append('TUNE_%s equ %d' % (name.upper(), i))
    for k, v in TUNE_ALIASES.items():
        out.append('TUNE_%s equ %d' % (k, v))
    out.append('tune_tab:')
    out.append('        dw ' + ','.join('tune_' + nm for nm in TUNE_NAMES))
    out += tune_lines
    out.append('chord_tab:')
    for c in allch:
        out.append('        db %d,%d,%d   ; %s' % (CHORDS[c] + (c,)))
    out.append('pat_tab:')
    for i in range(len(pats)):
        out.append('        dw pat_%d' % i)
    for i, p in enumerate(pats):
        out.append('pat_%d:' % i)
        for k in range(0, 48, 12):
            out.append('        db ' + ','.join(str(v) for v in p[k:k + 12]))
    for i, (nm, data) in enumerate(SFX):
        out.append('SFX_%s equ %d' % (nm, i))
    out.append('sfx_tab:')
    out.append('        dw ' + ','.join('sfx_' + nm.lower() for nm, _ in SFX))
    for nm, data in SFX:
        out.append('sfx_%s:' % nm.lower())
        out.append('        db ' + ','.join(str(v) for v in data) + ',0')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    s = gen_asm()
    print(len(s.splitlines()), 'lines')
