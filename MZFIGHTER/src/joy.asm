; =====================================================================
;  joy.asm - Sharp MZ-1X03 joysticks (optional, J on the title)
;
;  E008h bits 1-4 = stick A X, A Y, stick B X, B Y (active low).  While
;  the picture is drawn they carry the buttons (bit 1 = A SW1, bit 2 = A
;  SW2, bits 3/4 = B).  From the start of VBLANK each axis line is low for
;  a time set by the stick position.  joy_frame catches the VBLANK edge,
;  times all four pulses at once, and turns them into IN_* bits through a
;  centre learnt when the option is switched on (so the real 270+28*pos T
;  timing and the emulator's model both work; an empty socket learns 0
;  and is ignored).  Waiting for the edge costs up to a field per frame,
;  which is why the option is off by default.
; =====================================================================

JOYPORT equ 0E008h
VBLPORT equ 0E002h          ; bit 7 = /VBLK (0 during VBLANK)

; joy_frame: buttons, then the axes after the next VBLANK edge
joy_frame:
        ; buttons: read first, then check it was still the picture
        ld a,(JOYPORT)
        ld c,a
        ld a,(VBLPORT)
        rla
        jr nc,.nob
        ld a,c
        cpl
        ld (joy_btn),a
.nob:   ld a,(joy_alt)          ; the axes every other frame
        xor 1
        ld (joy_alt),a
        jp z,.dirs
        di
.w1:    ld a,(VBLPORT)          ; wait for the picture...
        rla
        jr nc,.w1
.w2:    ld a,(VBLPORT)          ; ...then the start of VBLANK
        rla
        jr c,.w2
        ld a,(mtick)            ; the frame clock restarts at this edge
        ld (frame_tick),a       ; (2 ticks a field, locked to the lines)
        ld b,22                 ; the pulses start ~270 T after the edge
        djnz $
        ld hl,JOYPORT
        ld bc,0
        ld de,0
        exx
        ld b,100                ; ~12000 T at most
        exx
.l:     ld a,(hl)
        or 0E1h
        inc a                   ; all four lines high: done
        jr z,.done
        dec a
        rra
        rra
        jr c,$+3
        inc b                   ; A X
        rra
        jr c,$+3
        inc c                   ; A Y
        rra
        jr c,$+3
        inc d                   ; B X
        rra
        jr c,$+3
        inc e                   ; B Y
        exx
        dec b
        exx
        jr nz,.l
.done:  ei
        ld a,b
        ld (joy_cnt),a          ; A X
        ld a,c
        ld (joy_cnt+1),a        ; A Y
        ld a,d
        ld (joy_cnt+2),a        ; B X
        ld a,e
        ld (joy_cnt+3),a        ; B Y
        ld a,(joy_cal_now)
        or a
        jr z,.dirs
        ; calibrate: these counts are the centres
        xor a
        ld (joy_cal_now),a
        ld hl,joy_cnt
        ld de,joy_cen
        ld bc,4
        ldir
.dirs:  ; stick A -> joy_in1, stick B -> joy_in2
        ld ix,joy_cnt
        ld a,(joy_btn)
        ld c,a
        call .stick
        ld (joy_in1),a
        ld ix,joy_cnt+2
        ld a,(joy_btn)
        rrca
        rrca
        ld c,a
        call .stick
        ld b,a
        ld a,(joy_mode)
        cp 2
        ld a,b
        jr z,$+3
        xor a
        ld (joy_in2),a
        ret
; IX = counts (x, y; centres 4 bytes on), C bits 1/2 = buttons pressed
.stick: ld b,0
        bit 1,c
        jr z,$+4
        set IN_P,b
        bit 2,c
        jr z,$+4
        set IN_K,b
        ld e,(ix+4)             ; X centre
        ld a,(ix+0)
        ld d,IN_L
        call .axis
        ld e,(ix+5)             ; Y centre
        ld a,(ix+1)
        ld d,IN_U
        call .axis
        ld a,b
        ret
; A = count, E = centre, D = low bit (IN_L / IN_U; +1 is the high one)
.axis:  ld h,a
        ld a,e
        cp 4
        ret c                   ; no stick in this socket
        srl a
        ld l,a                  ; centre / 2
        ld a,h
        cp l
        jr nc,.nlo
        ld a,d
        jr .set
.nlo:   ld a,e
        add a,l
        jr nc,$+4
        ld a,255
        cp h
        ret nc                  ; count <= centre * 3/2: middle
        ld a,d
        inc a
.set:   ; set bit A of B
        push bc
        ld c,1
        or a
        jr z,.s1
.s0:    sla c
        dec a
        jr nz,.s0
.s1:    ld a,c
        pop bc
        or b
        ld b,a
        ret

; joy_toggle: OFF -> stick A -> sticks A+B -> OFF (learns the centres)
joy_toggle:
        ld a,(joy_mode)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (joy_mode),a
        ld a,1
        ld (joy_cal_now),a
        xor a
        ld (joy_in1),a
        ld (joy_in2),a
        ret

joy_mode: db 0
joy_alt: db 0
joy_cal_now: db 0
joy_btn: db 0
joy_in1: db 0
joy_in2: db 0
joy_cnt: ds 4               ; A X, A Y, B X, B Y
joy_cen: ds 4
