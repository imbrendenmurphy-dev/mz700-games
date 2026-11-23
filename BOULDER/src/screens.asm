; =====================================================================
;  screens.asm - title, cave guide, high scores, name entry
; =====================================================================

SCROLL_ROW      equ 24
DIG_ROW         equ 17                  ; the little digger's tunnel, under the title
SEL_ROW         equ 19                  ; start cave, joystick, press space, best, credit

; ---------------------------------------------------------------------
; page helpers
; ---------------------------------------------------------------------
; wait up to A*25 fields (A half-seconds) for FIRE or CR; NZ = pressed.
; Calls (page_fx) every field for animation.
page_wait:
        ld (page_len),a
        ld b,a
        ld c,25
        xor a
        ld (page_restart),a
        call wait_release_fire
.l:     push bc
        call wait_field
        ld hl,anim
        inc (hl)
        ld hl,(page_fx)
        call jp_hl
        call read_keys
        pop bc
        and K_FIRE
        ret nz
        ld a,(key_pause)
        or a
        ret nz                      ; CR also starts
        ld a,(page_restart)         ; something chosen: start the timer again
        or a
        jr z,.n
        xor a
        ld (page_restart),a
        ld a,(page_len)
        ld b,a
        ld c,25
.n:     dec c
        jr nz,.l
        ld c,25
        djnz .l
        xor a
        ret

jp_hl:  jp (hl)

no_fx:  ret

page_wait_nofx:
        ld hl,no_fx
        ld (page_fx),hl
        jp page_wait

wait_release_fire:
.w:     call poll
        call read_keys
        and K_FIRE
        jr nz,.w
        ld a,(key_pause)
        or a
        jr nz,.w
        ret

; draw element A with its animated look at DE (keeps DE)
fe_elem:
        ld c,a
        ld a,(anim)
        rrca
        rrca
        and 3
        rrca
        rrca
        or c
        ld l,a
        ld h,high ANIMIDX
        ld a,(hl)
        ld l,a
        ld h,high DISP_CH
        ld a,(hl)
        ld (de),a
        inc h
        ld a,(hl)
        set 3,d
        ld (de),a
        res 3,d
        ret

; ---------------------------------------------------------------------
; title screen
; ---------------------------------------------------------------------
title_screen:
        ld a,(mus_on)
        or a
        jr nz,.playing
        ld hl,SONG_TITLE
        call mus_play
.playing:
        call patch_reset
        ; the title picture: UNDER against the night sky, MINED dug below
        ld hl,PIC_TITLE
        call draw_pic
        xor a
        ld (logo_phase),a
        ld hl,txt_press
        ld c,SEL_ROW+2
        ld a,WHITE*16
        call print_centre
        ld hl,txt_credit
        ld c,SEL_ROW+4
        ld a,BLUE*16
        call print_centre
        ; best score
        ld hl,txt_best
        ld b,10
        ld c,SEL_ROW+3
        ld a,CYAN*16
        call print_at
        ld hl,HISCORES+5
        ld b,3
        ld c,WHITE*16
        call print_bcd
        inc de
        inc de
        ld hl,HISCORES
        ld b,3
.nm:    ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,YELLOW*16
        call putc
        inc hl
        inc de
        djnz .nm
        call cave_select_draw
        call joy_draw
        call dig_init
        ld hl,(scroll_ptr)          ; the text carries on where it left off last time
        ld a,h
        or a
        jr nz,.sp
        ld hl,scroll_text
        ld (scroll_ptr),hl
.sp:    xor a
        ld (scroll_tick),a
        call fe_reset
        ld hl,title_fx
        ld (page_fx),hl
        ld a,40                     ; 20 seconds
        jp page_wait

title_fx:
        ld hl,logo_phase
        inc (hl)
        ld a,(hl)
        and 3                       ; a star changes colour every 4 fields
        jr nz,.ns
        call rand
        and 70h
        jr nz,$+4
        ld a,BLUE*16
        ld c,a
        ld a,(logo_phase)
        rrca
        rrca
        ld hl,TT_STARS
        call set_fg_n
