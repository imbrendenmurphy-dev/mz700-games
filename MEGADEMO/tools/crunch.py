"""crunch.py - a small LZ77 packer for MZ-700 tape files, unpacked by
src/stub.asm.

Stream format (unpacked forwards):
    00-7F n        n+1 literal bytes follow
    80-FE n lo hi  copy (n & 7F) + 3 bytes from (output - (hi:lo))
    FF             end
"""

MIN_MATCH = 3
MAX_MATCH = 0x7E + 3
MAX_LIT = 128


def pack(data, max_cands=128):
    n = len(data)
    heads = {}
    out = bytearray()
    lits = bytearray()

    def flush():
        i = 0
        while i < len(lits):
            k = min(MAX_LIT, len(lits) - i)
            out.append(k - 1)
            out.extend(lits[i:i + k])
            i += k
        lits.clear()

    def insert(p):
        if p + 3 <= n:
            heads.setdefault(bytes(data[p:p + 3]), []).append(p)

    i = 0
    while i < n:
        best_len, best_off = 0, 0
        if i + MIN_MATCH <= n:
            cands = heads.get(bytes(data[i:i + 3]), [])
            for p in reversed(cands[-max_cands:]):
                off = i - p
                if off > 0xFFFF:
                    break
                ln = 0
                while ln < MAX_MATCH and i + ln < n and data[p + ln] == data[i + ln]:
                    ln += 1
                if ln > best_len:
                    best_len, best_off = ln, off
                    if ln == MAX_MATCH:
                        break
        if best_len >= MIN_MATCH:
            flush()
            out.append(0x80 + best_len - 3)
            out.append(best_off & 0xFF)
            out.append(best_off >> 8)
            for k in range(best_len):
                insert(i + k)
            i += best_len
        else:
            lits.append(data[i])
            insert(i)
            i += 1
    flush()
    out.append(0xFF)
    return bytes(out)


def unpack(packed):
    out = bytearray()
    i = 0
    while True:
        t = packed[i]
        i += 1
        if t == 0xFF:
            return bytes(out)
        if t < 0x80:
            out += packed[i:i + t + 1]
            i += t + 1
        else:
            ln = (t & 0x7F) + 3
            off = packed[i] | packed[i + 1] << 8
            i += 2
            for _ in range(ln):
                out.append(out[-off])


def check_in_place(packed, out_start, in_start):
    """Unpacking forwards over the same memory: output must never pass input."""
    i = 0
    o = out_start
    while True:
        t = packed[i]
        i += 1
        if t == 0xFF:
            return True
        if t < 0x80:
            o += t + 1
            i += t + 1
        else:
            o += (t & 0x7F) + 3
            i += 2
        if o > in_start + i:
            return False
