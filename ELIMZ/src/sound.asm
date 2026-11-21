; =====================================================================
;  sound.asm - STARHAUL's sound (data: tools/music.py -> gen_music.inc)
;
;  Two outputs share the music voices and the effect calls:
;
;  MIXER (snd_mode 1): title, docked, menus, hyperspace, launch, game
;  over, death.  Three pulse-width voices are interleaved on the 1-bit
;  speaker: writing an 8253 control word for counter 0 sets OUT0 at once
;  (mode 0 low, mode 4 high), the trick Shiru's Earshaver uses on the
;  MZ-700 and the one Dracula's Castle 2 here uses.  Each voice's duty is
;  its loudness, so notes pluck and fade; voice 2 can play white noise.
;  The mixer plays only while the program waits (wait_frame /
;  wait_fields), so screens keep their per-frame work small.
;
;  TONE (snd_mode 0): flight.  Counter 0 plays a square wave by itself
;  while the 3D view uses all the CPU.  Two effect slots step about 100
;  times a second (both edges of the vertical blank, from poll); when both
;  are busy they take turns, so a laser sounds over an explosion.  With no
;  effect, the music voices take turns on it the same way (the auto-dock
;  waltz).  Noise: poll rewrites the count with random values.
; =====================================================================

SPK_LO          equ 20h                 ; counter 0, MSB only, mode 0: OUT0 low
SPK_HI          equ 28h                 ; mode 4: OUT0 high (bit 3 = the voice bit)

; music voice
MV_PTR          equ 0
MV_WAIT         equ 2
MV_LEN          equ 3
MV_FRQ          equ 4
MV_DUTY         equ 6
MV_DECAY        equ 7
MV_DMIN         equ 8
MV_DSTART       equ 9
MV_FLAGS        equ 10                  ; bit 0 noise, 1 vibrato, 7 resting
MV_NOTE         equ 11
MV_BASE         equ 12
MV_AGE          equ 14
MV_SIZE         equ 16

; mixer effect slot (segments of 9 bytes, see music.py)
SL_PTR          equ 0
SL_CNT          equ 2
SL_FRQ          equ 3
SL_DF           equ 5
SL_DUTY         equ 7
SL_DD           equ 8
SL_MODE         equ 9
SL_ARG          equ 10
SL_PRIO         equ 11
SL_SIZE         equ 12

; flight effect slot (segments of 7 bytes)
HS_PTR          equ 0
HS_CNT          equ 2
HS_DIV          equ 3
HS_DD           equ 5
HS_MODE         equ 7
HS_ARG          equ 8
HS_PRIO         equ 9
HS_START        equ 10
HS_SIZE         equ 12

; ---------------------------------------------------------------------
; set-up and switching
; ---------------------------------------------------------------------
snd_init:
        ld hl,snd_vars
        ld de,snd_vars+1
        ld bc,snd_vars_end-snd_vars-1
        ld (hl),0
        ldir
        ld hl,0ACE1h
        ld (snd_seed),hl
        ld a,5Bh
        ld (nz_seed),a
        ; fall through: start in mixer mode

; the screens between flights
snd_fe:
        push hl
        xor a
        ld (SNDGATE),a
        ld (noise_on),a
        ld hl,hslot0
        call clr_hslots
        ld a,SPK_LO
        ld (CTRL),a
        ld a,1
        ld (snd_mode),a
        pop hl
        ret

; flight: the tone generator
snd_fl:
        push hl
        call read_ctr1
        ld (snd_clk),hl
        ld hl,mslot0
        ld b,3*SL_SIZE
.c:     ld (hl),0
        inc hl
        djnz .c
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
; music: HL = song (three stream pointers)
; ---------------------------------------------------------------------
mus_play:
        push ix
        push bc
        push de
        ld ix,mvoice0
        ld b,3
.v:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+MV_PTR),e
        ld (ix+MV_PTR+1),d
        ld (ix+MV_WAIT),1
        ld (ix+MV_LEN),14
        ld (ix+MV_DUTY),0
        ld (ix+MV_FLAGS),80h
        ld (ix+MV_NOTE),0
        ld de,MV_SIZE
        add ix,de
        djnz .v
        ld a,1
        ld (mus_on),a
        pop de
        pop bc
        pop ix
        ret

