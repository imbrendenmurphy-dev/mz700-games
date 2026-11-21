"""music.py - the SHARP EDGES soundtrack, rendered to a 100 Hz tick stream.

The MZ-700 has one 8253 square-wave channel. The player (src/music.asm) runs
from the counter-2 interrupt 100 times a second and sets one value per tick:

    0          speaker off
    1..111     a note: period table index (1 = C1, MIDI 24)
    0x80+k     a noise burst from the drum table (DRUMS[k])

Everything clever happens here: the drums, the bass/lead interleave at 100 Hz
(two voices out of one channel), the chord arpeggios. The song is split into
bars of 192 ticks, identical bars are stored once, and an order list plays them.
"""

TICKS_ROW = 12          # 100 Hz / 12 = 8.33 rows per second -> 125 BPM in 16ths
ROWS_BAR = 16
TICKS_BAR = TICKS_ROW * ROWS_BAR
PIT_CLOCK = 17734475 / 16    # counter 0 clock

NOTE_BASE = 23          # stream value 1 = MIDI 24 (C1)

# noise bursts: (writes, mask, base, keep sounding afterwards)
DRUMS = [
    (10, 0x1F, 24, 0),      # 0 closed hat
    (36, 0xFF, 70, 1),      # 1 snare attack
    (28, 0x1FF, 120, 1),    # 2 snare body
    (18, 0x3FF, 200, 0),    # 3 snare tail
    (22, 0x3F, 30, 0),      # 4 open hat
    (40, 0x7FF, 400, 1),    # 5 boom noise (transitions)
]

NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(s):
    """'A3', 'C#4', 'Bb2' -> MIDI number."""
    n = NAMES[s[0]]
    i = 1
    if s[i:i + 1] == '#':
        n += 1
        i += 1
    elif s[i:i + 1] == 'b':
        n -= 1
        i += 1
    return 12 * (int(s[i:]) + 1) + n


def period_table():
    out = [0]
    for i in range(1, 112):
        m = i + NOTE_BASE
        f = 440.0 * 2 ** ((m - 69) / 12.0)
        out.append(min(65535, int(round(PIT_CLOCK / f))))
    return out


def nv(m):
    """MIDI -> stream value."""
    v = m - NOTE_BASE
    assert 1 <= v <= 111, m
    return v


# ---------------------------------------------------------------- notation
# A melody line: space-separated tokens, each one row (16th) unless it has a
# length suffix: 'A4:4' = 4 rows.  '.' = rest, '-' = hold previous note.
def parse_line(text, rows=ROWS_BAR):
    out = []
    for tok in text.split():
        ln = 1
        if ':' in tok:
            tok, l = tok.split(':')
            ln = int(l)
        if tok == '.':
            out += [None] * ln
        elif tok == '-':
            out += ['-'] * ln
        else:
            out += [midi(tok)] + ['-'] * (ln - 1)
    assert len(out) % rows == 0, (text, len(out))
    return out


CHORDS = {
    'Am': ('A2', [0, 3, 7]), 'F': ('F2', [0, 4, 7]), 'C': ('C3', [0, 4, 7]),
    'G': ('G2', [0, 4, 7]), 'E': ('E2', [0, 4, 7]), 'Dm': ('D3', [0, 3, 7]),
    'Em': ('E2', [0, 3, 7]), 'E7': ('E2', [0, 4, 10]), 'Fmaj7': ('F2', [0, 4, 11]),
    'Bb': ('Bb2', [0, 4, 7]),
}

# drum lanes, one char per row: k kick, s snare, h hat, o open hat, . none
DRUMS_FULL = 'k.h.s.hkk.h.s.ho'
DRUMS_HALF = 'k...s...k...s..h'
DRUMS_HATS = '..h...h...h...hh'
DRUMS_FOUR = 'k.h.k.h.k.h.k.ho'
DRUMS_FILL = 'k.s.s.k.ssssssss'

KICK = [midi(n) for n in ('C5', 'E4', 'A3', 'E3', 'C3')]


def drum_ticks(ch):
    """per-tick overrides for a drum hit at the start of a row."""
    if ch == 'k':
        return [nv(m) for m in KICK]
    if ch == 's':
        return [0x81, 0x82, 0x82, 0x83]
    if ch == 'h':
        return [0x80]
    if ch == 'o':
        return [0x84, 0x84]
    return []


