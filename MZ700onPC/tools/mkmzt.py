"""mkmzt.py BIN OUT.MZT LOAD [EXEC] [NAME] - wrap a raw binary in a 128-byte MZ-700 tape header."""
import sys
b = open(sys.argv[1], 'rb').read()
load = int(sys.argv[3], 0)
exe = int(sys.argv[4], 0) if len(sys.argv) > 4 else load
name = (sys.argv[5] if len(sys.argv) > 5 else 'TEST').upper().encode()[:16]
h = bytearray(128)
h[0] = 1
h[1:1 + len(name)] = name
h[1 + len(name)] = 0x0D
h[0x12:0x14] = len(b).to_bytes(2, 'little')
h[0x14:0x16] = load.to_bytes(2, 'little')
h[0x16:0x18] = exe.to_bytes(2, 'little')
open(sys.argv[2], 'wb').write(bytes(h) + b)
