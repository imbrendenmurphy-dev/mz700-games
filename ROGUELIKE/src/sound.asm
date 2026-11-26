; =====================================================================
;  sound.asm - LUMEN's sound (data: tools/music.py -> gen_music.inc)
;
;  One output for the whole game: 8253 counter 0 plays a square wave by
;  itself, so sound costs almost no CPU and every screen can animate.
;   - Music is the tracker: a pitch per 50 Hz tick, arranged at build
;     time in the demoscene way (plucked notes, chord arpeggios, a kick
;     into the bass, vibrato).  The waltz plays on the title, through the
;     attract screens, docked and with the docking computer.
;   - Effects: two slots step about 100 times a second (a scan-line
;     clock, so none are lost while the view is drawn).  When both are
;     busy they take turns, so a laser sounds over an explosion; while
;     either plays, the music waits.  Noise: poll rewrites the count
;     with random values.
; =====================================================================

; effect slot (segments of 7 bytes, see music.py)
HS_PTR          equ 0
HS_CNT          equ 2
HS_DIV          equ 3
HS_DD           equ 5
HS_MODE         equ 7
HS_ARG          equ 8
HS_PRIO         equ 9
HS_START        equ 10
HS_SIZE         equ 12

snd_init:
        ld hl,snd_vars
        ld de,snd_vars+1
        ld bc,snd_vars_end-snd_vars-1
        ld (hl),0
        ldir
        ld a,5Bh
        ld (nz_seed),a
        ; fall through

; (re)start the tone generator: counter 0 as a square wave, effects off
snd_fe:
snd_fl:
        push hl
        call read_ctr1
        ld (snd_clk),hl
        ld hl,hslot0
        call clr_hslots
        xor a
        ld (snd_mode),a
        ld (SNDGATE),a
        ld (noise_on),a
        ld a,36h                        ; counter 0: LSB/MSB, mode 3 square wave
        ld (CTRL),a
        ld hl,0
        ld (cur_div),hl                 ; the next tone reloads the count
        pop hl
        ret

clr_hslots:
        ld b,2*HS_SIZE
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; ---------------------------------------------------------------------
; the tracker: one channel, as the demoscene plays it.  A value per
; 50 Hz tick: 00 silence, 01-DF a divisor from TRK_TAB, E0+k hold k more
; ticks, FF loop.
; ---------------------------------------------------------------------
trk_play:                               ; HL = stream
        ld (trk_ptr),hl
        ld (trk_start),hl
        xor a
        ld (trk_rep),a
        ld (trk_cur),a
        inc a
        ld (trk_on),a
        ret

trk_tick:
        ld a,(trk_on)
        or a
        ret z
        ld hl,trk_rep
        ld a,(hl)
        or a
        jr z,.rd
        dec (hl)
        ret
.rd:    ld hl,(trk_ptr)
.r2:    ld a,(hl)
        inc hl
        cp 0FFh
        jr nz,.nl
        ld hl,(trk_start)
        jr .r2
.nl:    cp 0FEh                         ; the end (a tune that does not loop)
        jp z,mus_stop
        ld (trk_ptr),hl
        cp 0E0h
        jr c,.val
        sub 0E0h
        ld (trk_rep),a
        ret
.val:   ld (trk_cur),a
        ret

mus_stop:
        xor a
        ld (trk_on),a
        ld (trk_cur),a
        ret

; ---------------------------------------------------------------------
; effects.  HL = effect program, A = priority: a slot playing something
; of higher priority is left alone.  Keeps every register except AF.
; ---------------------------------------------------------------------
sfx:
        push bc
        push de
        push hl
        push ix
        ld b,a
        ex de,hl
        ld ix,hslot0                    ; the same effect again: restart it
        call .same
        jr z,.take
        ld ix,hslot1
        call .same
        jr z,.take
        ld ix,hslot0                    ; a free slot
        ld a,(ix+HS_PTR+1)
        or a
        jr z,.take
        ld ix,hslot1
        ld a,(ix+HS_PTR+1)
        or a
        jr z,.take
        ld a,(hslot0+HS_PRIO)           ; else the less important one
        ld c,a
        ld a,(hslot1+HS_PRIO)
        cp c
        ld ix,hslot1
        jr c,.low
        ld ix,hslot0
        ld a,c
.low:   cp b
        jr z,.take
        jr nc,.x
.take:  ld (ix+HS_PTR),e
        ld (ix+HS_PTR+1),d
        ld (ix+HS_START),e
        ld (ix+HS_START+1),d
        ld (ix+HS_CNT),1
        ld (ix+HS_PRIO),b
.x:     pop ix
        pop hl
        pop de
        pop bc
        ret
.same:  ld a,(ix+HS_PTR+1)
        or a
        jr z,.ns
        ld a,(ix+HS_START)
        cp e
        ret nz
        ld a,(ix+HS_START+1)
        cp d
        ret
.ns:    or 1
        ret
; silence every effect (keeps HL and BC)
sfx_stop:
        push hl
        push bc
        ld hl,hslot0
        call clr_hslots
        pop bc
        pop hl
        jp out_off

