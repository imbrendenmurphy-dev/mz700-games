"""tunes.py - the soundtrack (see music.py for the row format).

Each tune: (name, ticks per row, arpeggio ticks, loop pattern (FFh = once),
patterns).  Rhythm letters: k kick, s snare, h hat, p pah (chord blip),
b bass pluck, B kick + bass, x kick + pah, q snare + pah.
"""
from music import pattern, E

ROCK = 'k.h.s.h.k.k.s.hs'
BASS = 'B...b...B...b...'


def tunes():
    T = []
    # ---------------------------------------------------------- title: A minor, heroic
    T.append(('title', 5, 3, 2, [
        pattern(E, 'Am F', 'B..pb..pB..pb.pp'),
        pattern(E, 'G E', 'B..pb..pB..pk.ss'),
        pattern('A4 . . . E5 . . . A5 . G5 . E5 . D5 .', 'Am', ROCK),
        pattern('C5 . . . D5 . E5 . F5 . . . E5 . D5 .', 'F', ROCK),
        pattern('E5 . . . G5 . . . C6 . B5 . G5 . E5 .', 'C', ROCK),
        pattern('G#5 . . . B5 . . . E5 . . . - . . .', 'E', 'k.h.s.h.k.k.s.ss'),
        pattern('A5 . G5 . F5 . E5 . D5 . . . C5 . D5 .', 'Dm Am', ROCK),
        pattern('E5 . . . . . . . E4 . G#4 . B4 . E5 .', 'E', 'k.h.s.h.k.s.s.ss'),
    ]))
    # ---------------------------------------------------------- select: D major, bouncy
    T.append(('select', 5, 3, 0, [
        pattern('D5 . F#5 . A5 . F#5 . D5 . F#5 . A5 . B5 .', 'D', 'B.pkb.pkB.pkb.ps'),
        pattern('A5 . . . G5 . F#5 . E5 . . . - . . .', 'G A', 'B.pkb.pkB.pks.ss'),
    ]))
    # ---------------------------------------------------------- japan: in-scale on E (E F A B C)
    T.append(('japan', 6, 4, 1, [
        pattern('E5 . . . F5 . . . E5 . . . B4 . . .', 'Am', BASS),
        pattern('E5 . F5 . A5 . . . B5 . A5 . F5 . E5 .', 'Am', 'k...s...k.k.s...'),
        pattern('C6 . . . B5 . A5 . F5 . . . E5 . . .', 'F', 'k...s...k.k.s...'),
        pattern('A5 . B5 . C6 . E6 . C6 . B5 . A5 . F5 .', 'Dm Am', ROCK),
        pattern('E5 . . . F5 . E5 . B4 . . . - . . .', 'E', 'k...s...k.k.s.ss'),
    ]))
    # ---------------------------------------------------------- brazil: samba in G
    sb = 'B.pbs.pbB.pbs.ps'
    T.append(('brazil', 5, 3, 0, [
        pattern('G5 . . B5 . . D6 . B5 . . G5 . . A5 .', 'G', sb),
        pattern('B5 . A5 . G5 . E5 . . . D5 . E5 . G5 .', 'Em C', sb),
        pattern('A5 . . C6 . . E6 . D6 . . B5 . . A5 .', 'Am D', sb),
        pattern('G5 . . . D5 . G5 . - . G5 . A5 . B5 .', 'G', 'B.pbs.pbB.pbs.ss'),
    ]))
    # ---------------------------------------------------------- usa: E blues shuffle
    bl = 'B..ps..pB..ps.pp'
    T.append(('usa', 5, 3, 0, [
        pattern('E5 . . G5 . . A5 . A#5 . B5 . . . G5 .', 'E', bl),
        pattern('E5 . . D5 . . E5 . - . . . B4 . D5 .', 'E', bl),
        pattern('A5 . . C6 . . D6 . D#6 . E6 . . . C6 .', 'A', bl),
        pattern('B5 . . A5 . . G5 . E5 . . . - . . .', 'B A', 'B..ps..pB.k.s.ss'),
    ]))
    # ---------------------------------------------------------- china: G major pentatonic
    cn = 'B...s.h.B.k.s.h.'
    T.append(('china', 6, 4, 0, [
        pattern('G5 . A5 . B5 . D6 . E6 . D6 . B5 . A5 .', 'G', cn),
        pattern('B5 . . . A5 . G5 . E5 . . . D5 . . .', 'Em', cn),
        pattern('D6 . E6 . D6 . B5 . A5 . B5 . A5 . G5 .', 'C D', cn),
        pattern('E5 . . . G5 . . . G5 . . . - . . .', 'G', 'B...s.h.B.k.s.ss'),
    ]))
    # ---------------------------------------------------------- russia: D minor march
    mr = 'B.p.s.p.B.p.s.pp'
    T.append(('russia', 5, 3, 0, [
        pattern('A5 . . . D6 . . . C6 . A#5 . A5 . G5 .', 'Dm', mr),
        pattern('F5 . G5 . A5 . . . E5 . . . - . . .', 'A', mr),
        pattern('A5 . A#5 . C6 . . . A#5 . A5 . G5 . F5 .', 'Gm Dm', mr),
        pattern('E5 . F5 . E5 . C#5 . D5 . . . - . . .', 'A Dm', 'B.p.s.p.B.p.s.ss'),
    ]))
    # ---------------------------------------------------------- mexico: C major, oom-pah
    op = 'B.p.b.p.B.p.b.p.'
    T.append(('mexico', 5, 3, 0, [
        pattern('E5 . G5 . C6 . . . C6 . D6 . E6 . . .', 'C', op),
        pattern('D6 . C6 . B5 . G5 . A5 . B5 . G5 . . .', 'G', op),
        pattern('F5 . A5 . C6 . . . C6 . D6 . F6 . . .', 'F', op),
        pattern('E6 . D6 . C6 . G5 . C6 . . . - . . .', 'G C', 'B.p.b.p.B.p.s.ss'),
    ]))
    # ---------------------------------------------------------- thailand: A minor pentatonic
    th = 'B...b.h.B...s.h.'
    T.append(('thailand', 6, 4, 0, [
        pattern('A5 . C6 . D6 . . . E6 . D6 . C6 . A5 .', 'Am', th),
        pattern('G5 . . . A5 . C6 . A5 . . . - . . .', 'G Am', th),
        pattern('E6 . G6 . E6 . D6 . C6 . D6 . E6 . . .', 'C', th),
        pattern('D6 . C6 . A5 . G5 . A5 . . . - . . .', 'G Am', 'B...b.h.B.k.s.ss'),
    ]))
    # ---------------------------------------------------------- india: E phrygian dominant
    ind = 'B.b.s.b.B.b.s.bh'
    T.append(('india', 6, 4, 0, [
        pattern('E5 . F5 . G#5 . A5 . B5 . A5 . G#5 . F5 .', 'E', ind),
        pattern('E5 . . . . . F5 . E5 . D5 . E5 . . .', 'E Dm', ind),
        pattern('A5 . B5 . C6 . D6 . C6 . B5 . A5 . G#5 .', 'Am E', ind),
        pattern('F5 . E5 . F5 . G#5 . E5 . . . - . . .', 'Dm E', 'B.b.s.b.B.b.s.ss'),
    ]))
    # ---------------------------------------------------------- boss: C minor, grinding
    bo = 'B.k.s.k.B.k.s.ks'
    T.append(('boss', 5, 3, 0, [
        pattern('C5 . . C5 . . D#5 . . D5 . . C5 . G4 .', 'Cm', bo),
        pattern('C5 . . C5 . . F5 . . D#5 . . D5 . . .', 'Cm Fm', bo),
        pattern('G5 . . F#5 . . G5 . G#5 . . G5 . F5 . .', 'Ab G', bo),
        pattern('D#5 . D5 . C5 . B4 . C5 . . . - . . .', 'G Cm', 'B.k.s.k.B.k.s.ss'),
    ]))
    # ---------------------------------------------------------- jingles
    T.append(('win', 4, 3, 0xFF, [
        pattern('C5 . E5 . G5 . C6 . . . G5 . C6 . . .', 'C', 'x...p...x...p...'),
        pattern('E6 . . . . . . . - . . . . . . .', 'C', 'x.......k.......'),
    ]))
    T.append(('lose', 8, 4, 0xFF, [
        pattern('A4 . . . G4 . . . F4 . . . E4 . . .', 'Am Dm', 'b.......b.......'),
        pattern('E4 . . . . . . . - . . . . . . .', 'Am', 'b...............'),
    ]))
    T.append(('ending', 6, 4, 0, [
        pattern('C5 . . . G5 . . . E5 . . . C6 . . .', 'C', 'B...s...B.k.s...'),
        pattern('A5 . . . F5 . A5 . C6 . . . A5 . . .', 'F', 'B...s...B.k.s...'),
        pattern('B5 . . . G5 . B5 . D6 . . . B5 . . .', 'G', 'B...s...B.k.s...'),
        pattern('C6 . . . . . . . G5 . E5 . C5 . . .', 'C', 'B...s...B.k.s.ss'),
    ]))
    return T


TUNE_NAMES = ['title', 'select', 'japan', 'brazil', 'usa', 'china', 'russia', 'mexico', 'thailand', 'india', 'boss',
              'win', 'lose', 'ending']
TUNE_ALIASES = {'STAGE0': 2}
