; =====================================================================
;  vars.asm - RAM layout (not part of the saved binary)
; =====================================================================

        org VARBASE
vars_start:
seed            ds 2
fieldcnt        ds 1
lastframe       ds 1
drops           ds 1
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

key_pause       ds 1
key_quit        ds 1
joy_on          ds 1              ; MZ-1X03 joystick switched on (J on the title)
joy_bits        ds 1              ; K_ bits read from it last frame
joy_kprev       ds 1              ; J held last field
joy_disp        ds 1
joy_tmp         ds 1
joy_edge        ds 2              ; 8253 counter 1 when VBLANK began              ; E008h seen outside VBLANK (0 bit = button held)
fe_prev         ds 1
fe_rep          ds 1
keys            ds 1
keys_prev       ds 1
latch           ds 1
pref            ds 1
tick_keys       ds 1
pause_prev      ds 1
hud_dirty       ds 1

turbo           ds 1                ; test harness: no frame waits, a tick every frame
tick_dir        ds 1                ; test harness: the keys for this tick
ticks           ds 2
cseed           ds 2                ; the cave's random numbers
shower_rate     ds 1
shower_haz      ds 1
shower_left     ds 1
tps             ds 1                ; ticks per cave second
sec_ctr         ds 1
pl_push         ds 1
pl_push_old     ds 1
demo            ds 1
demo_abort      ds 1
demo_cave       ds 1
demo_ticks      ds 2
quit            ds 1

; game
score           ds 3
life_acc        ds 2
lives           ds 1
level           ds 1
start_cave      ds 1
start_sel       ds 1                ; which wing the title starts in
attract_n       ds 1                ; which tour of the front end is next
pic_t           ds 1                ; picture pages: field counter
wk_tab          ds 2                ; the walker: its path, step, look
wk_i            ds 1
wk_glyph        ds 1
wk_attr         ds 1
wk_prev         ds 2                ; the cell it stands on (0 = none) and what was there
wk_sch          ds 1
wk_sat          ds 1
tw_ptr          ds 2                ; the typewriter
tw_de           ds 2
tw_row          ds 1
ge_tab          ds 2                ; the guide page being shown
ge_ctl          ds 2
ge_title        ds 2
cave_no         ds 1
cave_hdr        ds 2
cave_result     ds 1
hiscore_rank    ds 1

; cave
need            ds 1
got             ds 1
dval            ds 1
xval            ds 1
ctime           ds 1
speed           ds 1
exit_open       ds 1
exit_addr       ds 2
magic_state     ds 1                ; 0 dormant, 1 active, 2 spent
magic_time      ds 1
amoeba_slow     ds 1
amoeba_fast     ds 1
amoeba_cnt      ds 2
amoeba_grow     ds 1
amoeba_conv     ds 1                ; 1 -> boulders, 2 -> diamonds
inbox_time      ds 1
timeout         ds 1
flash           ds 1
end_time        ds 1
anim            ds 1
tick_last       ds 1
sec_last        ds 1
scan_ptr        ds 2
scan_rows       ds 1
cave_w          ds 1                ; cave size (40-64 x 22-32)
cave_h          ds 1
cave_wskip      ds 1                ; 64 - w
unp_rows        ds 1
unp_cols        ds 1
view_x          ds 1                ; top-left cave cell on screen
view_y          ds 1
view_ptr        ds 2                ; CAVE + view_y * 64 + view_x
glide_x         ds 1                ; scrolling: -1, 0, +1 cell per frame
glide_y         ds 1

; player
pl_addr         ds 2
pl_off          ds 2
pl_dir          ds 1
pl_face         ds 1
pl_moved        ds 1
pl_dead         ds 1
pl_exit         ds 1
pl_frozen       ds 1
key_got         ds 1                ; the cave's key is taken: locks open
shade_ph        ds 1                ; shades move when 1 (every other tick)

; demo replay
demo_ptr        ds 2
demo_left       ds 1
demo_kv         ds 1

; render
lfsr            ds 2
dis_mode        ds 1

; front end
page_fx         ds 2
page_len        ds 1
page_restart    ds 1
scroll_ptr      ds 2
scroll_tick     ds 1
logo_phase      ds 1
dig_x           ds 1
dig_t           ds 1
ge_ptr          ds 2
hs_ptr          ds 2
hs_pos          ds 1
hs_i            ds 1
hs_ent          ds 2
PBUF            ds 80
DIGBUF          ds 120
HISCORES        ds 8*8              ; name[3], score[3] BCD (lo first), cave, level
vars_end:
        ASSERT vars_end <= QUEUE
