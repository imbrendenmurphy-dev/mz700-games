"""mapdump.py - print the current zone from a RAM dump of LUMEN.

    py tools/mapdump.py test/ram.bin [build/lumen.sym]

The dump comes from mzemu's `dumpram FILE` (64K, as the CPU sees RAM).
Prints the 64 x 32 map with the player (@), creatures (letters by type:
a-z then A-Z), items (*) and a legend.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import defs  # noqa: E402
import content as C  # noqa: E402

CH = {'ROCK': ' ', 'WALL': '#', 'FLOOR': '.', 'FLOOR2': ',', 'DOOR': '+', 'OPEN': "'", 'LOCKED': 'L',
      'SEAL': 'S', 'WATER': '~', 'LAVA': '=', 'ICE': 'i', 'OBSIDIAN': ':', 'PILLAR': 'O', 'FUNGUS': 'f',
      'CRYSTAL': 'c', 'BRAZOFF': 'b', 'BRAZON': 'B', 'SCONCE': 'k', 'EXIT': '>', 'GATEP': 'G', 'GATEB': 'G',
      'GATEM': 'G', 'GATEL': 'G', 'GATEOPEN': '_', 'PLATE': '^', 'BOULDER': '0', 'PLATEB': '0',
      'LEVER': 'V', 'GATELO': '_', 'MIRRORA': '/', 'MIRRORB': '\\', 'EMITTER': 'e', 'TARGET': 't',
      'TARGETON': 'T', 'WEB': 'w', 'BOOKS': '|', 'ALTAR': 'A', 'STATUE': 's', 'CHEST': 'C', 'CHESTO': 'c',
      'FOUNTAIN': 'F', 'DRYFONT': 'F', 'BONES': ';', 'MOSS': ',', 'CARPET': '=', 'RUNE': 'r',
      'THRONE': 'T', 'TRAP': 'x', 'TRAPSEEN': 'x', 'ROOTS': ',', 'ANVIL': 'n', 'COFFIN': 'n',
      'COLTL': 'o', 'COLTR': 'o', 'COLBL': 'o', 'COLBR': 'o', 'COLMID': 'O', 'STATUEB': '!',
      'URNTL': 'U', 'URNTR': 'U', 'URNBL': 'u', 'URNBR': 'u',
      'PEDESTAL': '_', 'PEDLIT': 'Y', 'LDOOR': 'H', 'LDOPEN': 'h'}


def syms(path):
    out = {}
    for line in open(path):
        p = line.split()
        if len(p) >= 3 and p[1] == 'EQU':
            out[p[0].rstrip(':')] = int(p[2], 16)
    return out


def main(ram_path, sym_path):
    ram = open(ram_path, 'rb').read()
    s = syms(sym_path)
    grid = []
    for y in range(32):
        row = []
        for x in range(64):
            b = ram[y * 64 + x]
            t = b & 0x3F
            row.append(CH.get(defs.TILES[t][0], '?') if t < len(defs.TILES) else '?')
        grid.append(row)
    mons = []
    for i in range(24):
        r = ram[0xA800 + i * 8:0xA808 + i * 8]
        if r[0]:
            mons.append((r[0], r[1], r[2], r[3], r[4]))
            letter = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN'[r[0] - 1]
            grid[r[2]][r[1]] = letter
    items = []
    for i in range(24):
        r = ram[0xA8C0 + i * 4:0xA8C4 + i * 4]
        if r[0]:
            items.append(tuple(r))
            grid[r[2]][r[1]] = '*'
    px, py = ram[s['px']], ram[s['py']]
    grid[py][px] = '@'
    print('zone %d  player %d,%d  hp %d  turns %d' % (ram[s['zone']], px, py, ram[s['hp']],
                                                     ram[s['turns']] + 256 * ram[s['turns'] + 1]))
    for row in grid:
        print(''.join(row))
    for m in mons:
        print('mon %-10s at %2d,%2d hp %3d fl %02X' % (C.MONSTERS[m[0] - 1][0], m[1], m[2], m[3], m[4]))
    for it in items:
        print('item %-12s at %2d,%2d qty %d' % (C.ITEMS[it[0] - 1][0], it[1], it[2], it[3]))
    ex = s['zexits']
    z = ram[s['zone']]
    for k in range(3):
        e = ram[ex + z * 9 + k * 3:ex + z * 9 + k * 3 + 3]
        if e[0] != 0xFF:
            print('exit at %d,%d -> zone %d' % tuple(e))


if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, 'build', 'lumen.sym'))
