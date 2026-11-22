"""fighters.py - the roster: builds, costumes, styles and pose libraries.

All characters are original.  Poses are joint angles (see figure.py); each
style overrides the base (karate) poses that make it look different.
"""
from figure import Build, Costume, Pose, BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE

# frame names, in the order the engine indexes them
FRAMES = ['stance', 'walk1', 'walk2', 'crouch', 'jump', 'punch', 'kick', 'cpunch', 'sweep',
          'jkick', 'block', 'cblock', 'hit', 'fall', 'down', 'spec_a', 'spec_b', 'win']


class Fighter:
    def __init__(self, name, build, costume, style='karate', spa='fire', spb='upper', speed=5,
                 power=0, proj='fire', alt=None, country='', stage=0, blurb=''):
        self.name = name
        self.build = build
        self.costume = costume
        self.style = style
        self.spa = spa          # special A (QCF+P, or mash P for flurry): fire / flurry / rush
        self.spb = spb          # special B: upper (DP+P) / spin, dive (QCB+K)
        self.speed = speed      # walk speed, 1/16 cell per frame
        self.power = power      # extra damage per hit
        self.proj = proj        # projectile art style
        self.alt = alt or {}    # mirror-match palette: colour -> colour
        self.country = country
        self.stage = stage
        self.blurb = blurb


def base_poses(b):
    L = b.thigh + b.shin
    hy = L - 0.12 * L                 # hip height in the stance (knees bent)
    P = {}
    P['stance'] = Pose(hip=(0, hy), lean=6, arm_f=(62, 155), arm_b=(5, 115), leg_f=(24, 4), leg_b=(-22, -14), top='f')
    P['stance2'] = Pose(hip=(0, hy - 2), lean=8, arm_f=(58, 150), arm_b=(0, 112), leg_f=(26, 2), leg_b=(-24, -16),
                        top='f')
    P['walk1'] = Pose(hip=(0, hy + 1), lean=6, arm_f=(55, 150), arm_b=(10, 120), leg_f=(30, 10), leg_b=(-8, -28),
                      foot_b=-40, top='f')
    P['walk2'] = Pose(hip=(0, hy + 1), lean=6, arm_f=(60, 155), arm_b=(0, 115), leg_f=(-5, -25), leg_b=(18, 0),
                      foot_f=-40, top='f')
    P['crouch'] = Pose(hip=(-2, hy * 0.5), lean=18, arm_f=(60, 150), arm_b=(30, 140), leg_f=(78, -15),
                       leg_b=(10, -100), foot_b=-100, top='f')
    P['jump'] = Pose(hip=(0, hy), lean=10, arm_f=(70, 160), arm_b=(40, 150), leg_f=(95, -20), leg_b=(60, -50),
                     foot_f=60, foot_b=20, top='f')
    P['punch'] = Pose(hip=(3, hy - 2), lean=14, arm_f=(90, 90), arm_b=(-30, 95), leg_f=(30, 6), leg_b=(-26, -18),
                      top='f')
    P['kick'] = Pose(hip=(-4, hy + 2), lean=-26, arm_f=(70, 150), arm_b=(-50, 60), leg_f=(100, 98), leg_b=(-4, -6),
                     foot_f=100, top='f')
    P['cpunch'] = Pose(hip=(0, hy * 0.5), lean=20, arm_f=(88, 88), arm_b=(-20, 120), leg_f=(78, -15),
                       leg_b=(10, -100), foot_b=-100, top='f')
    P['sweep'] = Pose(hip=(-6, hy * 0.36), lean=-10, arm_f=(30, 30), arm_b=(-30, -30), leg_f=(92, 92),
                      leg_b=(70, -40), foot_f=92, fist_f='open', fist_b='open', top='f')
    P['jkick'] = Pose(hip=(0, hy), lean=-15, arm_f=(70, 150), arm_b=(-60, 40), leg_f=(70, 70), leg_b=(40, -60),
                      foot_f=75, foot_b=0, top='f')
    P['block'] = Pose(hip=(-2, hy), lean=-6, arm_f=(30, 175), arm_b=(50, 165), leg_f=(20, 2), leg_b=(-24, -14),
                      top='f')
    P['cblock'] = Pose(hip=(-3, hy * 0.5), lean=6, arm_f=(30, 175), arm_b=(50, 165), leg_f=(78, -15),
                       leg_b=(10, -100), foot_b=-100, top='f')
    P['hit'] = Pose(hip=(-4, hy), lean=-24, head=-25, arm_f=(20, -10), arm_b=(-40, -20), leg_f=(22, 6),
                    leg_b=(-14, -6), top='f')
    P['fall'] = Pose(hip=(0, hy * 0.7), lean=-30, head=-20, arm_f=(150, 170), arm_b=(120, 160), leg_f=(70, 40),
                     leg_b=(40, 10), top='f', angle=-50)
    P['down'] = Pose(hip=(0, 6), lean=0, head=0, arm_f=(10, 10), arm_b=(-10, -10), leg_f=(10, 25), leg_b=(-5, 15),
                     top='f', angle=-88, foot_f=180, foot_b=180)
    P['spec_a'] = Pose(hip=(2, hy - 3), lean=16, arm_f=(92, 92), arm_b=(85, 88), leg_f=(32, 6), leg_b=(-28, -20),
                       fist_f='open', fist_b='open', top='f')
    P['spec_b'] = Pose(hip=(4, hy + 6), lean=-4, arm_f=(172, 178), arm_b=(20, 110), leg_f=(70, -20), leg_b=(-8, -12),
                       top='f')
    P['win'] = Pose(hip=(0, hy + 2), lean=0, arm_f=(165, 180), arm_b=(-30, 160), leg_f=(12, 0), leg_b=(-12, 0),
                    top='f')
    P['throw'] = Pose(hip=(2, hy - 2), lean=18, arm_f=(80, 60), arm_b=(70, 50), leg_f=(30, 6), leg_b=(-26, -18),
                      fist_f='open', fist_b='open', top='f')
    return P


