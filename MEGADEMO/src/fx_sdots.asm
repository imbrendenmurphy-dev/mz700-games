; ---------------------------------------------------------------------------
; fx_sdots.asm - sine dots: 96 dots on Lissajous curves in 80x50.
; dot i: x = 40 + sin(i*k1 + t*2)/4 + sin(i*k2 - t)/16
;        y = 25 + sin(i*k3 + t)/8   + sin(i*k4 + t*3)/16
; The k's change every bar, so the figure keeps changing.
; Mask buffer in CBUF, colours in ABUF; only touched cells reach VRAM.
; ---------------------------------------------------------------------------

NSD     equ 80

sdots_init:
        call cls_black
        ld hl,CBUF
        xor a
        call fill_buf
        xor a
        ld (sd_nold),a
        ld hl,sd_cap
        ld de,VCHR+24*40
        ld a,50h
        jp print_at

sdots_frame:
        call wait_vbl
        ; erase last frame's cells (mask)
        ld a,(sd_nold)
        or a
        jr z,.e0
        ld b,a
        ld hl,sd_old
.e:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,CBUF
        add hl,de
        ld (hl),0
        pop hl
        djnz .e
.e0:    ; this bar's figure
        ld a,(mus_pos)
        and 3
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,sd_ks
        add hl,de
        ld de,sd_k
        ld bc,4
        ldir
        ; angle accumulators at i = 0
        ld a,(mtick)
        ld c,a
        add a,a
        ld (sd_a1),a
        xor a
        sub c
        ld (sd_a2),a
        ld a,c
        ld (sd_a3),a
        add a,a
        add a,c
        ld (sd_a4),a
        ld hl,sd_new
        ld (sd_np),hl
        xor a
        ld (sd_nnew),a
        ld (sd_i),a
.dot:   ; x
        ld a,(sd_a1)
        call sin_a
        sra a
        sra a
        ld c,a
        ld a,(sd_a2)
        call sin_a
        sra a
        sra a
        sra a
        sra a
        add a,c
        add a,40
        cp 80
        jp nc,.skip
        ld (sd_x),a
        ; y
        ld a,(sd_a3)
        call sin_a
        sra a
        sra a
        sra a
        ld c,a
        ld a,(sd_a4)
        call sin_a
        sra a
        sra a
        sra a
        sra a
        add a,c
        add a,25
        cp 48
        jr nc,.skip
        ; cell and bit
        ld c,a
        srl a
        call mul40
        ld a,(sd_x)
        ld b,a
        srl a
        ld e,a
        ld d,0
        add hl,de
        ex de,hl                ; DE = cell
        ld a,c
        and 1
        add a,a
        ld c,a
        ld a,b
        and 1
        or c
        ld c,a
        ld b,0
        ld hl,sd_bit
        add hl,bc
        ld a,(hl)
        ld hl,CBUF
        add hl,de
        or (hl)
        ld (hl),a
        ld a,(sd_i)             ; colour by dot number
        rrca
        rrca
        rrca
        rrca
        and 7
        ld c,a
        ld b,0
        ld hl,sd_col
        add hl,bc
        ld a,(hl)
        ld hl,ABUF
        add hl,de
        ld (hl),a
        ld hl,(sd_np)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (sd_np),hl
        ld hl,sd_nnew
        inc (hl)
.skip:  ; next dot: angles step by k
        ld hl,sd_a1
        ld de,sd_k
        ld b,4
.st:    ld a,(de)
        add a,(hl)
        ld (hl),a
        inc hl
        inc de
        djnz .st
        ld hl,sd_i
        inc (hl)
        ld a,(hl)
        cp NSD
        jp c,.dot
        ; present old + new
        ld a,(sd_nold)
        ld hl,sd_old
        call .list
        ld a,(sd_nnew)
        ld hl,sd_new
        call .list
        ld hl,sd_new
        ld de,sd_old
        ld bc,NSD*2
        ldir
        ld a,(sd_nnew)
        ld (sd_nold),a
        ret
.list:  or a
        ret z
        ld b,a
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,CBUF
        add hl,de
        ld a,(hl)
        or a
        jr z,.z
        or 0F0h
.z:     ld hl,VCHR
        add hl,de
        ld (hl),a
        ld hl,ABUF
        add hl,de
        ld a,(hl)
        ld hl,VATR
        add hl,de
        ld (hl),a
        pop hl
        djnz .l
        ret

sd_ks:  db 3, 7, 5, 2,   2, 5, 3, 9,   5, 3, 2, 7,   7, 2, 3, 3
sd_bit: db 1, 2, 4, 8
sd_col: db 70h, 50h, 10h, 30h, 20h, 60h, 40h, 50h

sd_k:    ds 4
sd_a1:   db 0
sd_a2:   db 0
sd_a3:   db 0
sd_a4:   db 0
sd_x:    db 0
sd_i:    db 0
sd_nold: db 0
sd_nnew: db 0
sd_np:   dw 0
sd_old:  ds NSD*2
sd_new:  ds NSD*2
