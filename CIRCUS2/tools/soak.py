"""soak.py [fields] - run the attract mode (title, demos, pages) and check for crashes,
stray writes outside RAM areas the game owns, and leftover object cells."""
import sys
sys.path.insert(0, 'tools')
from run import Game, S
fields = int(sys.argv[1]) if len(sys.argv) > 1 else 15000
g = Game()
m = g.m
c = m.cpu
orig = c.mem_write_hook
stray = []
lo_vars = S['vars_start']
def mw(a, v):
    if 0x1200 <= a < S['end_of_program'] and not stray:
        stray.append(('%04X' % c.pc, '%04X' % a))
    return orig(a, v)
c.mem_write_hook = mw
pd = S['present_done']
end = c.t + fields * 70886
demos = set()
checks = 0
while c.t < end:
    c.step()
    pc = c.pc
    if pc == pd:
        checks += 1
        if checks % 50 == 0:
            bad = [o for o in range(1000) if m.mem[0xB000 + o]]
            assert not bad, ('OCC left', m.field(), bad[:5])
    elif pc == S['act_setup'] and m.mem[S['demo']]:
        demos.add(m.mem[S['act']])
    elif not (0x1200 <= pc < S['end_of_program']):
        raise RuntimeError('PC escaped to %04X at field %d' % (pc, m.field()))
assert 0xCD00 < c.sp <= 0xCFF0, hex(c.sp)
print('%d fields ok, demo acts %s, writes into code: %s, %d invariant checks' % (
    fields, sorted(a + 1 for a in demos), stray or 'none', checks // 50))
