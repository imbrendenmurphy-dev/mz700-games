; HWTEST - MZ700onPC hardware timing test, for a real MZ-700 (no add-ons needed).
; Run it on the real machine and in MZ700onPC; the screen shows four measured numbers next to what the
; emulator predicts. Matching numbers = the emulator's timing is right for that machine.
;  1 CPU LOOPS PER FIELD   a 35 T loop counted from one VBLANK to the next: CPU clock x field length
;  2 VRAM WRITES PER FIELD blocks of back-to-back writes to unused VRAM: how wide the VRAM free window is,
;                          and whether it is open all through VBLANK. The closest model gets a < mark.
;  3 HBLANK PULSES         E008 bit 7 falling edges counted from the /VBLK fall (311 on a real MZ-700: see E_EDGES)
;  4 HBLANK LOW PERCENT    the share of the line E008 bit 7 reads low (CSP: 99.2 of 227.2 T = 44%)
; Interrupts are off; the test repeats forever, so the numbers should hold steady.
        org 1200h
        jp start
r_loops: dw 0                   ; 1203
r_vram:  dw 0                   ; 1205 writes per field
r_edges: dw 0                   ; 1207
r_pct:   dw 0                   ; 1209
r_low:   dw 0                   ; 120B
r_tot:   dw 0                   ; 120D

; what MZ700onPC measures, per model (filled in from the emulator)
E_LOOPS equ 2025
E_ACC   equ 2992
E_CONS  equ 2496
E_DISP  equ 4672
E_OFF   equ 7712
E_EDGES equ 311                 ; 312 lines, but /VBLK falls as line 199's pulse starts, so the count misses one
E_PCT   equ 44

WHITE   equ 70h
YELLOW  equ 60h
CYAN    equ 50h
GREEN   equ 40h
RED     equ 20h
GREY    equ 70h

start:  di
        ld sp, 10F0h
        call cls
        ld hl, statics
        call prtall
        call expected
main:   call t_loops
        ld (r_loops), de
        call t_vram
        ex de, hl
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        ld (r_vram), hl
        call t_hb
        call show
        jr main

; ---------------------------------------------------------------- measurements
sync:   ld a, (0E002h)          ; wait for the picture (/VBLK high) ...
        rla
        jr nc, sync
.v:     ld a, (0E002h)          ; ... then for VBLANK to start
        rla
        jr c, .v
        ret

t_loops:
        call sync
        ld de, 0
.a:     inc de                  ; 6
        ld a, (0E002h)          ; 13
        rla                     ; 4
        jr nc, .a               ; 12  (35 T)
.b:     inc de
        ld a, (0E002h)
        rla
        jr c, .b
        ret

t_vram: call sync
        ld de, 0
        ld hl, 0D3F0h           ; VRAM past the 1000 visible cells
.a:     inc de
        dup 16
        ld (hl), a
        edup
        ld a, (0E002h)
        rla
        jr nc, .a
.b:     inc de
        dup 16
        ld (hl), a
        edup
        ld a, (0E002h)
        rla
        jr c, .b
        ret

; IX = E008 bit 7 falling edges from one VBLANK start to the next
t_hb:   call sync
        ld ix, 0
.a:     call edge
        ld a, (0E002h)
        rla
        jr nc, .a
.b:     call edge
        ld a, (0E002h)
        rla
        jr c, .b
        dec ix                  ; the count ends on the next field's first edge
        ld (r_edges), ix
        ; the share of time bit 7 reads low: a branch-free sampler, about 109 T a sample
        call sync
        ld hl, 0                ; samples high
        ld de, 0                ; samples
.s1:    call smp
        ld a, (0E002h)
        rla
        jr nc, .s1
.s2:    call smp
        ld a, (0E002h)
        rla
        jr c, .s2
        ex de, hl               ; HL = samples, DE = high
        push hl
        or a
        sbc hl, de              ; HL = low
        pop de
        ld (r_low), hl
        ld (r_tot), de
        ; percent = low * 100 / total
        push de
        add hl, hl              ; x4
        add hl, hl
        ld b, h
        ld c, l
        add hl, hl              ; x32
        add hl, hl
        add hl, hl
        push hl
        add hl, hl              ; x64
        pop de
        add hl, de              ; x96
        add hl, bc              ; x100
        pop de
        ld bc, 0
.d:     or a
        sbc hl, de
        jr c, .dd
        inc bc
        jr .d
.dd:    add hl, de              ; the remainder
        add hl, hl              ; round: remainder*2 >= total
        or a
        sbc hl, de
        jr c, .dr
        inc bc
.dr:    ld (r_pct), bc
        ret

; wait for one high-to-low change of E008 bit 7 (IX + 1), giving up after about 10000 T
edge:   ld b, 0
.h:     ld a, (0E008h)
        rla
        jr c, .lo
        djnz .h
        ret
