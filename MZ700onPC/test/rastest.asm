; MZ700onPC pixel-timing test (needs the MZ-1500 PCG option for its palette: --pcg 1500 / "pcg 1500").
; The whole screen is background colour 0. After VBLANK the program switches palette entry 0 between blue and
; red with back-to-back OUT (C),r - one every 12 T. A pixel is 0.4 T (2 master clocks), so on a pixel-exact
; emulator every colour boundary is exactly 30 pixels after the last one, part-way along the lines, and the
; 227.2 T line makes the stripes lean. A line-at-a-time renderer shows whole lines of one colour instead.
        org 1200h
start:  di
        ld hl, 0D000h           ; codes 0 (space), attributes 00 (black on black)
        ld de, 0D001h
        ld bc, 999
        ld (hl), 0
        ldir
        ld hl, 0D800h
        ld de, 0D801h
        ld bc, 999
        ld (hl), 0
        ldir
        ld a, 1                 ; MZ-1500 PCG display on (the palette applies with it)
        out (0F0h), a
        ld c, 0F1h
        ld d, 01h               ; palette 0 -> blue
        ld e, 02h               ; palette 0 -> red
        ld h, 00h               ; palette 0 -> black

frame:  ld a, (0E002h)          ; wait for VBLANK to start
        rla
        jr nc, frame
vb:     ld a, (0E002h)
        rla
        jr c, vb
        ld b, 0                 ; wait out VBLANK and some picture lines: about 29000 T
dl:     ex (sp), hl
        ex (sp), hl
        ex (sp), hl
        ex (sp), hl
        ex (sp), hl
        ex (sp), hl
        djnz dl
        dup 500
        out (c), d
        out (c), e
        edup
        out (c), h
        jp frame