mus_stop:
        xor a
        ld (mus_on),a
        ld (mvoice0+MV_PTR+1),a
        ld (mvoice1+MV_PTR+1),a
        ld (mvoice2+MV_PTR+1),a
        ld (mvoice0+MV_DUTY),a
        ld (mvoice1+MV_DUTY),a
        ld (mvoice2+MV_DUTY),a
        ret

; ---------------------------------------------------------------------
; effects.  HL = effect (dw flight program, mixer voice 0, 1, 2 programs),
; A = priority: a slot playing something of higher priority is left alone.
; Keeps every register except AF.
; ---------------------------------------------------------------------
sfx:
        push bc
        push de
        push hl
        push ix
        ld b,a
        ld a,(snd_mode)
        or a
        jr nz,.mix
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or a
        jr z,.x
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
.mix:   inc hl
        inc hl
        ld ix,mslot0
        call .ms
        ld ix,mslot1
        call .ms
        ld ix,mslot2
        call .ms
        jr .x
.ms:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or a
        ret z
        ld a,(ix+SL_PTR+1)
        or a
        jr z,.mt
        ld a,(ix+SL_PRIO)
        cp b
        jr z,.mt
        ret nc
.mt:    ld (ix+SL_PTR),e
        ld (ix+SL_PTR+1),d
        ld (ix+SL_CNT),0
        ld (ix+SL_PRIO),b
        ret

; silence every effect (keeps HL)
sfx_stop:
        push hl
        push bc
        ld hl,hslot0
        call clr_hslots
        ld hl,mslot0
        ld b,3*SL_SIZE
.c:     ld (hl),0
        inc hl
        djnz .c
        pop bc
        pop hl
        ld a,(snd_mode)
        or a
        ret nz
        jp out_off

; ---------------------------------------------------------------------
; ticks: snd_tick at each VBLANK start (from poll or the mixer), snd_half
; at each VBLANK end (from poll).  Keep every register except AF.
; ---------------------------------------------------------------------
snd_tick:
        push ix
        push iy
        ld a,(mus_on)
        or a
        jr z,.nm
        ld ix,mvoice0
        call mv_tick
        ld ix,mvoice1
        call mv_tick
        ld ix,mvoice2
        call mv_tick
.nm:    ld a,(snd_mode)
        or a
        jr z,.hw
        ld ix,mslot0
        call sl_tick
        ld ix,mslot1
        call sl_tick
        ld ix,mslot2
        call sl_tick
        call mx_apply
        pop iy
        pop ix
        ret
.hw:    call hw_sub
        pop iy
        pop ix
        ret

snd_half:
        ld a,(snd_mode)
        or a
        ret nz
        push ix
        call hw_sub
        pop ix
        ret

; ---------------------------------------------------------------------
; music voice tick (IX = voice).  Stream bytes:
;   00 rest, 01-5F note (1 = C1), 60-7F length 1-32 ticks, 80-8F
;   instrument, 91 nn length nn, FE dw jump, FF stop
; ---------------------------------------------------------------------
mv_tick:
        ld a,(ix+MV_PTR+1)
        or a
        jr nz,.act
        ld (ix+MV_DUTY),a
        ret
.act:   inc (ix+MV_AGE)
        bit 7,(ix+MV_FLAGS)
        jr nz,.env
        ld a,(ix+MV_DUTY)               ; envelope: fall to the floor
        sub (ix+MV_DECAY)
        jr c,.fl
        cp (ix+MV_DMIN)
        jr nc,.dok
.fl:    ld a,(ix+MV_DMIN)
.dok:   ld (ix+MV_DUTY),a
        bit 1,(ix+MV_FLAGS)             ; vibrato after the attack
        jr z,.env
        ld a,(ix+MV_AGE)
        cp 12
        jr c,.env
        ld l,(ix+MV_BASE)
        ld h,(ix+MV_BASE+1)
        ld a,l                          ; DE = base / 128
        rla
        ld a,h
        rla
        ld e,a
        ld a,0
        rla
        ld d,a
        ld a,(ix+MV_AGE)
        and 4
        jr z,.up
        or a
        sbc hl,de
        jr .sv
.up:    add hl,de
.sv:    ld (ix+MV_FRQ),l
        ld (ix+MV_FRQ+1),h
.env:   dec (ix+MV_WAIT)
        ret nz
        ld l,(ix+MV_PTR)
        ld h,(ix+MV_PTR+1)
