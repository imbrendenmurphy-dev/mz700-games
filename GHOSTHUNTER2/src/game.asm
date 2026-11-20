; =====================================================================
;  game.asm - game flow, per-frame logic, items, HUD, sprite choice
; =====================================================================
HUD_ROW         equ 0
BAR_ROW         equ 22
INFO_ROW        equ 24

; ---------------------------------------------------------------------
; frame: wait for the next field, draw, read the controls
frame:
        ld a,(turbo)
        or a
        call z,wait_frame
        call render
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        call read_keys
        ld b,a
        ld a,(inp)
        ld (inp_prev),a
        cpl
        and b
        ld (inp_new),a
        ld a,b
        ld (inp),a
        ret

; empty frame (no overlays)
blank_frame:
        call ovl_clear
        jr frame

; B frames with the current scene; NZ if start pressed
wait_frames:
        push bc
        call frame
        call start_pressed
        pop bc
        ret nz
        djnz wait_frames
        xor a
        ret

; FIRE or CR newly pressed -> NZ
start_pressed:
        ld a,(inp_new)
        and K_FIRE
        ret nz
        ld a,(key_pause)
        ld b,a
        ld a,(pause_prev)
        cpl
        and b
        push af
        ld a,b
        ld (pause_prev),a
        pop af
        ret

; ---------------------------------------------------------------------
; GAME FLOW
start_game:
        xor a
        ld (demo),a
        call mus_stop
        ld hl,score
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld a,3
        ld (lives),a
        xor a
        ld (extragiven),a
        ld a,1
        ld (level),a
        call level_start
        ret

; play levels until the game (or the demo) ends
level_start:
        xor a
        ld (spawned),a
        ld (sirenmode),a
        call setup_round
        call reset_actors
        ld a,1
        ld (firstlife),a
        call round_banner
life_start:
        call ready_sequence
        ret nz                      ; demo stopped by a key
play_loop:
        call game_logic
        ld (result),a
        call build_overlays
        call hud_power
        call update_hud
        call keys_ingame
        ld a,(quit_req)
        or a
        jp nz,game_over
        ld a,(demo)
        or a
        jr z,.nd
        ld hl,(demotim)
        dec hl
        ld (demotim),hl
        ld a,h
        or l
        jr z,.demo_end
        call anykey
        jr nz,.demo_key
.nd:    call frame
        ld a,(result)
        or a
        jr z,play_loop
        cp 1
        jp z,level_clear
        cp 2
        jp z,death
        jp time_up
.demo_end:
        xor a
        ret
.demo_key:
        ld a,1
        ld (demo_abort),a
        or a
        ret

; CR pauses, S toggles the sound, BREAK gives up
keys_ingame:
        xor a
        ld (quit_req),a
        ld a,(demo)
        or a
        ret nz
        ld a,(key_sound)
        ld b,a
        ld a,(sound_prev)
        cpl
        and b
        ld a,b
        ld (sound_prev),a
        jr z,.ns
        ld a,(snd_mute)
        xor 1
        ld (snd_mute),a
.ns:    ld a,(key_quit)
        or a
        jr z,.nq
        ld a,1
        ld (quit_req),a
        ret
.nq:    ld a,(key_pause)
        ld b,a
        ld a,(pause_prev)
        cpl
        and b
        ld a,b
        ld (pause_prev),a
        ret z
        ld a,1                      ; pause
        ld (pausing),a
        ld hl,s_paused
        ld a,WHITE*16+BLUE
        call hud_label
        ld a,(snd_mute)
        push af
        ld a,1
        ld (snd_mute),a
.pl:    call frame
        ld a,(key_pause)
        ld b,a
        ld a,(pause_prev)
        cpl
        and b
        ld a,b
        ld (pause_prev),a
        jr z,.pl
        pop af
        ld (snd_mute),a
        xor a
        ld (pausing),a
        ld hl,0
        ld (lastlabel),hl
        ret

; bonus rounds explain themselves first
round_banner:
        ld a,(demo)
        or a
        ret nz
        ld a,(roundtype)
        or a
        ret z
        ld hl,s_buffet
        ld (roundtype_lbl),hl
        ld hl,buffet_t
        call speed_word
        ld (roundtim),hl
        ld hl,s_bb1
        ld de,s_bb2
        ld a,(roundtype)
        cp 1
        jr z,.b
        ld hl,s_panic
        ld (roundtype_lbl),hl
        ld hl,panic_t
        call speed_word
        ld (roundtim),hl
        ld hl,s_pb1
        ld de,s_pb2
.b:     push de
        push hl
        ; a box in the middle of the maze
        ld b,7
        ld c,8
        ld a,BLUE*16+BLUE
        call clear_rows_mid
        ld hl,s_bonus
        ld c,9
        ld a,YELLOW*16+BLUE
        call print_centre
        pop hl
        ld c,11
        ld a,WHITE*16+BLUE
        call print_centre
        pop hl
        ld c,13
        ld a,CYAN*16+BLUE
        call print_centre
        ld hl,SONG_BONUS
        call mus_play
        ld b,150
.w:     push bc
        call blank_frame
        pop bc
        djnz .w
        call mus_stop
        jp redraw_maze

; clear B rows from row C, columns 4..35, with attr A
clear_rows_mid:
.r:     push bc
        push af
        ld b,4
        call vaddr
        pop af
        ld b,32
.c:     push af
        xor a
        ld (de),a
        pop af
        set 3,d
        ld (de),a
        res 3,d
        inc de
        djnz .c
        pop bc
        inc c
        djnz .r
        ret

; copy the whole background to the screen
redraw_maze:
        call recolour_all
        ld hl,BGCH
        ld de,VRAM
        ld bc,1000
        ldir
        call poll
        ld hl,BGAT
        ld de,ARAM
        ld bc,1000
        ldir
        call poll
        call ovl_forget
        jp draw_hud_static

; READY! with the actors shown; the first life of a level plays the jingle
ready_sequence:
        xor a
        ld (frighttim),a
        ld (pvisible),a
        ld a,1
        ld (ghostsvis),a
        ld a,3
        ld (hud_dirty),a
        call update_hud
        ld hl,0
        ld (lastlabel),hl
        ld hl,s_ready
        ld (readymsg),hl
        ld a,YELLOW*16
        ld (readycol),a
        ld b,60
        ld a,(firstlife)
        or a
        jr z,.short
        ld a,(demo)
        or a
        jr nz,.short
        ld hl,SONG_START
        call mus_play
        ld b,150
.short: xor a
        ld (firstlife),a
.w:     push bc
        call build_overlays
        call hud_power
        call frame
        pop bc
        ld a,(demo)
        or a
        jr z,.nc
        call anykey
        jr nz,.key
.nc:    djnz .w
        call mus_stop
        ld hl,0
        ld (readymsg),hl
        ld a,1
        ld (pvisible),a
        ld a,(PLAYER+A_X)
        ld b,a
        ld a,(PLAYER+A_Y)
        ld c,a
        ld a,YELLOW
        call burst
        xor a
        ret
.key:   ld a,1
        ld (demo_abort),a
        or a
        ret

level_clear:
        ld a,(demo)
        or a
        jr z,.real
        xor a
        ret
.real:  xor a
        ld (sirenmode),a
        ld (frighttim),a
        ld (supertim),a
        ld (ghostsvis),a
        ld a,(roundtype)            ; pellet panic bonus
        cp 2
        jr nz,.np
        ld de,5000h
        call add_points
        ld a,P_5000
        call popup_at_player
.np:    ld hl,SONG_CLEAR
        call mus_play
        ld b,0
.f:     push bc
        call build_overlays
        call update_hud
        pop bc
        push bc
        ld a,b                      ; maze strobe
        and 15
        jr nz,.ns
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and 1
        call set_palette
.ns:    ld a,b
        and 31
        jr nz,.nb
        ld a,(PLAYER+A_X)
        ld b,a
        ld a,(PLAYER+A_Y)
        ld c,a
        ld a,WHITE
        call burst
.nb:    call frame
        pop bc
        inc b
        ld a,b
        cp 128
        jr nz,.f
        call mus_stop
        xor a
        call set_palette
        call recolour_all
        ld a,(intermission)
        or a
        call nz,run_intermission
        ld hl,level
        inc (hl)
        jp level_start

time_up:
        xor a
        ld (sirenmode),a
        ld (frighttim),a
        ld hl,s_timeup
        ld (readymsg),hl
        ld a,YELLOW*16
        ld (readycol),a
        ld b,100
.w:     push bc
        call build_overlays
        call frame
        pop bc
        djnz .w
        ld hl,0
        ld (readymsg),hl
        xor a
        call set_palette
        call recolour_all
        ld hl,level
        inc (hl)
        jp level_start

death:
        xor a
        ld (sirenmode),a
        call mus_stop
        call sfx_stop
        ld b,40                     ; a frozen moment
.f:     push bc
        call build_overlays
        call frame
        pop bc
        djnz .f
        ld hl,SONG_DEATH
        call mus_play
        xor a
        ld (supertim),a
        ld (frighttim),a
        ld (ghostsvis),a
        ld (pvisible),a
        ld a,(palette)
        or a
        jr z,.np
        xor a
        call set_palette
.np:    ld b,0
.an:    push bc
        call build_overlays
        pop bc
        push bc
        ld a,b                      ; collapse
        srl a
        srl a
        srl a
        cp 6
        jr nc,.gone
        ld e,a
        ld d,0
        ld hl,die_glyphs
        add hl,de
        ld a,(hl)
        ld e,YELLOW*16+ALT
        cp 80h
        jr c,.d1
        ld e,YELLOW*16
        and 7Fh
.d1:    ld hl,PLAYER+A_X
        ld b,(hl)
        inc hl
        ld c,(hl)
        call ovl_grid
.gone:  pop bc
        push bc
        ld a,b
        cp 48
        jr nz,.nb
        ld a,(PLAYER+A_X)
        ld b,a
        ld a,(PLAYER+A_Y)
        ld c,a
        ld a,YELLOW
        call burst
        ld a,(PLAYER+A_X)
        ld b,a
        ld a,(PLAYER+A_Y)
        ld c,a
        ld a,RED
        call burst
.nb:    call frame
        pop bc
        inc b
        ld a,b
        cp 100
        jr nz,.an
        call mus_stop
        ld a,(demo)
        or a
        jr z,.real
        xor a                       ; the demo is over
        ret
.real:  ld hl,lives
        dec (hl)
        jr z,game_over
        call reset_actors
        jp life_start

; glyphs of the collapsing hero (80h+ = first character set)
die_glyphs: db 3Eh, 3Ah, 63h, 7Eh+80h, 3Eh+80h, 3Ch+80h

