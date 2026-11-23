"""showcase.py - promotional stills and an animated GIF, taken from the real
Z80 build in the simulator.

    py tools/showcase.py [stills|gif]       (default: both)

writes showcase/:
    attract_title.png    the title: logo, digger, scroller
    attract_guide.png    the guide to what lives in the caves
    attract_scores.png   the high-score table
    attract_card.png     a cave card
    play_*.png           the demo replaying recorded solutions in six caves
    undermined.gif         the title, the legend, the demo in cave A (scrolling),
                         U, X, Z and a bonus cave, then the ending

The gameplay is the attract demo: the program replaying a cave's recorded
winning run, exactly as the bot played it.  To pick the cave, the script
pokes the demo's cave list and jumps into the attract loop at the demo.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S       # noqa: E402
from mzsim import PAL         # noqa: E402

OUT = os.path.join(ROOT, 'showcase')
os.makedirs(OUT, exist_ok=True)
STEP = 4                      # fields per GIF frame (12.5 frames a second)
SCALE = 2


def find_demo_entry():
    """the attract loop's `ld a,1 / ld (demo),a` (where the demo starts)"""
    code = open(os.path.join(ROOT, 'build', 'undermined.bin'), 'rb').read()
    pat = bytes([0x3E, 0x01, 0x32, S['demo'] & 0xFF, S['demo'] >> 8])
    k = code.index(pat, S['attract'] - 0x1200)
    return 0x1200 + k


DEMO_AT = find_demo_entry()


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
    img.save(os.path.join(OUT, name + '.png'))
    print('wrote showcase/%s.png' % name)


def demo_of(cave):
    """a fresh machine, sent straight into the attract demo in cave index `cave`;
    returns once the cave card is up"""
    g = Game()
    g.run(30)
    g.m.mem[S['demo_caves']] = cave
    g.wb('demo_cave', S['DEMO_N'] - 1)   # the demo steps to entry 0 of its list
    c = g.m.cpu
    c.sp = S['STACKTOP']
    c.pc = DEMO_AT
    g.run(5)
    assert g.rb('demo') == 1 and g.rb('cave_no') == cave
    return g


def until_play(g, frames=None):
    """run through the cave card and the reveal to the first move"""
    while g.rb('inbox_time'):
        g.run(STEP)
        if frames is not None:
            frames.append(frame(g))
    g.run(STEP)


IDX = {}


def index_of(letter):
    if not IDX:
        import caves
        IDX.update({c.letter: i for i, c in enumerate(caves.caves())})
    return IDX[letter]


def page_of(label, fields):
    """a fresh machine sent straight to a front-end page (it returns to the
    attract loop afterwards); runs `fields` into it"""
    g = Game()
    g.run(30)
    c = g.m.cpu
    c.sp = S['STACKTOP'] - 2
    g.m.mem[c.sp] = S['attract'] & 0xFF
    g.m.mem[c.sp + 1] = S['attract'] >> 8
    c.pc = S[label]
    g.run(fields)
    return g


def stills():
    g = Game()
    g.run(320)
    save(frame(g), 'attract_title')
    for label, fields, name in (('story_page', 700, 'attract_story'), ('wings_page', 200, 'attract_wings'),
                                ('guide_page', 300, 'attract_guide'), ('guide2_page', 300, 'attract_guide2'),
                                ('hiscore_page', 150, 'attract_scores'), ('ending', 900, 'ending')):
        save(frame(page_of(label, fields)), name)
    g = demo_of(index_of('X'))
    g.run(60)
    save(frame(g), 'attract_card')

    # gameplay: (cave, ticks into the solution, name)
    for letter, ticks, name in (('A', 150, 'play_a_first_light'), ('C', 70, 'play_c_the_mountain'),
                                ('G', 200, 'play_g_the_moth'), ('K', 150, 'play_k_hourglass'),
                                ('O', 120, 'play_o_the_tree'), ('T', 260, 'play_t_the_core'),
                                ('U', 120, 'play_u_geodes'), ('V', 300, 'play_v_seeping_halls'),
                                ('W', 200, 'play_w_crystal_vault'), ('X', 150, 'play_x_shades'),
                                ('Y', 200, 'play_y_catacombs'), ('Z', 200, 'play_z_heart'),
                                ('1', 50, 'bonus_1_crystal_rain'), ('3', 250, 'bonus_3_alchemists_vat')):
        g = demo_of(index_of(letter))
        until_play(g)
        run_ticks(g, ticks)
        save(frame(g), name)


