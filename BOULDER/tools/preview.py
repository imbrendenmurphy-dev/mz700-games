"""preview.py - render every cave as the game would show it (build/cave_X.png)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caves  # noqa: E402
import mzfont as F  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def render(c, phase=0, scale=2):
    """the whole cave (any size) with its name underneath"""
    cw, chh = max(c.w, 40), c.h + 3
    ch = [0] * (cw * chh)
    at = [0x70] * (cw * chh)
    txt = F.text_codes('CAVE %s  %s  %dX%d' % (c.letter, c.name, c.w, c.h))
    for i, v in enumerate(txt[:cw]):
        ch[(chh - 1) * cw + i] = v
    looks = caves.theme_looks(getattr(c, 'theme', 0) or 0)[0]
    for y in range(c.h):
        for x in range(c.w):
            e = c.g[y][x]
            look = looks['PLAYER'] if e == 'INBOX' else looks[e]
            g, a = look[phase]
            ch[(y + 1) * cw + x] = g
            at[(y + 1) * cw + x] = a
    return F.render_cells(ch, at, cw, chh, scale=scale)


if __name__ == '__main__':
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    for c in caves.caves():
        avail = c.check()
        render(c).save(os.path.join(ROOT, 'build', 'cave_%s.png' % c.letter))
        print(c.letter, c.name, 'need', c.need, 'avail', avail)