game_over:
        xor a
        ld (sirenmode),a
        ld (supertim),a
        ld (frighttim),a
        ld a,(palette)
        or a
        jr z,.np
        xor a
        call set_palette
.np:    ld a,3
        ld (hud_dirty),a
        call update_hud
        ld hl,s_gameover
        ld (readymsg),hl
        ld a,RED*16
        ld (readycol),a
        ld hl,SONG_OVER
        call mus_play
        ld a,1
        ld (ghostsvis),a
        xor a
        ld (pvisible),a
        ld b,200                    ; the ghosts dance
.w:     push bc
        call build_overlays
        call frame
        pop bc
        djnz .w
        call mus_stop
        ld hl,0
        ld (readymsg),hl
        xor a
        ret

; ---------------------------------------------------------------------
; per-frame logic.  A = 0 go on, 1 level clear, 2 death, 3 time up
game_logic:
        ld a,(hitstop)
        or a
        jr z,.run
        dec a
        ld (hitstop),a
        xor a
        ret
.run:   ld ix,actors                ; remember where everyone started
        ld b,5
.pp:    ld a,(ix+A_X)
        ld (ix+A_PX),a
        ld a,(ix+A_Y)
        ld (ix+A_PY),a
        ld de,16
        add ix,de
        djnz .pp
        ld a,(demo)                 ; controls -> next direction
        or a
        jr nz,.noinp
        ld a,(inp)
        and K_DIRS
        jr z,.noinp
        ld b,a
        ld a,(inp_new)
        and b
        jr nz,.pick
        ld a,b
.pick:  ld c,0                      ; K_ bit order: up, down, left, right
.pk:    rrca
        jr c,.got
        inc c
        jr .pk
.got:   ld e,c
        ld d,0
        ld hl,key2dir
        add hl,de
        ld a,(hl)
        ld (PLAYER+A_NEXT),a
.noinp: call tick_timers
        ld ix,PLAYER
        ld a,(pspeed)
        ld b,a
        ld a,(speedtim)
        ld c,a
        ld a,(supertim)
        or c
        ld a,b
        jr z,.ps
        srl a                       ; boosted: 1.5x
        add a,b
        jr nc,.ps
        ld a,255
.ps:    call move_actor
        ld ix,GHOST1
        ld b,4
.gu:    push bc
        call ghost_update
        pop bc
        ld de,16
        add ix,de
        djnz .gu
        call collisions
        or a
        ret nz
        call item_logic
        ld a,(roundtype)
        cp 1
        jr z,.timed
        ld hl,(pellets)
        ld a,h
        or l
        jr nz,.nc
        ld a,1
        ret
.nc:    ld a,(roundtype)
        cp 2
        jr z,.timed
        xor a
        ret
.timed: ld hl,(roundtim)
        dec hl
        ld (roundtim),hl
        ld a,h
        or l
        ld a,0
        ret nz
        ld a,3
        ret

key2dir: db 2,3,1,0                 ; up, down, left, right

; HL = table of three words (SLOW, NORMAL, FAST) -> HL = entry for speedsel
speed_word:
        ld a,(speedsel)
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
buffet_t: dw 2000,1600,1333         ; 20 s at the VZ pace, stretched
panic_t:  dw 2500,2000,1667         ; 25 s at the VZ pace, stretched

tick_timers:
        ld a,(streaktim)
        or a
        jr z,.t0
        dec a
        ld (streaktim),a
.t0:    ld a,(framecount)           ; energisers blink
        and 15
        jr nz,.t0b
        ld a,(energvis)
        xor 1
        ld (energvis),a
        call draw_energisers
.t0b:   ld a,(framecount)
        and 15
        cp 8
        jr nz,.t1
        ld a,(televis)
        xor 1
        ld (televis),a
        call draw_teleporters
.t1:    ld a,(roundtype)
        cp 1
        jr nz,.tf
        ld a,200                    ; buffet: always frightened
        ld (frighttim),a
        ld (frightmax),a
        ld a,(palette)
        or a
        ld a,1
        call z,set_palette
.tf:    ld a,(frighttim)
        or a
        jr z,.t2
        ld b,a
        ld a,(framecount)
        and 1
        jr nz,.t2
        dec b
        ld a,b
        ld (frighttim),a
        jr nz,.t2
        ld a,(supertim)
        or a
        jr nz,.t2
        ld a,(roundtype)
        cp 1
        jr z,.t2
        call unfrighten_all
.t2:    ld hl,freezetim
        call dec_tim
        ld hl,speedtim
        call dec_tim
        ld hl,x2tim
        call dec_tim
        ld hl,shieldtim
        call dec_tim
        ld hl,decoytim
        call dec_tim
        ld hl,itemtim
        call dec_tim
        ld a,(supertim)
        or a
        jr z,.t3
        ld b,a
        ld a,(framecount)
        and 1
        jr nz,.t3
        dec b
        ld a,b
        ld (supertim),a
        jr nz,.t3
        call unfrighten_all
.t3:    ld a,(speedtim)             ; speed / hunter trail
        ld b,a
        ld a,(supertim)
        or b
        jr z,.t4
        ld a,(PLAYER+A_X)
        ld hl,PLAYER+A_PX
        cp (hl)
        jr nz,.tr
        ld a,(PLAYER+A_Y)
        inc hl
        cp (hl)
        jr z,.t4
