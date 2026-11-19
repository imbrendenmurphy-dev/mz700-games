"""world.py - the world of SKINK: region maps, transporter links, switches.

Maps are drawn as 22 rows of 30 characters (the interior); the build adds
the steel border.  Legend:

    ' ' space      '.' earth      '#' wall       '(' ')' curved walls
    '%' secret wall (looks like wall, can be dug)    '$' steel
    'O' rock       'e' egg        'M' monster    '<' '^' '>' 'v' spirit
    '*' gem        '+' mosaic piece   'W' crown   'K' key   'S' safe
    'C' cage       'X' skulls     'f' fungus     '"' decoration
    '|' barrier    '=' switch     'G' sun gate   '0'-'9' transporters
    'P' start (first region only)
"""
from engine import W, H, RSZ
from tiles import E, ELEMS

LEGEND = {
    ' ': 'SPACE', '.': 'EARTH', '#': 'WALL', '(': 'CURVL', ')': 'CURVR', '%': 'SECRET',
    '$': 'STEEL', 'O': 'ROCK', 'e': 'EGG', 'M': 'MONSTER', '<': 'SPIRIT0', '^': 'SPIRIT1',
    '>': 'SPIRIT2', 'v': 'SPIRIT3', '*': 'GEM', '+': 'PIECE', 'W': 'CROWN', 'K': 'KEY',
    'S': 'SAFE', 'C': 'CAGE', 'X': 'SKULL', 'f': 'FUNGUS', '"': 'DECOR', '|': 'BARRIER',
    '=': 'SWITCH', 'G': 'GATE',
}
CHAR = {v: k for k, v in LEGEND.items()}
CHAR.update({'TRANS': 'T', 'PLAYER': 'P', 'ROCKF': 'o', 'EGGF': 'e', 'HATCH1': 'h', 'HATCH2': 'h',
             'HATCH3': 'h', 'SWITCHON': '/', 'COVER': '?', 'SPACE': ' '})


class Region:
    def __init__(self, key, name, theme, rows, hint=''):
        self.key, self.name, self.theme, self.hint = key, name, theme, hint
        assert len(rows) == H - 2, (key, len(rows))
        self.rows = rows
        self.cells = [E['STEEL']] * RSZ
        self.trans = {}             # digit -> pos
        self.start = None
        for y, row in enumerate(rows):
            assert len(row) == W - 2, (key, y, len(row), row)
            for x, ch in enumerate(row):
                p = (y + 1) * W + x + 1
                if ch.isdigit():
                    assert ch not in self.trans, (key, ch)
                    self.trans[ch] = p
                    self.cells[p] = E['TRANS']
                elif ch == 'P':
                    self.start = p
                    self.cells[p] = E['SPACE']
                else:
                    self.cells[p] = E[LEGEND[ch]]

    def arrival(self, digit):
        """the cell next to transporter `digit` where a traveller arrives"""
        p = self.trans[digit]
        for d in (W, 1, -1, -W):
            if self.cells[p + d] in (E['SPACE'], E['EARTH']):
                return p + d
        raise AssertionError('transporter %s%s has no free side' % (self.key, digit))


class Trans:
    def __init__(self, region, pos, dregion, dpos):
        self.region, self.pos, self.dregion, self.dpos = region, pos, dregion, dpos


class Switch:
    def __init__(self, region, pos, target, rect):
        self.region, self.pos, self.target = region, pos, target
        self.x1, self.y1, self.x2, self.y2 = rect


class World:
    def __init__(self, regions, links, switches):
        """links: (key, digit, key, digit[, 'one']) - two-way unless 'one'.
        switches: (key, n, target key, (x, y)) - the n-th switch (reading order) of
        region `key` opens the barrier group containing (x, y) of the target
        (interior coordinates, as in the map strings)."""
        self.regions = regions
        self.idx = {r.key: i for i, r in enumerate(regions)}
        self.start_region = 0
        self.start_pos = regions[0].start
        assert self.start_pos is not None
        self.trans = []
        used = set()
        for ln in links:
            a, da, b, db = ln[:4]
            pairs = [(a, da, b, db)] if 'one' in ln[4:] else [(a, da, b, db), (b, db, a, da)]
            for (s, ds, t, dt) in pairs:
                rs, rt = self.idx[s], self.idx[t]
                assert (rs, ds) not in used, (s, ds)
                used.add((rs, ds))
                self.trans.append(Trans(rs, regions[rs].trans[ds], rt, regions[rt].arrival(dt)))
        for i, r in enumerate(regions):
            for d in r.trans:
                assert (i, d) in used, 'transporter %s%s goes nowhere' % (r.key, d)
        self.switches = []
        for key, n, tkey, (x, y) in switches:
            r = regions[self.idx[key]]
            sws = [p for p in range(RSZ) if r.cells[p] == E['SWITCH']]
            pos = sws[n]
            t = regions[self.idx[tkey]]
            rect = barrier_group(t, (y + 1) * W + x + 1)
            self.switches.append(Switch(self.idx[key], pos, self.idx[tkey], rect))
        for i, r in enumerate(regions):
            n = sum(1 for p in range(RSZ) if r.cells[p] == E['SWITCH'])
            assert n == sum(1 for s in self.switches if s.region == i), 'switch count ' + r.key

    def trans_at(self, region, pos):
        for t in self.trans:
            if t.region == region and t.pos == pos:
                return t
        raise KeyError((region, pos))

    def switch_at(self, region, pos):
        for i, s in enumerate(self.switches):
            if s.region == region and s.pos == pos:
                return i, s
        raise KeyError((region, pos))


def barrier_group(r, p):
    assert r.cells[p] == E['BARRIER'], (r.key, p % W - 1, p // W - 1)
    seen = {p}
    todo = [p]
    while todo:
        q = todo.pop()
        for d in (1, -1, W, -W):
            n = q + d
            if n not in seen and r.cells[n] == E['BARRIER']:
                seen.add(n)
                todo.append(n)
    xs = [q % W for q in seen]
    ys = [q // W for q in seen]
    rect = (min(xs), min(ys), max(xs), max(ys))
    for y in range(rect[1], rect[3] + 1):
        for x in range(rect[0], rect[2] + 1):
            q = y * W + x
            assert r.cells[q] != E['BARRIER'] or q in seen, 'barrier groups overlap in ' + r.key
    return rect


def load():
    import regions as R
    return World(R.REGIONS, R.LINKS, R.SWITCHES)
