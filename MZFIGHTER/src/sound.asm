; =====================================================================
;  sound.asm - interrupt-driven music and effects on the 8253
;
;  Counter 1 counts scan lines (mode 2, N=78), counter 2 counts those
;  (mode 0, N=2) and raises INT every 156 lines = 100 Hz.  The handler
;  re-arms counter 2, counts mtick, plays an effect byte if one is running
;  and otherwise, every second tick, one tick of the music.
;
;  The music is synthesised from compact rows (tools/music.py): each row is
;  3 bytes - lead note (0 hold, 7Fh rest), chord (0 keep) and flags:
;      bits 0-1 drum: 1 kick falling into the chord root, 2 snare, 3 hat
;      bit 2 "pah" (two-note chord blip)   bit 3 bass pluck
;  and the one square-wave channel is shared out per 50 Hz tick between
;  the drum, the bass, a plucked lead with vibrato and decay, and a chord
;  arpeggio that fills the gaps.
; =====================================================================

irq:    push af
        out (0E3h),a                    ; I/O back in view (render may have
        push bc                         ; the high RAM paged in)
        push de
        push hl
        ld hl,CTR2
        ld (hl),2                       ; re-arm counter 2 (INT released)
        ld (hl),0
        ld hl,mtick
        inc (hl)
        bit 0,(hl)                      ; the keyboard, 50 times a second: a
        call z,scan_keys                ; tap is never lost behind a redraw
        ld a,(sfx_on)
        or a
        jr z,.mus
        call sfx_tick
        ld a,(mtick)
        rra
        jr c,.out
        ld a,(mus_on)
        or a
        call nz,mus_step                ; keep time, don't sound
        jr .out
.mus:   ld a,(mtick)
        rra
        jr c,.out
        ld a,(mus_on)
        or a
        jr z,.out
        call mus_step
        call snd_out
.out:   ld a,(hi_on)
        or a
        jr z,.x
        out (0E1h),a
.x:     pop hl
        pop de
        pop bc
        pop af
        ei
        reti

; page the high RAM in / out (order matters against the interrupt)
hi_in:  ld a,1
        ld (hi_on),a
        out (0E1h),a
        ret
hi_out: xor a
        ld (hi_on),a
        out (0E3h),a
        ret
hi_on:  db 0

; ---------------------------------------------------------------- output
; snd_val: 0 = silence, 1..95 = note, 80h+k = noise burst k, FFh = keep
snd_out:
        ld a,(snd_val)
        or a
        jr z,.off
        jp m,.noise
        ld l,a
        ld h,0
        add hl,hl
        ld de,mus_div
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(mus_vib)
        or a
        call nz,vibrato
.div:   ld hl,(snd_last)
        or a
        sbc hl,de
        ret z
        ld (snd_last),de
        ld a,e
        ld (CTR0),a
        ld a,d
        ld (CTR0),a
        ld a,1
        ld (SNDGATE),a
        ret
.off:   ld (SNDGATE),a
        ld hl,0
        ld (snd_last),hl
        ret
.noise: and 7Fh
        ld l,a
        add a,a
        add a,a
        add a,l                         ; 5 bytes per kind
        ld l,a
        ld h,0
        ld de,noise_kinds
        add hl,de
        ld b,(hl)                       ; writes
        inc hl
        ld c,(hl)                       ; mask low
        inc hl
        ld a,(hl)                       ; mask high
        ld (.mh+1),a
        inc hl
        ld e,(hl)                       ; base
        inc hl
        ld d,(hl)
        ld a,1
        ld (SNDGATE),a
        ld hl,(nseed)
.nl:    ld a,h
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
        ld a,l
        and c
        add a,e
        ld (CTR0),a
        ld a,h
.mh:    and 0
        adc a,d
        ld (CTR0),a
        djnz .nl
        ld (nseed),hl
        ld hl,0FFFFh
        ld (snd_last),hl
        ret

