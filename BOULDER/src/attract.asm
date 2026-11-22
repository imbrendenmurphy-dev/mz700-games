; =====================================================================
;  attract.asm - the story, the second guide page, the seven wings and
;  the ending (pictures from tools/pictures.py, packed by build.py)
; =====================================================================

; draw_pic: HL = runs of (count, char, attr), ended by a 0 count
draw_pic:
        ld de,VRAM
.r:     ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld l,a
.c:     ld a,c
        ld (de),a
        set 3,d
        ld a,l
        ld (de),a
        res 3,d
        inc de
        djnz .c
        pop hl
        jr .r

; set_fg_n: HL = table (db n, dw screen offsets), A = index (taken mod n),
; C = foreground << 4: recolour that cell, keeping its bank and background
set_fg_n:
        ld b,(hl)
        inc hl
.m:     cp b
        jr c,.ok
        sub b
        jr .m
.ok:    add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,ARAM
        add hl,de
        ld a,(hl)
        and 8Fh
        or c
        ld (hl),a
        ret

; set_fg_all: HL = table, C = foreground << 4: recolour every cell in it
set_fg_all:
        ld b,(hl)
        inc hl
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,ARAM
        add hl,de
        ld a,(hl)
        and 8Fh
        or c
        ld (hl),a
        pop hl
        djnz .l
        ret

; glint: every 8 fields, recolour the cells of table HL through a
; cycle of four colours (DE = the cycle)
glint:
        ld a,(pic_t)
        ld b,a
        and 7
        ret nz
        ld a,b
        rrca
        rrca
        rrca
        and 3
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld a,(de)
        ld c,a
        jp set_fg_all

; ---------------------------------------------------------------------
; a walker: steps along a table of screen offsets (db n, dw ...), saving
; and restoring the cell under it, then rests a moment and starts again
; ---------------------------------------------------------------------
walk_init:                          ; HL = table, A = glyph, C = attr
        ld (wk_tab),hl
        ld (wk_glyph),a
        ld a,c
        ld (wk_attr),a
        xor a
        ld (wk_i),a
        ld h,a
        ld l,a
        ld (wk_prev),hl
        ret

walk_step:
        ld hl,(wk_prev)             ; put back what was under the walker
        ld a,h
        or a
        jr z,.nr
        ld a,(wk_sch)
        ld (hl),a
        set 3,h
        ld a,(wk_sat)
        ld (hl),a
        ld hl,0
        ld (wk_prev),hl
.nr:    ld hl,(wk_tab)
        ld b,(hl)
        inc hl
        ld a,(wk_i)
        inc a
        ld (wk_i),a
        dec a
        cp b
        jr c,.go
        sub b
        cp 12                       ; out of sight a moment, then again
        ret c
        xor a
        ld (wk_i),a
        ret
.go:    add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,VRAM
        add hl,de
        ld (wk_prev),hl
        ld a,(hl)
        ld (wk_sch),a
        ld a,(wk_glyph)
        ld (hl),a
        set 3,h
        ld a,(hl)
        ld (wk_sat),a
        ld a,(wk_attr)
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; typewriter: lines of text (0 ends a line, 0FFh the lot), centred, one
; character every other field from row (tw_row) down
; ---------------------------------------------------------------------
tw_start:                           ; HL = text, A = first row
        ld (tw_ptr),hl
        ld (tw_row),a
tw_line:
        ld hl,(tw_ptr)
        ld a,(hl)
        cp 0FFh
        ret z
        ld b,0
.n:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        inc b
        jr .n
.e:     ld a,40
        sub b
        srl a
        ld b,a
        ld a,(tw_row)
        ld c,a
        call vaddr
        ld (tw_de),de
        ret

typewriter:
        ld a,(pic_t)
        and 1
        ret nz
        ld hl,(tw_ptr)
        ld a,(hl)
        cp 0FFh
        ret z
        inc hl
        ld (tw_ptr),hl
        or a
        jr nz,.ch
        ld a,(tw_row)               ; next line
        inc a
        ld (tw_row),a
        jr tw_line
.ch:    ld l,a
        ld h,high ATOD
        ld a,(hl)
        ld de,(tw_de)
        ld c,WHITE*16
        call putc
        inc de
        ld (tw_de),de
        ret

; ---------------------------------------------------------------------
; the story: the mountain by night, a hymn, the legend typed out
; ---------------------------------------------------------------------
story_page:
        ld hl,PIC_STORY
        call draw_pic
        ld hl,SONG_HYMN
        call mus_play
        xor a
        ld (pic_t),a
        ld hl,txt_story
        ld a,20
        call tw_start
        ld hl,ST_WALK
        ld a,43h                    ; the miner, facing left (second bank)
        ld c,YELLOW*16+80h
        call walk_init
        ld hl,story_fx
        ld (page_fx),hl
        ld a,40
        call page_wait
        push af
        ld hl,SONG_TITLE
        call mus_play
        pop af
        ret

