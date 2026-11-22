; =====================================================================
;  joy.asm - a Sharp MZ-1X03 joystick in port A (J on the title)
;
;  E008h bits 1 and 2 are stick A's X and Y.  While the picture is drawn
;  they are its two buttons (low = pressed): button 1 fires, button 2
;  bombs.  From the start of vertical blank each goes low for a time set
;  by the stick's position.  Ticks that are catching up keep the last
;  reading.  Not yet tried on a real stick.  It is off by default: an
;  empty socket reads as up + left.
; =====================================================================

; in the display: the buttons -> joyfire (bits 1-2, 1 = pressed)
joy_fire:
        ld a,(joyon)
        or a
        ret z
        push bc
        ld a,(SNDGATE)          ; read the buttons first,
        ld b,a
        ld a,(PPIC)             ; then keep it only if still in the picture
        ld c,a
        ld a,(polx)
        xor c
        rla
        ld a,b
        pop bc
        ret nc
        cpl
        and 06h
        ld (joyfire),a
        ret

; right at the vertical blank (after wait_tick): time both pulses by
; counting loop passes until each bit goes high.  The first reading after
; J is the centre; a stick a quarter of the way either side of it is a
; direction.  (Timing the pulses, rather than sampling at fixed lines,
; works with either model of the MZ-1X03: 68 + 28 x position T, or
; 6750 +- 3500 T.)  Costs up to ~55 scan lines while the stick is on.
joy_sample1:
        ld a,(joyon)
        or a
        ret z
        ld a,(synced)
        or a
        ret z
        ld hl,SNDGATE
        ld d,0
        ld bc,0
.l:     inc d
        jr z,.done
        ld a,(hl)
        bit 1,a
        jr nz,.xh
        ld b,d                  ; X still low
.xh:    bit 2,a
        jr nz,.yh
        ld c,d                  ; Y still low
.yh:    and 6
        cp 6
        jr nz,.l
.done:  ld a,(joycal)
        or a
        jr nz,.dir
        ld a,b                  ; the first reading: the centre
        ld (joycx),a
        ld a,c
        ld (joycy),a
        ld a,1
        ld (joycal),a
        ret
.dir:   ld e,0
        ld a,(joycx)
        call .axis
        jr z,.x1
        jr c,.xl
        set 3,e                 ; right
        jr .x1
.xl:    set 2,e                 ; left
.x1:    ld b,c
        ld a,(joycy)
        call .axis
        jr z,.y1
        jr c,.yu
        set 1,e                 ; down
        jr .y1
.yu:    set 0,e                 ; up
.y1:    ld a,e
        ld (joymv),a
        ret
; A = centre, B = reading: Z centre, C below, NC+NZ above
.axis:  ld h,a
        srl a
        srl a                   ; quarter
        ld l,a
        ld a,h
        sub l
        cp b
        jr nc,.lo               ; reading <= centre - quarter
        ld a,h
        add a,l
        jr c,.mid
        cp b
        jr c,.hi                ; reading > centre + quarter
.mid:   xor a
        ret
.lo:    or 1
        scf
        ret
.hi:    or 1
        ret

joy_sample2:
        ret

; C = key bits being built: add the stick and its buttons
joy_keys:
        ld a,(joyon)
        or a
        ret z
        ld a,(joymv)
        or c
        ld c,a
        ld a,(joyfire)
        bit 1,a
        jr z,.b
        set 4,c                 ; K_FIRE
.b:     bit 2,a
        ret z
        set 5,c                 ; K_BOMB
        ret
