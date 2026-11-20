; =====================================================================
;  screens.asm - title, cave guide, high scores, name entry
; =====================================================================

LOGO_ROW        equ 1
SCROLL_ROW      equ 24
DIG_ROW         equ 22                  ; the little digger's tunnel

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
        and 7
        rrca
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
        ld a,BLACK
        call cls
        call patch_reset
        ; logo
        ld hl,LOGO
        ld de,VRAM+LOGO_ROW*40
        ld bc,LOGO_H*40
        ldir
        xor a
        ld (logo_phase),a
        call logo_colours
        ld hl,txt_sub
        ld c,9
        ld a,CYAN*16
        call print_centre
        ld hl,txt_press
        ld c,15
        ld a,WHITE*16
        call print_centre
        ld hl,txt_credit
        ld c,19
        ld a,BLUE*16
        call print_centre
        ; best score
        ld hl,txt_best
        ld b,10
        ld c,17
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
        call dig_init
        ld hl,scroll_text
        ld (scroll_ptr),hl
        xor a
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
        and 3
        call z,logo_colours
        call scroller
        call dig_step
        call cave_select_keys
        ; flash "press space"
        ld a,(logo_phase)
        and 16
        ld a,WHITE*16
        jr z,$+4
        ld a,YELLOW*16
        ld de,VRAM+15*40
        ld b,40
        jp fill_attr

; LEFT / RIGHT choose the starting cave: A, E, I or M
cave_select_keys:
        call fe_keys
        ld b,a
        ld a,(start_cave)
        bit B_LEFT,b
        jr z,.nl
        sub 4
        jr nc,.set
        ld a,NCAVES-4
        jr .set
.nl:    bit B_RIGHT,b
        ret z
        add a,4
        cp NCAVES
        jr c,.set
        xor a
.set:   ld (start_cave),a
        ld hl,SFX_CLICK
        ld a,1
        call sfx
        ld a,1                      ; give the player time to choose
        ld (page_restart),a
        jp cave_select_draw

cave_select_draw:
        ld hl,txt_startcave
        ld b,11
        ld c,12
        ld a,GREEN*16
        call print_at
        ld a,51h                    ; '<'
        ld c,WHITE*16
        call putc
        inc de
        inc de
        ld a,(start_cave)
        inc a
        ld c,YELLOW*16+80h          ; bold letter
        call putc
        inc de
        inc de
        ld a,57h                    ; '>'
        ld c,WHITE*16
        jp putc

; logo rows: a fixed gradient with a white glint sweeping down
logo_colours:
        ld a,(logo_phase)
        rrca
        rrca
        and 31
        ld c,a
        ld de,VRAM+LOGO_ROW*40
        ld hl,logo_grad
        ld b,0
.r:     ld a,b
        cp c
        ld a,(hl)
        jr nz,.nc
        ld a,WHITE*16
.nc:    push bc
        push hl
        ld b,40
        call fill_attr
        pop hl
        pop bc
        inc hl
        inc b
        ld a,b
        cp LOGO_H
        jr c,.r
        ret

logo_grad:
        db YELLOW*16,YELLOW*16,YELLOW*16,RED*16,RED*16,MAGENTA*16,MAGENTA*16,BLUE*16

; text scroller on the bottom row
scroller:
        ld hl,scroll_tick
        inc (hl)
        ld a,(hl)
        and 1
        ret nz
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
        ld a,(scroll_tick)
        and 6
        ret nz
        ld de,VRAM+SCROLL_ROW*40
        ld b,40
        ld a,GREEN*16
        jp fill_attr

; ---------------------------------------------------------------------
; the title's little digger: walks along a tunnel of earth, and the
; rocks and gems resting on top drop into the hole behind him
; ---------------------------------------------------------------------
dig_init:
        xor a
        ld (dig_x),a
        ld (dig_t),a
        ; row DIG_ROW-1: gems and rocks, row DIG_ROW: earth, row DIG_ROW+1: steel
        ld hl,DIGBUF
        ld b,40
.a:     push bc
        push hl
        call rand
        pop hl
        pop bc
        and 3
        ld c,E_SPACE
        jr z,.s
        dec a
        ld c,E_BOULDER
        jr z,.s
        dec a
        ld c,E_DIAMOND
        jr z,.s
        ld c,E_SPACE
.s:     ld (hl),c
        inc hl
        djnz .a
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
        ; things fall into the hole behind the digger
        ld hl,DIGBUF
        ld de,DIGBUF+40
        ld b,40
.f:     ld a,(de)
        or a
        jr nz,.nf
        ld a,(hl)
        or a
        jr z,.nf
        ld (de),a
        ld (hl),E_SPACE
.nf:    inc hl
        inc de
        djnz .f
        ; step
        ld a,(dig_x)
        cp 40
        jr c,.walk
        call dig_init               ; off the edge: a new tunnel
        jr dig_draw
.walk:  ld e,a
        ld d,0
        ld hl,DIGBUF+40
        add hl,de
        ld a,(hl)
        cp E_DIRT
        jr z,.dig
        cp E_SPACE
        jr nz,.wait                 ; blocked by something that fell
.dig:   ld (hl),E_PLAYER
        dec hl
        ld a,(dig_x)
        or a
        jr z,.first
        ld (hl),E_SPACE
.first: ld hl,dig_x
        inc (hl)
        jr dig_draw
.wait:  ld (hl),E_SPACE             ; (cannot happen: things only fall behind him)
dig_draw:
        ld a,(dig_x)
        or a
        jr z,.nm
        ld a,1
        ld (pl_moved),a
        ld a,3
        ld (pl_face),a
        call patch_looks_pl
.nm:    ld hl,DIGBUF
        ld de,VRAM+(DIG_ROW-1)*40
        ld b,120
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
        ld b,8
.l:     push bc
        ld a,b
        dec a                       ; phases 7..0
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
        ld a,BLACK
        call cls
        call patch_reset
        ld a,1
        ld (magic_state),a          ; show the magic wall awake
        ld b,0
        ld c,1
        ld a,WHITE*16+BLUE
        call clear_rows
        ld hl,txt_guide
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        ld hl,guide_tab
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
.ctl:   ld hl,guide_ctl
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
        ld hl,guide_tab
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
        inc a
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
        ld hl,SONG_TITLE
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
