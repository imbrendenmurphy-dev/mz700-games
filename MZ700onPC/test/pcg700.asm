; PCG-700 test: char 80h (set 1) = checkerboard written from E010, 81h = copy of CG-ROM 'A' (01h),
; then shown in a row with the PCG on (rows 2-3) - row 5 shows code 80h after turning it off again? no: stays on.
        org 1200h
start:  di
        ld hl,0D800h            ; attrs white on black
        ld bc,1000
.cl:    ld (hl),70h
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.cl
        ; char 80h: addr 0..7 (char 0 of the PCG area), alternating AA/55
        ld b,0
.def:   ld a,b
        and 1
        ld a,0AAh
        jr z,.e
        ld a,55h
.e:     ld (0E010h),a
        ld a,b
        ld (0E011h),a
        ld a,08h                ; strobe low, display off
        ld (0E012h),a
        ld a,18h                ; strobe high -> write
        ld (0E012h),a
        inc b
        ld a,b
        cp 8
        jr nz,.def
        ; char 81h = copy of the CG-ROM row data at the same index (font[0x408+r] = code 81h of set 1 in the ROM)
        ld b,8
.cp:    ld a,b
        add a,7                 ; addresses 8..15
        ld (0E011h),a
        ld a,28h                ; copy bit, strobe low, display off
        ld (0E012h),a
        ld a,38h
        ld (0E012h),a
        djnz .cp
        ld a,00h                ; display on (bit 3 low)
        ld (0E012h),a
        ld hl,0D000h+80
        ld (hl),80h
        inc hl
        ld (hl),81h
        inc hl
        ld (hl),01h             ; 'A' from the CG-ROM
        inc hl
        ld (hl),80h
        jr $
