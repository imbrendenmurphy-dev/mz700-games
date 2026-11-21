; =====================================================================
;  math.asm - fixed-point helpers
; =====================================================================

; ---------------------------------------------------------------------
; mul8s: HL = B * C (signed 8 x 8), quarter-square tables.
; Keeps BC.  Clobbers A, DE.
; ---------------------------------------------------------------------
mul8s:
        ld a,b
        xor 80h
        ld d,a                      ; a' = a + 128
        ld a,c
        xor 80h
        ld e,a                      ; b' = b + 128
        add a,d                     ; a' + b' = (a+b) + 256
        ld l,a
        ld a,high QSQLO
        adc a,0
        ld h,a
        ld a,e
        cpl
        scf
        adc a,d                     ; a' - b' + 256 = (a-b) + 256
        ld e,a
        ld a,high QSQLO
        adc a,0
        ld d,a
        push bc
        ld c,(hl)
        inc h
        inc h
        ld b,(hl)                   ; BC = f(a+b)
        ld a,(de)
        inc d
        inc d
        ld l,a
        ld a,(de)
        ld h,a                      ; HL = f(a-b)
        ld a,c
        sub l
        ld l,a
        ld a,b
        sbc a,h
        ld h,a
        pop bc
        ret

; ---------------------------------------------------------------------
; HL = |HL| ; neg_hl: HL = -HL
; ---------------------------------------------------------------------
abs_hl:
        bit 7,h
        ret z
neg_hl:
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; ---------------------------------------------------------------------
; div16u: HL = HL / DE (unsigned, DE < 8000h).  Clobbers A, BC.
; ---------------------------------------------------------------------
div16u:
        ld a,d                      ; quotient < 256?  (H < DE)
        or a
        jr nz,.fast
        ld a,h
        cp e
        jr c,.fast
        ld a,h
        ld c,l
        ld hl,0
        ld b,16
.l:     sla c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,.s
        add hl,de
        djnz .l
        jr .x
.s:     inc c
        djnz .l
.x:     ld h,a
        ld l,c
        ret
.fast:  ld a,l                      ; 8 steps, unrolled: remainder starts as H
        ld l,h
        ld h,0
        REPT 8
        add a,a
        adc hl,hl
        sbc hl,de
        jr nc,$+5
        add hl,de
        jr $+3
        inc a
        ENDR
        ld l,a
        ld h,0
        ret

; ---------------------------------------------------------------------
; mul16u: DEHL = BC * DE (unsigned)
; ---------------------------------------------------------------------
mul16u:
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
        ret

; ---------------------------------------------------------------------
; div32: HL = DEHL / BC (unsigned); 7FFFh if the quotient would not fit
; ---------------------------------------------------------------------
div32:
        ex de,hl
        or a
        sbc hl,bc
        add hl,bc
        ex de,hl
        jr nc,.ovf                  ; DE >= BC: too big
        ld a,16
.l:     add hl,hl
        rl e
        rl d
        jr c,.big
        ex de,hl
        or a
        sbc hl,bc
        jr nc,.ok
        add hl,bc
        ex de,hl
        jr .n
.ok:    ex de,hl
        inc l
        jr .n
.big:   ex de,hl
        or a
        sbc hl,bc
        ex de,hl
        inc l
.n:     dec a
        jr nz,.l
        bit 7,h
        ret z
.ovf:   ld hl,7FFFh
        ret

; ---------------------------------------------------------------------
; muldiv: HL = BC * DE / (md_c), all signed 16-bit, quotient clamped
; to +-7FFFh.
; ---------------------------------------------------------------------
muldiv:
        ld a,b
        xor d
        ld (md_sign),a
        ld a,b
        or a
        jp p,.a
        xor a
        sub c
        ld c,a
        sbc a,a
        sub b
        ld b,a
.a:     bit 7,d
        jr z,.b
        ex de,hl
        call neg_hl
        ex de,hl
.b:     call mul16u                 ; DEHL = |a| * |b|
        push hl
        ld hl,(md_c)
        ld a,(md_sign)
        xor h
        ld (md_sign),a
        call abs_hl
        ld b,h
        ld c,l
        pop hl
        ld a,b
        or c
        jr nz,.d
        ld hl,7FFFh
        jr .s
