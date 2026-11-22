; =====================================================================
;  sound.asm - one voice on 8253 counter 0 (data: tools/music.py)
;
;  Counter 0 plays a square wave by itself, so sound costs almost no CPU.
;   - Music is a tracker: a pitch per 50 Hz tick, arranged at build time
;     (kick into the bass, snare click, plucked melody, arpeggios).
;   - Effects: two slots step ~100 times a second.  When both are busy
;     they take turns, so a shot sounds over an explosion; while either
;     plays, the music waits.  Noise: snd_poll rewrites the count with
;     random values while the CPU waits.
;  Ticks come from a scan-line clock (8253 counter 1) via snd_clock, which
;  the game calls often, so no sound tick is lost while it works.
; =====================================================================

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
        ld a,36h                ; counter 0: LSB/MSB, mode 3 square wave
        ld (CTRL),a
        call read_ctr1
        ld (snd_clk),hl
        ; fall through
; silence every effect
sfx_stop:
        push hl
        push bc
        ld hl,hslot0
        ld b,2*HS_SIZE
.c:     ld (hl),0
        inc hl
        djnz .c
        pop bc
        pop hl
        jp out_off

; ---------------------------------------------------------------------
; HL = tune: play it (unless the music is switched off)
music:
        ld a,(soundopt)
        or a
        jr nz,mus_stop
        ld a,(demo)
        or a
        jr nz,mus_stop
trk_play:
        ld (trk_ptr),hl
        ld (trk_start),hl
        xor a
        ld (trk_rep),a
        ld (trk_cur),a
        inc a
        ld (trk_on),a
        ret

mus_stop:
        xor a
        ld (trk_on),a
        ld (trk_cur),a
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
.nl:    cp 0FEh
        jp z,mus_stop
        ld (trk_ptr),hl
        cp 0E0h
        jr c,.val
        sub 0E0h
        ld (trk_rep),a
        ret
.val:   ld (trk_cur),a
        ret

; ---------------------------------------------------------------------
; effects.  HL = effect, A = priority: a slot playing something more
; important is left alone.  Keeps every register except AF.
sfx:
        push bc
        ld b,a
        ld a,(soundopt)
        cp 2
        jr z,.no
        ld a,(demo)
        or a
        jr nz,.no
        push de
        push hl
        push ix
        ex de,hl
        ld ix,hslot0            ; the same effect again: restart it
        call .same
        jr z,.take
        ld ix,hslot1
        call .same
        jr z,.take
        ld ix,hslot0            ; a free slot
        ld a,(ix+HS_PTR+1)
        or a
        jr z,.take
        ld ix,hslot1
        ld a,(ix+HS_PTR+1)
        or a
        jr z,.take
        ld a,(hslot0+HS_PRIO)   ; else the less important one
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
.no:    pop bc
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

; ---------------------------------------------------------------------
; the scan-line clock: a half tick every 156 lines.  Call it often.
; Keeps BC, DE, HL, IX, IY.
snd_clock:
        push bc
        push de
        push hl
        call read_ctr1
        ex de,hl
        ld hl,(snd_clk)
        or a
        sbc hl,de               ; lines since the last half tick
        ld a,h
        cp 4
        jr c,.l
        ld (snd_clk),de         ; far behind: start again
        ld hl,156
.l:     ld bc,156
        or a
        sbc hl,bc
        jr c,.x
        push hl
        ld hl,(snd_clk)
        or a
        sbc hl,bc
        ld (snd_clk),hl
        ld hl,snd_ph
        inc (hl)
        bit 0,(hl)
        jr z,.h
        call trk_tick
.h:     push ix
        call hw_sub
        pop ix
        pop hl
        jr .l
.x:     pop hl
        pop de
        pop bc
        ret

; noise: a fresh random count while a noise segment plays
snd_poll:
        ld a,(noise_on)
        or a
        ret z
noise_step:
        ld a,(nz_seed)
        add a,a
        jr nc,.n
        xor 2Dh
.n:     ld (nz_seed),a
        ld (CTR0),a
        rrca
        rrca
nzs_mask:
        and 0
nzs_band:
        add a,0
        ld (CTR0),a
        ret

; one ~100 Hz step: the effect slots, then what counter 0 should play
hw_sub:
        ld ix,hslot0
        call hs_tick
        ld ix,hslot1
        call hs_tick
        ld hl,hw_par
        inc (hl)
        ld a,(hslot0+HS_PTR+1)
        or a
        ld a,(hslot1+HS_PTR+1)
        jr z,.s1
        ld ix,hslot0
        or a
        jp z,hs_out
        ld a,(hw_par)
        rra
        jp nc,hs_out
        ld ix,hslot1
        jp hs_out
.s1:    ld ix,hslot1
        or a
        jp nz,hs_out
        ld a,(trk_on)           ; no effect: the tracker
        or a
        jp z,out_off
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

hs_out: ld a,(ix+HS_MODE)
        cp 2
        jp z,out_off
        cp 1
        jr z,.noise
        ld l,(ix+HS_DIV)
        ld h,(ix+HS_DIV+1)
        cp 3
        jp nz,out_div
        ld b,(ix+HS_ARG)        ; vibrato: +- divisor >> arg
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
        ld a,1
        ld (noise_on),a
        ld (SNDGATE),a
        ld hl,0
        ld (cur_div),hl
        jp noise_step

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
        ld (ix+HS_PTR+1),a
        ld (ix+HS_PRIO),a
        ret
.seg:   ld (ix+HS_CNT),a
        push ix
        pop de
        inc de
        inc de
        inc de
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

out_off:
        xor a
        ld (noise_on),a
        ld (SNDGATE),a
        ld hl,0
        ld (cur_div),hl
        ret

; M: MUSIC + FX -> FX ONLY -> OFF
cycle_sound:
        ld a,(soundopt)
        inc a
        cp 3
        jr c,.s
        xor a
.s:     ld (soundopt),a
        call sfx_stop
        call mus_stop
        ld a,1
        ld (hudsnd),a
        ld a,(soundopt)
        or a
        ret nz
        ld hl,(curtune)         ; music back on: the tune for here
        jp music

; HL = tune, remembered for when the music comes back on
play_tune:
        ld (curtune),hl
        jp music

        include "../build/gen_music.inc"
