; MZ-1500 PCG test: PCG char 10h: blue plane = all on, red plane = right half on -> left blue, right magenta.
; cell 0 of row 2 shows it under text 'A' (white fg); cell 2 shows it over text (priority 3).
        org 1200h
start:  di
        ld hl,0D800h
        ld bc,1000
.cl:    ld (hl),70h
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.cl
        ld a,1
        out (0E5h),a            ; blue plane at D000
        ld hl,0D000h+10h*8
        ld b,8
.b:     ld (hl),0FFh
        inc hl
        djnz .b
        ld a,2
        out (0E5h),a            ; red plane
        ld hl,0D000h+10h*8
        ld b,8
.r:     ld (hl),0Fh
        inc hl
        djnz .r
        out (0E6h),a            ; unmap
        ld a,01h                ; PCG on, text fg over PCG over bg
        out (0F0h),a
        ld a,01h                ; 'A'
        ld (0D000h+80),a
        ld (0D000h+82),a
        ld a,10h
        ld (0D400h+80),a        ; PCG code low bits
        ld (0D400h+82),a
        ld a,08h
        ld (0DC00h+80),a        ; PCG on for the cell
        ld (0DC00h+82),a
        jr $
