"""shots.py - README screenshots into docs/."""
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
g.run(900)                    # title page lasts 20 s
g.run(400)
keep(g, 'guide')
# a game in cave B, played by the pilot
g = Game()
g.run(30)
g.wb('start_cave', 1)
g.run(10, ['space'])
g.run(60)
keep(g, 'intro')
while g.rb('inbox_time') != 0:
    g.run(5)
g.wb('demo', 1)
g.run(700)
keep(g, 'cave')
print('done')