.ns:
        call scroller
        call dig_step
        call cave_select_keys
        call joy_keys
        ; flash "press space"
        ld a,(logo_phase)
        and 16
        ld a,WHITE*16
        jr z,$+4
        ld a,YELLOW*16
        ld de,VRAM+(SEL_ROW+2)*40
        ld b,40
        jp fill_attr

; LEFT / RIGHT choose the starting wing: cave A, E, I, M, Q, U or X
cave_select_keys:
        call fe_keys
        ld b,a
        ld a,(start_sel)
        bit B_LEFT,b
        jr z,.nl
        sub 1
        jr nc,.set
        ld a,NSTARTS-1
        jr .set
.nl:    bit B_RIGHT,b
        ret z
        inc a
        cp NSTARTS
        jr c,.set
        xor a
.set:   ld (start_sel),a
        ld e,a
        ld d,0
        ld hl,start_caves
        add hl,de
        ld a,(hl)
        ld (start_cave),a
        ld hl,SFX_CLICK
        ld a,1
        call sfx
        ld a,1                      ; give the player time to choose
        ld (page_restart),a
        jp cave_select_draw

; J switches the MZ-1X03 joystick on and off
joy_keys:
        ld a,3                      ; row 3: J is bit 6
        ld (KEYPA),a
        ld a,(KEYPA+1)
        cpl
        and 40h
        ld hl,joy_kprev
        ld b,(hl)
        ld (hl),a
        ret z
        ld a,b
        or a
        ret nz
        ld a,0FFh                   ; no button seen yet
        ld (joy_disp),a
        xor a
        ld (joy_bits),a
        ld a,(joy_on)
        xor 1
        ld (joy_on),a
        ld hl,SFX_CLICK
        ld a,1
        call sfx
        ld a,1
        ld (page_restart),a
joy_draw:
        ld hl,txt_joyoff
        ld a,(joy_on)
        or a
        jr z,$+5
        ld hl,txt_joyon
        ld c,SEL_ROW+1
        ld a,CYAN*16
        jp print_centre

cave_select_draw:
        ld hl,txt_startcave
        ld b,11
        ld c,SEL_ROW
        ld a,GREEN*16
        call print_at
        ld a,51h                    ; '<'
        ld c,WHITE*16
        call putc
        inc de
        inc de
        ld a,(start_cave)
        push hl
        call letter_of
        pop hl
        ld c,YELLOW*16+80h          ; bold letter
        call putc
        inc de
        inc de
        ld a,57h                    ; '>'
        ld c,WHITE*16
        jp putc


; text scroller on the bottom row
scroller:
        ld hl,scroll_tick           ; one character every 5 fields: 10 a second
        dec (hl)
        ret p
        ld (hl),4
        ld hl,VRAM+SCROLL_ROW*40+1
        ld de,VRAM+SCROLL_ROW*40
        ld bc,39
        ldir
        ld hl,(scroll_ptr)
        ld a,(hl)
        or a
        jr nz,.ok
        ld hl,scroll_text
        ld a,(hl)
.ok:    inc hl
        ld (scroll_ptr),hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        ld (VRAM+SCROLL_ROW*40+39),a
        ld de,VRAM+SCROLL_ROW*40
        ld b,40
        ld a,GREEN*16
        jp fill_attr

; ---------------------------------------------------------------------
; the title's little digger: tunnels right under a gallery of gems, which
; drop into the hole behind him (and the rocks in the roof drop onto
; them), then turns and walks back, gathering the gems as the rocks fall
; in behind him.  DIGBUF rows: roof (earth/rock), gallery (gem/space),
; tunnel (earth), steel.  dig_x = his column, 0FFh while off screen.
; ---------------------------------------------------------------------
dig_init:
        ld a,0FFh
        ld (dig_x),a
        xor a
        ld (dig_t),a
        ld (dig_dir),a
        ld hl,DIGBUF
        ld de,DIGBUF+40
        ld b,40
.a:     push bc
        push hl
        push de
        call rand
        pop de
        pop hl
        pop bc
        and 3                       ; 0,3 nothing, 1 a gem, 2 a gem under a rock
        ld (hl),E_DIRT
        ld c,E_SPACE
        jr z,.s
        cp 3
        jr z,.s
        ld c,E_DIAMOND
        cp 2
        jr nz,.s
        ld (hl),E_BOULDER
