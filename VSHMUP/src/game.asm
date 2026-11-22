; =====================================================================
;  game.asm - the game: stages, events, ticks, HUD, clear, game over
; =====================================================================

new_game:
        ld hl,0
        ld (score),hl
        xor a
        ld (score+2),a
        ld (loop),a
        ld (weapon),a
        ld (options),a
        ld (speed),a
        ld (shield),a
        ld (medal),a
        ld a,1
        ld (stage),a
        ld (power),a
        ld a,3
        ld (lives),a
        ld (bombs),a
        ld hl,0050h             ; first extra ship at 50,000
        ld (nextext),hl
        ld a,(startstage)       ; (tests: start further on)
        or a
        jr z,.s
        ld (stage),a
.s:     call player_reset
        jp start_stage

; clear everything that moves
clear_objects:
        ld hl,ENEMY
        ld de,ENEMY+1
        ld bc,MAXEN*ENSZ-1
        ld (hl),0
        ldir
        ld hl,EBUL
        ld de,EBUL+1
        ld bc,MAXEB*EBSZ+MAXSH*SHSZ-1   ; (bullets and shots)
        ld (hl),0
        ldir
        ld hl,ITEMS
        ld b,MAXIT*ITSZ
.i:     ld (hl),0
        inc hl
        djnz .i
        ld hl,FXL
        ld b,0
.f:     ld (hl),0
        inc hl
        djnz .f
        ld hl,SPAWN
        ld b,MAXSP*SPSZ
.s:     ld (hl),0
        inc hl
        djnz .s
        xor a
        ld (bossact),a
        ld (captm),a
        ld hl,0
        ld (cap1),hl
        ret

start_stage:
        call clear_objects
        call scn_clear
        ld a,(stage)            ; difficulty: stage - 1 + 2 per loop
        dec a
        ld b,a
        ld a,(loop)
        add a,a
        add a,b
        ld (diff),a
        ld c,a                  ; bullet speed and fire gaps
        add a,a
        add a,a
        add a,a
        add a,44h
        cp 78h
        jr c,.sp
        ld a,78h
.sp:    ld (bspd),a
        ld a,c
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,90
        sub b
        cp 30
        jr nc,.fg
        ld a,30
.fg:    ld (firegap),a
        ld a,G_PLAY
        ld (gstate),a
        ld a,1
        ld (nomiss),a
        ld hl,0
        ld (dist),hl
        ld a,1
        ld (scrollon),a
        ld (scrollcnt),a
        ld a,4
        ld (scrollper),a
        ld a,(stage)
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,stagetab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (evptr),hl
        call player_reset
        call draw_play_screen
        ld a,(skipto)           ; (tests: skip the stage up to 2 x this)
        ld l,a
        ld h,0
        add hl,hl
        ld (skipw),hl
        or a
        jr z,.ev
        ld (dist),hl
.sk:    ld hl,(evptr)           ; pass over the events before it
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(skipw)
        or a
        sbc hl,de
        jr z,.ev
        jr c,.ev
        ld hl,(evptr)
        inc hl
        inc hl
        ld a,(hl)
        ld bc,10
        cp 1
        jr z,.sb
        ld bc,5
        cp 2
        jr z,.sb
        ld bc,4
.sb:    ld hl,(evptr)
        add hl,bc
        ld (evptr),hl
        jr .sk
.ev:    call do_events
        ; caption: STAGE n and its name
        ld a,(stage)
        add a,'0'
        ld (stagecap+6),a
        ld a,(stage)
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,stagenames
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,stagecap
        ld a,75
        call caption
        ld hl,SFX_START
        ld a,5
        call sfx
        ld a,(stage)
        cp 3
        ld hl,TRK_STAGE
        jr c,.m
        ld hl,TRK_STAGE2
.m:     jp play_tune

stagecap: db "STAGE 1",0
stagenames: dw sn1,sn2,sn3,sn4,sn5
sn1:    db "OUTER RIM",0
sn2:    db "NEBULA",0
sn3:    db "STAR DOCK",0
sn4:    db "COMETS",0
sn5:    db "THE CORE",0

; the play screen: space, the HUD panel, the stars
draw_play_screen:
        ld a,A_SPACE
        call clear_bg
        call hud_init
        call stars_draw
        jp refresh_all

; ---------------------------------------------------------------------
; one 25 Hz tick of play
game_tick:
        call restore
        call snd_clock
        xor a
        ld (scrolled),a
        ld a,(scrollon)
        or a
        jr z,.ns
        ld hl,scrollcnt
        dec (hl)
        jr nz,.ns
        ld a,(scrollper)
        ld (hl),a
        call scroll_step
        ld hl,(dist)
        inc hl
        ld (dist),hl
        call do_events
        ld a,1
        ld (scrolled),a
