; =====================================================================
;  sound.asm - one voice on 8253 counter 0: sweeps, warbles and noise
;
;  A sound is a list of steps (6 bytes):
;     db ticks, kind ; dw start divisor, divisor change per tick
;  kind 0 tone, 5 warble (+-1/8 every other tick), 4 rest,
;       1/2/3 noise: a random divisor from (divisor) to (divisor + 1FFh /
;       7FFh / 1FFFh) - re-rolled continuously while the CPU waits for
;       vertical blank, so it's real noise, not 50 Hz grit.
;  Tone = 1108800 / divisor Hz.  db 0 ends the sound.
;  Sweeping the divisor makes the falling zaps and rising whoops of the
;  arcade machines of the time.
; =====================================================================

init_hw:
        ld a,36h                ; counter 0: LSB/MSB, mode 3 (square wave)
        ld (CTRL),a
        ld a,74h                ; counter 1: LSB/MSB, mode 2, count 65536:
        ld (CTRL),a             ; it counts scan lines, for tick pacing
        xor a
        ld (CTR1),a
        ld (CTR1),a
        xor a
        ld (SNDGATE),a
        ret

; HL = sound, A = priority.  Interrupts a lower or equal priority sound.
play_sfx:
        ld b,a
        ld a,(sndon)
        or a
        ret z
        ld a,(demo)             ; the demo plays silently
        or a
        ret nz
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

; M: sound ALL (effects + heartbeat) -> FX only -> OFF -> ALL
cycle_sound:
        ld a,(soundopt)
        inc a
        cp 3
        jr c,.s
        xor a
.s:     ld (soundopt),a
        cp 2
        ld a,0
        jr z,.o
        inc a
.o:     ld (sndon),a
        call snd_off
        ld hl,sfx_spawn         ; a blip to show it's on
        ld a,1
        jp play_sfx

snd_off:
        ld hl,0
        ld (sndptr),hl
        ld (sndnz),hl
        xor a
        ld (sndleft),a
        ld (sndpri),a
        ld (SNDGATE),a
        ret

snd_tick:
        ld hl,(sndptr)
        ld a,h
        or a
        jp z,.quiet
        ld a,(sndleft)
        or a
        jr nz,.run
        ld a,(hl)               ; next step
        or a
        jp z,snd_off
        ld (sndleft),a
        inc hl
        ld a,(hl)
        ld (sndkind),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (snddiv),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (snddel),de
        ld (sndptr),hl
.run:   ld hl,sndleft
        dec (hl)
        ld a,(sndkind)
        cp 4
        jr z,.quiet             ; a rest
        ld hl,0                 ; noise mask
        or a
        jr z,.nm
        cp 5
        jr z,.nm
        ld hl,01FFh
        dec a
        jr z,.nm
        ld hl,07FFh
        dec a
        jr z,.nm
        ld hl,1FFFh
.nm:    ld (sndnz),hl
        ld a,h
        or l
        jr z,.tone
        call noise_out
        jr .gate
.tone:  ld de,(snddiv)
        ld a,(sndkind)
        cp 5
        jr nz,.out
        ld a,(sndwob)           ; warble: +- 1/8, alternate ticks
        xor 1
        ld (sndwob),a
        ld h,d
        ld l,e
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        or a
        jr z,.sub
        add hl,de
        ex de,hl
        jr .out
.sub:   ex de,hl
        or a
        sbc hl,de
        ex de,hl
.out:   ld a,e
        ld (CTR0),a
        ld a,d
        ld (CTR0),a
.gate:  ld a,1
        ld (SNDGATE),a
        ld hl,(snddiv)          ; sweep
        ld de,(snddel)
        add hl,de
        ld (snddiv),hl
        ret
.quiet: xor a
        ld (SNDGATE),a
        ld hl,0
        ld (sndnz),hl
        ret

; a fresh random divisor for a noise step (also called from wait_vblank)
noise_out:
        push hl
        push de
        call nrand
        ld a,(sndnz)
        and l
        ld e,a
        ld a,(sndnz+1)
        and h
        ld d,a
        ld hl,(snddiv)
        add hl,de
        ld a,l
        ld (CTR0),a
        ld a,h
        ld (CTR0),a
        pop de
        pop hl
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

; the same for noise, on its own seed (so sound never changes the game)
nrand:
        ld hl,(nseed)
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
        ld (nseed),hl
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
; step macros (frequencies in Hz)
DV      equ 1108800
TONE    MACRO t, hz             ; a steady tone
        db t, 0
        dw DV/hz, 0
        ENDM
SWP     MACRO t, hz1, hz2       ; a tone sweeping from hz1 to hz2
        db t, 0
        dw DV/hz1, (DV/hz2-DV/hz1)/t
        ENDM
WRB     MACRO t, hz1, hz2       ; the same, warbling
        db t, 5
        dw DV/hz1, (DV/hz2-DV/hz1)/t
        ENDM
NZ      MACRO t, k, d1, d2      ; noise of band k, base divisor d1 -> d2
        db t, k
        dw d1, (d2-d1)/t
        ENDM
