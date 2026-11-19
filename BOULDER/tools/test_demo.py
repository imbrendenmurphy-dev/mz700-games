"""test_demo.py - run the attract mode into the demo and watch the pilot.

    py tools/test_demo.py [fields] [shot_every]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game  # noqa: E402

fields = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
every = int(sys.argv[2]) if len(sys.argv) > 2 else 250
g = Game()
last = None
for f in range(fields):
    g.run(1)
    if g.rb('demo'):
        st = (g.rb('cave_no'), g.rb('got'), g.rb('pl_dead'), g.rb('exit_open'), g.rb('pl_exit'))
        if st != last:
            print('field %5d cave %d got %2d dead %d exit %d out %d' % ((f,) + st))
            last = st
    if f % every == every - 1:
        g.shot('demo_%05d' % f)
print('drops', g.rb('drops'))
