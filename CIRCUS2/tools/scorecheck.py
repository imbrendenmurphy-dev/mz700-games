"""scorecheck.py first_act fields - pilot plays (lives topped up) from first_act; checks that the
score only ever grows by what add_pts was asked to add (x2 when DOUBLE is on)"""
import sys
sys.path.insert(0, 'tools')
from run import Game, S
first = int(sys.argv[1]); fields = int(sys.argv[2])
g = Game()
g.run(60)
g.m.held = {'space'}
g.m.run_until_pc(S['wait_release'], max_t=70886 * 50)
g.m.held = set()
g.m.run_until_pc(S['act_setup'], max_t=70886 * 200)
g.wb('act', first - 1)
g.wb('autoplay', 1)
g.wb('turbo', 1)
c = g.m.cpu
def score():
    return int('%02X%02X%02X' % (g.rb('score'), g.rb('score', 1), g.rb('score', 2)))
ap = S['add_pts']
expect = score()
pend = None
end = c.t + fields * 70886
n = 0
lastact = None
while c.t < end:
    if c.pc == ap:
        if pend is not None and score() != pend:
            print('MISMATCH before call: score', score(), 'expected', pend); break
        de = '%04X' % (c.d << 8 | c.e)
        add = int(de) * (2 if g.rb('pw_x2') else 1)
        pend = min(999999, score() + add)
    c.step()
    n += 1
    if n % 5000 == 0:
        if g.rb('lives') < 3:
            g.wb('lives', 5)
        if pend is not None and c.pc != ap and score() != pend and not (S['mul_bcd'] <= c.pc < S['pts_text']):
            print('MISMATCH: score', score(), 'expected', pend, 'act', g.rb('act') + 1, 'pc %04X' % c.pc); break
        a = g.rb('act')
        if a != lastact:
            print('act', a + 1, 'score', score(), 'field', g.m.field())
            lastact = a
print('end act', g.rb('act') + 1, 'score', score(), 'expected', pend)
