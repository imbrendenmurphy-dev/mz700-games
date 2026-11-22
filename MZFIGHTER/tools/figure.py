"""figure.py - procedural fighter art: a skeleton in a pose, dressed with a
build (proportions) and a costume (colours, hair, extras), rendered to a
colour-index pixel image (TR = transparent).

Coordinates: pixels, origin at the anchor (between the feet, on the ground),
x forward (towards the opponent), y UP.  Angles in degrees: limbs measured
from straight down, positive = swung forward; torso from vertical, positive =
leaning forward.
"""
import math
import numpy as np
from PIL import Image, ImageDraw

TR = 8
SS = 4                  # supersampling
W, H = 160, 136         # canvas (pixels)
AX, AY = 80, 128        # anchor in the canvas (image coords, y down)

BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)


def vec(deg, length):
    r = math.radians(deg)
    return (math.sin(r) * length, -math.cos(r) * length)


def add(p, v):
    return (p[0] + v[0], p[1] + v[1])


class Canvas:
    def __init__(self):
        self.im = Image.new('P', (W * SS, H * SS), TR)
        self.d = ImageDraw.Draw(self.im)
        self.flip = False

    def P(self, p):
        x, y = p
        return ((AX + x) * SS, (AY - y) * SS)

    def capsule(self, a, b, r1, r2, col):
        """a tapered limb from a (radius r1) to b (radius r2)."""
        ax, ay = self.P(a)
        bx, by = self.P(b)
        r1 *= SS
        r2 *= SS
        dx, dy = bx - ax, by - ay
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        poly = [(ax + nx * r1, ay + ny * r1), (bx + nx * r2, by + ny * r2),
                (bx - nx * r2, by - ny * r2), (ax - nx * r1, ay - ny * r1)]
        self.d.polygon(poly, fill=col)
        self.d.ellipse([ax - r1, ay - r1, ax + r1, ay + r1], fill=col)
        self.d.ellipse([bx - r2, by - r2, bx + r2, by + r2], fill=col)

    def poly(self, pts, col):
        self.d.polygon([self.P(p) for p in pts], fill=col)

    def ellipse(self, c, rx, ry, col):
        x, y = self.P(c)
        self.d.ellipse([x - rx * SS, y - ry * SS, x + rx * SS, y + ry * SS], fill=col)

    def result(self):
        """majority-vote downsample -> numpy (H, W) colour indices."""
        a = np.array(self.im, dtype=np.uint8).reshape(H, SS, W, SS).transpose(0, 2, 1, 3).reshape(H, W, SS * SS)
        out = np.full((H, W), TR, np.uint8)
        for c in range(9):
            pass
        cnt = np.zeros((H, W, 9), np.int32)
        for c in range(9):
            cnt[:, :, c] = (a == c).sum(2)
        # transparent wins only with a clear majority, so thin parts survive
        op = cnt[:, :, :8]
        best = op.argmax(2)
        bestn = op.max(2)
        out = np.where(bestn * 2 >= cnt[:, :, 8] * 0 + SS * SS // 2, best, TR).astype(np.uint8)
        out[bestn < (SS * SS) * 0.35] = TR
        return out


# ---------------------------------------------------------------- builds
class Build:
    def __init__(self, **kw):
        # lengths
        self.thigh = 20
        self.shin = 20
        self.torso = 28
        self.neck = 4
        self.head = 7.6          # head radius
        self.uarm = 15
        self.farm = 14
        # widths (radii)
        self.thigh_r = (6, 4.5)
        self.shin_r = (4.5, 3.5)
        self.uarm_r = (4.5, 3.8)
        self.farm_r = (3.8, 3.2)
        self.fist = 4.5
        self.shoulder_w = 13     # half width of the chest at the shoulders
        self.waist_w = 9
        self.hip_w = 10
        self.foot = 9
        self.chest = 1.0         # pec bulge factor
        self.scale = 1.32
        self.__dict__.update(kw)
        k = self.scale
        for a in ('thigh', 'shin', 'torso', 'neck', 'head', 'uarm', 'farm', 'fist', 'shoulder_w', 'waist_w',
                  'hip_w', 'foot'):
            setattr(self, a, getattr(self, a) * k)
        for a in ('thigh_r', 'shin_r', 'uarm_r', 'farm_r'):
            setattr(self, a, tuple(v * k for v in getattr(self, a)))


# ---------------------------------------------------------------- poses
class Pose:
    """hip: (x, y) of the pelvis; torso lean; head tilt; arms/legs as
    (upper angle, lower angle) absolute, for the front (f) and back (b) limbs."""
    def __init__(self, hip=(0, 40), lean=0, arm_f=(30, 100), arm_b=(10, 120),
                 leg_f=(15, 0), leg_b=(-15, 0), fist_f='fist', fist_b='fist',
                 top='b', foot_f=None, foot_b=None, head=0, extra=None, angle=0):
        self.hip = hip
        self.lean = lean
        self.arm_f = arm_f
        self.arm_b = arm_b
        self.leg_f = leg_f
        self.leg_b = leg_b
        self.fist_f = fist_f
        self.fist_b = fist_b
        self.top = top          # which arm is drawn over the torso: 'f' / 'b'
        self.foot_f = foot_f    # foot angle (None = flat on the ground)
        self.foot_b = foot_b
        self.head = head
        self.extra = extra or {}
        self.angle = angle      # whole-body rotation (for flips, falls)


def rot(p, ang, c):
    if not ang:
        return p
    r = math.radians(ang)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(r) - y * math.sin(r), c[1] + x * math.sin(r) + y * math.cos(r))


def skeleton(b, p):
    """joint positions"""
    J = {}
    hip = p.hip
    J['hip'] = hip
    neck = add(hip, (math.sin(math.radians(p.lean)) * b.torso, math.cos(math.radians(p.lean)) * b.torso))
    J['neck'] = neck
    J['head'] = add(neck, vec(180 + p.lean * 0.5 + p.head, b.neck + b.head))
    perp = (math.cos(math.radians(p.lean)), -math.sin(math.radians(p.lean)))
    sh = add(neck, vec(180 + p.lean, -3))
    J['sh_f'] = add(sh, (perp[0] * b.shoulder_w * 0.55, perp[1] * b.shoulder_w * 0.55))
    J['sh_b'] = add(sh, (-perp[0] * b.shoulder_w * 0.55, -perp[1] * b.shoulder_w * 0.55))
    hp = hip
    J['hp_f'] = add(hp, (perp[0] * b.hip_w * 0.4, perp[1] * b.hip_w * 0.4))
    J['hp_b'] = add(hp, (-perp[0] * b.hip_w * 0.4, -perp[1] * b.hip_w * 0.4))
    for s, arm in (('f', p.arm_f), ('b', p.arm_b)):
        e = add(J['sh_' + s], vec(arm[0], b.uarm))
        J['el_' + s] = e
        J['ha_' + s] = add(e, vec(arm[1], b.farm))
    for s, leg in (('f', p.leg_f), ('b', p.leg_b)):
        k = add(J['hp_' + s], vec(leg[0], b.thigh))
        J['kn_' + s] = k
        J['an_' + s] = add(k, vec(leg[1], b.shin))
    if p.angle:
        c = add(hip, (0, 0))
        for k in J:
            J[k] = rot(J[k], p.angle, c)
    return J


# ---------------------------------------------------------------- costume
class Costume:
    def __init__(self, **kw):
        self.skin = YELLOW
        self.hair = BLACK
        self.hair_style = 'short'     # short, long, topknot, bald, mohawk, bun, flat, mask, beard
        self.shirt = None             # None = bare chest (skin)
        self.sleeve = None            # upper arm colour (None = skin)
        self.forearm = None
        self.belt = BLACK
        self.trousers = WHITE
        self.shins = None             # None = trousers
        self.shoes = None             # None = skin (barefoot)
        self.gloves = None            # None = skin
        self.band = None              # headband colour
        self.gi_top = None            # gi jacket colour (covers torso + shoulders, V neck)
        self.sash = None              # long belt tails
        self.mask = None              # wrestler mask colour
        self.wraps = None             # hand/foot wraps (muay thai)
        self.shorts = None            # short trousers (thighs only)
        self.beard = None
        self.robe = None              # long robe skirt
        self.cape = None
        self.trim = None
        self.__dict__.update(kw)


def draw_figure(b, c, p, extra_fx=None):
    cv = Canvas()
    J = skeleton(b, p)
    top = c.gi_top or c.shirt or c.skin
    sleeve = c.sleeve if c.sleeve is not None else (c.gi_top if c.gi_top is not None else c.skin)
    forearm = c.forearm if c.forearm is not None else c.skin
    gloves = c.gloves if c.gloves is not None else (c.wraps if c.wraps is not None else forearm)
    thighc = c.trousers
    shinc = c.shins if c.shins is not None else c.trousers
    if c.shorts is not None:
        thighc = c.shorts
        shinc = c.skin if c.shins is None else c.shins
    footc = c.shoes if c.shoes is not None else (c.wraps if c.wraps is not None else c.skin)

    def leg(s):
        hp, kn, an = J['hp_' + s], J['kn_' + s], J['an_' + s]
        cv.capsule(hp, kn, b.thigh_r[0], b.thigh_r[1], thighc)
        cv.capsule(kn, an, b.shin_r[0], b.shin_r[1], shinc)
        # foot: points forward (or along the shin when kicking)
        fa = p.foot_f if s == 'f' else p.foot_b
        if fa is None:
            toe = add(an, (b.foot * 0.85, -1.5))
            heel = add(an, (-b.foot * 0.3, -1.5))
        else:
            v = vec(fa, b.foot)
            toe = add(an, v)
            heel = add(an, (-v[0] * 0.25, -v[1] * 0.25))
        cv.capsule(heel, toe, 2.8, 2.2, footc)
        if c.robe is not None and c.shorts is None:
            pass

    def arm(s):
        sh, el, ha = J['sh_' + s], J['el_' + s], J['ha_' + s]
        cv.capsule(sh, el, b.uarm_r[0], b.uarm_r[1], sleeve)
        cv.capsule(el, ha, b.farm_r[0], b.farm_r[1], forearm)
        fs = p.fist_f if s == 'f' else p.fist_b
        if fs == 'open':
            v = (ha[0] - el[0], ha[1] - el[1])
            ln = math.hypot(*v) or 1
            tip = add(ha, (v[0] / ln * 5, v[1] / ln * 5))
            cv.capsule(ha, tip, b.fist * 0.8, b.fist * 0.6, gloves)
        else:
            cv.ellipse(ha, b.fist, b.fist, gloves)

    def torso():
        hip, neck = J['hip'], J['neck']
        lean = p.lean + p.angle * 0
        ang = math.atan2(neck[0] - hip[0], neck[1] - hip[1])
        perp = (math.cos(ang), -math.sin(ang))
        up = (math.sin(ang), math.cos(ang))
        def at(base, w, u=0):
            return add(base, (perp[0] * w + up[0] * u, perp[1] * w + up[1] * u))
        chest = add(hip, (up[0] * b.torso * 0.7, up[1] * b.torso * 0.7))
        pts = [at(hip, -b.hip_w), at(hip, -b.waist_w, b.torso * 0.35), at(chest, -b.shoulder_w),
               at(neck, -b.shoulder_w * 0.8, -1), at(neck, b.shoulder_w * 0.8, -1), at(chest, b.shoulder_w * b.chest),
               at(hip, b.waist_w, b.torso * 0.35), at(hip, b.hip_w)]
        cv.poly(pts, top)
        if c.gi_top is not None and c.shirt is None:
            # V of skin at the neck
            cv.poly([at(neck, -3, -1), at(neck, 3, -1), at(neck, 0, -9)], c.skin)
        # pelvis / trousers top
        cv.poly([at(hip, -b.hip_w), at(hip, b.hip_w), at(hip, b.hip_w, 5), at(hip, -b.hip_w, 5)],
                c.shorts if c.shorts is not None else c.trousers)
        if c.belt is not None:
            cv.poly([at(hip, -b.waist_w - 1, 4), at(hip, b.waist_w + 1, 4), at(hip, b.waist_w + 1, 7.5),
                     at(hip, -b.waist_w - 1, 7.5)], c.belt)
        if c.robe is not None:
            # long skirt from the waist, over the thighs
            kn = J['kn_f'], J['kn_b']
            lo = min(kn[0][1], kn[1][1]) - 6
            xs = [kn[0][0], kn[1][0], hip[0]]
            cv.poly([at(hip, -b.hip_w - 1, 6), at(hip, b.hip_w + 1, 6), (max(xs) + 7, lo), (min(xs) - 7, lo)], c.robe)

    def head():
        h = J['head']
        cv.capsule(J['neck'], add(J['neck'], (0, 3)), 4, 4, c.skin)
        hr = b.head
        hs = c.hair_style
        face = c.mask if c.mask is not None else c.skin
        if hs == 'long':
            cv.poly([add(h, (-hr * 0.9, hr * 0.5)), add(h, (hr * 0.2, hr)), add(h, (-hr * 0.3, -hr * 2.6)),
                     add(h, (-hr * 1.5, -hr * 2.2))], c.hair)
        if hs == 'ponytail':
            cv.capsule(add(h, (-hr * 0.8, hr * 0.4)), add(h, (-hr * 2.2, -hr * 1.2)), 3, 2, c.hair)
        cv.ellipse(h, hr * 0.92, hr, face)
        # hair cap
        if hs in ('short', 'long', 'topknot', 'ponytail', 'bun', 'buns', 'flat', 'spiky'):
            cv.d.chord([cv.P(add(h, (-hr - 1, hr + 1)))[0], cv.P(add(h, (-hr - 1, hr + 1)))[1],
                        cv.P(add(h, (hr + 1, -hr - 1)))[0], cv.P(add(h, (hr + 1, -hr - 1)))[1]],
                       172, 360 + 2, fill=c.hair)
            # back of the head
            cv.ellipse(add(h, (-hr * 0.55, hr * 0.05)), hr * 0.45, hr * 0.8, c.hair)
        if hs == 'flat':
            cv.poly([add(h, (-hr, hr * 0.3)), add(h, (hr, hr * 0.3)), add(h, (hr * 1.0, hr * 1.6)),
                     add(h, (-hr * 1.0, hr * 1.6))], c.hair)
        if hs == 'spiky':
            for dx, ang in ((-hr * 1.1, -40), (-hr * 0.4, -15), (hr * 0.3, 10)):
                base = add(h, (dx, hr * 0.4))
                tip = add(base, vec(180 - ang, hr * 1.3))
                cv.poly([add(base, (-3.5, 0)), add(base, (3.5, 0)), tip], c.hair)
        if hs == 'turban':
            cv.ellipse(add(h, (-hr * 0.1, hr * 0.55)), hr * 1.15, hr * 0.75, c.hair)
            cv.ellipse(add(h, (hr * 0.2, hr * 0.95)), hr * 0.5, hr * 0.45, c.trim if c.trim is not None else c.hair)
        if hs == 'buns':
            cv.ellipse(add(h, (-hr * 0.8, hr * 0.9)), 3.2 * b.scale, 3.2 * b.scale, c.hair)
            cv.ellipse(add(h, (hr * 0.5, hr * 1.1)), 3.0 * b.scale, 3.0 * b.scale, c.hair)
        if hs == 'topknot':
            cv.ellipse(add(h, (-hr * 0.3, hr * 1.1)), 2.5, 3, c.hair)
        if hs == 'bun':
            cv.ellipse(add(h, (-hr * 0.9, hr * 0.6)), 3.5, 3.5, c.hair)
        if hs == 'mohawk':
            cv.poly([add(h, (-hr * 1.1, hr * 0.2)), add(h, (-hr * 0.6, hr * 1.5)), add(h, (hr * 0.5, hr * 1.4)),
                     add(h, (hr * 0.2, hr * 0.7))], c.hair)
        if c.beard is not None:
            cv.poly([add(h, (-hr * 0.2, -hr * 0.2)), add(h, (hr * 0.95, -hr * 0.2)), add(h, (hr * 0.4, -hr * 2.0)),
                     add(h, (-hr * 0.1, -hr * 1.2))], c.beard)
        if c.band is not None:
            cv.poly([add(h, (-hr, hr * 0.25)), add(h, (hr, hr * 0.35)), add(h, (hr, hr * 0.0)), add(h, (-hr, -hr * 0.1))], c.band)
            cv.poly([add(h, (-hr, hr * 0.2)), add(h, (-hr * 2.0, -hr * 0.3)), add(h, (-hr * 1.8, -hr * 0.8)), add(h, (-hr, -hr * 0.1))], c.band)
        if c.mask is not None:
            cv.ellipse(add(h, (hr * 0.4, hr * 0.15)), hr * 0.35, hr * 0.22, WHITE if c.mask != WHITE else RED)

    under = 'f' if p.top == 'b' else 'b'
    if c.cape is not None:
        sb = J['sh_b']
        cv.poly([add(sb, (-2, 2)), add(J['sh_f'], (0, 2)), add(J['hip'], (-6, -18)), add(J['hip'], (-18, -16))], c.cape)
    leg('b')
    arm(under)
    leg('f')
    torso()
    head()
    arm(p.top)
    if extra_fx:
        extra_fx(cv, J)
    return cv.result(), J
