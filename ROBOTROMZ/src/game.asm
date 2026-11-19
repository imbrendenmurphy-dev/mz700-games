; =====================================================================
;  game.asm - game states, waves, HUD, captions, scoring
; =====================================================================

new_game:
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld hl,0
        ld (extacc),hl
        ld a,3
        ld (lives),a
        ld a,1
        ld (wave),a
        jp start_wave

; ---------------------------------------------------------------------
game_tick:
        call restore
        ld a,(state)
        add a,a
        ld e,a
        ld d,0
        ld hl,state_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

state_tab:
        dw tick_intro, tick_play, tick_dying, tick_clear, tick_over

; P (pause) = RETURN.  While paused nothing moves; Q quits to the title.
check_pause:
        ld a,(sedge)
        and KS_M
        jr z,.nm
        ld a,(sndon)            ; M toggles sound
        xor 1
        ld (sndon),a
        call snd_off
.nm:    ld a,(sedge)
        and KS_CR
        ret z
        ld a,(state)
        cp S_PLAY
        ret nz
        call snd_off
        ld hl,s_paused
        ld de,0*40+24
        ld c,70h
        call print_bg
.wait:  call wait_vblank
        call flush_bg
        call read_keys
        ld a,(sedge)
        and KS_Q
        jp nz,title
        ld a,(sedge)
        and KS_CR
        jr z,.wait
        ld hl,s_blank9
        ld de,0*40+24
        ld c,70h
        jp print_bg             ; (shows at the next flush)

; ---------------------------------------------------------------------
tick_intro:
        xor a
        ld (ai_on),a
        call update_objects     ; only counts down the materialising
        call place_objects
        call place_player
        ld hl,statetm
        dec (hl)
        ret nz
        call clear_caption
        ld a,S_PLAY
        ld (state),a
        ret

tick_play:
        ld a,1
        ld (ai_on),a
        call player_update
        call droid_speed
        call update_objects
        call place_objects
        call update_bullets
        call update_shots
        call player_collide
        call place_player
        call hud_update
        ld a,(state)
        cp S_PLAY
        ret nz
        ld a,(alive)
        or a
        ret nz
        ; wave cleared
        ld a,S_CLEAR
        ld (state),a
        ld a,150
        ld (statetm),a
        call clear_bullets
        ld hl,sfx_clear
        ld a,8
        call play_sfx
        ld hl,s_wave
        ld de,10*40+14
        ld c,61h
        call print_bg
        ld a,(wave)
        call print_wave_num
        ld hl,s_cleared
        call print_bg
        ld a,(saved)            ; full family bonus: saved some, lost none
        or a
        ret z
        ld a,(lost)
        or a
        ret nz
        ld de,5000h
        ld a,200
        call add_score
        ld hl,s_bonus
        ld b,12
        ld c,71h
        jp print_centre

tick_dying:
        xor a
        ld (ai_on),a
        call place_objects
        call place_player
        ld hl,statetm
        dec (hl)
        ret nz
        ld hl,lives
        dec (hl)
        call hud_lives
        ld a,(lives)
        or a
        jr z,.over
        jp respawn
.over:  ld a,S_OVER
        ld (state),a
        ld a,200
        ld (statetm),a
        ld hl,sfx_over
        ld a,9
        call play_sfx
        ld hl,s_gameover
        ld b,11
        ld c,21h
        jp print_centre

tick_clear:
        xor a
        ld (ai_on),a
        call update_objects     ; explosions and pop-ups finish
        call place_objects
        call place_player
        call hud_update
        ld hl,statetm
        dec (hl)
        ret nz
        ld hl,wave
        ld a,(hl)
        cp 99
        jp nc,start_wave
        inc (hl)
        jp start_wave

tick_over:
        call place_objects
        ld hl,statetm
        dec (hl)
        jr z,.done
        ld a,(statetm)
        cp 150
        ret nc
        ld a,(sedge)
        and KS_SPACE
        ret z