def style_poses(style, b, spb):
    """per-style overrides"""
    L = b.thigh + b.shin
    hy = L - 0.12 * L
    P = {}
    if style == 'boxer':
        P['stance'] = Pose(hip=(0, hy + 1), lean=12, arm_f=(40, 160), arm_b=(25, 165), leg_f=(18, 4), leg_b=(-18, -10),
                           top='f')
        P['stance2'] = Pose(hip=(0, hy - 1), lean=14, arm_f=(44, 162), arm_b=(28, 168), leg_f=(20, 2),
                            leg_b=(-20, -12), top='f')
        P['block'] = Pose(hip=(-2, hy), lean=2, arm_f=(15, 178), arm_b=(25, 175), leg_f=(18, 2), leg_b=(-20, -12),
                          top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=-4, arm_f=(170, 170), arm_b=(-160, -170), leg_f=(14, 0),
                        leg_b=(-14, 0), top='f')
    elif style == 'capoeira':
        P['stance'] = Pose(hip=(0, hy - 6), lean=-4, arm_f=(120, 150), arm_b=(-60, -20), leg_f=(40, -10),
                           leg_b=(-34, -24), top='f')
        P['stance2'] = Pose(hip=(-2, hy - 9), lean=4, arm_f=(30, 100), arm_b=(-110, -150), leg_f=(30, -20),
                            leg_b=(-40, -20), top='b')
        P['walk1'] = Pose(hip=(2, hy - 6), lean=-2, arm_f=(100, 140), arm_b=(-80, -40), leg_f=(36, 0),
                          leg_b=(-20, -40), foot_b=-50, top='f')
        P['walk2'] = Pose(hip=(-2, hy - 7), lean=4, arm_f=(40, 110), arm_b=(-100, -140), leg_f=(-10, -30),
                          leg_b=(30, -10), foot_f=-40, top='b')
        P['kick'] = Pose(hip=(-6, hy - 2), lean=-40, arm_f=(150, 170), arm_b=(-60, -10), leg_f=(120, 120),
                         leg_b=(-6, -10), foot_f=120, top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=0, arm_f=(150, 170), arm_b=(-150, -170), leg_f=(10, 0), leg_b=(-14, 20),
                        top='f')
    elif style == 'wrestler':
        P['stance'] = Pose(hip=(0, hy - 4), lean=18, arm_f=(70, 110), arm_b=(40, 100), leg_f=(30, 8), leg_b=(-30, -14),
                           fist_f='open', fist_b='open', top='f')
        P['stance2'] = Pose(hip=(0, hy - 6), lean=20, arm_f=(74, 104), arm_b=(44, 96), leg_f=(32, 6),
                            leg_b=(-32, -16), fist_f='open', fist_b='open', top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=0, arm_f=(130, 175), arm_b=(-130, -175), leg_f=(16, 0),
                        leg_b=(-16, 0), top='f')
    elif style == 'kungfu':
        P['stance'] = Pose(hip=(0, hy - 2), lean=4, arm_f=(80, 95), arm_b=(-20, 150), leg_f=(30, 0), leg_b=(-20, -20),
                           fist_f='open', top='f')
        P['stance2'] = Pose(hip=(0, hy - 4), lean=6, arm_f=(85, 100), arm_b=(-25, 155), leg_f=(32, -2),
                            leg_b=(-22, -22), fist_f='open', top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=0, arm_f=(60, 160), arm_b=(60, 160), leg_f=(60, -60), leg_b=(0, 0),
                        foot_f=40, fist_f='open', fist_b='open', top='f')
    elif style == 'muaythai':
        P['stance'] = Pose(hip=(0, hy + 2), lean=-4, arm_f=(45, 165), arm_b=(30, 170), leg_f=(14, 4), leg_b=(-14, -6),
                           top='f')
        P['stance2'] = Pose(hip=(0, hy + 1), lean=-2, arm_f=(48, 168), arm_b=(32, 172), leg_f=(30, -40),
                            leg_b=(-10, -6), foot_f=-20, top='f')
        P['kick'] = Pose(hip=(-4, hy + 4), lean=-32, arm_f=(40, 160), arm_b=(-70, -40), leg_f=(112, 112),
                         leg_b=(-2, -4), foot_f=112, top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=0, arm_f=(160, 175), arm_b=(160, 175), leg_f=(14, 0), leg_b=(-14, 0),
                        top='f')
    elif style == 'luchador':
        P['stance'] = Pose(hip=(0, hy - 6), lean=16, arm_f=(80, 130), arm_b=(60, 120), leg_f=(34, 4), leg_b=(-30, -16),
                           fist_f='open', fist_b='open', top='f')
        P['stance2'] = Pose(hip=(0, hy - 8), lean=18, arm_f=(70, 120), arm_b=(55, 110), leg_f=(36, 2),
                            leg_b=(-32, -18), fist_f='open', fist_b='open', top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=-6, arm_f=(150, 160), arm_b=(-150, -160), leg_f=(16, 0),
                        leg_b=(-16, 0), top='f')
    elif style == 'kalari':
        P['stance'] = Pose(hip=(0, hy - 8), lean=10, arm_f=(100, 80), arm_b=(-60, -90), leg_f=(46, 0), leg_b=(-36, -20),
                           fist_f='open', fist_b='open', top='f')
        P['stance2'] = Pose(hip=(0, hy - 10), lean=12, arm_f=(104, 76), arm_b=(-64, -95), leg_f=(48, -2),
                            leg_b=(-38, -22), fist_f='open', fist_b='open', top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=0, arm_f=(10, 150), arm_b=(-10, -150), leg_f=(60, -80), leg_b=(0, 0),
                        foot_f=-90, fist_f='open', fist_b='open', top='f')
    elif style == 'boss':
        P['stance'] = Pose(hip=(0, hy + 2), lean=0, arm_f=(30, 120), arm_b=(-10, 40), leg_f=(16, 2), leg_b=(-16, -4),
                           top='f')
        P['stance2'] = Pose(hip=(0, hy + 1), lean=2, arm_f=(34, 124), arm_b=(-12, 44), leg_f=(16, 2), leg_b=(-16, -4),
                            top='f')
        P['win'] = Pose(hip=(0, hy + 2), lean=-4, arm_f=(170, 175), arm_b=(-20, 30), leg_f=(16, 0), leg_b=(-16, 0),
                        fist_f='open', top='f')
    # special B by move type
    if spb == 'spin':
        P['spec_b'] = Pose(hip=(0, hy + 2), lean=30, arm_f=(-60, -30), arm_b=(100, 120), leg_f=(-100, -100),
                           leg_b=(40, -50), foot_f=-100, top='b')
    elif spb == 'dive':
        P['spec_b'] = Pose(hip=(0, hy * 0.6), lean=70, arm_f=(110, 110), arm_b=(100, 100), leg_f=(-60, -70),
                           leg_b=(-80, -80), foot_f=-70, foot_b=-80, fist_f='open', fist_b='open', top='f')
    return P


