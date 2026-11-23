; HWTEST2 - MZ700onPC: which line of the field has no HBLANK pulse on E008 bit 7?
; HWTEST counted 311 pulses per field on a real PAL MZ-700, against 312 lines. This one times every pulse
; (bit 7 low) and every gap (bit 7 high) for one field, starting at the /VBLK fall (E002 bit 7), and reports:
;  1 the wait from VBLANK starting to the first pulse
;  2 how many pulses come before /VBLK rises again (VBLANK lines)
;  3 the line(s) with no pulse, numbered with 0 = the top picture line, 200 = the first VBLANK line
;  4 the shortest and longest pulse, 5 the shortest and longest gap on normal lines (units of 33 T)
;  6 the raw gap/pulse lengths round the first missing pulse
; Interrupts off; it repeats, so the numbers should hold steady.
        org 1200h
        jp start
r_first: dw 0                   ; 1203 wait loops (29 T) from /VBLK fall to the first pulse
r_vbl:   dw 0                   ; 1205 pulses before /VBLK rises
r_nmiss: dw 0                   ; 1207
r_miss:  dw 0, 0, 0, 0          ; 1209 missing lines
r_lmin:  dw 0                   ; 1211
r_lmax:  dw 0
r_hmin:  dw 0
r_hmax:  dw 0
r_ctx:   dw 0                   ; record index of the first gap

E_FIRST equ 1
E_VBL   equ 112
E_LMIN  equ 2
E_LMAX  equ 3
E_HMIN  equ 1
E_HMAX  equ 2

NREC    equ 330
REC     equ 3000h               ; NREC records of (gap, pulse, E002)
GAPMAX  equ 5                   ; a gap longer than this spans a line with no pulse

WHITE   equ 70h
YELLOW  equ 60h
CYAN    equ 50h
GREEN   equ 40h
RED     equ 20h
GREY    equ 70h

start:  di
        ld sp, 10F0h
        call cls
        ld hl, statics
        call prtall
        call expected
main:   call capture
        call analyse
        call show
        jr main

; ---------------------------------------------------------------- capture one field
; Each record is stored at the rising edge (start of the gap after a pulse, about 128 T free):
; the gap before this pulse, the pulse, and E002 read just after it.
capture:
.s1:    ld a, (0E002h)          ; wait for the picture ...
        rla
        jr nc, .s1
.s2:    ld a, (0E002h)          ; ... then for /VBLK to fall
        rla
        jr c, .s2
        ld de, 0
.w:     inc de                  ; 6 + 13 + 4 + 12 = 35 T a loop
        ld a, (0E008h)
        rla
        jr c, .w
        ld (r_first), de
        ld hl, REC
        ld de, NREC
        ld bc, 0
.lo:    inc b                   ; 33 T a count, while the pulse lasts
        ld a, (0E008h)
        rla
        jr nc, .lo
        ld (hl), c
        inc hl
        ld (hl), b
        inc hl
        ld a, (0E002h)
        ld (hl), a
        inc hl
        dec de
        ld a, d
        or e
        ret z
        ld bc, 0
.hi:    inc c                   ; 33 T a count, while the gap lasts
        ld a, (0E008h)
        rla
        jr c, .hi
        jr .lo

; ---------------------------------------------------------------- analyse
analyse:
        ld hl, 0
        ld (r_nmiss), hl
        ld (r_miss), hl
        ld (r_miss + 2), hl
        ld (r_miss + 4), hl
        ld (r_miss + 6), hl
        ld (r_ctx), hl
        ld a, 255
        ld (r_lmin), a
        ld (r_hmin), a
        xor a
        ld (r_lmax), a
        ld (r_hmax), a
        ld (r_vbl), a
        ld (r_vbl + 1), a
        ; pulses before /VBLK rises: the first record whose E002 bit 7 is high
        ld ix, REC
        ld de, 0
.v:     bit 7, (ix + 2)
        jr nz, .vd
        inc de
        inc ix
        inc ix
        inc ix
        ld a, d
        cp high NREC
        jr nz, .v
        ld a, e
        cp low NREC
        jr nz, .v
.vd:    ld (r_vbl), de
        ; records 1..311: pulse min/max, gap min/max, gaps that span a missing line
        ld ix, REC + 3
        ld de, 1                ; record index
        ld bc, 0                ; C = lines missed so far
        ; a long wait for the first pulse means line 200 itself had none
        ld hl, (r_first)
        ld a, h
        or a
        jr nz, .l200
        ld a, l
        cp 9
        jr c, .r
.l200:  ld hl, 200
        ld (r_miss), hl
        ld c, 1
        ld a, 1
        ld (r_nmiss), a
.r:     ld a, (ix + 1)          ; pulse length
        ld hl, r_lmin
        cp (hl)
        jr nc, $+3
        ld (hl), a
        ld hl, r_lmax
        cp (hl)
        jr c, $+3
        ld (hl), a
        ld a, (ix + 0)          ; gap length
        cp GAPMAX + 1
        jr nc, .miss
        ld hl, r_hmin
        cp (hl)
        jr nc, $+3
        ld (hl), a
        ld hl, r_hmax
        cp (hl)
        jr c, $+3
        ld (hl), a
        jr .nx
