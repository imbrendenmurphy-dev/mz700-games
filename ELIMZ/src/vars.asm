; =====================================================================
;  vars.asm - RAM layout (not part of the saved binary)
; =====================================================================

        org VARBASE
vars_start:
seed            ds 2
fieldcnt        ds 1
lastframe       ds 1
last_ctr        ds 2
drops           ds 1
turbo           ds 1                ; test harness: no frame waits
autoplay        ds 1                ; test harness: keys from demo_keys
demo_keys       ds 1
snd_vars:                           ; cleared by snd_init
snd_mode        ds 1                ; always 0 now (one output)
snd_mute        ds 1
noise_on        ds 1
nz_seed         ds 1
cur_div         ds 2
hw_par          ds 1
snd_clk         ds 2
snd_ph          ds 1
trk_on          ds 1
trk_rep         ds 1
trk_cur         ds 1
trk_ptr         ds 2
trk_start       ds 2
hslot0          ds HS_SIZE
hslot1          ds HS_SIZE
snd_vars_end:
fx_pal          ds 2
fx_n            ds 1
fx_dir          ds 1
fx_ph           ds 1
fx_last         ds 9
key_extra       ds 1
joy_on          ds 1                ; the MZ-1X03 joystick (joy.asm)
joy_req         ds 1
joy_skip        ds 1
joy_run         ds 1
joy_end         ds 1
joy_rel         ds 1
joy_rawend      ds 1
joy_rawrel      ds 1
joy_btn         ds 1
joy_sw2         ds 1
joy_dirs        ds 1
joy_vref        ds 2
joy_fl          ds 2
joy_len         ds 2
joy_lo          ds 2
joy_hi          ds 2
joy_sum         ds 4
fe_prev         ds 1
fe_rep          ds 1

; game
keys            ds 1
frame           ds 1
state           ds 1                ; 0 flying, 1 docked, 2 destroyed
speed           ds 1
shield          ds 1
energy          ds 1
heat            ds 1
lcd             ds 1
laser_on        ds 1
hitflash        ds 1
flash_on        ds 1
spawn_t         ds 1
msg_t           ds 1
kills           ds 1
credits         ds 3
cr_dirty        ds 1
cv              ds 3
cvt             ds 2
fuel            ds 1
cur_sys         ds 1
target_sys      ds 1
arrive          ds 1
hyper_t         ds 1
hkey            ds 1
cargo           ds NGOODS+1             ; (the last: fuel, for the market)
stock           ds NGOODS+1
price           ds 2*(NGOODS+1)
mkt_sel         ds 1
mk_row          ds 1
mk_attr         ds 1
mk_e3           ds 1
mk_i            ds 1
mk_q            ds 1
mk_base         ds 2
mk_p            ds 2
ch_x            ds 1
ch_y            ds 1
nr_best         ds 1
nr_sys          ds 1
msgbuf          ds 40
seekers         ds 1
has_jammer      ds 1                ; has_jammer..has_booster: equipment 1..4
has_twin        ds 1
has_pod         ds 1
has_booster     ds 1
has_scoop       ds 1
has_autodock    ds 1
has_fscoop      ds 1                ; (the has_* flags run on: equipment 1..7)
holdmax         ds 1
legal           ds 1
mkey            ds 1
jkey            ds 1
prevx           ds 1
title_t         ds 1
title_ship      ds 1
title_ang       ds 1
NTSTARS         equ 14
tstars          ds 2*NTSTARS
hit_obj         ds 2
hit_z           ds 2
ai_ds           ds 2
ai_dr           ds 2
ai_dn           ds 2
loc_x           ds 1
loc_y           ds 1
loc_z           ds 1
deb_r           ds 1
att_t           ds 2
demo_t          ds 2
pl_best         ds 2
pl_obj          ds 2
pl_z            ds 2
pl_x            ds 2
pl_y            ds 2
pl_thr          ds 2
gal_ptr         ds 2
gal_t           ds 1
gal_col         ds 1
autodock        ds 1
ambush          ds 1
load_req        ds 1
tape_ok         ds 1
pk_dir          ds 1
save_buf        ds SAVE_LEN
bar_last        ds 8
rp_col          ds 1
; hidden.asm
nfc             ds 1
cs_k            ds 1
cwv             ds 6
mcp             ds 2
macc            ds 2
efp             ds 2
ed0             ds 2
ef0             ds 2
hs_mode         ds 1
pl_on           ds 1
pl_r            ds 1
pl_cx           ds 2
pl_cy           ds 2
pl_len          ds 1
pl_ox           ds 1
pl_oy           ds 1
pl_w            ds 1
pl_a0           ds 2
pl_a1           ds 2
pl_b0           ds 2
pl_b1           ds 2
vl_max          ds 1
sunv            ds 6
vtb_s           ds 1
oc_rs           ds 2
pl_mode         ds 1
pl_col          ds 1
sun_col         ds 1
sun_var         ds 1
sun_x           ds 1
sun_y           ds 1
mf_m1           ds 1
mf_e            ds 1
f_cx            ds 1
f_cy            ds 1
f_dx            ds 1
f_dy            ds 1
f_y             ds 1
f_ady           ds 1
f_w             ds 1
f_k             ds 1
f_a0            ds 1
f_a1            ds 1
f_b0            ds 1
f_b1            ds 1
f_base          ds 2
f_rm            ds 1
f_m0            ds 1
f_m1            ds 1
f_e             ds 1
f_s             ds 1
pz_mute         ds 1
hull            ds 1                ; ships.asm: the hull we fly
max_fuel        ds 1                ; its figures (apply_hull):
max_speed       ds 1
seek_max        ds 1
armour          ds 1
sh_step         ds 1
hull_rank       ds 1
fuel_price      ds 1
fuel_stock      ds 1
fb_amt          ds 1
yd_p            ds 2
sun_d           ds 2
temp            ds 1
sun_msg         ds 1
sun_dbl         ds 1
jk_note         ds 1
ui_t            ds 2
ui_f            ds 2
ui_s            ds 1
hp_timed        ds 1
ui_buf          ds 32
view            ds 1                ; 0 front, 1 rear, 2 left, 3 right
fk_prev         ds 1
xf_m            ds 1
xf_x            ds 2
xf_z            ds 2
lc_gx           ds 1
lc_gy           ds 1
lc_bd           ds 1
si_save         ds 12
tn_f            ds 1
tn_z            ds 1
tn_p            ds 2
tn_d            ds 2
TN_X            ds 12               ; this ring's corners, x then y,
TN_Y            ds 12               ; then the last ring's (struts)
TN_PX           ds 24
comp_addr       ds 2
numbuf          ds 6

