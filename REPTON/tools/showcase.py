"""showcase.py - promotional stills and an animated GIF, taken from the real
Z80 build in the simulator.

    py tools/showcase.py

writes showcase/:
    title.png         the title screen
    play_hub.png      the demo in the Sunlit Hollow
    play_cavern.png   the demo after its first transporter warp
    status.png        the world status screen in a game
    skink.gif         the title, then the attract demo up to and past a warp
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game          # noqa: E402
from mzsim import PAL         # noqa: E402

OUT = os.path.join(ROOT, 'showcase')
os.makedirs(OUT, exist_ok=True)
STEP = 4                      # fields per GIF frame (12.5 frames a second)
SCALE = 2


def frame(g):
    """the MZ-700 screen as a PIL image (320 x 200 x SCALE)"""
    m = g.m
    img = Image.new('RGB', (320, 200))
    px = img.load()
    for r in range(25):
        for c in range(40):
            ch = m.mem[0xD000 + r * 40 + c]
            at = m.mem[0xD800 + r * 40 + c]
            fg = tuple(PAL[(at >> 4) & 7])
            bg = tuple(PAL[at & 7])
            gl = m.glyph(ch, at & 0x80)
            for y in range(8):
                bits = gl[y]
                for x in range(8):
                    px[c * 8 + x, r * 8 + y] = fg if bits & (0x80 >> x) else bg
    return img.resize((320 * SCALE, 200 * SCALE), Image.NEAREST)


def save(img, name):
    img.save(os.path.join(OUT, name))
    print('wrote showcase/' + name)


frames = []
g = Game()

# the title: the logo, the creature parade and the scroller
g.run(20)
for i in range(int(9 * 50 / STEP)):
    g.run(STEP)
    frames.append(frame(g))
    if i == 60:
        save(frames[-1], 'title.png')
n_title = len(frames)

# run through the story, guide and records pages to the demo
waited = 0
while not g.rb('demo'):
    g.run(10)
    waited += 10
    assert waited < 50 * 200, 'the demo never started'
g.run(120)                    # past the reveal

# the demo, until a few seconds after the first warp
warp_at = None
hub_shot = False
for i in range(int(60 * 50 / STEP)):
    g.run(STEP)
    frames.append(frame(g))
    if not hub_shot and i == 60:
        save(frames[-1], 'play_hub.png')
        hub_shot = True
    if warp_at is None and g.rb('region') != 0:
        warp_at = len(frames)
    if warp_at is not None and len(frames) - warp_at == int(4 * 50 / STEP):
        save(frames[-1], 'play_cavern.png')
    if warp_at is not None and len(frames) - warp_at >= int(7 * 50 / STEP):
        break
    if not g.rb('demo'):
        break
assert warp_at is not None, 'the demo did not warp within a minute'
print('title %d frames, demo %d frames, warp at frame %d' % (n_title, len(frames) - n_title, warp_at))

# GIF: shrink the palette once (8 MZ-700 colours) and keep it small
pal_img = Image.new('P', (1, 1))
flat = []
for c in PAL:
    flat += list(c)
pal_img.putpalette(flat + [0] * (768 - len(flat)))
gif = [f.quantize(palette=pal_img, dither=Image.Dither.NONE) for f in frames]
durations = [STEP * 20] * len(gif)
durations[n_title - 1] = 800  # a beat between the title and the demo
gif[0].save(os.path.join(OUT, 'skink.gif'), save_all=True, append_images=gif[1:],
            duration=durations, loop=0, optimize=True, disposal=1)
print('wrote showcase/skink.gif (%d frames, %.0f KB)' % (
    len(gif), os.path.getsize(os.path.join(OUT, 'skink.gif')) / 1024))

# a status screen from a real game
g2 = Game()
g2.run(60)
g2.run(5, ['space'])
g2.run(150)
for k, n in (('right', 40), ('down', 30), ('left', 25)):
    g2.run(n, [k])
g2.run(20)
g2.run(5, ['space'])
g2.run(60)
save(frame(g2), 'status.png')
