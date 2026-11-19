"""rooms.py - room maps, levels and their binary encoding.

A room is 40 x 23 cells (screen rows 2-24).  Maps are drawn in ASCII:

  tiles      ' ' sky   '#' ground (auto top/fill)   'F' fake ground (secret)
             'B' block  'H' brick  '=' one-way plank  '^' spikes  'v' ceiling spikes
             '|' vine   'o' gem    'a' apple   '1' extra life   '$' golden star
             'S' spring '~' liquid surface  'w' liquid  'C' crumbling block
             'r' 'g' 'b' chroma blocks (solid only while Kiko has that colour)
  decor      per world, see DECOR (lower case letters and a few symbols)
  objects    'K' Kiko (level start)   'E' walker   'Z' flyer   'J' hopper
             'Y' spiky walker  'L' bat  'U' spitter  'D' dropper
             'I' 'V' 'A' inkblot red / green / blue   'M' moving platform (left end;
             ':' marks its travel limits on the same row)  'N' lift (vertical
             platform; ':' marks limits in the same column)  'G' goal prism  'O' boss

An object letter's cell is the object's (x, y): x = left column of its hit
box, y = bottom row.
"""
import tiles as TL

W, H = 40, 23

OBJ_TYPES = ['NONE', 'WALKER', 'FLYER', 'HOPPER', 'SPIKY', 'BAT', 'SPITTER', 'DROPPER',
             'INK', 'PLATH', 'PLATV', 'GOAL', 'BOSS', 'SHOT', 'FX', 'STALAC']
OT = {n: i for i, n in enumerate(OBJ_TYPES)}
OBJ_LETTERS = {'E': 'WALKER', 'Z': 'FLYER', 'J': 'HOPPER', 'Y': 'SPIKY', 'L': 'BAT',
               'U': 'SPITTER', 'D': 'DROPPER', 'I': 'INK', 'V': 'INK', 'A': 'INK',
               'M': 'PLATH', 'N': 'PLATV', 'G': 'GOAL', 'O': 'BOSS'}
INK_COLOUR = {'I': 2, 'V': 4, 'A': 1}

BASE = {' ': 'sky', 'B': 'block', 'H': 'brick', '=': 'plank', '^': 'spike', 'v': 'cspike',
        '|': 'vine', 'o': 'gem0', 'a': 'apple', '1': 'oneup', '$': 'golden', 'S': 'spring',
        '~': 'water', 'w': 'deep', 'C': 'crumble', 'F': 'fake',
        'r': 'ghost_R', 'g': 'ghost_G', 'b': 'ghost_B', ':': 'sky', 'K': 'sky'}

DECOR = {
    'W1': {'*': 'flower', '+': 'flower2', 'f': 'bush', '"': 'grass', 'm': 'mush', 'n': 'fence',
           'p': 'post', 's': 'sign', 'u': 'sun'},
    'W2': {'*': 'crystal', '+': 'crystal2', 'l': 'stalag', 'm': 'mush', 't': 'torch', 'x': 'bones',
           'n': 'rail', 'd': 'drip', '/': 'rock_l', '\\': 'rock_r'},
    'W3': {'*': 'star', 'q': 'gear', 'n': 'chain', 'k': 'bird', 'P': 'pipe'},
    'W4': {'q': 'window', 'Q': 'window2', 'k': 'banner', 'n': 'chain', 't': 'torch', 'P': 'pillar',
           'm': 'moon', '*': 'star', 'c': 'crown'},
}

# multi-cell decorations: letter -> rows of tile names (None = leave alone);
# drawn with the letter's cell as the top-left corner, only over sky
STAMPS = {
    'W1': {
        'c': [[None, 'cloud_dome', 'cloud_ball', 'cloud_dome', None],
              ['cloud_l', 'cloud_full', 'cloud_full', 'cloud_full', 'cloud_r']],
        't': [[None, 'leaf_dome', 'leaf_dome', None],
              ['leaf_l', 'leaf', 'leaf', 'leaf_r'],
              [None, 'leaf_bowl', 'leaf_bowl', None],
              'TRUNK'],
        'h': [[None, 'hill_l', 'hill_r', None],
              ['hill_l', 'hill', 'hill', 'hill_r']],
    },
    'W3': {
        'c': [[None, 'cloud_dome', 'cloud_ball', 'cloud_dome', None],
              ['cloud_l', 'cloud_full', 'cloud_full', 'cloud_full', 'cloud_r']],
    },
    'W2': {}, 'W4': {},
}
TRUNK = [None, 'trunk_r', 'trunk', None]


class Room:
    def __init__(self, name, world, text):
        self.name = name
        self.world = world
        rows = text.strip('\n').split('\n')
        # maps are anchored at the bottom: missing rows at the top are sky
        assert len(rows) <= H, (name, len(rows))
        rows = [''] * (H - len(rows)) + rows
        for i, r in enumerate(rows):
            assert len(r) <= W, (name, i, len(r), r)
        self.rows = [r.ljust(W) for r in rows]
        self.exits = [0xFF] * 4          # left, right, up, down
        self.index = None
        self.build()

    def ch(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.rows[y][x]
        return '#'

    def build(self):
        w = self.world
        sky = TL.tid(w, 'sky')
        T = [[sky] * W for _ in range(H)]
        self.objs = []
        self.start = None
        decor = DECOR[w]
        stamps = STAMPS[w]
        pending = []
        for y in range(H):
            for x in range(W):
                c = self.rows[y][x]
                if c == '#':
                    up = self.ch(x, y - 1)
                    T[y][x] = TL.tid(w, 'top' if (y > 0 and up not in '#F') else 'fill')
                elif c in OBJ_LETTERS and c not in decor:
                    self.objs.append((c, x, y))
                elif c in decor:
                    T[y][x] = TL.tid(w, decor[c])
                elif c in stamps:
                    pending.append((c, x, y))
                elif c in BASE:
                    if c == 'K':
                        self.start = (x, y)
                    T[y][x] = TL.tid(w, BASE[c])
                else:
                    raise ValueError('%s: unknown map char %r at %d,%d' % (self.name, c, x, y))
        for c, x, y in pending:
            rows = stamps[c]
            for dy, row in enumerate(rows):
                if row == 'TRUNK':
                    yy = y + dy
                    while yy < H and self.rows[yy][x + 1] in ' t':
                        for dx, nm in enumerate(TRUNK):
                            if nm and T[yy][x + dx] == sky:
                                T[yy][x + dx] = TL.tid(w, nm)
                        yy += 1
                    break
                for dx, nm in enumerate(row):
                    xx, yy = x + dx, y + dy
                    if nm and 0 <= xx < W and 0 <= yy < H and T[yy][xx] == sky \
                            and self.rows[yy][xx] in ' ' + c:
                        T[yy][xx] = TL.tid(w, nm)
        self.T = T
        # objects -> records (type, x, y, p1, p2)
        recs = []
        for c, x, y in self.objs:
            t = OBJ_LETTERS[c]
            p1 = p2 = 0
            if t == 'INK':
                p1 = INK_COLOUR[c]
            elif t == 'PLATH':
                lo, hi = x, x
                row = self.rows[y]
                for xx in range(x - 1, -1, -1):
                    if row[xx] == ':':
                        lo = xx
                        break
                for xx in range(x + 1, W):
                    if row[xx] == ':':
                        hi = xx - 3           # left end limit: platform is 4 wide
                        break
                assert lo < hi or lo == x, (self.name, 'platform limits')
                p1, p2 = lo, max(hi, x)
            elif t == 'PLATV':
                lo, hi = y, y
                for yy in range(y - 1, -1, -1):
                    if self.rows[yy][x] == ':':
                        lo = yy
                        break
                for yy in range(y + 1, H):
                    if self.rows[yy][x] == ':':
                        hi = yy
                        break
                p1, p2 = lo, hi
            recs.append((OT[t], x, y, p1, p2))
        self.recs = recs

    def gems(self):
        """cells (in scan order) that count against the level's pickup bitmap"""
        out = []
        for y in range(H):
            for x in range(W):
                f = TL.TILES[self.T[y][x]].flags
                if f & (TL.F_GEM | TL.F_ITEM):
                    out.append((x, y))
        return out

    def rle(self):
        flat = [t for row in self.T for t in row]
        assert max(flat) < 0xFF
        out = []
        i = 0
        while i < len(flat):
            j = i
            while j < len(flat) and flat[j] == flat[i] and j - i < 255:
                j += 1
            n = j - i
            if n >= 3:
                out += [0xFF, n, flat[i]]
            else:
                out += flat[i:j]
            i = j
        return out


class Level:
    """layout: rows of room keys ('.' = nothing); neighbours are linked"""
    def __init__(self, code, name, world, song, layout, rooms, boss=False, hint=''):
        self.code = code
        self.hint = hint
        self.name = name
        self.world = world
        self.song = song
        self.boss = boss
        self.rooms = []
        grid = [ln.split() for ln in layout.strip().split('\n')]
        pos = {}
        for y, row in enumerate(grid):
            for x, k in enumerate(row):
                if k != '.':
                    pos[k] = (x, y)
        self.byname = {}
        for k in sorted(pos, key=lambda k: (pos[k][1], pos[k][0])):
            r = Room('%s.%s' % (code, k), world, rooms[k])
            r.key = k
            self.rooms.append(r)
            self.byname[k] = r
        self.pos = pos
        self.grid = grid
        starts = [r for r in self.rooms if r.start]
        assert len(starts) == 1, (code, 'needs exactly one K')
        self.first = starts[0]

    def link(self):
        inv = {v: k for k, v in self.pos.items()}
        for k, (x, y) in self.pos.items():
            r = self.byname[k]
            for i, (dx, dy) in enumerate(((-1, 0), (1, 0), (0, -1), (0, 1))):
                n = inv.get((x + dx, y + dy))
                if n:
                    r.exits[i] = self.byname[n].index