.next:  ld a,(hl)
        inc hl
        cp 60h
        jr c,.note
        cp 80h
        jr c,.len
        cp 90h
        jr c,.ins
        cp 91h
        jr z,.llen
        cp 0FEh
        jr z,.jump
        ld (ix+MV_PTR+1),0              ; FF: the end
        ld (ix+MV_DUTY),0
        ret
.len:   sub 5Fh
        ld (ix+MV_LEN),a
        jr .next
.llen:  ld a,(hl)
        inc hl
        ld (ix+MV_LEN),a
        jr .next
.jump:  ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jr .next
.ins:   and 0Fh
        push hl
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,INSTRUMENTS
        add hl,de
        ld a,(hl)
        ld (ix+MV_DSTART),a
        inc hl
        ld a,(hl)
        ld (ix+MV_DECAY),a
        inc hl
        ld a,(hl)
        ld (ix+MV_DMIN),a
        inc hl
        ld a,(hl)
        ld (ix+MV_FLAGS),a
        pop hl
        jr .next
.note:  ld (ix+MV_PTR),l
        ld (ix+MV_PTR+1),h
        ld (ix+MV_NOTE),a
        ld b,a
        ld a,(ix+MV_LEN)
        ld (ix+MV_WAIT),a
        ld a,b
        or a
        jr z,.rest
        add a,a
        ld e,a
        ld d,0
        ld hl,NOTE_STEP-2
        add hl,de
        ld a,(hl)
        ld (ix+MV_FRQ),a
        ld (ix+MV_BASE),a
        inc hl
        ld a,(hl)
        ld (ix+MV_FRQ+1),a
        ld (ix+MV_BASE+1),a
        ld a,(ix+MV_DSTART)
        ld (ix+MV_DUTY),a
        res 7,(ix+MV_FLAGS)
        ld (ix+MV_AGE),0
        ret
.rest:  ld (ix+MV_DUTY),0
        set 7,(ix+MV_FLAGS)
        ret

; ---------------------------------------------------------------------
; mixer effect slot tick (IX = slot)
; segment: frames, step(2), step change(2), duty, duty change, mode, arg
; ---------------------------------------------------------------------
sl_tick:
        ld l,(ix+SL_PTR)
        ld h,(ix+SL_PTR+1)
        ld a,h
        or a
        ret z
        ld a,(ix+SL_CNT)
        or a
        jr z,.load
        dec (ix+SL_CNT)
        jr z,.load
        ld l,(ix+SL_FRQ)
        ld h,(ix+SL_FRQ+1)
        ld e,(ix+SL_DF)
        ld d,(ix+SL_DF+1)
        add hl,de
        ld (ix+SL_FRQ),l
        ld (ix+SL_FRQ+1),h
        ld a,(ix+SL_DD)
        or a
        ret z
        ld b,a
        ld a,(ix+SL_DUTY)
        bit 7,b
        jr nz,.neg
        add a,b
        jr nc,.ds
        ld a,255
        jr .ds
.neg:   add a,b
        jr c,.ds
        xor a
.ds:    ld (ix+SL_DUTY),a
        ret
.load:  ld a,(hl)
        or a
        jr nz,.seg
        ld (ix+SL_PTR),a                ; finished
        ld (ix+SL_PTR+1),a
        ld (ix+SL_PRIO),a
        ret
.seg:   ld (ix+SL_CNT),a
        push ix
        pop de
        inc de
        inc de
        inc de                          ; DE = slot + SL_FRQ
        inc hl
        ld bc,8
        ldir
        ld (ix+SL_PTR),l
        ld (ix+SL_PTR+1),h
        ret

; ---------------------------------------------------------------------
; mixer: copy the voices into the sample loop (once per field)
; ---------------------------------------------------------------------
mx_apply:
        ld ix,mslot0
        ld iy,mvoice0
        call .src
        ld (mx_stepA),hl
        ld (ml_pa+1),a
        ld ix,mslot1
        ld iy,mvoice1
        call .src
        ld (mx_stepB),hl
        ld (ml_pb+1),a
        ld ix,mslot2
        ld iy,mvoice2
        call .src
        ld (mx_stepC),hl
        ld (ml_pc+1),a
        ld a,c
        cp 1
        ld a,7Ch                        ; ld a,ixh: a tone
        jr nz,.t
        ld hl,1                         ; noise: read program bytes, one a sample,
        ld (mx_stepC),hl                ; from somewhere in 2000h-5FFFh
        call rnd_snd
        ld a,h
        and 3Fh
        add a,20h
        ld h,a
        ld (mx_accC),hl
        ld a,7Eh                        ; ld a,(ix+0)
