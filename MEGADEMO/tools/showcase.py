"""showcase.py - stills of every part and an animated GIF of the whole demo,
taken from the real build (release/SHARPEDG.MZT) running in mzemu.

    py tools/showcase.py [stills|gif]       (default: both)

writes showcase/:
    NN_part.png       one still per part, 640x400 (2x)
    sharpedges.gif    the decruncher, then a short clip of every part, at the
                      demo's real speed (a frame every 4 fields = 80 ms)

Needs Pillow and ..\\MZ700onPC\\mzemu.exe.  Part start bars come from
tools/music.py, so it follows the song if the running order changes.
"""
import glob
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import music  # noqa: E402

EMU = os.path.join(ROOT, '..', 'MZ700onPC', 'mzemu.exe')
MZT = os.path.join(ROOT, 'release', 'SHARPEDG.MZT')
OUT = os.path.join(ROOT, 'showcase')
STEP = 4                        # fields per GIF frame

# part: (bars into the part, extra fields) for the still, and GIF seconds
SHOTS = {
    'intro':   (2, 40, 2.4), 'title':   (3, 30, 3.2), 'plasma':  (2, 40, 2.4),
    'stars':   (2, 20, 2.0),  'roto':    (2, 40, 2.4), 'fire':    (2, 40, 2.4),
    'tunnel':  (2, 40, 2.4),  'vortex':  (1, 40, 2.0), 'kefrens': (4, 10, 2.4),
    'twist':   (2, 40, 2.4),  'shade':   (3, 40, 2.4), 'moire':   (2, 40, 2.4),
    'floor':   (2, 40, 2.4),  'cube':    (1, 50, 2.4), 'dots':    (1, 90, 2.4),
    'barrel':  (2, 40, 2.4),  'sdots':   (1, 60, 2.0), 'ebobs':   (2, 60, 2.4),
    'wobble':  (1, 40, 2.4),  'crash':   (0, 75, 2.4), 'greets':  (1, 40, 2.8),
    'end':     (4, 40, 2.4),
}
TITLES = {
    'intro': 'intro', 'title': 'title', 'plasma': 'plasma', 'stars': 'starfield',
    'roto': 'rotozoomer', 'fire': 'fire', 'tunnel': 'tunnel', 'vortex': 'vortex',
    'kefrens': 'kefrens_bars', 'twist': 'twister', 'shade': 'shadebobs', 'moire': 'moire',
    'floor': 'sunset_floor', 'cube': 'vector_cube', 'dots': 'vector_dots',
    'barrel': 'rolling_barrels', 'sdots': 'sine_dots', 'ebobs': 'endless_bobs',
    'wobble': 'wobbling_logo', 'crash': 'fake_crash', 'greets': 'greetings', 'end': 'the_end',
}


def emu(script):
    r = subprocess.run([EMU, '-e', script], capture_output=True, text=True, cwd=ROOT)
    if r.returncode:
        sys.exit('mzemu failed:\n' + r.stdout + r.stderr)


def starts():
    return music.build()['starts']


def stills():
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, '[0-9][0-9]_*.png')):
        os.remove(f)
    s = 'mzt %s;' % MZT
    names = []
    for i, (name, bar) in enumerate(starts()):
        b, fields, _ = SHOTS[name]
        fn = os.path.join(OUT, '%02d_%s.png' % (i + 1, TITLES[name]))
        s += ' untilmem mus_pos %d 40000; frames %d; screen %s 2;' % (bar + b, fields, fn)
        names.append(fn)
    s = 'sym build/megademo.sym; ' + s
    emu(s)
    print('wrote %d stills' % len(names))


def gif():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix='sharpedges_')
    try:
        s = 'sym build/megademo.sym; mzt %s; shots %s 12 %d;' % (
            MZT, os.path.join(tmp, 'a_'), STEP)
        clips = ['a_']
        for i, (name, bar) in enumerate(starts()):
            b, fields, secs = SHOTS[name]
            pre = 'p%02d_' % i
            n = int(secs * 50 / STEP)
            s += ' untilmem mus_pos %d 40000; frames %d; shots %s %d %d;' % (
                bar + b, max(0, fields - 20), os.path.join(tmp, pre), n, STEP)
            clips.append(pre)
        emu(s)
        frames = []
        for pre in clips:
            for f in sorted(glob.glob(os.path.join(tmp, pre + '*.png'))):
                im = Image.open(f).convert('RGB')
                frames.append(im.resize((im.width * 2, im.height * 2), Image.NEAREST))
        # the MZ-700 has 8 colours: one shared palette keeps the GIF small
        pal = Image.new('P', (1, 1))
        cols = [0, 0, 0, 0, 0, 255, 255, 0, 0, 255, 0, 255,
                0, 255, 0, 0, 255, 255, 255, 255, 0, 255, 255, 255]
        pal.putpalette(cols + [0] * (768 - len(cols)))
        q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
        path = os.path.join(OUT, 'sharpedges.gif')
        q[0].save(path, save_all=True, append_images=q[1:], duration=STEP * 20,
                  loop=0, optimize=True, disposal=1)
        print('wrote showcase/sharpedges.gif (%d frames, %.0f s, %.0f KB)' % (
            len(q), len(q) * STEP / 50.0, os.path.getsize(path) / 1024.0))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'both'
    if what in ('stills', 'both'):
        stills()
    if what in ('gif', 'both'):
        gif()
