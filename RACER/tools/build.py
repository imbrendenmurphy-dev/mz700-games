"""build.py - builds REDLINE for the Sharp MZ-700.

    py tools/build.py

Generates the data (gen.py, music.py), assembles src/main.asm with
sjasmplus and wraps the binary as release/NOVASTRM.MZT plus an identical
.MZF (UniCMT, emulators).
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
BUILD = os.path.join(ROOT, 'build')
SRC = os.path.join(ROOT, 'src')
REL = os.path.join(ROOT, 'release')
LOAD = 0x1200
NAME = 'REDLINE'
FILE = 'REDLINE'


def mzf(data, exe):
    hdr = bytearray(128)
    hdr[0] = 0x01
    fn = NAME.encode('ascii') + b'\x0d'
    hdr[1:1 + len(fn)] = fn
    for i in range(1 + len(fn), 18):
        hdr[i] = 0x0d
    hdr[18:20] = len(data).to_bytes(2, 'little')
    hdr[20:22] = LOAD.to_bytes(2, 'little')
    hdr[22:24] = exe.to_bytes(2, 'little')
    return bytes(hdr) + data


def main():
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(REL, exist_ok=True)
    for t in ('gen.py', 'music.py'):
        r = subprocess.run([sys.executable, os.path.join(HERE, t)], capture_output=True, text=True)
        if r.returncode:
            sys.exit(r.stdout + r.stderr)
    asm = os.path.join(HERE, 'sjasmplus', 'sjasmplus.exe')
    if not os.path.exists(asm):
        asm = shutil.which('sjasmplus') or sys.exit('needs sjasmplus')
    r = subprocess.run([asm, '--nologo', '--sym=../build/redline.sym', '--lst=../build/redline.lst',
                        'main.asm'], cwd=SRC, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    if out:
        print(out)
    if r.returncode:
        sys.exit('assembly failed')
    data = open(os.path.join(BUILD, 'redline.bin'), 'rb').read()
    img = mzf(data, LOAD)
    for ext in ('MZT', 'MZF'):
        open(os.path.join(REL, FILE + '.' + ext), 'wb').write(img)
    print('REDLINE: %d bytes, %04Xh-%04Xh' % (len(data), LOAD, LOAD + len(data) - 1))


if __name__ == '__main__':
    main()
