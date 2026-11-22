; ---------------------------------------------------------------------------
; fx_twist.asm - the twister: a square bar turning a little more on every
; pixel row, swaying from side to side.
; TWTPL (from high RAM): for each of 256 angles, two spans relative to the
; bar's centre: offset, width, colour (face * 2 + bright).  Per pixel row
; that leaves 2 sines and 2 span fills, straight into ABUF: the top row
; stores colour << 4 into a cleared row, the bottom row ORs its colour in.
; ---------------------------------------------------------------------------

TWTPL   equ WORK                ; 256 x 6 bytes

twist_init:
        call chunky_init
        ld hl,hi_twtpl
        ld de,TWTPL
        ld bc,256*6
        call hicopy
        ld hl,tw_cap
        ld de,VCHR+24*40
        ld a,50h
        jp print_at

twist_frame:
        call wait_vbl
        ld bc,24                ; rows 0-23 (24 = caption)
        call blit_attr_rows
        ld a,(mtick)
        ld (tw_t),a
        ld hl,ABUF
        xor a
.cell:  ld (tw_y),a
        ld (tw_row0),hl
        xor a                   ; clear the row
        DUP 40
        ld (hl),a
        inc hl
        EDUP
        ld a,(tw_y)
        add a,a
        ld c,0
        call tw_row
        ld a,(tw_y)
        add a,a
        inc a
        ld c,1
        call tw_row
        ld hl,(tw_row0)
        ld de,40
        add hl,de
        ld a,(tw_y)
        inc a
        cp 24
        jr c,.cell
        ret

; A = pixel row, C = 0 top (store colour << 4) / 1 bottom (OR colour)
tw_row: ld b,a
        ld a,c
        ld (tw_half),a
        ; angle: turns with time, twisted by a slow sine down the bar
        ld a,b
        add a,a
        add a,a
        ld c,a
        ld a,(tw_t)
        add a,c
        ld h,SINE/256
        ld l,a
        ld a,(hl)
        sra a
        ld c,a
        ld a,(tw_t)
        add a,a
        add a,c
        ld (tw_a),a
        ; centre sways
        ld a,b
        add a,a
        ld c,a
        ld a,(tw_t)
        add a,a
        sub c
        ld l,a
        ld a,(hl)
        sra a
        sra a
        sra a
        sra a
        add a,20
        ld (tw_cx),a
        ; the template
        ld a,(tw_a)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl               ; *6
        ld de,TWTPL
        add hl,de
        call .span
        ; fall into the second span
.span:  ld a,(hl)               ; offset
        inc hl
        ld b,(hl)               ; width
        inc hl
        ld c,(hl)               ; colour index
        inc hl
        inc b
        dec b
        ret z
        push hl
        ld hl,tw_cx
        add a,(hl)
        ld e,a
        ld d,0
        ld hl,(tw_row0)
        add hl,de
        push hl
        ld a,(tw_half)
        or a
        ld hl,tw_colT
        jr z,.ct
        ld hl,tw_colB
.ct:    ld e,c
        add hl,de
        ld c,(hl)
        pop hl
        jr nz,.or
.st:    ld (hl),c
        inc hl
        djnz .st
        pop hl
        ret
.or:    ld a,(hl)
        or c
        ld (hl),a
        inc hl
        djnz .or
        pop hl
        ret

; face colours: dark, bright for faces 0-3
tw_colT:    db 20h, 60h, 10h, 50h, 30h, 70h, 10h, 50h
tw_colB:    db 02h, 06h, 01h, 05h, 03h, 07h, 01h, 05h

tw_t:    db 0
tw_y:    db 0
tw_a:    db 0
tw_cx:   db 0
tw_half: db 0
tw_row0: dw 0
