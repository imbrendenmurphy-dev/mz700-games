; =====================================================================
;  game.asm - game states, waves, HUD, captions, scoring, high scores
; =====================================================================

new_game:
        ld a,1
new_game_at:                    ; A = first wave
        ld (wave),a
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld hl,0
        ld (extacc),hl
        ld a,3
        ld (lives),a
        call clear_particles
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

; RETURN pauses.  While paused nothing moves; Q quits to the title.
check_pause:
        ld a,(demo)
        or a
        ret nz
        ld a,(sedge)
        and KS_M
        call nz,cycle_sound     ; M: ALL / FX / OFF
        ld a,(sedge)
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
        call print_bg           ; (shows at the next flush)
        jp hud_power

; ---------------------------------------------------------------------
tick_intro:
        xor a
        ld (ai_on),a
        call update_objects     ; only counts down the materialising
        call place_objects
        call update_particles
        call place_player
        ld a,(framecnt)
        and 3
        call z,caption_colours
        ld hl,statetm
        dec (hl)
        ret nz
        call clear_big
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
        call update_particles
        call update_bullets
        call update_shots
        call player_collide
        call place_player
        call pick_tick
        call edge_flash
        call heartbeat
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
        ld hl,s_bigclear
        ld b,7
        ld e,61h
        call big_centre
        ld hl,s_saved           ; HUMANS SAVED: n
        ld de,15*40+12
        ld c,71h
        call print_bg
        ld a,(saved)
        call print_dec2
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
        ld b,17
        ld c,61h
        jp print_centre

; now and then a power-up appears (from wave 2)
pick_tick:
        ld a,(wave)
        cp 2
        ret c
        ld a,(demo)
        or a
        ret nz
        ld hl,(picktm)
        dec hl
        ld (picktm),hl
        ld a,h
        or l
        ret nz
        call rand8              ; the next one 14-24 s later
        ld l,a
        ld h,0
        add hl,hl
        ld de,700
        add hl,de
        ld (picktm),hl
        call rand_pos_robot     ; not right next to you
        ld a,T_PICK
        call new_obj
        ret c
        call rand8
        and 1
        ld (ix+OAUX),a
        ld hl,PICKLIFE
        ld (ix+OVXL),l
        ld (ix+OVXH),h
        ld (ix+OST),20
        ld hl,sfx_spawn
        ld a,2
        jp play_sfx

tick_dying:
        xor a
        ld (ai_on),a
        call place_objects
        call update_particles
        call place_player
        ld a,(statetm)
        cp 50
        jr nz,.nb
        call player_bc          ; the second, bigger bang
        ld a,b
        ld b,c
        ld c,a
        ld a,0E1h+GRAV
        ld de,0010h
        call burst
.nb:    ld hl,statetm
        dec (hl)
        ret nz
        ld a,(demo)
        or a
        jp nz,demo_end
        ld a,(trainer)          ; trainer mode: lives never run out
        or a
        jp nz,respawn
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
        ld hl,s_biggame
        ld b,7
        ld e,21h
        jp big_centre

tick_clear:
        xor a
        ld (ai_on),a
        call update_objects     ; explosions and pop-ups finish
        call place_objects
        call update_particles
        call place_player
        call hud_update
        call edge_flash
        ld a,(framecnt)
        and 3
        call z,caption_colours
        ld a,(statetm)          ; fireworks
        and 15
        call z,firework
        ld hl,statetm
        dec (hl)
        ret nz
        ld a,(demo)
        or a
        jp nz,demo_end
        ld hl,wave
        ld a,(hl)
        cp 99
        jp nc,start_wave
        inc (hl)
        jp start_wave

; a firework somewhere in the middle of the arena
firework:
        ld a,30
        call rand_n
        add a,5
        ld c,a
        ld a,14
        call rand_n
        add a,5
        ld b,a
        call rand8
        and 7
        ld hl,cyctab
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        or GRAV
        ld de,000Ch
        jp burst

tick_over:
        call place_objects
        call update_particles
        ld hl,statetm
        dec (hl)
        jr z,.done
        ld a,(statetm)
        cp 150
        ret nc
        ld a,(sedge)
        and KS_SPACE
        ret z
.done:  call snd_off
        call hiscore_rank       ; a place in the table?
        jp nc,title
        call enter_name
        ld a,PG_HEROES          ; show the table
        ld (page),a
        jp attract

; ---------------------------------------------------------------------
; high scores.  HISC: 8 x (score BCD 3 bytes low first, initials 3, wave, -)

init_hiscores:
        ld hl,hisc_init
        ld de,HISC
        ld bc,64
        ldir
        ld a,0FFh
        ld (hinew),a
        jp set_hiscore

; hiscore = the table's top score (for the HUD)
set_hiscore:
        ld hl,HISC
        ld de,hiscore
        ld bc,3
        ldir
        ret

; does score beat entry 7?  Carry = yes, A = its rank (0..7)
hiscore_rank:
        ld ix,HISC
        ld c,0
.l:     call beats              ; score > (ix)?
        jr c,.yes
        ld de,8
        add ix,de
        inc c
        ld a,c
        cp 8
        jr nz,.l
        or a
        ret
.yes:   ld a,c
        scf
        ret

beats:                          ; carry if score > the entry at IX
        ld a,(ix+2)
        ld hl,score+2
        cp (hl)
        jr nz,.d
        ld a,(ix+1)
        dec hl
        cp (hl)
        jr nz,.d
        ld a,(ix+0)
        dec hl
        cp (hl)
.d:     ret                     ; carry: entry < score

; insert the score at rank A with blank initials; IX = its entry
hiscore_insert:
        ld (hinew),a
        ld b,a
        ld a,7                  ; move entries rank..6 down one
        sub b
        jr z,.put
        ld c,a
        ld b,0
        sla c                   ; *8
        rl b
        sla c
        rl b
        sla c
        rl b
        ld hl,HISC+7*8-1
        ld de,HISC+8*8-1
        lddr
.put:   ld a,(hinew)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld ix,HISC
        add ix,de
        ld a,(score)
        ld (ix+0),a
        ld a,(score+1)
        ld (ix+1),a
        ld a,(score+2)
        ld (ix+2),a
        ld (ix+3),' '
        ld (ix+4),' '
        ld (ix+5),' '
        ld a,(wave)
        ld (ix+6),a
        jp set_hiscore

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
        ld (edgetm),a
        ld hl,0                 ; power-ups end with the wave
        ld (pw3),hl
        ld (pwsh),hl
        call rand8              ; the first pickup after 10-20 s
        ld l,a
        ld h,0
        add hl,hl
        ld de,500
        add hl,de
        ld (picktm),hl
        ld a,30
        ld (beattm),a
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
        ; wave table row: waves 1-40, then 21-40 again
        ld a,(wave)
        dec a
.m:     cp NWAVES
        jr c,.r
        sub 20
        jr .m
.r:     ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl               ; *2
        push hl
        add hl,hl
        add hl,hl               ; *8
        add hl,de               ; *9
        pop de
        add hl,de               ; *11
        ld de,wavetab
        add hl,de
        ld (waverow),hl
        ; droid speed: (table delay + ease) * 6 ticks per step
        push hl
        ld de,W_DELAY
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
        call formation
        ; screen
        call draw_arena
        call hud_all
        call refresh_all
        ld hl,s_bigwave         ; "WAVE nn" in big letters
        ld de,capbuf
        ld bc,5
        ldir
        ld a,(wave)
        ld b,'0'-1
.tens:  inc b
        sub 10
        jr nc,.tens
        add a,'0'+10
        ex de,hl
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,capbuf
        ld b,7
        ld e,61h
        call big_centre
        call wave_subtitle
        ld b,14                 ; (row 12 is where the player stands)
        ld c,71h
        call print_centre
        ld a,S_INTRO
        ld (state),a
        ld a,130
        ld (statetm),a
        ld hl,sfx_wave
        ld a,8
        jp play_sfx

; HL = subtitle for the wave in (waverow)
wave_subtitle:
        ld ix,(waverow)
        ld a,(wave)
        cp 40
        ld hl,s_sub_last
        ret z
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
        ld a,(ix+W_FORM)
        ld hl,s_sub_edge
        bit 2,a
        ret nz
        and 3
        jr z,.nf
        ld hl,s_sub_ring
        dec a
        ret z
        ld hl,s_sub_lines
        dec a
        ret z
        ld hl,s_sub_grid
        ret
.nf:    ld hl,s_sub_orb
        ld a,(ix+4)
        or a
        ret nz
        ld hl,s_sub_first
        ld a,(wave)
        cp 1
        ret z
        ld hl,s_sub_droid
        ret

; arrange pylons (ring / corridors / grid) and droids (round the edges)
formation:
        ld ix,(waverow)
        ld a,(ix+W_FORM)
        ld (form),a
        or a
        ret z
        xor a
        ld (fk),a               ; pylon number
        ld a,(ix+1)
        ld (fn),a               ; pylon count
        ld ix,OBJ
        ld a,(objtop)
        ld b,a
.l:     push bc
        ld a,(ix+OT)
        cp T_PYLON
        jr nz,.nd
        ld a,(form)
        and 3
        jr z,.nx
        call pylon_spot         ; B = row, C = column for pylon (fk)
        ld hl,fk
        inc (hl)
        jr .set
.nd:    cp T_DROID
        jr nz,.nx
        ld a,(form)
        bit 2,a
        jr z,.nx
        call edge_spot
.set:   ld (ix+OX),c
        ld (ix+OY),b
        call set_materialise
.nx:    ld de,OBJSZ
        add ix,de
        pop bc
        djnz .l
        ret

; a random cell on the arena's edge
edge_spot:
        call rand8
        and 3
        jr z,.top
        dec a
        jr z,.bot
        dec a
        ld c,XMIN
        jr z,.side
        ld c,XMAX
.side:  ld a,YMAX-YMIN+1
        call rand_n
        add a,YMIN
        ld b,a
        ret
.top:   ld b,YMIN
        jr .tb
.bot:   ld b,YMAX
.tb:    ld a,XMAX-XMIN+1
        call rand_n
        add a,XMIN
        ld c,a
        ret

; pylon (fk) of (fn) in the wave's pattern -> B = row, C = column
pylon_spot:
        ld a,(form)
        and 3
        dec a
        jr z,.ring
        dec a
        jr z,.lines
        ; grid: 4 columns x 4 rows, clear of the middle
        ld a,(fk)
        and 15
        ld b,a
        and 3
        ld hl,grid_cols
        add a,l
        ld l,a
        jr nc,.g1
        inc h
.g1:    ld c,(hl)
        ld a,b
        rrca
        rrca
        and 3
        ld hl,grid_rows
        add a,l
        ld l,a
        jr nc,.g2
        inc h
.g2:    ld b,(hl)
        ret
.lines: ; two walls, columns 11 and 28, rows 4..21
        ld a,(fk)
        ld c,11
        bit 0,a
        jr z,.l1
        ld c,28
.l1:    srl a
        ld b,a
        add a,a
        add a,b                 ; (k/2) * 3
.l2:    cp 18
        jr c,.l3
        sub 18
        jr .l2
.l3:    add a,4
        ld b,a
        ret
.ring:  ; round a 23 x 15 box: perimeter 76, spaced 76 / n
        ld a,(fn)
        ld e,a
        ld a,76
        ld d,0
.d1:    sub e
        jr c,.d2
        inc d
        jr .d1
.d2:    ld a,(fk)               ; p = k * step
        ld b,a
        xor a
.m1:    dec b
        jp m,.m2
        add a,d
        jr .m1
.m2:    cp 23
        jr nc,.r1
        add a,8
        ld c,a
        ld b,5
        ret
.r1:    sub 23
        cp 15
        jr nc,.r2
        add a,5
        ld b,a
        ld c,31
        ret
.r2:    sub 15
        cp 23
        jr nc,.r3
        ld b,a
        ld a,31
        sub b
        ld c,a
        ld b,20
        ret
.r3:    sub 23
        ld b,a
        ld a,20
        sub b
        ld b,a
        ld c,8
        ret

grid_cols:  db 6,12,26,32
grid_rows:  db 5,9,15,19

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
        cp T_PYLON
        jr z,.mat               ; so do pylons (formations)
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

; blank caption rows 10 and 14 back to the arena
clear_caption:
        ld hl,10*40+1
        ld de,00h*256+A_ARENA
        ld b,38
        call fill_bg
        ld hl,14*40+1
        ld b,38
        jp fill_bg

; ---------------------------------------------------------------------
; HUD: score (0-5)  W nn (8-10)  HI hhhhhh (13-21)  DEMO (24)  lives (34-39)
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
        ld a,(trainer)
        or a
        jr z,.nt
        ld hl,s_t
        ld de,32
        ld c,20h
        call print_bg
.nt:    ld a,(demo)
        or a
        jr z,.nd
        ld hl,s_demo
        ld de,24
        ld c,20h
        call print_bg
        jr hud_score
.nd:    call hud_power
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
        ld a,(hudpw)
        or a
        jr z,.s
        xor a
        ld (hudpw),a
        ld a,(demo)
        or a
        call z,hud_power
.s:     ld a,(hudflag)
        or a
        ret z
        xor a
        ld (hudflag),a
        jr hud_score

; which power-up is on, at column 24 (SHIELD wins over 3-WAY)
hud_power:
        ld hl,s_shield
        ld c,50h
        ld de,(pwsh)
        ld a,d
        or e
        jr nz,.p
        ld hl,s_3way
        ld c,60h
        ld de,(pw3)
        ld a,d
        or e
        jr nz,.p
        ld hl,s_blank7
.p:     ld de,24
        jp print_bg

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
        ld a,48                 ; the arena edge flashes
        ld (edgetm),a
        call player_bc          ; a ring of cyan round the player
        ld a,b
        ld b,c
        ld c,a
        ld a,0D1h
        ld de,0010h
        call burst
        ld hl,sfx_extra
        ld a,7
        jp play_sfx
