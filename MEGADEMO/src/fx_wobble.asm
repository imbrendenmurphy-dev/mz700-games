; ---------------------------------------------------------------------------
; fx_wobble.asm - the SHARP EDGES logo as 40x30 chunky pixels, every pixel
; row pushed sideways by its own sine: the wobbling logo.
; Logo rows 1-15 become pixel rows 10-39 (2 each), drawn from runs
; (wb_runs: per logo row a count, then x, width).  Each cell row is filled
; with the background first, then the logo's runs are poked into the top or
; bottom nibble.  Behind it, thin blue lines drift down.
; ---------------------------------------------------------------------------

wobble_init:
        jp chunky_init

wobble_frame:
        call chunky_show
        ld hl,ABUF
        xor a
.cell:  ld (wb_r),a
        ld (wb_row0),hl
        ; background for both halves: a blue line every 8th pixel row
        add a,a
        call wb_bg
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(wb_r)
        add a,a
        inc a
        call wb_bg
        or c
        DUP 40
        ld (hl),a
        inc hl
        EDUP
        ld a,(wb_r)
        add a,a
        ld c,0F0h
        call wb_row
        ld a,(wb_r)
        add a,a
        inc a
        ld c,0Fh
        call wb_row
        ld hl,(wb_row0)
        ld de,40
        add hl,de
        ld a,(wb_r)
        inc a
        cp 25
        jp c,.cell
        ret

wb_bg:  ld b,a                  ; A = pixel row -> 0 or 1
        ld a,(mtick)
        srl a
        add a,b
        and 7
        ld a,0
        ret nz
        inc a
        ret

; A = pixel row, C = nibble mask for this half (F0h top, 0Fh bottom)
wb_row: sub 10
        ret c
        cp 30
        ret nc
        ld b,a
        ; ink for this pixel row, in both nibbles, masked
        ld e,a
        ld d,0
        ld hl,wb_ink
        add hl,de
        ld a,(hl)
        and c
        ld (wb_inkv),a
        ld a,c
        cpl
        ld (wb_keep),a
        ; offset -4..3 from a sine of row and time
        ld a,b
        add a,10
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(mtick)
        add a,a
        add a,a
        add a,e
        ld h,SINE/256
        ld l,a
        ld a,(hl)
        sra a
        sra a
        sra a
        sra a
        sra a
        ld (wb_off),a
        ; runs of logo row 1 + b/2
        ld a,b
        srl a
        add a,a
        ld e,a
        ld d,0
        ld hl,wb_runtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld b,(hl)               ; run count
        inc hl
        inc b
        dec b
        ret z
.run:   push bc
        ld a,(wb_off)
        add a,(hl)              ; x
        inc hl
        ld c,(hl)               ; width
        inc hl
        push hl
        ld hl,(wb_row0)
.px:    cp 40
        jr nc,.n
        push hl
        ld e,a
        ld d,0
        add hl,de
        ld e,a
        ld a,(wb_keep)
        and (hl)
        ld d,a
        ld a,(wb_inkv)
        or d
        ld (hl),a
        ld a,e
        pop hl
.n:     inc a
        dec c
        jr nz,.px
        pop hl
        pop bc
        djnz .run
        ret

wb_r:    db 0
wb_off:  db 0
wb_inkv: db 0
wb_keep: db 0
wb_row0: dw 0
