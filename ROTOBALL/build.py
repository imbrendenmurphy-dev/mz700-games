"""build.py - builds Rotoball for the Sharp MZ-700.

    py build.py

Produces build/ROTOBALL.MZF (for UniCMT / real hardware) and an identical
build/ROTOBALL.MZT (the extension MZ700WIN's File > Open expects).
"""
import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import gen_data  # noqa: E402
from zasm import assemble_file, AsmError  # noqa: E402

NAME = 'ROTOBALL'


def mzf(name, load, data, exe):
    hdr = bytearray(128)
    hdr[0] = 0x01                                   # OBJ (machine code)
    fn = name.encode('ascii')[:16] + b'\x0d'
    hdr[1:1 + len(fn)] = fn
    for i in range(1 + len(fn), 18):
        hdr[i] = 0x0d
    struct.pack_into('<HHH', hdr, 18, len(data), load, exe)
    return bytes(hdr) + data


def main():
    gen_data.main()
    try:
        load, data, sym = assemble_file(os.path.join(ROOT, 'src', 'rotoball.asm'))
    except AsmError as e:
        sys.exit('assembly failed:\n%s' % e)
    exe = sym['start']
    out = mzf(NAME, load, data, exe)
    bdir = os.path.join(ROOT, 'build')
    rdir = os.path.join(ROOT, 'release')
    os.makedirs(rdir, exist_ok=True)
    for d in (bdir, rdir):
        for ext in ('MZF', 'MZT'):
            with open(os.path.join(d, NAME + '.' + ext), 'wb') as f:
                f.write(out)
    with open(os.path.join(bdir, 'rotoball.sym'), 'w') as f:
        for k, v in sorted(sym.items(), key=lambda kv: kv[1]):
            if not k.startswith('_L_'):
                f.write('%-16s %04X\n' % (k, v))
    print('ROTOBALL: load %04X  exec %04X  size %d bytes (ends %04X)' %
          (load, exe, len(data), load + len(data) - 1))


if __name__ == '__main__':
    main()
