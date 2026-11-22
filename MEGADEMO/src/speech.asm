; ---------------------------------------------------------------------------
; speech.asm - 1-bit sampled speech.  Each bit sets the speaker by writing an
; 8253 control word for counter 0: mode 0 (20h) drives OUT0 low at once,
; mode 4 (28h) high.  One bit every ~227 T = 15.6 kHz.  The sample lives in
; high RAM and is copied to WORK first (the I/O page must stay switched in
; while playing).  Music stops while it talks; interrupts are off.
; ---------------------------------------------------------------------------

speak:  ld hl,hi_speech
        ld de,WORK
        ld bc,SPEECH_LEN
        call hicopy
        di
        ld a,1
        ld (0E008h),a           ; gate on
        ld hl,WORK
        ld de,SPEECH_LEN
.byte:  ld a,(hl)
        inc hl
        DUP 8
        rlca
        ld c,a
        and 1
        rlca
        rlca
        rlca
        or 20h                  ; 20h or 28h
        ld (0E007h),a
        ld a,c
        ld b,13
        djnz $
        EDUP
        dec de
        ld a,d
        or e
        jp nz,.byte
        ; back to music: counter 0 as a square wave, next note re-programmed
        ld a,36h
        ld (0E007h),a
        xor a
        ld (mus_last),a
        ld (0E008h),a
        ld a,2                  ; re-arm counter 2, drop the stale tick
        ld (0E006h),a
        xor a
        ld (0E006h),a
        ei
        ret
