"""shots.py - README screenshots into docs/ (title, guide, a cave card, the demo)."""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, ROOT  # noqa: E402

DOCS = os.path.join(ROOT, 'docs')
os.makedirs(DOCS, exist_ok=True)


def keep(g, name):
    shutil.copy(g.shot(name), os.path.join(DOCS, name + '.png'))


g = Game()
g.run(300)
keep(g, 'title')
g.run(900)                     # the title page lasts 20 s
g.run(400)
keep(g, 'guide')
while not g.rb('demo'):        # on to the demo: its cave card, then the replay
    g.run(10)
g.run(60)
keep(g, 'intro')
while g.rb('inbox_time'):
    g.run(5)
g.run(int(sys.argv[1]) if len(sys.argv) > 1 else 900)
keep(g, 'cave')
print('done, demo cave', chr(65 + g.rb('cave_no')))