.done:  call update_hiscore
        jp title

update_hiscore:                 ; hiscore = max(hiscore, score)
        ld hl,score+2
        ld de,hiscore+2
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.new
        ret nz
        dec hl
        dec de
        djnz .c
        ret
.new:   ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        ret

; ---------------------------------------------------------------------
; set up wave (wave)
start_wave:
        call clear_objects
        call clear_bullets
        call clear_shots
        call snd_off
        ld hl,CX*256+80h
        ld (px),hl
        ld hl,CY*256+80h
        ld (py),hl
        xor a
        ld (rescues),a
        ld (saved),a
        ld (lost),a
        ld (firecd),a
        ld (pyflip),a
        ; difficulty stage: 3 for waves 1-2, 2 for 3-5, 1 for 6-10, 0 after
        ld a,(wave)
        ld b,3
        cp 3
        jr c,.st
        dec b
        cp 6
        jr c,.st
        dec b
        cp 11
        jr c,.st
        dec b
.st:    ld a,b
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,ease_tab
        add hl,de
        ld de,ease
        ld bc,8
        ldir
        ; wave table row: (wave-1) mod 20
        ld a,(wave)
        dec a
.m20:   cp 20
        jr c,.r
        sub 20
        jr .m20
.r:     ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; *10
        ld de,wavetab
        add hl,de
        ld (waverow),hl
        ; droid speed: (table delay + ease) * 6 ticks per step
        push hl
        ld de,9
        add hl,de
        ld a,(hl)
        ld hl,ease+E_DADD
        add a,(hl)
        ld b,a
        add a,a
        add a,b
        add a,a
        ld (droid_delay),a
        call reload_droid_tmr
        pop hl
        ; spawn everything
        ld de,spawn_types
        ld b,9
.sp:    push bc
        ld a,(de)
        ld c,a
        ld a,(hl)
        or a
        jr z,.sn
        ld b,a
.s1:    push bc
        push de
        push hl
        ld a,c
        call spawn_obj
        pop hl
        pop de
        pop bc
        djnz .s1
.sn:    inc hl
        inc de
        pop bc
        djnz .sp
        ; screen
        call draw_arena
        call hud_all
        call refresh_all
        ld hl,s_wave
        ld de,10*40+16
        ld c,61h
        call print_bg
        ld a,(wave)
        call print_wave_num
        call wave_subtitle
        ld b,12
        ld c,71h
        call print_centre
        ld a,S_INTRO
        ld (state),a
        ld a,130
        ld (statetm),a
        ld hl,sfx_wave
        ld a,8
        jp play_sfx

print_wave_num:                 ; A = wave, two digits at DE (attribute C)
        jp print_dec2

; HL = subtitle for the wave in (waverow)
wave_subtitle:
        ld ix,(waverow)
        ld hl,s_sub_brain
        ld a,(ix+3)
        or a
        ret nz
        ld hl,s_sub_tank
        ld a,(ix+5)
        or a
        ret nz
        ld hl,s_sub_crush
        ld a,(ix+2)
        cp 8
        ret nc
        ld hl,s_sub_orb
        ld a,(ix+4)
        or a
        ret nz
        ld hl,s_sub_first
        ld a,(wave)
        cp 1
        ret z
        ld hl,s_sub_droid
        ret

; respawn after a death: robots back to the edges, everything re-materialises
respawn:
        call clear_bullets
        call clear_shots
        ld hl,CX*256+80h
        ld (px),hl
        ld hl,CY*256+80h
        ld (py),hl
        ld ix,OBJ
        ld b,MAXOBJ
.l:     push bc
        ld a,(ix+OT)
        or a
        jr z,.nx
        cp T_SKULL
        jr nc,.kill             ; skulls, pop-ups, explosions go
        cp T_MOM
        jr nc,.mat              ; humans stay where they are
        call rand_pos_robot
        ld (ix+OX),c
        ld (ix+OY),b
