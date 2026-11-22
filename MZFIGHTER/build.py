"""build.py - builds the game for the Sharp MZ-700.

    py build.py [debug]

Generates build/gen_*.inc from tools/, assembles src/main.asm with sjasmplus,
packs program + high-RAM data behind a loader stub and writes NAME.MZT
(emulators) plus the identical NAME.MZF (UniCMT / real hardware) to build/
and release/.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.join(ROOT, 'tools')
BUILD = os.path.join(ROOT, 'build')
SRC = os.path.join(ROOT, 'src')
REL = os.path.join(ROOT, 'release')
sys.path.insert(0, TOOLS)

import gfx  # noqa: E402
import music  # noqa: E402
import text  # noqa: E402
import crunch  # noqa: E402
import fighters  # noqa: E402
import art  # noqa: E402
import stage  # noqa: E402

NAME = 'WORLDCLASH'          # file name
TAPE_NAME = 'WORLD CLASH'    # name in the tape header
LOAD = 0x1200


def mzf(name, load, data, exe):
    hdr = bytearray(128)
    hdr[0] = 0x01
    fn = name.encode('ascii')[:16] + b'\x0d'
    hdr[1:1 + len(fn)] = fn
    for i in range(1 + len(fn), 18):
        hdr[i] = 0x0d
    hdr[18:20] = len(data).to_bytes(2, 'little')
    hdr[20:22] = load.to_bytes(2, 'little')
    hdr[22:24] = exe.to_bytes(2, 'little')
    return bytes(hdr) + data


def main():
    debug = 'debug' in sys.argv[1:]
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(REL, exist_ok=True)

    def write(name, s):
        with open(os.path.join(BUILD, name), 'w', newline='\n') as f:
            f.write(s)

    lo, hi, total = gfx.generate(fighters.ROSTER)
    write('gen_gfx.inc', '\n'.join(lo) + '\n')
    write('gen_hi.inc', '\n'.join(hi) + '\n')
    write('gen_text.inc', text.gen_asm())
    write('gen_art.inc', '\n'.join(art.generate()) + '\n')
    sasm, stotal = stage.gen_asm()
    write('gen_stage.inc', sasm)
    write('gen_music.inc', music.gen_asm())
    asm = os.path.join(TOOLS, 'sjasmplus', 'sjasmplus.exe')
    args = [asm, '--nologo', '--msg=war', '--sym=../build/game.sym', '--lst=../build/game.lst']
    if debug:
        args.append('-DDEBUG')
    r = subprocess.run(args + ['main.asm'], cwd=SRC, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode:
        sys.exit('assembly failed')
    data = open(os.path.join(BUILD, 'MAIN.BIN'), 'rb').read()
    hdata = open(os.path.join(BUILD, 'HIGH.BIN'), 'rb').read()
    packed = crunch.pack(data)
    assert crunch.unpack(packed) == data
    assert crunch.check_in_place(packed, LOAD, 0xD000 - len(packed)), 'packed data overlaps'
    hpacked = crunch.pack(hdata)
    assert crunch.unpack(hpacked) == hdata
    with open(os.path.join(BUILD, 'main.pak'), 'wb') as f:
        f.write(packed)
    with open(os.path.join(BUILD, 'high.pak'), 'wb') as f:
        f.write(hpacked)
    r = subprocess.run([asm, '--nologo', '--msg=war', '--sym=../build/stub.sym', 'stub.asm'],
                       cwd=SRC, capture_output=True, text=True)
    sys.stdout.write(r.stdout + r.stderr)
    if r.returncode:
        sys.exit('stub assembly failed')
    tape = open(os.path.join(BUILD, 'stub.bin'), 'rb').read()
    out = mzf(TAPE_NAME, LOAD, tape, LOAD)
    dirs = (BUILD,) if debug else (BUILD, REL)
    for d in dirs:
        for ext in ('MZT', 'MZF'):
            with open(os.path.join(d, NAME + '.' + ext), 'wb') as f:
                f.write(out)
    print('%s: program %d bytes (%04X-%04X), high data %d (D000-%04X), tape %d bytes' % (
        NAME, len(data), LOAD, LOAD + len(data), len(hdata), 0xD000 + len(hdata), len(tape)))


if __name__ == '__main__':
    main()