def pose(ftr, name):
    P = base_poses(ftr.build)
    P.update(style_poses(ftr.style, ftr.build, ftr.spb))
    return P[name]


FIGHTERS = {
    'kenji': Fighter('KENJI',
                     Build(),
                     Costume(skin=YELLOW, hair=BLACK, hair_style='short', gi_top=WHITE, trousers=WHITE,
                             belt=BLACK, band=RED),
                     style='karate', spa='fire', spb='upper', proj='fire', alt={WHITE: CYAN, RED: BLUE},
                     country='JAPAN', stage=0),
    'rosa': Fighter('ROSA',
                    Build(scale=1.24, thigh_r=(5.5, 4), shin_r=(4, 3), uarm_r=(3.6, 3), farm_r=(3, 2.6), fist=3.8,
                          shoulder_w=10.5, waist_w=7, hip_w=9.5, head=7.2),
                    Costume(skin=MAGENTA, hair=BLACK, hair_style='long', shirt=RED, trousers=GREEN, belt=YELLOW),
                    style='capoeira', spa='flurry', spb='spin', speed=6, proj='jade',
                    alt={RED: BLUE, GREEN: WHITE}, country='BRAZIL', stage=1),
    'brody': Fighter('BRODY',
                     Build(scale=1.36, uarm_r=(5.5, 4.5), farm_r=(4.6, 4), fist=5.5, shoulder_w=15, waist_w=10),
                     Costume(skin=YELLOW, hair=WHITE, hair_style='flat', shirt=WHITE, trousers=BLUE, belt=BLACK,
                             gloves=RED, shoes=BLACK),
                     style='boxer', spa='rush', spb='upper', speed=5, power=2, proj='fire',
                     alt={BLUE: GREEN, RED: YELLOW}, country='U.S.A.', stage=2),
    'mei': Fighter('MEI LING',
                   Build(scale=1.22, thigh_r=(5.5, 4), shin_r=(4, 3), uarm_r=(3.5, 3), farm_r=(3, 2.6), fist=3.8,
                         shoulder_w=10, waist_w=7, hip_w=9, head=7.2),
                   Costume(skin=YELLOW, hair=BLACK, hair_style='buns', gi_top=CYAN, trousers=WHITE, belt=RED,
                           shoes=RED),
                   style='kungfu', spa='fire', spb='spin', speed=6, proj='chi',
                   alt={CYAN: MAGENTA, RED: BLUE}, country='CHINA', stage=3),
    'volkov': Fighter('VOLKOV',
                      Build(scale=1.46, thigh_r=(7.5, 5.5), shin_r=(5.5, 4.5), uarm_r=(6, 5), farm_r=(5, 4.5),
                            fist=5.5, shoulder_w=17, waist_w=13, hip_w=12, head=7.4, chest=1.1),
                      Costume(skin=MAGENTA, hair=RED, hair_style='bald', beard=RED, shorts=BLUE, shins=BLUE,
                              shoes=BLACK, belt=YELLOW, trousers=BLUE),
                      style='wrestler', spa='rush', spb='upper', speed=3, power=4, proj='fire',
                      alt={BLUE: GREEN, YELLOW: WHITE}, country='RUSSIA', stage=4),
    'condor': Fighter('EL CONDOR',
                      Build(scale=1.32, uarm_r=(5, 4), farm_r=(4.2, 3.6), shoulder_w=14),
                      Costume(skin=MAGENTA, hair=GREEN, hair_style='bald', mask=GREEN, trousers=GREEN,
                              shins=YELLOW, shoes=YELLOW, belt=YELLOW),
                      style='luchador', spa='flurry', spb='dive', speed=5, power=1, proj='fire',
                      alt={GREEN: RED, YELLOW: WHITE}, country='MEXICO', stage=5),
    'somchai': Fighter('SOMCHAI',
                       Build(scale=1.34, thigh_r=(5.5, 4.2), shin_r=(4.2, 3.4)),
                       Costume(skin=YELLOW, hair=BLACK, hair_style='short', band=WHITE, shorts=RED, belt=WHITE,
                               wraps=WHITE, trousers=RED),
                       style='muaythai', spa='fire', spb='upper', speed=5, power=1, proj='blade',
                       alt={RED: BLUE}, country='THAILAND', stage=6),
    'ravi': Fighter('RAVI',
                    Build(scale=1.34, thigh=22, shin=22, uarm=17, farm=16, thigh_r=(5, 3.8), shin_r=(3.8, 3),
                          uarm_r=(3.8, 3.2), farm_r=(3.2, 2.8), shoulder_w=12, waist_w=8, hip_w=9),
                    Costume(skin=MAGENTA, hair=WHITE, hair_style='turban', trim=YELLOW, beard=BLACK, shirt=None,
                            trousers=YELLOW, belt=RED, robe=None),
                    style='kalari', spa='fire', spb='spin', speed=4, proj='ring',
                    alt={YELLOW: CYAN, RED: BLUE}, country='INDIA', stage=7),
    'zarkon': Fighter('ZARKON',
                      Build(scale=1.44, uarm_r=(5.5, 4.8), farm_r=(4.8, 4.2), fist=5.2, shoulder_w=16, waist_w=11,
                            thigh_r=(6.5, 5), shin_r=(5, 4)),
                      Costume(skin=WHITE, hair=WHITE, hair_style='spiky', gi_top=BLUE, trousers=BLUE, belt=YELLOW,
                              gloves=YELLOW, shoes=MAGENTA, shins=BLUE, cape=MAGENTA, sleeve=BLUE, forearm=BLUE),
                      style='boss', spa='fire', spb='rush', speed=5, power=3, proj='bolt',
                      alt={BLUE: RED, MAGENTA: GREEN}, country='?', stage=8),
}
ROSTER = ['kenji', 'rosa', 'brody', 'mei', 'volkov', 'condor', 'somchai', 'ravi', 'zarkon']
