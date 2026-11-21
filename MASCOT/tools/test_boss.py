"""test_boss.py - check that every boss behaves and can be beaten.

    py tools/test_boss.py [1-4]

Starts the game at the boss level (start_level hook), walks Kiko into the
arena, then repeatedly places him just above the boss and lets him drop
(stomp) or puts him level with it and sticks the tongue out, in the right
colour, until the boss is gone and the prism appears.  Screenshots go to
build/shots/boss<N>_*.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run import Game, S  # noqa: E402

OSZ = 32
LEVEL_OF = {1: 2, 2: 5, 3: 8, 4: 11}
CIDX = {2: 0, 4: 1, 1: 2}


def objs(g):
    out = []
    for i in range(14):
        a = S['OBJS'] + i * OSZ
        t = g.m.mem[a]
        if t:
            out.append(dict(slot=i, t=t, x=g.m.mem[a + 1], y=g.m.mem[a + 3], st=g.m.mem[a + 8],
                            hp=g.m.mem[a + 11], col=g.m.mem[a + 12], fl=g.m.mem[a + 17],
                            w=g.m.mem[a + 13], h=g.m.mem[a + 14], flash=g.m.mem[a + 22]))
    return out


def boss(g):
    for o in objs(g):
        if o['t'] == 12:
            return o
    return None


def main(n):
    g = Game()
    g.run(60)
    g.wb('start_level', LEVEL_OF[n])
    g.run(10, ['space'])
    g.run(150)                       # level intro
    # walk right into the arena
    for i in range(400):
        g.run(1, ['right'])
        if g.rb('room') != g.rb('cp_room') or g.rb('kx') >= 37:
            pass
        if boss(g):
            break
    g.run(40, ['right'])
    print('arena: hero', g.hero(), 'boss', boss(g))
    g.shot('boss%d_0' % n)
    hits = 0
    for attempt in range(800):
        b = boss(g)
        if b is None:
            break
        if b['st'] == 99:
            g.run(10)
            continue
        g.wb('hinv', 200)            # keep Kiko alive for the test
        g.wb('hearts', 3)
        # take the boss's colour (worlds 3, 4)
        if n >= 3 and b['col'] in CIDX:
            g.wb('hcol', CIDX[b['col']])
        top = b['y'] - b['h'] + 1
        vulnerable = (n == 1 and b['st'] == 3) or (n == 2 and b['st'] == 2) or n >= 3
        if not vulnerable or b['flash']:
            g.run(5)
            continue
        hp0 = b['hp']
        if n == 3:
            # level with its face, tongue out
            g.wb('kx', max(0, b['x'] - 4))
            g.wb('ky', b['y'])
            g.wb('hdir', 0)
            g.wb('hstate', 0)
            g.run(1, ['x'])
            g.run(12)
        else:
            # drop onto its back
            g.wb('kx', b['x'] + 1)
            g.wb('ky', top - 2)
            g.wb('kyf', 0x80)
            g.wb('hgnd', 0)
            g.wb('hvy', 60)
            g.wb('hvy', 0, 1)
            g.wb('hstate', 0)
            g.wb('hinv', 0)          # a good stomp must not hurt Kiko
            g.run(12)
        b2 = boss(g)
        if b2 and b2['hp'] < hp0:
            hits += 1
            if n != 3:
                for f in range(25):  # the boss hops up after the hit
                    g.run(1)
                    if g.rb('hearts') < 3:
                        print('   hurt at +%d: kiko %s, objects %s' % (f, g.hero(), [
                            (o['t'], o['x'], o['y'], o['st'], o['flash']) for o in objs(g)]))
                        break
                if g.rb('hearts') < 3:
                    print('FAIL: Kiko lost a heart stomping the boss')
                    main.hurt = True
            print('hit %d: hp %d -> %d' % (hits, hp0, b2['hp']))
            g.shot('boss%d_hit%d' % (n, hits))
    g.run(100)
    goal = [o for o in objs(g) if o['t'] == 11]
    print('boss gone:', boss(g) is None, ' prism:', bool(goal), ' hits:', hits)
    g.shot('boss%d_end' % n)
    if goal:
        # walk onto it
        gx = goal[0]['x']
        g.wb('kx', gx)
        g.wb('ky', goal[0]['y'])
        g.run(30)
        print('level_done', g.rb('level_done'), 'state', g.rb('hstate'))
    main.game = g
    return boss(g) is None and bool(goal) and not getattr(main, 'hurt', False)


if __name__ == '__main__':
    which = [int(a) for a in sys.argv[1:]] or [1, 2, 3, 4]
    ok = all([main(n) for n in which])
    sys.exit(0 if ok else 1)
