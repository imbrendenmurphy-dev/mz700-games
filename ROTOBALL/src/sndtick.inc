; One sound tick: play the next word of the current sound (see tools/sfx.py).
; Uses A, DE, HL only and no stack, so the renderer can run it inline.
    ld hl,(sndptr)
    ld a,h
    or l
    jr z,.st_end
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld a,d
    or e
    jr nz,.st_play
    ld (sndptr),de      ; end of sound: DE = 0, A = 0
    ld (SNDGATE),a
    ld (sndpri),a
    jr .st_end
.st_play:
    ld (sndptr),hl
    ld a,d
    cp 0FEh
    jr c,.st_note
    jr nz,.st_noise
    xor a               ; FE00h: rest
    ld (SNDGATE),a
    jr .st_end
.st_noise:              ; FFxxh: noise, divisor xx*256 + random
    ld d,e
    ld a,r
    ld e,a
.st_note:
    ld a,e
    ld (CTR0),a
    ld a,d
    ld (CTR0),a
    ld a,1
    ld (SNDGATE),a
.st_end:
