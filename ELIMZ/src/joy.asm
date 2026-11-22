; =====================================================================
;  joy.asm - the Sharp MZ-1X03 joystick (optional: J on the title)
;
;  The MZ-1X03 is analogue.  It plugs into either joystick socket and
;  is read at E008h: bits 1 and 2 for socket A (stick X, stick Y),
;  bits 3 and 4 for socket B.
;   - From the start of each vertical blank, each axis line gives a
;     pulse whose length follows the stick (Sharp's read routine times
;     it; mz800emu and the MiSTer core use 68 + 28 x position T, so
;     centre is about 16 scan lines and full travel about 32).
;   - While the picture is displayed, the same lines are the two fire
;     switches, SW1 and SW2.
;  Sources disagree on the polarity, so switching the joystick on
;  calibrates it: it learns the lines' resting levels and the stick's
;  centre (so the stick must rest centred, buttons up).
;
;  Pulses are timed in scan lines on 8253 counter 1, from the VBLANK
;  start.  The program does not always see that start at once (poll may
;  be late), so joy_vref keeps the line count of the last VBLANK start
;  and each new one is placed exactly from the field length.  A
;  reading starts only if we are at most JOY_LAG lines late; otherwise
;  it waits for the next field.
; =====================================================================

JOY_LAG         equ 5                   ; lines: later than this, skip a field
JOY_MAX         equ 60                  ; lines: a pulse can't be longer

; A = the joystick's E008h lines, moved so the stick in use is bits 1-2
joy_in:
        ld a,(SNDGATE)
jin_rot:
        nop                             ; socket B: rrca, rrca
        nop
        ret

; ---------------------------------------------------------------------
; joy_read: A = the joystick's K_ bits (0 when it is off): directions
; from the last pulse reading, K_FIRE from SW1; joy_sw2 = 1 while SW2
; is down.  It also asks for a new pulse reading (every frame in
; flight, every other call on the mixer screens, so the music isn't
; broken up).  Keeps BC, DE, HL.
; ---------------------------------------------------------------------
joy_read:
        ld a,(joy_on)
        or a
        ret z
        push hl
        ld a,(snd_mode)
        or a
        jr z,.req
        ld hl,joy_skip                  ; mixer: every other call
        inc (hl)
        bit 0,(hl)
        jr nz,.btn
.req:   ld a,1
        ld (joy_req),a
.btn:   ld a,(KEYPC)                    ; buttons only show while the
        and 80h                         ; picture is displayed
        ld hl,vblev+1
        cp (hl)
        call nz,joy_btns
        ld a,(joy_btn)
        rrca
        rrca
        and 1
        ld (joy_sw2),a
        ld a,(joy_btn)
        and 2
        ld a,(joy_dirs)
        jr z,$+4
        or K_FIRE
        pop hl
        ret

; joy_btn = the switches pressed (bit 1 SW1, bit 2 SW2).  Call only
; while the picture is displayed.  Keeps every register except AF.
joy_btns:
        push hl
        call joy_in
        ld hl,joy_rel
        xor (hl)
        and 6
        ld (joy_btn),a
        pop hl
        ret

; ---------------------------------------------------------------------
; joy_edge: a VBLANK start has been seen, HL = counter 1 now.  Places
; this VBLANK exactly and, if a reading is wanted and we are not too
; late, times the pulses.  Uses every register except IX.
; ---------------------------------------------------------------------
joy_edge:
        ex de,hl                        ; DE = now
        ld hl,(joy_vref)
        or a
        sbc hl,de                       ; lines since the last known start
        ld bc,(joy_fl)
.m:     or a
        sbc hl,bc
        jr nc,.m
        add hl,bc                       ; HL = lines since this one began
        push hl
        add hl,de
        ld (joy_vref),hl
        pop hl
        ld a,(joy_req)
        or a
        ret z
        ld a,h
        or a
        ret nz
        ld a,l
        cp JOY_LAG+1
        ret nc                          ; too late: next field
        xor a
        ld (joy_req),a
        ; fall through

; time both axis pulses (to the line) from joy_vref
joy_pulses:
        ld a,6
        ld (joy_run),a
.l:     call joy_in
        ld hl,joy_end
        xor (hl)
        ld hl,joy_run
        and (hl)                        ; axes whose pulse is still on
        ld c,a
        call read_ctr1
        ex de,hl
        ld hl,(joy_vref)
        or a
        sbc hl,de                       ; lines into the blank
        ld a,h
        or a
        jr nz,.stop
        ld a,l
        cp JOY_MAX
        jr nc,.stop
        ld b,a
        ld a,(joy_run)
        xor c                           ; axes that have just ended
        ld d,a
        ld a,b
        bit 1,d
        jr z,$+5
        ld (joy_len),a
        bit 2,d
        jr z,$+5
        ld (joy_len+1),a
        ld a,c
        ld (joy_run),a
        or a
        jr nz,.l
        jr joy_dirs_calc
.stop:  ld a,(joy_run)                  ; a line stuck on: full travel
        ld d,a
        ld a,JOY_MAX
        bit 1,d
        jr z,$+5
        ld (joy_len),a
        bit 2,d
        jr z,$+5
        ld (joy_len+1),a

