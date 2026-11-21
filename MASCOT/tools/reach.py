"""reach.py - can every level be finished, and every gem reached?

    py tools/reach.py [level-code ...]

A Python copy of Kiko's movement (src/hero.asm: walk, jump, gravity,
one-way planks, springs, chroma blocks, room edges) explores each level
from the start.  From every resting spot it tries walks and jumps (three
directions, several run-ups and button holds, letting go of the direction
part-way, changing colour at take-off or at the top of the jump) and
records every cell Kiko's body passes through.  Vines are climbed to both
ends.  Enemies are ignored; moving platforms count as planks over their
whole path and lifts as a ladder of planks (both optimistic).

Reports per level: goal reached?, gems and stars not reachable.
"""
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tiles as TL  # noqa: E402
import levels as LV  # noqa: E402
import rooms as RM  # noqa: E402

ACC_G, ACC_A, FRIC_G, FRIC_A, SKID, MAXV = 5, 4, 6, 2, 12, 60
G_LO, G_HI, VMAXY, JUMPV, SPRINGV, VINEJV = 6, 15, 160, -128, -176, -96
W, H = 40, 23
CB = {'R': 0, 'G': 1, 'B': 2}


def s8(v):
    return v


class RoomModel:
    def __init__(self, room, world):
        self.room = room
        self.flags = [[TL.TILES[t].flags for t in row] for row in room.T]
        cb = TL.CHROMA_BASE[world]
        self.chroma = [[None] * W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                d = room.T[y][x] - cb
                if 0 <= d < 6:
                    self.chroma[y][x] = d // 2
        # moving platforms as planks along their path (optimistic)
        self.extra = set()
        for (t, x, y, p1, p2) in room.recs:
            if t == RM.OT['PLATH']:
                for xx in range(p1, p2 + 4):
                    self.extra.add((xx, y))
            elif t == RM.OT['PLATV']:
                for yy in range(p1, p2 + 1):
                    for xx in range(x, x + 4):
                        self.extra.add((xx, yy))
        self.goal = [(x, y) for (t, x, y, p1, p2) in room.recs if t == RM.OT['GOAL']]
        self.boss = any(t == RM.OT['BOSS'] for (t, x, y, p1, p2) in room.recs)

    def f(self, x, y, col):
        if not (0 <= y < H):
            return 0
        if not (0 <= x < W):
            return TL.F_SOLID
        c = self.chroma[y][x]
        if c is not None:
            return TL.F_SOLID if c == col else 0
        fl = self.flags[y][x]
        if (x, y) in self.extra:
            fl |= TL.F_ONEWAY
        return fl


class Sim:
    """one hero; mirrors hero.asm closely enough for reachability"""
    def __init__(self, lvl, room, x, y, col):
        self.lvl, self.room = lvl, room
        self.x, self.xf, self.y, self.yf = x, 0x80, y, 0xC0
        self.vx, self.vy = 0, 0
        self.gnd, self.coy, self.jbuf, self.drop = True, 0, 0, 0
        self.col = col
        self.prevk = 0
        self.dead = False
        self.touched = set()
        self.exits = 0

    def m(self):
        return self.lvl.models[self.room]

    def fl(self, x, y):
        return self.m().f(x, y, self.col)

    def col_flags(self, x, ybot, n=3):
        v = 0
        for i in range(n):
            v |= self.fl(x, ybot - i)
        return v

    def row_flags(self, x, y, n=2):
        v = 0
        for i in range(n):
            v |= self.fl(x + i, y)
        return v

    def change_room(self, d):
        r = self.lvl.rooms[self.room]
        n = r.exits[d]
        if n == 0xFF:
            return False
        self.room = self.lvl.index_of[n]
        if d == 0:
            self.x = W - 2
        elif d == 1:
            self.x = 0
        elif d == 2:
            self.y = H - 1
        else:
            self.y = 2
        self.exits += 1
        return True

    def supported(self):
        if self.y + 1 >= H:
            return False
        e = self.row_flags(self.x, self.y + 1)
        if e & TL.F_SOLID:
            return True
        if not self.drop and e & TL.F_ONEWAY:
            return True
        return False

    def step(self, keys):
        press = keys & ~self.prevk
        self.prevk = keys
        for a in ('coy', 'drop'):
            if getattr(self, a):
                setattr(self, a, getattr(self, a) - 1)
        if press & 16:
            self.jbuf = 7
        elif self.jbuf:
            self.jbuf -= 1
        # walk
        lr = keys & 12
        if lr == 8 or lr == 4:
            d = 1 if lr == 8 else -1
            acc = ACC_A
            if self.gnd:
                acc = ACC_G
                if self.vx * d < 0:
                    acc = SKID
            self.vx += d * acc
            self.vx = max(-MAXV, min(MAXV, self.vx))
        else:
            fr = FRIC_G if self.gnd else FRIC_A
            if self.vx > 0:
                self.vx = max(0, self.vx - fr)
            elif self.vx < 0:
                self.vx = min(0, self.vx + fr)
        # move x
        if self.vx:
            p = self.x * 256 + self.xf + self.vx
            nx, nf = p >> 8, p & 255
            if nx != self.x:
                if self.vx > 0:
                    if self.x + 2 >= W:
                        if self.change_room(1):
                            self.xf = nf
                            return 'room'
                        blocked = True
                    else:
                        blocked = self.col_flags(self.x + 2, self.y) & TL.F_SOLID
                    if blocked:
                        self.xf, self.vx = 0xF0, 0
                    else:
                        self.x += 1
                        self.xf = nf
                else:
                    if self.x == 0:
                        if self.change_room(0):
                            self.xf = nf
                            return 'room'
                        blocked = True
                    else:
                        blocked = self.col_flags(self.x - 1, self.y) & TL.F_SOLID
                    if blocked:
                        self.xf, self.vx = 0x10, 0
                    else:
                        self.x -= 1
                        self.xf = nf
            else:
                self.xf = nf
        # jump (DOWN + JUMP on a plank: drop through instead)
        if self.jbuf and self.gnd and keys & 2:
            e = self.row_flags(self.x, self.y + 1)
            if not (e & TL.F_SOLID) and e & TL.F_ONEWAY:
                self.drop, self.jbuf = 10, 0
        if self.jbuf and (self.gnd or self.coy):
            self.vy, self.gnd, self.coy, self.jbuf = JUMPV, False, 0, 0
        # gravity
        if not self.gnd:
            self.vy += G_LO if (self.vy < 0 and keys & 16) else G_HI
            self.vy = min(self.vy, VMAXY)
        # move y
        if self.gnd:
            if not self.supported():
                self.gnd = False
                if self.vy >= 0:
                    self.coy = 8
        else:
            p = self.y * 256 + self.yf + self.vy
            ny, nf = p >> 8, p & 255
            if ny == self.y:
                self.yf = nf
            elif self.vy >= 0:
                if self.y + 1 >= H:
                    if self.change_room(3):
                        self.yf = nf
                        return 'room'
                    self.y += 1
                    if self.y >= H + 2:
                        self.dead = True
                        return 'dead'
                else:
                    e = self.row_flags(self.x, self.y + 1)
                    if e & TL.F_SOLID or (not self.drop and e & TL.F_ONEWAY):
                        self.yf, self.gnd = 0xC0, True
                        self.vy = SPRINGV if e & TL.F_SPRING else 0
                        if e & TL.F_SPRING:
                            self.gnd = False
                    else:
                        self.y += 1
                        self.yf = nf
            else:
                if self.y - 3 < 0:
                    if self.change_room(2):
                        self.yf = nf
                        return 'room'
                    self.vy, self.yf = 0, 0
                elif self.row_flags(self.x, self.y - 3) & TL.F_SOLID:
                    self.vy, self.yf = 0, 0
                else:
                    self.y -= 1
                    self.yf = nf
        # touch
        for dx in (0, 1):
            for dy in (0, 1, 2):
                cx, cy = self.x + dx, self.y - dy
                if 0 <= cx < W and 0 <= cy < H:
                    self.touched.add((self.room, cx, cy))
                    f = self.fl(cx, cy)
                    if f & TL.F_HURT and f & TL.F_CRUMBLE:
                        self.dead = True
                        return 'dead'
        return None

    def on_vine(self):
        v = 0
        for dx in (0, 1):
            v |= self.col_flags(self.x + dx, self.y) & TL.F_VINE
        return v


class LevelModel:
    def __init__(self, lv):
        self.lv = lv
        self.rooms = lv.rooms
        self.index_of = {r.index: i for i, r in enumerate(lv.rooms)}
        self.models = [RoomModel(r, lv.world) for r in lv.rooms]
        own = {'W1': [1], 'W2': [0, 1], 'W3': [0, 1, 2], 'W4': [0, 1, 2]}[lv.world]
        self.colours = own


def macros(colours):
    out = []
    for d in (0, 4, 8):
        for run in (0, 6, 14):
            if d == 0 and run:
                continue
            for hold in (0, 3, 7, 12, 30):
                for release in (None, 10, 20):
                    if d == 0 and release:
                        continue
                    for sw in ([None] + [(t, c) for t in (0, 14) for c in colours]):
                        out.append((d, run, hold, release, sw))
    return out


def run_macro(lm, st, mac):
    room, x, y, col = st
    d, run, hold, release, sw = mac
    s = Sim(lm, room, x, y, col)
    s.gnd = s.supported()
    keys_dir = d
    if not s.gnd and s.on_vine():
        # leaving a vine: a jump off it, or the hop at its top
        s.vy = VINEJV if hold else -110
        run = 0
    frames = 0
    # run-up
    for i in range(run):
        r = s.step(keys_dir)
        frames += 1
        if r == 'dead':
            return s, None
    # jump (or walk off) and fly until landing
    t = 0
    jumping = hold > 0
    while frames < 160:
        k = keys_dir
        if release is not None and t >= release:
            k = 0
        if jumping and t < hold:
            k |= 16
        if sw and t == sw[0]:
            s.col = sw[1]
        r = s.step(k)
        frames += 1
        t += 1
        if r == 'dead':
            return s, None
        if s.gnd and t > 2 and (hold == 0 or t > hold):
            # settle
            for i in range(30):
                if s.vx == 0:
                    break
                s.step(0)
            if not s.gnd:
                continue
            return s, (s.room, s.x, s.y, s.col)
        if not jumping and t > 30 and s.gnd:
            return s, (s.room, s.x, s.y, s.col)
    return s, None


def climb_states(lm, st):
    """vine: every row reachable up/down the vine, hopping off at the ends"""
    room, x, y, col = st
    out = []
    s = Sim(lm, room, x, y, col)
    if not s.on_vine() and not (s.row_flags(x, y + 1) & TL.F_VINE):
        return out, set()
    touched = set()
    for direction in (-1, 1):
        s = Sim(lm, room, x, y, col)
        for _ in range(60):
            ny = s.y + direction
            if direction < 0:
                if s.y - 3 < 0:
                    if not s.change_room(2):
                        break
                    continue
                if s.row_flags(s.x, s.y - 3) & TL.F_SOLID:
                    break
            else:
                if s.y + 1 >= H:
                    if not s.change_room(3):
                        break
                    continue
                if s.row_flags(s.x, s.y + 1) & TL.F_SOLID:
                    break
            s.y = ny
            for dx in (0, 1):
                for dy in (0, 1, 2):
                    touched.add((s.room, s.x + dx, s.y - dy))
            if not s.on_vine():
                break
            # at every vine position: jump off left/right/up, or shuffle sideways
            out.append((s.room, s.x, s.y, s.col))
            for dx in (-1, 1):
                nx = s.x + dx
                if 0 <= nx <= W - 2 and not (s.col_flags(nx + (1 if dx > 0 else 0), s.y) & TL.F_SOLID):
                    t = Sim(lm, s.room, nx, s.y, s.col)
                    if t.on_vine():
                        out.append((s.room, nx, s.y, s.col))
    return out, touched


def explore(lv):
    lm = LevelModel(lv)
    start_room = lm.index_of[lv.first.index]
    sx, sy = lv.first.start
    start = (start_room, sx, sy, 1)
    seen = {start}
    q = deque([start])
    touched = set()
    vine_states = set()
    mac = macros(lm.colours)
    while q:
        st = q.popleft()
        room, x, y, col = st
        # climbing
        vs, vt = climb_states(lm, st)
        touched |= vt
        for v in vs:
            vine_states.add(v)
        cand = [st] + vs
        has_chroma = any(c is not None for row in lm.models[room].chroma for c in row)
        for base in cand:
            for d in (4, 8):
                s = Sim(lm, base[0], base[1], base[2], base[3])
                s.gnd = s.supported()
                x0, r0 = s.x, s.room
                for i in range(40):
                    s.step(d)
                    if s.x != x0 or s.room != r0 or s.dead or not s.gnd:
                        break
                for i in range(40):
                    if s.dead or (s.gnd and s.vx == 0):
                        break
                    s.step(0)
                touched |= s.touched
                if not s.dead and s.gnd:
                    e = (s.room, s.x, s.y, s.col)
                    if e not in seen:
                        seen.add(e)
                        q.append(e)
            for mc in mac:
                if mc[4] is not None and not has_chroma:
                    continue
                s, end = run_macro(lm, base, mc)
                touched |= s.touched
                if end and end not in seen:
                    seen.add(end)
                    q.append(end)
                    # changing colour while standing is also a move
                for c in lm.colours:
                    if end:
                        e2 = (end[0], end[1], end[2], c)
                        if e2 not in seen:
                            sim = Sim(lm, e2[0], e2[1], e2[2], c)
                            if sim.supported():
                                seen.add(e2)
                                q.append(e2)
    return lm, seen, touched


def report(lv):
    lm, seen, touched = explore(lv)
    goal_ok = False
    boss_level = any(m.boss for m in lm.models)
    missing = []
    for ri, (r, m) in enumerate(zip(lm.rooms, lm.models)):
        for (gx, gy) in m.goal:
            for dx in range(3):
                for dy in range(3):
                    if (ri, gx + dx, gy - dy) in touched:
                        goal_ok = True
        for (x, y) in r.gems():
            if (ri, x, y) not in touched:
                missing.append((r.key, x, y, TL.TILES[r.T[y][x]].name))
    if boss_level:
        goal_ok = any((ri, 19 + dx, 17 - dy) in touched for ri, m in enumerate(lm.models) if m.boss
                      for dx in range(3) for dy in range(3))
    rooms_seen = sorted({lm.rooms[s[0]].key for s in seen})
    print('%-5s %-18s goal %-3s rooms %s  states %d  unreachable pickups %d' % (
        lv.code, lv.name, 'OK' if goal_ok else 'NO', ''.join(rooms_seen), len(seen), len(missing)))
    for mi in missing:
        print('        room %s  x %2d y %2d  %s' % mi)
    return goal_ok, missing


def link_all():
    """number rooms and link neighbours, exactly as build.py does"""
    n = 0
    for lv in LV.LEVELS:
        for r in lv.rooms:
            r.index = n
            n += 1
        lv.link()


if __name__ == '__main__':
    link_all()
    want = sys.argv[1:]
    bad = 0
    for lv in LV.LEVELS:
        if want and lv.code not in want:
            continue
        ok, miss = report(lv)
        bad += (not ok) + len(miss)
    sys.exit(1 if bad else 0)
