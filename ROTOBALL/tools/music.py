"""music.py - the title tune for Rotoball's three-channel music player.

Channels are streams of (note, rows) byte pairs; note 0 = rest, 1..84 =
semitones from C2, FFh = loop. Drums use 1 = kick, 2 = snare, 3 = hi-hat.
The player (src/music.asm) interleaves lead and bass tick by tick on the
single 8253 voice, and lets drum hits cut in for a few ticks.
"""
CLOCK = 1108800
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8,
         'A': 9, 'A#': 10, 'B': 11}


def num(n):
    """'A4' -> note number (C2 = 1)."""
    return NAMES[n[:-1]] + (int(n[-1]) - 2) * 12 + 1


def freq(k):
    return 65.406 * 2 ** ((k - 1) / 12)


def stream(text):
    """'E5:2 A5:2 -:4' -> bytes. '-' is a rest."""
    out = []
    for tok in text.split():
        n, length = tok.split(':')
        out += [0 if n == '-' else num(n), int(length)]
    return out


def drums(pattern):
    """one char per row: K kick, S snare, H hat, . nothing (merged into rests)"""
    out = []
    code = {'K': 1, 'S': 2, 'H': 3}
    i = 0
    while i < len(pattern):
        c = pattern[i]
        j = i + 1
        while j < len(pattern) and pattern[j] == '.':
            j += 1
        out += [code.get(c, 0), j - i]
        i = j
    return out


LEAD = '''
E5:2 A5:2 C6:2 B5:2 A5:4 E5:2 G5:2
F5:2 A5:2 C6:4 D6:2 C6:2 A5:4
G5:2 E5:2 G5:2 C6:2 E6:4 D6:2 C6:2
B5:4 G5:2 D6:2 B5:4 -:4
A5:2 C6:2 E6:2 D6:2 C6:2 B5:2 A5:4
C6:2 A5:2 F5:2 A5:2 C6:4 F6:4
E6:2 D6:2 C6:2 G5:2 E5:4 G5:4
D6:2 B5:2 G5:4 E5:8
'''

BASS = ' '.join([
    'A2:2 A2:2 A3:2 A2:2 A2:2 A2:2 A3:2 E3:2',
    'F2:2 F2:2 F3:2 F2:2 F2:2 F2:2 F3:2 C3:2',
    'C3:2 C3:2 C4:2 C3:2 C3:2 C3:2 C4:2 G2:2',
    'G2:2 G2:2 G3:2 G2:2 G2:2 G2:2 G3:2 D3:2',
] * 2)

DRUMS = ('K.H.S.H.K.KHS.HH' * 7) + 'K.S.S.SSK.SSSSSS'


def check(name, data, rows):
    total = sum(data[1::2])
    assert total == rows, '%s has %d rows, expected %d' % (name, total, rows)


def asm():
    lead, bass, drm = stream(LEAD), stream(BASS), drums(DRUMS)
    for name, d in (('lead', lead), ('bass', bass), ('drums', drm)):
        check(name, d, 128)
    out = ['NOTETAB:', '    dw 0']
    divs = [round(CLOCK / freq(k)) for k in range(1, 85)]
    for i in range(0, len(divs), 12):
        out.append('    dw ' + ','.join(str(v) for v in divs[i:i + 12]))
    for name, d in (('tune_lead', lead), ('tune_bass', bass), ('tune_drums', drm)):
        out.append(name + ':')
        for i in range(0, len(d), 16):
            out.append('    db ' + ','.join(str(v) for v in d[i:i + 16]))
        out.append('    db 0FFh')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    print(asm())