; joy_dirs = K_ direction bits from the pulse lengths
joy_dirs_calc:
        ld c,0
        ld a,(joy_len)
        ld hl,joy_lo
        cp (hl)
        jr nc,$+4
        set B_LEFT,c
        ld hl,joy_hi
        cp (hl)
        jr c,$+4
        set B_RIGHT,c
        ld a,(joy_len+1)
        ld hl,joy_lo+1
        cp (hl)
        jr nc,$+4
        set B_UP,c
        ld hl,joy_hi+1
        cp (hl)
        jr c,$+4
        set B_DOWN,c
        ld a,c
        ld (joy_dirs),a
        ret

; from poll, at a VBLANK start
joy_poll:
        call read_ctr1
        jp joy_edge

; ---------------------------------------------------------------------
; wait (busily) for the next VBLANK start: HL = counter 1 there
; ---------------------------------------------------------------------
vb_start:
        ld a,(vblev+1)
        ld b,a
.o:     ld a,(KEYPC)                    ; leave the blank we may be in
        and 80h
        cp b
        jr z,.o
.i:     ld a,(KEYPC)
        and 80h
        cp b
        jr nz,.i
        jp read_ctr1

; ---------------------------------------------------------------------
; joy_toggle (J on the title): HL = the status line to show.
; Off -> on calibrates; on -> off.
; ---------------------------------------------------------------------
joy_toggle:
        ld a,(joy_on)
        or a
        jr z,joy_cal
        xor a
        ld (joy_on),a
        ld (joy_dirs),a
        ld (joy_btn),a
        ld hl,txt_joyoff
        ret

joy_cal:
        call vb_start                   ; the field length, in lines
        ld (joy_vref),hl
        call vb_start
        ex de,hl
        ld hl,(joy_vref)
        or a
        sbc hl,de
        ld (joy_vref),de
        ld bc,-250
        add hl,bc
        jr nc,.std                      ; < 250 lines: odd, assume PAL
        ld bc,250-330
        add hl,bc
        jr c,.std                       ; > 330: likewise
        ld bc,330
        add hl,bc
        jr .fl
.std:   ld hl,312
.fl:    ld (joy_fl),hl
.late:  call read_ctr1                  ; the resting levels: late in the
        ex de,hl                        ; blank, all pulses are over
        ld hl,(joy_vref)
        or a
        sbc hl,de
        ld de,JOY_MAX
        or a
        sbc hl,de
        jr c,.late
        ld a,(SNDGATE)
        ld (joy_rawend),a
        ld a,(vblev+1)                  ; and in the picture
        ld b,a
.pic:   ld a,(KEYPC)
        and 80h
        cp b
        jr z,.pic
        ld a,(SNDGATE)
        ld (joy_rawrel),a
        xor a                           ; socket A
        call joy_try
        jr nc,.ok
        ld a,1                          ; socket B
        call joy_try
        jr nc,.ok
        xor a
        ld (joy_on),a
        ld hl,txt_joynone
        ret
.ok:    ld a,1
        ld (joy_on),a
        xor a
        ld (joy_req),a
        ld (joy_dirs),a
        ld (joy_btn),a
        ld hl,txt_joyon
        ret

; try socket A (A = 0) or B (A = 1): NC if a stick rests centred there
joy_try:
        or a
        ld hl,0                         ; nop, nop
        jr z,$+5
        ld hl,0F0Fh                     ; rrca, rrca
        ld (jin_rot),hl
        ld a,(joy_rawend)
        call .norm
        ld (joy_end),a
        ld a,(joy_rawrel)
        call .norm
        ld (joy_rel),a
        ld hl,0                         ; sum of four readings
        ld (joy_sum),hl
        ld (joy_sum+2),hl
        ld b,4
.r:     push bc
        call vb_start
        ld (joy_vref),hl
        call joy_pulses
        ld hl,(joy_sum)
        ld a,(joy_len)
        call .add
        ld (joy_sum),hl
        ld hl,(joy_sum+2)
        ld a,(joy_len+1)
        call .add
        ld (joy_sum+2),hl
        pop bc
        djnz .r
        ld hl,(joy_sum)                 ; centre X, Y = sum / 4
        srl h
        rr l
        srl h
        rr l
        ld a,l
        call .limits
        ret c
        ld (joy_lo),a
        ld a,b
        ld (joy_hi),a
        ld hl,(joy_sum+2)
        srl h
        rr l
        srl h
        rr l
        ld a,l
        call .limits
        ret c
        ld (joy_lo+1),a
        ld a,b
        ld (joy_hi+1),a
        ret

.add:   add a,l
        ld l,a
        ret nc
        inc h
        ret

; A = centre (lines) -> A = low limit c - c/2, B = high limit c + c/2;
; carry if no stick (the pulse too short to tell, or stuck)
.limits:
        cp 6
        ret c
        cp JOY_MAX-12
        ccf
        ret c
        ld c,a
        srl a
        ld b,a
        add a,c
        push af
        ld a,c
        sub b
        ld c,a
        pop af
        ld b,a
        ld a,c
        or a
        ret

; normalise a raw E008h byte as joy_in does
.norm:  ld hl,jin_rot
        bit 0,(hl)                      ; rrca = 0Fh, nop = 00h
        ret z
        rrca
        rrca
        ret

txt_joyon:      db " JOYSTICK ON - SW1 FIRE  SW2 SEEKER ",0
txt_joyoff:     db "    JOYSTICK OFF: KEYBOARD ONLY     ",0
txt_joynone:    db "  NO JOYSTICK (CENTRE IT, THEN J)   ",0
