; ---------------------------------------------------------------------------
; fx_plasma.asm - 40x50 colour plasma.
;
; "Half-block mode": every character is 7Ah (top half filled), so the ink is
; the colour of the upper 8x4 pixel and the paper the colour of the lower one.
; Only the attributes change: a 40x50 8-colour bitmap for 1000 bytes.
; pixel = pal[X[x] + Y[y]]; PALx pages: +0 = colour<<4 (top), +256 = colour.
; ---------------------------------------------------------------------------

chunky_init:                    ; all cells 7Ah, black
        ld a,7Ah
        ld hl,CBUF
        call fill_buf
        call blit_char
        xor a
        ld hl,ABUF
        call fill_buf
        jp blit_attr

plasma_init:
        call chunky_init
        ld a,PALS/256
        ld (pl_pal),a
        ret

plasma_frame:
        call wait_vbl
        call blit_attr
        ; palette: changes every bar
        ld a,(mus_pos)
        sub BAR_PLASMA
        and 3
        add a,a
        add a,PALS/256
        ld (pl_pal),a
        ; X values go straight into the cell code (2 immediates per cell)
        ld a,(mtick)
        ld c,a
        ld hl,pl_cells+1
        ld b,40
        ld e,0                  ; x*7
.xl:    ld a,e
        add a,c                 ; + t
        call sin_a
        sra a
        ld d,a
        ld a,e
        add a,a
        sub c
        sub c                   ; x*14 - 2t
        call sin_a
        sra a
        add a,d
        ld (hl),a
        ld de,7
        add hl,de
        ld (hl),a
        ld de,11
        add hl,de
        ld a,(pl_xa)
        add a,7
        ld (pl_xa),a
        ld e,a
        djnz .xl
        xor a
        ld (pl_xa),a
        ; Y table (50)
        ld hl,pl_y
        ld b,50
        ld e,0
.yl:    ld a,e
        sub c                   ; y*5 - t
        call sin_a
        sra a
        ld d,a
        ld a,e
        add a,a
        add a,c
        add a,c
        add a,c                 ; y*10 + 3t
        call sin_a
        sra a
        add a,d
        add a,c                 ; drift through the palette
        ld (hl),a
        inc hl
        ld a,e
        add a,5
        ld e,a
        djnz .yl
        ; cells
        ld de,ABUF
        ld iy,pl_y
        ld a,25
.row:   ld (pl_rows),a
        ld b,(iy+0)
        ld c,(iy+1)
        ld a,(pl_pal)
        ld h,a
        call pl_cells
        inc iy
        inc iy
        ld a,(pl_rows)
        dec a
        jr nz,.row
        ret

; one row of 40 cells: B = Y top, C = Y bottom, H = palette page, DE -> ABUF
pl_cells:
        DUP 40
        ld a,0                  ; X (patched)
        add a,b
        ld l,a
        ld a,(hl)               ; top colour << 4
        inc h
        ex af,af'
        ld a,0                  ; X (patched)
        add a,c
        ld l,a
        ld a,(hl)               ; bottom colour
        dec h
        ld l,a
        ex af,af'
        or l
        ld (de),a
        inc de
        EDUP
        ret
        ASSERT pl_cells.end - pl_cells == 40*18+1
pl_cells.end:

pl_xa:   db 0
pl_rows: db 0
pl_pal: db 0
pl_y:   ds 50