; maths scratch
md_c            ds 2
md_sign         ds 1
rp              ds 2
rq              ds 2
rnp             ds 2
rot_k           ds 1
rot_k2          ds 1
ro1             ds 1
ro2             ds 1
rb1             ds 1
rb2             ds 1
tvec            ds 6
tin             ds 6
dbx             ds 1
dby             ds 1
dbz             ds 1
acc             ds 2

; projection / lines
vx_             ds 2
vy_             ds 2
vz_             ds 2
tx              ds 2
ty              ds 2
tz              ds 2
psx             ds 2
psy             ds 2
lx0             ds 2
ly0             ds 2
lx1             ds 2
ly1             ds 2
ex_             ds 2
ey_             ds 2
fx_             ds 2
fy_             ds 2
oc0             ds 1
oc1             ds 1
clipn           ds 1
ldx             ds 1
ldy             ds 1
lsx             ds 1
lsy             ds 1
ccx             ds 2
ccy             ds 2
cr_x            ds 1
cr_y            ds 1
cr_d            ds 2
cpx1            ds 2
cpx2            ds 2
cpy1            ds 2
cpy2            ds 2

; models
mdl             ds 2
mrad            ds 1
mtx             ds 9
nv              ds 1
ne              ds 1
vi              ds 1
ea              ds 1
eb              ds 1
outa            ds 1
num_            ds 2
TVX             ds 48
TVY             ds 48
TVZ             ds 48
TSX             ds 48
TSY             ds 48

; world
planet          ds 6
dust            ds 6*NDUST
objects         ds MAXOBJ*OBJSZ
killer          ds 2                ; fx.asm: the death camera
kbest           ds 2
cam_d           ds 2
frags           ds NFRAG*FRSZ
gl_w            ds 1                ; screens.asm: glinting
vars_end:
