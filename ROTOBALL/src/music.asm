; ======================================================================
;  music.asm - three-channel music on one square-wave voice
;
;  Channel 0 = lead, 1 = bass, 2 = drums (data in build/gen_music.inc).
;  Lead and bass alternate tick by tick (about 100 ticks/s), so both are
;  heard as a buzzy two-voice chord; drum hits cut in for a few ticks.
; ======================================================================

MUS_TPR = 12            ; sound ticks per row (a 16th note)

; channel record: +0 ptr, +2 loop start, +4 rows left, +5 note, +6 age (ticks)

mus_start:
    ld ix,mus_ch0
    ld hl,tune_lead
    call .init
    ld ix,mus_ch1
    ld hl,tune_bass
    call .init
    ld ix,mus_ch2
    ld hl,tune_drums
    call .init
    ld a,1
    ld (mus_rt),a
    ld (mus_on),a
    ret
.init:
    ld (ix+0),l
    ld (ix+1),h
    ld (ix+2),l
    ld (ix+3),h
    ld (ix+4),1
    ld (ix+5),0
    ret

mus_stop:
    xor a
    ld (mus_on),a
    ld (SNDGATE),a
    ret

; advance the music clock by one tick
mus_tick:
    ld a,(mus_on)
    or a
    ret z
    push ix
    ld hl,mus_rt
    dec (hl)
    jr nz,.age
    ld (hl),MUS_TPR
    ld ix,mus_ch0
    call mus_chan
    ld ix,mus_ch1
    call mus_chan
    ld ix,mus_ch2
    call mus_chan
.age:
    ld hl,mus_ch0+6
    inc (hl)
    ld hl,mus_ch1+6
    inc (hl)
    ld hl,mus_ch2+6
    inc (hl)
    ld hl,mus_tc
    inc (hl)
    pop ix
    ret

mus_chan:
    dec (ix+4)
    ret nz
    ld l,(ix+0)
    ld h,(ix+1)
.f:
    ld a,(hl)
    cp 0FFh
    jr nz,.n
    ld l,(ix+2)
    ld h,(ix+3)
    jr .f
.n:
    ld (ix+5),a
    inc hl
    ld a,(hl)
    inc hl
    ld (ix+4),a
    ld (ix+0),l
    ld (ix+1),h
    ld (ix+6),0
    ret

; play this tick's music sound (only when no sound effect is playing)
mus_out:
    ld a,(mus_on)
    or a
    ret z
    ld a,(mus_ch2+5)    ; drum hit in its first ticks?
    or a
    jr z,.tone
    ld c,a
    ld a,(mus_ch2+6)
    ld b,a
    dec c
    jr nz,.notkick
    ld a,b              ; kick: falling thump over 3 ticks
    cp 3
    jr nc,.tone
    add a,a
    add a,a
    add a,a
    add a,a
    add a,a
    add a,30
    ld d,a
    ld e,0
    jr out_div
.notkick:
    dec c
    jr nz,.hat
    ld a,b              ; snare: 3 ticks of mid noise
    cp 3
    jr nc,.tone
    ld d,3
    jr .noise
.hat:
    ld a,b              ; hat: 1 tick of high noise
    or a
    jr nz,.tone
    ld a,r              ; divisor 128-255: 4-9 kHz hiss
    or 80h
    ld e,a
    ld d,0
    jr out_div
.noise:
    ld a,r
    ld e,a
    jr out_div
.tone:
    ld a,(mus_tc)
    rra
    jr nc,.bassfirst
    call .lead
    ret c
    call .bass
    ret c
    jr .silent
.bassfirst:
    call .bass
    ret c
    call .lead
    ret c
.silent:
    xor a
    ld (SNDGATE),a
    ret
.lead:                  ; carry if played
    ld a,(mus_ch0+6)
    or a
    ret z               ; first tick of a note: a tiny gap (NC)
    ld a,(mus_ch0+5)
    jr .note
.bass:
    ld a,(mus_ch1+6)
    or a
    ret z
    ld a,(mus_ch1+5)
.note:
    or a
    ret z
    add a,a
    ld e,a
    ld d,0
    ld hl,NOTETAB
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    call out_div
    scf
    ret

out_div:                ; DE = 8253 divisor, sound on
    ld a,e
    ld (CTR0),a
    ld a,d
    ld (CTR0),a
    ld a,1
    ld (SNDGATE),a
    ret
