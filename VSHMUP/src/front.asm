; =====================================================================
;  front.asm - attract sequence, title, high scores, initials
;
;  Pages cycle: title -> story -> enemies -> power-ups -> demo -> high
;  scores.  Stars drift behind every page.  SPACE (or a joystick
;  button) starts a game from anywhere.
; =====================================================================

; -> A = 0: start a game, 1: run the demo
front_end:
        xor a
        ld (demo),a
        call sfx_stop
.page:  ld a,(page)
        cp PG_DEMO
        jr nz,.show
        ld a,1                  ; the demo
        ret
.show:  call page_setup
.tick:  call wait_tick
        call joy_sample1
        call flush
        call joy_sample2
        call read_keys
        call restore
        call stars_tick
        call page_anim
        ld hl,framecnt
        inc (hl)
        ld a,(sedge)
        and KS_M
        call nz,cycle_sound
        ld a,(sedge)
        and KS_J
        call nz,toggle_joy
        ld a,(sedge)
        and KS_SPACE
        jr nz,.start
        ld hl,(ptick)
        inc hl
        ld (ptick),hl
        ld de,(pagelen)
        or a
        sbc hl,de
        jr c,.tick
        call next_page
        jr .page
.start: xor a
        ret

next_page:
        ld a,(page)
        inc a
        cp NPAGES
        jr c,.p
        xor a
.p:     ld (page),a
        ret

; build the page's screen
page_setup:
        ld hl,0
        ld (ptick),hl
        ld a,40
        ld (starw),a
        call clear_objects
        call scn_clear
        xor a
        ld (typed),a
        ld hl,0
        ld (typep),hl
        ld a,70h
        call clear_bg
        ld a,(page)
        or a
        jr nz,.n1
        ; ---- title
        ld hl,750
        ld (pagelen),hl
        call draw_logo
        ld hl,titletext
        call print_list
        call joy_show
        ld hl,hiscore
        ld de,22*40+21
        ld c,50h
        call print_score
        ld a,(trk_on)           ; the title tune (if not already playing)
        or a
        jr nz,.fin
        ld hl,TRK_TITLE
        call play_tune
        jr .fin
.n1:    cp PG_STORY
        jr nz,.n2
        ld hl,500
        ld (pagelen),hl
        ld hl,txt_story_h
        ld b,1
        ld c,60h
        call print_centre
        ld hl,story
        ld (typep),hl
        jr .fin
.n2:    cp PG_FOES
        jr nz,.n3
        ld hl,400
        ld (pagelen),hl
        call draw_foes
        jr .fin
.n3:    cp PG_ITEMS
        jr nz,.n5
        ld hl,450
        ld (pagelen),hl
        call draw_items
        jr .fin
.n5:    ; high scores
        ld hl,400
        ld (pagelen),hl
        call draw_scores
.fin:   call stars_draw
        jp refresh_all

; HL = list of (row, column, attribute, text, 0), ending FFh
print_list:
.t:     ld a,(hl)
        cp 0FFh
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        call print_at
        jr .t

titletext:
        db 16,10,70h,"PRESS SPACE TO PLAY",0
        db 17,3,50h,"MOVE",0
        db 17,10,70h,"CURSOR KEYS OR W A S D",0
        db 18,3,50h,"FIRE",0
        db 18,10,70h,"SPACE, Z OR K",0
        db 19,3,50h,"BOMB",0
        db 19,10,70h,"B, X OR L",0
        db 20,3,50h,"ALSO",0
        db 20,10,70h,"M SOUND, RETURN PAUSE",0
        db 21,10,70h,"J JOYSTICK (PORT A)",0
        db 22,12,60h,"HI-SCORE",0
        db 24,11,10h,"VIBED BY BPM 2026",0
        db 0FFh

; ---------------------------------------------------------------------
; the NOVA STORM logo (tools/logo.py): column, row, width, height, then a
; (char, attribute) pair per cell, 0,0 = empty.  It is drawn into BG once;
; then a white shine sweeps across it diagonally and a star twinkles in
; the O.
draw_logo:
        ld hl,logo+4
        ld a,(logo+1)
        ld b,a
        ld a,(logo+3)
.r:     push af
        ld a,(logo)
        ld c,a
        ld a,(logo+2)
