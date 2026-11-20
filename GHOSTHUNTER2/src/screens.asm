; =====================================================================
;  screens.asm - attract sequence: title, meet the ghosts, power-ups,
;  demo, hall of fame; initials entry; screen wipes
; =====================================================================
CHASE_ROW       equ 19

attract:
        ld sp,STACKTOP
        xor a
        ld (demo),a
        ld (sirenmode),a
.cycle: call title_screen
        jr nz,.go
        call meet_ghosts
        jr nz,.go
        call powerups_screen
        jr nz,.go
        call run_demo
        jr nz,.go
        call hiscore_screen
        jr nz,.go
        jr .cycle
.go:    ld sp,STACKTOP
        call mus_stop
        call sfx_stop
        call wait_release
        call start_game
        call wait_release
        call enter_hiscore
        jr attract

; ---------------------------------------------------------------------
; wipes: blinds, eight passes of every eighth row
wipe_out:
        call ovl_clear
        call frame
        call ovl_forget
        ld e,0
.p:     ld a,e
.r:     cp 25
        jr nc,.n
        push af
        push de
        call row_addr
        ld b,40
.c:     ld (hl),0
        set 3,h
        ld (hl),BLACK*16+BLACK
        res 3,h
        inc hl
        djnz .c
        pop de
        pop af
        add a,8
        jr .r
.n:     push de
        call frame
        pop de
        inc e
        ld a,e
        cp 8
        jr nz,.p
        ret

wipe_in:
        call ovl_forget
        ld e,0
.p:     ld a,e
.r:     cp 25
        jr nc,.n
        push af
        push de
        call row_addr               ; HL = VRAM row
        ex de,hl
        ld h,d
        ld l,e
        res 6,h                     ; HL = background row
        push de
        push hl
        ld bc,40
        ldir
        pop hl
        pop de
        set 3,h
        set 3,d
        ld bc,40
        ldir
        pop de
        pop af
        add a,8
        jr .r
.n:     push de
        call frame
        pop de
        inc e
        ld a,e
        cp 8
        jr nz,.p
        ret

; ---------------------------------------------------------------------
; background helpers (front-end pages are drawn into BG, then wiped in)
; print into the background: HL = string, B = col, C = row, A = attr
bg_print:
        push af
        call vaddr
        res 6,d
        pop af
        ld c,a
        jp print

; centred on row C
bg_centre:
        push af
        push hl
        ld b,0
.n:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        cp 8
        jr c,.n
        inc b
        jr .n
.e:     ld a,40
        sub b
        srl a
        ld b,a
        pop hl
        pop af
        jr bg_print

; one character into the background: A = char, B = col, C = row, E = attr
bg_putc:
        push hl
        push de
        push af
        call vaddr
        res 6,d
        pop af
        ld (de),a
        set 3,d
        pop hl
        ld a,l
        ld (de),a
        pop hl
        ret

; clear the background: chars 0, attr A
; (cls_bg in game.asm)

; ---------------------------------------------------------------------
; TITLE
title_screen:
        call wipe_out
        ld hl,TITLE_CH
        ld de,BGCH
        ld bc,1000
        ldir
        ld hl,TITLE_AT
        ld de,BGAT
        ld bc,1000
        ldir
        ld hl,s_tag
        ld c,12
        ld a,GREEN*16+BLACK
        call bg_centre
        ld hl,s_hiscore             ; HI-SCORE 012345 BPM
        ld b,10
        ld c,23
        ld a,CYAN*16+BLACK
        call bg_print
        ld hl,HITAB
        ld b,3
        ld c,WHITE*16+BLACK
        call print_bcd_hi
        inc de
        ld hl,HITAB+3
        ld b,3
.nm:    ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,YELLOW*16+BLACK
        ld (de),a
        res 3,d
        inc de
        djnz .nm
        call wipe_in
        ld hl,SONG_TITLE
        call mus_play
        ld hl,0
        ld (attr_t),hl
        ld a,0FFh
        ld (msgidx),a
.loop:  call ovl_clear
        call title_chase
        call title_twinkle
        call title_gleam
        call title_message
        ld hl,(attr_t)              ; lightning
        ld a,h
        or a
        jr nz,.nl
        ld a,l
        cp 150
        jr z,.lt
        cp 158
        jr z,.lt
        cp 153
        jr z,.lo
        cp 161
        jr nz,.nl
.lo:    call lightning_off
        jr .nl
.lt:    call lightning_on
        ld hl,SFX_THUNDER
        ld a,2
        call sfx
.nl:    call frame
        call start_pressed
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,1100
        or a
        sbc hl,de
        jr nz,.loop
        call mus_stop
        xor a
        ret

; the hero runs from the ghosts, then turns the tables
title_chase:
        ld a,(attr_t)
        ld c,CHASE_ROW
; chase scene: A = time (0..255 = chased, else hunting), C = row
chase_scene:
        push af
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        ld (anim),a
        pop af
        ld d,a
        ld a,(attr_t+1)
        and 1
        jr nz,.hunt
        ld a,d                      ; hero x = t/4 - 4, ghosts behind
        srl a
        srl a
        sub 4
        ld b,a
        push bc
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,BH_R0
        call draw_big
        pop bc
        ld e,0
.g1:    ld a,b
        sub 5
        ld b,a
        push bc
        push de
        ld a,e
        add a,a
        add a,BG_RED0
        ld e,a
        ld a,(anim)
        add a,e
        call draw_big
        pop de
        pop bc
        inc e
        ld a,e
        cp 4
        jr nz,.g1
        ret
.hunt:  ld a,d                      ; frightened ghosts flee left, hero behind
        srl a
        srl a
        ld e,a
        ld a,42
        sub e
        ld b,a
        ld e,4
.g2:    push bc
        push de
        ld a,(anim)
        add a,BG_BLUE0
        call draw_big
        pop de
        pop bc
        ld a,b
        add a,5
        ld b,a
        dec e
        jr nz,.g2
        inc b
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,BH_L0
        jp draw_big

; twinkle a random star now and then
title_twinkle:
        ld a,(framecount)
        and 3
        ret nz
        ld b,NSTARS
        call rand_below
        add a,a
        ld e,a
        ld d,0
        ld hl,STARS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                      ; VRAM address of the star
        push hl
        ld b,4
        call rand_below
        ld e,a
        ld d,0
        ld hl,star_cols
        add hl,de
        ld a,(hl)
        pop hl
        push af
        res 6,h
        set 3,h
        pop af
        ld (hl),a
        set 6,h
        ld (hl),a
        ret
star_cols: db WHITE*16+BLACK, YELLOW*16+BLACK, CYAN*16+BLACK, BLUE*16+BLACK

; a gleam sweeps across the big 2 every five seconds
TWO_COL equ 32
TWO_ROW equ 5
title_gleam:
        ld hl,(attr_t)
        ld a,l
        and 0FFh
        sub 40
        ret c
        cp 16
        ret nc
        ld (best),a                 ; diagonal index
        ld c,TWO_ROW
.r:     ld b,TWO_COL
.c:     push bc
        ld a,b
        sub TWO_COL
        add a,c
        sub TWO_ROW
        ld l,a
        ld a,(best)
        sub l
        cp 2
        push af
        call vaddr
        ld h,d
        ld l,e
        res 6,h
        set 3,h
        set 3,d
        pop af
        ld a,(hl)
        jr nc,.st
        and 8Fh
        or WHITE*16
.st:    ld (de),a
        pop bc
        inc b
        ld a,b
        cp TWO_COL+6
        jr nz,.c
        inc c
        ld a,c
        cp TWO_ROW+7
        jr nz,.r
        ret

; bottom line: four messages in turn, the first one flashing
title_message:
        ld hl,(attr_t)
        add hl,hl
        ld a,h
        and 3
        ld c,a
        ld a,(msgidx)
        cp c
        jr z,.same
        ld a,c
        ld (msgidx),a
        ld b,24
        ld c,1
        ld a,BLACK*16+BLACK
        call clear_rows
        ld a,(msgidx)
        add a,a
        ld e,a
        ld d,0
        ld hl,title_msgs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,24
        ld a,YELLOW*16+BLACK
        call print_centre
        ret
.same:  ld a,c
        or a
        ret nz
        ld a,(framecount)
        and 15
        ret nz
        ld a,(framecount)
        and 16
        ld a,YELLOW*16+BLACK
        jr z,$+4
        ld a,WHITE*16+BLACK
        ld de,VRAM+24*40
        ld b,40
        jp fill_attr
title_msgs: dw tm0,tm1,tm2,tm3

; lightning: the sky (rows 0-16, black background) turns white
lightning_on:
        ld hl,BGAT
        ld de,ARAM
        ld bc,17*40
.l:     ld a,(hl)
        and 07h
        ld a,(hl)
        jr nz,.n
        or WHITE
.n:     ld (de),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret
lightning_off:
        ld hl,BGAT
        ld de,ARAM
        ld bc,17*40
        ldir
        ret

; ---------------------------------------------------------------------
; MEET THE GHOSTS
meet_ghosts:
        call wipe_out
        ld a,BLACK*16+BLACK
        call cls_bg
        ld hl,s_meet
        ld c,1
        ld a,YELLOW*16+BLACK
        call bg_centre
        ld b,0
.e:     push bc
        ld a,b                      ; entry row = 4 + 5 * i
        add a,a
        add a,a
        add a,b
        add a,4
        ld c,a
        ld a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,meet_strs
        add hl,de
        ld a,(hl)                   ; colour
        inc hl
        push af
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop af
        push bc
        push hl
        ld b,8
        call bg_print
        pop hl
.sk:    ld a,(hl)
        inc hl
        or a
        jr nz,.sk
        pop bc
        inc c
        ld b,8
        ld a,WHITE*16+BLACK
        call bg_print
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.e
        ld hl,s_meet_b
        ld c,23
        ld a,CYAN*16+BLACK
        call bg_centre
        call wipe_in
        ld hl,0
        ld (attr_t),hl
.loop:  call ovl_clear
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        ld (anim),a
        ld b,0
.g:     push bc
        ld a,b
        add a,a
        add a,a
        add a,b
        add a,4
        ld c,a
        ld a,b
        cp 3                        ; PEEKABOO: now you see him...
        jr nz,.vis
        ld a,(attr_t)
        and 64
        jr z,.vis
        ld a,(attr_t)
        and 4
        jr z,.vis
        inc c
        ld b,4
        ld a,71h
        ld e,WHITE*16+ALT
        call ovl_sc
        jr .nx
.vis:   ld a,b
        add a,a
        add a,BG_RED0
        ld e,a
        ld a,(anim)
        add a,e
        ld b,3
        call draw_big
.nx:    pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.g
        call frame
        call start_pressed
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,450
        or a
        sbc hl,de
        jr nz,.loop
        xor a
        ret

meet_strs:
        db RED*16+BLACK : dw mg0
        db 0
        db GREEN*16+BLACK : dw mg1
        db 0
        db MAGENTA*16+BLACK : dw mg2
        db 0
        db CYAN*16+BLACK : dw mg3
        db 0

; ---------------------------------------------------------------------
; POWER UP!
powerups_screen:
        call wipe_out
        ld a,BLACK*16+BLACK
        call cls_bg
        ld hl,s_pow
        ld c,1
        ld a,YELLOW*16+BLACK
        call bg_centre
        ld b,0
.l:     push bc
        ld a,b                      ; row 4 + 2i
        add a,a
        add a,4
        ld c,a
        ld a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,pow_tab
        add hl,de
        ld a,(hl)                   ; icon glyph
        inc hl
        ld e,(hl)                   ; icon attr
        inc hl
        push hl
        push bc
        ld b,4
        call bg_putc
        pop bc
        pop hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,7
        ld a,b
        pop de
        push de
        ld a,d
        cp 6
        ld a,GREEN*16+BLACK
        jr nz,$+4
        ld a,YELLOW*16+BLACK
        call bg_print
        pop bc
        inc b
        ld a,b
        cp 7
        jr nz,.l
        ld hl,ctl1
        ld c,19
        ld a,WHITE*16+BLACK
        call bg_centre
        ld hl,ctl2
        ld c,21
        ld a,WHITE*16+BLACK
        call bg_centre
        ld hl,ctl3
        ld c,23
        ld a,CYAN*16+BLACK
        call bg_centre
        call wipe_in
        ld hl,0
        ld (attr_t),hl
.loop:  call ovl_clear
        ld a,(framecount)           ; the star flashes
        and 4
        ld e,YELLOW*16
        jr z,$+4
        ld e,RED*16
        ld a,6Bh
        ld b,4
        ld c,16
        call ovl_sc
        ld a,(framecount)           ; the energiser blinks
        and 16
        jr z,.ev
        ld a,86h
        ld e,BLACK*16+ALT
        ld b,4
        ld c,4
        call ovl_sc
.ev:    call frame
        call start_pressed
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,450
        or a
        sbc hl,de
        jr nz,.loop
        xor a
        ret

pow_tab:
        db 86h, YELLOW*16+ALT : dw pw0
        db 0C3h, YELLOW*16 : dw pw1
        db 0B3h, WHITE*16+ALT : dw pw2
        db 3Dh, WHITE*16+ALT : dw pw3
        db 22h, RED*16+ALT : dw pw4
        db 8Eh, GREEN*16+ALT : dw pw5
        db 6Bh, YELLOW*16 : dw pw6

; ---------------------------------------------------------------------
; DEMO: the real game, played by the pilot
run_demo:
        call mus_stop
        ld a,1
        ld (demo),a
        xor a
        ld (demo_abort),a
        ld b,6
        call rand_below
        ld (mazeidx),a
        and 3
        inc a
        ld (level),a
        ld a,1
        ld (lives),a
        ld hl,score
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld hl,1500
        ld (demotim),hl
        call level_start
        xor a
        ld (demo),a
        ld (sirenmode),a
        ld (frighttim),a
        ld (supertim),a
        call mus_stop
        call sfx_stop
        ld a,(palette)
        or a
        jr z,.np
        xor a
        call set_palette
        call recolour_all
.np:    ld a,(demo_abort)
        or a
        ret z
        call wait_release
        or 1
        ret

; ---------------------------------------------------------------------
; HALL OF FAME
hiscore_screen:
        call wipe_out
        call draw_hof
        ld hl,s_play
        ld c,23
        ld a,YELLOW*16+BLACK
        call bg_centre
        call wipe_in
        ld hl,0
        ld (attr_t),hl
.loop:  call ovl_clear
        call hof_parade
        call frame
        call start_pressed
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,500
        or a
        sbc hl,de
        jr nz,.loop
        xor a
        ret

; draw the table into the background
draw_hof:
        ld a,BLACK*16+BLACK
        call cls_bg
        ld hl,s_hof
        ld c,2
        ld a,YELLOW*16+BLACK
        call bg_centre
        ld b,0
.l:     push bc
        ld a,b
        add a,a
        add a,6
        ld c,a                      ; row 6 + 2i
        ld a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,ranks
        add hl,de
        ld a,b
        push bc
        ld e,a
        ld d,0
        push hl
        ld hl,rank_cols
        add hl,de
        ld a,(hl)
        pop hl
        ld b,11
        call bg_print               ; "1ST"
        pop bc
        ld a,b                      ; score
        add a,a
        add a,b
        add a,a
        ld e,a
        ld d,0
        ld hl,HITAB
        add hl,de
        push hl
        ld b,16
        call vaddr
        res 6,d
        pop hl
        push hl
        ld b,3
        ld c,WHITE*16+BLACK
        call print_bcd_hi
        inc de
        inc de
        pop hl
        inc hl
        inc hl
        inc hl
        ld b,3
.nm:    ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,YELLOW*16+BLACK
        ld (de),a
        res 3,d
        inc de
        djnz .nm
        pop bc
        inc b
        ld a,b
        cp 5
        jr nz,.l
        ret
rank_cols: db YELLOW*16+BLACK, WHITE*16+BLACK, CYAN*16+BLACK, GREEN*16+BLACK, MAGENTA*16+BLACK

; ghosts and the hero parade along row 19
hof_parade:
        ld a,(attr_t)
        ld c,18
        jp chase_scene

; ---------------------------------------------------------------------
; NEW HIGH SCORE: rank the score, enter three initials
enter_hiscore:
        ld b,0                      ; find the rank
        ld hl,HITAB
.f:     push hl
        ld de,score
        ld c,3
.c:     ld a,(de)
        cp (hl)
        jr c,.lower
        jr nz,.higher
        inc hl
        inc de
        dec c
        jr nz,.c
.lower: pop hl
        ld de,6
        add hl,de
        inc b
        ld a,b
        cp 5
        jr nz,.f
        ret                         ; not in the table
.higher:
        pop hl
        ld a,b
        ld (hs_rank),a
        ld a,4                      ; shift the lower entries down
        sub b
        jr z,.ins
        ld c,a
        add a,a
        add a,c
        add a,a
        ld c,a
        ld b,0
        ld hl,HITAB+4*6-1
        ld de,HITAB+5*6-1
        lddr
.ins:   ld a,(hs_rank)
        ld b,a
        add a,a
        add a,b
        add a,a
        ld e,a
        ld d,0
        ld hl,HITAB
        add hl,de
        ex de,hl
        ld hl,score
        ld bc,3
        ldir
        ld a,'A'
        ld (de),a
        inc de
        ld a,'A'
        ld (de),a
        inc de
        ld a,'A'
        ld (de),a
        ld a,(hs_rank)              ; best ever?
        or a
        jr nz,.nb
        ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
.nb:    call wipe_out
        call draw_hof
        ld hl,s_nhs
        ld c,18
        ld a,YELLOW*16+BLACK
        call bg_centre
        ld hl,s_ent
        ld c,20
        ld a,WHITE*16+BLACK
        call bg_centre
        ld hl,s_enthelp
        ld c,22
        ld a,CYAN*16+BLACK
        call bg_centre
        call wipe_in
        ld hl,SONG_HISCORE
        call mus_play
        xor a
        ld (hs_pos),a
        call fe_reset
.loop:  call ovl_clear
        ld a,(hs_rank)              ; the letter being entered flashes
        add a,a
        add a,6
        ld c,a
        ld a,(hs_pos)
        add a,24
        ld b,a
        ld a,(framecount)
        and 8
        jr z,.fl
        ld a,0
        ld e,WHITE*16+8+WHITE
        call ovl_sc
.fl:    call frame
        call fe_keys
        ld c,a
        call hs_cur                 ; HL -> current letter
        bit B_UP,c
        jr z,.n1
        push bc
        call next_letter
        call hs_show
        pop bc
.n1:    bit B_DOWN,c
        jr z,.n2
        push bc
        call prev_letter
        call hs_show
        pop bc
.n2:    bit B_LEFT,c
        jr z,.n3
        ld a,(hs_pos)
        or a
        jr z,.n3
        dec a
        ld (hs_pos),a
.n3:    ld a,c
        and K_FIRE+K_RIGHT
        jr z,.n4
        ld hl,SFX_LETTER
        ld a,1
        call sfx
        ld a,(hs_pos)
        inc a
        ld (hs_pos),a
        cp 3
        jr z,.done
.n4:    ld a,(key_pause)
        or a
        jr z,.loop
.done:  call mus_stop
        ld b,60
.w:     push bc
        call blank_frame
        pop bc
        djnz .w
        ret

hs_cur: ld a,(hs_rank)
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,3
        ld e,a
        ld a,(hs_pos)
        add a,e
        ld e,a
        ld d,0
        ld hl,HITAB
        add hl,de
        ret

; put the current letter on the screen (and background)
hs_show:
        ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        push af
        ld a,(hs_rank)
        add a,a
        add a,6
        ld c,a
        ld a,(hs_pos)
        add a,24
        ld b,a
        pop af
        ld e,YELLOW*16+BLACK
        push bc
        push af
        call bg_putc
        pop af
        pop bc
        call vaddr
        ld (de),a
        set 3,d
        ld a,YELLOW*16+BLACK
        ld (de),a
        ld hl,SFX_CLICK
        ld a,1
        jp sfx

next_letter:
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr nz,.s
        ld a,' '
.s:     cp ' '+1
        jr nz,.t
        ld a,'A'
.t:     ld (hl),a
        ret
prev_letter:
        ld a,(hl)
        cp 'A'
        jr nz,.a
        ld a,' '
        jr .t
.a:     cp ' '
        jr nz,.b
        ld a,'Z'
        jr .t
.b:     dec a
.t:     ld (hl),a
        ret
