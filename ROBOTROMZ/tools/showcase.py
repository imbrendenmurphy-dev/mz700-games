"""showcase.py - promotional stills and an animated GIF, taken from the real
Z80 build running in the MZ-700 model.

    py tools/showcase.py

writes showcase/:
    attract_title.png  attract_story.png  attract_robots.png
    attract_howto.png  attract_demo.png   attract_heroes.png
    play_wave1.png     play_fence.png     play_3way.png
    play_shield.png    play_corridors.png play_clear.png
    robogeddon.gif     the attract sequence, then a gameplay montage

GIF frames are sampled on emulated time (every 4 fields = 12.5 frames a
second), so the GIF runs at the game's real speed.  Needs Pillow and the
CG-ROM image at rom/mz700fon.int.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from mzemu import MZ, load_syms  # noqa: E402
from mzfont import PAL  # noqa: E402
import play  # noqa: E402

B = os.path.join(ROOT, 'build')
OUT = os.path.join(ROOT, 'showcase')
FIELD = 70886                   # T-states per PAL field
STEP = 4                        # fields per GIF frame
SCALE = 2


class Scene:
    """one machine: run it in real (emulated) time, grab frames and stills"""

    def __init__(self, wave=None, god=False, seed=None):
        for k in ('WAVE', 'GOD', 'DEMO'):
            os.environ.pop(k, None)
        if wave:
            os.environ['WAVE'] = str(wave)
        if god:
            os.environ['GOD'] = '1'
        self.sym = load_syms(os.path.join(B, 'robogedn.sym'))
        self.m = MZ(os.path.join(B, 'ROBOGEDN.MZT'))
        play.patch(self.m, self.sym)
        self.seed = seed
        self.ticks = 0
        self.m.run_until_pc(self.sym['wait_vblank'], 10 ** 8)
        self.next_grab = None

    def rb(self, name, off=0):
        return self.m.mem[self.sym[name] + off]

    def wb(self, name, v, off=0):
        self.m.mem[self.sym[name] + off] = v & 0xFF

    def ww(self, name, v):
        self.wb(name, v)
        self.wb(name, v >> 8, 1)

    def tick(self, keys=()):
        self.m.held = set(keys)
        self.m.step()
        self.m.run_until_pc(self.sym['wait_vblank'], 10 ** 9)
        self.ticks += 1

    def screen(self):
        return self.m.screen(SCALE)

    def run(self, seconds=None, keys=lambda t: (), until=None, frames=None, limit=60):
        """run for seconds (or until until() is true), adding a frame to the
        list every STEP fields if frames is given"""
        t0 = self.m.cpu.t
        end = t0 + seconds * 50 * FIELD if seconds else t0 + limit * 50 * FIELD
        if frames is not None:
            self.next_grab = t0
        k = 0
        while self.m.cpu.t < end:
            if until and until():
                break
            self.tick(keys(k))
            k += 1
            if frames is not None and self.m.cpu.t >= self.next_grab:
                frames.append(self.screen())
                self.next_grab += STEP * FIELD
        return frames

    def press_start(self):
        if self.seed:               # (the wave is spawned as SPACE is seen)
            self.wb('seed', self.seed & 0xFF)
            self.wb('seed', (self.seed >> 8) | 1, 1)
        for _ in range(4):
            self.tick(['space'])

    def next_page(self):
        """end the current attract page now"""
        self.ww('ptick', 0xFFF0)


def save(img, name):
    img.save(os.path.join(OUT, name))
    print('wrote showcase/' + name)


def main():
    os.makedirs(OUT, exist_ok=True)
    gif = []                    # (frames, hold-the-last-frame ms)

    # ---- the attract sequence, from power-on
    s = Scene()
    f = s.run(4.5, frames=[])
    save(f[-1], 'attract_title.png')
    gif.append((f, 500))
    s.next_page()
    s.tick()
    f = s.run(4.0, frames=[])                       # story, typing
    s.run(5.0)
    save(s.screen(), 'attract_story.png')
    gif.append((f, 400))
    s.next_page()
    s.tick()
    f = s.run(7.6, frames=[])                       # the robots arriving
    save(f[-1], 'attract_robots.png')
    gif.append((f, 500))
    s.next_page()
    s.tick()
    f = s.run(2.5, frames=[])                       # how to play
    save(f[-1], 'attract_howto.png')
    gif.append((f, 400))
    s.next_page()
    s.tick()
    f = s.run(9.0, frames=[])                       # the demo
    save(f[-1], 'attract_demo.png')
    gif.append((f, 600))
    attract = gif[:]

    # ---- gameplay scenes (invincible, so the camera can stay on the action)
    # wave 1: the first droids go to pieces
    g = Scene(seed=1234)
    g.run(6.0)
    g.press_start()
    g.run(until=lambda: g.rb('state') == 1)
    g.run(5.0, keys=lambda k: play.s_play(k + 520))
    save(g.screen(), 'play_wave1.png')

    # wave 8: the Electric Fence caption, then the 3-Way spray
    g = Scene(wave=8, god=True, seed=4242)
    g.run(6.0)
    g.press_start()
    f = g.run(until=lambda: g.rb('state') == 1, frames=[])
    save(f[len(f) * 2 // 3], 'play_fence.png')
    g.ww('pw3', 1500)
    g.wb('hudpw', 1)
    f2 = g.run(6.0, keys=lambda k: play.s_play(k + 520), frames=[])
    save(f2[-1], 'play_3way.png')
    gif.append((f + f2, 300))

    # wave 5: mindbots, with the Shield up
    g = Scene(wave=5, god=True, seed=777)
    g.run(6.0)
    g.press_start()
    g.run(until=lambda: g.rb('state') == 1)
    g.run(2.0, keys=lambda k: play.s_play(k + 520))
    g.ww('pwsh', 1500)
    g.wb('hudpw', 1)
    f = g.run(5.0, keys=lambda k: play.s_stand(k + 520), frames=[])
    save(f[len(f) // 2], 'play_shield.png')
    gif.append((f, 300))

    # wave 13: corridors of doom
    g = Scene(wave=13, god=True, seed=99)
    g.run(6.0)
    g.press_start()
    g.run(until=lambda: g.rb('state') == 1)
    g.run(4.0, keys=lambda k: play.s_play(k + 520))
    save(g.screen(), 'play_corridors.png')

    # wave 7 cleared: fireworks
    g = Scene(wave=7, god=True, seed=1234)
    g.run(6.0)
    g.press_start()
    g.run(until=lambda: g.rb('state') == 3, keys=lambda k: play.s_stand(k + 520), limit=120)
    f = g.run(3.0, frames=[])
    save(f[len(f) // 3], 'play_clear.png')
    gif.append((f, 300))

    # the heroes page (where the attract sequence goes after the demo)
    s.run(until=lambda: s.rb('page') == 5)
    f = s.run(3.0, frames=[])
    save(f[-1], 'attract_heroes.png')
    gif.append((f, 800))

    # ---- GIF: 8 MZ-700 colours, no dithering
    pal_img = Image.new('P', (1, 1))
    flat = []
    for c in PAL:
        flat += list(c)
    pal_img.putpalette(flat + [0] * (768 - len(flat)))
    frames, durations = [], []
    for fl, hold in gif:
        for i, fr in enumerate(fl):
            frames.append(fr.quantize(palette=pal_img, dither=Image.Dither.NONE))
            durations.append(hold if i == len(fl) - 1 else STEP * 20)
    path = os.path.join(OUT, 'robogeddon.gif')
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, optimize=True, disposal=1)
    print('wrote showcase/robogeddon.gif (%d frames, %.1f s, %.0f KB)' % (
        len(frames), sum(durations) / 1000.0, os.path.getsize(path) / 1024))


if __name__ == '__main__':
    main()