REST    MACRO t
        db t, 4
        dw 0, 0
        ENDM
NT      MACRO hz                ; a staccato note of the title riff
        db 5, 0
        dw DV/hz, 0
        db 1, 4
        dw 0, 0
        ENDM
ZAP     MACRO                   ; the falling zap that ends a bar
        db 4, 0
        dw DV/1400, (DV/300-DV/1400)/4
        ENDM

; ---- in play
sfx_shoot:                      ; a short laser crack: down from 3 kHz
        SWP 2, 3200, 1500
        SWP 2, 1500, 650
        db 0
sfx_boom:                       ; a thump, a crash, then rumble falling away
        TONE 1, 70
        NZ 3, 2, 300, 700
        NZ 10, 3, 700, 3600
        db 0
sfx_bigboom:                    ; the same, bigger and longer
        TONE 2, 55
        NZ 4, 2, 250, 700
        NZ 26, 3, 700, 7000
        db 0
sfx_zap:                        ; a bullet shot down: a spit of noise
        NZ 3, 1, 120, 400
        db 0
sfx_push:                       ; a crusher knocked back: a dull clank
        TONE 2, 60
        NZ 2, 2, 900, 1600
        db 0
sfx_efire:                      ; seeker spark
        SWP 3, 900, 300
        db 0
sfx_missile:                    ; mindbot missile: a rising hiss
        NZ 6, 1, 700, 150
        db 0
sfx_shell:                      ; tank shell: a low thoomp
        SWP 3, 160, 80
        db 0
sfx_rescue:                     ; two climbing whoops and a shimmer
        SWP 5, 300, 1200
        SWP 5, 450, 1800
        WRB 10, 1800, 2200
        db 0
sfx_human:                      ; a human lost: a long fall and a crunch
        SWP 18, 900, 120
        NZ 6, 3, 1500, 4000
        db 0
sfx_mutate:                     ; a human turned: a sick warble up and down
        WRB 24, 150, 600
        WRB 12, 600, 200
        db 0
sfx_spawn:                      ; something hatches / materialises
        SWP 4, 200, 700
        db 0
sfx_pick:                       ; a power-up: a whoop that keeps going
        SWP 8, 400, 2400
        WRB 10, 2400, 2600
        db 0
sfx_extra:                      ; extra life: three whoops and a trill
        SWP 6, 200, 1600
        REST 2
        SWP 6, 200, 1600
        REST 2
        SWP 6, 200, 1600
        WRB 14, 1600, 1600
        db 0
sfx_death:                      ; you: a crash, a long warbling fall, rumble
        NZ 6, 3, 400, 1500
        WRB 60, 700, 60
        NZ 20, 3, 3000, 12000
        db 0
sfx_beat:                       ; the heartbeat: lub ... dub
        TONE 2, 55
        REST 3
        TONE 3, 45
        db 0

; ---- between waves
sfx_wave:                       ; a new wave: a growl climbing out of the dark
        WRB 50, 60, 500
        SWP 10, 500, 1500
        NZ 10, 1, 150, 600
        db 0
sfx_clear:                      ; cleared: a dive and a soaring climb
        SWP 15, 1500, 150
        SWP 15, 150, 2000
        WRB 10, 2000, 2000
        db 0
sfx_over:                       ; game over: a slow descent into rumble
        WRB 40, 220, 110
        WRB 40, 110, 55
        WRB 60, 55, 30
        NZ 30, 3, 6000, 20000
        db 0
sfx_type:                       ; typewriter tick
        NZ 1, 1, 60, 60
        db 0

; ---- title: a rising growl, a crash, then a menacing minor ostinato
; (E phrygian, then up a fourth) with a falling zap at the end of each
; bar, and a long warbling fall to finish
sfx_title:
        WRB 60, 50, 400
        NZ 12, 3, 1500, 6000
        REST 6
        ; A
        NT 165
        NT 165
        NT 330
        NT 165
        NT 175
        NT 165
        NT 294
        NT 262
        NT 165
        NT 165
        NT 330
        NT 165
        NT 196
        NT 175
        NT 165
        NT 147
        ZAP
        ; A
        NT 165
        NT 165
        NT 330
        NT 165
        NT 175
        NT 165
        NT 294
        NT 262
        NT 165
        NT 165
        NT 330
        NT 165
        NT 196
        NT 175
        NT 165
        NT 147
        ZAP
        ; B (up a fourth)
        NT 220
        NT 220
        NT 440
        NT 220
        NT 233
        NT 220
        NT 392
        NT 349
        NT 220
        NT 220
        NT 440
        NT 220
        NT 262
        NT 233
        NT 220
        NT 196
        ZAP
        ; A
        NT 165
        NT 165
        NT 330
        NT 165
        NT 175
        NT 165
        NT 294
        NT 262
        NT 165
        NT 165
        NT 330
        NT 165
        NT 196
        NT 175
        NT 165
        NT 147
        ; the sting
        WRB 50, 330, 41
        NZ 20, 3, 3000, 15000
        db 0