.tr:    ld a,(PLAYER+A_PX)
        ld b,a
        ld a,(PLAYER+A_PY)
        ld c,a
        ld a,(framecount)
        and 2
        ld a,RED
        jr z,$+4
        ld a,YELLOW
        call trail_dot
.t4:    ld a,(frighttim)            ; scatter / chase schedule
        or a
        jr nz,.t5
        ld a,(modephase)
        cp 5
        jr nc,.t5
        ld hl,(modetim)
        dec hl
        ld (modetim),hl
        ld a,h
        or l
        jr nz,.t5
        ld a,(modephase)
        inc a
        ld (modephase),a
        and 1
        ld (chasemode),a
        ld a,(modephase)
        add a,a
        ld e,a
        ld d,0
        ld hl,modetimes
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (modetim),hl
        ld ix,GHOST1                ; roaming ghosts turn round
        ld b,4
.rv:    ld a,(ix+A_ST)
        cp ST_ACT
        jr nz,.rv1
        set 1,(ix+A_FLG)
.rv1:   ld de,16
        add ix,de
        djnz .rv
.t5:    ld hl,(pellets_total)       ; GRUMBLE gets angry: 1/4 left (3/8 from level 5)
        srl h
        rr l
        srl h
        rr l
        ld a,(level)
        cp 5
        jr c,.e1
        ld de,(pellets_total)
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        ld h,d
        ld l,e
        add hl,de
        add hl,de
.e1:    ld de,(pellets)
        or a
        sbc hl,de
        ld a,0
        jr c,.e2
        inc a
.e2:    ld (elroy),a
        ld b,1                      ; siren
        ld a,(frighttim)
        or a
        jr z,.s1
        ld b,2
.s1:    ld ix,GHOST1
        ld c,4
.s2:    ld a,(ix+A_ST)
        cp ST_EYES
        jr c,.s3
        ld b,3
.s3:    ld de,16
        add ix,de
        dec c
        jr nz,.s2
        ld a,(roundtype)
        cp 2
        jr nz,.s4
        ld b,0                      ; pellet panic: no siren
.s4:    ld a,b
        ld (sirenmode),a
        ret

dec_tim:
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

modetimes: dw 350,1000,350,1000,250,0

; ---------------------------------------------------------------------
; collisions: A = 2 when the hero dies
collisions:
        ld ix,GHOST1
        ld b,4
.l:     push bc
        ld a,(ix+A_ST)
        cp ST_ACT
        jr z,.chk
        cp ST_FRT
        jr nz,.n
.chk:   ld a,(PLAYER+A_X)           ; same character?
        cp (ix+A_X)
        jr nz,.sw
        ld a,(PLAYER+A_Y)
        cp (ix+A_Y)
        jr z,.hit
.sw:    ld a,(PLAYER+A_X)           ; or swapped places this frame?
        cp (ix+A_PX)
        jr nz,.n
        ld a,(PLAYER+A_Y)
        cp (ix+A_PY)
        jr nz,.n
        ld a,(PLAYER+A_PX)
        cp (ix+A_X)
        jr nz,.n
        ld a,(PLAYER+A_PY)
        cp (ix+A_Y)
        jr nz,.n
.hit:   ld a,(ix+A_ST)
        cp ST_FRT
        jr z,.eat
        ld a,(supertim)
        or a
        jr nz,.eat
        ld a,(freezetim)
        or a
        jr nz,.n
        ld a,(shieldtim)
        or a
        jr nz,.shield
        ld a,(godmode)
        or a
        jr nz,.n
        pop bc
        ld a,2
        ret
.shield:
        xor a
        ld (shieldtim),a
        ld (ix+A_ST),ST_EYES
        ld a,P_POP
        call popup_at_player
        call ghost_burst
        ld hl,SFX_SHIELD
        ld a,5
        call sfx
        jr .n
.eat:   call eat_ghost
.n:     ld de,16
        add ix,de
        pop bc
        dec b
        jp nz,.l
        xor a
        ret

eat_ghost:
        ld (ix+A_ST),ST_EYES
        ld a,(supertim)
        or a
        jr z,.chain
        ld a,P_1000
        jr .score
.chain: ld a,(chain)
        inc a
        ld (chain),a
        ld e,a
        ld d,0
        ld hl,chainpop-1
        add hl,de
        ld a,e
        cp 6
        jr c,.c1
        ld hl,chainpop+4
.c1:    ld a,(hl)
.score: push af
        add a,a
        ld e,a
        ld d,0
        ld hl,popval
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_points
        pop af
        ld d,(ix+A_X)
        ld e,(ix+A_Y)
        call popup
        call ghost_burst
        ld hl,SFX_EATG
        ld a,6
        call sfx
        ld a,14
        ld (hitstop),a
        ld a,(roundtype)            ; perfect chain -> the hunter star
        or a
        ret nz
        ld a,(chain)
        cp 4
        ret nz
        ld a,P_PERFECT
        ld de,DOORX*256+EXITY
        call popup
        ld a,IT_STAR
        ld (itemspr),a
        ld a,250
        ld (itemtim),a
        ld hl,SFX_SPAWN
        ld a,3
        jp sfx
chainpop: db P_200,P_400,P_800,P_1600,P_3200

ghost_burst:
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        ld a,(framecount)
        and 1
        ld a,WHITE
        jr z,$+4
        ld a,CYAN
        jp burst

