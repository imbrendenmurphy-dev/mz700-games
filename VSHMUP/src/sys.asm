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
; wait for the next tick: 2 PAL fields (25 ticks a second), starting at
; a vertical blank.  A tick that ran late doesn't wait: the next one
; starts at once and catches up (more than 2 ticks behind, it resyncs).
; Sound keeps ticking from the scan-line clock all the while.
TICKL   equ 624
wait_tick:
        ld a,(turbo)
        or a
        jr nz,.turbo
        call lines_since
        ld bc,TICKL
        or a
        sbc hl,bc
        jr c,.ontime
        ld bc,2*TICKL
        sbc hl,bc
        jr nc,.resync
        ld hl,(duectr)          ; catch up: due one tick after the last
        ld bc,-TICKL
        add hl,bc
        ld (duectr),hl
        ld hl,(drops)
        inc hl
        ld (drops),hl
        xor a
        ld (synced),a
        jp snd_clock
.ontime:
.w:     call snd_clock          ; until 24 lines before the next blank
        call snd_poll
        call joy_fire           ; (in the picture: the stick's buttons)
        call lines_since
        ld bc,TICKL-24
        or a
        sbc hl,bc
        jr c,.w
.resync:
        call wait_vb
        call read_ctr1
        ld (duectr),hl
        ld a,1
        ld (synced),a
        jp snd_clock
.turbo: call snd_clock          ; (tests: no waiting at all)
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
; direction from (dx = B, dy = C), signed cells (|d| < 64) -> A = 0..31
; (0 = right, 8 = down, 16 = left, 24 = up)
atan32:
        ld a,b
        or c
        jr nz,.go
        ld a,8                  ; on top of it: straight down
        ret
.go:    ld a,b
        bit 7,a
        jr z,.ax
        neg
.ax:    ld d,a                  ; D = |dx|
        ld a,c
        bit 7,a
        jr z,.ay
        neg
.ay:    ld e,a                  ; E = |dy|
        ld a,d
        cp e
        jr c,.steep
        ld h,e                  ; k from |dy|*16/|dx|
        ld l,d
        call .k
        jr .quad
.steep: ld h,d                  ; k from |dx|*16/|dy|, base 8-k
        ld l,e
        call .k
        neg
        add a,8
.quad:  ld e,a                  ; E = angle within the quadrant (0..8)
        bit 7,b
        jr nz,.left
        bit 7,c
        ld a,e
        ret z                   ; right, down
        neg                     ; right, up: 32-a
        and 31
        ret
.left:  ld a,16
        bit 7,c
        jr nz,.lu
        sub e                   ; left, down: 16-a
        ret
.lu:    add a,e                 ; left, up: 16+a
        and 31
        ret
; H = small, L = big (big > 0) -> A = 0..4 (round(4*atan(small/big)/45))
.k:     push bc
        ld a,h                  ; q = small*16 / big
        ld c,l
        ld h,0
        ld l,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,0
.dv:    or a
        sbc hl,bc
        jr c,.dd
        inc b
        jr .dv
.dd:    ld a,b                  ; thresholds 2, 5, 9, 13
        ld c,0
        cp 2
        jr c,.kk
        inc c
        cp 5
        jr c,.kk
        inc c
        cp 9
        jr c,.kk
        inc c
        cp 13
        jr c,.kk
        inc c
.kk:    ld a,c
        pop bc
        ret

; A = direction 0..31, E = speed (0..127, 1/256 cell per tick)
; -> B = vx, C = vy (signed 1/256 cell per tick)
dir_vel:
        push hl
        push de
        ld d,a
        call .look              ; cos
        call smul
        ld b,a
        ld a,d
        sub 8                   ; sin(t) = cos(t - 90 degrees)
        and 31
        call .look
        call smul
        ld c,a
        pop de
        pop hl
        ret
.look:  ld hl,costab
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ret

; A = signed value (-127..127), E = 0..127 -> A = A*E/128 (signed)
; (BC, DE, HL preserved)
smul:
        push hl
        push bc
        push de
        ld c,0
        bit 7,a
        jr z,.p
        neg
        inc c
.p:     ld h,a
        ld l,0
        ld d,0
        ld b,8
        ld a,h
        ld h,0
.m:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .m
        add hl,hl               ; /128
        ld a,h
        dec c
        jr nz,.r
        neg
.r:     pop de
        pop bc
        pop hl
        ret

; cos(k * 11.25 degrees) * 127, k = 0..31
costab:
        db 127,125,117,106,90,71,49,25,0,-25,-49,-71,-90,-106,-117,-125
        db -127,-125,-117,-106,-90,-71,-49,-25,0,25,49,71,90,106,117,125

; ---------------------------------------------------------------------
; scoring.  The score is 3 BCD bytes (low first) of tens: it shows with
; a fixed 0 at the end.  DE = BCD tens to add.
add_score:
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
        jr nc,.ok
        ld a,99h                ; (clamp at the top)
        ld (hl),a
        dec hl
        ld (hl),a
        dec hl
        ld (hl),a
.ok:    ld a,1
        ld (hudscore),a
        ; an extra ship at 50,000 and every 100,000 (score >= next)
        ld hl,score+2
        ld a,(nextext+1)
        cp (hl)
        jr c,.ext
        ret nz
        dec hl
        ld a,(nextext)
        cp (hl)
        jr z,.ext
        ret nc
.ext:   ld a,(nextext+1)        ; next += 100,000 (= 10000h tens BCD)
        add a,1
        daa
        ld (nextext+1),a
        jp extra_ship
