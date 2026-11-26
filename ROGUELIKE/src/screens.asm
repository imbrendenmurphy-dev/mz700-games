; =====================================================================
;  screens.asm - title, story, bestiary, records, the descent, death and
;  victory
;
;  Every front-end page animates while it waits, so the tracker keeps
;  playing and the torchlight effects stay alive.  A page returns NZ when
;  SPACE / fire starts a game, Z when it timed out (or another key).
; =====================================================================

; ---------------------------------------------------------------------
; the title: LUMEN in big blocks, a lantern's light sweeping over it
LOGO_X          equ (40-LOGO_W)/2
LOGO_Y          equ 1

title_screen:
        ld a,(trk_on)
        or a
        jr nz,.playing
        ld hl,TRK_TITLE
        call trk_play
.playing:
        xor a
        call cls
        ; the logo's glyphs (black until the sweep colours them)
        ld hl,LOGO
        ld de,VRAM+LOGO_Y*40+LOGO_X
        ld a,LOGO_H
        ld (lg_rows),a
.r:     ld b,LOGO_W
.c:     ld a,(hl)
        inc hl
        and 0Fh
        push hl
        ld hl,LOGO_GLYPHS
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ld (de),a
        inc de
        djnz .c
        push hl
        ld hl,40-LOGO_W
        add hl,de
        ex de,hl
        pop hl
        ld a,(lg_rows)
        dec a
        ld (lg_rows),a
        jr nz,.r
        ld c,12
        ld a,YELLOW*16
        ld hl,s_sub1
        call print_centre
        ld c,14
        ld a,WHITE*16
        ld hl,s_sub2
        call print_centre
        ld c,16
        ld a,CYAN*16
        ld hl,s_keys1
        call print_centre
        ld c,17
        ld a,CYAN*16
        ld hl,s_keys2
        call print_centre
        ld c,18
        ld a,CYAN*16
        ld hl,s_keys3
        call print_centre
        ld c,21
        ld a,GREEN*16
        ld hl,s_start
        call print_centre
        ld c,23
        ld a,BLUE*16
        ld hl,s_credit
        call print_centre
        ld hl,500
        jp page_wait_sweep

; two seconds that keys cannot skip (after a death or the victory)
page_hold:
        ld b,50
.w:     push bc
        call wait_field
        call wait_field
        call fe_embers
        pop bc
        djnz .w
        jp kb_clear

; wait up to HL fields, sweeping the logo; NZ on SPACE
page_wait_sweep:
        ld a,1
        ld (sweep_on),a
        jr page_wait_go
; wait up to HL fields; NZ on SPACE
page_wait:
        xor a
        ld (sweep_on),a
page_wait_go:
        ld (pw_left),hl
        call wait_release
.w:     call wait_field
        call wait_field
        ld a,(sweep_on)
        or a
        call nz,logo_sweep
        call fe_embers
        call scan_keys
        ld a,KC_SPACE
        call key_hit
        jr nz,.start
        call anyhit
        jr nz,.skip
        ld hl,(pw_left)
        dec hl
        dec hl
        ld (pw_left),hl
        bit 7,h
        jr z,.w
.skip:  xor a
        ret
.start: or 1
        ret

; the glow logo, each frame: a diagonal shine sweeps over the letters
; (|sweep - x - y| <= 3 brightens, <= 1 brightest); the inner aura is a
; blue dither; in the outer aura single dots twinkle where
; (x + y + phase) mod 3 = 0.  A cell byte: glyph index (bits 0-3),
; class (4-6: 1-3 letter bands, 4 inner aura, 5 outer dots), bit 7 red
; ground behind a letter's partial cell.
logo_sweep:
        ld hl,sweep_pos
        inc (hl)
        ld a,(hl)
        cp 110
        jr c,.p
        ld (hl),0
        xor a
.p:     srl a
        sub 8
        ld (sw_x),a                 ; -8 .. 46
        ld a,(sweep_pos)            ; the twinkle phase, every 8 frames
        rrca
        rrca
        rrca
        and 1Fh
.m3:    sub 3
        jr nc,.m3
        add a,3
        ld (lg_ph),a
        ld hl,LOGO
        ld de,ARAM+LOGO_Y*40+LOGO_X
        ld c,0
