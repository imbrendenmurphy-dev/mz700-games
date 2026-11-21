"""test_view.py - generate an island and render views from the start tile.

    py tools/test_view.py [island] [headings...]

Writes build/shots/view_<island>_<heading>.png and reports render times.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

CPU = 3546875


def main():
    isl = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    hds = [int(a) for a in sys.argv[2:]] or [None]
    g = Game()
    g.wb('island', isl)
    t = g.call('gen_island')
    print('generate %.2f s' % (t / CPU))
    g.call('hud_draw') if False else None
    g.wb('pitch', 1)
    g.wb('beam', 0)
    for h in hds:
        if h is None:
            # face the lantern like play_island does
            pt = g.rw('ptile')
            lt = g.rw('lant_t')
            import math
            dx = (lt & 31) - (pt & 31)
            dy = (lt >> 5) - (pt >> 5)
            h = int(round(math.atan2(dx, -dy) / (2 * math.pi) * 32)) % 32
        g.wb('heading', h)
        g.wb('ccx', 20)
        g.wb('ccy', 12)
        g.wb('cur_on', 0)
        t = g.call('do_render')
        p = g.shot('view_%d_%02d' % (isl, h))
        print('heading %2d: render %.2f s  objects %d  -> %s' % (h, t / CPU, g.rb('nobj'), p))
        print('  target kind %d tile %d ok %d' % (g.rb('tgt_kind'), g.rw('tgt_t'), g.rb('tgt_ok')))


if __name__ == '__main__':
    main()
