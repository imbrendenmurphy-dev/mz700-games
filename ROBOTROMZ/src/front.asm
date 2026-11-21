; =====================================================================
;  front.asm - the attract sequence and the high-score initials screen
;
;  Pages: 0 title, 1 the story so far, 2 the robots, 3 demo (the computer
;  plays), 4 the heroes (high scores), then round again.  SPACE starts a
;  game from any of them.
; =====================================================================

; returns A = 0 to start a game, 1 to run the demo
front_end:
        call snd_off
        call clear_particles
.newpage:
        ld a,(page)
        cp PG_DEMO
        jr nz,.np
        ld a,1
        ret
.np:    call draw_page
        ld hl,0
        ld (ptick),hl
.loop:  call wait_vblank
        call flush
        call snd_tick
        call read_keys
        call restore
        ld a,(sedge)
        and KS_SPACE
        jr z,.ns
        xor a
        ret
.ns:    ld a,(sedge)
        and KS_M
        jr z,.nm
        call cycle_sound
        ld a,(page)
        or a
        call z,show_sound
.nm:    ld a,(sedge)            ; T: trainer mode
        and KS_T
        jr z,.nt
        ld a,(trainer)
        xor 1
        ld (trainer),a
        ld hl,sfx_type
        ld a,1
        call play_sfx
        ld a,(page)
        or a
        call z,show_trainer
.nt:    ld a,(kprev+5)          ; 1 / 2 / 3: control mode
        cpl
        ld b,a
        ld a,(kbuf+5)
        and b
        ld c,0
        bit 7,a                 ; 1: keyboard
        jr nz,.cm
        inc c
        bit 6,a                 ; 2: twin joysticks
        jr nz,.cm
        inc c
        bit 5,a                 ; 3: one joystick
        jr z,.nc
.cm:    ld a,c
        ld (ctlmode),a
        ld hl,sfx_type
        ld a,1
        call play_sfx
        ld a,(page)
        or a
        call z,show_controls
.nc:    call animate_page
        call update_particles
        ld hl,framecnt
        inc (hl)
        ld hl,(ptick)
        inc hl
        ld (ptick),hl
        ld de,(pagelen)
        or a
        sbc hl,de
        jp c,.loop
        ld a,(page)             ; next page
        inc a
        cp NPAGES
        jr c,.p
        xor a
.p:     ld (page),a
        jp .newpage

draw_page:
        ld a,(page)
        or a
        jp z,draw_title
        dec a
        jp z,draw_story
        dec a
        jp z,draw_gallery
        dec a
        jp z,draw_howto
        jp draw_heroes

animate_page:
        ld a,(framecnt)
        and 7
        jp z,border_colours
        ld a,(page)
        or a
        jp z,anim_title
        dec a
        jp z,anim_story
        dec a
        jp z,anim_gallery
        dec a
        ret z                   ; how to play: just the border
        jp anim_heroes

; ---------------------------------------------------------------------
; page 3: how to play
draw_howto:
        ld hl,520
        call set_len
        call page_frame
        ld hl,howto_recs
        call print_recs
        ld hl,15*40+3           ; the two power-ups
        ld de,0B5E0h
        call bg_put
        ld hl,17*40+3
        ld de,08FD0h
        call bg_put
        jp refresh_all

; text records: row, column (FFh = centred), attribute, string; FFh ends
print_recs:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        cp 0FFh
        jr z,.ctr
        push bc
        push hl
        ld c,a
        call calc_ofs
        ex de,hl
        pop hl
        pop bc
        call print_bg
        jr .l
.ctr:   call print_centre
        jr .l

page_frame:                     ; black page inside a thin frame (colours roll)
        call clear_particles
        ld a,70h
        call clear_bg
        ld b,0
        ld e,70h
        jp frame_box

set_len:                        ; HL = page length in ticks
        ld (pagelen),hl
        ret

; ---------------------------------------------------------------------
; page 0: title
draw_title:
        ld hl,450
        call set_len
        call page_frame
        ld hl,logo              ; 4 rows x 35 block characters
        ld de,BGCH+2*40+2
        ld b,4
.lr:    push bc
        ld bc,35
        ldir
        ex de,hl
        ld bc,5
        add hl,bc
        ex de,hl
        pop bc
        djnz .lr
        ld hl,title_recs
        call print_recs
        ld hl,hiscore
        ld de,22*40+22
        ld c,50h
        call print_bcd6
        call show_sound
        call show_trainer
        call show_controls
        call refresh_all
        ld hl,sfx_title
        ld a,1
        jp play_sfx

show_sound:
        ld a,(soundopt)
        ld hl,s_snd_all
        or a
        jr z,.on
        ld hl,s_snd_fx
        dec a
        jr z,.on
        ld hl,s_snd_off
.on:    ld de,17*40+18
        ld c,70h
        jp print_bg

show_controls:
        ld a,(ctlmode)
        ld hl,s_ctl_keys
        or a
        jr z,.c
        ld hl,s_ctl_twin
        dec a
        jr z,.c
        ld hl,s_ctl_one
.c:     ld de,15*40+18
        ld c,60h
        jp print_bg

show_trainer:
        ld hl,s_off
        ld c,70h
        ld a,(trainer)
        or a
        jr z,.t
        ld hl,s_on
        ld c,20h
.t:     ld de,18*40+18
        jp print_bg

anim_title:
        ld a,(framecnt)         ; sparks fly off the logo
        and 15
        cp 2
        jr nz,.ns
        ld a,35
        call rand_n
        add a,2
        ld c,a
        ld a,4
        call rand_n
        add a,2
        ld b,a
        call rand8
        and 7
        ld hl,cyctab
        add a,l
        ld l,a
        jr nc,.c
        inc h
.c:     ld a,(hl)
        and 0F0h
        or GRAV
        ld de,0105h
        call burst
.ns:    ld a,(framecnt)
        and 7
        cp 4
        ret nz
        ld a,(framecnt)         ; logo colour bands roll across
        rrca
        rrca
        rrca
        ld (phase),a
        ld hl,2*40+2
        ld b,4
.r:     push bc
        push hl
        ld b,35
        ld c,0
.cl:    push bc
        ld a,c
        srl a
        srl a
        ld b,a
        ld a,(phase)
        sub b
        and 7
        ld de,logocols
        add a,e
        ld e,a
        jr nc,.n1
        inc d
.n1:    ld a,(de)
        ld e,a
        call recolour
        inc hl
        pop bc
        inc c
        djnz .cl
        pop hl
        ld de,40
        add hl,de
        pop bc
        djnz .r
        jp blink_space

; "PRESS SPACE TO START" on row 20 blinks
blink_space:
        ld a,(framecnt)
        and 32
        ld e,60h
        jr z,.p
        ld e,00h
.p:     ld hl,20*40+10
        ld b,20
.pl:    call recolour
        inc hl
        djnz .pl
        ret

; ---------------------------------------------------------------------
; page 1: the story so far, typed out, while droids chase a human
draw_story:
        ld hl,620
        call set_len
        call page_frame
        ld hl,story_recs
        call print_recs
        ld hl,story
        ld (storyp),hl
        ld hl,5*40+6
        ld (storyc),hl
        ld (storyl),hl
        xor a
        ld (chase),a
        jp refresh_all

anim_story:
        ld a,(framecnt)         ; type a letter every other tick
        and 1
        jr nz,.chase
        ld hl,(storyp)
        ld a,(hl)
        cp 0FFh
        jr z,.chase
        inc hl
        ld (storyp),hl
        or a
        jr nz,.ch
        ld hl,(storyl)          ; end of line: down two rows
        ld de,80
        add hl,de
        ld (storyl),hl
        ld (storyc),hl
        jr .chase
.ch:    call asc2dc
        ld d,a
        ld e,70h
        ld hl,(storyc)
        call bg_put
        inc hl
        ld (storyc),hl
        ld hl,sfx_type
        ld a,0
        call play_sfx
.chase: ld a,(framecnt)         ; a human runs, droids march after it
        and 3
        jr nz,.nm
        ld a,(chase)
        inc a
        cp 60
        jr c,.cs
        xor a
.cs:    ld (chase),a
.nm:    ld a,(chase)
        ld c,a
        ld a,(framecnt)
        and 8
        ld d,43h                ; running man, bank 2
        jr z,.f
        ld d,45h
.f:     ld e,0E0h               ; yellow on black
        call chase_cell
        ld b,5
.dr:    ld a,c
        sub 3
        ld c,a
        push bc
        ld a,(framecnt)
        and 8
        ld d,30h                ; droids
        jr z,.g
        ld d,31h
.g:     ld e,0A0h
        call chase_cell
        pop bc
        djnz .dr
        ret

; C = column (draw only if 1..38), D/E look, on row 21
chase_cell:
        ld a,c
        dec a
        cp 38
        ret nc
        push bc
        ld l,c
        ld h,0
        ld bc,21*40
        add hl,bc
        call put_cell
        pop bc
        ret

; ---------------------------------------------------------------------
; page 2: the robots, materialising one by one
draw_gallery:
        ld hl,560
        call set_len
        call page_frame
        ld hl,gallery_recs
        call print_recs
        ld hl,gshown
        ld b,10
.z:     ld (hl),0
        inc hl
        djnz .z
        jp refresh_all

anim_gallery:
        ld ix,gallery
        ld hl,30                ; entry k appears at 30 + 36k ticks
        ld (gwhen),hl
        xor a
        ld (gk),a
.l:     ld a,(ix+0)
        or a
        ret z
        ld hl,(ptick)
        ld de,(gwhen)
        or a
        sbc hl,de               ; HL = ticks since it started
        jr c,.nx
        ld a,h
        or a
        jr nz,.done
        ld a,l
        cp 16
        jr nc,.done
        and 3                   ; sparkling in
        jr nz,.nx
        ld a,l
        rrca
        rrca
        and 3
        ld hl,matglyph
        add a,l
        ld l,a
        jr nc,.m
        inc h
.m:     ld d,(hl)
        call gal_attr
        set 7,e
        call gal_put
        jr .nx
.done:  ld a,(gk)                ; arrived: first time, show its name
        ld hl,gshown
        add a,l
        ld l,a
        jr nc,.g1
        inc h
.g1:    ld a,(hl)
        or a
        jr nz,.alive
        ld (hl),1
        call gal_look
        call gal_put
        ld l,(ix+3)
        ld h,(ix+4)
        push hl
        ld b,(ix+0)
        ld a,(ix+1)
        add a,2
        ld c,a
        call calc_ofs
        ex de,hl
        pop hl
        ld c,70h
        call print_bg
        ld hl,sfx_spawn
        ld a,1
        call play_sfx
        jr .nx
.alive: ld a,(framecnt)
        and 15
        cp 4
        jr nz,.nx
        call gal_look
        call gal_put
.nx:    ld hl,(gwhen)
        ld de,36
        add hl,de
        ld (gwhen),hl
        ld hl,gk
        inc (hl)
        ld de,5
        add ix,de
        jp .l

gal_attr:                       ; E = the type's colour on black
        ld a,(ix+2)
        call tinfo_ptr
        inc hl
        inc hl
        ld a,(hl)
        and 0F0h
        ld e,a
        ret

gal_look:                       ; D/E = the type's glyph (animated)
        ld a,(ix+2)
        call tinfo_ptr
        ld d,(hl)
        ld a,(framecnt)
        and 16
        jr z,.g
        inc hl
        ld d,(hl)
        dec hl
.g:     inc hl
        inc hl
        ld a,(hl)
        and 0F0h
        ld e,a
        ret

gal_put:
        push de
        ld b,(ix+0)
        ld c,(ix+1)
        call calc_ofs
        pop de
        jp bg_put

; ---------------------------------------------------------------------
; page 4: the heroes
draw_heroes:
        ld hl,450
        call set_len
        call page_frame
        ld hl,hero_recs
        call print_recs
        ld ix,HISC
        ld b,0                  ; rank
.l:     push bc
        ld a,b                  ; row = 5 + 2 * rank
        add a,a
        add a,5
        ld b,a
        ld c,8
        call calc_ofs
        ex de,hl
        pop bc
        push bc
        ld a,b
        call hero_attr
        ld a,b
        inc a
        call digit_bg
        inc de
        inc de
        push ix                 ; initials
        pop hl
        inc hl
        inc hl
        inc hl
        ld b,3
.n:     ld a,(hl)
        push hl
        push bc
        call asc2dc
        ex de,hl
        ld d,a
        ld e,c
        call bg_put
        ex de,hl
        pop bc
        pop hl
        inc hl
        inc de
        djnz .n
        inc de
        inc de
        push ix
        pop hl
        call print_bcd6
        inc de
        inc de
        ld hl,s_w
        call print_bg
        ld a,(ix+6)
        call print_dec2
        ld de,8
        add ix,de
        pop bc
        inc b
        ld a,b
        cp 8
        jr nz,.l
        jp refresh_all

hero_attr:                      ; A = rank -> C = its colour
        ld hl,herocols
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld c,(hl)
        ret

anim_heroes:
        ld a,(framecnt)         ; fireworks
        and 31
        cp 4
        jr nz,.nf
        call firework
.nf:    ld a,(hinew)            ; the new entry flashes
        cp 8
        ret nc
        ld a,(framecnt)
        and 7
        cp 4
        ret nz
        ld a,(hinew)
        add a,a
        add a,5
        ld b,a
        ld c,8
        call calc_ofs
        ld a,(framecnt)
        rrca
        rrca
        rrca
        and 7
        ld de,bordcols
        add a,e
        ld e,a
        jr nc,.c
        inc d
.c:     ld a,(de)
        ld e,a
        ld b,19
.r:     call recolour
        inc hl
        djnz .r
        ret

; ---------------------------------------------------------------------
; a new high score: A = rank.  Type your initials.
enter_name:
        call hiscore_insert     ; IX = the entry
        ld (nameptr),ix
        call page_frame
        ld hl,name_recs
        call print_recs
        ld hl,score
        ld de,11*40+20
        ld c,70h
        call print_bcd6
        call refresh_all
        ld hl,sfx_extra
        ld a,1
        call play_sfx
        xor a
        ld (nidx),a
        ld hl,1500              ; 30 seconds at most
        ld (ptick),hl
        ld a,60
        ld (ndone),a
.loop:  call wait_vblank
        call flush
        call snd_tick
        call read_keys
        call restore
        call update_particles
        ld hl,framecnt
        inc (hl)
        ld a,(framecnt)
        and 31
        call z,firework
        ld a,(framecnt)
        and 7
        call z,border_colours
        ld hl,(ptick)
        dec hl
        ld (ptick),hl
        ld a,h
        or l
        ret z
        ld a,(sedge)            ; RETURN: done
        and KS_CR
        ret nz
        call get_letter
        or a
        jr z,.cur
        cp 8
        jr z,.del
        ld b,a
        ld a,(nidx)
        cp 3
        jr nc,.cur
        call name_slot          ; HL = initial, DE = its cell
        ld (hl),b
        call show_initial
        ld hl,nidx
        inc (hl)
        ld hl,sfx_type
        ld a,1
        call play_sfx
        jr .cur
.del:   ld a,(nidx)
        or a
        jr z,.cur
        cp 3
        jr nc,.d2
        call name_slot          ; rub out the cursor
        ex de,hl
        ld de,0060h
        call bg_put
.d2:    ld hl,nidx
        dec (hl)
        call name_slot
        ld (hl),' '
        call show_initial
        ld a,60
        ld (ndone),a
.cur:   ld a,(nidx)             ; all three typed: a moment to rub out
        cp 3
        jr c,.blink
        ld hl,ndone
        dec (hl)
        ret z
        jp .loop
.blink: call name_slot          ; the next initial blinks
        ex de,hl                ; HL = its cell
        ld a,(framecnt)
        and 16
        ld d,43h                ; block
        jr z,.b
        ld d,2Ah                ; dash
.b:     ld e,60h
        call bg_put
        jp .loop

; HL = initial (nidx) in the entry, DE = cell offset of it on screen
name_slot:
        ld a,(nidx)
        ld hl,(nameptr)
        inc hl
        inc hl
        inc hl
        ld e,a
        ld d,0
        add hl,de
        push hl
        ld hl,14*40+18
        add hl,de
        ex de,hl
        pop hl
        ret

show_initial:                   ; the initial at HL, in cell DE
        ld a,(hl)
        call asc2dc
        ex de,hl
        ld d,a
        ld e,60h
        jp bg_put

; ---------------------------------------------------------------------
; the border's colours flow round diagonally
border_colours:
        ld a,(framecnt)
        rrca
        rrca
        rrca
        ld (phase),a
        ld hl,0
        ld c,0
        ld b,40
.t:     call border_cell
        inc hl
        inc c
        djnz .t
        ld hl,24*40
        ld c,24
        ld b,40
.bt:    call border_cell
        inc hl
        inc c
        djnz .bt
        ld hl,40
        ld c,1
        ld b,23
.s:     call border_cell
        push hl
        push bc
        ld de,39
        add hl,de
        ld a,c
        add a,39
        ld c,a
        call border_cell
        pop bc
        pop hl
        ld de,40
        add hl,de
        inc c
        djnz .s
        ret

; colour border cell HL by C (= row + column) and the phase
border_cell:
        push bc
        push hl
        ld a,(phase)
        sub c
        and 7
        ld hl,bordcols
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld e,(hl)
        pop hl
        call recolour
        pop bc
        ret

; give BG cell HL attribute E, keeping its character
recolour:
        push hl
        push bc
        ld bc,BGCH
        add hl,bc
        ld d,(hl)
        pop bc
        pop hl
        jp bg_put

bordcols:
        db 20h,60h,40h,50h,10h,30h,70h,60h
logocols:
        db 20h,20h,60h,60h,70h,50h,30h,30h
herocols:
        db 60h,70h,50h,40h,30h,20h,50h,70h

; ---------------------------------------------------------------------
title_recs:
        db 7,0FFh,60h
        db "- 2085 -",0
        db 9,0FFh,50h
        db "SHARP MZ-700 VERSION",0
        db 10,0FFh,70h
        db "VIBED BY BPM 2026",0
        db 13,6,70h
        db "MOVE        W A S D",0
        db 14,6,70h
        db "FIRE        I J K L OR CURSORS",0
        db 15,6,70h
        db "CONTROL 1-3",0
        db 16,6,70h
        db "PAUSE       RETURN",0
        db 17,6,70h
        db "SOUND (M)",0
        db 18,6,70h
        db "TRAINER (T)",0
        db 20,10,60h
        db "PRESS SPACE TO START",0
        db 22,13,50h
        db "HI SCORE",0
        db 0FFh

story_recs:
        db 2,0FFh,60h
        db "- THE STORY SO FAR -",0
        db 0FFh

story:
        db "THE YEAR IS 2085.",0
        db "OUR OWN ROBOTS HAVE TURNED",0
        db "ON US: THE ROBOGEDDON.",0
        db "ONE FAMILY IS LEFT, AND",0
        db "ONLY YOU CAN SAVE THEM.",0
        db "BLAST EVERY ROBOT, SAVE THE",0
        db "HUMANS. NEVER STOP MOVING!",0
        db 0FFh

gallery_recs:
        db 2,0FFh,60h
        db "- THE ROBOTS -",0
        db 0FFh

gallery:                        ; row, column, type, name (row 0 ends)
        db 5,4,T_DROID
        dw s_g_droid
        db 9,4,T_PYLON
        dw s_g_pylon
        db 13,4,T_CRUSH
        dw s_g_crush
        db 17,4,T_ORB
        dw s_g_orb
        db 21,4,T_SEEKER
        dw s_g_seek
        db 5,22,T_BRAIN
        dw s_g_brain
        db 9,22,T_MUTANT
        dw s_g_mut
        db 13,22,T_FACT
        dw s_g_fact
        db 17,22,T_TANK
        dw s_g_tank
        db 21,22,T_DAD
        dw s_g_hum
        db 0
s_g_droid:  db "DROID    100",0
s_g_pylon:  db "PYLON     25",0
s_g_crush:  db "CRUSHER  ---",0
s_g_orb:    db "ORB     1000",0
s_g_seek:   db "SEEKER   150",0
s_g_brain:  db "MINDBOT  500",0
s_g_mut:    db "MUTANT   100",0
s_g_fact:   db "FACTORY 1000",0
s_g_tank:   db "TANK     200",0
s_g_hum:    db "HUMANS 1000+",0

hero_recs:
        db 2,0FFh,60h
        db "- ROBOGEDDON HEROES -",0
        db 22,0FFh,50h
        db "SHOOT THEIR SHOTS FOR 25",0
        db 0FFh

name_recs:
        db 5,0FFh,60h
        db "GREAT SCORE!",0
        db 8,0FFh,70h
        db "ENTER YOUR INITIALS",0
        db 11,13,50h
        db "SCORE",0
        db 18,0FFh,50h
        db "TYPE A-Z, RETURN WHEN DONE",0
        db 19,0FFh,50h
        db "DEL RUBS OUT",0
        db 0FFh

s_snd_all:  db "ALL    ",0
s_snd_fx:   db "FX ONLY",0
s_snd_off:  db "OFF    ",0
s_ctl_keys: db "KEYBOARD      ",0
s_ctl_twin: db "TWIN JOYSTICKS",0
s_ctl_one:  db "ONE JOYSTICK  ",0
s_on:       db "ON ",0
s_off:      db "OFF",0

howto_recs:
        db 2,0FFh,60h
        db "- HOW TO PLAY -",0
        db 4,2,70h
        db "SHOOT EVERY ROBOT TO CLEAR THE WAVE.",0
        db 6,2,70h
        db "GET NEXT TO THE HUMANS TO SAVE THEM:",0
        db 7,2,70h
        db "1000, THEN 2000 ... UP TO 5000 EACH.",0
        db 9,2,70h
        db "SAVE SOME, LOSE NONE: 5000 BONUS.",0
        db 11,2,70h
        db "AN EXTRA LIFE EVERY 25000 POINTS.",0
        db 13,2,50h
        db "POWER-UPS, FROM WAVE 2:",0
        db 15,6,60h
        db "3-WAY   TRIPLE SHOT, 10 SECONDS",0
        db 17,6,50h
        db "SHIELD  6 SECONDS. ROBOTS THAT",0
        db 18,6,50h
        db "        TOUCH YOU ARE DESTROYED",0
        db 20,2,70h
        db "EACH POWER-UP IS WORTH 250.",0
        db 22,2,70h
        db "T ON THE TITLE: TRAINER MODE.",0
        db 0FFh

        include "../build/gen_logo.inc"
