; =====================================================================
;  vars.asm - RAM layout (not part of the saved binary)
; =====================================================================

        org VARBASE
vars_start:
seed            ds 2
fieldcnt        ds 1
lastframe       ds 1
drops           ds 1
turbo           ds 1                ; test harness: no frame waits, a tick every frame
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
key_extra       ds 1                ; bit 0 SPACE, 1 R, 2 S, 3 L, 4 Y, 5 N, 6 H
fe_prev         ds 1
fe_rep          ds 1
keys            ds 1
latch           ds 1
pref            ds 1
xprev           ds 1

demo            ds 1
demo_abort      ds 1
replay_ptr      ds 2                ; input stream (demo / tests), 0 = keyboard
replay_cnt      ds 1
replay_dir      ds 1
quit            ds 1
game_over_flag  ds 1
won             ds 1
replay_done     ds 1
msg_ptr         ds 2
lfsr            ds 2
upk_end         ds 2
fx_region       ds 1
mx              ds 1
my              ds 1
mdx             ds 1
mdy             ds 1
mhor            ds 1
mver            ds 1
sdir            ds 1
anim_fe         ds 1
page_len        ds 1
page_allow_load ds 1
page_fx         ds 2
rec_pct         ds 1
mos_n           ds 1
mos_base        ds 2

; per tick
frame_ctr       ds 1
tick_dir        ds 1                ; 0 none, 1 left, 2 up, 3 right, 4 down
pl_addr         ds 2
pl_off          ds 2
pl_face         ds 1
pl_moved        ds 1
pl_dead         ds 1
pl_trans        ds 2                ; transporter stepped on (cell address) or 0
pl_switch       ds 2
pl_gate         ds 1
scan_ptr        ds 2
anim            ds 1
hud_dirty       ds 1
msg_time        ds 1
rbase           ds 2                ; WORLD + region * RSZ
theme           ds 1
cam_x           ds 1
cam_y           ds 1
cam_ptr         ds 2
done_flag       ds 1                ; every requirement met (the gate is open)
gems_left       ds 2
pieces_left     ds 1
crowns_left     ds 1
mons_left       ds 1
sec_frames      ds 1

; front end
page_restart    ds 1
scroll_ptr      ds 2
scroll_tick     ds 1
logo_phase      ds 1
rec_ptr         ds 2
rec_pos         ds 1
rec_i           ds 1
st_sel          ds 1
tape_err        ds 1
PBUF            ds 80
RECORDS         ds 8*8              ; name[3], percent, time h, m, s, deaths
vars_end:

; ---------------------------------------------------------------- saved state
        org SAVEVARS
save_start:
save_magic      ds 2
region          ds 1
pl_pos          ds 2                ; player cell within the region
entry_pos       ds 2                ; where the player came in (death / reset return here)
sw_flags        ds 2                ; switches thrown
tick            ds 2
score           ds 3
deaths          ds 2
ptime           ds 3                ; play time: hours, minutes, seconds
visited         ds 3                ; bit per region
save_end:
        ASSERT save_end <= WORLD
