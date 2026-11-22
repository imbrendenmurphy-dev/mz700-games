"""scene_station.py - the station close ahead at three angles (hidden lines).
py tools/scene_station.py -> build/shots/stn_*.png"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402


def w16(m, a, v):
    m[a] = v & 255
    m[a + 1] = (v >> 8) & 255


if __name__ == '__main__':
    g = Game()
    g.launch(100)
    m = g.m.mem
    ob = S['objects']
    m[S['spawn_t']] = 255
    m[S['speed']] = 0
    for k in range(1, 8):
        m[ob + 32 * k] = 0
    # station 600 ahead, a little up and right; orientation: facing us,
    # then turned 30 and 60 degrees (side and nose mixed)
    import math
    for name, ang in (('front', 0), ('turn30', 30), ('turn70', 70)):
        a = math.radians(ang)
        side = (-math.cos(a), 0, -math.sin(a))
        nose = (math.sin(a), 0, -math.cos(a))
        w16(m, ob + 2, 60)
        w16(m, ob + 4, 40)
        w16(m, ob + 6, 600)
        for off, v in ((8, side), (14, (0, 1, 0)), (20, nose)):
            for i in range(3):
                w16(m, ob + off + 2 * i, round(v[i] * 0x4000))
        g.run(4)
        g.shot('stn_' + name)
    print('ok')
