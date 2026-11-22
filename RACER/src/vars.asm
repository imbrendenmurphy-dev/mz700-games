; =====================================================================
;  vars.asm - variables (part of the loaded image, so they start at 0)
; =====================================================================
; ---- system
polx:       db 0
duectr:     dw 0
drops:      dw 0
dt:         db 2
blit_sp:    dw 0        ; fields since the last frame
turbo:      db 0        ; tests: no waiting for the frame
kbuf:       ds 10
kprev:      ds 10
keys:       db 0        ; K_ bits this frame
skeys:      db 0        ; KS_ keys held
sedge:      db 0        ; KS_ keys newly pressed
joyfire:    db 0
joyon:      db 0
joycal:     db 0
joycx:      db 0
joycy:      db 0
joymv:      db 0
synced:     db 0
seed:       dw 0ACE1h
framecnt:   db 0

; ---- sound (snd_init clears snd_vars .. snd_vars_end)
snd_vars:
trk_ptr:    dw 0
trk_start:  dw 0
trk_rep:    db 0
trk_cur:    db 0
trk_on:     db 0
hslot0:     ds HS_SIZE
hslot1:     ds HS_SIZE
snd_clk:    dw 0
snd_ph:     db 0
hw_par:     db 0
noise_on:   db 0
nz_seed:    db 0
cur_div:    dw 0
snd_vars_end:
soundopt:   db 0        ; 0 music + effects, 1 effects, 2 off
curtune:    dw 0

; ---- camera and road
posf:       db 0        ; camera z: fraction, then units (16 a segment)
pos:        dw 0
px:         dw 0        ; camera / player x (world units, signed)
pxf:        db 0
bounce:     db 0
speed:      dw 0        ; 8.8 units per field

rd_frac:    db 0
rd_tmp:     db 0
rd_iy:      dw 0
rd_s0:      dw 0
rd_hcam:    dw 0
rd_cptr:    dw 0
rd_x:       dw 0
rd_dx:      dw 0
rd_ymax:    db 0
rd_n:       db 0
rd_seg:     dw 0
rd_s:       db 0
rd_y:       db 0
rd_cx:      dw 0
rd_hw:      db 0
rd_stripe:  db 0
rd_py:      db 0
rd_pcx:     dw 0
rd_phw:     db 0
st_ct:      db 0
fc_cx:      dw 0
fc_hw:      db 0
fc_bot:     db 0
fc_row:     db 0
fc_pl:      db 0
fc_pr:      db 0
fc_e:       ds 9
tt_a:       ds 9        ; run colours: stripe A, stripe B, flat
tt_b:       ds 9
tt_f:       ds 9
CPAIR:      ds 81       ; run colour pairs, [top*3 + bottom][run]
CPAIRF:     ds 81       ; (for two roads)
mp_ord:     dw 0
fc_spl:     db 0
st_spl:     db 0
rd_spl:     db 0
ghostend:   dw 0
fk_c1:      dw 0
fk_c2:      dw 0
st_q:       db 0
st_dcx:     dw 0
st_dhw:     dw 0
st_k:       db 0
st_cx:      dw 0
st_cxf:     db 0
st_hw:      db 0
st_hwf:     db 0
st_top:     db 0
st_yy:      db 0
fs_y:       db 0
fs_f:       db 0
fs_c:       db 0
fs_o1:      db 0
fs_o2:      db 0
fs_lo:      db 0
fs_pl:      db 0
fs_pr:      db 0
fs_e:       ds 10
fs_runs:    ds 10
XS:         ds 3*(NSAMP+2)  ; per segment ahead: curve x (word), clip

; ---- theme
pal_a:      ds 5        ; grass, rumble, road, line, line-on (stripe A)
pal_b:      ds 5        ; (stripe B)
pal_far:    db 0        ; distant land
th_obja:    db 0
th_objb:    db 0

; ---- course building
bc_run:     dw 0
bc_h:       dw 0
bc_seg:     dw 0
bc_gap:     db 0
bc_side:    db 0
bc_cnt:     db 0
bc_curv:    db 0
bc_slope:   db 0
bc_mode:    db 0
bc_tcurv:   db 0
bc_tslope:  db 0
crs_len:    dw 0

demo:       db 0
score:      ds 3
hudsnd:     db 0
hudscore:   db 0

; ---- sprites
CARN:       ds NSAMP+2  ; traffic per segment ahead (car + 1)
sd_n:       db 0
sd_optr:    dw 0
sd_seg:     dw 0
sd_type:    db 0
sd_ox:      dw 0
sd_s:       db 0
sd_img:     dw 0
sd_y:       db 0
sd_clip:    db 0
bl_w:       db 0
bl_src:     dw 0
bl_end:     db 0
bl_row:     db 0
bl_left:    db 0
bl_dl:      db 0
bl_dh:      db 0
bl_len:     db 0
bl_n:       db 0

; ---- car
carframe:   dw CARF_S
carshift:   db 0
carlast:    dw 0
carlshift:  db 0
carwant:    ds 4*14
carhave:    ds 4*14

; ---- sky
skypat:     dw 0
skyattr:    ds 7
skyforce:   db 0
skyx:       dw 0
sky_o1:     db 0
sky_o2:     db 0
sky_off:    db 0
sky_src:    dw 0

; ---- hud
hud_time:   db 0
hud_spd:    db 0
hud_boost:  db 0
hud_stage:  db 0
hud_prog:   db 0
msgnum:     db 0
msgptr:     dw 0
msgtime:    db 0
msgdraw:    db 0
msgcol:     db 0
msgbuf:     ds 44

; ---- game
gstate:     db 0
gtimer:     db 0
gameend:    db 0
ckeys:      db 0
dk:         db 0
offroad:    db 0
slope:      db 0
boost:      db 0
boosting:   db 0
slipping:   db 0
shake:      db 0
combo:      db 0
combot:     db 0
distacc:    db 0
crel:       dw 0
cdx:        dw 0
cadx:       dw 0
spawnt:     db 0
timesec:    db 0
tfield:     db 50
stage:      db 0
cdown:      db 0
node:       db 0
nodel:      db 0
noder:      db 0
nodet:      db 0
thptr:      dw 0
thname:     dw 0
carsmax:    db 0        ; from the theme (6 bytes, in this order)
spawngap:   db 0
carmin:     dw 0
carvar:     db 0
lanechg:    db 0
eng_r:      db 0
eng_on:     db 1

; ---- the computer driver
autopilot:  db 0        ; tests: it drives real games
demoquit:   db 0
ai_cv:      db 0
ai_lane:    dw 0
ai_tx:      dw 0
forkseg:    dw 0
forkshown:  db 0
fk_end:     db 0
fk_d:       dw 0
fk_side:    db 0
ai_fork:    db 0
forkbuf:    ds 44

; ---- front end
page:       db 0
ptick:      dw 0
titlemode:  db 0
titlego:    db 0
inrace:     db 0
hinew:      db 0FFh
hs_row:     db 0
hs_rank:    db 0
hs_col:     db 0
nameptr:    dw 0
nidx:       db 0
namebuf:    ds 10
routebits:  dw 0
goalhit:    db 0
paused:     db 0
quitflag:   db 0
demotm:     dw 0
rt_n:       db 0
fk_here:    dw 0
startnode:  db 0        ; tests: the first course
