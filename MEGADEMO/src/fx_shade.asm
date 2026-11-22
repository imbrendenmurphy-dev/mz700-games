; ---------------------------------------------------------------------------
; fx_shade.asm - shadebobs: 5 round stamps wander on Lissajous paths and add
; one to every pixel they cover (mod 16) in a 40x50 value buffer, which a
; 16-colour cycle turns into bands.  Only the cells under each bob are
; recoloured, straight into VRAM, so it runs at 50 fps.
; ---------------------------------------------------------------------------

SHV     equ WORK                ; 40 x 50 values
NSHB    equ 3

shade_init:
        call chunky_init
        ld hl,SHV
        ld de,SHV+1
        ld bc,1999
        ld (hl),0
        ldir
        ld hl,sh_cap
        ld de,VCHR+24*40
        ld a,50h
        jp print_at

shade_frame:
        call wait_vbl
        ld ix,sh_bobs
        ld b,NSHB
.bob:   push bc
        ; x = 20 + 16 sin(t*a + p), y = 24 + 18 sin(t*b + q)
        ld a,(mtick)
        srl a
        ld c,a
        ld a,(ix+0)
.mx:    ; multiply t by the speed (1-3) by repeated adds
        ld e,a
        xor a
.m1:    add a,c
        dec e
        jr nz,.m1
        add a,(ix+1)
        call sin_a
        sra a
        sra a
        sra a                   ; +-15
        add a,20
        ld (sh_x),a
        ld a,(ix+2)
        ld e,a
        xor a
.m2:    add a,c
        dec e
        jr nz,.m2
        add a,(ix+3)
        call sin_a
        sra a
        sra a
        sra a
        ld d,a
        sra a
        sra a
        sra a
        add a,d                 ; +-17
        add a,24
        ld (sh_y),a
        ; stamp
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; y*40
        ld a,(sh_x)
        ld e,a
        ld d,0
        add hl,de
        ld de,SHV
        add hl,de
        ld (sh_base),hl
        ld iy,sh_disc
.st:    ld e,(iy+0)
        ld d,(iy+1)
        ld a,d
        cp 80h
        jr z,.std
        ld hl,(sh_base)
        add hl,de
        ld a,(hl)
        inc a
        and 15
        ld (hl),a
        inc iy
        inc iy
        jr .st
.std:   ; recolour cells: rows (y-3)/2 .. (y+3)/2, columns x-3 .. x+3
        ld a,(sh_y)
        sub 4
        and 0FEh                ; even pixel row
        ld (sh_py),a
        ld c,5
.cr:    push bc
        ld a,(sh_py)
        call mul40
        ld a,(sh_x)
        sub 4
        ld e,a
        ld d,0
        add hl,de
        ld bc,SHV
        add hl,bc
        push hl                 ; top value of the first cell
        ld a,(sh_py)
        srl a
        call mul40
        add hl,de
        ld bc,VATR
        add hl,bc               ; its attribute
        pop de
        ld b,9
.cc:    push bc
        ld a,(de)               ; top value
        ld c,a
        push hl
        ld hl,40
        add hl,de
        ld a,(hl)               ; bottom value
        ld hl,sh_palb
        add a,l
        ld l,a
        jr nc,.p1
        inc h
.p1:    ld b,(hl)
        ld hl,sh_palt
        ld a,c
        add a,l
        ld l,a
        jr nc,.p2
        inc h
.p2:    ld a,(hl)
        or b
        pop hl
        ld (hl),a
        inc hl
        inc de
        pop bc
        djnz .cc
        ld hl,sh_py
        inc (hl)
        inc (hl)
        pop bc
        dec c
        jr nz,.cr
        ld de,4
        add ix,de
        pop bc
        dec b
        jp nz,.bob
        ret

; speed x, phase x, speed y, phase y
sh_bobs:    db 1, 0, 2, 64,  2, 40, 1, 0,  3, 90, 2, 10,  1, 160, 3, 200,  2, 220, 3, 128
sh_palt:    db 00h,10h,10h,50h,50h,70h,70h,60h,60h,20h,20h,30h,30h,10h,10h,00h
sh_palb:    db 00h,01h,01h,05h,05h,07h,07h,06h,06h,02h,02h,03h,03h,01h,01h,00h

sh_x:    db 0
sh_y:    db 0
sh_py:   db 0
sh_base: dw 0
