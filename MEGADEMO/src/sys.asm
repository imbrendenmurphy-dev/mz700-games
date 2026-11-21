; ---------------------------------------------------------------------------
; sys.asm - frame sync, buffer blits, screen fills, text, random numbers
; ---------------------------------------------------------------------------

; Wait for the start of VBLANK (E002 bit 7 falls).  Counts frames.
wait_vbl:
        ld a,(0E002h)
        rla
        jr nc,wait_vbl          ; still in VBLANK: wait for the picture
.w2:    ld a,(0E002h)
        rla
        jr c,.w2
        ld hl,(fcount)
        inc hl
        ld (fcount),hl
        ret

fcount: dw 0

; ---------------------------------------------------------------- row blits
; Copy rows of a back buffer (40 bytes per row) to VRAM with unrolled
; pop hl / ld (nn),hl - about 6 bytes per scan line under the VRAM waits.
; B = first row, C = row count.  Interrupts stay on: the handler only puts
; its return address below SP, i.e. into bytes already copied.
blit_attr_rows:
        ld hl,bt_attr
        jr blit_rows
blit_char_rows:
        ld hl,bt_char
blit_rows:
        ld (bl_sp),sp
        ld a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        push hl
        pop iy
        ld ix,.ret
.lp:    ld l,(iy+0)
        ld h,(iy+1)
        ld sp,hl
        ld l,(iy+2)
        ld h,(iy+3)
        jp (hl)
.ret:   ld de,4
        add iy,de
        dec c
        jr nz,.lp
        ld sp,(bl_sp)
        ret
bl_sp:  dw 0

blit_attr:                      ; whole attribute buffer
        ld bc,0019h
        jr blit_attr_rows
blit_char:
        ld bc,0019h
        jr blit_char_rows

bt_attr:
.r = 0
        DUP 25
        dw ABUF + .r*40, ba_code + .r*82
.r = .r + 1
        EDUP
bt_char:
.r = 0
        DUP 25
        dw CBUF + .r*40, bc_code + .r*82
.r = .r + 1
        EDUP

ba_code:
.r = 0
        DUP 25
.c = 0
        DUP 20
        pop hl
        ld (VATR + .r*40 + .c),hl
.c = .c + 2
        EDUP
        jp (ix)
.r = .r + 1
        EDUP
bc_code:
.r = 0
        DUP 25
.c = 0
        DUP 20
        pop hl
        ld (VCHR + .r*40 + .c),hl
.c = .c + 2
        EDUP
        jp (ix)
.r = .r + 1
        EDUP

; ---------------------------------------------------------------- fills
; fill a 1000-byte buffer at HL with A
fill_buf:
        ld (hl),a
        ld d,h
        ld e,l
        inc de
        ld bc,999
        ldir
        ret

; whole screen: char A, attr C (through the buffers)
fill_screen:
        push bc
        ld hl,CBUF
        call fill_buf
        pop bc
        ld a,c
        ld hl,ABUF
        call fill_buf
        call blit_char
        jp blit_attr

cls_black:
        xor a
        ld c,70h
        jr fill_screen

; ---------------------------------------------------------------- text
; HL = string (display codes, FFh ends), DE = VRAM char address, A = attr
print_at:
        ld c,a
.lp:    ld a,(hl)
        cp 0FFh
        ret z
        ld (de),a
        set 3,d                 ; D000 -> D800
        ld a,c
        ld (de),a
        res 3,d
        inc hl
        inc de
        jr .lp

; same into the buffers: DE = offset 0..999
print_buf:
        ld c,a
.lp:    ld a,(hl)
        cp 0FFh
        ret z
        push hl
        ld hl,CBUF
        add hl,de
        ld (hl),a
        ld hl,ABUF
        add hl,de
        ld (hl),c
        pop hl
        inc hl
        inc de
        jr .lp

; ---------------------------------------------------------------- maths
; xorshift16 -> HL and A (= L). Keeps BC, DE.
rand:   ld hl,(rseed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rseed),hl
        ld a,l
        ret
rseed:  dw 1234h

; A = angle -> A = sin * 127 (signed).  Keeps everything else.
sin_a:  push hl
        ld h,SINE/256
        ld l,a
        ld a,(hl)
        pop hl
        ret
cos_a:  add a,64
        jr sin_a

; HL-free 16-bit version: signed A * signed E -> HL = a*e (signed 16)
muls16: push bc
        push de
        ld c,a
        ; |a|, |e|, sign
        xor e
        ld b,a                  ; bit 7 = result sign
        ld a,c
        or a
        jp p,.p1
        neg
.p1:    ld c,a
        ld a,e
        or a
        jp p,.p2
        neg
.p2:    ; unsigned C * A via quarter squares: (c+a)^2/4 - (c-a)^2/4
        ld e,a
        add a,c                 ; c+a, up to 254 (no carry: both <= 127)
        ld l,a
        ld h,QSQ/256
        ld a,(hl)
        inc h
        ld d,(hl)               ; d:a = q(c+a)
        push af
        ld a,c
        sub e
        jr nc,.p3
        neg
.p3:    ld l,a
        dec h
        pop af
        sub (hl)
        ld e,a
        inc h
        ld a,d
        sbc a,(hl)
        ld h,a
        ld l,e                  ; HL = c*a
        bit 7,b
        jr z,.p4
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.p4:    pop de
        pop bc
        ret

; A (signed) * E (signed) / 128 -> A
mul8:   call muls16
        add hl,hl
        ld a,h
        ret
