; ======================================================================
;  sound.asm - one-voice sound effects / jingles (data in build/gen_sfx.inc)
; ======================================================================

init_hw:
    ld a,36h            ; counter 0: LSB/MSB, mode 3 (square wave)
    ld (CTRL),a
    ld a,74h            ; counter 1: LSB/MSB, mode 2, free-running /65536
    ld (CTRL),a
    xor a
    ld (CTR1),a
    ld (CTR1),a
    ld (SNDGATE),a
    ret

; HL = sound, A = priority. Replaces the current sound unless it has
; a higher priority.
play_sfx:
    ld b,a
    ld a,(sndptr)
    ld c,a
    ld a,(sndptr+1)
    or c
    jr z,.go
    ld a,(sndpri)
    ld c,a
    ld a,b
    cp c
    ret c
.go:
    ld (sndptr),hl
    ld a,b
    ld (sndpri),a
    ret

snd_tick:
    include "sndtick.inc"
    ret

; while turning with nothing else playing: gritty hiss
spin_hiss:
    ld hl,(sndptr)
    ld a,h
    or l
    ret nz
    ld a,(keys)
    and K_LEFT+K_RIGHT
    jr z,.off
    call rand           ; random divisor 1024-2047 (540-1080 Hz)
    ld a,h
    and 3
    or 4
    ld h,a
    ld a,l
    ld (CTR0),a
    ld a,h
    ld (CTR0),a
    ld a,1
    ld (SNDGATE),a
    ret
.off:
    xor a
    ld (SNDGATE),a
    ret

rand:                   ; HL = xorshift16
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
