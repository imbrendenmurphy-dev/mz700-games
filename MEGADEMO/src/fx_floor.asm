; ---------------------------------------------------------------------------
; fx_floor.asm - sunset over a perspective checkerboard.
; Sky: cell rows 0-11, a 480-byte attribute picture from high RAM (sun with
; stripes on a sunset gradient).  Floor: pixel rows 24-49.  Row j has depth
; fl_z[j]; across the row u = (x - 20) * fl_s[j] + camera x (8.8), and the
; checker is bit 0 of (u_int XOR (z + camera z)/16).
; ---------------------------------------------------------------------------

FLT     equ WORK                ; top-half row buffer
FLB     equ WORK+100h           ; bottom-half row buffer

floor_init:
        call chunky_init
        ld hl,hi_sky
        ld de,ABUF
        ld bc,480
        call hicopy
        ld bc,000Ch             ; rows 0-11 once
        jp blit_attr_rows

floor_frame:
        call wait_vbl
        ld bc,0C0Dh             ; rows 12-24
        call blit_attr_rows
        ; camera: forward, swaying sideways
        ld hl,(mtick)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *16
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl               ; *64
        add hl,de               ; *80: 0.3 depth units per tick (8.8)
        ld (fl_cz),hl
        ld a,(mtick)
        call sin_a
        ld l,a
        ld h,0
        bit 7,a
        jr z,.p
        dec h
.p:     add hl,hl
        add hl,hl
        add hl,hl               ; +-1016 = +-4 tiles
        ld (fl_cx),hl
        ld ix,ABUF+12*40
        xor a
.cell:  ld (fl_r),a
        push ix
        add a,a
        ld d,FLT/256
        ld e,0
        ld c,0F0h
        call fl_row
        ld a,(fl_r)
        add a,a
        inc a
        ld d,FLB/256
        ld e,0
        ld c,0Fh
        call fl_row
        pop ix
        ld hl,FLT
        ld b,40
.cb:    ld a,(hl)
        inc h
        or (hl)
        dec h
        ld (ix+0),a
        inc ix
        inc l
        djnz .cb
        ld a,(fl_r)
        inc a
        cp 13
        jr c,.cell
        ret

; A = floor row (0-25), DE = buffer, C = nibble mask
fl_row: ld (fl_mask),bc
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld de,fl_rows
        add hl,de               ; (step lo, step hi, z, colours)
        add hl,hl               ; 4 bytes per row
        or a
        sbc hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = step per pixel (8.8)
        inc hl
        ld a,(hl)               ; depth
        inc hl
        ld c,(hl)               ; colours: hi nibble = tile A, lo = tile B
        push bc
        ; v parity = ((z + camera z/256 ...)) / 16 & 1, as 0 or 1
        ld hl,(fl_cz)
        add a,h
        rrca
        rrca
        rrca
        rrca
        and 1
        ld (fl_v),a
        ; u at x = 0: camera - 20 * step
        ld hl,(fl_cx)
        ld b,20
.s:     or a
        sbc hl,de
        djnz .s
        pop bc
        ld a,c
        and 0F0h
        ld b,a                  ; tile A (hi)
        ld a,c
        and 0Fh
        rlca
        rlca
        rlca
        rlca
        ld c,a                  ; tile B (hi)
        ld a,(fl_mask)
        cp 0Fh
        jr nz,.hi
        ; bottom halves want the low nibble
        ld a,b
        rrca
        rrca
        rrca
        rrca
        ld b,a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        ld c,a
.hi:    exx
        pop de                  ; buffer
        exx
        ld a,(fl_v)
        ld (.v+1),a
        ld a,40
        ld (fl_n),a
.px:    add hl,de
        ld a,h
.v:     xor 0
        rra
        ld a,b
        jr nc,.w
        ld a,c
.w:     exx
        ld (de),a
        inc e
        exx
        ld a,(fl_n)
        dec a
        ld (fl_n),a
        jr nz,.px
        ret

fl_cz:   dw 0
fl_cx:   dw 0
fl_r:    db 0
fl_v:    db 0
fl_n:    db 0
fl_mask: dw 0