.t:     ld (ml_mc+1),a
        ret
; IX = effect slot, IY = music voice -> HL = step, A = duty, C = mode
.src:   ld a,(ix+SL_PTR+1)
        or a
        jr z,.mus
        ld c,(ix+SL_MODE)
        ld l,(ix+SL_FRQ)
        ld h,(ix+SL_FRQ+1)
        ld a,c
        cp 2
        jr nz,.sd
        push hl                         ; rumble: a random step on top
        call rnd_snd
        ld a,h
        and (ix+SL_ARG)
        ld h,a
        pop de
        add hl,de
        ld c,0
.sd:    ld a,(ix+SL_DUTY)
        jr .mute
.mus:   ld a,(mus_on)
        or a
        jr z,.z
        ld a,(iy+MV_PTR+1)
        or a
        jr z,.z
        ld l,(iy+MV_FRQ)
        ld h,(iy+MV_FRQ+1)
        ld a,(iy+MV_FLAGS)
        and 1
        ld c,a
        ld a,(iy+MV_DUTY)
.mute:  ld b,a
        ld a,(snd_mute)
        or a
        ld a,b
        ret z
.z:     xor a
        ld c,a
        ret

; HL = random (16-bit xorshift; the game's own rand is left alone)
rnd_snd:
        ld hl,(snd_seed)
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
        ld (snd_seed),hl
        ret

; ---------------------------------------------------------------------
; mix_wait: play the mixer until B more VBLANKs have started (B >= 1).
; Returns at the start of a VBLANK.  Keeps BC, DE, HL, IX.
; ---------------------------------------------------------------------
mix_wait:
        ld a,b
        or a
        ret z
        push bc
        push de
        push hl
        push ix
        ld (mx_left),a
        call poll                       ; catch an edge that just went by
        ld a,(pollcmp+1)
        call mx_cond
mx_go:  call mx_catchup
        exx
        ld hl,(mx_accB)
        ld de,(mx_stepB)
        exx
        ld hl,(mx_accA)
        ld de,(mx_stepA)
        ld bc,(mx_stepC)
        ld ix,(mx_accC)
        ; --- the sample loop: 216 T (223 with noise), ~16.4 kHz.  Voice A
        ; is heard for 84 T of it, B for 69, C for 63.
mloop:  add hl,de                       ; 11  voice A
        ld a,h                          ; 4
ml_pa:  cp 0                            ; 7   duty A
        sbc a,a                         ; 4
        and 08h                         ; 7
        or SPK_LO                       ; 7
        ld (CTRL),a                     ; 13
        ld a,(KEYPC)                    ; 13  VBLANK edge?
        rla                             ; 4
ml_cond: jp nc,mx_edge                  ; 10  (patched: jp c / jp nc)
ml_b:   exx                             ; 4   voice B
        add hl,de                       ; 11
        ld a,h                          ; 4
ml_pb:  cp 0                            ; 7
        sbc a,a                         ; 4
        and 08h                         ; 7
        or SPK_LO                       ; 7
        ld (CTRL),a                     ; 13
        exx                             ; 4
        add ix,bc                       ; 15  voice C
ml_mc:  ld a,ixh                        ; 8   (ld a,(ix+0) for noise: 19)
        nop                             ; 4
ml_pc:  cp 0                            ; 7
        sbc a,a                         ; 4
        and 08h                         ; 7
        or SPK_LO                       ; 7
        ld (CTRL),a                     ; 13
        jp mloop                        ; 10

mx_edge:
        ld a,(KEYPC)                    ; the new level: play on it
        and 80h
        ld (pollcmp+1),a                ; poll must not count this edge again
        push af
        or a
        ld a,0D2h                       ; level 1: leave on NC
        jr nz,$+4
        ld a,0DAh                       ; level 0: leave on C
        ld (ml_cond),a
        pop af
        push hl
        ld hl,vblev+1
        cp (hl)
        pop hl
        jr z,.vbs
        ld a,(joy_on)                   ; the blank ended: the joystick's
        or a                            ; buttons show now
        call nz,joy_btns
        jp ml_b                         ; straight back
.vbs:
        ld (mx_accA),hl                 ; a VBLANK starts: one field gone
        ld (mx_accC),ix
        exx
        ld (mx_accB),hl
        exx
        call mx_stamp                   ; HL = counter 1
        ld a,(joy_on)
        or a
        call nz,joy_edge                ; the joystick's pulses start now
        ld hl,fieldcnt
        inc (hl)
        call snd_tick
        ld hl,mx_left
        dec (hl)
        jp nz,mx_go
        ld a,SPK_LO                     ; rest the speaker while the caller works
        ld (CTRL),a
        pop ix
        pop hl
        pop de
        pop bc
        ret

; The voices stop while the program works.  So that the tune keeps its
; pitch, each voice's phase moves on by the samples it missed (scan lines
; from 8253 counter 1: one line = 227 T = 1.052 samples).
mx_stamp:
        call read_ctr1
        ld (mx_tout),hl
        ret

CATCH_K         equ 10                  ; samples from the counter read to the loop

mx_catchup:
        call read_ctr1
        ex de,hl
        ld hl,(mx_tout)
        or a
        sbc hl,de                       ; lines missed
        ld b,h                          ; BC = lines + lines/16 - lines/128
        ld c,l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        add hl,bc
        srl b
        rr c
        srl b
        rr c
        srl b
        rr c
        srl b
        rr c
        srl b
        rr c
        srl b
        rr c
        srl b
        rr c
        or a
        sbc hl,bc
        ld bc,CATCH_K                   ; + this routine's own time
        add hl,bc
        ld b,h
        ld c,l
        push bc
        ld hl,(mx_accA)
        ld de,(mx_stepA)
        call adv_acc
        ld (mx_accA),hl
        pop bc
        push bc
        ld hl,(mx_accB)
        ld de,(mx_stepB)
        call adv_acc
        ld (mx_accB),hl
        pop bc
        ld a,(ml_mc+1)
        cp 7Ch
        ret nz                          ; noise: no phase to keep
        ld hl,(mx_accC)
        ld de,(mx_stepC)
        call adv_acc
        ld (mx_accC),hl
        ret

; HL = HL + DE * BC (mod 65536)
adv_acc:
        push hl
        push bc
        ld hl,0
        ld a,c
        ld b,8
.m1:    add hl,hl
        add a,a
        jr nc,.n1
        add hl,de
.n1:    djnz .m1
        pop bc
        ld a,b
        or a
        jr z,.d                         ; under 256 samples: done
        ld c,b
        xor a
        ld b,8
.m2:    add a,a
        sla c
        jr nc,.n2
        add a,e
.n2:    djnz .m2
        add a,h
        ld h,a
.d:     pop de
        add hl,de
        ret

; A = bit-7 level to keep playing on: patch the exit test
mx_cond:
        or a
        ld a,0D2h                       ; level 1: leave on NC
        jr nz,.s
        ld a,0DAh                       ; level 0: leave on C
.s:     ld (ml_cond),a
        ret

; ---------------------------------------------------------------------
; flight: the tone generator
; ---------------------------------------------------------------------
; In flight poll can miss VBLANK edges while the view is drawn, so the
; ticks follow 8253 counter 1 instead: a half tick every 156 scan lines,
; with any that were missed caught up at once.
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
        jr z,hs_out
        ld a,(hw_par)                   ; both busy: take turns
        rra
        jr nc,hs_out
        ld ix,hslot1
        jr hs_out
.s1:    ld ix,hslot1
        or a
        jr nz,hs_out
        ; no effect: the music voices take turns
        ld a,(mus_on)
        or a
        jp z,out_off
        ld ix,mvoice0
        call mv_sounds
        ld c,a
        ld ix,mvoice1
        call mv_sounds
        add a,a
        or c
        jr nz,.some
        ld ix,mvoice2
        call mv_sounds
        jp z,out_off
        jr .play
.some:  ld ix,mvoice0
        cp 3
        jr nz,.one
        ld a,(hw_par)
        rra
        jr nc,.play
        ld ix,mvoice1
        jr .play
.one:   bit 0,c
        jr nz,.play
        ld ix,mvoice1
.play:  ld a,(ix+MV_NOTE)
        add a,a
        ld e,a
        ld d,0
        ld hl,NOTE_DIV-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp out_div

; A = 1 (NZ) if music voice IX is sounding
mv_sounds:
        ld a,(ix+MV_PTR+1)
        or a
        ret z
        ld a,(ix+MV_NOTE)
        or a
        ret z
        ld a,(ix+MV_DUTY)
        cp 10h
        ld a,0
        jr c,.n
        inc a
.n:     or a
        ret

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