.lo:    ld b, 0
.l:     ld a, (0E008h)
        rla
        jr nc, .got
        djnz .l
        ret
.got:   inc ix
        ret

smp:    ld a, (0E008h)
        rlca
        and 1
        add a, l
        ld l, a
        ld a, h
        adc a, 0
        ld h, a
        inc de
        ret

; ---------------------------------------------------------------- results
show:   ld hl, (r_loops)
        ld de, 0D000h + 3 * 40 + 30
        ld c, YELLOW
        call num
        call verdict_loops

        ld hl, (r_vram)
        ld de, 0D000h + 7 * 40 + 30
        ld c, YELLOW
        call num
        call closest

        ld hl, (r_edges)
        ld de, 0D000h + 15 * 40 + 30
        ld c, YELLOW
        call num
        ld hl, (r_edges)
        ld de, E_EDGES
        or a
        sbc hl, de
        ld de, 0D000h + 15 * 40 + 37
        call okmark

        ld hl, (r_pct)
        ld de, 0D000h + 18 * 40 + 30
        ld c, YELLOW
        call num
        ld hl, (r_pct)
        ld de, -E_PCT
        add hl, de              ; within 1 either way is fine
        inc hl
        ld a, h
        or a
        jr nz, .bad
        ld a, l
        cp 3
        jr nc, .bad
        ld hl, 0
        jr .pk
.bad:   ld hl, 1
.pk:    ld de, 0D000h + 18 * 40 + 37
        jp okmark

; loops: OK when within 3 of E_LOOPS
verdict_loops:
        ld hl, (r_loops)
        ld de, -E_LOOPS
        add hl, de
        inc hl
        inc hl
        inc hl
        ld a, h
        or a
        jr nz, .bad
        ld a, l
        cp 7
        jr nc, .bad
        ld hl, 0
        jr .k
.bad:   ld hl, 1
.k:     ld de, 0D000h + 3 * 40 + 37
; HL = 0 -> green OK, else red NO, at DE
okmark: ld a, h
        or l
        ld hl, t_ok
        ld c, GREEN
        jr z, .p
        ld hl, t_no
        ld c, RED
.p:     jp print

; mark the VRAM model nearest to r_vram with '<' (rows 9-12, column 36)
closest:
        ld ix, models
        ld b, 4
        ld iy, 0FFFFh           ; best difference
        ld a, 0
        ld (best), a
.l:     ld e, (ix + 0)
        ld d, (ix + 1)
        ld hl, (r_vram)
        or a
        sbc hl, de
        jr nc, .p
        ex de, hl               ; negate
        ld hl, 0
        or a
        sbc hl, de
.p:     push hl
        push iy
        pop de
        or a
        sbc hl, de
        pop hl
        jr nc, .n
        push hl
        pop iy
        ld a, 4
        sub b
        ld (best), a
.n:     inc ix
        inc ix
        djnz .l
        ld b, 0
.m:     ld a, b
        ld hl, 0D000h + 9 * 40 + 37
        ld de, 40
        or a
        jr z, .r
.s:     add hl, de
        dec a
        jr nz, .s
.r:     ex de, hl
        ld a, (best)
        cp b
        ld hl, t_mark
        ld c, GREEN
        jr z, .w
        ld hl, t_nomark
.w:     push bc
        call print
        pop bc
        inc b
        ld a, b
        cp 4
        jr nz, .m
        ret

best:   db 0
models: dw E_ACC, E_CONS, E_DISP, E_OFF

; ---------------------------------------------------------------- text
; num: HL = value, DE = VRAM, C = attr; 5 digits, leading spaces
num:    push de
        ld ix, digits
        ld bc, -10000
        call .dig
        ld bc, -1000
        call .dig
        ld bc, -100
        call .dig
        ld bc, -10
        call .dig
        ld a, l
        ld (ix + 0), a
        pop de
        ld hl, digits
        ld b, 5
        ld c, 1                 ; 1 while still in the leading zeros
.o:     ld a, (hl)
        or a
        jr nz, .dg
        ld a, b
        cp 1
        jr z, .zero             ; always show the last digit
        ld a, c
        or a
        jr z, .zero
        xor a                   ; a leading zero: space
        jr .put
.zero:  xor a
.dg:    ld c, 0
        add a, 20h              ; display code digit
.put:   ld (de), a
        set 3, d
        ld a, YELLOW
        ld (de), a
        res 3, d
        inc de
        inc hl
        djnz .o
        ret
.dig:   xor a
.dl:    add hl, bc
        inc a
        jr c, .dl
        dec a
        sbc hl, bc              ; carry is clear here
        ld (ix + 0), a
        inc ix
        ret