; ---------------------------------------------------------------------
; ITEMS: spawn under the house at 1/4, 1/2, 3/4 of the pellets; collect
IT_SPEED        equ 0
IT_X2           equ 1
IT_FREEZE       equ 2
IT_DECOY        equ 3
IT_SHIELD       equ 4
IT_STAR         equ 5
IT_CANDY        equ 6                ; treasures 6..11

item_logic:
        ld a,(roundtype)
        or a
        ret nz
        ld a,(itemtim)
        or a
        jr nz,.active
        ld a,(spawned)
        cp 3
        ret nc
        inc a                       ; threshold = total * (spawned+1) / 4
        ld b,a
        ld hl,(pellets_total)
        srl h
        rr l
        srl h
        rr l
        ex de,hl
        ld hl,0
.m:     add hl,de
        djnz .m
        ld de,(eaten)
        or a
        sbc hl,de
        ret nc
        ld a,(spawned)
        inc a
        ld (spawned),a
        cp 2
        jr z,.power
        cp 3
        jr nz,.treasure
        ld a,(level)
        cp 3
        jr nc,.power
.treasure:
        ld a,(level)
        dec a
        cp 6
        jr c,.t1
        ld a,5
.t1:    add a,IT_CANDY
        jr .set
.power: ld a,(level)                ; unlocked: 2 kinds on level 1, +1 per level, max 5
        inc a
        cp 6
        jr c,.p2
        ld a,5
.p2:    ld b,a
        call rand_below
.set:   ld (itemspr),a
        ld a,250
        ld (itemtim),a
        ld hl,SFX_SPAWN
        ld a,3
        jp sfx
.active:
        ld a,(PLAYER+A_X)
        cp STARTX
        ret nz
        ld a,(PLAYER+A_Y)
        cp STARTY
        ret nz
        xor a
        ld (itemtim),a
        ld a,(itemspr)
        cp IT_CANDY
        jr nc,.treas
        add a,a
        ld e,a
        ld d,0
        ld hl,pu_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.treas: sub IT_CANDY
        ld e,a
        ld d,0
        ld hl,treasure_pop
        add hl,de
        ld a,(hl)
        push af
        add a,a
        ld e,a
        ld hl,popval
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_points
        pop af
        call popup_at_player
        ld b,STARTX
        ld c,STARTY
        ld a,YELLOW
        call burst
        ld hl,SFX_ITEM
        ld a,4
        jp sfx
treasure_pop: db P_100,P_300,P_500,P_700,P_1000,P_2000
pu_tab: dw pu_speed,pu_x2,pu_freeze,pu_decoy,pu_shield,pu_super

pu_common:                          ; A = pop-up
        call popup_at_player
        ld b,STARTX
        ld c,STARTY
        ld a,WHITE
        call burst
        ld hl,SFX_PUP
        ld a,4
        jp sfx
pu_speed:
        ld a,220
        ld (speedtim),a
        ld (pumax),a
        ld a,P_SPEED
        jr pu_common
pu_freeze:
        ld a,220
        ld (freezetim),a
        ld (pumax),a
        ld a,P_FREEZE
        call popup_at_player
        ld hl,SFX_FREEZE
        ld a,4
        jp sfx
pu_decoy:
        ld a,250
        ld (decoytim),a
        ld (pumax),a
        ld a,(PLAYER+A_X)
        ld (decoyx),a
        ld a,(PLAYER+A_Y)
        ld (decoyy),a
        ld a,P_DECOY
        jr pu_common
pu_x2:
        ld a,250
        ld (x2tim),a
        ld (pumax),a
        ld a,P_X2
        jr pu_common
pu_shield:
        ld a,250
        ld (shieldtim),a
        ld (pumax),a
        ld a,P_SHIELD
        jr pu_common
pu_super:
        ld a,200
        ld (supertim),a
        ld (pumax),a
        ld a,(frighttime)           ; everyone roaming becomes prey
        push af
        ld a,250
        ld (frighttime),a
        call frighten_all
        pop af
        ld (frighttime),a
        ld a,250
        ld (frighttim),a
        ld hl,SONG_SUPER
        call mus_play
        ld a,P_HUNT
        jp pu_common

; ---------------------------------------------------------------------
; LEVEL SETUP
; round table by (level-1) % 8: maze, round type, intermission after
roundtab:
        db 0,0,0
        db 1,0,1
        db 2,0,0
        db 4,1,0
        db 3,0,2
        db 4,0,0
        db 5,0,0
        db 0,2,0

setup_round:
        ld a,(level)
        dec a
        and 7
        ld b,a
        add a,a
        add a,b
        ld e,a
        ld d,0
        ld hl,roundtab
        add hl,de
        ld a,(demo)
        or a
        jr z,.nd
        xor a
        ld (roundtype),a
        ld (intermission),a
        jr .gotr
.nd:    ld a,(hl)
        ld (mazeidx),a
        inc hl
        ld a,(hl)
        ld (roundtype),a
        inc hl
        ld a,(hl)
        ld (intermission),a
.gotr:  ld a,(level)                ; difficulty: lv = min(level, 12)
        cp 13
        jr c,.l1
        ld a,12
.l1:    ld b,a
        add a,a                     ; player 65 + 4/3 lv
        add a,b
        add a,a
        srl a
        srl a
        add a,66
        ld (pspeed),a
        ld a,b                      ; ghosts 57 + 2 lv
        add a,a
        add a,57
        ld (gspeed),a
        ld a,37
        ld (fspeed),a
        ld a,b                      ; frightened: 190 - 12 lv (min 45) x 2 frames
        add a,a
        add a,b
        add a,a
        add a,a
        ld c,a
        ld a,190
        sub c
        jr c,.fm
        cp 45
        jr nc,.fo
