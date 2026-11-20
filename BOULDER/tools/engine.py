"""engine.py - the ROCKFALL rules in Python, tick for tick the same as the Z80.

Mirrors src/cave.asm (scan and handlers), src/player.asm (the player's move,
scoring) and the clock in src/game.asm.  tools/crosscheck.py compares this
model with the real program in the simulator after every tick.

    g = Game(cave_index)        # level 1
    g.tick(keys)                # keys = K_ bits: 1 up 2 down 4 left 8 right 16 fire
"""
import caves as C

E = C.E
W = C.W
K_UP, K_DOWN, K_LEFT, K_RIGHT, K_FIRE = 1, 2, 4, 8, 16
OFF = (-1, -W, 1, W)                 # dir 0 left, 1 up, 2 right, 3 down
SPACE, DIRT, BRICK, MAGIC, STEEL = E['SPACE'], E['DIRT'], E['BRICK'], E['MAGIC'], E['STEEL']
EXIT, EXITO, BOULDER, BOULDERF = E['EXIT'], E['EXITO'], E['BOULDER'], E['BOULDERF']
DIAMOND, DIAMONDF, FIRE0, BUTT0 = E['DIAMOND'], E['DIAMONDF'], E['FIRE0'], E['BUTT0']
AMOEBA, PLAYER, EXPWALL, INBOX = E['AMOEBA'], E['PLAYER'], E['EXPWALL'], E['INBOX']
EXP1, EXP4, DEX1, DEX4, SHOWER = E['EXP1'], E['EXP4'], E['DEX1'], E['DEX4'], E['SHOWER']
ROUND = (BOULDER, DIAMOND, BRICK, EXPWALL)
SOLID_SKIP = (STEEL, EXIT, EXITO, INBOX, SHOWER)


class Game:
    def __init__(self, index, cave=None, level=0):
        c = cave or C.caves()[index]
        self.cave = c
        self.index = index
        self.g = [STEEL] * (W * C.H)
        for y in range(1, C.H - 1):
            for x in range(1, W - 1):
                self.g[y * W + x] = E[c.g[y][x]]
        self.pl_addr = self.g.index(INBOX)
        self.exit_addr = self.g.index(EXIT)
        self.need, self.dval, self.xval = c.need, c.dval, c.xval
        self.speed = c.speed
        t = c.time
        for _ in range(level):
            if t - 15 < 60:
                break
            t -= 15
        self.ctime = t
        if level >= 2 and self.speed >= 5:
            self.speed -= 1
        self.tps = 8 if self.speed >= 6 else (10 if self.speed >= 5 else 12)
        self.sec_ctr = self.tps
        self.magic_time = c.magic
        self.amoeba_slow = c.amoeba
        self.amoeba_fast = 1 if c.amoeba == 0 else 0
        self.shower_rate, self.shower_haz, self.shower_left = c.shrate, c.shhaz, c.shmax
        self.cseed = (0x5A01 + index * 0x101) & 0xFFFF
        self.got = self.exit_open = self.magic_state = self.amoeba_conv = 0
        self.pl_dead = self.pl_exit = self.pl_frozen = self.timeout = 0
        self.pl_push = 0
        self.inbox_time = 16
        self.score = 0
        self.life_acc = 0
        self.lives = 3
        self.ticks = 0
        self.keys = 0
        self.amoeba_cnt = self.amoeba_grow = 0
        self.scan_ptr = 0

    # ---------------------------------------------------------------- random
    def crand(self):
        s = self.cseed
        h, l = s >> 8, s & 255
        a = ((l >> 1) | ((h & 1) << 7)) ^ h
        h = a
        a = ((h >> 1) | ((l & 1) << 7)) ^ l
        l = a
        h ^= l
        self.cseed = (h << 8) | l
        return h

    # ---------------------------------------------------------------- tick
    def tick(self, keys):
        self.keys = keys
        if self.inbox_time:
            self.inbox_time -= 1
        self.scan()
        self.ticks += 1
        self.clock()

    def clock(self):
        if self.inbox_time or self.pl_frozen or self.pl_dead:
            return
        self.sec_ctr -= 1
        if self.sec_ctr:
            return
        self.sec_ctr = self.tps
        if self.magic_state == 1:
            self.magic_time = (self.magic_time - 1) & 255
            if self.magic_time == 0:
                self.magic_state = 2
        if self.amoeba_slow:
            self.amoeba_slow -= 1
            if self.amoeba_slow == 0:
                self.amoeba_fast = 1
        if self.ctime == 0:
            return
        self.ctime -= 1
        if self.ctime == 0:
            self.pl_frozen = 1
            self.timeout = 1

    def scan(self):
        g = self.g
        self.amoeba_cnt = 0
        self.amoeba_grow = 0
        for i in range(W, W * (C.H - 1)):
            v = g[i]
            if v == 0:
                continue
            if v & 0x80:
                g[i] = v & 0x7F
                continue
            if v < BOULDER:
                continue
            self.scan_ptr = i
            HANDLERS[v](self, i)
        if self.amoeba_conv or self.amoeba_cnt == 0:
            return
        if self.amoeba_cnt >= 200:
            self.amoeba_conv = 1
        elif not self.amoeba_grow:
            self.amoeba_conv = 2

    # ---------------------------------------------------------------- handlers
    def h_rest(self, i):
        g = self.g
        c = g[i]
        below = g[i + W]
        if below == 0:
            g[i] = 0
            g[i + W] = (c + 1) | 0x80
            return
        if (below & 0x1F) in ROUND:
            self.try_roll(i, c + 1)

    def try_roll(self, i, c):
        g = self.g
        if g[i - 1] == 0 and g[i + W - 1] == 0:
            g[i - 1] = c
            g[i] = 0
        elif g[i + 1] == 0 and g[i + W + 1] == 0:
            g[i + 1] = c | 0x80
            g[i] = 0

    def h_fall(self, i):
        g = self.g
        c = g[i]
        b = g[i + W] & 0x1F
        if b == 0:
            g[i] = 0
            g[i + W] = c | 0x80
            return
        if b == MAGIC:
            if self.magic_state != 2:
                if self.magic_state == 0:
                    self.magic_state = 1
                g[i] = 0
                if g[i + 2 * W] == 0:
                    g[i + 2 * W] = (c ^ (BOULDERF ^ DIAMONDF)) | 0x80
                return
        elif b == PLAYER:
            return self.explode(i + W, EXP1)
        elif b >= FIRE0 and b < AMOEBA:
            return self.explode(i + W, EXP1 if b < BUTT0 else DEX1)
        else:
            if b in (BOULDERF, DIAMONDF):
                return
            if b in ROUND:
                self.try_roll(i, c)
                if g[i] != c:
                    return
        g[i] = c - 1                                 # land

    def h_fly(self, i):
        g = self.g
        c = g[i]
        for o in OFF:
            n = g[i + o] & 0x1F
            if n == PLAYER or n == AMOEBA:
                return self.explode(i, EXP1 if c < BUTT0 else DEX1)
        if c < BUTT0:
            d = c - FIRE0
            if self.fly_try(i, (d - 1) & 3) or self.fly_try(i, d):
                return
            g[i] = FIRE0 + ((d + 1) & 3)
        else:
            d = c - BUTT0
            if self.fly_try(i, ((d + 1) & 3) | 4) or self.fly_try(i, d | 4):
                return
            g[i] = BUTT0 + ((d - 1) & 3)

    def fly_try(self, i, e):
        g = self.g
        t = i + OFF[e & 3]
        if g[t] != 0:
            return False
        code = FIRE0 + (e & 3) + (4 if e & 4 else 0)
        if e & 2:
            code |= 0x80
        g[t] = code
        g[i] = 0
        return True

    def h_amoeba(self, i):
        g = self.g
        self.amoeba_cnt += 1
        if self.amoeba_conv:
            g[i] = BOULDER if self.amoeba_conv == 1 else DIAMOND
            return
        if not self.amoeba_grow:
            for o in OFF:
                if g[i + o] < DIRT + 1:
                    self.amoeba_grow = 1
                    break
        b = self.crand()
        thr = 48 if self.amoeba_fast else 6
        if not b < thr:
            return
        e = (self.cseed & 255) & 3
        t = i + OFF[e]
        if g[t] < DIRT + 1:
            g[t] = AMOEBA | (0x80 if e & 2 else 0)

    def h_expwall(self, i):
        g = self.g
        if g[i - 1] == 0:
            g[i - 1] = EXPWALL
        if g[i + 1] == 0:
            g[i + 1] = EXPWALL | 0x80

    def h_exp(self, i):
        self.g[i] = 0 if self.g[i] == EXP4 else self.g[i] + 1

    def h_dex(self, i):
        self.g[i] = DIAMOND if self.g[i] == DEX4 else self.g[i] + 1

    def h_inbox(self, i):
        if self.inbox_time == 0:
            self.g[i] = PLAYER
            self.pl_addr = i

    def h_shower(self, i):
        g = self.g
        if self.shower_left == 0:
            return
        t = i + W
        if g[t] != 0:
            return
        if not self.crand() < self.shower_rate:
            return
        g[t] = (BOULDERF if self.crand() < self.shower_haz else DIAMONDF) | 0x80
        self.shower_left -= 1

    def h_none(self, i):
        pass

    def explode(self, centre, stage):
        g = self.g
        for r in (-W, 0, W):
            for c in (-1, 0, 1):
                j = centre + r + c
                m = g[j] & 0x1F
                if m in SOLID_SKIP:
                    continue
                if m == PLAYER:
                    self.pl_dead = 1
                g[j] = stage | (0x80 if j > self.scan_ptr else 0)

    # ---------------------------------------------------------------- player
    def h_player(self, i):
        g = self.g
        self.pl_addr = i
        push_old = self.pl_push
        self.pl_push = 0
        if self.pl_frozen:
            return
        keys = self.keys
        dirs = keys & 15
        if not dirs:
            return
        b = 0
        if dirs & K_UP:
            b = 1
        if dirs & K_DOWN:
            b = 3
        if dirs & K_LEFT:
            b = 0
        if dirs & K_RIGHT:
            b = 2
        fire = keys & K_FIRE
        t = i + OFF[b]
        m = g[t] & 0x1F
        if m <= DIRT:
            pass
        elif m in (DIAMOND, DIAMONDF):
            self.got_diamond()
        elif m == EXITO:
            if fire:
                return
            g[i] = 0
            self.pl_addr = t
            self.pl_exit = 1
            self.pl_frozen = 1
            return
        elif m == BOULDER:
            if fire or b & 1:
                return
            beyond = t + OFF[b]
            if g[beyond] != 0:
                return
            self.pl_push = push_old + 1
            if self.pl_push < 2:
                return
            self.pl_push = 0
            g[beyond] = BOULDER | (0x80 if b & 2 else 0)
            fire = 0
        else:
            return
        if fire:
            g[t] = 0
            return
        g[i] = 0
        self.pl_addr = t
        g[t] = PLAYER | (0x80 if b & 2 else 0)

    def got_diamond(self):
        self.add_points(self.xval if self.exit_open else self.dval)
        if self.got < 99:
            self.got += 1
        if not self.exit_open and self.need == self.got:
            self.exit_open = 1
            self.g[self.exit_addr] = EXITO

    def add_points(self, p):
        self.score += p
        self.life_acc += p
        if self.life_acc >= 500:
            self.life_acc -= 500
            if self.lives < 9:
                self.lives += 1

    # ---------------------------------------------------------------- helpers
    @property
    def won(self):
        return self.pl_exit

    @property
    def alive(self):
        return not self.pl_dead and not self.timeout

    def at(self, x, y):
        return self.g[y * W + x] & 0x1F

    def player_xy(self):
        return self.pl_addr % W, self.pl_addr // W

    def clone(self):
        n = Game.__new__(Game)
        n.__dict__.update(self.__dict__)
        n.g = list(self.g)
        return n


HANDLERS = [Game.h_none] * 32
for _n in ('BOULDER', 'DIAMOND'):
    HANDLERS[E[_n]] = Game.h_rest
for _n in ('BOULDERF', 'DIAMONDF'):
    HANDLERS[E[_n]] = Game.h_fall
for _d in range(4):
    HANDLERS[FIRE0 + _d] = Game.h_fly
    HANDLERS[BUTT0 + _d] = Game.h_fly
for _k in range(4):
    HANDLERS[EXP1 + _k] = Game.h_exp
    HANDLERS[DEX1 + _k] = Game.h_dex
HANDLERS[AMOEBA] = Game.h_amoeba
HANDLERS[PLAYER] = Game.h_player
HANDLERS[EXPWALL] = Game.h_expwall
HANDLERS[INBOX] = Game.h_inbox
HANDLERS[SHOWER] = Game.h_shower
