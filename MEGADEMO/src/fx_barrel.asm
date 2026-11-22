; ---------------------------------------------------------------------------
; fx_barrel.asm - rolling barrel scrollers: big-font text wrapped round two
; upright cylinders turning in opposite directions.  Screen column x shows
; surface column BR_U[x] (an arcsine, so letters squeeze at the edges) in
; shade BR_S[x] (0 = edge .. 3 = front).  Each font row is one cell row.
; Barrel struct (IX): +0 text pointer, +2 column 0-5, +3 direction,
; +4 ABUF row, +6 letter colours, +8 body colours, +10 text start,
; +12 text end (the 0), +14 speed mask
; ---------------------------------------------------------------------------

BRCB    equ WORK                ; 64 surface columns of font bits

barrel_init:
        call chunky_init
        ld hl,br_cap
        ld de,VCHR+12*40
        ld a,50h
        jp print_at

barrel_frame:
        call wait_vbl
        ld bc,0307h
        call blit_attr_rows
        ld bc,0E07h
        call blit_attr_rows
        ld ix,br_one
        call br_draw
        ld ix,br_two
        jp br_draw

br_draw:
        ; move: one column per frame (or every other frame)
        ld a,(fcount)
        and (ix+14)
        jr nz,.build
        ld a,(ix+3)
        or a
        jp m,.back
        ld a,(ix+2)             ; forwards
        inc a
        cp 6
        jr c,.f1
        ld l,(ix+0)
        ld h,(ix+1)
        inc hl
        ld a,(hl)
        or a
        jr nz,.f0
        ld l,(ix+10)
        ld h,(ix+11)
.f0:    ld (ix+0),l
        ld (ix+1),h
        xor a
.f1:    ld (ix+2),a
        jr .build
.back:  ld a,(ix+2)
        dec a
        jp p,.b1
        ld l,(ix+0)
        ld h,(ix+1)
        ld e,(ix+10)
        ld d,(ix+11)
        or a
        sbc hl,de
        jr z,.wr
        add hl,de
        dec hl
        jr .b0
.wr:    ld l,(ix+12)
        ld h,(ix+13)
        dec hl
.b0:    ld (ix+0),l
        ld (ix+1),h
        ld a,5
.b1:    ld (ix+2),a
.build: ; 64 surface columns
        ld l,(ix+0)
        ld h,(ix+1)
        ld c,(ix+2)
        ld de,BRCB
        ld b,64
.cb:    ld a,c
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
        add hl,de
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
        inc e
        inc c
        ld a,c
        cp 6
        jr c,.nx
        ld c,0
        inc hl
        ld a,(hl)
        or a
        jr nz,.nx
        ld l,(ix+10)
        ld h,(ix+11)
.nx:    djnz .cb
        ; columns onto the barrel
        ld l,(ix+4)
        ld h,(ix+5)
        ld (br_dst),hl
        ld hl,br_u
        ld (br_up),hl
        ld b,40
.col:   push bc
        ld hl,(br_up)
        ld a,(hl)               ; surface column
        inc hl
        ld (br_up),hl
        ld e,a
        ld d,BRCB/256
        ld a,(de)               ; its font bits
        ld c,a
        ld de,br_s-br_u-1
        add hl,de
        ld a,(hl)               ; shade 0-3
        ld e,a
        ld d,0
        ld l,(ix+6)
        ld h,(ix+7)
        add hl,de
        ld b,(hl)               ; letter colour
        ld l,(ix+8)
        ld h,(ix+9)
        add hl,de
        ld e,(hl)               ; body colour
        ld hl,(br_dst)
        push hl
        ld a,7
.r:     rr c
        ld (hl),e
        jr nc,.r0
        ld (hl),b
.r0:    push de
        ld de,40
        add hl,de
        pop de
        dec a
        jr nz,.r
        pop hl
        inc hl
        ld (br_dst),hl
        pop bc
        djnz .col
        ret

br_one: dw br_text1
        db 0, 1
        dw ABUF+3*40, br_lc1, br_bc1, br_text1, br_text1_end
        db 0
br_two: dw br_text2
        db 0, 0FFh
        dw ABUF+14*40, br_lc2, br_bc2, br_text2, br_text2_end
        db 1
br_lc1: db 11h, 55h, 77h, 77h
br_bc1: db 00h, 00h, 11h, 11h
br_lc2: db 22h, 66h, 77h, 77h
br_bc2: db 00h, 00h, 33h, 33h

br_dst: dw 0
br_up:  dw 0
