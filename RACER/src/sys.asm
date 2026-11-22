; =====================================================================
;  sys.asm - hardware set-up, tick pacing, keyboard, random, maths
; =====================================================================

init_hw:
        ld a,74h                ; counter 1: LSB/MSB, mode 2, count 65536:
        ld (CTRL),a             ; it counts scan lines, for pacing
        xor a
        ld (CTR1),a
        ld (CTR1),a
        ld (SNDGATE),a
        ret

; E002h bit 7 = /VBLK; measure which level is the short (blanking) one
detect_vblank:
        ld hl,PPIC
        xor a
        ld (polx),a
        ld a,(hl)
        and 80h
        ld b,a
.e0:    ld a,(hl)
        and 80h
        cp b
        jr z,.e0
        ld b,a
        ld de,0
.m1:    inc de
        ld a,(hl)
        and 80h
        cp b
        jr z,.m1
        ld c,a
        push de
        ld de,0
.m2:    inc de
        ld a,(hl)
        and 80h
        cp c
        jr z,.m2
        pop hl
        or a
        sbc hl,de
        ld a,b
        jr c,.bshort
        ld a,c
.bshort:
        ld (polx),a             ; xor with this -> bit 7 = 0 in VBLANK
        ret

; HL = 8253 counter 1 (latched; it counts scan lines downwards)
read_ctr1:
        ld a,40h
        ld (CTRL),a
        ld a,(CTR1)
        ld l,a
        ld a,(CTR1)
        ld h,a
        ret

; HL = lines since this tick was due
lines_since:
        call read_ctr1
        ex de,hl
        ld hl,(duectr)
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------------
; wait_frame: at least 2 PAL fields after the last frame, then the start
; of a vertical blank.  A = fields since the last frame (1..4): the game
; steps its world that many times, so it keeps time when drawing is slow.
FIELDL  equ 312
wait_frame:
        ld a,(turbo)
        or a
        jr nz,.turbo
.w:     call snd_clock
        call snd_poll
        call joy_fire
        call lines_since
        ld bc,2*FIELDL-40
        or a
        sbc hl,bc
        jr c,.w
        call wait_vb
        call lines_since
        call read_ctr1
        ld (duectr),hl
        call snd_clock
        ld bc,FIELDL/2          ; fields = (lines + 156) / 312
        add hl,bc
        ld a,0
        ld bc,FIELDL
.f:     or a
        sbc hl,bc
        jr c,.fd
        inc a
        jr .f
.fd:    cp 5
        jr c,.ok
        ld a,4
.ok:    or a
        jr nz,.ok2
        inc a
.ok2:   ld (dt),a
        ld hl,(drops)           ; frames that took more than 2 fields
        cp 3
        jr c,.nd
        inc hl
        ld (drops),hl
.nd:    ld a,1
        ld (synced),a
        ld a,(dt)
        ret
.turbo: call snd_clock          ; (tests: no waiting, 2 fields a frame)
        ld a,2
        ld (dt),a
        ret

; wait for the start of a vertical blank (sound ticking meanwhile)
wait_vb:
.d:     call snd_poll           ; while in the blank, wait for the display
        ld a,(PPIC)
        ld hl,polx
        xor (hl)
        rla
        jr nc,.d
.b:     call snd_poll           ; then for the blank (a tight loop, so
        ld a,(PPIC)             ; the tick is stamped right at the edge)
        ld hl,polx
        xor (hl)
        rla
        jr c,.b
        ret

; wait A fields (front-end pages)
wait_fields:
        push af
        call wait_vb
        pop af
        dec a
        jr nz,wait_fields
        call read_ctr1
        ld (duectr),hl
        ret

; ---------------------------------------------------------------------
; keyboard.  Rows E000h = F0h + row, columns E001h active low.
;  row 0: b0 CR     row 1: b6 Z           row 2: b7 Q b5 S b1 W b0 X
;  row 3: b7 I b6 J b5 K b4 L b3 M        row 4: b7 A b6 B b4 D
;  row 6: b4 SPACE  row 7: b5 up b4 down b3 right b2 left
read_keys:
        ld hl,kbuf
        ld de,kprev
        ld bc,10
        ldir
        ld hl,kbuf
        ld b,0F0h
.scan:  ld a,b
        ld (KROW),a
        nop
        nop
        ld a,(KCOL)
        cpl
        ld (hl),a
        inc hl
        inc b
        ld a,b
        cp 0FAh
        jr nz,.scan

        ld c,0
        ld a,(kbuf+7)           ; cursor keys
        bit 5,a
        jr z,.c1
        set 0,c
.c1:    bit 4,a
        jr z,.c2
        set 1,c
.c2:    bit 2,a
        jr z,.c3
        set 2,c