.d:     call div32
.s:     ld a,(md_sign)
        or a
        ret p
        jp neg_hl

; ---------------------------------------------------------------------
; asr_bc: BC >>= A (arithmetic, A >= 1, rounded)
; ---------------------------------------------------------------------
asr_bc:
        cp 8
        jr c,.s
        ld c,b
        ld b,0
        bit 7,c
        jr z,$+4
        ld b,0FFh
        sub 8
        ret z
.s:     sra b
        rr c
        dec a
        jr nz,.s
        ret nc
        inc bc
        ret

; ---------------------------------------------------------------------
; rot_pair: small-angle rotation of two signed words, a = 2^-k,
; cos a ~ 1 - 2^-(2k+1):
;     P' = P - P>>(2k+1) - Q>>k
;     Q' = Q - Q>>(2k+1) + P>>k
; HL -> P, DE -> Q ; (rot_k), (rot_k2) = k, 2k+1.  Keeps IX, IY.
; ---------------------------------------------------------------------
rot_pair:
        push hl
        push de
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (rp),bc
        ex de,hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (rq),bc
        ld a,(rot_k2)               ; P' = P - P>>k2 - Q>>k
        ld bc,(rp)
        call asr_bc
        ld hl,(rp)
        or a
        sbc hl,bc
        push hl
        ld a,(rot_k)
        ld bc,(rq)
        call asr_bc
        pop hl
        or a
        sbc hl,bc
        ld (rnp),hl
        ld a,(rot_k2)               ; Q' = Q - Q>>k2 + P>>k
        ld bc,(rq)
        call asr_bc
        ld hl,(rq)
        or a
        sbc hl,bc
        push hl
        ld a,(rot_k)
        ld bc,(rp)
        call asr_bc
        pop hl
        add hl,bc
        ex de,hl
        pop hl                      ; -> Q
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl                      ; -> P
        ld de,(rnp)
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; A = k: set rot_k / rot_k2
set_rot:
        ld (rot_k),a
        add a,a
        inc a
        ld (rot_k2),a
        ret

; ---------------------------------------------------------------------
; vec_to_bytes: (vx,vy,vz) words at HL -> bytes (dbx,dby,dbz) scaled
; down by the same power of two until each fits in -100..100.
; Returns A = shift count used.
; ---------------------------------------------------------------------
vec_to_bytes:
        ld de,tvec
        ld bc,6
        ldir
        ld b,0                      ; shift count
.chk:   ld hl,(tvec)
        call .fits
        jr nc,.sh
        ld hl,(tvec+2)
        call .fits
        jr nc,.sh
        ld hl,(tvec+4)
        call .fits
        jr nc,.sh
        ld a,(tvec)
        ld (dbx),a
        ld a,(tvec+2)
        ld (dby),a
        ld a,(tvec+4)
        ld (dbz),a
        ld a,b
        ret
.sh:    inc b
        ld hl,tvec
        ld c,3
.s1:    inc hl
        sra (hl)
        dec hl
        rr (hl)
        inc hl
        inc hl
        dec c
        jr nz,.s1
        jr .chk
; C set if -100 <= HL <= 100
.fits:  push bc
        ld bc,100
        add hl,bc                   ; 0..200 if it fits
        ld a,h
        or a
        jr nz,.no
        ld a,l
        cp 201
        pop bc
        ret
.no:    pop bc
        or a
        ret

; ---------------------------------------------------------------------
; dot3: HL = dbx*v.x + dby*v.y + dbz*v.z, where IY -> vector of 3 words
; (high bytes used, unit 64).  Keeps IX, IY.
; ---------------------------------------------------------------------
dot3:
        ld a,(dbx)
        ld b,a
        ld c,(iy+1)
        call mul8s
        push hl
        ld a,(dby)
        ld b,a
        ld c,(iy+3)
        call mul8s
        push hl
        ld a,(dbz)
        ld b,a
        ld c,(iy+5)
        call mul8s
        pop de
        add hl,de
        pop de
        add hl,de
        ret
