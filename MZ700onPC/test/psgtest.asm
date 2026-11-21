; MZ700onPC MZ-1500 PSG test: 1 s of A4 (440 Hz) on the left chip (OUT F2), then 1 s of E5 (659 Hz) on the right
; chip (OUT F3), then 1 s of white noise on both (OUT E9), then silence. Tone register N = 3579545 / (32 * Hz).
        org 1200h
start:  di
        ld a, 9Fh               ; silence all voices on both chips
        out (0E9h), a
        ld a, 0BFh
        out (0E9h), a
        ld a, 0DFh
        out (0E9h), a
        ld a, 0FFh
        out (0E9h), a

        ld a, 80h | (254 & 15)  ; left tone 1 = 254 (440.4 Hz)
        out (0F2h), a
        ld a, 254 >> 4
        out (0F2h), a
        ld a, 90h               ; volume max
        out (0F2h), a
        call second
        ld a, 9Fh
        out (0F2h), a

        ld a, 80h | (170 & 15)  ; right tone 1 = 170 (658.0 Hz)
        out (0F3h), a
        ld a, 170 >> 4
        out (0F3h), a
        ld a, 90h
        out (0F3h), a
        call second
        ld a, 9Fh
        out (0F3h), a

        ld a, 0E4h              ; white noise, N/512
        out (0E9h), a
        ld a, 0F0h
        out (0E9h), a
        call second
        ld a, 0FFh
        out (0E9h), a
        ld a, 1
        ld (3000h), a
done:   jr done

second: ld bc, 50               ; ~1 s: 50 fields of /VBLK
sec1:   ld a, (0E002h)
        rla
        jr c, sec1              ; wait for VBLANK
sec2:   ld a, (0E002h)
        rla
        jr nc, sec2
        dec bc
        ld a, b
        or c
        jr nz, sec1
        ret
