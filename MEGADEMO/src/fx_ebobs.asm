; ---------------------------------------------------------------------------
; fx_ebobs.asm - endless bobs: 3x3-character balls drawn along Lissajous
; paths and never erased, so the trails fill the screen.  The paths change
; every bar, the colours every few frames.
; ---------------------------------------------------------------------------

NEB     equ 4

ebobs_init:
        jp cls_black

ebobs_frame:
        call wait_vbl
        ld a,(mus_pos)
        and 3
        add a,a
        ld e,a
        ld d,0
        ld hl,eb_paths
        add hl,de
        ld a,(hl)
        ld (eb_sx),a
        inc hl
        ld a,(hl)
        ld (eb_sy),a
        ld b,NEB
.bob:   push bc
        ld a,b
        rrca
        rrca
        rrca                    ; bob * 32: phase
        ld c,a
        ; x = 18 + sin(t*sx + phase) * 18/128
        ld a,(eb_sx)
        call eb_tmul
        add a,c
        call sin_a
        sra a
        sra a
        sra a
        ld e,a
        sra a
        sra a
        sra a
        add a,e                 ; ~ 0.14 * sin -> +-18
        add a,18
        ld (eb_x),a
        ld a,(eb_sy)
        call eb_tmul
        add a,c
        add a,c
        call sin_a
        sra a
        sra a
        sra a
        sra a                   ; +-7.9
        ld e,a
        sra a
        add a,e                 ; +-11
        add a,11
        call mul40
        ld a,(eb_x)
        ld e,a
        ld d,0
        add hl,de
        ld de,VCHR
        add hl,de
        ; colour
        ld a,(mtick)
        rrca
        rrca
        rrca
        add a,c
        and 7
        ld e,a
        ld d,0
        push hl
        ld hl,eb_cols
        add hl,de
        ld c,(hl)
        pop hl
        ; draw 3x3
        ld de,eb_ball
        ld b,3
.r:     push bc
        ld b,3
.c:     ld a,(de)
        inc de
        ld (hl),a
        set 3,h
        ld (hl),c
        res 3,h
        inc hl
        djnz .c
        push de
        ld de,37
        add hl,de
        pop de
        pop bc
        djnz .r
        pop bc
        djnz .bob
        ret

eb_tmul:                        ; A = mtick * A (A = 1-3)
        ld e,a
        ld a,(mtick)
        ld d,a
        xor a
.m:     add a,d
        dec e
        jr nz,.m
        ret

eb_ball:  db 4Eh, 43h, 4Dh, 43h, 43h, 43h, 42h, 43h, 56h
eb_paths: db 1, 2,  2, 3,  3, 1,  1, 3
eb_cols:  db 10h, 50h, 70h, 60h, 20h, 30h, 40h, 50h
eb_sx:    db 0
eb_sy:    db 0
eb_x:     db 0