; ---------------------------------------------------------------------
; ticks (from the scan-line clock): snd_tick 50 times a second, snd_half
; between.  Keep every register except AF.
; ---------------------------------------------------------------------
snd_tick:
        push hl
        call trk_tick
        pop hl
snd_half:
        push ix
        push iy
        call hw_sub
        pop iy
        pop ix
        ret

snd_clock:
        call read_ctr1
        ex de,hl
        ld hl,(snd_clk)
        or a
        sbc hl,de                       ; lines since the last half tick
        ld a,h
        cp 1248/256+1
        jr c,.l
        ld (snd_clk),de                 ; far behind (after a pause): start again
        ld hl,156
.l:     ld bc,156
        or a
        sbc hl,bc
        ret c
        push hl
        ld hl,(snd_clk)
        or a
        sbc hl,bc
        ld (snd_clk),hl
        ld hl,snd_ph
        inc (hl)
        bit 0,(hl)
        jr z,.h
        call snd_tick
        jr .n
.h:     call snd_half
.n:     pop hl
        jr .l

; one ~100 Hz step: the effect slots, then what counter 0 should play
hw_sub:
        ld ix,hslot0
        call hs_tick
        ld ix,hslot1
        call hs_tick
        ld hl,hw_par
        inc (hl)
        ld a,(snd_mute)
        or a
        jp nz,out_off
        ld a,(hslot0+HS_PTR+1)
        or a
        ld a,(hslot1+HS_PTR+1)
        jr z,.s1
        ld ix,hslot0
        or a
        jp z,hs_out
        ld a,(hw_par)                   ; both busy: take turns
        rra
        jp nc,hs_out
        ld ix,hslot1
        jp hs_out
.s1:    ld ix,hslot1
        or a
        jp nz,hs_out
        ; no effect: the tracker
        ld a,(trk_on)
        or a
        jr z,.nt
        ld a,(trk_cur)
        or a
        jp z,out_off
        add a,a
        ld e,a
        ld d,0
        ld hl,TRK_TAB-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp out_div
.nt:    jp out_off

; counter 0 plays effect slot IX
hs_out: ld a,(ix+HS_MODE)
        cp 2
        jp z,out_off
        cp 1
        jr z,.noise
        ld l,(ix+HS_DIV)
        ld h,(ix+HS_DIV+1)
        cp 3
        jp nz,out_div
        ld b,(ix+HS_ARG)                ; vibrato: +- divisor >> arg
        ld e,l
        ld d,h
.sh:    srl d
        rr e
        djnz .sh
        ld a,(hw_par)
        and 2
        jr z,.p
        or a
        sbc hl,de
        jp out_div
.p:     add hl,de
        jp out_div
.noise: ld a,(ix+HS_ARG)
        ld (nzs_mask+1),a
        ld a,(ix+HS_DIV+1)
        ld (nzs_band+1),a
        jp out_noise

; flight effect slot tick (IX = slot)
; segment: frames, divisor(2), divisor change(2), mode, arg
hs_tick:
        ld l,(ix+HS_PTR)
        ld h,(ix+HS_PTR+1)
        ld a,h
        or a
        ret z
        dec (ix+HS_CNT)
        jr z,.load
        ld l,(ix+HS_DIV)
        ld h,(ix+HS_DIV+1)
        ld e,(ix+HS_DD)
        ld d,(ix+HS_DD+1)
        add hl,de
        ld (ix+HS_DIV),l
        ld (ix+HS_DIV+1),h
        ret
.load:  ld a,(hl)
        or a
        jr nz,.seg
        ld (ix+HS_PTR+1),a              ; finished
        ld (ix+HS_PRIO),a
        ret
.seg:   ld (ix+HS_CNT),a
        push ix
        pop de
        inc de
        inc de
        inc de                          ; DE = slot + HS_DIV
        inc hl
        ld bc,6
        ldir
        ld (ix+HS_PTR),l
        ld (ix+HS_PTR+1),h
        ret

; HL = divisor
out_div:
        xor a
        ld (noise_on),a
        ld a,(cur_div)
        cp l
        jr nz,.w
        ld a,(cur_div+1)
        cp h
        jr z,.g
.w:     ld (cur_div),hl
        ld a,l
        ld (CTR0),a
        ld a,h
        ld (CTR0),a
.g:     ld a,1
        ld (SNDGATE),a
        ret

out_noise:
        ld a,1
        ld (noise_on),a
        ld (SNDGATE),a
        ld hl,0
        ld (cur_div),hl
        jp noise_step

out_off:
        xor a
        ld (noise_on),a
        ld (SNDGATE),a
        ret

; a new random count in the noise band (called from poll while noise_on)
noise_step:
        ld a,(nz_seed)
        add a,a
        jr nc,.n
        xor 2Dh
.n:     ld (nz_seed),a
        ld (CTR0),a                     ; low byte
        rrca
        rrca
nzs_mask:
        and 0                           ; random part of the high byte
nzs_band:
        add a,0                         ; the band
        ld (CTR0),a
        ret
