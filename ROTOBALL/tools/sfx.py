"""sfx.py - sound effects and jingles for the MZ-700's single 8253 square-wave voice.

A sound is a list of 16-bit words, one per sound tick (about 7 ticks per game
frame, roughly 8-9 ms each):
    divisor     play this 8253 counter-0 divisor (clock / frequency)
    0FFxxh      noise: random low byte, high byte xx (smaller = higher)
    0FE00h      rest (gate off for this tick)
    0           end
Chords and "two voices" are faked by alternating notes on successive ticks.
"""
import math

CLOCK = 1108800          # 8253 counter 0 input on the PAL MZ-700
REST = 0xFE00


def noise(band):
    return 0xFF00 | band


def div(freq):
    return max(2, min(0xFDFF, round(CLOCK / freq)))


def note(name):
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2,
             'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    n, octave = name[:-1], int(name[-1])
    semis = names[n] + (octave - 4) * 12
    return 440.0 * 2 ** (semis / 12)


def sweep(f0, f1, ticks, noise_every=0, band=2):
    out = []
    for i in range(ticks):
        f = f0 * (f1 / f0) ** (i / max(1, ticks - 1))
        if noise_every and i % noise_every == noise_every - 1:
            out.append(noise(band))
        else:
            out.append(div(f))
    return out


def arp(notes, ticks_each):
    out = []
    for n in notes:
        out += [div(note(n))] * ticks_each
    return out


def tune(steps, tick_len=7):
    """steps: list of (melody note or None, bass note or None, length in steps).
    Melody and bass alternate tick by tick; a short gap separates notes."""
    out = []
    for mel, bass, length in steps:
        ticks = length * tick_len
        for t in range(ticks):
            if t >= ticks - 1:
                out.append(REST)
            elif bass and mel and t % 2:
                out.append(div(note(bass)))
            elif mel:
                out.append(div(note(mel)))
            elif bass:
                out.append(div(note(bass)))
            else:
                out.append(REST)
    return out


SOUNDS = {
    # name: (priority, words)
    'clink': (1, [div(2600), div(3400), div(2900), div(4200)]),
    'gem': (2, arp(['C6', 'E6', 'G6', 'C7', 'E7', 'G7', 'C8'], 2) + arp(['G7', 'C8'], 3)),
    'pickup': (3, sweep(300, 2400, 18) + arp(['C7', 'G7', 'C8'], 3)),
    'stomp': (3, [div(900), noise(1)] + sweep(700, 110, 16, noise_every=3, band=3) + [div(90)] * 3),
    'bomb': (4, [noise(b) for b in (1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16, 18, 20, 24)
                 for _ in range(2)]),
    'shieldhit': (3, sweep(3000, 800, 10, noise_every=2, band=1)),
    'exitopen': (4, tune([('C6', 'C4', 1), ('E6', 'C4', 1), ('G6', 'E4', 1), ('C7', 'G4', 3)], 5)),
    'death': (5, sweep(1400, 900, 8) + sweep(1100, 60, 46, noise_every=3, band=6) + [REST] * 6),
    'start': (6, tune([('C5', 'C3', 2), ('G5', 'C3', 1), ('E5', 'G3', 1), ('C6', 'C4', 2),
                       ('B5', 'G3', 1), ('G5', 'G3', 1), ('A5', 'F3', 2), ('G5', 'C3', 4)])),
    'clear': (6, tune([('G5', 'C4', 1), ('C6', 'E4', 1), ('E6', 'G4', 1), ('G6', 'C5', 1),
                       ('E6', 'G4', 1), ('G6', 'C5', 1), ('C7', 'E5', 6)], 6)),
    'gameover': (6, tune([('G4', 'C3', 3), ('D#4', 'C3', 3), ('C4', 'G2', 3), ('B3', 'G2', 2),
                          ('C4', 'C3', 6)], 8)),
}


def asm():
    out = []
    for name, (pri, words) in SOUNDS.items():
        out.append('SFXP_%s = %d' % (name.upper(), pri))
        out.append('sfx_%s:' % name)
        for i in range(0, len(words), 12):
            out.append('    dw ' + ','.join('0%04Xh' % w for w in words[i:i + 12]))
        out.append('    dw 0')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    for name, (pri, words) in SOUNDS.items():
        print('%-10s pri %d  %3d ticks (~%.2fs)' % (name, pri, len(words), len(words) * 0.0086))