.miss:  ; record DE's pulse comes a line late: line 200 + DE + C had none
        ld a, c
        cp 4
        jr nc, .nx
        ld hl, (r_ctx)
        ld a, h
        or l
        jr nz, .notfirst
        ld (r_ctx), de
.notfirst:
        push de
        ld hl, 200
        add hl, de
        ld d, 0
        ld e, c
        add hl, de
        ld de, -312             ; wrap past the end of the field
        add hl, de
        jr c, $+4
        sbc hl, de              ; carry clear here: undo
        ld a, c                 ; the next field's line 200 again: skip it
        or a
        jr z, .new
        ld de, (r_miss)
        or a
        sbc hl, de
        add hl, de
        jr nz, .new
        pop de
        jr .nx
.new:   ex de, hl
        ld hl, r_miss
        ld a, c
        add a, a
        add a, l
        ld l, a
        jr nc, $+3
        inc h
        ld (hl), e
        inc hl
        ld (hl), d
        pop de
        inc c
        ld a, c
        ld (r_nmiss), a
.nx:    inc ix
        inc ix
        inc ix
        inc de
        ld a, e
        cp low 312
        jr nz, .r
        ld a, d
        cp high 312
        jr nz, .r
        ret

; ---------------------------------------------------------------- show
show:   ld hl, (r_first)
        ld de, 0D000h + 3 * 40 + 30
        call num
        ld hl, (r_vbl)
        ld de, 0D000h + 6 * 40 + 30
        call num
        ld hl, (r_nmiss)
        ld de, 0D000h + 9 * 40 + 30
        call num
        ; the missing lines, up to four, on row 10
        ld hl, 0D000h + 10 * 40 + 4
        ld b, 26
.cl:    ld (hl), 0
        inc hl
        djnz .cl
        ld a, (r_nmiss)
        or a
        jr z, .none
        ld b, a
        ld iy, r_miss
        ld de, 0D000h + 10 * 40 + 4
.ml:    push bc
        ld l, (iy + 0)
        ld h, (iy + 1)
        push de
        call num
        pop de
        ld hl, 6
        add hl, de
        ex de, hl
        inc iy
        inc iy
        pop bc
        djnz .ml
.none:  ld a, (r_lmin)
        ld l, a
        ld h, 0
        ld de, 0D000h + 13 * 40 + 24
        call num
        ld a, (r_lmax)
        ld l, a
        ld h, 0
        ld de, 0D000h + 13 * 40 + 30
        call num
        ld a, (r_hmin)
        ld l, a
        ld h, 0
        ld de, 0D000h + 16 * 40 + 24
        call num
        ld a, (r_hmax)
        ld l, a
        ld h, 0
        ld de, 0D000h + 16 * 40 + 30
        call num
        ; raw gap/pulse for records ctx-2 .. ctx+2 on row 20
        ld hl, 0D000h + 20 * 40
        ld b, 40
.c2:    ld (hl), 0
        inc hl
        djnz .c2
        ld a, (r_nmiss)
        or a
        ret z
        ld hl, (r_ctx)
        ld a, h
        or a
        jr nz, .c3
        ld a, l
        cp 2
        jr nc, .c3
        ld l, 2                 ; keep the window inside the records
.c3:    dec hl
        dec hl
        ld d, h
        ld e, l
        add hl, hl
        add hl, de              ; x3
        ld de, REC
        add hl, de
        push hl
        pop iy
        ld de, 0D000h + 20 * 40
        ld b, 5
.rl:    push bc
        ld l, (iy + 0)
        ld h, 0
        call num3
        ld a, 2Dh               ; '/'
        ld (de), a
        inc de
        ld l, (iy + 1)
        ld h, 0
        call num3
        inc de
        inc iy
        inc iy
        inc iy
        pop bc
        djnz .rl
        ret

; num3: HL (0-999) as three characters at DE, leading spaces; DE moves past them
num3:   push de
        ld de, 0D3F0h           ; build it off screen with num
        call num
        pop de
        ld hl, 0D3F2h
        ld b, 3
.c:     ld a, (hl)
        ld (de), a
        set 3, d
        ld a, YELLOW
        ld (de), a
        res 3, d
        inc hl
        inc de
        djnz .c
        ret

; ---------------------------------------------------------------- text
; num: HL = value, DE = VRAM, C = attr; 5 digits, leading spaces
num:    push de
        ld ix, digits
        ld bc, -10000
        call .dig
        ld bc, -1000
        call .dig
        ld bc, -100
        call .dig
        ld bc, -10
        call .dig
        ld a, l
        ld (ix + 0), a
        pop de
        ld hl, digits
        ld b, 5
        ld c, 1                 ; 1 while still in the leading zeros
