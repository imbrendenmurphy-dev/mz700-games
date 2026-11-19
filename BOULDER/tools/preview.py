"""preview.py - render every cave as the game would show it (build/cave_X.png)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caves  # noqa: E402
import mzfont as F  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def render(c, phase=0):
    ch = [0] * 1000
    at = [0x70] * 1000
    txt = F.text_codes('CAVE %s  %s' % (c.letter, c.name))
    for i, v in enumerate(txt):
        ch[24 * 40 + i] = v
    for y in range(caves.H):
        for x in range(caves.W):
            e = c.g[y][x]
            look = caves.LOOK['PLAYER'] if e == 'INBOX' else caves.LOOK[e]
            g, a = look[phase]
            ch[(y + 2) * 40 + x] = g
            at[(y + 2) * 40 + x] = a
    return F.render_cells(ch, at, 40, 25, scale=2)


if __name__ == '__main__':
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    for c in caves.caves():
        avail = c.check()
        render(c).save(os.path.join(ROOT, 'build', 'cave_%s.png' % c.letter))
        print(c.letter, c.name, 'need', c.need, 'avail', avail)