def run_ticks(g, n):
    """n game ticks, counted at tick_hook"""
    hook = S['tick_hook']
    c = g.m.cpu
    step = c.step
    for _ in range(n):
        if c.pc == hook:
            step()
        while c.pc != hook:
            step()
        if g.rb('pl_exit') or g.rb('pl_dead'):
            break


def screen_text(g):
    return ''.join(frame_text(g, r) for r in range(25))


def until_text(g, word, max_fields=50 * 60):
    """run until `word` is on screen (spaced-out headings count too)"""
    n = 0
    while word not in screen_text(g).replace(' ', ''):
        g.run(25)
        n += 25
        assert n < max_fields, word + ' never appeared'


def frame_text(g, r):
    """a screen row as rough ASCII (MZ display codes for A-Z are 01h-1Ah)"""
    out = []
    for c in range(40):
        ch = g.m.mem[0xD000 + r * 40 + c]
        out.append(chr(64 + ch) if 1 <= ch <= 26 else ' ')
    return ''.join(out)


def gif():
    frames = []
    g = Game()
    g.run(20)
    for _ in range(int(10 * 50 / STEP)):          # the title: out, and back for the gems
        g.run(STEP)
        frames.append(frame(g))
    cuts = [len(frames)]
    g = page_of('story_page', 0)                   # the legend: down the mine
    for _ in range(int(8 * 50 / STEP)):
        g.run(STEP)
        frames.append(frame(g))
    cuts.append(len(frames))
    for letter, secs, skip in (('A', 18, 0), ('U', 7, 100), ('X', 7, 140), ('Z', 8, 160), ('1', 6, 30)):
        cave = index_of(letter)
        g = demo_of(cave)
        g.run(25)                                  # the card is drawn
        for _ in range(int(2.5 * 50 / STEP)):      # hold the card
            g.run(STEP)
            frames.append(frame(g))
        while not g.rb('inbox_time'):              # skip the rest of the card
            g.run(STEP)
        if skip:
            until_play(g)
            run_ticks(g, skip)                     # straight into the action
        else:
            while g.rb('inbox_time'):              # cave A: the reveal
                g.run(STEP)
                frames.append(frame(g))
        for _ in range(int(secs * 50 / STEP)):
            g.run(STEP)
            frames.append(frame(g))
            if g.rb('pl_exit') or g.rb('pl_dead'):
                break
        cuts.append(len(frames))
    g = page_of('ending', 0)                       # daybreak
    for _ in range(int(7 * 50 / STEP)):
        g.run(STEP)
        frames.append(frame(g))
    cuts.append(len(frames))
    pal_img = Image.new('P', (1, 1))
    flat = []
    for c in PAL:
        flat += list(c)
    pal_img.putpalette(flat + [0] * (768 - len(flat)))
    gf = [f.quantize(palette=pal_img, dither=Image.Dither.NONE) for f in frames]
    dur = [STEP * 20] * len(gf)
    for c in cuts:
        dur[c - 1] = 700          # a beat at each cut
    path = os.path.join(OUT, 'undermined.gif')
    gf[0].save(path, save_all=True, append_images=gf[1:], duration=dur, loop=0,
               optimize=True, disposal=1)
    print('wrote showcase/undermined.gif (%d frames, %.0f s, %.0f KB)' % (
        len(gf), sum(dur) / 1000, os.path.getsize(path) / 1024))


if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'both'
    if what in ('stills', 'both'):
        stills()
    if what in ('gif', 'both'):
        gif()