.c3:    bit 3,a
        jr z,.c4
        set 3,c
.c4:    ld a,(kbuf+2)           ; W S
        bit 1,a
        jr z,.w1
        set 0,c
.w1:    bit 5,a
        jr z,.w2
        set 1,c
.w2:    bit 0,a                 ; X = bomb
        jr z,.w3
        set 5,c
.w3:    ld a,(kbuf+4)           ; A D B
        bit 7,a
        jr z,.w4
        set 2,c
.w4:    bit 4,a
        jr z,.w5
        set 3,c
.w5:    bit 6,a
        jr z,.w6
        set 5,c
.w6:    ld a,(kbuf+6)           ; SPACE fires
        bit 4,a
        jr z,.w7
        set 4,c
.w7:    ld a,(kbuf+3)           ; K fires, L bombs
        bit 5,a
        jr z,.w8
        set 4,c
.w8:    bit 4,a
        jr z,.w9
        set 5,c
.w9:    ld a,(kbuf+1)           ; Z fires
        bit 6,a
        jr z,.w10
        set 4,c
.w10:   call joy_keys           ; the joystick adds to C
        ld a,c
        call cancel_opp
        ld (keys),a

        ld c,0                  ; specials
        ld a,(kbuf+6)
        bit 4,a
        jr z,.s1
        set 0,c                 ; SPACE
.s1:    ld a,(kbuf+0)
        bit 0,a
        jr z,.s2
        set 1,c                 ; CR
.s2:    ld a,(kbuf+2)
        bit 7,a
        jr z,.s3
        set 2,c                 ; Q
.s3:    ld a,(kbuf+3)
        bit 3,a
        jr z,.s4
        set 3,c                 ; M
.s4:    bit 6,a
        jr z,.s5
        set 5,c                 ; J
.s5:    ld a,(kbuf+4)
        bit 6,a
        jr z,.s6
        set 4,c                 ; B
.s6:    ld a,(joyfire)          ; a joystick button = SPACE
        or a
        jr z,.s7
        set 0,c
.s7:    ld a,(skeys)
        cpl
        and c
        ld (sedge),a
        ld a,c
        ld (skeys),a
        ret

; drop both of a pair of opposite directions
cancel_opp:
        ld b,a
        and 03h
        cp 03h
        jr nz,.h
        ld a,b
        and 0FCh
        ld b,a
.h:     ld a,b
        and 0Ch
        cp 0Ch
        ld a,b
        ret nz
        and 0F3h
        ret

; A = the letter key newly pressed (ASCII), 8 for DEL, or 0
get_letter:
        ld a,(kbuf+7)           ; DEL: row 7 bit 6
        ld hl,kprev+7
        cpl
        or (hl)
        cpl
        bit 6,a
        ld a,8
        ret nz
        ld hl,kbuf+1
        ld de,kprev+1
        ld ix,lettab
        ld c,4
.r:     ld a,(de)
        cpl
        and (hl)
        jr nz,.hit
        inc hl
        inc de
        push bc
        ld bc,8
        add ix,bc
        pop bc
        dec c
        jr nz,.r
        xor a
        ret
.hit:   ld b,a
.f:     sla b
        jr c,.got
        inc ix
        jr .f
.got:   ld a,(ix+0)
        ret

lettab: db "YZ",0,0,0,0,0,0
        db "QRSTUVWX"
        db "IJKLMNOP"
        db "ABCDEFGH"

; any key at all held? (NZ = yes)
any_key:
        ld hl,kbuf
        ld b,10
        xor a
.a:     or (hl)
        inc hl
        djnz .a
        or a
        ret

; ---------------------------------------------------------------------
; HL = xorshift16 random number (also in seed)
rand:
        ld hl,(seed)
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
        ld (seed),hl
        ret

; A = random byte (BC, DE, HL preserved)
rand8:
        push hl
        call rand
        ld a,h
        xor l
        pop hl
        ret

; A = n (1..255) -> A = random 0..n-1 (BC, DE, HL preserved)
rand_n:
        push bc
        push de
        push hl
        ld e,a
        call rand8
        ld h,a
        ld l,0
        ld d,0
        ld b,8
.m:     add hl,hl
        jr nc,.s
        add hl,de
.s:     djnz .m
        ld a,h
        pop hl
        pop de
        pop bc
        ret

; ---------------------------------------------------------------------
; scoring.  The score is 3 BCD bytes (low first) of tens: it shows with
; a fixed 0 at the end.  DE = BCD tens to add.
add_score:
        ld a,(demo)
        or a
        ret nz