.s:     ld a,c
        ld (de),a
        inc hl
        inc de
        djnz .a
        ld hl,DIGBUF+80
        ld b,40
.e:     ld (hl),E_DIRT
        inc hl
        djnz .e
        ld b,40
.t:     ld (hl),E_STEEL
        inc hl
        djnz .t
        ret

dig_step:
        ld hl,dig_t
        inc (hl)
        ld a,(hl)
        cp 6
        jr c,dig_draw
        ld (hl),0
        ; rocks and gems drop into the space below them, bottom row first
        ld hl,DIGBUF+40
        call dig_fall
        ld hl,DIGBUF
        call dig_fall
        ; step
        ld a,(dig_dir)
        or a
        ld a,(dig_x)
        jr nz,.back
        inc a
        cp 40
        jr c,.go
        ld a,1                      ; the far end: turn round
        ld (dig_dir),a
        jr dig_draw
.back:  dec a
        cp 0FFh
        jr nz,.go
        call dig_init               ; home again: a new gallery
        jr dig_draw
.go:    ld e,a
        ld d,0
        ld hl,DIGBUF+80
        add hl,de
        ld b,a
        ld a,(hl)
        cp E_BOULDER
        jr z,dig_draw               ; (cannot happen: rocks only fall behind him)
        ld (hl),E_PLAYER            ; earth dug, gem gathered
        ld a,(dig_x)
        cp 0FFh
        jr z,.first
        ld e,a
        ld hl,DIGBUF+80
        add hl,de
        ld (hl),E_SPACE
.first: ld a,b
        ld (dig_x),a
dig_draw:
        ld a,(dig_x)
        cp 0FFh
        jr z,.nm
        ld a,1
        ld (pl_moved),a
        ld a,(dig_dir)
        add a,a
        cpl
        add a,4                     ; face 3 = right, 1 = left
        ld (pl_face),a
        call patch_looks_pl
.nm:    ld hl,DIGBUF
        ld de,VRAM+(DIG_ROW-2)*40
        ld b,160
.d:     push bc
        push hl
        ld a,(hl)
        call fe_elem
        pop hl
        pop bc
        inc hl
        inc de
        djnz .d
        ret

dig_fall:                           ; HL = a row of DIGBUF: drop its rocks and gems one row
        ld d,h
        ld e,l
        ld hl,40
        add hl,de
        ex de,hl                    ; HL = the row, DE = the row below
        ld b,40
.f:     ld a,(hl)
        cp E_BOULDER
        jr z,.r
        cp E_DIAMOND
        jr nz,.n
.r:     ld a,(de)
        or a
        jr nz,.n
        ld a,(hl)
        ld (de),a
        ld (hl),E_SPACE
.n:     inc hl
        inc de
        djnz .f
        ret

; the run-time looks (player, space, magic) for the front end
patch_reset:
        xor a
        ld (flash),a
        ld (magic_state),a
        ld (pl_moved),a
        jp set_theme                ; front-end pages use the first wing's looks

; patch the player look for every phase (front-end animation)
patch_looks_pl:
        ld a,(anim)
        push af
        ld b,4
.l:     push bc
        ld a,b
        dec a                       ; phases 3..0
        add a,a
        ld (anim),a
        call patch_looks
        pop bc
        djnz .l
        pop af
        ld (anim),a
        ret

; ---------------------------------------------------------------------
; cave guide: what lives in the caves, and the controls
; ---------------------------------------------------------------------
guide_page:
        ld hl,guide_tab
        ld de,guide_ctl
        ld bc,txt_guide
        jr guide_any
guide2_page:
        ld hl,guide2_tab
        ld de,guide2_ctl
        ld bc,txt_guide2
guide_any:
        ld (ge_tab),hl
        ld (ge_ctl),de
        ld (ge_title),bc
        ld a,BLACK
        call cls
        call patch_reset
        ld a,1
        ld (magic_state),a          ; show the magic wall awake
        ld b,0
        ld c,1
        ld a,WHITE*16+BLUE
        call clear_rows
        ld hl,(ge_title)
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        ld hl,(ge_tab)
        ld c,2