.c:     push af
        ld e,(hl)               ; char
        inc hl
        ld d,(hl)               ; attribute
        inc hl
        ld a,d
        or e
        jr z,.sk
        push hl
        push bc
        ld a,e
        ld e,d
        ld d,a
        call calc_ofs
        call bg_put
        pop bc
        pop hl
.sk:    inc c
        pop af
        dec a
        jr nz,.c
        inc b
        pop af
        dec a
        jr nz,.r
        ret

page_anim:
        ld a,(page)
        or a
        jr nz,.n1
        ; title: the logo shines, the star twinkles, a ship patrols
        call logo_shine
        call logo_twinkle
        jp title_ship
.n1:    cp PG_STORY
        jp z,story_type
        ret

; the shine: diagonal (column + row) = logophase, one step a tick, with a
; pause between sweeps.  Face colours turn white in it.
logo_shine:
        ld a,(logophase)
        inc a
        cp 110
        jr c,.s
        xor a
.s:     ld (logophase),a
        ld e,1
        call logo_diag          ; the new diagonal shines
        ld a,(logophase)
        dec a
        ld e,1
        call logo_diag
        ld a,(logophase)
        sub 2
        ld e,0                  ; the one behind it goes back
        jp logo_diag

; A = diagonal (column + row), E = 1 shine / 0 normal: redraw its cells
logo_diag:
        ld (ldiag),a
        ld a,e
        ld (lshine),a
        ld hl,logo+4
        ld (lrowp),hl
        ld a,(logo+1)           ; row = row0 .. row0 + h - 1
        ld b,a
        ld a,(logo+3)
.r:     push af
        ld a,(ldiag)            ; column = diagonal - row
        sub b
        jr c,.nx
        ld c,a
        ld hl,logo
        sub (hl)                ; inside the logo's columns?
        jr c,.nx
        ld hl,logo+2
        cp (hl)
        jr nc,.nx
        ld e,a
        ld d,0
        ld hl,(lrowp)
        add hl,de
        add hl,de
        ld e,(hl)               ; char
        inc hl
        ld d,(hl)               ; attribute
        ld a,d
        or e
        jr z,.nx
        ld a,(lshine)
        or a
        jr z,.put
        ld a,d                  ; shine: face colours (not blue or black) -> white
        and 70h
        cp 10h
        jr z,.bg
        or a
        jr z,.bg
        ld a,d
        or 70h
        ld d,a
.bg:    ld a,d
        and 07h
        cp 1
        jr z,.put
        or a
        jr z,.put
        ld a,d
        or 07h
        ld d,a
.put:   push bc
        ld a,e
        ld e,d
        ld d,a
        call calc_ofs
        call bg_put
        pop bc
.nx:    ld hl,(lrowp)           ; next row of the data
        ld a,(logo+2)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld (lrowp),hl
        inc b
        pop af
        dec a
        jr nz,.r
        ret

; a star twinkling in the hole of the O (screen row 4, column 16)
logo_twinkle:
        ld a,(twk)
        inc a
        cp 40
        jr c,.t
        xor a
.t:     ld (twk),a
        srl a
        cp 7
        jr c,.on
        ret nz                  ; (only once, at the end, to clear it)
.on:    ld l,a
        ld h,0
        add hl,hl
        ld de,twkseq
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld hl,4*40+16
        jp bg_put
twkseq: db 85h,0F0h, 6Ah,60h, 6Bh,70h, 0A0h,0F0h, 6Bh,70h, 6Ah,60h, 85h,0E0h, 0,70h

; the little ship on the title, sweeping to and fro; the prompt blinks
title_ship:
        ld a,(framecnt)
        and 63
        cp 32
        jr c,.r
        cpl
        and 31
.r:     add a,a                 ; 0..62 -> half speed via framecnt
        srl a
        add a,4                 ; column 4..35
        ld c,a
        ld b,14
        ld iy,SPR_PLAYER
        ld a,(iy+0)
        inc iy
