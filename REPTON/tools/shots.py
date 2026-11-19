"""shots.py - screenshots for the README (docs/*.png): title, guide, play, status."""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game  # noqa: E402

docs = os.path.join(ROOT, 'docs')
os.makedirs(docs, exist_ok=True)
g = Game()
g.run(150)
shutil.copy(g.shot('doc_title'), os.path.join(docs, 'title.png'))
g.run(1700)
shutil.copy(g.shot('doc_guide'), os.path.join(docs, 'guide.png'))
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'test_frontend.py')], check=True)
shutil.copy(os.path.join(ROOT, 'build', 'shots', 'fe_play.png'), os.path.join(docs, 'play.png'))
shutil.copy(os.path.join(ROOT, 'build', 'shots', 'fe_status.png'), os.path.join(docs, 'status.png'))
print('docs/ updated')