.e:     ld a,(hl)
        cp 0FFh
        jr z,.ctl
        inc hl
        push bc
        push hl
        ld b,3
        call vaddr
        pop hl
        ld (ge_ptr),hl
        pop bc
        push bc
        ld a,(hl)                   ; name
        inc hl
        ld h,(hl)
        ld l,a
        push de
        inc de
        inc de
        inc de
        ld c,YELLOW*16
        call print
        pop de
        ld hl,(ge_ptr)
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        ld bc,14
        add hl,bc
        ex de,hl
        ld c,CYAN*16
        call print
        ld hl,(ge_ptr)
        ld bc,4
        add hl,bc
        pop bc
        inc c
        inc c
        jr .e
.ctl:   ld hl,(ge_ctl)
        ld c,20
        jr .cl
.cl2:   inc c
.cl:    ld a,(hl)
        cp 0FFh
        jr z,.done
        push bc
        ld b,2
        push hl
        call vaddr
        pop hl
        ld c,WHITE*16
        call print
        pop bc
        inc c
        jr .cl2
.done:  ld hl,guide_fx
        ld (page_fx),hl
        ld a,28
        jp page_wait

; animate the element glyphs
guide_fx:
        call patch_looks_pl
        ld hl,(ge_tab)
        ld c,2
.e:     ld a,(hl)
        cp 0FFh
        ret z
        push hl
        push bc
        ld b,3
        call vaddr
        pop bc
        pop hl
        ld a,(hl)
        push hl
        push bc
        call fe_elem
        pop bc
        pop hl
        ld de,5
        add hl,de
        inc c
        inc c
        jr .e

guide_tab:
        db E_DIAMOND
        dw gt_diamond, gd_diamond
        db E_BOULDER
        dw gt_boulder, gd_boulder
        db E_DIRT
        dw gt_earth, gd_earth
        db E_FIRE0
        dw gt_firefly, gd_firefly
        db E_BUTT0
        dw gt_butterfly, gd_butterfly
        db E_AMOEBA
        dw gt_amoeba, gd_amoeba
        db E_MAGIC
        dw gt_magic, gd_magic
        db E_EXITO
        dw gt_exit, gd_exit
        db E_SHOWER
        dw gt_spout, gd_spout
        db 0FFh

; ---------------------------------------------------------------------
; high scores: name[3], score[3] BCD (lo first), cave, level
; ---------------------------------------------------------------------
hiscore_init:
        ld hl,hiscore_default
        ld de,HISCORES
        ld bc,64
        ldir
        ret

hiscore_page:
        call hiscore_draw
        ld hl,hs_fx
        ld (page_fx),hl
        ld a,16
        jp page_wait

hs_fx:  ld hl,logo_phase
        inc (hl)
        ld a,(hl)
        and 7
        ret nz
        ld a,(hl)
        and 8
        ld a,YELLOW*16
        jr z,$+4
        ld a,WHITE*16
        ld de,VRAM+5*40
        ld b,40
        jp fill_attr

hiscore_draw:
        ld a,BLACK
        call cls
        ld b,0
        ld c,1
        ld a,WHITE*16+BLUE
        call clear_rows
        ld hl,txt_hiscores
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        ld hl,txt_hshead
        ld b,5
        ld c,3
        ld a,CYAN*16
        call print_at
        ; a border of diamonds
        ld de,VRAM+22*40+4
        ld b,32
.dd:    ld a,44h
        ld c,CYAN*16
        call putc
        inc de
        djnz .dd
        xor a
        ld (hs_i),a
.e:     ld a,(hs_i)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,HISCORES
        add hl,de
        ld (hs_ent),hl
        ld a,(hs_i)
        add a,a
        add a,5
        ld c,a
        ld b,5
        call vaddr
        ld a,(hs_i)
        add a,21h
        ld c,WHITE*16
        call putc
        inc de
        ld a,2Eh
        call putc
        inc de
        inc de
        inc de
        ld hl,(hs_ent)
        ld b,3
