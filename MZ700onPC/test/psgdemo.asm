; MZ700onPC MZ-1500 PSG demo: a C - Am - F - G loop on both chips.
; Left chip: the chord (three tones). Right chip: bass, a plucked top note and a noise hi-hat.
; Tone register N = 3579545 / (32 * Hz). Needs the PSG fitted (Machine menu, --psg 1, or "psg on").
        org 1200h
start:  di
        ld hl, 0D000h           ; clear the screen
        ld de, 0D001h
        ld bc, 999
        ld (hl), 0
        ldir
        ld hl, 0D800h           ; white on blue
        ld de, 0D801h
        ld bc, 999
        ld (hl), 71h
        ldir
        ld hl, t1
        ld de, 0D000h + 40 * 10 + 12
        call puts
        ld hl, t2
        ld de, 0D000h + 40 * 12 + 11
        call puts
        ld hl, t3
        ld de, 0D000h + 40 * 14 + 10
        call puts

        ld a, 0E4h              ; right noise: white, N/512
        out (0F3h), a
        ld a, 0FFh              ; noise on the left chip off
        out (0F2h), a
        xor a
        ld (chord), a
        ld (tick), a

loop:   call vbl
        ld a, (tick)
        or a
        call z, newchord
        ld a, (tick)            ; top note: pluck, 1 step quieter every 2 fields
        srl a
        cp 15
        jr c, tp
        ld a, 15
tp:     or 0B0h                 ; right tone 2 (the top note) attenuation
        out (0F3h), a
        ld a, (tick)            ; hi-hat every 6 fields
nh:     cp 6
        jr c, hh
        sub 6
        jr nh
hh:     add a, a
        add a, 3
        cp 15
        jr c, hs
        ld a, 15
hs:     or 0F0h
        out (0F3h), a
        ld a, (tick)
        inc a
        cp 24
        jr c, st
        xor a
st:     ld (tick), a
        jr loop

newchord:
        ld a, (chord)
        ld l, a
        ld h, 0
        add hl, hl              ; x10 bytes
        ld d, h
        ld e, l
        add hl, hl
        add hl, hl
        add hl, de
        ld de, chords
        add hl, de
        ld c, 0F2h              ; left: tones 0, 1, 2
        ld b, 0
        call tone
        ld b, 1
        call tone
        ld b, 2
        call tone
        ld c, 0F3h              ; right: bass on tone 0, top on tone 1
        ld b, 0
        call tone
        ld b, 1
        call tone
        ld a, 92h               ; volumes: left chord, right bass
        out (0F2h), a
        ld a, 0B2h
        out (0F2h), a
        ld a, 0D2h
        out (0F2h), a
        ld a, 91h
        out (0F3h), a
        ld a, (chord)
        inc a
        and 3
        ld (chord), a
        ret

tone:   ; B = voice, C = port, HL -> period word; HL += 2
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ld a, b
        rrca
        rrca
        rrca                    ; voice << 5
        and 60h
        or 80h
        ld b, a
        ld a, e
        and 0Fh
        or b
        out (c), a
        ld a, e                 ; upper 6 bits: N >> 4
        srl d
        rra
        srl d
        rra
        srl d
        rra
        srl d
        rra
        and 3Fh
        out (c), a
        ret

vbl:    ld a, (0E002h)          ; wait for the start of VBLANK
        rla
        jr nc, vbl
vb2:    ld a, (0E002h)
        rla
        jr c, vb2
        ret

puts:   ld a, (hl)              ; ASCII to display code
        or a
        ret z
        cp 'A'
        jr c, pd
        sub 40h
        jr pp
pd:     cp '0'
        jr c, ps
        sub '0' - 20h
        jr pp
ps:     cp '-'
        ld a, 2Ah
        jr z, pp
        xor a
pp:     ld (de), a
        inc hl
        inc de
        jr puts

t1:     db "MZ-1500 PSG", 0
t2:     db "TWO SN76489 CHIPS", 0
t3:     db "C  AM  F  G  ON 6 VOICES", 0

;               L: chord three notes   R: bass, top
chords: dw 428, 339, 285,  855, 170     ; C:  C4 E4 G4   C3   E5
        dw 508, 428, 339, 1017, 214     ; Am: A3 C4 E4   A2   C5
        dw 320, 254, 214,  641, 254     ; F:  F4 A4 C5   F3   A4
        dw 453, 381, 285,  571, 226     ; G:  B3 D4 G4   G3   B4
chord:  db 0
tick:   db 0