; noise kinds: writes, mask (word), base (word)
noise_kinds:
        db 10
        dw 001Fh, 24                    ; 0 hat
        db 30
        dw 00FFh, 70                    ; 1 snare
        db 40
        dw 07FFh, 400                   ; 2 boom / crash
        db 20
        dw 01FFh, 120                   ; 3 hit
        db 24
        dw 003Fh, 40                    ; 4 hiss (magic)
        db 30
        dw 0FFFh, 900                   ; 5 rumble

; DE = divisor; bend it by the vibrato phase (about +-25 cents)
vibrato:
        ld a,(mus_age)
        rra
        and 7
        ld c,a
        ld h,d
        ld l,e
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                            ; HL = div / 64
        ld a,c
        and 3
        jr z,.n
        cp 2
        jr z,.full
        srl h
        rr l                            ; half depth
.full:  bit 2,c
        ex de,hl
        jr nz,.sub
        add hl,de
        ex de,hl
        ret
.sub:   or a
        sbc hl,de
        ex de,hl
        ret
.n:     ret

; ---------------------------------------------------------------- music
; A = tune number
mus_play:
        di
        push hl
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld de,tune_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(hl)                       ; ticks per row
        ld (mus_tpr),a
        inc hl
        ld a,(hl)                       ; arpeggio length (ticks of each row)
        ld (mus_arpl),a
        inc hl
        ld a,(hl)                       ; loop position in the order list
        inc hl
        ld (mus_order),hl
        ld e,a
        ld d,0
        add hl,de
        ld (mus_loop),hl
        ld hl,(mus_order)
        ld (mus_optr),hl
        xor a
        ld (mus_rowsleft),a
        ld (mus_k),a
        ld (mus_lead),a
        ld (mus_flags),a
        ld (mus_root),a
        ld (mus_n1),a
        ld (mus_n2),a
        ld a,1
        ld (mus_on),a
        pop de
        pop hl
        ei
        ret

mus_stop:
        xor a
        ld (mus_on),a
        ld (SNDGATE),a
        ld hl,0
        ld (snd_last),hl
        ret

; one 50 Hz tick: fetch a row when due, then choose what sounds -> snd_val
mus_step:
        ld a,(mus_k)
        or a
        call z,mus_row
        xor a
        ld (mus_vib),a
        ld a,(mus_k)
        ld c,a                          ; C = tick within the row
        ld a,(mus_flags)
        ld b,a                          ; B = flags
        and 3
        jr z,.nodrum
        cp 1
        jr nz,.snare
        ld a,c                          ; kick: root +24, +12, +0, +0
        cp 4
        jr nc,.nodrum
        ld hl,kick_oct
        ld e,c
        ld d,0
        add hl,de
        ld a,(mus_root)
        add a,(hl)
        jp .val
.snare: cp 2
        jr nz,.hat
        ld a,c
        cp 2
        jr nc,.nodrum
        ld a,81h
        jp .val
.hat:   ld a,c
        or a
        jr nz,.nodrum
        ld a,80h
        jp .val
.nodrum:
        bit 3,b                         ; bass pluck
        jr z,.nopluck
        ld a,c
        cp 2
        jr nc,.nopluck
        ld a,(mus_root)
        or a
        jr z,.nopluck
        bit 0,c
        jr nz,.val
        add a,12
        jr .val
.nopluck:
        bit 2,b                         ; pah
        jr z,.nopah
        ld a,c
        cp 2
        jr nc,.nopah
        ld a,(mus_n1)
        bit 0,c
        jr z,.p1
        ld a,(mus_n2)
.p1:    or a
        jr z,.nopah
        add a,12
        jr .val
.nopah: ld a,(mus_lead)
        or a
        jr z,.arp
        ld e,a
        ld a,(mus_age)
        or a
        jr nz,.held
        ld a,e
        add a,12                        ; the pluck: an octave up for one tick
        jr .val
.held:  cp 60
        jr c,.sus
        and 1                           ; decay: every other tick
        jr nz,.arp
.sus:   cp 8
        jr c,.plain
        ld a,1
        ld (mus_vib),a
.plain: ld a,e
        jr .val
.arp:   ld a,(mus_arpl)
        ld e,a
        ld a,c
        cp e
        jr nc,.sil
        ld a,(mtick)
        rra
        and 3
        jr z,.a0
        dec a
        jr z,.a1
        dec a
        jr z,.a2
.a1:    ld a,(mus_n1)
        jr .ar
.a2:    ld a,(mus_n2)
        jr .ar
.a0:    ld a,(mus_root)
.ar:    or a
        jr z,.val
        add a,24
        jr .val
.sil:   xor a
.val:   ld (snd_val),a
        ld hl,mus_age
        inc (hl)
        jr nz,$+3
        dec (hl)
        ld a,(mus_tpr)
        ld b,a
        ld a,(mus_k)
        inc a
        cp b
        jr c,$+3
        xor a
        ld (mus_k),a
        ret

kick_oct: db 24, 12, 0, 0

mus_row:
        ld a,(mus_rowsleft)
        or a
        jr nz,.have
        ld hl,(mus_optr)                ; next pattern from the order list
        ld a,(hl)
        cp 0FFh
        jr nz,.ok
        ld a,(mus_noloop)
        or a
        jp nz,mus_stop_tick
        ld hl,(mus_loop)
        ld a,(hl)
.ok:    inc hl
        ld (mus_optr),hl
        ld l,a
        ld h,0
        add hl,hl
        ld de,pat_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (mus_rowp),de
        ld a,16
.have:  dec a
        ld (mus_rowsleft),a
        ld hl,(mus_rowp)
        ld a,(hl)                       ; lead
        inc hl
        or a
        jr z,.chord
        cp 7Fh
        jr nz,.note
        xor a
.note:  ld (mus_lead),a
        xor a
        ld (mus_age),a
.chord: ld a,(hl)
        inc hl
        or a
        jr z,.flags
        push hl
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,chord_tab-3
        add hl,de
        ld a,(hl)
        ld (mus_root),a
        inc hl
        ld a,(hl)
        ld (mus_n1),a
        inc hl
        ld a,(hl)
        ld (mus_n2),a
        pop hl
.flags: ld a,(hl)
        inc hl
        ld (mus_flags),a
        ld (mus_rowp),hl
        ret

mus_stop_tick:
        pop hl                          ; drop mus_step's return: end the tune
        xor a
        ld (mus_on),a
        ld (snd_val),a
        ret

; ---------------------------------------------------------------- effects
; A = effect number.  Effects are 100 Hz byte streams: 1..95 note,
; 7Fh silence, 80h+k noise k, 0 end.
sfx_play:
        push hl
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld de,sfx_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        di
        ld (sfx_ptr),de
        ld a,1
        ld (sfx_on),a
        ei
        pop de
        pop hl
        ret

sfx_tick:
        ld hl,(sfx_ptr)
        ld a,(hl)
        inc hl
        ld (sfx_ptr),hl
        or a
        jr z,.end
        cp 7Fh
        jr nz,.v
        xor a
.v:     ld (snd_val),a
        xor a
        ld (mus_vib),a
        jp snd_out
.end:   ld (sfx_on),a
        ld (SNDGATE),a
        ld hl,0
        ld (snd_last),hl
        ret

; wait until the effect has finished
sfx_wait:
        ld a,(sfx_on)
        or a
        ret z
        halt
        jr sfx_wait

mtick:          db 0
sfx_on:         db 0
sfx_ptr:        dw 0
snd_val:        db 0
snd_last:       dw 0
nseed:          dw 1234h
mus_on:         db 0
mus_noloop:     db 0
mus_tpr:        db 6
mus_arpl:       db 4
mus_k:          db 0
mus_order:      dw 0
mus_loop:       dw 0
mus_optr:       dw 0
mus_rowp:       dw 0
mus_rowsleft:   db 0
mus_lead:       db 0
mus_age:        db 0
mus_vib:        db 0
mus_flags:      db 0
mus_root:       db 0
mus_n1:         db 0
mus_n2:         db 0
