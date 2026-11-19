"""zasm.py - a compact two-pass Z80 assembler (stdlib only).

Syntax (case-insensitive mnemonics):
  label:            global label           .loop:   local label (scoped to last global)
  NAME equ expr     NAME = expr
  org / db / dw / ds / align / include "file" / dsc "TEXT" (MZ display codes, no terminator)
  phase addr / dephase: assemble code to run at addr while emitting it here
  Numbers: 123, 0x1F, 1Fh, 0b1010, %1010, 'A'.   $ = current address.
  Functions in expressions: lo(x), hi(x).
Includes the undocumented IXH/IXL/IYH/IYL forms and SLL.
"""
import os
import re
import sys

R8 = {'B': 0, 'C': 1, 'D': 2, 'E': 3, 'H': 4, 'L': 5, '(HL)': 6, 'A': 7}
IXH = {'IXH': (0xDD, 4), 'IXL': (0xDD, 5), 'IYH': (0xFD, 4), 'IYL': (0xFD, 5)}
RP = {'BC': 0, 'DE': 1, 'HL': 2, 'SP': 3}
RP2 = {'BC': 0, 'DE': 1, 'HL': 2, 'AF': 3}
CC = {'NZ': 0, 'Z': 1, 'NC': 2, 'C': 3, 'PO': 4, 'PE': 5, 'P': 6, 'M': 7}
ALU = {'ADD': 0, 'ADC': 1, 'SUB': 2, 'SBC': 3, 'AND': 4, 'XOR': 5, 'OR': 6, 'CP': 7}
ROT = {'RLC': 0, 'RRC': 1, 'RL': 2, 'RR': 3, 'SLA': 4, 'SRA': 5, 'SLL': 6, 'SRL': 7}
SIMPLE = {
    'NOP': [0x00], 'HALT': [0x76], 'DI': [0xF3], 'EI': [0xFB], 'EXX': [0xD9],
    'RLCA': [0x07], 'RRCA': [0x0F], 'RLA': [0x17], 'RRA': [0x1F], 'DAA': [0x27],
    'CPL': [0x2F], 'SCF': [0x37], 'CCF': [0x3F],
    'NEG': [0xED, 0x44], 'RETN': [0xED, 0x45], 'RETI': [0xED, 0x4D],
    'RRD': [0xED, 0x67], 'RLD': [0xED, 0x6F],
    'LDI': [0xED, 0xA0], 'CPI': [0xED, 0xA1], 'INI': [0xED, 0xA2], 'OUTI': [0xED, 0xA3],
    'LDD': [0xED, 0xA8], 'CPD': [0xED, 0xA9], 'IND': [0xED, 0xAA], 'OUTD': [0xED, 0xAB],
    'LDIR': [0xED, 0xB0], 'CPIR': [0xED, 0xB1], 'INIR': [0xED, 0xB2], 'OTIR': [0xED, 0xB3],
    'LDDR': [0xED, 0xB8], 'CPDR': [0xED, 0xB9], 'INDR': [0xED, 0xBA], 'OTDR': [0xED, 0xBB],
}


def dispcode(ch):
    """ASCII -> Sharp MZ-700 display code (upper case, digits, common punctuation)."""
    if 'A' <= ch <= 'Z':
        return ord(ch) - 0x40
    if '0' <= ch <= '9':
        return 0x20 + ord(ch) - 0x30
    # checked against the European (international) CG-ROM
    table = {' ': 0x00, '.': 0x2E, '-': 0x2A, '!': 0x61, ':': 0x4F, '=': 0x2B, '/': 0x2D,
             ',': 0x2F, '?': 0x49, '*': 0x6B, '+': 0x6A, "'": 0x67, '"': 0x62, '(': 0x68, ')': 0x69}
    if ch in table:
        return table[ch]
    raise ValueError('no display code for %r' % ch)


class AsmError(Exception):
    pass


