; =====================================================================
;  vars.asm - RAM layout (not part of the saved binary)
; =====================================================================

        org VARBASE
vars_start:
seed            ds 2
fieldcnt        ds 1
lastframe       ds 1
drops           ds 1
turbo           ds 1                ; test harness: no frame waits
autoplay        ds 1                ; test harness: the pilot plays real games
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
sfx_pop         ds 6                ; pop effect, pitch set per combo

key_extra       ds 1
fe_prev         ds 1
fe_rep          ds 1
nent            ds 1
onent           ds 1
ndirty          ds 1
big_out         ds 2
big_solid       ds 1
tmp_slots       ds 2

; options and front end
difficulty      ds 1                ; 0 easy, 1 normal, 2 hard
demo_act        ds 1
demo_key        ds 1
anim_fe         ds 1
page_len        ds 1
page_fx         ds 2
t_msg           ds 1
t_msgt          ds 1
t_bal           ds 12               ; title: rising balloons (row, col) x 6
t_wink          ds 1
hs_rank         ds 1
hs_pos          ds 1
hs_ptr          ds 2
hs_new          ds 1
hs_prevkey      ds 1
hiscores        ds 5*6              ; name[3], score BCD[3] (high byte first)
strbuf          ds 34
tmpx            ds 1
tmpy            ds 1
tmpc            ds 1

; ---------------------------------------------------------------- game
GAMEVARS:
demo            ds 1
demo_timer      ds 2
inp             ds 1
inp_prev        ds 1
inp_new         ds 1
score           ds 3                ; BCD, high byte first
lives           ds 1
act             ds 1
encore          ds 1
nextlife        ds 1                ; BCD ten-thousands for the next extra life
gameresult      ds 1                ; 0 act clear, 1 game over, 2 quit/abort
ACTVARS:                            ; cleared for each act
pal             ds 12               ; bg, b0, b1, b2, a1, a2, hat, body, plank, hudfg, bomb, seam
actflags        ds 1
nrows           ds 1
balloons_left   ds 1
balloons_total  ds 1
misses_act      ds 1
combo           ds 1
streak          ds 1
see_x           ds 2                ; pivot, 8.8 units
see_v           ds 2
see_hw          ds 1                ; half width in units (12 or 20)
tilt            ds 1                ; 0 = left end low, 1 = right end low
flipcool        ds 1
flipanim        ds 1
piestick        ds 1
pw_wide         ds 1                ; power-up timers (these four in order)
pw_slow         ds 1
pw_x2           ds 1
pw_umb          ds 1
pw_net          ds 1
tickpar         ds 1
endtimer        ds 1
bonus_time      ds 2
bonus_pops      ds 1
spawn_t         ds 1
rowphase        ds 1
bob             ds 1
ai_target       ds 1
ai_t            ds 1
ai_x            ds 2
ai_y            ds 2
ai_vx           ds 2
respawn_side    ds 1
hud_req         ds 1                ; 1 = redraw the HUD
poleph          ds 1
rowleft         ds 1
mult            ds 1
nomiss          ds 1
fw_n            ds 1
fw_try          ds 1
pb_col          ds 1
pb_style        ds 1
cel_t           ds 1
prev_cy         ds 1
clown0          ds 16
clown1          ds 16
rows            ds 4*16
slots           ds 4*20             ; per row, per slot: 0 popped, else type + 1
parts           ds NPARTS*PT_SIZE
popups          ds NPOPS*PU_SIZE
tokens          ds 3*8
freeb           ds 12*8
monkey          ds 8
pies            ds 3*8
hoop            ds 4
GAMEVARS_END:
vars_end:
