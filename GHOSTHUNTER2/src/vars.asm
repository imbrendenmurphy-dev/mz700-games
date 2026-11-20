; =====================================================================
;  vars.asm - RAM layout (not part of the saved binary)
; =====================================================================

        org VARBASE
vars_start:
; ---- system / sound (shared with sys.asm, sound.asm)
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
sirenmode       ds 1
sirenspd        ds 1
sirenpos        ds 1

key_pause       ds 1
key_digit       ds 1
speedsel        ds 1                ; 0 SLOW, 1 NORMAL, 2 FAST
speedshow       ds 1
key_quit        ds 1
key_sound       ds 1
fe_prev         ds 1
fe_rep          ds 1
inp             ds 1                ; K_ bits this frame
inp_prev        ds 1
inp_new         ds 1                ; newly pressed this frame
pause_prev      ds 1
sound_prev      ds 1
framecount      ds 2
turbo           ds 1                ; test hook: skip frame waits

; ---- render
ov_draw         ds 2                ; overlay list on screen
ov_build        ds 2                ; overlay list being built
dirty_n         ds 1
rc_row          ds 1                ; recolour: next grid row (0 = idle)
palette         ds 1                ; 0 normal, 1 power
PALCUR          ds 9                ; attr per cell class (current palette)
CLSG            ds 9                ; glyph per cell class (0 = from LOOK)
pal_norm        ds 2                ; this maze's palettes
pal_power       ds 2
hud_dirty       ds 1
lastbar         ds 1
lastbarc        ds 1
lastlabel       ds 2

; ---- game state
demo            ds 1
demo_abort      ds 1
demotim         ds 2
godmode         ds 1
result          ds 1
level           ds 1
lives           ds 1
score           ds 3                ; BCD, most significant first
hiscore         ds 3
extragiven      ds 1
pausing         ds 1
quit_req        ds 1
firstlife       ds 1
mazeidx         ds 1
mstyle          ds 1
mname           ds 2
roundtype       ds 1                ; 0 normal, 1 buffet, 2 panic
roundtype_lbl   ds 2
roundtim        ds 2
intermission    ds 1
pellets         ds 2
pellets_total   ds 2
eaten           ds 2
spawned         ds 1
pspeed          ds 1
gspeed          ds 1
fspeed          ds 1
frighttime      ds 1
dizzy_chance    ds 1
frighttim       ds 1
frightmax       ds 1
freezetim       ds 1
speedtim        ds 1
x2tim           ds 1
shieldtim       ds 1
supertim        ds 1
decoytim        ds 1
decoyx          ds 1
decoyy          ds 1
pumax           ds 1
itemtim         ds 1
itemspr         ds 1
chasemode       ds 1
modephase       ds 1
modetim         ds 2
hitstop         ds 1
chain           ds 1
streak          ds 1
streaktim       ds 1
elroy           ds 1
wakaflip        ds 1
energvis        ds 1
televis         ds 1
pvisible        ds 1
ghostsvis       ds 1
strobe          ds 1
best            ds 1
bestd           ds 1
bestdir         ds 1
pdir_           ds 1
aidir           ds 1
aiscore         ds 1
aitx            ds 1
aity            ds 1
npx             ds 1
npy             ds 1
npd             ds 1
burstcol        ds 1
pop_attr        ds 1
ntele           ds 1
tele_list       ds 8
nenerg          ds 1
energ_list      ds 16
popups          ds 4*4              ; timer, x, y, string index
particles       ds 12*8             ; x(4.4), y(4.4), dx, dy, life, colour, glyph, pad
actors          ds 16*5
readymsg        ds 2                ; text shown under the house (0 = none)
readycol        ds 1

; ---- front end
attr_t          ds 2
anim            ds 1
msgidx          ds 1
page_t          ds 2
hs_rank         ds 1
hs_pos          ds 1
nameb           ds 4
HITAB           ds 5*6              ; score[3] BCD (msb first), name[3]
TSPR            ds 4*20             ; title/cutscene sprite cells drawn last frame
tspr_n          ds 1
cut_pt          ds 1
cut_px          ds 1
cut_ps          ds 2

OVL0            ds 1+4*OVMAX
OVL1            ds 1+4*OVMAX
DIRTY           ds 2*DIRTYMAX
vars_end:
        ASSERT vars_end <= GRID
