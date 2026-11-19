# Compact, complete-enough Z80 interpreter for test harnesses (documented opcodes,
# CB/ED/DD/FD/DDCB/FDCB prefixes, exact T-states). Memory and I/O go through
# callbacks so a machine model can add wait states and memory-mapped I/O.
#   cpu = Z80(read(addr)->int, write(addr,val), inp(port)->int, outp(port,val))
#   cpu.step() executes one instruction; cpu.t counts T-states.

SZ = [0] * 256
SZP = [0] * 256
for _i in range(256):
    s = (_i & 0x80) | (0x40 if _i == 0 else 0) | (_i & 0x28)
    SZ[_i] = s
    p = bin(_i).count('1') & 1
    SZP[_i] = s | (0 if p else 4)

CF, NF, PF, XF, HF, YF, ZF, SF = 1, 2, 4, 8, 16, 32, 64, 128


class Z80:
    def __init__(s, rd, wr, inp=None, outp=None):
        s.rd = rd
        s.wr = wr
        s.inp = inp or (lambda p: 0xFF)
        s.outp = outp or (lambda p, v: None)
        s.a = s.f = s.b = s.c = s.d = s.e = s.h = s.l = 0
        s.a_ = s.f_ = s.b_ = s.c_ = s.d_ = s.e_ = s.h_ = s.l_ = 0
        s.ix = s.iy = 0
        s.sp = 0xFFFF
        s.pc = 0
        s.i = s.r = 0
        s.iff1 = s.iff2 = 0
        s.im = 0
        s.halted = False
        s.t = 0
        s.ei_delay = False
        s._build()

    # ---------------- helpers
    def r16(s, a):
        return s.rd(a) | (s.rd((a + 1) & 0xFFFF) << 8)

    def w16(s, a, v):
        s.wr(a, v & 0xFF)
        s.wr((a + 1) & 0xFFFF, (v >> 8) & 0xFF)

    def fetch(s):
        v = s.rd(s.pc)
        s.pc = (s.pc + 1) & 0xFFFF
        return v

    def fetch16(s):
        v = s.rd(s.pc) | (s.rd((s.pc + 1) & 0xFFFF) << 8)
        s.pc = (s.pc + 2) & 0xFFFF
        return v

    def push(s, v):
        s.sp = (s.sp - 1) & 0xFFFF
        s.wr(s.sp, (v >> 8) & 0xFF)
        s.sp = (s.sp - 1) & 0xFFFF
        s.wr(s.sp, v & 0xFF)

    def pop(s):
        v = s.rd(s.sp) | (s.rd((s.sp + 1) & 0xFFFF) << 8)
        s.sp = (s.sp + 2) & 0xFFFF
        return v

    # register pairs
    def get_bc(s): return (s.b << 8) | s.c
    def get_de(s): return (s.d << 8) | s.e
    def get_hl(s): return (s.h << 8) | s.l
    def set_bc(s, v): s.b = (v >> 8) & 0xFF; s.c = v & 0xFF
    def set_de(s, v): s.d = (v >> 8) & 0xFF; s.e = v & 0xFF
    def set_hl(s, v): s.h = (v >> 8) & 0xFF; s.l = v & 0xFF
    def get_af(s): return (s.a << 8) | s.f
    def set_af(s, v): s.a = (v >> 8) & 0xFF; s.f = v & 0xFF

    # ---------------- ALU
    def add8(s, v, c=0):
        a = s.a
        r = a + v + c
        f = SZ[r & 0xFF] | (r >> 8 & 1) | ((a ^ v ^ r) & HF)
        if (~(a ^ v) & (a ^ r)) & 0x80: f |= PF
        s.a = r & 0xFF
        s.f = f

    def sub8(s, v, c=0, store=True):
        a = s.a
        r = a - v - c
        f = SZ[r & 0xFF] | NF | ((r >> 8) & 1) | ((a ^ v ^ r) & HF)
        if ((a ^ v) & (a ^ r)) & 0x80: f |= PF
        if store:
            s.a = r & 0xFF
            s.f = f
        else:
            s.f = (f & ~0x28) | (v & 0x28)

    def and8(s, v):
        s.a &= v
        s.f = SZP[s.a] | HF

    def xor8(s, v):
        s.a = (s.a ^ v) & 0xFF
        s.f = SZP[s.a]

    def or8(s, v):
        s.a = (s.a | v) & 0xFF
        s.f = SZP[s.a]

    def alu(s, op, v):
        if op == 0: s.add8(v)
        elif op == 1: s.add8(v, s.f & 1)
        elif op == 2: s.sub8(v)
        elif op == 3: s.sub8(v, s.f & 1)
        elif op == 4: s.and8(v)
        elif op == 5: s.xor8(v)
        elif op == 6: s.or8(v)
        else: s.sub8(v, 0, False)

    def inc8(s, v):
        r = (v + 1) & 0xFF
        f = (s.f & CF) | SZ[r] | ((v ^ r) & HF)
        if r == 0x80: f |= PF
        s.f = f
        return r

    def dec8(s, v):
        r = (v - 1) & 0xFF
        f = (s.f & CF) | SZ[r] | NF | ((v ^ r) & HF)
        if r == 0x7F: f |= PF
        s.f = f
        return r

    def add16(s, a, b):
        r = a + b
        s.f = (s.f & (SF | ZF | PF)) | ((r >> 16) & 1) | (((a ^ b ^ r) >> 8) & HF) | ((r >> 8) & 0x28)
        return r & 0xFFFF

    def adc16(s, a, b):
        c = s.f & 1
        r = a + b + c
        f = ((r >> 16) & 1) | (((a ^ b ^ r) >> 8) & HF) | ((r >> 8) & 0xA8)
        if (r & 0xFFFF) == 0: f |= ZF
        if (~(a ^ b) & (a ^ r)) & 0x8000: f |= PF
        s.f = f
        return r & 0xFFFF

    def sbc16(s, a, b):
        c = s.f & 1
        r = a - b - c
        f = NF | ((r >> 16) & 1) | (((a ^ b ^ r) >> 8) & HF) | ((r >> 8) & 0xA8)
        if (r & 0xFFFF) == 0: f |= ZF
        if ((a ^ b) & (a ^ r)) & 0x8000: f |= PF
        s.f = f
        return r & 0xFFFF

    def rot(s, op, v):
        c = s.f & 1
        if op == 0: r = ((v << 1) | (v >> 7)) & 0xFF; nc = v >> 7
        elif op == 1: r = ((v >> 1) | (v << 7)) & 0xFF; nc = v & 1
        elif op == 2: r = ((v << 1) | c) & 0xFF; nc = v >> 7
        elif op == 3: r = ((v >> 1) | (c << 7)) & 0xFF; nc = v & 1
        elif op == 4: r = (v << 1) & 0xFF; nc = v >> 7
        elif op == 5: r = ((v >> 1) | (v & 0x80)) & 0xFF; nc = v & 1
        elif op == 6: r = ((v << 1) | 1) & 0xFF; nc = v >> 7
        else: r = v >> 1; nc = v & 1
        s.f = SZP[r] | nc
        return r

    def cond(s, cc):
        f = s.f
        if cc == 0: return not (f & ZF)
        if cc == 1: return bool(f & ZF)
        if cc == 2: return not (f & CF)
        if cc == 3: return bool(f & CF)
        if cc == 4: return not (f & PF)
        if cc == 5: return bool(f & PF)
        if cc == 6: return not (f & SF)
        return bool(f & SF)

    # register access by 3-bit index (6 = (HL) handled by caller)
    def getr(s, i):
        return (s.b, s.c, s.d, s.e, s.h, s.l, 0, s.a)[i]

    def setr(s, i, v):
        if i == 0: s.b = v
        elif i == 1: s.c = v
        elif i == 2: s.d = v
        elif i == 3: s.e = v
        elif i == 4: s.h = v
        elif i == 5: s.l = v
        elif i == 7: s.a = v

    def getrp(s, i):
        if i == 0: return s.get_bc()
        if i == 1: return s.get_de()
        if i == 2: return s.get_hl()
        return s.sp

    def setrp(s, i, v):
        if i == 0: s.set_bc(v)
        elif i == 1: s.set_de(v)
        elif i == 2: s.set_hl(v)
        else: s.sp = v & 0xFFFF

    # ---------------- main step
    def interrupt(s, vec=0x38):
        if not s.iff1: return False
        if s.halted:
            s.halted = False
            s.pc = (s.pc + 1) & 0xFFFF
        s.iff1 = s.iff2 = 0
        s.push(s.pc)
        s.pc = vec if s.im != 2 else s.r16((s.i << 8) | 0xFF)
        s.t += 13
        return True

    def step(s):
        if s.halted:
            s.t += 4
            return
        op = s.fetch()
        s.r = (s.r & 0x80) | ((s.r + 1) & 0x7F)
        s.ops[op](op)

    def _build(s):
        ops = [None] * 256
        for op in range(256):
            ops[op] = s._decode(op)
        s.ops = ops

    def _decode(s, op):
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        p, q = y >> 1, y & 1
        if x == 1:
            if op == 0x76:
                def f(o):
                    s.halted = True
                    s.pc = (s.pc - 1) & 0xFFFF
                    s.t += 4
                return f
            if z == 6:
                def f(o, y=y):
                    s.setr(y, s.rd(s.get_hl())); s.t += 7
                return f
            if y == 6:
                def f(o, z=z):
                    s.wr(s.get_hl(), s.getr(z)); s.t += 7
                return f
            def f(o, y=y, z=z):
                s.setr(y, s.getr(z)); s.t += 4
            return f
        if x == 2:
            if z == 6:
                def f(o, y=y):
                    s.alu(y, s.rd(s.get_hl())); s.t += 7
                return f
            def f(o, y=y, z=z):
                s.alu(y, s.getr(z)); s.t += 4
            return f
        if x == 0:
            if z == 0:
                if y == 0:
                    def f(o): s.t += 4
                    return f
                if y == 1:
                    def f(o):
                        s.a, s.a_ = s.a_, s.a
                        s.f, s.f_ = s.f_, s.f
                        s.t += 4
                    return f
                if y == 2:
                    def f(o):
                        d = s.fetch()
                        s.b = (s.b - 1) & 0xFF
                        if s.b:
                            s.pc = (s.pc + (d - 256 if d > 127 else d)) & 0xFFFF; s.t += 13
                        else:
                            s.t += 8
                    return f
                if y == 3:
                    def f(o):
                        d = s.fetch()
                        s.pc = (s.pc + (d - 256 if d > 127 else d)) & 0xFFFF; s.t += 12
                    return f
                def f(o, cc=y - 4):
                    d = s.fetch()
                    if s.cond(cc):
                        s.pc = (s.pc + (d - 256 if d > 127 else d)) & 0xFFFF; s.t += 12
                    else:
                        s.t += 7
                return f
            if z == 1:
                if q == 0:
                    def f(o, p=p):
                        s.setrp(p, s.fetch16()); s.t += 10
                    return f
                def f(o, p=p):
                    s.set_hl(s.add16(s.get_hl(), s.getrp(p))); s.t += 11
                return f
            if z == 2:
                if op == 0x02:
                    def f(o): s.wr(s.get_bc(), s.a); s.t += 7
                elif op == 0x12:
                    def f(o): s.wr(s.get_de(), s.a); s.t += 7
                elif op == 0x22:
                    def f(o): s.w16(s.fetch16(), s.get_hl()); s.t += 16
                elif op == 0x32:
                    def f(o): s.wr(s.fetch16(), s.a); s.t += 13
                elif op == 0x0A:
                    def f(o): s.a = s.rd(s.get_bc()); s.t += 7
                elif op == 0x1A:
                    def f(o): s.a = s.rd(s.get_de()); s.t += 7
                elif op == 0x2A:
                    def f(o): s.set_hl(s.r16(s.fetch16())); s.t += 16
                else:
                    def f(o): s.a = s.rd(s.fetch16()); s.t += 13
                return f
            if z == 3:
                if q == 0:
                    def f(o, p=p): s.setrp(p, (s.getrp(p) + 1) & 0xFFFF); s.t += 6
                else:
                    def f(o, p=p): s.setrp(p, (s.getrp(p) - 1) & 0xFFFF); s.t += 6
                return f
            if z == 4:
                if y == 6:
                    def f(o):
                        a = s.get_hl(); s.wr(a, s.inc8(s.rd(a))); s.t += 11
                    return f
                def f(o, y=y): s.setr(y, s.inc8(s.getr(y))); s.t += 4
                return f
            if z == 5:
                if y == 6:
                    def f(o):
                        a = s.get_hl(); s.wr(a, s.dec8(s.rd(a))); s.t += 11
                    return f
                def f(o, y=y): s.setr(y, s.dec8(s.getr(y))); s.t += 4
                return f
            if z == 6:
                if y == 6:
                    def f(o): s.wr(s.get_hl(), s.fetch()); s.t += 10
                    return f
                def f(o, y=y): s.setr(y, s.fetch()); s.t += 7
                return f
            # z == 7
            def f(o, y=y):
                a = s.a
                if y == 0:
                    s.a = ((a << 1) | (a >> 7)) & 0xFF
                    s.f = (s.f & (SF | ZF | PF)) | (a >> 7) | (s.a & 0x28)
                elif y == 1:
                    s.a = ((a >> 1) | (a << 7)) & 0xFF
                    s.f = (s.f & (SF | ZF | PF)) | (a & 1) | (s.a & 0x28)
                elif y == 2:
                    s.a = ((a << 1) | (s.f & 1)) & 0xFF
                    s.f = (s.f & (SF | ZF | PF)) | (a >> 7) | (s.a & 0x28)
                elif y == 3:
                    s.a = ((a >> 1) | ((s.f & 1) << 7)) & 0xFF
                    s.f = (s.f & (SF | ZF | PF)) | (a & 1) | (s.a & 0x28)
                elif y == 4:  # DAA
                    c = s.f & CF; h = s.f & HF; n = s.f & NF
                    corr = 0; nc = 0
                    if h or (a & 0xF) > 9: corr |= 6
                    if c or a > 0x99: corr |= 0x60; nc = 1
                    if n:
                        r = (a - corr) & 0xFF
                        nh = HF if (h and (a & 0xF) < 6) else 0
                    else:
                        r = (a + corr) & 0xFF
                        nh = HF if (a & 0xF) > 9 else 0
                    s.a = r
                    s.f = SZP[r] | nc | nh | n
                elif y == 5:
                    s.a = a ^ 0xFF
                    s.f = (s.f & (SF | ZF | PF | CF)) | HF | NF | (s.a & 0x28)
                elif y == 6:
                    s.f = (s.f & (SF | ZF | PF)) | CF | (a & 0x28)
                else:
                    c = s.f & CF
                    s.f = (s.f & (SF | ZF | PF)) | (HF if c else 0) | (0 if c else CF) | (a & 0x28)
                s.t += 4
            return f
        # x == 3
        if z == 0:
            def f(o, cc=y):
                if s.cond(cc): s.pc = s.pop(); s.t += 11
                else: s.t += 5
            return f
        if z == 1:
            if q == 0:
                if p == 3:
                    def f(o): s.set_af(s.pop()); s.t += 10
                else:
                    def f(o, p=p): s.setrp(p, s.pop()); s.t += 10
                return f
            if p == 0:
                def f(o): s.pc = s.pop(); s.t += 10
            elif p == 1:
                def f(o):
                    s.b, s.b_ = s.b_, s.b; s.c, s.c_ = s.c_, s.c
                    s.d, s.d_ = s.d_, s.d; s.e, s.e_ = s.e_, s.e
                    s.h, s.h_ = s.h_, s.h; s.l, s.l_ = s.l_, s.l
                    s.t += 4
            elif p == 2:
                def f(o): s.pc = s.get_hl(); s.t += 4
            else:
                def f(o): s.sp = s.get_hl(); s.t += 6
            return f
        if z == 2:
            def f(o, cc=y):
                a = s.fetch16()
                if s.cond(cc): s.pc = a
                s.t += 10
            return f
        if z == 3:
            if y == 0:
                def f(o): s.pc = s.fetch16(); s.t += 10
            elif y == 1:
                return s._cb
            elif y == 2:
                def f(o): s.outp((s.a << 8) | s.fetch(), s.a); s.t += 11
            elif y == 3:
                def f(o): s.a = s.inp((s.a << 8) | s.fetch()); s.t += 11
            elif y == 4:
                def f(o):
                    v = s.r16(s.sp); s.w16(s.sp, s.get_hl()); s.set_hl(v); s.t += 19
            elif y == 5:
                def f(o):
                    s.d, s.h = s.h, s.d; s.e, s.l = s.l, s.e; s.t += 4
            elif y == 6:
                def f(o): s.iff1 = s.iff2 = 0; s.t += 4
            else:
                def f(o): s.iff1 = s.iff2 = 1; s.t += 4
            return f
        if z == 4:
            def f(o, cc=y):
                a = s.fetch16()
                if s.cond(cc):
                    s.push(s.pc); s.pc = a; s.t += 17
                else:
                    s.t += 10
            return f
        if z == 5:
            if q == 0:
                if p == 3:
                    def f(o): s.push(s.get_af()); s.t += 11
                else:
                    def f(o, p=p): s.push(s.getrp(p)); s.t += 11
                return f
            if p == 0:
                def f(o):
                    a = s.fetch16(); s.push(s.pc); s.pc = a; s.t += 17
                return f
            if p == 1: return lambda o: s._index('ix')
            if p == 2: return s._ed
            return lambda o: s._index('iy')
        if z == 6:
            def f(o, y=y): s.alu(y, s.fetch()); s.t += 7
            return f
        def f(o, y=y):
            s.push(s.pc); s.pc = y * 8; s.t += 11
        return f

    # ---------------- CB prefix
    def _cb(s, o):
        op = s.fetch()
        s.r = (s.r & 0x80) | ((s.r + 1) & 0x7F)
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        if z == 6:
            a = s.get_hl(); v = s.rd(a)
            if x == 1:
                s._bit(y, v); s.f = (s.f & ~0x28); s.t += 12; return
            s.wr(a, s._cbop(x, y, v)); s.t += 15
            return
        v = s.getr(z)
        if x == 1:
            s._bit(y, v); s.t += 8; return
        s.setr(z, s._cbop(x, y, v)); s.t += 8

    def _bit(s, y, v):
        r = v & (1 << y)
        f = (s.f & CF) | HF | (v & 0x28)
        if r == 0: f |= ZF | PF
        if y == 7 and r: f |= SF
        s.f = f

    def _cbop(s, x, y, v):
        if x == 0: return s.rot(y, v)
        if x == 2: return v & ~(1 << y) & 0xFF
        return v | (1 << y)

    # ---------------- DD / FD
    def _index(s, reg):
        op = s.fetch()
        s.r = (s.r & 0x80) | ((s.r + 1) & 0x7F)
        xy = getattr(s, reg)

        def disp():
            d = s.fetch()
            return (xy + (d - 256 if d > 127 else d)) & 0xFFFF

        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        if op == 0xCB:
            a = disp(); op2 = s.fetch()
            x2, y2, z2 = op2 >> 6, (op2 >> 3) & 7, op2 & 7
            v = s.rd(a)
            if x2 == 1:
                s._bit(y2, v); s.f = (s.f & ~0x28) | ((a >> 8) & 0x28); s.t += 20; return
            r = s._cbop(x2, y2, v)
            s.wr(a, r)
            if z2 != 6: s.setr(z2, r)
            s.t += 23
            return
        if op == 0x21: setattr(s, reg, s.fetch16()); s.t += 14; return
        if op == 0x22: s.w16(s.fetch16(), xy); s.t += 20; return
        if op == 0x2A: setattr(s, reg, s.r16(s.fetch16())); s.t += 20; return
        if op == 0x23: setattr(s, reg, (xy + 1) & 0xFFFF); s.t += 10; return
        if op == 0x2B: setattr(s, reg, (xy - 1) & 0xFFFF); s.t += 10; return
        if op in (0x09, 0x19, 0x29, 0x39):
            v = (s.get_bc(), s.get_de(), xy, s.sp)[op >> 4]
            setattr(s, reg, s.add16(xy, v)); s.t += 15; return
        if op == 0x34:
            a = disp(); s.wr(a, s.inc8(s.rd(a))); s.t += 23; return
        if op == 0x35:
            a = disp(); s.wr(a, s.dec8(s.rd(a))); s.t += 23; return
        if op == 0x36:
            a = disp(); s.wr(a, s.fetch()); s.t += 19; return
        if op == 0xE1: setattr(s, reg, s.pop()); s.t += 14; return
        if op == 0xE5: s.push(xy); s.t += 15; return
        if op == 0xE9: s.pc = xy; s.t += 8; return
        if op == 0xF9: s.sp = xy; s.t += 10; return
        if op == 0xE3:
            v = s.r16(s.sp); s.w16(s.sp, xy); setattr(s, reg, v); s.t += 23; return
        # half-index registers
        def gh(i):
            if i == 4: return (getattr(s, reg) >> 8) & 0xFF
            if i == 5: return getattr(s, reg) & 0xFF
            return s.getr(i)

        def sh(i, v):
            if i == 4: setattr(s, reg, (getattr(s, reg) & 0xFF) | (v << 8))
            elif i == 5: setattr(s, reg, (getattr(s, reg) & 0xFF00) | v)
            else: s.setr(i, v)
        if x == 1 and op != 0x76:
            if z == 6:
                a = disp(); s.setr(y, s.rd(a)); s.t += 19; return
            if y == 6:
                a = disp(); s.wr(a, s.getr(z)); s.t += 19; return
            sh(y, gh(z)); s.t += 8; return
        if x == 2:
            if z == 6:
                a = disp(); s.alu(y, s.rd(a)); s.t += 19; return
            s.alu(y, gh(z)); s.t += 8; return
        if x == 0 and z == 4 and y in (4, 5):
            sh(y, s.inc8(gh(y))); s.t += 8; return
        if x == 0 and z == 5 and y in (4, 5):
            sh(y, s.dec8(gh(y))); s.t += 8; return
        if x == 0 and z == 6 and y in (4, 5):
            sh(y, s.fetch()); s.t += 11; return
        # otherwise: prefix acts as NOP on following opcode
        s.t += 4
        s.ops[op](op)

    # ---------------- ED prefix
    def _ed(s, o):
        op = s.fetch()
        s.r = (s.r & 0x80) | ((s.r + 1) & 0x7F)
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        p, q = y >> 1, y & 1
        if x == 1:
            if z == 0:
                v = s.inp((s.b << 8) | s.c)
                if y != 6: s.setr(y, v)
                s.f = (s.f & CF) | SZP[v]; s.t += 12; return
            if z == 1:
                s.outp((s.b << 8) | s.c, s.getr(y) if y != 6 else 0); s.t += 12; return
            if z == 2:
                if q == 0: s.set_hl(s.sbc16(s.get_hl(), s.getrp(p)))
                else: s.set_hl(s.adc16(s.get_hl(), s.getrp(p)))
                s.t += 15; return
            if z == 3:
                a = s.fetch16()
                if q == 0: s.w16(a, s.getrp(p))
                else: s.setrp(p, s.r16(a))
                s.t += 20; return
            if z == 4:
                a = s.a; s.a = 0; s.sub8(a); s.t += 8; return
            if z == 5:
                s.pc = s.pop(); s.iff1 = s.iff2; s.t += 14; return
            if z == 6:
                s.im = (0, 0, 1, 2, 0, 0, 1, 2)[y]; s.t += 8; return
            if y == 0: s.i = s.a; s.t += 9; return
            if y == 1: s.r = s.a; s.t += 9; return
            if y == 2:
                s.a = s.i; s.f = (s.f & CF) | SZ[s.a] | (PF if s.iff2 else 0); s.t += 9; return
            if y == 3:
                s.a = s.r; s.f = (s.f & CF) | SZ[s.a] | (PF if s.iff2 else 0); s.t += 9; return
            if y == 4:  # RRD
                a = s.get_hl(); m = s.rd(a)
                s.wr(a, ((s.a << 4) | (m >> 4)) & 0xFF)
                s.a = (s.a & 0xF0) | (m & 0x0F)
                s.f = (s.f & CF) | SZP[s.a]; s.t += 18; return
            if y == 5:  # RLD
                a = s.get_hl(); m = s.rd(a)
                s.wr(a, ((m << 4) | (s.a & 0x0F)) & 0xFF)
                s.a = (s.a & 0xF0) | (m >> 4)
                s.f = (s.f & CF) | SZP[s.a]; s.t += 18; return
            s.t += 8; return
        if x == 2 and z <= 3 and y >= 4:
            inc = 1 if (y & 1) == 0 else -1
            rep = y >= 6
            while True:
                hl = s.get_hl(); bc = s.get_bc()
                if z == 0:  # LDI/LDD
                    v = s.rd(hl); s.wr(s.get_de(), v)
                    s.set_hl(hl + inc); s.set_de(s.get_de() + inc); bc = (bc - 1) & 0xFFFF; s.set_bc(bc)
                    s.f = (s.f & (SF | ZF | CF)) | (PF if bc else 0)
                    if rep and bc:
                        s.t += 21; s.pc = (s.pc - 2) & 0xFFFF; return
                    s.t += 16; return
                if z == 1:  # CPI/CPD
                    v = s.rd(hl); c = s.f & CF
                    s.sub8(v, 0, False)
                    s.set_hl(hl + inc); bc = (bc - 1) & 0xFFFF; s.set_bc(bc)
                    s.f = (s.f & ~(PF | CF)) | (PF if bc else 0) | c
                    if rep and bc and not (s.f & ZF):
                        s.t += 21; s.pc = (s.pc - 2) & 0xFFFF; return
                    s.t += 16; return
                if z == 2:  # INI/IND
                    v = s.inp(bc); s.wr(hl, v); s.set_hl(hl + inc)
                    s.b = (s.b - 1) & 0xFF; s.f = SZ[s.b] | NF
                    if rep and s.b:
                        s.t += 21; s.pc = (s.pc - 2) & 0xFFFF; return
                    s.t += 16; return
                # OUTI/OUTD
                v = s.rd(hl); s.b = (s.b - 1) & 0xFF
                s.outp((s.b << 8) | s.c, v); s.set_hl(hl + inc); s.f = SZ[s.b] | NF
                if rep and s.b:
                    s.t += 21; s.pc = (s.pc - 2) & 0xFFFF; return
                s.t += 16; return
        s.t += 8
