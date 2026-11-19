"""sprites.py - every animation frame in the game, as cell art.

Frames are written facing RIGHT; left-facing copies are mirrored glyph by
glyph (celart.MIRROR plus the overrides below).  Each frame has an origin:
the cell that sits on the object's (x, y), where y is the bottom row of
its hit box.  Frame binary (gen_sprites.inc):

    db w, h, ox, oy            ox/oy: signed offset of the top-left cell
    db ch, at  x (w*h)         at bit 3 = transparent background;
                               ch = 0 and at = 0 = cell not drawn
"""
import celart as ca

MIRROR_OVERRIDE = {0x165: 0x168, 0x168: 0x165, 0x166: 0x167, 0x167: 0x166,
                   0x1F5: 0x1F5, 0x1F6: 0x1F6, 0x1B3: 0x1B3, 0x16A: 0x16A}

# name -> (art, ox, oy, mirror?)
FRAMES = {}


def F(name, art, ox, oy, mirror=True):
    FRAMES[name] = (ca.parse(art), ox, oy, mirror)


# ------------------------------------------------------------------ Kiko
# hit box: 2 wide x 3 tall; art 4 wide (tail at -1, snout at +2)
HEAD = '.      1A5:G   189:W/K   1BF:G'
BODY = '165:G  043:G   043:G     .'
F('K_STAND', HEAD + '\n' + BODY + '\n.      147:G   147:G     .', -1, -2)
F('K_BLINK', '.      1A5:G   07A:G/W   1BF:G\n' + BODY + '\n.      147:G   147:G     .', -1, -2)
F('K_SLEEP', '.      1A5:G   043:G     1BF:G\n' + BODY + '\n.      147:G   147:G     .', -1, -2)
F('K_RUN1', HEAD + '\n' + BODY + '\n.      148:G   146:G     .', -1, -2)
F('K_RUN2', HEAD + '\n166:G  043:G   043:G     .\n.      147:G   147:G     .', -1, -2)
F('K_RUN3', HEAD + '\n' + BODY + '\n.      146:G   148:G     .', -1, -2)
F('K_JUMP', HEAD + '\n' + BODY + '\n.      1BE:G   1BE:G     .', -1, -2)
F('K_FALL', '.      1A5:G   18B:W/K   1BF:G\n' + BODY + '\n.      146:G   148:G     .', -1, -2)
F('K_SQUASH', '.      .       .         .\n' + HEAD + '\n165:G  043:G   043:G     .', -1, -2)
F('K_TONGUE', '.      1A5:G   189:W/K   07A:G/M\n' + BODY + '\n.      147:G   147:G     .', -1, -2)
F('K_CLIMB1', '.      1A5:G   189:W/K   1BF:G\n.      043:G   043:G     .\n.      148:G   148:G     .', -1, -2)
F('K_CLIMB2', '.      1A5:G   189:W/K   1BF:G\n.      043:G   043:G     .\n.      146:G   146:G     .', -1, -2)
F('K_HURT', '.      1A5:G   18B:W/K   07A:G/M\n' + BODY + '\n.      146:G   148:G     .', -1, -2)
F('K_WIN', '.      1A5:G   0E3:K/W   1BF:G\n' + BODY + '\n.      1BE:G   1BE:G     .', -1, -2)
F('K_DEAD', '.      1A5:G   165:K/W   07A:G/M\n' + BODY + '\n.      146:G   148:G     .', -1, -2)
# tongue pieces (1 cell): shaft and tip, drawn level with the snout
F('TONGUE', '03E:M', 0, 0, mirror=False)
F('TONGUE_TIP', '13E:M', 0, 0, mirror=False)

# ------------------------------------------------------------------ W1 enemies
# Ladybop: 2x1 walker (red shell, black head)
F('LADY1', '1C0:R  13E:R   1BF:K', 0, 0)
F('LADY2', '1C0:R  1B2:R/K  1BF:K', 0, 0)
# Buzzbee: 1x1 flyer, wings flap
F('BEE1', '1F7:Y', 0, 0)
F('BEE2', '1F8:Y', 0, 0)
# Boinger (frog): 2x2 hopper
F('FROG1', '189:W/K 189:W/K\n14B:G   14B:G', 0, -1)
F('FROG2', '189:W/K 189:W/K\n146:G   148:G', 0, -1)
# Spikeshell: 2x1, can't be stomped
F('SNAIL1', '16D:W  165:M   1BF:Y', 0, 0)
F('SNAIL2', '16D:W  166:M   1BF:Y', 0, 0)

