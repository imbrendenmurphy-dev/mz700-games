"""palettes.py - a contact sheet of every act's arena and the info pages (build/shots/palettes.png)"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from run import Game, S  # noqa: E402

out = []
for act in range(1, 10):
    g = Game()
    g.run(60)
    g.m.held = {'space'}
    g.m.run_until_pc(S['wait_release'], max_t=70886 * 50)
    g.m.held = set()
    g.m.run_until_pc(S['act_setup'], max_t=70886 * 200)
    g.wb('act', act - 1)
    g.wb('autoplay', 1)
    g.wb('turbo', 1)
    g.m.run_until_pc(S['play_act'], max_t=70886 * 2000)
    g.run(120)
    out.append(g.shot('pal_act%d' % act))
for page in ('howto_screen', 'goodies_screen', 'hiscore_screen', 'preview_screen'):
    g = Game()
    g.run(30)
    c = g.m.cpu
    c.sp -= 2
    c.pc = S[page]
    g.run(40)
    out.append(g.shot('pal_' + page))
ims = [Image.open(p).resize((320, 200)) for p in out]
sheet = Image.new('RGB', (960, 200 * ((len(ims) + 2) // 3)))
for k, im in enumerate(ims):
    sheet.paste(im, ((k % 3) * 320, (k // 3) * 200))
sheet.save(os.path.join(os.path.dirname(out[0]), 'palettes.png'))
print('ok')