digits: ds 5

cls:    ld hl, 0D000h
        ld de, 0D001h
        ld bc, 999
        ld (hl), 0
        ldir
        ld hl, 0D800h
        ld de, 0D801h
        ld bc, 999
        ld (hl), WHITE
        ldir
        ret

; print: HL = ASCII string (0-terminated), DE = VRAM, C = attr
print:  ld a, (hl)
        inc hl
        or a
        ret z
        call atod
        ld (de), a
        set 3, d
        ld a, c
        ld (de), a
        res 3, d
        inc de
        jr print

atod:   cp 'A'
        jr c, .nl
        cp 'Z' + 1
        jr nc, .nl
        sub 40h
        ret
.nl:    cp '0'
        jr c, .p
        cp '9' + 1
        jr nc, .p
        add a, 20h - '0'
        ret
.p:     cp '-'
        jr nz, $+5
        ld a, 2Ah
        ret
        cp '.'
        jr nz, $+5
        ld a, 2Eh
        ret
        cp '/'
        jr nz, $+5
        ld a, 2Dh
        ret
        cp '<'
        jr nz, $+5
        ld a, 51h
        ret
        cp '='
        jr nz, $+5
        ld a, 2Bh
        ret
        cp ','
        jr nz, $+5
        ld a, 2Fh
        ret
        xor a
        ret

; prtall: list of (row, col, attr, string) until row FFh
prtall: ld a, (hl)
        cp 0FFh
        ret z
        inc hl
        push hl
        ld l, a                 ; row * 40
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl
        ld d, h
        ld e, l
        add hl, hl
        add hl, hl
        add hl, de
        ld de, 0D000h
        add hl, de
        ex de, hl
        pop hl
        ld a, (hl)
        inc hl
        add a, e
        ld e, a
        jr nc, $+3
        inc d
        ld c, (hl)
        inc hl
        call print
        jr prtall

t_ok:     db "OK", 0
t_no:     db "NO", 0
t_mark:   db "<", 0
t_nomark: db " ", 0

ROWNUM  macro rr_, cc_, at_
        db rr_, cc_, at_
        endm

statics:
        ROWNUM 0, 1, CYAN
        db "MZ700ONPC HARDWARE TIMING TEST", 0
        ROWNUM 1, 1, GREY
        db "----------------------------------", 0
        ROWNUM 3, 1, WHITE
        db "1 CPU LOOPS PER FIELD", 0
        ROWNUM 4, 3, GREY
        db "EMULATOR SAYS", 0
        ROWNUM 7, 1, WHITE
        db "2 VRAM WRITES PER FIELD", 0
        ROWNUM 8, 3, GREY
        db "EMULATOR SAYS, BY MODEL", 0
        ROWNUM 9, 3, GREY
        db "ACCURATE  T128-208", 0
        ROWNUM 10, 3, GREY
        db "CONSERVATIVE  T128-191", 0
        ROWNUM 11, 3, GREY
        db "PICTURE LINES ONLY", 0
        ROWNUM 12, 3, GREY
        db "NO WAITS", 0
        ROWNUM 15, 1, WHITE
        db "3 HBLANK PULSES PER FIELD", 0
        ROWNUM 16, 3, GREY
        db "EMULATOR SAYS", 0
        ROWNUM 18, 1, WHITE
        db "4 HBLANK LOW PERCENT", 0
        ROWNUM 19, 3, GREY
        db "EMULATOR SAYS", 0
        ROWNUM 22, 1, CYAN
        db "YELLOW = THIS MACHINE.  OK = MATCHES.", 0
        ROWNUM 23, 1, CYAN
        db "< = CLOSEST VRAM MODEL.", 0
        ROWNUM 24, 1, GREY
        db "PLEASE PHOTOGRAPH THIS SCREEN.", 0
        db 0FFh

        ; the emulator's numbers, printed once by expected
expected:
        ld hl, E_LOOPS
        ld de, 0D000h + 4 * 40 + 30
        call numg
        ld hl, E_ACC
        ld de, 0D000h + 9 * 40 + 30
        call numg
        ld hl, E_CONS
        ld de, 0D000h + 10 * 40 + 30
        call numg
        ld hl, E_DISP
        ld de, 0D000h + 11 * 40 + 30
        call numg
        ld hl, E_OFF
        ld de, 0D000h + 12 * 40 + 30
        call numg
        ld hl, E_EDGES
        ld de, 0D000h + 16 * 40 + 30
        call numg
        ld hl, E_PCT
        ld de, 0D000h + 19 * 40 + 30
numg:   push de
        call num
        pop de                  ; recolour grey-white
        ld b, 5
        set 3, d
.c:     ld a, WHITE
        ld (de), a
        inc de
        djnz .c
        ret