.r:     ld a,(lg_ph)                ; (x + y + phase) mod 3 at x = 0
        add a,c
.m4:    sub 3
        jr nc,.m4
        add a,3
        ld (lg_m),a
        ld b,0
.c:     ld a,(hl)
        and 70h
        jr z,.n
        cp 40h
        jr c,.letter
        jr z,.aura
        ; outer aura: a twinkling dot
        ld a,(lg_m)
        or a
        ld a,0F1h
        jr z,$+3
        xor a
        res 3,d
        ld (de),a
        set 3,d
.aura:  ld a,BLUE*16
        ld (de),a
        jr .n
.letter:
        push hl
        rrca
        rrca
        rrca
        rrca
        ld l,a                      ; band 1-3
        ld a,(sw_x)
        sub b
        sub c
        bit 7,a
        jr z,$+4
        neg
        ld h,0
        cp 4
        jr nc,.g
        inc h
        cp 2
        jr nc,.g
        inc h
.g:     ld a,l
        add a,a
        add a,l
        add a,h
        ld hl,lg_bands-3
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        bit 7,(hl)
        jr z,$+4
        or RED
        ld (de),a
.n:     inc hl
        inc de
        ld a,(lg_m)                 ; the mod-3 count moves on with x
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (lg_m),a
        inc b
        ld a,b
        cp LOGO_W
        jr c,.c
        ex de,hl
        push bc
        ld bc,40-LOGO_W
        add hl,bc
        pop bc
        ex de,hl
        inc c
        ld a,c
        cp LOGO_H
        jp c,.r
        ret
lg_bands:
        db WHITE*16, WHITE*16, WHITE*16
        db YELLOW*16, WHITE*16, WHITE*16
        db RED*16, YELLOW*16, WHITE*16

; embers drifting up the front-end screens (on black cells only)
fe_embers:
        ld hl,fe_emb
        ld b,6
.l:     push bc
        push hl
        ld a,(hl)                   ; row (0 = free)
        or a
        jr nz,.move
        call rand
        and 7
        jr nz,.n
        ld a,24
        pop hl
        push hl
        ld (hl),a
        inc hl
        ld b,40
        call rand_below
        ld (hl),a
        jr .n
.move:  ; erase, move up, draw
        pop hl
        push hl
        call .cell
        ld a,(de)
        cp 0F1h
        jr nz,.ne
        xor a
        ld (de),a
.ne:    pop hl
        push hl
        dec (hl)
        ld a,(hl)
        cp 1
        jr nc,.dr
        ld (hl),0
        jr .n
.dr:    call rand
        and 3
        jr nz,.dd
        inc hl
        call rand
        and 1
        jr z,.lf
        ld a,(hl)
        cp 39
        jr nc,.dd0
        inc (hl)
        jr .dd0
.lf:    ld a,(hl)
        or a
        jr z,.dd0
        dec (hl)
.dd0:   dec hl
.dd:    call .cell
        ld a,(de)
        or a
        jr nz,.n
        ld a,0F1h
        ld (de),a
        set 3,d
        ld a,(hl)
        ld a,c
        ld (de),a
.n:     pop hl
        inc hl
        inc hl
        pop bc
        djnz .l
        ret
; DE = VRAM of ember HL (row, col); C = its colour
.cell:  ld a,(hl)
        push hl
        inc hl
        ld b,(hl)
        ld c,a
        call vaddr
        pop hl
        ld a,(hl)
        ld c,YELLOW<<4
        cp 16
        ret nc
        ld c,RED<<4
        cp 8
        ret nc
        ld c,MAGENTA<<4
        ret

; ---------------------------------------------------------------------
story_page:
        xor a
        call cls
        ld hl,t_story
        ld c,2
        call text_page
        ld hl,600
        jp page_wait

; a block of centred lines from row C (colour codes 1-7 inside)
text_page:
.l:     ld a,(hl)
        or a
        ret z
        push bc
        ld a,WHITE*16
        push hl
        call print_centre
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        pop bc
        inc c
        jr .l

; the creatures of the deep, with their names, in three columns
bestiary_page:
        xor a
        call cls
        ld c,1
        ld a,YELLOW*16
        ld hl,s_bestiary
        call print_centre
        ld a,1                      ; type
        ld bc,1*256+3               ; column x, row
.l:     push af
        push bc
        call mon_type
        call vaddr
        ld a,(iy+MT_G)
        ld c,(iy+MT_A)
        call putc
        inc de
        inc de
        ld l,(iy+MT_NAME)
        ld h,(iy+MT_NAME+1)
        ld c,WHITE*16
        call print
        pop bc
        pop af
        inc c
        ld e,a
        ld a,c
        cp 14
        ld a,e
        jr c,.n
        ld c,3
        ld e,a
        ld a,b
        add a,13
        ld b,a
        ld a,e
.n:     inc a
        cp M_HERMIT
        jr c,.l
        ld c,22
        ld a,CYAN*16
        ld hl,s_best2
        call print_centre
        ld hl,600
        jp page_wait

; ---------------------------------------------------------------------
; records: 5 of score (2), level, zones (bit count), name (3)
NREC            equ 5
RECSZ           equ 7

records_init:
        ld hl,rec_default
        ld de,records
        ld bc,NREC*RECSZ
        ldir
        ret

records_page:
        xor a
        call cls
        ld c,2
        ld a,YELLOW*16
        ld hl,s_records
        call print_centre
        ld bc,10*256+5
        ld a,CYAN*16
        ld hl,s_rechead
        call print_at
        ld ix,records
        ld c,7
        ld b,NREC
.l:     push bc
        ld b,10
        call vaddr
        ld a,(ix+4)
        call putc_ascii
        ld a,(ix+5)
        call putc_ascii
        ld a,(ix+6)
        call putc_ascii
        ; score
        inc de
        inc de
        inc de
        inc de
        ld l,(ix+0)
        ld h,(ix+1)
        ld b,5
        ld c,WHITE*16
        call print_num
        inc de
        inc de
        inc de
        ld l,(ix+2)
        ld h,0
        ld b,2
        ld c,GREEN*16
        call print_num
        inc de
        inc de
        inc de
        inc de
        ld l,(ix+3)
        ld h,0
        ld b,1
        ld c,MAGENTA*16
        call print_num
        ld de,RECSZ
        add ix,de
        pop bc
        inc c
        inc c
        djnz .l
        ld c,21
        ld a,GREEN*16
        ld hl,s_start
        call print_centre
        ld hl,500
        jp page_wait

; one ASCII letter at DE (yellow)
putc_ascii:
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,YELLOW*16
        call putc
        inc de
        ret

rec_default:
        dw 900
        db 4,5,"S","K","Y"
        dw 600
        db 3,4,"E","M","B"
        dw 400
        db 3,3,"A","S","H"
        dw 250
        db 2,2,"W","I","C"
        dw 100
        db 1,1,"D","U","N"

; ---------------------------------------------------------------------
descend_screen:
        ld a,(demo)
        or a
        ret nz
        xor a
        call cls
        ld hl,t_descend
        ld c,8
        call text_page
        ld hl,SFX_STAIRS
        ld a,2
        call sfx
        ld hl,150
        call page_wait
        ret

; the score: gold + 5 per kill + xp + 40 per zone seen + 2000 for the win
calc_score:
        ld hl,(gold)
        ld de,(kills)
        ld b,5
.k:     add hl,de
        djnz .k
        ld de,(xp)
        add hl,de
        ld a,(zvisit)
        ld b,8
        ld de,40
.z:     rrca
        jr nc,.zn
        add hl,de
.zn:    djnz .z
        ld a,(won)
        or a
        jr z,.x
        ld de,2000
        add hl,de
.x:     ld (score),hl
        ret

death:
        call calc_score
        ld a,(demo)
        or a
        ret nz
        ; the torch goes out: a few frames of darkness falling
        ld b,7
.d:     push bc
        ld a,b
        ld (torch),a
        call wait_frame
        call mark_all
        call render_frame
        ld a,6
        call wait_fields
        pop bc
        djnz .d
        ld hl,TRK_OVER
        call trk_play
        xor a
        call cls
        ld hl,t_death
        ld c,5
        call text_page
        call stats_lines
        call page_hold
        ld hl,600
        call page_wait
        jp enter_record

victory:
        call calc_score
        ld a,(demo)
        or a
        ret nz
        ld hl,TRK_WIN
        call trk_play
        xor a
        call cls
        ld hl,t_victory
        ld c,3
        call text_page
        call stats_lines
        call page_hold
        ld hl,900
        call page_wait
        jp enter_record

; score, level, kills, turns on rows 16-19
stats_lines:
        ld bc,12*256+16
        ld a,CYAN*16
        ld hl,s_score
        call print_at
        ld hl,(score)
        ld b,5
        ld c,WHITE*16
        call print_num
        ld bc,12*256+17
        ld a,CYAN*16
        ld hl,s_level
        call print_at
        ld a,(plevel)
        ld l,a
        ld h,0
        ld b,5
        ld c,WHITE*16
        call print_num
        ld bc,12*256+18
        ld a,CYAN*16
        ld hl,s_kills
        call print_at
        ld hl,(kills)
        ld b,5
        ld c,WHITE*16
        call print_num
        ld bc,12*256+19
        ld a,CYAN*16
        ld hl,s_turns
        call print_at
        ld hl,(turns)
        ld b,5
        ld c,WHITE*16
        jp print_num

; a new record?  ask for three letters
enter_record:
        ld ix,records+(NREC-1)*RECSZ
        ld hl,(score)
        ld e,(ix+0)
        ld d,(ix+1)
        or a
        sbc hl,de
        ret c
        ret z
        ; find the place: shift lower ones down
        ld ix,records
        ld b,NREC
.f:     ld hl,(score)
        ld e,(ix+0)
        ld d,(ix+1)
        or a
        sbc hl,de
        jr nc,.here
        ld de,RECSZ
        add ix,de
        djnz .f
        ret
.here:  ; move entries from IX down by one (the last one drops)
        push ix
        pop hl
        ld de,records+NREC*RECSZ
        ex de,hl
        or a
        sbc hl,de                   ; bytes from IX to the end
        ld bc,RECSZ
        or a
        sbc hl,bc
        jr z,.ins
        jr c,.ins
        ld b,h
        ld c,l
        ld hl,records+(NREC-1)*RECSZ-1
        ld de,records+NREC*RECSZ-1
        lddr
.ins:   ld hl,(score)
        ld (ix+0),l
        ld (ix+1),h
        ld a,(plevel)
        ld (ix+2),a
        ld a,(zvisit)
        ld b,8
        ld c,0
.zc:    rrca
        jr nc,$+3
        inc c
        djnz .zc
        ld (ix+3),c
        ; the name
        xor a
        call cls
        ld c,8
        ld a,YELLOW*16
        ld hl,s_newrec
        call print_centre
        ld c,10
        ld a,WHITE*16
        ld hl,s_typename
        call print_centre
        ld a,'A'
        ld (ix+4),a
        ld (ix+5),a
        ld (ix+6),a
        ld b,0                      ; letter index
.nl:    push bc
        ; draw the three letters
        ld de,VRAM+13*40+18
        ld b,3
        push ix
.dl:    ld a,(ix+4)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,WHITE*16
        call putc
        inc de
        inc ix
        djnz .dl
        pop ix
        pop bc
        push bc
        ; the cursor under the current letter
        ld de,VRAM+14*40+17
        ld b,5
        xor a
        ld c,0
        call fill_cells
        pop bc
        push bc
        ld a,b
        ld de,VRAM+14*40+18
        add a,e
        ld e,a
        ld a,050h                   ; ^
        ld c,GREEN*16
        call putc
        pop bc
        ; keys
        push bc
.k:     call wait_field
        call scan_keys
        call getletter
        jr nz,.letter
        ld a,KC_CR
        call key_hit
        jr nz,.done
        jr .k
.letter:
        call kb_clear
        pop bc
        push bc
        push ix
        ld e,b
        ld d,0
        add ix,de
        ld (ix+4),a
        pop ix
        pop bc
        inc b
        ld a,b
        cp 3
        jr c,.nl
        ret
.done:  pop bc
        ret

; A = ASCII of a letter key that went down, NZ; else Z
getletter:
        ld c,0                      ; key code
.l:     ld a,c
        call key_hit
        jr z,.n
        ld a,c
        ld hl,letter_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        or a
        jr z,.n
        ret
.n:     inc c
        ld a,c
        cp 5*8
        jr c,.l
        xor a
        ret
letter_tab:
        db 0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,"Z","Y"
        db "XWVUTSRQ"
        db "PONMLKJI"
        db "HGFEDCBA"
