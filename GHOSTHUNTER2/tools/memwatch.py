import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S
g = Game()
ref = bytes(g.m.mem[0x1200:g.end])
selfmod = {S['pollcmp']+1, S['vblev']+1}
for k,v in S.items():
    if k.endswith('.hi'):
        selfmod.add(v+1)
step = int(sys.argv[2]) if len(sys.argv) > 2 else 50
for f in range(0, int(sys.argv[1]), step):
    g.run(step)
    cur = g.m.mem[0x1200:g.end]
    diff = [0x1200+i for i in range(len(ref)) if cur[i] != ref[i] and 0x1200+i not in selfmod]
    if diff:
        print('field', f+step, 'demo', g.rb('demo'), 'diffs', len(diff), ' '.join('%04X' % a for a in diff[:12]))
        inv = sorted(S.items(), key=lambda kv: kv[1])
        for a in diff[:3]:
            lab = max((kv for kv in inv if kv[1] <= a), key=lambda kv: kv[1])
            print('  %04X in %s+%d' % (a, lab[0], a - lab[1]))
        break