class Bar:
    def __init__(self, chord, drums='', bass='octave', lead=None, arp=False,
                 arp_oct=4, lead_mode='alt'):
        self.chord = chord
        self.drums = drums
        self.bass = bass
        self.lead = lead            # list of 16 entries (MIDI / None / '-')
        self.arp = arp
        self.arp_oct = arp_oct
        self.lead_mode = lead_mode

    def render(self, prev_lead=None):
        root, ivs = CHORDS[self.chord]
        r = midi(root)
        ticks = []
        lead = self.lead or [None] * ROWS_BAR
        cur = prev_lead
        for row in range(ROWS_BAR):
            # bass for this row
            b = None
            if self.bass == 'octave':
                b = r + (12 if (row // 2) % 2 else 0)
            elif self.bass == 'pulse':
                b = r if row % 4 in (0, 1, 3) else r + 12
            elif self.bass == 'root':
                b = r
            elif self.bass == 'walk':
                b = r + [0, 0, 12, 0, 7, 0, 12, 10][row // 2]
            # lead
            ln = lead[row]
            if ln == '-':
                pass
            elif ln is None:
                cur = None
            else:
                cur = ln
            row_ticks = []
            dt = drum_ticks(self.drums[row]) if self.drums else []
            for t in range(TICKS_ROW):
                if t < len(dt):
                    row_ticks.append(dt[t])
                    continue
                gt = row * TICKS_ROW + t
                arp_note = None
                if self.arp:
                    a = ivs[gt % len(ivs)]
                    arp_note = midi('A%d' % self.arp_oct) - 9 + (r % 12) + a
                    if arp_note > midi('B%d' % self.arp_oct) + 2:
                        arp_note -= 12
                voices = []
                if cur is not None:
                    voices.append(cur)
                elif arp_note is not None:
                    voices.append(arp_note)
                # bass: plucked - sounds in the first 7 ticks of its row
                if b is not None and t < 7:
                    voices.append(b)
                if not voices:
                    row_ticks.append(0)
                elif len(voices) == 1:
                    row_ticks.append(nv(voices[0]))
                else:
                    # interleave lead and bass at 100 Hz, lead gets 2 of 3
                    if self.lead_mode == 'alt':
                        row_ticks.append(nv(voices[gt % 2]))
                    else:
                        row_ticks.append(nv(voices[0 if gt % 3 else 1]))
            ticks += row_ticks
        return ticks, cur


# ---------------------------------------------------------------- the song
def bars_from(prog, **kw):
    return [Bar(c, **kw) for c in prog]


def lead_bars(prog, text, **kw):
    notes = parse_line(text)
    out = []
    for i, c in enumerate(prog):
        out.append(Bar(c, lead=notes[i * 16:(i + 1) * 16], **kw))
    return out


PROG_A = ['Am', 'F', 'C', 'G']
PROG_B = ['Am', 'F', 'G', 'E']
PROG_C = ['Dm', 'Am', 'Bb', 'E']

MEL_A = ('A4:3 C5:3 E5:2 D5:4 C5:2 B4:2 '
         'A4:3 C5:3 F5:2 E5:4 C5:4 '
         'G4:3 C5:3 E5:2 G5:4 E5:2 D5:2 '
         'D5:3 B4:3 G4:2 B4:4 D5:4')
MEL_A2 = ('A4:3 C5:3 E5:2 D5:4 C5:2 B4:2 '
          'A4:3 C5:3 F5:2 E5:4 A5:4 '
          'G5:3 E5:3 D5:2 E5:4 D5:2 B4:2 '
          'G#4:3 B4:3 E5:2 G#5:4 B5:4')
MEL_B = ('E5:2 E5:1 A5:3 G5:2 E5:4 D5:2 C5:2 '
         'C5:2 C5:1 F5:3 E5:2 C5:4 A4:4 '
         'B4:2 B4:1 D5:3 G5:2 F5:4 E5:2 D5:2 '
         'E5:6 G#4:2 B4:4 E5:4')
MEL_C = ('D5:2 F5:2 A5:4 G5:2 F5:2 E5:2 D5:2 '
         'C5:2 E5:2 A5:4 E5:4 C5:4 '
         'D5:2 F5:2 Bb5:4 A5:2 F5:2 D5:4 '
         'E5:4 G#5:4 B5:4 E6:4')
MEL_D = ('A5:1 E5:1 C5:1 A4:1 A5:1 E5:1 C5:1 A4:1 G5:2 E5:2 C5:2 E5:2 '
         'F5:1 C5:1 A4:1 F4:1 F5:1 C5:1 A4:1 F4:1 A5:4 C6:4 '
         'G5:1 D5:1 B4:1 G4:1 G5:1 D5:1 B4:1 G4:1 B5:2 G5:2 D5:2 B4:2 '
         'E5:2 G#5:2 B5:2 E6:2 D6:2 B5:2 G#5:2 E5:2')


def song():
    """sections: (name, [Bar...]). The demo script syncs parts to these."""
    S = []
    # intro: chords as fast arpeggios, no drums
    S.append(('intro', bars_from(PROG_A, bass=None, arp=True, arp_oct=4)))
    # title: beat kicks in
    title = (bars_from(PROG_A, drums=DRUMS_HALF, bass='octave', arp=True) +
             lead_bars(PROG_A, MEL_A, drums=DRUMS_FULL, bass='octave') +
             lead_bars(PROG_B, MEL_A2, drums=DRUMS_FULL, bass='octave'))
    S.append(('title', title))
    plasma = (lead_bars(PROG_A, MEL_B, drums=DRUMS_FULL, bass='walk') +
              lead_bars(PROG_B, MEL_D, drums=DRUMS_FOUR, bass='pulse'))
    S.append(('plasma', plasma))
    roto = (bars_from(PROG_C, drums=DRUMS_HALF, bass='pulse', arp=True, arp_oct=5) +
            lead_bars(PROG_C, MEL_C, drums=DRUMS_FULL, bass='octave'))
    S.append(('roto', roto))
    tunnel = (bars_from(PROG_B, drums=DRUMS_HATS, bass='walk', arp=True) +
              lead_bars(PROG_B, MEL_D, drums=DRUMS_FULL, bass='walk'))
    S.append(('tunnel', tunnel))
    kefrens = (bars_from(PROG_C, drums=DRUMS_FOUR, bass='walk', arp=True, arp_oct=5) +
               lead_bars(PROG_C, MEL_C, drums=DRUMS_FULL, bass='pulse'))
    S.append(('kefrens', kefrens))
    dots = (lead_bars(PROG_A, MEL_A, drums=DRUMS_FOUR, bass='octave') +
            lead_bars(PROG_B, MEL_A2, drums=DRUMS_FULL, bass='octave') +
            lead_bars(PROG_C, MEL_C, drums=DRUMS_FULL, bass='pulse'))
    S.append(('dots', dots))
    greets = (lead_bars(PROG_A, MEL_B, drums=DRUMS_FULL, bass='walk') +
              lead_bars(PROG_B, MEL_D, drums=DRUMS_FULL, bass='pulse') +
              bars_from(PROG_A[:3], drums=DRUMS_FULL, bass='octave', arp=True) +
              [Bar('E', drums=DRUMS_FILL, bass='octave', arp=True)])
    S.append(('greets', greets))
    end = (lead_bars(PROG_A, MEL_A, bass='root', lead_mode='3') +
           bars_from(['Am', 'F', 'E', 'Am'], bass='root', arp=True, arp_oct=4))
    S.append(('end', end))
    return S


def build():
    """-> dict: unique bars, order list, section start bars, period table."""
    secs = song()
    bars = []
    order = []
    starts = []
    cur = None
    for name, blist in secs:
        starts.append((name, len(order)))
        for b in blist:
            t, cur = b.render(cur)
            assert len(t) == TICKS_BAR
            t = tuple(t)
            if t not in bars:
                bars.append(t)
            order.append(bars.index(t))
    return dict(bars=bars, order=order, starts=starts, periods=period_table(),
                drums=DRUMS)


if __name__ == '__main__':
    d = build()
    print('%d bars in the song, %d unique (%d bytes), %.1f s' % (
        len(d['order']), len(d['bars']), len(d['bars']) * TICKS_BAR,
        len(d['order']) * TICKS_BAR / 100.0))
    for n, s in d['starts']:
        print('  %-8s bar %3d  %6.1f s' % (n, s, s * TICKS_BAR / 100.0))
