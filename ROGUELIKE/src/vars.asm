; =====================================================================
;  vars.asm - variables (cleared at power-on)
; =====================================================================
vars_start:
seed            ds 2
fieldcnt        ds 1
framecnt        ds 1
last_ctr        ds 2
keymat          ds 10
keynew          ds 10
keyacc          ds 10
pn_w            ds 1
numbuf          ds 6

snd_vars:
snd_mode        ds 1
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

; light and view
cl_org          ds 2
sl_y            ds 1
sl_x            ds 1
sl_n            ds 1
sl_dy           ds 1
sl_base         ds 2
vx              ds 1
vy              ds 1
viewmap         ds 2
torch           ds 1
last_torch      ds 1
torch_fl        ds 1
last_fl         ds 1
torch_hue       ds 1
ov_g            ds 1
ov_a            ds 1
ov_vx           ds 1
ov_vy           ds 1
need_fov        ds 1
rp_y            ds 1
roll_row        ds 1
dirty_lo        ds VIEWH
dirty_hi        ds VIEWH

; particles
part_next       ds 2
part_life       ds 1
bu_kind         ds 1
fe_emb          ds 12

; generation
g_kind          ds 9
g_rooms         ds 36
g_vis           ds 9
g_need          ds 1
g_have          ds 1
cb_cell         ds 1
cb_room         ds 2
cb_size         ds 2
cb_n            ds 1
cb_x            ds 1
cb_y            ds 1
jc_x2           ds 1
jc_y2           ds 1
sp_slot         ds 1
sp_ptr          ds 2
sp_x            ds 1
sp_y            ds 1
sp_w            ds 1
sp_h            ds 1
sp_src          ds 2
dc_room         ds 2
dc_size         ds 2
g_own           ds 9
g_nmerge        ds 1
g_big           ds 1
g_cell          ds 1
dg_step         ds 2
dg_x0           ds 1
dg_w            ds 1
pm_type         ds 1

; zones
zone            ds 1
zone_new        ds 1
zone_from       ds 1
zone_live       ds 1
zgen            ds 1
zvisit          ds 1
newgame         ds 1
zexits          ds NZONES*9

; monsters
monbase         ds 2
m_dist          ds 1
m_gdist         ds 1
m_best          ds 1
m_bdir          ds 1
m_dmg           ds 1
mo_elem         ds 1
mo_dead         ds 1
q_tail          ds 2
q_cnt           ds 1

; the player (cleared for each game)
pvars_start:
px              ds 1
py              ds 1
pmap            ds 2
hp              ds 1
hpmax           ds 1
mp              ds 1
mpmax           ds 1
plevel          ds 1
xp              ds 2
xpnext          ds 2
gold            ds 2
oil             ds 1
keys            ds 1
sigils          ds 1
spells          ds 1
curspell        ds 1
weapon          ds 1
armour          ds 1
pdef            ds 1
hpot            ds 1
mpot            ds 1
bombs           ds 1
smap            ds 1
stele           ds 1
poison          ds 1
regen           ds 1
kills           ds 2
turns           ds 2
dead            ds 1
won             ds 1
quit            ds 1
pflash          ds 1
score           ds 2
act_code        ds 1
act_dir         ds 1
dir_prev        ds 1
dir_rep         ds 1
bot_wait        ds 1
relic           ds 1                ; 1 = the sun-stone is carried
pvars_end:
ld_chg          ds 1

dbg_warp        ds 1
in_input        ds 1
dbg_seed        ds 2
mv_tile         ds 1
mv_flags        ds 1
demo            ds 1
bot_dir         ds 1
bot_dist        ds 1
bot_best        ds 1
bot_cell        ds 2
bot_zturns      ds 1

; items
pk_recp         ds 2
pk_type         ds 1
pk_qty          ds 1
pk_it           ds 2
m_num           ds 2

; status rows, messages
hud_dirty       ds 1
sg_bits         ds 1
sp_cost         ds 1
pnl_w           ds 1
bar_max         ds 1
bar_q           ds 1
mq_head         ds 1
mq_tail         ds 1
mq_age          ds 1
mqueue          ds 4*40
ot_attr         ds 1
banner_t        ds 1

; spells
bolt_dir        ds 1
bolt_kind       ds 1
bolt_dmg        ds 1
bolt_owner      ds 1
bolt_on         ds 1
bolt_x          ds 1
bolt_y          ds 1
bolt_g          ds 1
bolt_a          ds 1
bolt_light      ds 1
bolt_trail      ds 1
bolt_burst      ds 1
bolt_left       ds 1
relight_req     ds 1
flares          ds NFLARE*3
flash_t         ds 1
flash_x         ds 1
flash_y         ds 1
flash_l         ds 1
bl_dest         ds 2
bm_x            ds 1
bm_y            ds 1

; puzzles
pb_from         ds 2
beam_n          ds 1
beam            ds NBEAM*2

; folk
dlg_on          ds 1
dlg_dirty       ds 1
dlg_text        ds 2
shop_wares      ds 2
shop_greet      ds 2
bw_item         ds 1
bw_price        ds 2
shop_buf        ds 400

; front end
sweep_on        ds 1
sweep_pos       ds 1
sw_x            ds 1
sw_row          ds 1
lg_rows         ds 1
lg_ph           ds 1
lg_m            ds 1
pw_left         ds 2
records         ds NREC*RECSZ
vars_end:
