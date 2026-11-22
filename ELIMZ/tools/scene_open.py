"""scene_open.py - frame rate in open space after launch (planet ahead)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

if __name__ == '__main__':
    g = Game()
    g.launch(150)
    g.m.mem[S['spawn_t']] = 255
    f0 = g.rb('frame')
    g.run(300)
    n = (g.rb('frame') - f0) & 255
    print('open space: %d frames in 300 fields (%.1f fps)' % (n, n / 6.0))