# ------------------------------------------------------------------ W2 enemies
F('BAT1', '1BB:M  189:W/K  1BC:M', 0, 0)
F('BAT2', '1BC:M  189:W/K  1BB:M', 0, 0)
F('BATHANG', '16F:M  189:W/K  16F:M', 0, 0, mirror=False)
F('ROCKY1', '1C0:R  13E:R   1BF:R', 0, 0)        # rolling rock walker
F('ROCKY2', '1C0:R  1B2:R/Y  1BF:R', 0, 0)
F('SPIT1', '1BD:Y\n043:R', 0, -1)                # fire spitter turret
F('SPIT2', '1BD:R\n043:R', 0, -1)
F('FIREBALL1', '13E:Y', 0, 0)
F('FIREBALL2', '1B3:R', 0, 0)
F('STALAC', '16F:W', 0, 0, mirror=False)          # dropping stalactite
F('EMBER1', '1F7:R', 0, 0)
F('EMBER2', '1F8:Y', 0, 0)

# ------------------------------------------------------------------ W3 enemies
F('COG1', '18F:Y  18F:Y', 0, 0)
F('COG2', '18E:Y  18E:Y', 0, 0)
F('BIRD1', '18C:M  1BB:W', 0, 0)
F('BIRD2', '18C:M  1BC:W', 0, 0)
# inkblots: drawn in green, recoloured to their own colour at run time
F('INK1', '1BD:G   1BD:G\n189:W/G 189:W/G\n1BE:G   1BE:G', 0, -2)
F('INK2', '1BD:G   1BD:G\n189:W/G 189:W/G\n146:G   148:G', 0, -2)
F('SPARK1', '1B3:Y', 0, 0)
F('SPARK2', '1B3:W', 0, 0)

# ------------------------------------------------------------------ W4 enemies
F('KNIGHT1', '1C5:W  .\n18B:W/K 05A:W\n147:W  .', 0, -2)
F('KNIGHT2', '1C5:W  .\n18B:W/K 05A:W\n146:W  .', 0, -2)
F('GHOST1', '1BD:W   1BD:W\n189:K/W 189:K/W\n0EF:W   0EF:W', 0, -2)
F('GHOST2', '1BD:W   1BD:W\n189:K/W 189:K/W\n0D0:W   0D0:W', 0, -2)

# ------------------------------------------------------------------ props
F('PLAT', '07A:W  07A:W  07A:W  07A:W', 0, 0, mirror=False)   # recoloured per world
F('PRISM1', '.      1BD:W  .\n1A5:R  043:G  1A1:B\n.      1BE:Y  .', 0, -2, mirror=False)
F('PRISM2', '.      1BD:Y  .\n1A5:M  043:C  1A1:R\n.      1BE:W  .', 0, -2, mirror=False)
F('POOF1', '1B3:W', 0, 0, mirror=False)
F('POOF2', '06B:Y', 0, 0, mirror=False)
F('POP', '0F6:W', 0, 0, mirror=False)
F('SCORE100', '021:W  020:W  020:W', 0, 0, mirror=False)
F('ZZZ', '01A:W', 0, 0, mirror=False)
F('HEART', '053:R', 0, 0, mirror=False)

