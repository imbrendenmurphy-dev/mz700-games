; =====================================================================
;  sky.asm - the sky, rows 2-8: clouds (rows 2-5) and a skyline (rows
;  6-8), each a 64-column pattern that wraps and slides sideways on the
;  bends, the skyline faster than the clouds.  Only characters that
;  changed are written (SKYSH is the shadow).  Colours are one attribute
;  per row, written by sky_init.
; =====================================================================

NSKY    equ 7

; theme's sky: HL = 7 x 64 characters, then 7 attributes
sky_init:
        ld (skypat),hl
        push hl                 ; SKYBUF: each row twice over (no wrapping)
        ld de,SKYBUF
        ld c,NSKY
.d:     push bc
        push hl
        ld bc,64
        ldir
        pop hl
        ld bc,64
        ldir
        pop bc
        dec c
        jr nz,.d
        pop hl
        ld de,7*64
        add hl,de
        ld de,skyattr
        ld bc,NSKY
        ldir
        ld hl,CRAM+SKYROW*40    ; colours
        ld de,skyattr
        ld c,NSKY
.r:     ld a,(de)
        inc de
        ld b,40
.c:     ld (hl),a
        inc hl
        djnz .c
        dec c
        jr nz,.r
        ld hl,SKYSH             ; force every character
        ld bc,NSKY*40
.f:     ld (hl),0FFh
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.f
        ld a,1
        ld (skyforce),a
        ret

; at the blank: redraw the rows whose offset moved
sky_update:
        ld a,(skyx+1)           ; skyline offset
        and 63
        ld b,a
        ld a,(skyx+1)
        rra
        and 63                  ; clouds: half as fast
        ld c,a
        ld a,(skyforce)
        or a
        jr nz,.all
        ld a,(sky_o1)
        cp c
        jr nz,.cl
.m:     ld a,(sky_o2)
        cp b
        ret z
        jr .mt
.all:   xor a
        ld (skyforce),a
.cl:    ld a,c
        ld (sky_o1),a
        push bc
        ld b,0                  ; rows 0-3
        ld c,4
        call sky_rows
        pop bc
        ld a,(sky_o2)
        cp b
        ret z
.mt:    ld a,b
        ld (sky_o2),a
        ld b,4
        ld c,3
        ; fall through
; draw C rows from sky row B, offset A
sky_rows:
        ld (sky_off),a
.r:     push bc
        ld a,b
        cp MSGROW-SKYROW        ; the message row, while a message shows
        jr nz,.go
        ld a,(msgtime)
        or a
        jp nz,.nx
.go:    ld l,b                  ; DE = SKYBUF + row*128 + offset
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(sky_off)
        ld e,a
        ld d,0
        add hl,de
        ld de,SKYBUF
        add hl,de
        push hl
        ld a,b                  ; HL = SKYSH + row*40
        add a,SKYROW
        ld b,a
        ld c,0
        call cell_ofs
        ld de,SKYSH-SKYROW*40
        add hl,de
        pop de
        rept 40
        ld a,(de)
        cp (hl)
        call nz,sky_put
        inc de
        inc hl
        endr
.nx:    pop bc
        inc b
        dec c
        jp nz,.r
        ret

; a changed sky cell: A into the shadow at HL and into VRAM
sky_put:
        ld (hl),a
        push hl
        ld bc,VRAM+SKYROW*40-SKYSH
        add hl,bc
        ld (hl),a
        pop hl
        ret