class Asm:
    def __init__(self, base_dir='.'):
        self.base_dir = base_dir
        self.sym = {}

    # ------------------------------------------------------------ expressions
    def ev(self, e):
        s = e.strip()
        s = re.sub(r"'(.)'", lambda m: str(ord(m.group(1))), s)
        s = re.sub(r'\b([0-9][0-9A-Fa-f]*)[hH]\b', lambda m: str(int(m.group(1), 16)), s)
        s = re.sub(r'%([01]+)\b', lambda m: str(int(m.group(1), 2)), s)
        s = re.sub(r'\.([A-Za-z_]\w*)', lambda m: '_L_' + self.scope + '_' + m.group(1), s)
        s = s.replace('$', '__pc__')
        env = {}
        for k, v in self.sym.items():
            env[k] = v
        env['__pc__'] = self.pc
        env['lo'] = lambda x: x & 0xFF
        env['hi'] = lambda x: (x >> 8) & 0xFF
        env['LO'] = env['lo']
        env['HI'] = env['hi']
        s = s.replace('/', '//')
        try:
            return int(eval(s, {'__builtins__': {}}, env))
        except NameError as ex:
            if self.final:
                raise AsmError('undefined symbol in %r (%s)' % (e, ex))
            return 0

    def label_name(self, name):
        if name.startswith('.'):
            return '_L_' + self.scope + '_' + name[1:]
        return name

    def define(self, name, value):
        if self.final and name in self.sym and self.sym[name] != value and name not in self.redefinable:
            raise AsmError('label %s changed value between passes (%04X -> %04X)' % (name, self.sym[name], value))
        if not self.final and name in self.defined_this_pass and name not in self.redefinable:
            raise AsmError('duplicate symbol ' + name)
        self.defined_this_pass.add(name)
        self.sym[name] = value

    # ------------------------------------------------------------ operands
    def cls(self, op):
        o = op.strip()
        u = o.upper().replace(' ', '')
        if u in R8:
            return ('r8', R8[u])
        if u in IXH:
            return ('xh',) + IXH[u]
        if u in ('IX', 'IY'):
            return ('xr', 0xDD if u == 'IX' else 0xFD)
        if u in ('BC', 'DE', 'HL', 'SP', 'AF'):
            return ('rp', u)
        if u == "AF'":
            return ('afx',)
        if u in ('I', 'R'):
            return ('ir', u)
        m = re.match(r'^\((IX|IY)([+-].*)?\)$', u)
        if m:
            inner = o.strip()[1:-1].strip()[2:].strip()
            return ('ix', 0xDD if m.group(1) == 'IX' else 0xFD, inner if inner else '0')
        if u in ('(BC)', '(DE)', '(SP)', '(C)'):
            return ('indr', u[1:-1])
        if o.startswith('(') and o.endswith(')'):
            depth = 0
            outer = True
            for i, ch in enumerate(o):
                if ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth == 0 and i != len(o) - 1:
                        outer = False
            if outer:
                return ('ind', o[1:-1])
        return ('imm', o)

    def n8(self, e):
        v = self.ev(e)
        if self.final and not -128 <= v <= 255:
            raise AsmError('byte out of range: %s = %d' % (e, v))
        return v & 0xFF

    def n16(self, e):
        v = self.ev(e) & 0xFFFF
        return [v & 0xFF, v >> 8]

    def d8(self, e):
        v = self.ev(e)
        if self.final and not -128 <= v <= 127:
            raise AsmError('index displacement out of range: %d' % v)
        return v & 0xFF

    def rel(self, e):
        t = self.ev(e)
        d = t - (self.pc + 2)
        if self.final and not -128 <= d <= 127:
            raise AsmError('relative jump out of range (%d)' % d)
        return d & 0xFF

    # ------------------------------------------------------------ encoder
    def enc(self, mn, ops):
        C = [self.cls(o) for o in ops]
        n = len(C)
        if mn in SIMPLE and n == 0:
            return SIMPLE[mn]
        if mn == 'RET' and n == 0:
            return [0xC9]
        if mn == 'LD' and n == 2:
            return self.enc_ld(C, ops)
        if mn in ('PUSH', 'POP') and n == 1:
            base = 0xC5 if mn == 'PUSH' else 0xC1
            a = C[0]
            if a[0] == 'xr':
                return [a[1], base | 0x20]
            if a[0] == 'rp' and a[1] in RP2:
                return [base | RP2[a[1]] << 4]
        if mn in ALU:
            if n == 2:
                a, b = C
                if a == ('rp', 'HL') and b[0] == 'rp' and b[1] in RP:
                    r = RP[b[1]]
                    if mn == 'ADD':
                        return [0x09 | r << 4]
                    if mn == 'ADC':
                        return [0xED, 0x4A | r << 4]
                    if mn == 'SBC':
                        return [0xED, 0x42 | r << 4]
                if a[0] == 'xr' and mn == 'ADD':
                    if b[0] == 'rp' and b[1] in ('BC', 'DE', 'SP'):
                        return [a[1], 0x09 | RP[b[1]] << 4]
                    if b == a:
                        return [a[1], 0x29]
                if a == ('r8', 7):
                    C = C[1:]
                    n = 1
                else:
                    raise AsmError('bad ALU operands')
            a = C[0]
            k = ALU[mn]
            if a[0] == 'r8':
                return [0x80 | k << 3 | a[1]]
            if a[0] == 'xh':
                return [a[1], 0x80 | k << 3 | a[2]]
            if a[0] == 'imm':
                return [0xC6 | k << 3, self.n8(a[1])]
            if a[0] == 'ix':
                return [a[1], 0x86 | k << 3, self.d8(a[2])]
        if mn in ('INC', 'DEC') and n == 1:
            a = C[0]
            dec = mn == 'DEC'
            if a[0] == 'r8':
                return [0x04 | a[1] << 3 | dec]
            if a[0] == 'xh':
                return [a[1], 0x04 | a[2] << 3 | dec]
            if a[0] == 'rp' and a[1] in RP:
                return [(0x0B if dec else 0x03) | RP[a[1]] << 4]
            if a[0] == 'xr':
                return [a[1], 0x2B if dec else 0x23]
            if a[0] == 'ix':
                return [a[1], 0x34 | dec, self.d8(a[2])]
        if mn == 'JP':
            if n == 1:
                a = C[0]
                if a == ('r8', 6):
                    return [0xE9]
                if a[0] == 'ind' and a[1].strip().upper() in ('IX', 'IY'):
                    return [0xDD if a[1].strip().upper() == 'IX' else 0xFD, 0xE9]
                if a[0] == 'xr' or (a[0] == 'ix' and a[2] == '0'):
                    return [a[1], 0xE9]
                return [0xC3] + self.n16(ops[0])
            return [0xC2 | CC[ops[0].strip().upper()] << 3] + self.n16(ops[1])
        if mn == 'JR':
            if n == 1:
                return [0x18, self.rel(ops[0])]
            c = CC[ops[0].strip().upper()]
            if c > 3:
                raise AsmError('JR condition must be NZ/Z/NC/C')
            return [0x20 | c << 3, self.rel(ops[1])]
        if mn == 'DJNZ':
            return [0x10, self.rel(ops[0])]
        if mn == 'CALL':
            if n == 1:
                return [0xCD] + self.n16(ops[0])
            return [0xC4 | CC[ops[0].strip().upper()] << 3] + self.n16(ops[1])
        if mn == 'RET' and n == 1:
            return [0xC0 | CC[ops[0].strip().upper()] << 3]
        if mn == 'RST':
            v = self.ev(ops[0])
            return [0xC7 | (v & 0x38)]
        if mn == 'EX':
            u = [o.strip().upper().replace(' ', '') for o in ops]
            if u == ['DE', 'HL']:
                return [0xEB]
            if u == ['AF', "AF'"]:
                return [0x08]
            if u == ['(SP)', 'HL']:
                return [0xE3]
            if u == ['(SP)', 'IX']:
                return [0xDD, 0xE3]
            if u == ['(SP)', 'IY']:
                return [0xFD, 0xE3]
        if mn == 'IM':
            return [0xED, {0: 0x46, 1: 0x56, 2: 0x5E}[self.ev(ops[0])]]
        if mn in ROT and n == 1:
            a = C[0]
            k = ROT[mn]
            if a[0] == 'r8':
                return [0xCB, k << 3 | a[1]]
            if a[0] == 'ix':
                return [a[1], 0xCB, self.d8(a[2]), k << 3 | 6]
        if mn in ('BIT', 'RES', 'SET') and n == 2:
            b = self.ev(ops[0])
            a = C[1]
            base = {'BIT': 0x40, 'RES': 0x80, 'SET': 0xC0}[mn]
            if a[0] == 'r8':
                return [0xCB, base | b << 3 | a[1]]
            if a[0] == 'ix':
                return [a[1], 0xCB, self.d8(a[2]), base | b << 3 | 6]
        if mn == 'IN' and n == 2:
            a, b = C
            if a == ('r8', 7) and b[0] == 'ind':
                return [0xDB, self.n8(b[1])]
            if a[0] == 'r8' and b == ('indr', 'C'):
                return [0xED, 0x40 | a[1] << 3]
        if mn == 'OUT' and n == 2:
            a, b = C
            if a[0] == 'ind' and b == ('r8', 7):
                return [0xD3, self.n8(a[1])]
            if a == ('indr', 'C') and b[0] == 'r8':
                return [0xED, 0x41 | b[1] << 3]
        raise AsmError('cannot encode %s %s' % (mn, ', '.join(ops)))

    def enc_ld(self, C, ops):
        a, b = C
        if a[0] == 'r8' and b[0] == 'r8':
            if a[1] == 6 and b[1] == 6:
                raise AsmError('ld (hl),(hl)')
            return [0x40 | a[1] << 3 | b[1]]
        # IXH/IXL forms
        if a[0] == 'xh' and b[0] == 'r8' and b[1] not in (4, 5, 6):
            return [a[1], 0x40 | a[2] << 3 | b[1]]
        if b[0] == 'xh' and a[0] == 'r8' and a[1] not in (4, 5, 6):
            return [b[1], 0x40 | a[1] << 3 | b[2]]
        if a[0] == 'xh' and b[0] == 'xh' and a[1] == b[1]:
            return [a[1], 0x40 | a[2] << 3 | b[2]]
        if a[0] == 'xh' and b[0] == 'imm':
            return [a[1], 0x06 | a[2] << 3, self.n8(b[1])]
        if a[0] == 'r8' and b[0] == 'imm':
            return [0x06 | a[1] << 3, self.n8(b[1])]
        if a[0] == 'r8' and a[1] != 6 and b[0] == 'ix':
            return [b[1], 0x46 | a[1] << 3, self.d8(b[2])]
        if a[0] == 'ix' and b[0] == 'r8' and b[1] != 6:
            return [a[1], 0x70 | b[1], self.d8(a[2])]
        if a[0] == 'ix' and b[0] == 'imm':
            return [a[1], 0x36, self.d8(a[2]), self.n8(b[1])]
        if a == ('r8', 7) and b[0] == 'indr' and b[1] in ('BC', 'DE'):
            return [0x0A if b[1] == 'BC' else 0x1A]
        if b == ('r8', 7) and a[0] == 'indr' and a[1] in ('BC', 'DE'):
            return [0x02 if a[1] == 'BC' else 0x12]
        if a == ('r8', 7) and b[0] == 'ind':
            return [0x3A] + self.n16(b[1])
        if b == ('r8', 7) and a[0] == 'ind':
            return [0x32] + self.n16(a[1])
        if a == ('r8', 7) and b[0] == 'ir':
            return [0xED, 0x57 if b[1] == 'I' else 0x5F]
        if b == ('r8', 7) and a[0] == 'ir':
            return [0xED, 0x47 if a[1] == 'I' else 0x4F]
        if a[0] == 'rp' and a[1] in RP and b[0] == 'imm':
            return [0x01 | RP[a[1]] << 4] + self.n16(b[1])
        if a[0] == 'xr' and b[0] == 'imm':
            return [a[1], 0x21] + self.n16(b[1])
        if a == ('rp', 'HL') and b[0] == 'ind':
            return [0x2A] + self.n16(b[1])
        if b == ('rp', 'HL') and a[0] == 'ind':
            return [0x22] + self.n16(a[1])
        if a[0] == 'xr' and b[0] == 'ind':
            return [a[1], 0x2A] + self.n16(b[1])
        if b[0] == 'xr' and a[0] == 'ind':
            return [b[1], 0x22] + self.n16(a[1])
        if a[0] == 'rp' and a[1] in RP and b[0] == 'ind':
            return [0xED, 0x4B | RP[a[1]] << 4] + self.n16(b[1])
        if b[0] == 'rp' and b[1] in RP and a[0] == 'ind':
            return [0xED, 0x43 | RP[b[1]] << 4] + self.n16(a[1])
        if a == ('rp', 'SP') and b == ('rp', 'HL'):
            return [0xF9]
        if a == ('rp', 'SP') and b[0] == 'xr':
            return [b[1], 0xF9]
        raise AsmError('cannot encode LD %s' % ', '.join(ops))

    # ------------------------------------------------------------ driver
    @staticmethod
    def splitops(t):
        out = []
        cur = ''
        q = None
        depth = 0
        i = 0
        while i < len(t):
            ch = t[i]
            if q:
                cur += ch
                if ch == q:
                    q = None
            elif ch == '"' or (ch == "'" and i + 2 < len(t) and t[i + 2] == "'"):
                q = ch
                cur += ch
            elif ch == '(':
                depth += 1
                cur += ch
            elif ch == ')':
                depth -= 1
                cur += ch
            elif ch == ',' and depth == 0:
                out.append(cur.strip())
                cur = ''
            else:
                cur += ch
            i += 1
        if cur.strip():
            out.append(cur.strip())
        return out

    @staticmethod
    def strip_comment(line):
        q = None
        out = ''
        for i, ch in enumerate(line):
            if q:
                if ch == q:
                    q = None
            elif ch == '"':
                q = ch
            elif ch == "'" and i + 2 < len(line) and line[i + 2] == "'":
                q = None
                out += line[i:i + 3]
                continue
            elif ch == ';':
                break
            out += ch
        return out.rstrip()

    def emit(self, bs):
        for x in bs:
            o = (self.pc + self.delta) & 0xFFFF
            if self.final and o in self.out:
                raise AsmError('overlapping output at %04X' % o)
            self.out[o] = x & 0xFF
            self.pc += 1

    def load(self, path):
        lines = []
        with open(path, encoding='utf-8-sig') as f:
            for n, raw in enumerate(f.read().split('\n'), 1):
                m = re.match(r'^\s*include\s+"([^"]+)"', raw, re.I)
                if m:
                    inc = os.path.join(os.path.dirname(path), m.group(1))
                    lines.extend(self.load(inc))
                else:
                    lines.append((path, n, raw))
        return lines

    def run_pass(self, lines, final):
        self.final = final
        self.pc = 0
        self.delta = 0          # output address - logical address (PHASE)
        self.out = {}
        self.scope = 'top'
        self.defined_this_pass = set()
        self.redefinable = set()
        for path, n, raw in lines:
            try:
                self.line(raw)
            except (AsmError, KeyError, ValueError, SyntaxError, TypeError, IndexError) as e:
                raise AsmError('%s:%d: %s\n    %s' % (os.path.basename(path), n, e, raw.strip()))

    def line(self, raw):
        t = self.strip_comment(raw)
        if not t.strip():
            return
        m = re.match(r'^\s*([A-Za-z_]\w*)\s*(?:equ|EQU|Equ|=)\s*(.+)$', t)
        if m:
            self.define(m.group(1), self.ev(m.group(2)))
            return
        m = re.match(r'^\s*(\.?[A-Za-z_]\w*):(.*)$', t)
        if m:
            name = m.group(1)
            if not name.startswith('.'):
                self.scope = name
            self.define(self.label_name(name), self.pc)
            t = m.group(2)
            if not t.strip():
                return
        t = t.strip()
        parts = t.split(None, 1)
        mn = parts[0].upper()
        rest = parts[1] if len(parts) > 1 else ''
        ops = self.splitops(rest) if rest else []
        if mn == 'ORG':
            self.pc = self.ev(rest)
            self.delta = 0
        elif mn == 'PHASE':         # assemble for another run address, keep output here
            target = self.ev(rest)
            self.delta = self.pc + self.delta - target
            self.pc = target
        elif mn == 'DEPHASE':
            self.pc = self.pc + self.delta
            self.delta = 0
        elif mn == 'ALIGN':
            a = self.ev(rest)
            while self.pc % a:
                self.emit([0])
        elif mn in ('DS', 'DEFS'):
            cnt = self.ev(ops[0])
            fill = self.ev(ops[1]) if len(ops) > 1 else 0
            self.emit([fill] * cnt)
        elif mn in ('DB', 'DEFB', 'DEFM'):
            for o in ops:
                if o.startswith('"'):
                    self.emit([ord(c) for c in o[1:-1]])
                else:
                    self.emit([self.n8(o)])
        elif mn in ('DW', 'DEFW'):
            for o in ops:
                self.emit(self.n16(o))
        elif mn == 'DSC':
            s = rest.strip()
            self.emit([dispcode(c) for c in s[1:-1]])
        elif mn == 'ASSERT':
            if self.final and not self.ev(rest):
                raise AsmError('assertion failed: ' + rest)
        else:
            self.emit(self.enc(mn, ops))


def assemble_file(path):
    a = Asm(os.path.dirname(path))
    lines = a.load(path)
    for _ in range(3):
        a.run_pass(lines, False)
    a.run_pass(lines, True)
    lo = min(a.out)
    hi = max(a.out)
    data = bytes(a.out.get(i, 0) for i in range(lo, hi + 1))
    return lo, data, a.sym


if __name__ == '__main__':
    lo, data, sym = assemble_file(sys.argv[1])
    print('assembled %d bytes at %04X' % (len(data), lo))