.o:     ld a, (hl)
        or a
        jr nz, .dg
        ld a, b
        cp 1
        jr z, .zero             ; always show the last digit
        ld a, c
        or a
        jr z, .zero
        xor a                   ; a leading zero: space
        jr .put
.zero:  xor a
.dg:    ld c, 0
        add a, 20h              ; display code digit
.put:   ld (de), a
        set 3, d
        ld a, YELLOW
        ld (de), a
        res 3, d
        inc de
        inc hl
        djnz .o
        ret
.dig:   xor a
.dl:    add hl, bc
        inc a
        jr c, .dl
        dec a
        sbc hl, bc              ; carry is clear here
        ld (ix + 0), a
        inc ix
        ret
digits: ds 5

cls:    ld hl, 0D000h
        ld de, 0D001h
        ld bc, 999
        ld (hl), 0
        ldir
        ld hl, 0D800h
        ld de, 0D801h
        ld bc, 999
        ld (hl), WHITE
        ldir
        ret

; print: HL = ASCII string (0-terminated), DE = VRAM, C = attr
print:  ld a, (hl)
        inc hl
        or a
        ret z
        call atod
        ld (de), a
        set 3, d
        ld a, c
        ld (de), a
        res 3, d
        inc de
        jr print

atod:   cp 'A'
        jr c, .nl
        cp 'Z' + 1
        jr nc, .nl
        sub 40h
        ret
.nl:    cp '0'
        jr c, .p
        cp '9' + 1
        jr nc, .p
        add a, 20h - '0'
        ret
.p:     cp '-'
        jr nz, $+5
        ld a, 2Ah
        ret
        cp '.'
        jr nz, $+5
        ld a, 2Eh
        ret
        cp '/'
        jr nz, $+5
        ld a, 2Dh
        ret
        cp '<'
        jr nz, $+5
        ld a, 51h
        ret
        cp '='
        jr nz, $+5
        ld a, 2Bh
        ret
        cp ','
        jr nz, $+5
        ld a, 2Fh
        ret
        xor a
        ret

; prtall: list of (row, col, attr, string) until row FFh
prtall: ld a, (hl)
        cp 0FFh
        ret z
        inc hl
        push hl
        ld l, a                 ; row * 40
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl
        ld d, h
        ld e, l
        add hl, hl
        add hl, hl
        add hl, de
        ld de, 0D000h
        add hl, de
        ex de, hl
        pop hl
        ld a, (hl)
        inc hl
        add a, e
        ld e, a
        jr nc, $+3
        inc d
        ld c, (hl)
        inc hl
        call print
        jr prtall


ROWNUM  macro rr_, cc_, at_
        db rr_, cc_, at_
        endm

statics:
        ROWNUM 0, 1, CYAN
        db "HWTEST2  LINE WITH NO HBLANK PULSE", 0
        ROWNUM 1, 1, GREY
        db "----------------------------------", 0
        ROWNUM 3, 1, WHITE
        db "1 VBLANK TO FIRST PULSE", 0
        ROWNUM 4, 3, GREY
        db "EMULATOR SAYS", 0
        ROWNUM 6, 1, WHITE
        db "2 PULSES IN VBLANK", 0
        ROWNUM 7, 3, GREY
        db "EMULATOR SAYS", 0
        ROWNUM 9, 1, WHITE
        db "3 LINES WITH NO PULSE", 0
        ROWNUM 11, 3, GREY
        db "0 = TOP LINE.  EMULATOR SAYS NONE", 0
        ROWNUM 13, 1, WHITE
        db "4 PULSE MIN, MAX", 0
        ROWNUM 14, 3, GREY
        db "EMULATOR SAYS", 0
        ROWNUM 16, 1, WHITE
        db "5 GAP MIN, MAX", 0
        ROWNUM 17, 3, GREY
        db "EMULATOR SAYS", 0
        ROWNUM 19, 1, WHITE
        db "6 GAP/PULSE ROUND THE MISSING PULSE", 0
        ROWNUM 22, 1, CYAN
        db "YELLOW = THIS MACHINE.", 0
        ROWNUM 23, 1, CYAN
        db "LENGTHS ARE IN STEPS OF 33 T.", 0
        ROWNUM 24, 1, GREY
        db "PLEASE PHOTOGRAPH THIS SCREEN.", 0
        db 0FFh

expected:
        ld hl, E_FIRST
        ld de, 0D000h + 4 * 40 + 30
        call numg
        ld hl, E_VBL
        ld de, 0D000h + 7 * 40 + 30
        call numg
        ld hl, E_LMIN
        ld de, 0D000h + 14 * 40 + 24
        call numg
        ld hl, E_LMAX
        ld de, 0D000h + 14 * 40 + 30
        call numg
        ld hl, E_HMIN
        ld de, 0D000h + 17 * 40 + 24
        call numg
        ld hl, E_HMAX
        ld de, 0D000h + 17 * 40 + 30
numg:   push de
        call num
        pop de
        ld b, 5
        set 3, d
.c:     ld a, WHITE
        ld (de), a
        inc de
        djnz .c
        ret
