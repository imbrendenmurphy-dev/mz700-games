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
noise_on        ds 1
noise_band      ds 1
cur_div         ds 2
snd_mute        ds 1
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

; game
keys            ds 1
frame           ds 1
state           ds 1                ; 0 flying, 1 docked, 2 destroyed
state_t         ds 1
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
cargo           ds 10
stock           ds 10
price           ds 20
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
holdmax         ds 1
legal           ds 1
mkey            ds 1
jkey            ds 1
prevx           ds 1
title_t         ds 1
title_ship      ds 1
hit_obj         ds 2
hit_z           ds 2
ai_ds           ds 2
ai_dr           ds 2
ai_dn           ds 2
loc_x           ds 1
loc_y           ds 1
loc_z           ds 1
deb_r           ds 1
bar_last        ds 8
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
vars_end:
