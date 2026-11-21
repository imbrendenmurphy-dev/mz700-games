; ---------------------------------------------------------------------------
; fx_greets.asm - big chunky scroller with a rippling reflection, between
; two layers of parallax stars.
; rows 8-14: letters (5x7 font, one font row per character row)
; rows 15-18: the reflection, half height, in blue, each pixel row shifted
; rows 0-7, 19-24: stars
; big_font: 5 column bytes per character (bit 0 = top row), index = code-32
; greet_text: ASCII codes, 0 = end
; ---------------------------------------------------------------------------

GR_TOP  equ 8
NSTARS  equ 28

greets_init:
        call cls_black
        ; half-block characters in rows 8-18
        ld hl,VCHR+GR_TOP*40
        ld b,11*40/8
.f:     DUP 8
        ld (hl),7Ah
        inc hl
        EDUP
        djnz .f
        ld hl,greet_text
        ld (gr_textp),hl
        xor a
        ld (gr_col),a
        ld (gr_sub),a
        ; stars: row, x (8.8), speed
        ld ix,gr_stars
        ld b,NSTARS
.s:     call rand
        and 15
        cp 14
        jr nc,.s
        cp 8
        jr c,.r
        add a,11                ; rows 19-24
.r:     ld (ix+0),a
.x:     call rand
        cp 160
        jr nc,.x
        ld (ix+2),a             ; x = column*4 + sub-step
        call rand
        and 3
        inc a
        ld (ix+3),a             ; speed 1-4
        ld de,4
        add ix,de
        djnz .s
        ret

greets_frame:
        call wait_vbl
        ld b,GR_TOP
        ld c,11
        call blit_attr_rows
        call gr_stars_move
        ; advance one font column every 2 frames
        ld hl,gr_sub
        inc (hl)
        bit 0,(hl)
        jr z,.noadv
        ld a,(gr_col)
        inc a
        cp 6
        jr c,.c1
        ld hl,(gr_textp)
        inc hl
        ld a,(hl)
        or a
        jr nz,.c0
        ld hl,greet_text
.c0:    ld (gr_textp),hl
        xor a
.c1:    ld (gr_col),a
.noadv: call gr_columns
        call gr_band
        jp gr_reflect

; column bits for the 40 visible columns -> gr_bits
gr_columns:
        ld hl,(gr_textp)
        ld a,(gr_col)
        ld c,a
        ld de,gr_bits
        ld b,40
.l:     ld a,c
        cp 5
        jr nc,.gap
        push hl
        push de
        ld a,(hl)
        sub 32
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *5
        ld e,c
        add hl,de
        ld de,big_font
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        jr .put
.gap:   xor a
.put:   ld (de),a
        inc de
        inc c
        ld a,c
        cp 6
        jr c,.nx
        ld c,0
        inc hl
        ld a,(hl)
        or a
        jr nz,.nx
        ld hl,greet_text
.nx:    djnz .l
        ret

; rows 8-14 of ABUF
gr_band:
        ld a,(mtick)
        rrca
        rrca
        rrca
        and 7
        ld (gr_cphase),a
        ld hl,ABUF+GR_TOP*40
        ld c,1                  ; bit mask for this font row
        ld b,0                  ; row
.row:   ; colour for this row
        push hl
        ld a,(gr_cphase)
        add a,b
        and 7
        ld e,a
        ld d,0
        ld hl,gr_grad
        add hl,de
        ld a,(hl)
        pop hl
        ld e,a                  ; colour * 11h
        ld ix,gr_bits
        push bc
        ld b,40
.cell:  ld a,(ix+0)
        and c
        jr z,.z
        ld a,e
.z:     ld (hl),a
        inc hl
        inc ix
        djnz .cell
        pop bc
        sla c
        inc b
        ld a,b
        cp 7
        jr c,.row
        ret

gr_grad: db 77h, 66h, 66h, 22h, 22h, 33h, 66h, 77h

; rows 15-18: pixel row j shows font row 6-j, shifted by a ripple
gr_reflect:
        ld hl,ABUF+(GR_TOP+7)*40
        ld b,0                  ; j (pixel row, even = top half)
.pr:    push bc
        push hl
        ; ripple offset for this pixel row: -2..1 -> source = bits - rip
        ld a,(mtick)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,b
        rrca
        rrca
        rrca
        add a,c                 ; t*8 + j*32
        call sin_a
        sra a
        sra a
        sra a
        sra a
        sra a
        sra a                   ; -2..1
        neg
        ld e,a
        ld d,0
        bit 7,a
        jr z,.p
        dec d
.p:     ld hl,gr_bits
        add hl,de
        ex de,hl                ; DE = source
        ; mask for font row 6-j (j = 7: none)
        ld a,6
        sub b
        ld c,0
        jr c,.m
        inc a
        ld c,1
.ms:    dec a
        jr z,.m
        sla c
        jr .ms
.m:     ; colour: brighter near the text, in the top or bottom nibble
        ld a,b
        cp 2
        ld a,55h
        jr c,.cc
        ld a,11h
.cc:    bit 0,b
        pop hl
        jr nz,.bot
        and 0F0h
        ld (.tc+1),a
        ld b,40
.t:     ld a,(de)
        inc de
        and c
        jr z,.t0
.tc:    ld a,0
.t0:    ld (hl),a
        inc hl
        djnz .t
        jr .nx
.bot:   and 0Fh
        ld (.bc+1),a
        ld b,40
.b:     ld a,(de)
        inc de
        and c
        jr z,.b0
.bc:    ld a,0
.b0:    or (hl)
        ld (hl),a
        inc hl
        djnz .b
.nx:    pop bc
        ld de,-40
        add hl,de               ; back to the row start
        bit 0,b
        jr z,.same
        ld de,40
        add hl,de
.same:  inc b
        ld a,b
        cp 8
        jp c,.pr
        ret

; parallax stars: erase, move, draw.  x = 0..159 (4 steps per column)
gr_stars_move:
        ld ix,gr_stars
        ld b,NSTARS
.l:     push bc
        call .addr
        ld (hl),0
        ld a,(ix+2)
        sub (ix+3)
        jr nc,.ok
        add a,160
.ok:    ld (ix+2),a
        call .addr
        ld a,(ix+3)
        cp 3
        ld a,2Eh                ; '.'
        jr c,.ch
        ld a,6Bh                ; '*'
.ch:    ld (hl),a
        set 3,h
        ld a,(ix+3)
        dec a
        ld e,a
        ld d,0
        push hl
        ld hl,gr_starcol
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        ld de,4
        add ix,de
        pop bc
        djnz .l
        ret
.addr:  ld a,(ix+0)             ; row
        add a,a
        ld e,a
        ld d,0
        ld hl,gr_rowaddr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ix+2)
        rrca
        rrca
        and 3Fh
        ld e,a
        add hl,de
        ret

gr_rowaddr:
.r = 0
        DUP 25
        dw VCHR + .r*40
.r = .r + 1
        EDUP

gr_starcol: db 10h, 10h, 50h, 70h

gr_textp:  dw 0
gr_col:    db 0
gr_sub:    db 0
gr_cphase: db 0
gr_rip:    db 0
gr_rmask:  db 0
gr_rcol:   db 0
gr_rodd:   db 0
           db 0, 0
gr_bits:   ds 40
           db 0, 0
gr_stars:  ds NSTARS*4