.l:     push af
        push bc
        ld a,(iy+0)
        add a,c
        ld c,a
        ld a,(iy+1)
        add a,b
        ld b,a
        ld d,(iy+2)
        ld e,(iy+3)
        call put_one40
        ld de,4
        add iy,de
        pop bc
        pop af
        dec a
        jr nz,.l
        ld a,(framecnt)         ; the prompt
        and 15
        ret nz
        ld a,(framecnt)
        and 16
        ld a,70h
        jr z,.p
        ld a,60h
.p:     ld hl,titletext+3
        ld b,16
        ld c,10
        jp print_at

; ---------------------------------------------------------------------
; the story, typed a letter at a time
story_type:
        ld hl,(typep)
        ld a,h
        or l
        ret z
.l:     ld a,(hl)
        inc hl
        cp 0FFh
        jr nz,.c
        ld hl,0
        ld (typep),hl
        ret
.c:     or a
        jr nz,.ch
        ; new line: 0, row, column follow
        ld a,(hl)
        inc hl
        ld (typer),a
        ld a,(hl)
        inc hl
        ld (typec),a
        jr .l
.ch:    ld (typep),hl
        call asc2dc
        ld d,a
        ld e,70h
        ld a,(typer)
        ld b,a
        ld a,(typec)
        ld c,a
        inc a
        ld (typec),a
        call calc_ofs
        jp bg_put

txt_story_h: db "THE STORY SO FAR",0
story:  db 0,4,4,"THE YEAR IS 2190.",0
        db 6,4,"THE STORM FLEET HAS TORN",0
        db 7,4,"THROUGH THE OUTER RIM AND",0
        db 8,4,"IS DRIVING FOR THE CORE.",0
        db 10,4,"ONE PROTOTYPE FIGHTER IS",0
        db 11,4,"READY: THE NOVA.",0
        db 13,4,"FIVE SECTORS STAND BETWEEN",0
        db 14,4,"YOU AND THE OVERMIND THAT",0
        db 15,4,"COMMANDS THE FLEET. EACH IS",0
        db 16,4,"HELD BY ONE OF ITS WARLORDS.",0
        db 18,4,"SHOOT THE RED GUNSHIPS FOR",0
        db 19,4,"POWER-UPS. CATCH EVERY MEDAL.",0
        db 21,4,"GOOD LUCK, PILOT.",0FFh

; ---------------------------------------------------------------------
; enemies with their points
draw_foes:
        ld hl,txt_foes_h
        ld b,1
        ld c,60h
        call print_centre
        ld hl,foelist
.f:     ld a,(hl)
        cp 0FFh
        ret z
        ld b,a                  ; row
        inc hl
        ld c,(hl)               ; column
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = sprite
        inc hl
        push hl
        push bc
        push de
        pop iy
        call bg_sprite
        pop bc
        pop hl
        ld a,c                  ; name at column + 4
        add a,4
        ld c,a
        ld a,70h
        call print_at
        jr .f

txt_foes_h: db "THE STORM FLEET",0
foelist:
        db 4,1
        dw SPR_DART0
        db "DART      100",0
        db 6,1
        dw SPR_WASP0
        db "WASP      100",0
        db 8,1
        dw SPR_CRAB0
        db "CRAB      150",0
        db 10,1
        dw SPR_BUG0
        db "HORNET    100",0
        db 12,1
        dw SPR_SKULL0
        db "SKULL     200",0
        db 14,1
        dw SPR_EYE0
        db "WATCHER   300",0
        db 16,1
        dw SPR_MINE0
        db "MINE      200",0
        db 4,21
        dw SPR_FISHR
        db "RAY    100",0
        db 6,20
        dw SPR_UFO0
        db "SAUCER  500",0
        db 8,20
        dw SPR_GUN0
        db "GUNSHIP 500",0
        db 11,20
        dw SPR_ROCK
        db "ROCK    300",0
        db 14,21
        dw SPR_TUR0
        db "TURRET 300",0
        db 16,19
        dw SPR_HEAVY
        db "CRUISER 2000",0
        db 20,3
        dw SPR_PLAYER
        db "THE NOVA - YOU",0
        db 0FFh

; IY = sprite, B = row, C = column: into BG
bg_sprite:
        ld a,(iy+0)
        inc iy
