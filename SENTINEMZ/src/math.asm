; =====================================================================
;  math.asm - multiply / divide helpers and the island generator RNG
; =====================================================================

; HL = A * C, unsigned, A + C <= 255 (quarter squares: Q(a+c) - Q(|a-c|))
mul8u:
        push bc
        push de
        ld b,a
        add a,c
        ld l,a                      ; a + c
        ld a,b
        sub c
        jr nc,.p
        neg
.p:     ld e,a                      ; |a - c|
        ld h,high QLO
        ld d,h
        ld a,(de)
        ld c,a
        ld a,(hl)
        sub c
        ld c,a
        inc h
        inc d
        ld a,(de)
        ld b,a
        ld a,(hl)
        sbc a,b
        ld h,a
        ld l,c
        pop de
        pop bc
        ret

; DEHL = HL * DE (unsigned 16 x 16 -> 32)
mul16u:
        push bc
        ld b,h
        ld c,l                      ; BC = multiplicand
        ld hl,0
        ld a,16
.l:     add hl,hl
        rl e
        rl d
        jr nc,.n
        add hl,bc
        jr nc,.n
        inc de
.n:     dec a
        jr nz,.l
        pop bc
        ret

; DEHL = HL * DE signed
muls16:
        ld a,h
        xor d
        push af                     ; sign of the result in bit 7
        bit 7,h
        call nz,neg_hl
        ex de,hl
        bit 7,h
        call nz,neg_hl
        call mul16u
        pop af
        rla
        ret nc
; negate DEHL
neg32:
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        ld a,e
        cpl
        ld e,a
        ld a,d
        cpl
        ld d,a
        inc l
        ret nz
        inc h
        ret nz
        inc de
        ret

neg_hl:
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

neg_de:
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        ret

; HL = HL / DE unsigned, DE kept, BC = remainder
div16u:
        push de
        ld a,h
        ld c,l
        ld hl,0
        ld b,16
.l:     sla c
        rla
        adc hl,hl
        sbc hl,de                   ; (carry clear: DE < 8000h)
        jr nc,.ok
        add hl,de
        jr .nx
.ok:    inc c
.nx:    djnz .l
        ld b,h
        ld h,a
        ld a,c
        ld c,l
        ld l,a
        pop de
        ret

; HL = HL / C unsigned (C > 0), A = remainder
div16u8:
        xor a
        ld b,16
.l:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .l
        ret

; HL = (A * DE) >> 8, A signed byte, DE signed word
muls8x16:
        push bc
        push de
        ld b,a
        xor d
        ld c,a                      ; sign of the result in bit 7
        bit 7,d
        call nz,neg_de
        ld a,b
        bit 7,a
        jr z,.p1
        neg
.p1:
        ; A (0..128) * DE (0..32768) -> 24 bit in A:H:L? use mul16u
        ld l,a
        ld h,0
        call mul16u                 ; DEHL
        ld l,h
        ld h,e                      ; >> 8
        bit 7,c
        call nz,neg_hl
        pop de
        pop bc
        ret

; ---------------------------------------------------------------------
; xorshift 7,9,8 (deterministic: islands are the same every time)
; A = next value (low byte); keeps everything but AF
rng:
        push hl
        ld hl,(rseed)
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
        pop hl
        ret
