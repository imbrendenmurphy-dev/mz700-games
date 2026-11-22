"""scene_planet.py - ships in front of a close planet: hidden lines,
occlusion and the crescent.  py tools/scene_planet.py -> build/shots/"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

SHIPS = [(-190, 40, 400, 3), (-40, 160, 800, 2), (200, -60, 1100, 5)]


def setup():
    g = Game()
    g.launch(120)
    m = g.m.mem
    ob = S['objects']

    def w16(a, v):
        m[a] = v & 255
        m[a + 1] = (v >> 8) & 255
    w16(S['planet'], 1500)
    w16(S['planet'] + 2, -1200)
    w16(S['planet'] + 4, 8000)
    m[S['spawn_t']] = 255
    for k, (x, y, z, t) in enumerate(SHIPS, 1):
        base = ob + 32 * k
        m[base:base + 32] = m[ob:ob + 32]
        m[base] = t
        m[base + 1] = 0
        w16(base + 2, x)
        w16(base + 4, y)
        w16(base + 6, z)
        m[base + 26:base + 32] = bytes([0, 2, 0, 200, 0, 0])
    m[S['speed']] = 0
    return g


if __name__ == '__main__':
    g = setup()
    g.run(16)
    g.shot('scene_planet')
    f0 = g.rb('frame')
    g.run(150)
    print('frames in 150 fields: %d (%.1f fps)' % ((g.rb('frame') - f0) & 255, ((g.rb('frame') - f0) & 255) / 3.0))