.n:     ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,YELLOW*16
        call putc
        inc de
        inc hl
        djnz .n
        inc de
        inc de
        inc de
        inc hl
        inc hl                      ; most significant score byte
        ld b,3
        ld c,WHITE*16
        call print_bcd
        ld a,(hs_i)
        add a,a
        add a,5
        ld c,a
        ld b,27
        call vaddr
        ld hl,(hs_ent)
        ld bc,6
        add hl,bc
        ld a,(hl)                   ; cave
        push hl
        call letter_of
        pop hl
        ld c,CYAN*16
        call putc
        inc de
        ld a,2Dh
        call putc
        inc de
        inc hl
        ld a,(hl)                   ; level
        add a,21h
        ld c,WHITE*16
        call putc
        ld a,(hs_i)
        inc a
        ld (hs_i),a
        cp 8
        jp c,.e
        ret

; enter the score in the table if it is good enough
hiscore_entry:
        ld hl,HISCORES+3+2
        ld b,0
.f:     push hl
        ld a,(score+2)
        cp (hl)
        jr nz,.cmp
        dec hl
        ld a,(score+1)
        cp (hl)
        jr nz,.cmp
        dec hl
        ld a,(score)
        cp (hl)
.cmp:   pop hl
        jr z,.next
        jr nc,.found
.next:  ld de,8
        add hl,de
        inc b
        ld a,b
        cp 8
        jr c,.f
        ret                         ; not good enough
.found: ld a,b
        ld (hiscore_rank),a
        ld a,7
        sub b
        jr z,.ins
        ld c,a
        ld b,0
        sla c
        sla c
        sla c
        ld hl,HISCORES+7*8-1
        ld de,HISCORES+8*8-1
        lddr
.ins:   ld a,(hiscore_rank)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,HISCORES
        add hl,de
        ld (hs_ptr),hl
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        inc hl
        ld a,(score)
        ld (hl),a
        inc hl
        ld a,(score+1)
        ld (hl),a
        inc hl
        ld a,(score+2)
        ld (hl),a
        inc hl
        ld a,(cave_no)
        ld (hl),a
        inc hl
        ld a,(level)
        ld (hl),a
        ld hl,SONG_CHEER
        call mus_play
        call hiscore_draw
        ld hl,txt_entername
        ld c,20
        ld a,GREEN*16
        call print_centre
        ld hl,txt_enterhelp
        ld c,21
        ld a,CYAN*16
        call print_centre
        xor a
        ld (hs_pos),a
        call wait_release_fire
        call fe_reset
.loop:  call wait_field
        ld hl,logo_phase
        inc (hl)
        call hs_draw_name
        call fe_keys
        ld b,a
        bit B_UP,b
        jr z,.nu
        call .cur
        ld a,(hl)
        cp ' '
        jr nz,.u1
        ld a,'A'
        jr .su
.u1:    cp 'Z'
        jr nz,.u2
        ld a,' '
        jr .su
.u2:    inc a
.su:    ld (hl),a
        call .click
.nu:    bit B_DOWN,b
        jr z,.nd
        call .cur
        ld a,(hl)
        cp ' '
        jr nz,.d1
        ld a,'Z'
        jr .sd
.d1:    cp 'A'
        jr nz,.d2
        ld a,' '
        jr .sd
.d2:    dec a
.sd:    ld (hl),a
        call .click
.nd:    bit B_FIRE,b
        jp z,.loop
        ld hl,SFX_COLLECT
        ld a,1
        call sfx
        ld hl,hs_pos
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.loop
        call hiscore_draw
        ld hl,txt_welldone
        ld c,20
        ld a,YELLOW*16
        call print_centre
        ld a,6
        call page_wait_nofx
        jp mus_stop
.click: push bc
        ld hl,SFX_CLICK
        ld a,1
        call sfx
        pop bc
        ret
.cur:   ld hl,(hs_ptr)
        ld a,(hs_pos)
        ld e,a
        ld d,0
        add hl,de
        ret

; flash the name being entered
hs_draw_name:
        ld a,(hiscore_rank)
        add a,a
        add a,5
        ld c,a
        ld b,9
        call vaddr
        ld hl,(hs_ptr)
        ld b,0
.l:     ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,(hs_pos)
        cp b
        ld a,YELLOW*16
        jr nz,.c
        ld a,(logo_phase)
        and 8
        ld a,WHITE*16+RED
        jr z,.c
        ld a,RED*16+WHITE
.c:     ld (de),a
        res 3,d
        inc de
        inc hl
        inc b
        ld a,b
        cp 3
        jr c,.l
        ret
