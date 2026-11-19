"""tiles.py - the room tile set: glyph, colours and gameplay flags.

Every room cell holds one tile id (0-255).  Three page-aligned tables in
the game (TCHR, TATR, TFLG) give the character, attribute and flags; TANIM
gives the tile the cell becomes on the next animation tick (itself if
static).  Tiles are defined per world (W1..W4) plus a common set.
"""
from celart import CL

F_SOLID = 0x01      # blocks movement on all sides
F_ONEWAY = 0x02     # can be stood on, jumped through from below
F_HURT = 0x04       # costs a heart (spikes, lava, goo)
F_VINE = 0x08       # climbable
F_GEM = 0x10        # colour drop: collect on touch
F_ITEM = 0x20       # other pickup (apple, 1up, golden gem): see tile id
F_SPRING = 0x40     # bounce
F_CRUMBLE = 0x80    # gives way when stood on (with F_SOLID)
F_DEADLY = F_HURT | F_CRUMBLE   # liquids: lose a life at once

WORLDS = ['W1', 'W2', 'W3', 'W4']
SKY = {'W1': 'B', 'W2': 'K', 'W3': 'C', 'W4': 'K'}


def a(fg, bg, bank=0):
    return (bank << 7) | (CL[fg] << 4) | CL[bg]


class Tile:
    def __init__(self, name, glyph, fg, bg, flags=0):
        self.name = name
        self.glyph = glyph
        self.fg, self.bg = fg, bg
        self.flags = flags
        self.anim = None            # name of the next tile in the cycle

    @property
    def ch(self):
        return self.glyph & 0xFF

    @property
    def at(self):
        return a(self.fg, self.bg, self.glyph >> 8)


TILES = []
INDEX = {}


def T(name, glyph, fg, bg, flags=0, anim=None):
    t = Tile(name, glyph, fg, bg, flags)
    t.anim = anim
    INDEX[name] = len(TILES)
    TILES.append(t)
    return t


# ---------------------------------------------------------------- common
# id 0 must be a harmless empty cell; each world has its own sky too.
T('void', 0x000, 'W', 'K')

for w in WORLDS:
    sky = SKY[w]
    T(w + '.sky', 0x000, 'W', sky)
    # chroma blocks: solid / ghost pairs in R G B order (must stay consecutive)
    for c in 'RGB':
        T('%s.chroma_%s' % (w, c), 0x043, c, sky, F_SOLID)
        T('%s.ghost_%s' % (w, c), 0x0FF, c, sky)
    # gems: four tiles cycling colour
    gc = ['C', 'W', 'Y', 'M'] if sky != 'C' else ['B', 'W', 'Y', 'M']
    for i, c in enumerate(gc):
        T('%s.gem%d' % (w, i), 0x044, c, sky, F_GEM, anim='%s.gem%d' % (w, (i + 1) % 4))
    T(w + '.apple', 0x19D, 'R' if sky != 'R' else 'Y', sky, F_ITEM)
    T(w + '.oneup', 0x0CE, 'G' if sky != 'G' else 'Y', sky, F_ITEM)
    T(w + '.golden', 0x1B3, 'Y', sky, F_ITEM, anim=w + '.golden2')
    T(w + '.golden2', 0x1B3, 'W', sky, F_ITEM, anim=w + '.golden')
    T(w + '.spike', 0x16D, 'W' if sky != 'C' else 'K', sky, F_HURT)
    T(w + '.cspike', 0x16F, 'W' if sky != 'C' else 'K', sky, F_HURT)
    T(w + '.vine', 0x1B6, 'G', sky, F_VINE)
    T(w + '.spring', 0x176, 'W' if sky != 'C' else 'M', sky, F_SOLID | F_SPRING)
    T(w + '.spring_c', 0x07E, 'W' if sky != 'C' else 'M', sky, F_SOLID | F_SPRING)
    # chroma "doorway" used by the colour shrine (decor)
    T(w + '.door', 0x187, 'K', sky)

# ---------------------------------------------------------------- W1 meadow
T('W1.top', 0x07A, 'G', 'Y', F_SOLID)
T('W1.fill', 0x0EF, 'R', 'Y', F_SOLID)
T('W1.fake', 0x0EF, 'R', 'Y')                       # secret: looks solid
T('W1.block', 0x1B4, 'K', 'Y', F_SOLID)
T('W1.brick', 0x17F, 'Y', 'R', F_SOLID)
T('W1.plank', 0x07A, 'Y', 'B', F_ONEWAY)
T('W1.crumble', 0x1B1, 'Y', 'R', F_SOLID | F_CRUMBLE)
T('W1.crack', 0x0D3, 'Y', 'R', F_SOLID | F_CRUMBLE)
T('W1.water', 0x0E4, 'W', 'B', F_DEADLY, anim='W1.water2')
T('W1.water2', 0x0E5, 'W', 'B', F_DEADLY, anim='W1.water')
T('W1.deep', 0x0EF, 'B', 'C', F_DEADLY)
T('W1.flower', 0x06B, 'Y', 'B')
T('W1.flower2', 0x06B, 'M', 'B')
T('W1.bush', 0x046, 'G', 'B')
T('W1.grass', 0x0DF, 'G', 'B')
T('W1.cloud_dome', 0x1BD, 'W', 'B')
T('W1.cloud_ball', 0x13E, 'W', 'B')
T('W1.cloud_full', 0x043, 'W', 'B')
T('W1.cloud_bowl', 0x1BE, 'W', 'B')
T('W1.cloud_l', 0x1C0, 'W', 'B')
T('W1.cloud_r', 0x1BF, 'W', 'B')
T('W1.trunk', 0x07B, 'R', 'B')              # left half block (brown-ish)
T('W1.trunk_r', 0x03B, 'R', 'B')
T('W1.leaf', 0x043, 'G', 'B')
T('W1.leaf_dome', 0x1BD, 'G', 'B')
T('W1.leaf_bowl', 0x1BE, 'G', 'B')
T('W1.leaf_l', 0x1C0, 'G', 'B')
T('W1.leaf_r', 0x1BF, 'G', 'B')
T('W1.leaf_tr', 0x1A5, 'G', 'B')
T('W1.leaf_tl', 0x1A1, 'G', 'B')
T('W1.hill_l', 0x04E, 'G', 'B')
T('W1.hill_r', 0x04D, 'G', 'B')
T('W1.hill', 0x0D0, 'G', 'B')
T('W1.sign', 0x1B4, 'W', 'R')
T('W1.post', 0x075, 'Y', 'B')
T('W1.sun', 0x13E, 'Y', 'B')
T('W1.fence', 0x1AD, 'W', 'B')
T('W1.mush', 0x181, 'R', 'B')

# ---------------------------------------------------------------- W2 caverns
T('W2.top', 0x07A, 'M', 'R', F_SOLID)
T('W2.fill', 0x0D0, 'R', 'K', F_SOLID)
T('W2.fake', 0x0D0, 'R', 'K')
T('W2.block', 0x1B1, 'Y', 'M', F_SOLID)
T('W2.brick', 0x17F, 'M', 'K', F_SOLID)
T('W2.plank', 0x07A, 'M', 'K', F_ONEWAY)
T('W2.crumble', 0x1B2, 'R', 'Y', F_SOLID | F_CRUMBLE)
T('W2.crack', 0x0D3, 'R', 'Y', F_SOLID | F_CRUMBLE)
T('W2.water', 0x0E4, 'Y', 'R', F_DEADLY, anim='W2.water2')        # lava
T('W2.water2', 0x0E5, 'Y', 'R', F_DEADLY, anim='W2.water')
T('W2.deep', 0x0EF, 'Y', 'R', F_DEADLY, anim='W2.deep2')
T('W2.deep2', 0x0D0, 'Y', 'R', F_DEADLY, anim='W2.deep')
T('W2.crystal', 0x044, 'M', 'K')
T('W2.crystal2', 0x16D, 'C', 'K')
T('W2.stalag', 0x16F, 'R', 'K')
T('W2.mush', 0x181, 'C', 'K')
T('W2.torch', 0x13F, 'Y', 'K', anim='W2.torch2')
T('W2.torch2', 0x13F, 'R', 'K', anim='W2.torch')
T('W2.bones', 0x1B6, 'W', 'K')
T('W2.drip', 0x075, 'B', 'K')
T('W2.rock_l', 0x04E, 'R', 'K', F_SOLID)
T('W2.rock_r', 0x04D, 'R', 'K', F_SOLID)
T('W2.rail', 0x176, 'Y', 'K')

# ---------------------------------------------------------------- W3 clockwork clouds
T('W3.top', 0x1BD, 'W', 'C', F_SOLID)
T('W3.top2', 0x13E, 'W', 'C', F_SOLID)
T('W3.fill', 0x043, 'W', 'C', F_SOLID)
T('W3.fake', 0x043, 'W', 'C')
T('W3.block', 0x1B2, 'Y', 'B', F_SOLID)
T('W3.brick', 0x177, 'Y', 'M', F_SOLID)            # girder lattice
T('W3.plank', 0x07A, 'M', 'C', F_ONEWAY)
T('W3.crumble', 0x0D0, 'W', 'C', F_SOLID | F_CRUMBLE)
T('W3.crack', 0x0D3, 'W', 'C', F_SOLID | F_CRUMBLE)
T('W3.water', 0x0E4, 'B', 'C', F_DEADLY, anim='W3.water2')       # thunder cloud
T('W3.water2', 0x0E5, 'B', 'C', F_DEADLY, anim='W3.water')
T('W3.deep', 0x0EF, 'B', 'W', F_DEADLY)
T('W3.gear', 0x18F, 'Y', 'C', anim='W3.gear2')
T('W3.gear2', 0x18E, 'Y', 'C', anim='W3.gear3')
T('W3.gear3', 0x18D, 'Y', 'C', anim='W3.gear')
T('W3.cloud_dome', 0x1BD, 'W', 'C')
T('W3.cloud_ball', 0x13E, 'W', 'C')
T('W3.cloud_full', 0x043, 'W', 'C')
T('W3.cloud_bowl', 0x1BE, 'W', 'C')
T('W3.cloud_l', 0x1C0, 'W', 'C')
T('W3.cloud_r', 0x1BF, 'W', 'C')
T('W3.chain', 0x1B6, 'B', 'C')
T('W3.star', 0x1B3, 'W', 'C')
T('W3.bird', 0x18C, 'B', 'C')
T('W3.pipe', 0x175, 'M', 'C', F_SOLID)

# ---------------------------------------------------------------- W4 grey castle
T('W4.top', 0x07A, 'W', 'K', F_SOLID)
T('W4.fill', 0x0D0, 'W', 'K', F_SOLID)
T('W4.fake', 0x0D0, 'W', 'K')
T('W4.block', 0x1B4, 'K', 'W', F_SOLID)
T('W4.brick', 0x17F, 'W', 'K', F_SOLID)
T('W4.plank', 0x036, 'W', 'K', F_ONEWAY)
T('W4.crumble', 0x1B1, 'W', 'K', F_SOLID | F_CRUMBLE)
T('W4.crack', 0x0D3, 'W', 'K', F_SOLID | F_CRUMBLE)
T('W4.water', 0x0E4, 'W', 'K', F_DEADLY, anim='W4.water2')       # grey goo
T('W4.water2', 0x0E5, 'W', 'K', F_DEADLY, anim='W4.water')
T('W4.deep', 0x0EF, 'W', 'K', F_DEADLY)
T('W4.window', 0x1B4, 'Y', 'K')
T('W4.window2', 0x1B4, 'B', 'K')
T('W4.banner', 0x16A, 'W', 'K')
T('W4.chain', 0x1B6, 'W', 'K')
T('W4.torch', 0x13F, 'W', 'K', anim='W4.torch2')
T('W4.torch2', 0x13F, 'Y', 'K', anim='W4.torch')
T('W4.crown', 0x1C5, 'W', 'K')
T('W4.pillar', 0x175, 'W', 'K')
T('W4.moon', 0x13E, 'W', 'K')
T('W4.star', 0x0DB, 'W', 'K')

assert len(TILES) <= 256, len(TILES)

CHROMA_BASE = {w: INDEX[w + '.chroma_R'] for w in WORLDS}


def tid(world, name):
    """resolve a tile name for a world: world-specific first, then common"""
    k = '%s.%s' % (world, name)
    if k in INDEX:
        return INDEX[k]
    return INDEX[name]


def tables():
    chr_ = [0] * 256
    atr = [0] * 256
    flg = [0] * 256
    anim = list(range(256))
    for i, t in enumerate(TILES):
        chr_[i] = t.ch
        atr[i] = t.at
        flg[i] = t.flags
        if t.anim:
            anim[i] = INDEX[t.anim]
    return chr_, atr, flg, anim