.mat:   call set_materialise
        jr .nx
.kill:  ld (ix+OT),0
.nx:    ld de,OBJSZ
        add ix,de
        pop bc
        djnz .l
        call draw_arena
        call hud_all
        call refresh_all
        ld a,S_INTRO
        ld (state),a
        ld a,100
        ld (statetm),a
        ret

; ---------------------------------------------------------------------
clear_objects:
        xor a
        ld (objtop),a
        ld hl,OBJ
        ld de,OBJ+1
        ld bc,MAXOBJ*OBJSZ-1
        ld (hl),0
        ldir
        ret

clear_bullets:
        ld hl,EBUL
        ld de,EBUL+1
        ld bc,MAXEB*EBSZ-1
        ld (hl),0
        ldir
        ret

clear_shots:
        ld hl,SHOTS
        ld de,SHOTS+1
        ld bc,MAXSH*4-1
        ld (hl),0
        ldir
        ret

; arena: blue playfield inside a green/blue checked frame; HUD row black
draw_arena:
        ld a,A_ARENA
        call clear_bg
        ld hl,BGAT              ; HUD row: white on black
        ld b,40
.h:     ld (hl),70h
        inc hl
        djnz .h
        ld hl,BGCH+40           ; top and bottom frame lines
        ld de,BGCH+24*40
        ld b,40
.tb:    ld (hl),0D0h
        ld a,0D0h
        ld (de),a
        set 2,h
        set 2,d
        ld (hl),41h
        ld a,41h
        ld (de),a
        res 2,h
        res 2,d
        inc hl
        inc de
        djnz .tb
        ld hl,BGCH+2*40         ; sides
        ld de,39
        ld b,22
.sd:    ld (hl),0D0h
        set 2,h
        ld (hl),41h
        res 2,h
        add hl,de
        ld (hl),0D0h
        set 2,h
        ld (hl),41h
        res 2,h
        inc hl
        djnz .sd
        ret

; blank caption rows 10..12 back to the arena
clear_caption:
        ld hl,10*40+1
        ld de,00h*256+A_ARENA
        ld b,38
        call fill_bg
        ld hl,11*40+1
        ld b,38
        call fill_bg
        ld hl,12*40+1
        ld b,38
        jp fill_bg

; ---------------------------------------------------------------------
; HUD: score (0-5)  W nn (8-10)  HI hhhhhh (13-21)  lives (34-39)
hud_all:
        ld hl,s_w
        ld de,8
        ld c,60h
        call print_bg
        ld a,(wave)
        call print_dec2
        ld hl,s_hi
        ld de,13
        ld c,50h
        call print_bg
        ld hl,hiscore
        ld de,16
        call print_bcd6
        call hud_lives
hud_score:
        ld hl,score
        ld de,0
        ld c,70h
        jp print_bcd6

hud_lives:
        ld hl,39
        ld a,(lives)
        ld b,6
.l:     ld de,0070h
        or a
        jr z,.e
        dec a
        ld de,0CA70h            ; a little man per life
.e:     push af
        call bg_put
        pop af
        dec hl
        djnz .l
        ret

hud_update:
        ld a,(hudflag)
        or a
        ret z
        xor a
        ld (hudflag),a
        jr hud_score

; DE = points (4 BCD digits), A = points / 25 (for the extra-life count)
add_score:
        push af
        ld hl,score
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,1
        ld (hudflag),a
        pop af
        ld e,a
        ld d,0
        ld hl,(extacc)
        add hl,de
        ld (extacc),hl
        ld de,-1000             ; 25000 points = 1000 x 25
        add hl,de
        ret nc
        ld (extacc),hl
        ld a,(lives)
        cp 6
        jr nc,.full
        inc a
        ld (lives),a
.full:  call hud_lives
        ld hl,sfx_extra
        ld a,7
        jp play_sfx
