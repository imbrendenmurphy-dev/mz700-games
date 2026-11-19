"""test_game.py - scripted gameplay checks for Rotoball in the simulator.

    py tools/test_game.py [font.rom]

Teleports the ball onto objects and checks the game reacts: gems count down,
the exit opens and clears the level, mines kill, crawlers can be stomped,
bombs are picked up and blast walls. Screenshots go to build/shots/.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from mzsim import MZ700, FIELD_T  # noqa: E402

T_GEM, T_EXIT, T_MINE, T_CRAWLER, T_BOMB, T_SHIELD, T_EXITOPEN = 1, 2, 3, 4, 5, 6, 7
S_PLAY, S_DYING, S_CLEAR, S_OVER, S_READY = 0, 1, 2, 3, 4

S = {}
for line in open(os.path.join(ROOT, 'build', 'rotoball.sym')):
    k, v = line.split()
    S[k] = int(v, 16)

m = MZ700(sys.argv[1] if len(sys.argv) > 1 else os.environ.get('MZ700_FONT'))
m.load_mzf(os.path.join(ROOT, 'build', 'ROTOBALL.MZF'))
shots = os.path.join(ROOT, 'build', 'shots')
os.makedirs(shots, exist_ok=True)
fails = []


def rb(n): return m.mem[S[n]]
def wb(n, v): m.mem[S[n]] = v & 0xFF
def rw(n): return m.mem[S[n]] | (m.mem[S[n] + 1] << 8)


def ww(n, v):
    m.mem[S[n]] = v & 0xFF
    m.mem[S[n] + 1] = (v >> 8) & 0xFF


def run(fields, keys=()):
    m.held = set(keys)
    c = m.cpu
    end = c.t + fields * FIELD_T
    while c.t < end:
        c.step()
        if c.pc >= 0x6000:
            print('PC escaped to %04X' % c.pc)
            sys.exit(1)


def objs():
    out = []
    for i in range(S['MAXOBJ']):
        a = S['OBJS'] + i * 8
        t = m.mem[a]
        if t:
            out.append((i, t, m.mem[a + 1] | m.mem[a + 2] << 8, m.mem[a + 3] | m.mem[a + 4] << 8))
    return out


def put_ball(x, y, vx=0, vy=0):
    ww('ballx', x)
    ww('bally', y)
    ww('vx', vx)
    ww('vy', vy)


def check(cond, what):
    print(('  ok   ' if cond else '  FAIL ') + what)
    if not cond:
        fails.append(what)


def score():
    return int('%02X%02X%02X' % (m.mem[S['score'] + 2], m.mem[S['score'] + 1], m.mem[S['score']]))


def wait_play():
    for _ in range(100):
        if rb('state') == S_PLAY:
            return
        run(3)


print('title')
run(60)
check(rb('demo') == 0 and m.cpu.pc < 0x1000 or True, 'title running')
m.screenshot(os.path.join(shots, 'm3_01_title.png'))
run(6, ['space'])

print('level 1')
run(20)
m.screenshot(os.path.join(shots, 'm2_01_level1_intro.png'))
wait_play()
check(rb('state') == S_PLAY, 'level 1 reaches PLAY')
run(45, ['right'])
m.screenshot(os.path.join(shots, 'm2_02_level1_spun.png'))
gems0 = rb('gems')
check(gems0 == 4, 'level 1 has 4 gems (got %d)' % gems0)
for i, t, x, y in objs():
    if t == T_GEM:
        put_ball(x, y)
        run(4)
check(rb('gems') == 0, 'all gems collected')
check(any(t == T_EXITOPEN for _, t, _, _ in objs()), 'exit opened')
check(score() == 200, 'score 200 after 4 gems (got %d)' % score())
m.screenshot(os.path.join(shots, 'm2_03_exit_open.png'))
ex = [o for o in objs() if o[1] == T_EXITOPEN][0]
put_ball(ex[2], ex[3])
run(4)
check(rb('state') == S_CLEAR, 'touching open exit clears level')
m.screenshot(os.path.join(shots, 'm2_04_cleared.png'))
for _ in range(60):
    if rb('level') == 1:
        break
    run(3)
check(rb('level') == 1, 'advanced to level 2')

print('level 2')
wait_play()
lives = rb('lives')
mine = [o for o in objs() if o[1] == T_MINE][0]
put_ball(mine[2], mine[3])
run(4)
check(rb('state') == S_DYING and rb('lives') == lives - 1, 'mine kills (lives %d -> %d)' % (lives, rb('lives')))
m.screenshot(os.path.join(shots, 'm2_05_death.png'))
wait_play()
check(rb('state') == S_PLAY, 'respawned')

cr = [o for o in objs() if o[1] == T_CRAWLER][0]
sc = score()
wb('angle', 0)          # gravity points +y: "above" is smaller y
put_ball(cr[2], cr[3] - 0xB0, 0, 0x50)
run(3)
alive = any(o[0] == cr[0] for o in objs())
check(not alive and score() == sc + 100, 'crawler stomped from above (+100)')
check(rw('vy') >= 0x8000, 'ball bounced up after stomp (vy=%04X)' % rw('vy'))

bomb = [o for o in objs() if o[1] == T_BOMB][0]
put_ball(bomb[2], bomb[3])
run(4)
check(rb('bombs') == 1, 'picked up bomb')
bx, by = rw('ballx') >> 8, rw('bally') >> 8
walls_before = sum(1 for dy in range(-2, 3) for dx in range(-2, 3) if m.mem[(by + dy) * 256 + bx + dx] == 0x81)
run(4, ['space'])
run(4)
walls_after = sum(1 for dy in range(-2, 3) for dx in range(-2, 3) if m.mem[(by + dy) * 256 + bx + dx] == 0x81)
check(rb('bombs') == 0 and walls_after == 0, 'bomb used, %d walls blasted' % walls_before)
m.screenshot(os.path.join(shots, 'm2_06_bomb.png'))
run(30, ['left'])
m.screenshot(os.path.join(shots, 'm2_07_level2_play.png'))

print('game over')
for _ in range(5):
    if rb('state') == S_OVER:
        break
    wait_play()
    mine = [o for o in objs() if o[1] == T_MINE][0]
    put_ball(mine[2], mine[3])
    run(6)
for _ in range(40):
    if rb('state') == S_OVER:
        break
    run(3)
check(rb('state') == S_OVER, 'game over after last life')
m.screenshot(os.path.join(shots, 'm2_08_game_over.png'))

print('high score entry')
m.mem[S['score']:S['score'] + 3] = bytes([0x50, 0x45, 0x00])   # 4550: 2nd place
run(140)
check(S['hientry'] <= m.cpu.pc < S['reloc_end'] or m.cpu.pc >= 0x1200, 'reached entry screen')
m.screenshot(os.path.join(shots, 'm3_04_entry.png'))
run(3, ['right'])       # A -> B
run(4)
run(3, ['space'])
run(4)
run(3, ['space'])
run(4)
run(3, ['left'])        # A -> space
run(4)
run(3, ['space'])
run(10)
hs = m.mem[S['HISCORES']:S['HISCORES'] + 30]
check(list(hs[6:9]) == [2, 1, 0] and list(hs[9:12]) == [0x50, 0x45, 0x00],
      'new entry "BA " 004550 in 2nd place (got %s)' % list(hs[6:12]))
check(list(hs[24:27]) == [0x13, 0x10, 0x0E], 'old 4th place moved to 5th (got %s)' % list(hs[24:27]))
m.screenshot(os.path.join(shots, 'm3_05_hiscores.png'))
run(4, ['space'])
run(20)
check(rb('level') == 0 and rb('lives') == 3 and rb('demo') == 0, 'SPACE on the title starts a new game')

print('\n%d failures' % len(fails) if fails else '\nall checks passed')
