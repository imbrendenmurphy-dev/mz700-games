"""engine.py - Python reference model of the SKINK rules.

It mirrors the Z80 engine (src/physics.asm, src/player.asm) step for step,
so the same input sequence gives the same world in both.  It is used to
design and check the regions, to plan and verify the full solution, and to
cross-check the Z80 code in the simulator (tools/crosscheck.py).

Region: W x H cells (32 x 24), one byte each: bits 0-5 element, bit 7 =
"moved this tick".  The scan runs rows 1..H-2, left to right; anything
that moves right or down is written with bit 7 set and the scan clears the
bit instead of handling that cell, so nothing moves twice per tick.
"""
from tiles import E, ELEMS

W, H = 32, 24
RSZ = W * H
DIROFF = (-1, -W, 1, W)          # 0 left, 1 up, 2 right, 3 down
FLAG = 0x80
M = 0x3F

SPACE, EARTH, SECRET = E['SPACE'], E['EARTH'], E['SECRET']
ROCK, ROCKF, EGG, EGGF = E['ROCK'], E['ROCKF'], E['EGG'], E['EGGF']
GEM, PIECE, CROWN, KEY = E['GEM'], E['PIECE'], E['CROWN'], E['KEY']
CAGE, SAFE, SKULL, BARRIER = E['CAGE'], E['SAFE'], E['SKULL'], E['BARRIER']
SWITCH, SWITCHON, GATE, TRANS = E['SWITCH'], E['SWITCHON'], E['GATE'], E['TRANS']
PLAYER, MONSTER, FUNGUS = E['PLAYER'], E['MONSTER'], E['FUNGUS']
HATCH1, HATCH2, HATCH3 = E['HATCH1'], E['HATCH2'], E['HATCH3']
SPIRIT0 = E['SPIRIT0']
CURVL, CURVR = E['CURVL'], E['CURVR']

MONSTERISH = (EGG, EGGF, HATCH1, HATCH2, HATCH3, MONSTER)
GEMISH = (GEM, CAGE, SAFE)
DEADLY = (MONSTER, SKULL, FUNGUS, SPIRIT0, SPIRIT0 + 1, SPIRIT0 + 2, SPIRIT0 + 3)
FUNGUS_MASK = 15                  # fungus grows when (tick & mask) == 0


def round_dirs(e):
    """which ways an object resting on element e may roll: bit 0 left, bit 1 right"""
    if e in (ROCK, EGG, GEM):
        return 3
    if e == CURVL:
        return 1
    if e == CURVR:
        return 2
    return 0


class Dead(Exception):
    pass