.l:     push af
        push bc
        ld a,(iy+0)
        add a,c
        ld c,a
        ld a,(iy+1)
        add a,b
        ld b,a
        call calc_ofs
        ld d,(iy+2)
        ld e,(iy+3)
        call bg_put
        ld de,4
        add iy,de
        pop bc
        pop af
        dec a
        jr nz,.l
        ret

; ---------------------------------------------------------------------
draw_items:
        ld hl,txt_items_h
        ld b,1
        ld c,60h
        call print_centre
        ld hl,itemlist
        ld b,4
.i:     ld a,(hl)
        cp 0FFh
        jr z,.t
        push bc
        dec a                   ; capsule glyph
        add a,a
        push hl
        ld hl,captab
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld d,(hl)
        inc hl
        ld e,(hl)
        pop hl
        inc hl
        ld c,3
        push hl
        call calc_ofs
        call bg_put
        pop hl
        pop bc
        push bc
        ld c,6
        ld a,70h
        call print_at
        pop bc
        inc b
        inc b
        jr .i
.t:     ld hl,itemtext
        jp print_list

txt_items_h: db "POWER-UPS",0
itemlist:
        db IK_P,"POWER UP YOUR GUN",0
        db IK_V,"VULCAN: A WIDE SPREAD",0
        db IK_L,"LASER: BEAMS GO THROUGH",0
        db IK_O,"OPTION: A DRONE (2 MAX)",0
        db IK_S,"SPEED UP",0
        db IK_B,"ONE MORE SMART BOMB",0
        db IK_H,"SHIELD: TAKES ONE HIT",0
        db IK_MED,"MEDAL: 100 UP TO 10000",0
        db 0FFh
itemtext:
        db 20,2,50h,"GUNSHIPS CARRY THE CAPSULES.",0
        db 21,2,50h,"SHOOT A WHOLE FORMATION FOR",0
        db 22,2,50h,"A BONUS AND A MEDAL.",0
        db 0FFh

; ---------------------------------------------------------------------
; high scores: 8 x (score 3 BCD, initials 3, stage, -)
init_hiscores:
        ld hl,hidefault
        ld de,HISC
        ld bc,64
        ldir
        ld hl,HISC
        ld de,hiscore
        ld bc,3
        ldir
        ret

hidefault:
        db 00h,50h,00h,"BPM",5,0
        db 00h,40h,00h,"NOV",4,0
        db 00h,30h,00h,"STR",4,0
        db 00h,25h,00h,"ACE",3,0
        db 00h,20h,00h,"ZAP",3,0
        db 00h,15h,00h,"MZ7",2,0
        db 00h,10h,00h,"SHP",1,0
        db 00h,05h,00h,"CPU",1,0

draw_scores:
        ld hl,txt_high_h
        ld b,2
        ld c,60h
        call print_centre
        ld hl,txt_high_c
        ld b,4
        ld c,50h
        call print_centre
        ld ix,HISC
        ld b,6
        ld c,0
.r:     push bc
        ld a,c                  ; rank
        inc a
        ld (rankbuf),a
        push bc
        ld c,8
        call calc_ofs
        ex de,hl
        pop bc
        ld a,(hinew)            ; the newest entry flashes yellow
        cp c
        ld c,70h
        jr nz,.cc
        ld c,60h
.cc:    ld a,(rankbuf)
        call print_dec2
        inc de
        inc de
        inc de
        push ix
        pop hl
        call print_score
        inc de
        inc de
        inc de
        ld a,(ix+3)
        call .ch
        ld a,(ix+4)
        call .ch
        ld a,(ix+5)
        call .ch
        inc de
        inc de
        inc de
        ld a,(ix+6)
        call print_dec2
        ld de,8
        add ix,de
        pop bc
        inc b
        inc b
        inc c
        ld a,c
        cp 8
        jr c,.r
        ret
.ch:    push de
        push bc
        call asc2dc
        ex de,hl
        ld d,a
        ld e,c
        call bg_put
        pop bc
        pop de
        inc de
        ret
txt_high_h: db "NOVA ACES",0
txt_high_c: db "RANK   SCORE   NAME  STAGE",0

; after a game: a place in the table? -> asks for initials
check_hiscore:
        ld a,0FFh
        ld (hinew),a
        ld a,(trainer)
        or a
        ret nz
        ld ix,HISC
        ld c,0