.fm:    ld a,45
.fo:    ld (frighttime),a
        ld a,b                      ; DIZZY's random turns: 30 + 6 lv
        add a,a
        add a,b
        add a,a
        add a,30
        ld (dizzy_chance),a
        ld a,b
        add a,3
        ld (sirenspd),a
        ; draw everything
        call mus_stop
        call wipe_out
        ld a,BLUE*16+BLUE
        call cls_bg
        call setup_maze
        call wipe_in
        call ovl_forget
        jp draw_hud_static

; fill the background buffers (chars 0, attr A)
cls_bg:
        ld hl,BGCH
        ld de,BGCH+1
        ld bc,999
        ld (hl),0
        ldir
        ld hl,BGAT
        ld de,BGAT+1
        ld bc,999
        ld (hl),a
        ldir
        ret

; place everyone at the start
reset_actors:
        ld hl,actors
        ld de,actors+1
        ld bc,16*5-1
        ld (hl),0
        ldir
        ld ix,PLAYER
        ld (ix+A_X),STARTX
        ld (ix+A_Y),STARTY
        ld (ix+A_DIR),1
        ld (ix+A_NEXT),1
        ld ix,GHOST1
        ld hl,ghost_start
        ld b,4
        ld c,1
.g:     ld a,(hl)
        inc hl
        ld (ix+A_X),a
        ld a,(hl)
        inc hl
        ld (ix+A_Y),a
        ld a,(hl)
        inc hl
        ld (ix+A_ST),a
        ld a,(hl)
        inc hl
        ld (ix+A_TIM),a
        ld (ix+A_ID),c
        ld (ix+A_DIR),1
        inc c
        ld de,16
        add ix,de
        djnz .g
        ld a,(level)                ; quicker release later on
        cp 4
        jr c,.nr
        ld hl,GHOST1+32+A_TIM
        srl (hl)
        ld hl,GHOST1+48+A_TIM
        srl (hl)
.nr:    ld a,(roundtype)
        cp 2
        jr nz,.npn
        ld ix,GHOST1                ; pellet panic: GRUMBLE sleeps at home too
        ld (ix+A_ST),ST_HOUSE
        ld (ix+A_Y),HOUSEY
        ld (ix+A_X),DOORX-6
.npn:   cp 1
        jr nz,.nb
        ld ix,GHOST1+16             ; buffet: everyone out quickly
        ld (ix+A_TIM),10
        ld (ix+16+A_TIM),30
        ld (ix+32+A_TIM),50
.nb:    xor a
        ld (frighttim),a
        ld (freezetim),a
        ld (speedtim),a
        ld (x2tim),a
        ld (shieldtim),a
        ld (supertim),a
        ld (decoytim),a
        ld (itemtim),a
        ld (chasemode),a
        ld (modephase),a
        ld (hitstop),a
        ld (streak),a
        ld (streaktim),a
        ld (elroy),a
        ld hl,350
        ld (modetim),hl
        ld a,(palette)
        or a
        jr z,.np
        xor a
        call set_palette
.np:    jp clear_particles

ghost_start:
        db DOORX,EXITY,ST_ACT,0
        db DOORX,HOUSEY,ST_HOUSE,40
        db DOORX-3,HOUSEY,ST_HOUSE,160
        db DOORX+3,HOUSEY,ST_HOUSE,250

; ---------------------------------------------------------------------
; OVERLAYS for the play field
build_overlays:
        call ovl_clear
        ld a,(itemtim)              ; item under the house
        or a
        jr z,.noitem
        cp 60
        jr nc,.iv
        ld a,(framecount)
        and 4
        jr nz,.noitem
.iv:    ld a,(itemspr)
        add a,a
        ld e,a
        ld d,0
        ld hl,item_look
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        ld b,a
        ld a,(itemspr)
        cp IT_STAR
        jr nz,.is
        ld a,(framecount)
        and 4
        ld e,YELLOW*16
        jr z,.is
        ld e,RED*16
.is:    ld a,b
        ld b,STARTX
        ld c,STARTY
        call ovl_grid
.noitem:
        ld a,(decoytim)             ; decoy dummy
        or a
        jr z,.nodecoy
        ld a,(decoyx)
        ld b,a
        ld a,(decoyy)
        ld c,a
        ld a,(framecount)
        and 8
        ld a,3Dh
        jr z,$+4
        ld a,3Eh
        ld e,WHITE*16+ALT
        call ovl_grid
.nodecoy:
        ld a,(ghostsvis)
        or a
        jr z,.nogh
        ld ix,GHOST1
        ld b,4
.gl:    push bc
        call ghost_sprite           ; -> A char, E attr
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        call ovl_grid
        ld de,16
        add ix,de
        pop bc
        djnz .gl
.nogh:  ld a,(pvisible)
        or a
        jr z,.nopl
        ld ix,PLAYER
        call player_sprite
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        call ovl_grid
.nopl:  ld hl,(readymsg)
        ld a,h
        or l
        jr z,.nor
        push hl
        ld b,0
.rl:    ld a,(hl)
        inc hl
        or a
        jr z,.re
        inc b
        jr .rl
.re:    pop hl
        ld a,41
        sub b
        srl a
        ld b,a
        ld c,12
        ld a,(readycol)
        ld e,a
        call ovl_text
.nor:   call draw_popups
        jp update_particles

; glyph, attr per item
item_look:
        db 0C3h, YELLOW*16          ; speed: arrow
        db 22h, RED*16+ALT          ; x2
        db 0B3h, WHITE*16+ALT       ; freeze: snowflake
        db 3Dh, WHITE*16+ALT        ; decoy
        db 8Eh, GREEN*16+ALT        ; shield
        db 6Bh, YELLOW*16           ; star
        db 73h, RED*16+ALT          ; candy
        db 9Dh, RED*16+ALT          ; pumpkin
        db 74h, GREEN*16+ALT        ; potion
        db 0CEh, WHITE*16           ; skull
        db 44h, CYAN*16             ; gem
        db 0AAh, YELLOW*16+ALT      ; trophy

; ghost IX -> A = glyph, E = attr
ghost_sprite:
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        ld d,a                      ; animation frame
        ld a,(ix+A_ST)
        cp ST_EYES
        jp nc,.eyes
        cp ST_FRT
        jr z,.fright
        ld a,(freezetim)
        or a
        jr z,.nofz
        ld a,(ix+A_ST)
        cp ST_ACT
        jr nz,.nofz
        ld a,(framecount)           ; frozen: shivering ice
        and 2
        ld e,WHITE*16+ALT
        jr z,$+4
        ld e,CYAN*16+ALT
        ld a,38h
        add a,d
        ret
.nofz:  ld a,(ix+A_ID)              ; PEEKABOO fades to his eyes now and then
        cp 4
        jr nz,.body
        ld a,(level)
        cp 2
        jr nc,.pk
        ld a,(demo)
        or a
        jr z,.body
.pk:    ld a,(framecount+1)
        ld b,a
        ld a,(framecount)
        rr b
        rra
        cp 160
        jr c,.body
        cp 176
        jr c,.flick
        cp 240
        jr c,.eyes
.flick: ld a,(framecount)
        and 2
        jr z,.body
        jr .eyes
.body:  ld a,(ix+A_ID)
        dec a
        ld c,a
        ld b,0
        ld hl,ghost_cols
        add hl,bc
        ld e,(hl)
        ld hl,ghost_glyph
        add hl,bc
        ld a,(hl)
        add a,d
        ret
.fright:
        ld a,(frighttim)
        cp 50
        jr nc,.f1
        ld a,(framecount)
        and 8
        jr z,.f1
        ld e,WHITE*16+ALT
        ld a,36h
        add a,d
        ret
.f1:    ld e,BLUE*16+ALT
        ld a,(palette)
        or a
        jr nz,$+4
        ld e,WHITE*16+ALT
        ld a,36h
        add a,d
        ret
.eyes:  ld e,WHITE*16+ALT
        ld a,71h
        ret

ghost_cols:  db RED*16+ALT, GREEN*16+ALT, MAGENTA*16+ALT, CYAN*16+ALT
ghost_glyph: db 36h, 36h, 36h, 38h

; player IX -> A = glyph, E = attr
player_sprite:
        ld e,YELLOW*16+ALT
        ld a,(supertim)
        or a
        jr z,.ns
        ld a,(framecount)           ; hunter: flaming colours
        rrca
        and 3
        push hl
        ld hl,hunter_cols
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        pop hl
.ns:    ld a,(shieldtim)
        or a
        jr z,.nsh
        cp 60
        jr c,.sb
        ld a,(framecount)
        and 12
        jr nz,.nsh
        jr .bub
.sb:    ld a,(framecount)
        and 4
        jr nz,.nsh
.bub:   ld e,GREEN*16+ALT
        ld a,84h
        ret
.nsh:   bit 0,(ix+A_FLG)
        jr nz,.open
        ld a,(ix+A_ANIM)
        and 1
        ld a,3Eh
        ret z
.open:  ld a,(ix+A_DIR)
        and 3
        push hl
        ld hl,hero_open
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ret
hero_open:   db 3Dh,3Bh,3Ah,3Ch
hunter_cols: db YELLOW*16+ALT, RED*16+ALT, WHITE*16+ALT, RED*16+ALT

; ---------------------------------------------------------------------
; HUD:  row 0  score, HI, level, power label, lives
draw_hud_static:
        ld a,BLACK*16+BLACK
        ld b,HUD_ROW
        ld c,1
        call clear_rows
        ld b,BAR_ROW
        ld c,3
        ld a,BLACK*16+BLACK
        call clear_rows
        ld hl,s_hi
        ld b,8
        ld c,HUD_ROW
        ld a,GREEN*16+BLACK
        call print_at
        ld hl,s_lv
        ld b,18
        ld c,HUD_ROW
        ld a,GREEN*16+BLACK
        call print_at
        ld hl,(mname)               ; maze name on the bottom line
        ld c,INFO_ROW
        ld a,CYAN*16+BLACK
        call print_centre
        ld a,3
        ld (hud_dirty),a
        ld a,0FFh
        ld (lastbar),a
        ld hl,0
        ld (lastlabel),hl
        ret
s_hi:   db "HI",0
s_lv:   db "L",0

update_hud:
        ld a,(hud_dirty)
        or a
        ret z
        ld c,a
        xor a
        ld (hud_dirty),a
        push bc
        ld hl,score
        ld b,3
        ld de,VRAM+HUD_ROW*40
        ld c,YELLOW*16+BLACK
        call print_bcd_hi
        pop bc
        push bc
        ld a,(demo)
        or a
        jr nz,.nohi
        ld hl,score
        ld de,hiscore
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.newhi
        jr nz,.nohi
        inc hl
        inc de
        djnz .c
        jr .nohi
.newhi: ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        pop bc
        set 1,c
        push bc
.nohi:  pop bc
        bit 1,c
        ret z
        ld hl,hiscore
        ld b,3
        ld de,VRAM+HUD_ROW*40+11
        ld c,YELLOW*16+BLACK
        call print_bcd_hi
        ld a,(level)
        ld de,VRAM+HUD_ROW*40+19
        ld c,YELLOW*16+BLACK
        call print_dec2
        ld a,(lives)                ; spare lives at columns 34..38
        or a
        jr z,.l0
        dec a
.l0:    ld b,a
        ld de,VRAM+HUD_ROW*40+34
        ld c,5
.lv:    ld a,b
        or a
        ld a,0
        jr z,.blank
        dec b
        ld a,3Dh
.blank: ld (de),a
        set 3,d
        ld a,YELLOW*16+BLACK+ALT
        ld (de),a
        res 3,d
        inc de
        dec c
        jr nz,.lv
        ret

; BCD from the most significant byte: HL = first byte, B = bytes
print_bcd_hi:
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        call .dig
        ld a,(hl)
        call .dig
        inc hl
        djnz .l
        ret
.dig:   and 0Fh
        add a,20h
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        ret

; A = 0..99 -> two digits at DE, attr C
print_dec2:
        ld b,0
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     push af
        ld a,b
        add a,20h
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        pop af
        add a,20h
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        ret

; label at columns 23..30: HL = string, A = attr
hud_label:
        push hl
        push af
        ld hl,s_blank8
        ld b,23
        ld c,HUD_ROW
        call print_at
        pop af
        pop hl
        ld b,23
        ld c,HUD_ROW
        jp print_at
s_blank8: db "        ",0

; timer bar on BAR_ROW: A = length 0..39, B = attr
draw_bar:
        ld c,a
        ld a,(lastbar)
        cp c
        jr nz,.ch
        ld a,(lastbarc)
        cp b
        ret z
.ch:    ld a,c
        ld (lastbar),a
        ld a,b
        ld (lastbarc),a
        ld hl,VRAM+BAR_ROW*40
        ld e,39
.l:     ld a,c
        or a
        jr z,.bg
        dec c
        ld (hl),7Ah
        set 3,h
        ld (hl),b
        res 3,h
        jr .n
.bg:    ld (hl),0
.n:     inc hl
        dec e
        jr nz,.l
        ret

; power label and bar, every frame
hud_power:
        ld a,(roundtype)
        or a
        jp nz,.h7
        ld a,(supertim)
        or a
        jr z,.h1
        ld hl,s_super
        ld b,RED*16+BLACK
        ld c,200
        jp .show
.h1:    ld a,(frighttim)
        or a
        jr z,.h2
        ld hl,s_power
        ld b,CYAN*16+BLACK
        ld c,a
        ld a,(frightmax)
        ld e,a
        ld a,c
        jp .showm
.h2:    ld a,(freezetim)
        or a
        jr z,.h3
        ld hl,s_freeze
        ld b,WHITE*16+BLACK
        ld c,220
        jr .show
.h3:    ld a,(speedtim)
        or a
        jr z,.h4
        ld hl,s_speed
        ld b,RED*16+BLACK
        ld c,220
        jr .show
.h4:    ld a,(decoytim)
        or a
        jr z,.h5
        ld hl,s_decoy
        ld b,MAGENTA*16+BLACK
        ld c,250
        jr .show
.h5:    ld a,(x2tim)
        or a
        jr z,.h6
        ld hl,s_x2
        ld b,YELLOW*16+BLACK
        ld c,250
        jr .show
.h6:    ld a,(shieldtim)
        or a
        jr z,.h7
        ld hl,s_shield
        ld b,GREEN*16+BLACK
        ld c,250
        jr .show
.h7:    ld a,(roundtype)
        or a
        jr z,.none
        ld hl,(roundtim)            ; bonus round clock: bar = time / 64
        ld b,6
.bd:    srl h
        rr l
        djnz .bd
        ld a,l
        cp 40
        jr c,.bt
        ld a,39
.bt:    ld b,YELLOW*16+BLACK
        call draw_bar
        ld hl,(roundtype_lbl)
        jr .lbl
.none:  xor a
        ld b,0
        call draw_bar
        ld hl,s_blank8
        ld a,(demo)
        or a
        jr z,.lbl
        ld hl,s_demo
        jr .lbl
.show:  ld e,c
.showm: push hl                     ; bar = timer * 39 / max
        push bc
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; *32
        add hl,bc
        add hl,bc
        add hl,bc
        add hl,bc
        add hl,bc
        add hl,bc
        add hl,bc                   ; *39
        ld d,0
        ld b,0
.dv:    or a
        sbc hl,de
        jr c,.dd
        inc b
        jr .dv
.dd:    ld a,b
        cp 40
        jr c,$+4
        ld a,39
        pop bc
        call draw_bar
        pop hl
.lbl:   ld de,(lastlabel)
        or a
        sbc hl,de
        add hl,de
        ret z
        ld (lastlabel),hl
        ld a,(pausing)
        or a
        ret nz
        ld a,(lastbarc)
        or a
        jr nz,$+4
        ld a,YELLOW*16+BLACK
        jp hud_label
