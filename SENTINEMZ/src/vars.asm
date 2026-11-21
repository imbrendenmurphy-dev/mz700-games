; =====================================================================
;  vars.asm - RAM layout (not part of the saved binary)
; =====================================================================

        org VARBASE
vars_start:
; ---- system / sound (names shared with sys.asm, sound.asm)
seed            ds 2
fieldcnt        ds 1
lastframe       ds 1
drops           ds 1
turbo           ds 1                ; test harness: skip waits
autoplay        ds 1                ; 1 = the AI pilot plays (demo)
noise_on        ds 1
noise_band      ds 1
cur_div         ds 2
snd_mute        ds 1
music_off       ds 1
sfxptr          ds 2
sfxpri          ds 1
mus_on          ds 1
mus_song        ds 2
mus_ord         ds 2
mus_row         ds 2
mus_tick        ds 1
mus_speed       ds 1
mus_fx          ds 1
mus_arp         ds 1
lead_note       ds 1
lead_age        ds 1
bass_note       ds 1
bass_age        ds 1
drum_kind       ds 1
drum_age        ds 1
key_extra       ds 1
fe_prev         ds 1
fe_rep          ds 1

; ---- game state
island          ds 1
start_island    ds 1
best_island     ds 1
energy          ds 1
score           ds 2
ptile           ds 2                ; player's tile
heading         ds 1                ; 0..31 (0 = north, clockwise)
pitch           ds 1                ; 0 up, 1 level, 2 down
beam            ds 1                ; sector 0..7 lit by the Lantern
beamcode        ds 1                ; 8 | beam
beam_t          ds 2                ; fields to the next beam step
beam_period     ds 2
drain_t         ds 1
lit             ds 1                ; the Lantern sees the player now
warned          ds 1
lant_t          ds 2
lant_cairns     ds 1
lamp_col        ds 1
lantx           ds 1
lanty           ds 1
lamph           ds 1
nwisps          ds 1
wisp_t          ds 2
result          ds 1                ; play_island result
need_render     ds 1
idle_t          ds 2                ; fields without input (demo timeout)
demo_t          ds 2
msg_t           ds 1
absorbed        ds 1                ; count this island
built           ds 1
moves           ds 1
hint_t          ds 1
paused          ds 1

; ---- cursor / target
ccx             ds 1                ; cursor cell 0..39
ccy             ds 1                ; 0..20
cur_char        ds 1                ; what the cursor covers
cur_attr        ds 1
cur_on          ds 1
tgt_t           ds 2                ; picked tile
tgt_kind        ds 1                ; 0 none, 1 ground, 2 object
tgt_ok          ds 1                ; tile surface visible
pk_a            ds 2
lastletter      ds 1
rc_s            ds 1
rcx_a           ds 2                ; recast step vectors: x for dz 1/2, 1, 2 ...
rcx_b           ds 2
rcx_c           ds 2
rcy_a           ds 2                ; ... then y (6 bytes later)
rcy_b           ds 2
rcy_c           ds 2
rpx             ds 2
rpy             ds 2
wsrc            ds 2
wdst            ds 2
wpx             ds 1
wpy             ds 1
psec            ds 1
p5attr          ds 1
mrow            ds 1
mtx             ds 1
mty             ds 1
tl_attr         ds 1
tl_row          ds 1
tl_col          ds 1
tl_r            ds 1
pn_y            ds 1
pn_top          ds 1
demo_n          ds 1
last_ctr        ds 2

; ---- AI pilot
ai_state        ds 1
ai_t            ds 1
ai_turns        ds 1
ai_goal         ds 2
ai_act          ds 1
ai_cx           ds 1
ai_cy           ds 1
ai_best         ds 2
ai_bests        ds 2
ai_plan         ds 1
ai_wait         ds 1
ai_want         ds 1
ai_fail         ds 2
ai_here         ds 1
ai_k            ds 1
ai_wt           ds 1
ai_ht           ds 1

; ---- renderer
hor             ds 1
eye             ds 1
col             ds 1
colbase         ds 2
ybuf            ds 1
yb16            ds 2
ys_t            ds 1
mb_t            ds 1
cdx             ds 2
cdy             ds 2
ppx             ds 2
ppy             ds 2
d_x0            ds 2                ; (8 words copied from DIRTAB)
d_y0            ds 2
d_dx            ds 2
d_dy            ds 2
f_x             ds 2
f_y             ds 2
r_x             ds 2
r_y             ds 2
; objects
nobj            ds 1
olorder         ds MAXOL
pt_t            ds 2
pdx             ds 1
pdy             ds 1
pz              ds 2
px16            ds 2
psc             ds 2
pcol            ds 2
prow            ds 2
dslot           ds 1
dent            ds 2
dobj            ds 1
dbase           ds 2
dbaseh          ds 1
ddep            ds 1
dsc             ds 2
dcol            ds 2
sw              ds 1
shh             ds 1
sdat            ds 2
ow              ds 1
oh              ds 1
sstep           ds 2
ox0             ds 2
oy0             ds 2
sv              ds 2
su              ds 2
oy              ds 2
ox              ds 2
orow            ds 1
ocol            ds 1
srow            ds 2
rowcnt          ds 1
ystart          ds 1
dmark           ds 1
ROWT            ds VIEW_H
; present
vp              ds 2
prow_c          ds 1
py2             ds 1
pcp             ds 2

; ---- generator
rseed           ds 2
gp              ds 2
gq              ds 2
gc              ds 2
gx              ds 1
gy              ds 1
wx0             ds 1
wx1             ds 1
wy0             ds 1
wy1             ds 1
gptr            ds 2
acc             ds 2
lo              ds 1
span            ds 1
cnt             ds 16
h00             ds 1
h10             ds 1
h01             ds 1
h11             ds 1
shd             ds 1
Lc              ds 2
Rc              ds 2
dL              ds 2
dR              ds 2
vv              ds 2
dv              ds 2
fp              ds 2
tp              ds 2
rp              ds 2
bestv           ds 1
bestty          ds 1
pobj            ds 1
st              ds 2
targh           ds 1
sdx             ds 1
sdy             ds 1
nsteps          ds 1
lsx             ds 2
lsy             ds 2
lsh             ds 2
lhv             ds 2
lhh             ds 1

; ---- front end
fe_page         ds 1
fe_t            ds 2
hs_name         ds 3
hs_pos          ds 1
txtbuf          ds 41
fx_t            ds 1
fx_x0           ds 1
fx_y0           ds 1
fx_x1           ds 1
fx_y1           ds 1
HISCORES        ds 8*6              ; 8 entries: name[3], island, score lo, hi
STEPD           ds NSTEP*4
OLIST           ds MAXOL*OLSZ
vars_end:
        ASSERT vars_end <= 0CD00h