.f:     ld a,(score+2)          ; score > entry?
        cp (ix+2)
        jr c,.n
        jr nz,.ins
        ld a,(score+1)
        cp (ix+1)
        jr c,.n
        jr nz,.ins
        ld a,(score)
        cp (ix+0)
        jr c,.n
        jr z,.n
        jr .ins
.n:     ld de,8
        add ix,de
        inc c
        ld a,c
        cp 8
        jr c,.f
        ret
.ins:   ld a,c
        ld (hinew),a
        ; move the lower entries down
        ld a,7
        sub c
        jr z,.put
        ld b,a
        ld hl,HISC+55           ; last byte of entry 6
        ld de,HISC+63
.mv:    push bc
        ld bc,8
        lddr
        pop bc
        djnz .mv
.put:   ld hl,score
        push ix
        pop de
        ld bc,3
        ldir
        ld (ix+3),'.'
        ld (ix+4),'.'
        ld (ix+5),'.'
        ld a,(stage)
        ld (ix+6),a
        jp enter_name

; IX = entry: type the initials
enter_name:
        ld (nameptr),ix
        ld a,40
        ld (starw),a
        call clear_objects
        ld a,70h
        call clear_bg
        ld hl,txt_ename1
        ld b,4
        ld c,60h
        call print_centre
        ld hl,txt_ename2
        ld b,7
        ld c,70h
        call print_centre
        ld hl,txt_ename3
        ld b,20
        ld c,50h
        call print_centre
        call stars_draw
        call refresh_all
        ld hl,TRK_TITLE
        call play_tune
        xor a
        ld (nidx),a
.l:     call wait_tick
        call flush
        call read_keys
        call restore
        call stars_tick
        ld ix,(nameptr)
        ld hl,framecnt
        inc (hl)
        ; show the three letters, the current one blinking
        ld b,0
.s:     push bc
        ld a,b
        add a,3
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de
        ld a,(hl)
        call asc2dc
        ld d,a
        ld a,(nidx)
        cp b
        ld e,70h
        jr nz,.sc
        ld a,(framecnt)
        and 4
        ld e,60h
        jr z,.sc
        ld e,20h
.sc:    ld a,b
        add a,a
        add a,18
        ld c,a
        ld b,12
        xor a
        call put_one40
        pop bc
        inc b
        ld a,b
        cp 3
        jr c,.s
        call get_letter
        or a
        jr z,.k
        cp 8
        jr z,.del
        ld e,a
        ld a,(nidx)
        cp 3
        jr nc,.l
        push af
        add a,3
        ld c,a
        ld b,0
        ld hl,(nameptr)
        add hl,bc
        ld (hl),e
        pop af
        inc a
        ld (nidx),a
        ld hl,SFX_SELECT
        ld a,3
        call sfx
        jr .l
.del:   ld a,(nidx)
        or a
        jr z,.l
        dec a
        ld (nidx),a
        add a,3
        ld c,a
        ld b,0
        ld hl,(nameptr)
        add hl,bc
        ld (hl),'.'
        jp .l
.k:     ld a,(sedge)
        and KS_CR
        jp z,.l
        ld a,(nidx)
        or a
        jp z,.l
        ret
txt_ename1: db "A NEW NOVA ACE!",0
txt_ename2: db "TYPE YOUR INITIALS",0
txt_ename3: db "RETURN WHEN DONE",0

; put_one for the whole 40-column screen (B row, C column, D, E)
put_one40:
        call calc_ofs
        jp put_cell

; the joystick setting on the title
joy_show:
        ld a,(page)
        or a
        ret nz
        ld hl,txt_joyoff
        ld a,(joyon)
        or a
        jr z,.s
        ld hl,txt_joyon
.s:     ld b,21
        ld c,30
        ld a,60h
        jp print_at
txt_joyoff: db "OFF",0
txt_joyon:  db "ON ",0

; ---------------------------------------------------------------------
; J: joystick on / off
toggle_joy:
        ld a,(joyon)
        xor 1
        ld (joyon),a
        xor a
        ld (joyfire),a
        ld (joymv),a
        ld (joycal),a           ; centre it at the next reading
        call joy_show
        ld hl,SFX_SELECT
        ld a,3
        jp sfx
