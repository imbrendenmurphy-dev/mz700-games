; ---------------------------------------------------------------------------
; fx_stars.asm - 3D starfield in 80x50 (dotted quarter blocks).
; Each star: x, y (signed), z (16-255).  Screen = 40/25 + x*PR[z]/64.
; Near stars are 2x2 dots and white; far ones single dots in blue.
; ---------------------------------------------------------------------------

NSTARS3 equ 72

stars_init:
        call cls_black
        ld hl,st_cap
        ld de,VCHR+24*40
        ld a,50h
        call print_at
        ld ix,st_data
        ld b,NSTARS3
.s:     call st_new
        call rand               ; spread the first ones in depth
        or 16
        ld (ix+2),a
        ld (ix+3),0FFh          ; no old cell
        ld de,5
        add ix,de
        djnz .s
        ret

st_new: call rand
        ld (ix+0),a
        call rand
        ld (ix+1),a
        ld (ix+2),255
        ret

stars_frame:
        call wait_vbl
        ; erase every old cell
        ld ix,st_data
        ld b,NSTARS3
.e:     ld a,(ix+3)
        cp 0FFh
        jr z,.en
        ld l,(ix+4)
        ld h,a
        ld (hl),0
.en:    ld de,5
        add ix,de
        djnz .e
        ; speed swells and falls
        ld a,(mtick)
        call sin_a
        sra a
        sra a
        sra a
        sra a
        add a,10                ; 2..17
        ld (st_speed),a
        ; move, project, draw
        ld ix,st_data
        ld b,NSTARS3
.m:     push bc
        ld (ix+3),0FFh
        ld a,(st_speed)
        ld c,a
        ld a,(ix+2)
        sub c
        jr c,.re
        cp 16
        jr nc,.ok
.re:    call st_new
        jp .next
.ok:    ld (ix+2),a
        ld l,a
        ld h,0
        ld de,st_pr
        add hl,de
        ld e,(hl)               ; PR[z]
        ld a,(ix+0)
        call muls16             ; x * PR
        call st_div64
        add a,40
        cp 80
        jr nc,.next
        ld (st_px),a
        ld a,(ix+2)
        ld l,a
        ld h,0
        ld de,st_pr
        add hl,de
        ld e,(hl)
        ld a,(ix+1)
        sra a                   ; y range is smaller
        call muls16
        call st_div64
        add a,25
        cp 48                   ; keep the caption row
        jr nc,.next
        ; cell
        ld c,a
        srl a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld a,(st_px)
        ld b,a
        srl a
        ld e,a
        ld d,0
        add hl,de
        ld de,VCHR
        add hl,de
        ld (ix+3),h
        ld (ix+4),l
        ; glyph: near = 4 dots, else the one quarter
        ld a,(ix+2)
        cp 56
        ld a,0FFh
        jr c,.g
        ld a,c
        and 1
        add a,a
        ld e,a
        ld a,b
        and 1
        or e
        ld e,a
        ld d,0
        push hl
        ld hl,st_quad
        add hl,de
        ld a,(hl)
        pop hl
.g:     ld (hl),a
        set 3,h
        ld a,(ix+2)
        rlca
        rlca
        rlca
        and 7
        ld e,a
        ld d,0
        push hl
        ld hl,st_col
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
.next:  ld de,5
        add ix,de
        pop bc
        dec b
        jp nz,.m
        ret

st_div64:                       ; HL / 64 -> A; far off screen -> 7Fh
        ld a,h
        add a,10
        cp 20
        jr nc,.off
        add hl,hl
        add hl,hl
        ld a,h
        ret
.off:   ld a,7Fh
        ret

st_quad:  db 0F1h, 0F2h, 0F4h, 0F8h
st_col:   db 70h, 70h, 70h, 50h, 50h, 50h, 10h, 10h

st_speed: db 0
st_px:    db 0
st_data:  ds NSTARS3*5          ; x, y, z, old cell hi, lo