# ------------------------------------------------------------------ bosses
# W1: Big Bumble, giant beetle (6 x 4)
F('BB_WALK1', """
.      1A5:R   043:R    043:R    1A1:R   .
1A5:R  043:R   13E:K/R  043:R    043:R   1BF:K
043:R  043:R   043:R    13E:K/R  043:R   189:W/K
.      146:K   146:K    148:K    148:K   .
""", 0, -3)
F('BB_WALK2', """
.      1A5:R   043:R    043:R    1A1:R   .
1A5:R  043:R   13E:K/R  043:R    043:R   1BF:K
043:R  043:R   043:R    13E:K/R  043:R   189:W/K
.      148:K   146:K    146:K    148:K   .
""", 0, -3)
F('BB_DIZZY', """
.      1A5:R   043:R    043:R    1A1:R   1B3:Y
1A5:R  043:R   13E:K/R  043:R    043:R   1BF:K
043:R  043:R   043:R    13E:K/R  043:R   165:W/K
.      1BE:K   1BE:K    1BE:K    1BE:K   .
""", 0, -3)
# W2: Magma Mole (4 x 3)
F('MOLE1', """
1A5:M  043:M    043:M    1A1:M
043:M  189:W/K  189:W/K  043:M
1C0:M  07A:Y/M  07A:Y/M  1BF:M
""", 0, -2)
F('MOLE2', """
1A5:M  043:M    043:M    1A1:M
043:M  07A:M/W  07A:M/W  043:M
1C0:M  043:M    043:M    1BF:M
""", 0, -2)
# W3: Prism Phantom (5 x 4), recoloured at run time
F('PHANTOM1', """
.      1A5:G   043:G    1A1:G   .
1A5:G  189:W/K 043:G    189:W/K 1A1:G
043:G  043:G   07A:K/G  043:G   043:G
0EF:G  .       0EF:G    .       0EF:G
""", 0, -3, mirror=False)
F('PHANTOM2', """
.      1A5:G   043:G    1A1:G   .
1A5:G  189:W/K 043:G    189:W/K 1A1:G
043:G  043:G   07A:K/G  043:G   043:G
.      0EF:G   .        0EF:G   .
""", 0, -3, mirror=False)
# W4: Baron Greyscale (5 x 5), shield recoloured at run time
F('BARON1', """
.      1C5:Y   1C6:Y    .       .
1A5:W  043:W   043:W    1A1:W   .
043:W  189:W/K 189:W/K  043:W   .
0D0:W  0D0:W   0D0:W    0D0:W   1B2:G
147:W  .       .        147:W   .
""", 0, -4)
F('BARON2', """
.      1C5:Y   1C6:Y    .       .
1A5:W  043:W   043:W    1A1:W   .
043:W  07A:W/K 07A:W/K  043:W   .
0D0:W  0D0:W   0D0:W    0D0:W   1B2:G
146:W  .       .        148:W   .
""", 0, -4)


def frame_bytes(pic, ox, oy):
    h, w = len(pic), len(pic[0])
    out = [w, h, ox & 0xFF, oy & 0xFF]
    for row in pic:
        for c in row:
            if c is None:
                out += [0, 0]
            else:
                g, fg, bg = c
                at = ((g >> 8) << 7) | (fg << 4) | (8 if bg == ca.TR else bg)
                out += [g & 0xFF, at]
    return out


def all_frames():
    """[(asm name, bytes)] with _R and _L variants for mirrored frames"""
    out = []
    for name, (pic, ox, oy, mir) in FRAMES.items():
        if mir:
            w = len(pic[0])
            out.append((name + '_R', frame_bytes(pic, ox, oy)))
            # mirror about the hit box [0, hw): Kiko's box is 2 wide, every
            # other sprite's box is its art
            hw = 2 if name.startswith('K_') else w
            lpic = ca.mirror(pic, MIRROR_OVERRIDE)
            lox = hw - ox - w
            out.append((name + '_L', frame_bytes(lpic, lox, oy)))
        else:
            out.append((name, frame_bytes(pic, ox, oy)))
    return out


def preview(path, sky=1):
    pics = []
    for name, (pic, ox, oy, mir) in FRAMES.items():
        pics.append(pic)
        if mir:
            pics.append(ca.mirror(pic, MIRROR_OVERRIDE))
    ca.sheet(pics, sky=sky, cols=12, scale=3).save(path)


if __name__ == '__main__':
    import os
    import sys
    b = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build')
    preview(os.path.join(b, 'sprites_%s.png' % (sys.argv[1] if len(sys.argv) > 1 else '1')),
            int(sys.argv[1]) if len(sys.argv) > 1 else 1)

