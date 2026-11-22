; =====================================================================
;  tables.asm - the road's lookup tables, built at start-up in the RAM
;  under the monitor ROM (0000h-0FFFh; OUT (0E0h) pages it in)
; =====================================================================

HWT     equ 0000h       ; scale -> road half width (1/8 cells): s * 5 / 8
LWT     equ 0100h       ; hw -> lane line half width (0 = none)
O1T     equ 0200h       ; hw -> hw + rumble width
LPT     equ 0300h       ; hw -> lane offset + line half width
LMT     equ 0400h       ; hw -> lane offset - line half width
CLMP    equ 0500h       ; signed byte -> 0..40
QT      equ 0600h       ; rows -> 256 / rows
STRM    equ 0700h       ; segment ahead -> sampling mask
SCLS    equ 0800h       ; scale -> sprite size
RECIP   equ 0900h       ; z (0..NSAMP*16+8) -> 6000 / z, at most 255

make_tables:
        out (0E0h),a            ; RAM at 0000h-0FFFh
        ; HWT
        ld hl,HWT
        ld b,0
.hw:    ld a,b                  ; (s * 5) >> 3
        ld e,a
        ld d,0
        push hl
        ld l,e
        ld h,d
        add hl,hl
        add hl,hl
        add hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        pop hl
        ld (hl),a
        inc l
        inc b
        jr nz,.hw
        ; per hw: lane line, rumble, lane offsets
        ld b,0
.lw:    ld a,b                  ; line: hw / 24 when hw >= 40
        ld c,0
        cp 40
        jr c,.l1
        ld e,24
        call div8
        ld c,a
.l1:    ld h,high LWT
        ld l,b
        ld (hl),c
        ld a,b                  ; rumble: hw + hw/6 + 1 (at most 255)
        ld e,6
        call div8
        inc a
        add a,b
        jr nc,.l2
        ld a,255
.l2:    ld h,high O1T
        ld (hl),a
        ld a,b                  ; lane: hw / 3 +- line
        ld e,3
        call div8
        ld d,a
        add a,c
        jr nc,.l3
        ld a,255
.l3:    ld h,high LPT
        ld (hl),a
        ld a,d
        sub c
        ld h,high LMT
        ld (hl),a
        inc b
        jr nz,.lw
        ; CLMP
        ld hl,CLMP
.cl:    ld a,l
        or a
        jp m,.c0
        cp 41
        jr c,.c1
        ld a,40
        jr .c1
.c0:    xor a
.c1:    ld (hl),a
        inc l
        jr nz,.cl
        ; QT
        ld hl,QT
        ld (hl),255
        inc l
        ld (hl),255
        inc l
.q:     push hl                 ; 256 / r
        ld e,l
        ld hl,256
        call div16
        ld a,l
        pop hl
        ld (hl),a
        inc l
        jr nz,.q
        ; STRM: 0 below 8, 1 below 16, 3 below 32, then 7
        ld hl,STRM
.st:    ld a,l
        ld c,0
        cp 8
        jr c,.s1
        inc c
        cp 16
        jr c,.s1
        ld c,3
        cp 32
        jr c,.s1
        ld c,7
.s1:    ld (hl),c
        inc l
        jr nz,.st
        ; SCLS: the number of size steps at or below s
        ld hl,SCLS
.sc:    ld de,SIZESTEP
        ld c,0
.s2:    ld a,(de)
        or a
        jr z,.s3
        cp l
        jr z,.s4
        jr nc,.s3
.s4:    inc c
        inc de
        jr .s2
.s3:    ld (hl),c
        inc l
        jr nz,.sc
        ; RECIP: 6000 / z
        ld hl,RECIP
        ld (hl),255
        inc hl
        ld bc,1
.r:     push hl
        push bc
        ld hl,6000
        ld e,c
        ld d,b
        call div16w
        ld a,h
        or a
        ld a,l
        jr z,.r1
        ld a,255
.r1:    pop bc
        pop hl
        ld (hl),a
        inc hl
        inc bc
        ld a,c
        cp low (NSAMP*16+8)
        jr nz,.r
        ld a,b
        cp high (NSAMP*16+8)
        jr nz,.r
        ret

; A / E -> A (unsigned, by subtraction)
div8:
        push bc
        ld c,0
.d:     sub e
        jr c,.e
        inc c
        jr .d
.e:     ld a,c
        pop bc
        ret

; HL / E -> HL
div16:
        ld d,0
; HL / DE -> HL
div16w:
        push bc
        ld bc,0
.d:     or a
        sbc hl,de
        jr c,.e
        inc bc
        jr .d
.e:     ld h,b
        ld l,c
        pop bc
        ret
