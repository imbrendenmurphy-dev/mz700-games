; =====================================================================
;  sound.asm - one-voice effects on 8253 counter 0, stepped every tick
;
;  A sound is a list of notes: db ticks, dw divisor (tone = 1108800 /
;  divisor Hz; 0 = rest).  ticks + 80h = noise: a random divisor from
;  divisor to divisor+2047 every tick.  db 0 ends the sound.
; =====================================================================

init_hw:
        ld a,36h                ; counter 0: LSB/MSB, mode 3 (square wave)
        ld (CTRL),a
        xor a
        ld (SNDGATE),a
        ret

; HL = sound, A = priority.  Interrupts a lower or equal priority sound.
play_sfx:
        ld b,a
        ld a,(sndon)
        or a
        ret z
        ld a,(sndptr+1)
        or a
        jr z,.go
        ld a,(sndpri)
        cp b
        jr z,.go
        ret nc
.go:    ld (sndptr),hl
        ld a,b
        ld (sndpri),a
        xor a
        ld (sndleft),a
        ret

snd_off:
        ld hl,0
        ld (sndptr),hl
        xor a
        ld (sndleft),a
        ld (sndpri),a
        ld (SNDGATE),a
        ret

snd_tick:
        ld hl,(sndptr)
        ld a,h
        or a
        jr z,.quiet
        ld a,(sndleft)
        or a
        jr nz,.run
        ld a,(hl)               ; next note
        or a
        jr z,snd_off
        inc hl
        ld (sndmode),a
        and 7Fh
        ld (sndleft),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sndptr),hl
        ld (snddiv),de
.run:   ld hl,sndleft
        dec (hl)
        ld de,(snddiv)
        ld a,d
        or e
        jr z,.quiet
        ld a,(sndmode)
        rla
        jr nc,.out
        push de
        call rand
        pop de
        ld a,h
        and 07h
        ld h,a
        add hl,de
        ex de,hl
.out:   ld a,e
        ld (CTR0),a
        ld a,d
        ld (CTR0),a
        ld a,1
        ld (SNDGATE),a
        ret
.quiet: xor a
        ld (SNDGATE),a
        ret

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

; A = random byte (BC, DE preserved)
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
; effects (priority in brackets where they are played)
NOTE    MACRO hz, ticks
        db ticks
        dw 1108800/hz
        ENDM

sfx_shoot:
        db 1
        dw 300
        db 1
        dw 450
        db 1
        dw 700
        db 0
sfx_boom:
        db 82h
        dw 600
        db 84h
        dw 1500
        db 84h
        dw 3000
        db 0
sfx_zap:
        db 2
        dw 250
        db 2
        dw 180
        db 0
sfx_push:
        db 2
        dw 6000
        db 2
        dw 9000
        db 0
sfx_efire:
        db 2
        dw 1400
        db 2
        dw 1100
        db 0
sfx_rescue:
        NOTE 523, 3
        NOTE 659, 3
        NOTE 784, 3
        NOTE 1047, 6
        db 0
sfx_human:                      ; a human is lost
        NOTE 220, 6
        NOTE 165, 6
        NOTE 110, 10
        db 0
sfx_mutate:
        NOTE 880, 3
        NOTE 440, 3
        NOTE 880, 3
        NOTE 440, 3
        NOTE 220, 8
        db 0
sfx_death:
        NOTE 880, 4
        NOTE 784, 4
        NOTE 659, 4
        NOTE 523, 4
        NOTE 440, 4
        NOTE 349, 4
        NOTE 262, 6
        NOTE 196, 8
        db 0A0h
        dw 3000
        db 0
sfx_wave:
        NOTE 392, 6
        NOTE 523, 6
        NOTE 659, 6
        NOTE 784, 12
        db 4
        dw 0
        NOTE 659, 6
        NOTE 784, 18
        db 0
sfx_clear:
        NOTE 523, 5
        NOTE 659, 5
        NOTE 784, 5
        NOTE 1047, 5
        NOTE 784, 5
        NOTE 1047, 15
        db 0
sfx_extra:
        NOTE 1047, 4
        NOTE 1319, 4
        NOTE 1568, 4
        NOTE 1047, 4
        NOTE 1319, 4
        NOTE 1568, 10
        db 0
sfx_spawn:
        NOTE 1568, 2
        NOTE 1760, 2
        NOTE 1976, 2
        db 0
sfx_over:
        NOTE 392, 12
        NOTE 370, 12
        NOTE 349, 12
        NOTE 330, 30
        db 0