add_score_d:
        ld a,1
        ld (hudscore),a
        ld hl,score
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ret nc
        ld a,99h                ; (clamp at the top)
        ld (hl),a
        dec hl
        ld (hl),a
        dec hl
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; multiplies
; HL signed x A unsigned -> HL = (HL * A) >> 8 (signed).  Keeps DE.
mul_hs:
        ld c,a
        bit 7,h
        jr z,mul_huc
        call neg_hl
        call mul_huc
neg_hl: xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret
; HL unsigned (< 8000h) x A -> HL = (HL * A) >> 8.  Keeps DE.
mul_hu:
        ld c,a
mul_huc:
        call mul_fuc
        ld l,h
        ld h,a
        ret

; HL signed x A unsigned -> AHL = HL * A (24-bit signed).  Keeps DE.
mul_full:
        ld c,a
        bit 7,h
        jr z,mul_fuc
        call neg_hl
        call mul_fuc
        ld c,a                  ; negate AHL
        xor a
        sub l
        ld l,a
        ld a,0
        sbc a,h
        ld h,a
        ld a,0
        sbc a,c
        ret
; HL unsigned x C -> AHL.  Keeps DE.  (Squares for 8 x 8, else
; unrolled shift and add.)
mul_fuc:
        ld a,h
        or a
        jr nz,.big
        push de
        call mul88
        pop de
        xor a
        ret
.big:   push de
        ex de,hl
        ld hl,0
        xor a
        add hl,hl
        rla
        sla c
        jr nc,.n0
        add hl,de
        adc a,0
.n0:
        add hl,hl
        rla
        sla c
        jr nc,.n1
        add hl,de
        adc a,0
.n1:
        add hl,hl
        rla
        sla c
        jr nc,.n2
        add hl,de
        adc a,0
.n2:
        add hl,hl
        rla
        sla c
        jr nc,.n3
        add hl,de
        adc a,0
.n3:
        add hl,hl
        rla
        sla c
        jr nc,.n4
        add hl,de
        adc a,0
.n4:
        add hl,hl
        rla
        sla c
        jr nc,.n5
        add hl,de
        adc a,0
.n5:
        add hl,hl
        rla
        sla c
        jr nc,.n6
        add hl,de
        adc a,0
.n6:
        add hl,hl
        rla
        sla c
        jr nc,.n7
        add hl,de
        adc a,0
.n7:
        pop de
        ret

; L x C -> HL (unsigned bytes): (a+b)^2/4 - (a-b)^2/4 from SQL/SQH.
; Uses A, B, E.
mul88:
        ld a,l
        sub c
        jr nc,.p
        neg
.p:     ld e,a                  ; |a - b|
        ld a,l
        add a,c
        ld l,a
        ld a,high SQL
        adc a,0
        ld h,a                  ; &SQL[a + b]
        ld b,(hl)
        inc h
        inc h
        ld a,(hl)               ; A:B = (a+b)^2/4
        ld l,e
        ld h,high SQL
        ld e,a
        ld a,b
        sub (hl)
        ld b,a
        inc h
        inc h
        ld a,e
        sbc a,(hl)
        ld h,a
        ld l,b
        ret

; build EDT: 8 pages, EDT[f][o] = (o + 4 + f) >> 3
edt_init:
        ld hl,EDT
        ld c,4                  ; 4 + f
.p:     ld b,0
.o:     ld a,b
        add a,c
        rra                     ; (9 bits: carry in)
        srl a
        srl a
        ld (hl),a
        inc hl
        inc b
        jr nz,.o
        inc c
        ld a,c
        cp 12
        jr nz,.p
        ret

; build SQL/SQH: n*n/4 for n = 0..511 (low bytes, then high bytes)
sq_init:
        ld hl,0                 ; n^2/4 by differences
        ld de,SQL
        ld bc,0                 ; n
.l:     ld a,l
        ld (de),a
        inc d
        inc d
        ld a,h
        ld (de),a
        dec d
        dec d
        inc de
        ; next: (n+1)^2/4 - n^2/4 = n/2 rounded: (n+1)>>1 ... exact:
        ; floor((n+1)^2/4) - floor(n^2/4) = floor((n+1)/2)
        inc bc
        push bc
        srl b
        rr c
        add hl,bc
        pop bc
        ld a,b
        cp 2
        jr c,.l
        ret

; E signed x A (0..15) -> A = E * A / 16 (signed, towards zero).
; Keeps BC, DE, HL.
smul_frac16:
        or a
        ret z
        push bc
        push de
        push hl
        ld b,a
        ld a,e
        ld c,0
        or a
        jp p,.p
        neg
        inc c
.p:     ld e,a
        ld d,0
        ld hl,0
.l:     add hl,de
        djnz .l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        dec c
        jr nz,.r
        neg
.r:     pop hl
        pop de
        pop bc
        ret
