; =====================================================================
;  joy.asm - the MZ-700's two joystick ports (Sharp MZ-1X03)
;
;  E008h bits 1-4 are JA1, JA2, JB1, JB2: stick A's X and Y, stick B's X
;  and Y.  While the picture is drawn they are the fire buttons (low =
;  pressed: bits 1-2 stick A's two buttons, 3-4 stick B's).  From the start
;  of vertical blank each goes low for 68 + 28 x position T-states
;  (position 0 = left/up, 128 = centre, 255 = right/down): at most about
;  32 scan lines.  (As modelled by mz800emu and the MiSTer SharpMZ core.)
;
;  We only need 8 directions, so each tick samples the bits twice, timed
;  on counter 1 from the vertical blank: at line 10 (position ~80) a bit
;  that has already gone high means left/up, and at line 22 (~176) one
;  that is still low means right/down.  The first sample comes before the
;  screen flush and the second after it, so it costs next to nothing.
;  Ticks that are catching up (not at a vertical blank) keep the last
;  reading.
;
;  ctlmode: 0 keyboard, 1 twin joysticks (A moves, B fires),
;           2 one joystick (A moves; hold fire to shoot the way you face,
;             strafing).  The keyboard works in every mode.
; =====================================================================

; in the display: the fire buttons -> joyfire (bits 1-4, 1 = pressed).
; Keeps every register but AF.
joy_fire:
        ld a,(SNDGATE)
        cpl
        and 1Eh
        ld (joyfire),a
        ret

; A = scan lines since this tick's vertical blank started (max 255)
joy_lines:
        push de
        push hl
        call read_ctr1
        ex de,hl
        ld hl,(duectr)
        or a
        sbc hl,de
        ld a,h
        or a
        ld a,l
        jr z,.k
        ld a,255
.k:     pop hl
        pop de
        ret

joy_sample1:                    ; right after wait_vblank
        ld a,(ctlmode)
        or a
        ret z
        ld a,(synced)
        or a
        ret z
.w:     call joy_lines
        cp 10
        jr c,.w
        ld a,(SNDGATE)
        ld (joys1),a
        ret

joy_sample2:                    ; after the flush
        ld a,(ctlmode)
        or a
        ret z
        ld a,(synced)
        or a
        ret z
.w:     call joy_lines
        cp 22
        jr c,.w
        ld a,(SNDGATE)
        ld b,a                  ; B = second sample, C = first
        ld a,(joys1)
        ld c,a
        ld d,1                  ; stick A: bits 1 (X) and 2 (Y)
        call .stick
        ld (joymv),a
        ld d,3                  ; stick B: bits 3 and 4
        call .stick
        ld (joyfr),a
        ret
; D = X bit number (Y is the next): A = K_ direction bits
.stick: ld e,0
        ld a,d
        call .axis              ; X: left / right
        jr z,.x1
        jr c,.xl
        set 3,e                 ; right
        jr .x1
.xl:    set 2,e                 ; left
.x1:    ld a,d
        inc a
        call .axis              ; Y: up / down
        jr z,.y1
        jr c,.yu
        set 1,e                 ; down
        jr .y1
.yu:    set 0,e                 ; up
.y1:    ld a,e
        ret
; A = bit number: Z = centre, C = negative (left/up), NC+NZ = positive
.axis:  push bc
        ld l,a
        ld h,1
.m:     dec l                   ; H = 1 << bit
        jr z,.got
        sla h
        jr .m
.got:   sla h
        ld a,c                  ; ended by line 10: pushed left/up
        and h
        jr nz,.neg
        ld a,b                  ; still low at line 22: pushed right/down
        and h
        jr z,.pos
        pop bc
        xor a                   ; Z, NC: centre
        ret
.neg:   pop bc
        or 1                    ; NZ
        scf                     ; C
        ret
.pos:   pop bc
        or 1                    ; NZ, NC
        ret

; after the keyboard scan: add the joysticks to mkeys / fkeys
joy_merge:
        ld a,(ctlmode)
        or a
        ret z
        ld a,(joymv)
        ld b,a
        ld a,(mkeys)
        or b
        call cancel_opp
        ld (mkeys),a
        ld a,(ctlmode)
        cp 1
        jr nz,.one
        ld a,(joyfr)            ; twin sticks: B aims
        ld b,a
        ld a,(fkeys)
        or b
        call cancel_opp
        ld (fkeys),a
        ret
.one:   ld a,(joyfire)          ; one stick: hold fire to shoot ahead
        or a
        jr nz,.shoot
        ld a,(joymv)            ; not firing: face the way you move
        or a
        ret z
        ld (facing),a
        ret
.shoot: ld a,(facing)
        or a
        jr nz,.f
        ld a,K_UP
.f:     ld b,a
        ld a,(fkeys)
        or b
        call cancel_opp
        ld (fkeys),a
        ret

; any fire button counts as SPACE (to start) in the joystick modes:
; called with C = the special-key bits being built in read_keys
joy_specials:
        ld a,(ctlmode)
        or a
        ret z
        ld a,(joyfire)
        or a
        ret z
        set 0,c                 ; KS_SPACE
        ret
