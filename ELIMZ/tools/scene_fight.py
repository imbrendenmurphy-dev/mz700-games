"""scene_fight.py - frame rate with three pirates close ahead (the wav.py
fight scene).  py tools/scene_fight.py"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402


def setup():
    g = Game()
    g.launch(90)
    m = g.m.mem
    ob = S['objects']

    def w16(a, v):
        m[a] = v & 255
        m[a + 1] = (v >> 8) & 255
    for k, (x, y, z, t) in enumerate([(-30, 10, 700, 3), (40, -20, 900, 2), (0, 30, 1300, 4)], 1):
        base = ob + 32 * k
        m[base:base + 32] = m[ob:ob + 32]
        m[base] = t
        m[base + 1] = 0
        w16(base + 2, x)
        w16(base + 4, y)
        w16(base + 6, z)
        m[base + 26:base + 32] = bytes([0, 2, 0, 200, 0, 0])
    w16(ob + 6, -6000)
    m[S['spawn_t']] = 255
    return g


if __name__ == '__main__':
    g = setup()
    g.run(10)
    g.shot('scene_fight')
    f0 = g.rb('frame')
    g.run(300)
    n = (g.rb('frame') - f0) & 255
    print('frames in 300 fields: %d (%.1f fps)' % (n, n / 6.0))