.ns:    call stars_tick
        call snd_clock
        call spawners_tick
        call enemies_tick
        call snd_clock
        call boss_tick
        call items_tick
        call player_tick
        call snd_clock
        call shots_tick
        call bullets_tick
        call snd_clock
        call fx_tick
        call player_draw
        call state_tick
        jp hud_tick

; stage events due by now
do_events:
.l:     ld hl,(evptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(dist)
        or a
        sbc hl,de
        pop hl
        ret c                   ; not yet
        ld a,(hl)
        inc hl
        or a
        ret z                   ; (end)
        cp 1
        jr nz,.n2
        push hl
        call start_wave
        pop hl
        ld de,7
        jr .nx
.n2:    cp 2
        jr nz,.n3
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call add_piece
        pop hl
        jr .sv
.n3:    cp 3
        jr nz,.n4
        ld c,(hl)
        inc hl
        push hl
        ld a,T_TUR
        ld b,-1
        ld de,0
        call spawn_enemy
        pop hl
        jr .sv
.n4:    cp 4
        jr nz,.n5
        ld a,(hl)
        inc hl
        push hl
        xor a
        ld (scrollon),a
        pop hl
        push hl
        dec hl
        ld a,(hl)
        call boss_start
        pop hl
        jr .sv
.n5:    cp 5
        jr nz,.n6
        inc hl
        push hl
        ld hl,txt_warning
        ld de,0
        ld a,75
        call caption
        ld hl,SFX_WARN
        ld a,9
        call sfx
        ld hl,TRK_BOSS
        call play_tune
        pop hl
        jr .sv
.n6:    ld a,(hl)               ; 6: scroll speed
        inc hl
        ld (scrollper),a
.sv:    ld (evptr),hl
        jp .l
.nx:    add hl,de
        jr .sv

txt_warning: db "WARNING",0

; ---------------------------------------------------------------------
state_tick:
        ld a,(gstate)
        cp G_CLEAR
        jp z,clear_tick
        cp G_OVER
        jr z,over_tick
        ret

over_tick:
        ld hl,(overtm)
        dec hl
        ld (overtm),hl
        ld a,h
        or l
        ret nz
        ld a,1
        ld (gameend),a
        ret

game_over:
        ld a,G_OVER
        ld (gstate),a
        ld hl,150
        ld (overtm),hl
        ld hl,txt_game
        ld de,txt_over
        ld a,150
        call caption
        ld hl,TRK_OVER
        jp play_tune
txt_game: db "GAME",0
txt_over: db "OVER",0

; the boss is gone: the tally, then the next stage
stage_clear:
        ld a,G_CLEAR
        ld (gstate),a
        ld a,220
        ld (cleartm),a
        ld hl,txt_stage
        ld de,txt_clear
        ld a,90
        call caption
        ld hl,TRK_CLEAR
        call play_tune
        ; bonuses (tens, BCD): no miss 10,000; 1000 a bomb; 500 a medal level
        ld de,0
        ld a,(nomiss)
        or a
        jr z,.nm
        ld de,1000h
.nm:    ld (bon1),de
        ld a,(bombs)
        call bcd_x100
        ld (bon2),de
        ld a,(medal)
        call bcd_x50
        ld (bon3),de
        ret
txt_stage: db "STAGE",0
txt_clear: db "CLEAR",0

; A = n (0..9) -> DE = n * 100 (BCD tens: n0h 00h... = n * 1000 points)
bcd_x100:
        add a,a
        add a,a
        add a,a
        add a,a
        ld d,a
        ld e,0
        ret
; A = n (0..9) -> DE = n * 50 tens (500 points each)
bcd_x50:
        ld de,0
        or a
        ret z
        ld b,a
.l:     ld a,e
        add a,50h
        daa
        ld e,a
        ld a,d
        adc a,0
        daa
        ld d,a
        djnz .l
        ret

clear_tick:
        ld a,(cleartm)
        dec a
        ld (cleartm),a
        jr z,.next
        cp 160                  ; add the bonuses one at a time
        jr nz,.b2
        ld de,(bon1)
        call add_score
        ld hl,SFX_TALLY
        ld a,4
        call sfx
.b2:    ld a,(cleartm)
        cp 140
        jr nz,.b3
        ld de,(bon2)
        call add_score
        ld hl,SFX_TALLY
        ld a,4
        call sfx
.b3:    ld a,(cleartm)
        cp 120
        jr nz,.tl
        ld de,(bon3)
        call add_score
        ld hl,SFX_TALLY
        ld a,4
        call sfx
.tl:    ld a,(cleartm)
        cp 180
        ret nc
        cp 40
        ret c
        jp draw_tally
.next:  ld a,(stage)
        inc a
        cp 6
        jr c,.st
        ld a,(loop)             ; round again, harder
        inc a
        ld (loop),a
        ld a,1
.st:    ld (stage),a
        ld a,1
        ld (hudstage),a
        jp start_stage

; the tally lines, drawn as sprites
draw_tally:
        ld hl,tal1
        ld de,(bon1)
        ld b,16
        call .line
        ld hl,tal2
        ld de,(bon2)
        ld b,18
        call .line
        ld hl,tal3
        ld de,(bon3)
        ld b,20
.line:  push de
        ld c,3
        ld e,70h
        call text_spr
        pop de
        ld hl,numbuf            ; the value: 5 digits and a 0
        ld a,d
        call .two
        ld a,e
        call .two
        ld (hl),'0'
        inc hl
        ld (hl),0
        ld hl,numbuf
        ld c,19
        ld e,60h
        jp text_spr
.two:   push af
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        add a,'0'
        ld (hl),a
        inc hl
        pop af
        and 0Fh
        add a,'0'
        ld (hl),a
        inc hl
        ret
tal1:   db "NO MISS BONUS",0
tal2:   db "BOMB BONUS",0
tal3:   db "MEDAL BONUS",0

; HL = text, B = row, C = column, E = attribute: drawn as sprites this tick
text_spr:
.l:     ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push bc
        push de
        call asc2dc
        ld d,a
        xor a
        call put_one
        pop de
        pop bc
        pop hl
        inc c
        jr .l

; ---------------------------------------------------------------------
; RETURN pauses (Q quits to the title while paused); M changes the sound
check_keys:
        ld a,(demo)
        or a
        ret nz
        ld a,(sedge)
        and KS_M
        call nz,cycle_sound
        ld a,(sedge)
        and KS_CR
        ret z
        ; paused
        call mus_stop
        call sfx_stop
        ld hl,txt_paused
        ld b,12
        ld c,10
        ld a,70h
        call print_at
        call flush_bg
.p:     call wait_tick
        call read_keys
        ld a,(sedge)
        and KS_Q
        jr nz,.quit
        ld a,(sedge)
        and KS_CR
        jr z,.p
        ld hl,txt_unpause
        ld b,12
        ld c,10
        ld a,A_SPACE
        call print_at
        ld a,(soundopt)
        or a
        ret nz
        ld hl,(curtune)
        jp music
.quit:  ld a,1
        ld (gameend),a
        ld a,1
        ld (quitflag),a
        ret
txt_paused:  db " PAUSED ",0
txt_unpause: db "        ",0

; ---------------------------------------------------------------------
; HUD: the panel at columns 30..39
hud_init:
        ld b,PFH                ; the divider
        ld hl,PFW
.d:     push bc
        ld d,07Bh
        ld e,10h
        call bg_put
        ld bc,40
        add hl,bc
        pop bc
        djnz .d
        ld hl,hudtext
.t:     ld a,(hl)
        cp 0FFh
        jr z,.all
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        call print_at
        jr .t
.all:   ld a,1
        ld (hudscore),a
        ld (hudlives),a
        ld (hudbomb),a
        ld (hudpow),a
        ld (hudmed),a
        ld (hudstage),a
        ld (hudboss),a
        ld (hudsnd),a
        ld (hudhi),a
        ret

hudtext:
        db 0,32,60h,"NOVA",0
        db 1,33,50h,"STORM",0
        db 3,31,70h,"SCORE",0
        db 5,31,70h,"HI",0
        db 8,31,70h,"SHIPS",0
        db 10,31,70h,"BOMBS",0
        db 13,31,70h,"POWER",0
        db 15,31,70h,"SPEED",0
        db 16,31,70h,"OPT",0
        db 18,31,70h,"MEDAL",0
        db 21,31,70h,"STAGE",0
        db 0FFh

hud_tick:
        ld a,(hudscore)
        or a
        jr z,.h1
        xor a
        ld (hudscore),a
        ld hl,score
        ld de,4*40+32
        ld c,60h
        call print_score
        ; a new high score shows at once
        ld hl,score+2
        ld de,hiscore+2
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.newhi
        jr nz,.h1
        dec hl
        dec de
        djnz .c
        jr .h1
.newhi: ld a,(demo)
        or a
        jr nz,.h1
        ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        ld a,1
        ld (hudhi),a
.h1:    ld a,(hudhi)
        or a
        jr z,.h2
        xor a
        ld (hudhi),a
        ld hl,hiscore
        ld de,6*40+32
        ld c,50h
        call print_score
.h2:    ld a,(hudlives)
        or a
        jr z,.h3
        xor a
        ld (hudlives),a
        ld a,(lives)
        ld hl,9*40+31
        ld de,59h*256+0F0h      ; little ships (bank 2)
        call icons
.h3:    ld a,(hudbomb)
        or a
        jr z,.h4
        xor a
        ld (hudbomb),a
        ld a,(bombs)
        ld hl,11*40+31
        ld de,8Fh*256+0B0h      ; bombs: magenta balls (bank 2)
        call icons
.h4:    ld a,(hudpow)
        or a
        jr z,.h5
        xor a
        ld (hudpow),a
        call hud_power
.h5:    ld a,(hudmed)
        or a
        jr z,.h6
        xor a
        ld (hudmed),a
        ld a,(medal)
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,medtxt
        add hl,de
        push hl
        ld hl,19*40+32          ; clear the old value
        ld b,6
        ld de,A_SPACE
        call fill_bg
        pop hl
        ld de,19*40+32
        ld c,60h
        call print_bg
.h6:    ld a,(hudstage)
        or a
        jr z,.h7
        xor a
        ld (hudstage),a
        ld a,(stage)
        ld de,21*40+37
        ld c,70h
        call print_dec2
.h7:    ld a,(hudboss)
        or a
        jr z,.h8
        xor a
        ld (hudboss),a
        call hud_boss
.h8:    ld a,(hudsnd)
        or a
        ret z
        xor a
        ld (hudsnd),a
        ld a,(soundopt)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,sndtxt
        add hl,de
        ld de,24*40+36
        ld c,10h
        jp print_bg
sndtxt: db "MUS",0,"FX ",0,"OFF",0

; A = count, HL = first cell, D = char, E = attribute: up to 8 icons
icons:
        ld b,8
        ld c,a
.l:     push bc
        ld a,c
        or a
        jr z,.e
        dec c
        call bg_put
        jr .n
.e:     push de
        ld de,A_SPACE
        call bg_put
        pop de
.n:     inc hl
        ld a,c
        pop bc
        ld c,a
        djnz .l
        ret

hud_power:
        ld a,(weapon)           ; V (vulcan, yellow) or L (laser, cyan)
        or a
        ld de,1660h
        jr z,.w
        ld de,0C50h
.w:     ld hl,14*40+31
        call bg_put
        ld a,(power)            ; power bars
        ld hl,14*40+33
        ld de,43h*256+20h
        ld b,5
        call bars
        ld a,(speed)
        inc a
        ld hl,15*40+37
        ld de,43h*256+40h
        ld b,3
        call bars
        ld a,(options)          ; options
        ld hl,16*40+35
        ld de,8Eh*256+0E0h
        call icons2
        ld a,(shield)           ; shield
        or a
        ld de,A_SPACE
        jr z,.s
        ld de,0805h             ; "H", black on cyan
.s:     ld hl,16*40+38
        jp bg_put

; A = level, B = cells, HL = first, D = char, E = attribute when lit
bars:
        ld c,a
.l:     push bc
        ld a,c
        or a
        jr z,.off
        dec c
        call bg_put
        jr .n
.off:   push de
        ld d,0F5h               ; unlit: dots
        ld e,10h
        call bg_put
        pop de
.n:     inc hl
        ld a,c
        pop bc
        ld c,a
        djnz .l
        ret

; up to 2 icons
icons2:
        ld b,2
        ld c,a
        jp icons.l

hud_boss:
        ld hl,22*40+31
        ld a,(bossact)
        or a
        jr nz,.on
        ld b,9                  ; no boss: clear the lines
        ld de,A_SPACE
        call fill_bg
        ld hl,23*40+31
        ld b,9
        jp fill_bg
.on:    ld de,22*40+31
        ld hl,txt_boss
        ld c,20h
        call print_bg
        ; bar: hp / (max / 8) cells
        ld hl,(bhp)
        ld de,(bhp8)
        ld c,0
.dv:    or a
        sbc hl,de
        jr c,.dd
        inc c
        jr .dv
.dd:    ld a,c
        cp 9
        jr c,.ok
        ld a,8
.ok:    ld hl,23*40+31
        ld de,43h*256+20h
        ld b,8
        ld c,a
        jp bars.l
txt_boss: db "BOSS",0
