"""glyphs.py CODE... - print CG-ROM glyphs as ASCII art (codes in hex, +100 = bank 2)."""
import sys
import mzfont
codes = [int(c, 16) for c in sys.argv[1:]]
for i in range(0, len(codes), 8):
    grp = codes[i:i + 8]
    print('   '.join('%-8s' % ('%03X' % g) for g in grp))
    for y in range(8):
        print('   '.join(''.join('#' if b else '.' for b in mzfont.glyph_bits(g)[y]) for g in grp))
    print()