story_fx:
        ld hl,pic_t
        inc (hl)
        ld a,(hl)
        and 3                       ; a star changes colour every 4 fields
        jr nz,.ng
        call rand
        and 70h
        jr nz,$+4
        ld a,BLUE*16
        ld c,a
        ld a,(pic_t)
        rrca
        rrca
        ld hl,ST_STARS
        call set_fg_n
.ng:    ld hl,ST_GEMS
        ld de,glint_gem
        call glint
        ld a,(pic_t)                ; the lanterns flicker
        and 3
        jr nz,.nl
        call rand
        and 40h
        or RED*16
        ld c,a
        ld hl,ST_LAMPS
        call set_fg_all
.nl:    ld a,(pic_t)
        and 7
        call z,walk_step
        jp typewriter

glint_gem:      db CYAN*16, WHITE*16, CYAN*16, MAGENTA*16

; ---------------------------------------------------------------------
; the seven wings: a sample of each wing's stone, with its name
; ---------------------------------------------------------------------
WS_ROW          equ 3

wings_page:
        ld a,BLACK
        call cls
        ld b,0
        ld c,1
        ld a,WHITE*16+BLUE
        call clear_rows
        ld hl,txt_wings
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        xor a
.w:     push af
        add a,a
        add a,WS_ROW
        ld c,a
        ld b,11
        pop af
        push af
        add a,a
        ld e,a
        ld d,0
        ld hl,wing_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop af
        push af
        cp 7
        ld a,YELLOW*16
        jr c,$+4
        ld a,CYAN*16
        call print_at
        pop af
        inc a
        cp 8
        jr c,.w
        ld hl,txt_wings_ft
        ld c,22
        ld a,GREEN*16
        call print_centre
        xor a
        ld (pic_t),a
        call wings_fx
        ld hl,wings_fx
        ld (page_fx),hl
        ld a,24
        jp page_wait

; draw every wing's sample strip at the current phase
wings_fx:
        ld hl,pic_t
        inc (hl)
        ld a,(hl)
        and 3
        ret nz
        xor a
.t:     push af
        add a,a
        add a,WS_ROW
        ld c,a
        ld b,2
        call vaddr                  ; DE = the strip
        pop af
        push af
        add a,a
        ld l,a
        ld h,0
        ld bc,THEMETAB
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                      ; HL = the theme's ANIMIDX image
        ld a,(pic_t)
        rrca
        rrca
        rrca
        and 3
        rrca
        rrca
        ld c,a                      ; C = phase << 6
        ld b,8
        push hl
        ld hl,wing_strip
.e:     ld a,(hl)
        inc hl
        ex (sp),hl
        push hl
        or c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)                   ; display index
        ld l,a
        ld h,high DISP_CH
        ld a,(hl)
        ld (de),a
        inc h
        ld a,(hl)
        set 3,d
        ld (de),a
        res 3,d
        inc de
        pop hl
        ex (sp),hl
        djnz .e
        pop hl
        pop af
        inc a
        cp 8
        jr c,.t
        ret

wing_strip:     db E_STEEL, E_DIRT, E_BOULDER, E_DIRT, E_DIAMOND, E_BRICK, E_BRICK, E_STEEL

; ---------------------------------------------------------------------
; the second guide page: what waits in the deeper wings
; ---------------------------------------------------------------------
guide2_tab:
        db E_GEODE
        dw gt_geode, gd_geode
        db E_SLIME
        dw gt_slime, gd_slime
        db E_KEY
        dw gt_key, gd_key
        db E_LOCK
        dw gt_lock, gd_lock
        db E_SHADE
        dw gt_shade, gd_shade
        db 0FFh

; ---------------------------------------------------------------------
; the ending: out of the mountain at daybreak
; ---------------------------------------------------------------------
ending:
        ld hl,PIC_DAYBREAK
        call draw_pic
        ld hl,SONG_DAYBREAK
        call mus_play
        xor a
        ld (pic_t),a
        ld hl,txt_ending
        ld a,19
        call tw_start
        ld hl,DB_WALK
        ld a,45h                    ; the miner, facing right
        ld c,YELLOW*16+80h
        call walk_init
        ld hl,ending_fx
        ld (page_fx),hl
        ld a,60
        call page_wait
        jp mus_stop

ending_fx:
        ld hl,pic_t
        inc (hl)
        ld a,(hl)
        and 3
        jr nz,.nr
        call rand
        and 40h
        or YELLOW*16 & 0BFh
        ld c,a
        ld a,(pic_t)
        rrca
        rrca
        ld hl,DB_RAYS
        call set_fg_n
.nr:    ld hl,DB_GEMS
        ld de,glint_gem
        call glint
        ld a,(pic_t)
        and 7
        call z,walk_step
        jp typewriter