class Game:
    def __init__(self, world):
        """world: tools/world.World (maps, transporters, switches, meta)"""
        self.wd = world
        self.N = len(world.regions)
        self.mem = bytearray(self.N * RSZ)
        for r in range(self.N):
            self.unpack(r)
        self.flags = 0                  # switches thrown (bit per switch)
        self.tick = 0
        self.region = world.start_region
        self.pos = world.start_pos
        self.entry = self.pos
        self.face = 3
        self.dead = False
        self.won = False
        self.events = []
        self.visited = {self.region}
        self.deaths = 0
        self.score = 0
        self.snap = None
        self.enter_region(self.region, self.pos)

    # ------------------------------------------------------------ world state
    def base(self, r=None):
        return (self.region if r is None else r) * RSZ

    def cell(self, p, r=None):
        return self.mem[self.base(r) + p]

    def unpack(self, r):
        b = self.base(r)
        self.mem[b:b + RSZ] = bytes(self.wd.regions[r].cells)

    def fixup(self, r):
        """apply the thrown switches to region r (after unpack / restore)"""
        b = self.base(r)
        for i, sw in enumerate(self.wd.switches):
            if not (self.flags >> i) & 1:
                continue
            if sw.region == r:
                self.mem[b + sw.pos] = SWITCHON
            if sw.target == r:
                self.clear_rect(sw)

    def clear_rect(self, sw):
        b = self.base(sw.target)
        for y in range(sw.y1, sw.y2 + 1):
            for x in range(sw.x1, sw.x2 + 1):
                if self.mem[b + y * W + x] & M == BARRIER:
                    self.mem[b + y * W + x] = SPACE

    def counts(self):
        g = p = cr = mo = 0
        for v in self.mem:
            v &= M
            if v in GEMISH:
                g += 1
            elif v == PIECE:
                p += 1
            elif v == CROWN:
                cr += 1
            elif v in MONSTERISH:
                mo += 1
        return g, p, cr, mo

    def done(self):
        g, p, _, mo = self.counts()
        return g == 0 and p == 0 and mo == 0

    def enter_region(self, r, pos):
        self.region = r
        self.pos = pos
        self.entry = pos
        self.visited.add(r)
        self.mem[self.base() + pos] = PLAYER
        b = self.base()
        self.snap = bytes(self.mem[b:b + RSZ])

    def restore(self):
        """death: back to the snapshot taken on entry"""
        b = self.base()
        self.mem[b:b + RSZ] = self.snap
        self.fixup(self.region)
        self.pos = self.entry
        self.dead = False
        self.face = 3

    def reset_region(self):
        """R key: the region as it was at the start of the game"""
        self.unpack(self.region)
        self.fixup(self.region)
        b = self.base()
        self.mem[b + self.entry] = PLAYER
        self.pos = self.entry
        self.snap = bytes(self.mem[b:b + RSZ])

    # ------------------------------------------------------------ one tick
    def step(self, d):
        """d: 0 none, 1 left, 2 up, 3 right, 4 down.  Returns the events list."""
        self.events = []
        self.tick = (self.tick + 1) & 0xFFFF
        self.input = d
        self.trans = None
        self.switch_hit = None
        self.gate_hit = False
        b = self.base()
        m = self.mem
        for p in range(W, RSZ - W):
            v = m[b + p]
            if v == 0:
                continue
            if v & FLAG:
                m[b + p] = v & M
                continue
            if v < ROCK and v != PLAYER:
                continue
            self.handle(p, v)
        # after the scan
        if self.dead:
            self.events.append('dead')
            return self.events
        if self.trans is not None:
            self.do_transport(self.trans)
        if self.switch_hit is not None:
            self.do_switch(self.switch_hit)
        if self.gate_hit:
            if self.done():
                self.won = True
                self.events.append('win')
            else:
                self.events.append('gate_shut')
        return self.events

    def kill(self):
        if not self.dead:
            self.dead = True

    def handle(self, p, v):
        if v == PLAYER:
            return self.h_player(p)
        if v in (ROCK, EGG):
            return self.h_rest(p, v)
        if v in (ROCKF, EGGF):
            return self.h_fall(p, v)
        if v in (HATCH1, HATCH2, HATCH3):
            if self.tick & 3 == 0:
                self.mem[self.base() + p] = v + 1      # HATCH3 + 1 = MONSTER
                if v == HATCH3:
                    self.events.append('hatch')
            return
        if v == MONSTER:
            return self.h_monster(p)
        if SPIRIT0 <= v <= SPIRIT0 + 3:
            return self.h_spirit(p, v - SPIRIT0)
        if v == FUNGUS:
            return self.h_fungus(p)

    # rocks and eggs ------------------------------------------------------
    def h_rest(self, p, v):
        m, b = self.mem, self.base()
        below = m[b + p + W]
        if below == 0:
            m[b + p] = 0
            m[b + p + W] = (v + 1) | FLAG
            return
        self.try_roll(p, v + 1, round_dirs(below & M))

    def try_roll(self, p, f, dirs):
        """roll object f (falling code) at p; True if it moved"""
        m, b = self.mem, self.base()
        if dirs & 1 and m[b + p - 1] == 0 and m[b + p - 1 + W] == 0:
            m[b + p - 1] = f
            m[b + p] = 0
            return True
        if dirs & 2 and m[b + p + 1] == 0 and m[b + p + 1 + W] == 0:
            m[b + p + 1] = f | FLAG
            m[b + p] = 0
            return True
        return False

    def h_fall(self, p, f):
        m, b = self.mem, self.base()
        below = m[b + p + W]
        if below == 0:
            m[b + p] = 0
            m[b + p + W] = f | FLAG
            return
        be = below & M
        if be == PLAYER:
            self.kill()
            return
        if be == MONSTER:
            m[b + p + W] = 0
            self.score += 100
            self.events.append('crush')
            return
        if be in (ROCKF, EGGF):
            return
        if self.try_roll(p, f, round_dirs(be)):
            return
        m[b + p] = HATCH1 if f == EGGF else f - 1
        self.events.append('land')

    # creatures -------------------------------------------------------------
    def near(self, p, e):
        m, b = self.mem, self.base()
        for d in DIROFF:
            if m[b + p + d] & M == e:
                return p + d
        return None

    def h_monster(self, p):
        if self.near(p, PLAYER) is not None:
            self.kill()
            return
        if self.tick & 1:
            return
        m, b = self.mem, self.base()
        mx, my = p % W, p // W
        px, py = self.pos % W, self.pos // W
        dx, dy = px - mx, py - my
        hor = (2 if dx > 0 else 0) if dx else None
        ver = (3 if dy > 0 else 1) if dy else None
        order = (hor, ver) if abs(dx) >= abs(dy) else (ver, hor)
        for d in order:
            if d is None:
                continue
            t = p + DIROFF[d]
            if m[b + t] == 0:
                m[b + t] = MONSTER | (FLAG if d >= 2 else 0)
                m[b + p] = 0
                return

    def h_spirit(self, p, d):
        m, b = self.mem, self.base()
        if self.near(p, PLAYER) is not None:
            self.kill()
            return
        cg = self.near(p, CAGE)
        if cg is not None:
            m[b + cg] = GEM
            m[b + p] = 0
            self.events.append('caged')
            self.score += 50
            return
        for nd in ((d - 1) & 3, d):
            t = p + DIROFF[nd]
            if m[b + t] == 0:
                m[b + t] = (SPIRIT0 + nd) | (FLAG if nd >= 2 else 0)
                m[b + p] = 0
                return
        m[b + p] = SPIRIT0 + ((d + 1) & 3)

    def h_fungus(self, p):
        if self.tick & FUNGUS_MASK:
            return
        m, b = self.mem, self.base()
        d = (self.tick >> 4) & 3
        t = p + DIROFF[d]
        v = m[b + t]
        if v == 0:
            m[b + t] = FUNGUS | (FLAG if d >= 2 else 0)
        elif v & M == PLAYER:
            self.kill()

    # the player ------------------------------------------------------------
    def h_player(self, p):
        self.pos = p
        d = self.input
        if not d:
            return
        d -= 1
        self.face = d
        m, b = self.mem, self.base()
        off = DIROFF[d]
        t = p + off
        te = m[b + t] & M
        if te in (SPACE, EARTH, SECRET):
            if te:
                self.events.append('dig')
            return self.move(p, t, d)
        if te == GEM:
            self.score += 10
            self.events.append('gem')
            return self.move(p, t, d)
        if te == PIECE:
            self.score += 250
            self.events.append('piece')
            return self.move(p, t, d)
        if te == CROWN:
            self.score += 500
            self.events.append('crown')
            return self.move(p, t, d)
        if te == KEY:
            for q in range(RSZ):
                if m[b + q] & M == SAFE:
                    m[b + q] = GEM
            self.events.append('key')
            return self.move(p, t, d)
        if te in (ROCK, EGG) and d in (0, 2):
            beyond = t + off
            if m[b + beyond] == 0:
                m[b + beyond] = te | (FLAG if d == 2 else 0)
                self.events.append('push')
                return self.move(p, t, d)
            return
        if te == TRANS:
            self.trans = t
            return
        if te == SWITCH:
            self.switch_hit = t
            return
        if te == GATE:
            self.gate_hit = True
            return
        if te in DEADLY:
            self.kill()
            return

    def move(self, p, t, d):
        m, b = self.mem, self.base()
        m[b + p] = 0
        m[b + t] = PLAYER | (FLAG if d >= 2 else 0)
        self.pos = t

    # transporters and switches ---------------------------------------------
    def do_transport(self, t):
        tr = self.wd.trans_at(self.region, t)
        b2 = self.base(tr.dregion)
        v = self.mem[b2 + tr.dpos] & M
        if v not in (SPACE, EARTH):
            self.events.append('blocked')
            return
        self.mem[self.base() + self.pos] = SPACE
        self.events.append('transport')
        self.enter_region(tr.dregion, tr.dpos)

    def do_switch(self, t):
        i, sw = self.wd.switch_at(self.region, t)
        self.flags |= 1 << i
        self.mem[self.base() + t] = SWITCHON
        self.clear_rect(sw)
        self.events.append('switch')

    # helpers -------------------------------------------------------------
    def grid(self, r=None):
        b = self.base(r)
        return [[self.mem[b + y * W + x] & M for x in range(W)] for y in range(H)]

    def show(self, r=None, legend=None):
        from world import CHAR
        g = self.grid(r)
        return '\n'.join(''.join(CHAR.get(ELEMS[v], '?') for v in row) for row in g)
