; ---------------------------------------------------------------------------
; fx_moire.asm - interference rings: two sets of concentric rings, XORed.
; MOIT: 60 rows x 64 bytes, ring colour*11h by distance from (32, 30); the
; rings of set 1 are blue (11h) and those of set 2 green (44h), so the XOR
; gives black, blue, green and cyan.  Built at init from a quarter table in
; high RAM.  A 40-pixel row never crosses its 64-byte row, so inc e / inc l.
; ---------------------------------------------------------------------------

MOIT    equ WORK                ; 60 x 64 = 3840 bytes
MOIT2   equ WORK+0F00h          ; the same rings in the other colour

moire_init:
        call chunky_init
        ; quarter (32 x 31) from high RAM into CBUF (unused here)
        ld hl,hi_moire
        ld de,CBUF
        ld bc,32*31
        call hicopy
        ld ix,MOIT
        ld c,0                  ; ty
.y:     ld a,c
        sub 30
        jr nc,.ay
        neg
.ay:    ; |dy| row of the quarter
        cp 31
        jr c,.y1
        ld a,30
.y1:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *32
        ld de,CBUF
        add hl,de
        ld b,0                  ; tx
.x:     ld a,b
        sub 32
        jr nc,.ax
        neg
.ax:    cp 32
        jr c,.x1
        ld a,31
.x1:    push hl
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)               ; ring index & 3
        pop hl
        push hl
        ld hl,mo_c1
        add a,l
        ld l,a
        jr nc,.n1
        inc h
.n1:    ld e,(hl)               ; set-1 colour
        inc hl
        inc hl
        inc hl
        inc hl
        ld d,(hl)               ; set-2 colour
        pop hl
        ld (ix+0),e
        push ix
        push de
        ld de,MOIT2-MOIT
        add ix,de
        pop de
        ld (ix+0),d
        pop ix
        inc ix
        inc b
        ld a,b
        cp 64
        jr c,.x
        inc c
        ld a,c
        cp 60
        jr c,.y
        ret

moire_frame:
        call chunky_show
        ; centres: set 1 at (cx1, cy1), set 2 at (cx2, cy2)
        ld a,(mtick)
        call sin_a
        sra a
        sra a
        sra a                   ; +-15
        add a,20
        ld (mo_cx1),a
        ld a,(mtick)
        add a,a
        add a,40
        call sin_a
        sra a
        sra a
        sra a
        sra a                   ; +-7 -> clip to +-5
        call mo_clip5
        add a,25
        ld (mo_cy1),a
        ld a,(mtick)
        add a,a
        add a,128
        call sin_a
        sra a
        sra a
        sra a
        add a,20
        ld (mo_cx2),a
        ld a,(mtick)
        add a,200
        call sin_a
        sra a
        sra a
        sra a
        sra a
        call mo_clip5
        add a,25
        ld (mo_cy2),a
        ; first pixel row pointers: MOIT + (35 - cy)*64 + 32 - cx
        ld a,(mo_cy1)
        ld c,a
        ld a,(mo_cx1)
        ld hl,MOIT
        call .ptr
        ld (mo_p1),hl
        ld a,(mo_cy2)
        ld c,a
        ld a,(mo_cx2)
        ld hl,MOIT2
        call .ptr
        ld (mo_p2),hl
        ld bc,ABUF
        ld a,25
.row:   push af
        ; top pixel row
        ld de,(mo_p1)
        ld hl,(mo_p2)
        DUP 40
        ld a,(de)
        xor (hl)
        and 0F0h
        ld (bc),a
        inc e
        inc l
        inc bc
        EDUP
        call .adv
        ; bottom pixel row
        ld a,c
        sub 40
        ld c,a
        jr nc,.b0
        dec b
.b0:    ld de,(mo_p1)
        ld hl,(mo_p2)
        DUP 40
        ld a,(de)
        xor (hl)
        and 0Fh
        ld ixl,a
        ld a,(bc)
        or ixl
        ld (bc),a
        inc e
        inc l
        inc bc
        EDUP
        call .adv
        pop af
        dec a
        jp nz,.row
        ret
.adv:   ld hl,(mo_p1)           ; both pointers down a row
        ld de,64
        add hl,de
        ld (mo_p1),hl
        ld hl,(mo_p2)
        add hl,de
        ld (mo_p2),hl
        ret
.ptr:   ; HL = base + (30 - C)*64 + 32 - A
        neg
        add a,32
        ld e,a
        ld d,0
        add hl,de
        ld a,30
        sub c
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ret

mo_clip5:
        cp 6
        jr c,.ok                ; 0..5
        cp -5
        ret nc                  ; -5..-1
        bit 7,a
        ld a,5
        ret z
        ld a,-5
.ok:    ret

mo_c1:  db 00h, 11h, 00h, 11h   ; set 1 by ring index
mo_c2:  db 00h, 44h, 44h, 00h   ; set 2

mo_cx1: db 0
mo_cy1: db 0
mo_cx2: db 0
mo_cy2: db 0
mo_p1:  dw 0
mo_p2:  dw 0
