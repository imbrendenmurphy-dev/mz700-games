; =====================================================================
;  joy.asm - Sharp MZ-1X03 joystick in port 1 (E008h bits 1-4)
; =====================================================================
; How the MZ-1X03 is read, as the MiSTer SharpMZ core and the MZRaku
; emulator model it (neither is a hardware measurement, so this is
; untested on a real stick):
;   - At the start of vertical blank each axis line goes low for a time
;     set by the stick: ~0 lines held left/up, ~16-19 lines centred,
;     ~32-37 lines held right/down.  Bit 1 = stick 1 X, bit 2 = stick 1 Y
;     (bits 3/4 are stick 2, not used here).
;   - While the picture is shown the same lines carry the fire buttons:
;     bit 1 = fire 1, bit 2 = fire 2, low = pressed.
; So the stick is sampled twice after the blanking starts (lines 4-10:
; still low unless held left/up; lines 21-26: low only if held right/down) and the
; buttons once during the picture.  joy_service does the sampling from
; poll and from the flush loop; joy_bits turns the samples into K_ bits.
; Nothing counts as pressed until that line has shown a normal reading
; (a pulse that ends, or a released button), so an empty port or a stuck
; line can't hold Kiko in one direction.
JOYP            equ 0E008h
JS1_LO          equ 4               ; first sample window (lines after VBLANK)
JS1_HI          equ 11
JS2_LO          equ 21              ; second sample window
JS2_HI          equ 27

; lines since the last VBLANK start -> HL.  Keeps BC.
joy_lines:
        push de
        call read_ctr1
        ex de,hl
        ld hl,(vb_ctr)
        or a
        sbc hl,de                   ; counter 1 counts lines down
        pop de
        ret

; take whichever sample is due now (keeps every register except AF).
; Buttons: any time the picture is showing.  Stick: in the blanking, at
; the right lines, and only when this field's VBLANK start was caught
; on time (vb_ok) - a late edge would put the windows in the wrong place.
joy_service:
        push hl
        ld a,(KEYPC)
        and 80h
        ld l,a
        ld a,(vblev+1)              ; the level during VBLANK
        cp l
        jr nz,.btn
        ld a,(vb_ok)
        or a
        jr z,.x
        call joy_lines
        ld a,h
        or a
        jr nz,.x
        ld a,l
        cp JS1_LO
        jr c,.x
        cp JS1_HI
        jr c,.s1
        cp JS2_LO
        jr c,.x
        cp JS2_HI
        jr nc,.x
        ld a,(JOYP)
        ld (joy_s2),a
        ld hl,joy_got
        set 1,(hl)
        pop hl
        ret
.btn:   ld a,(JOYP)                 ; read, then check the picture is
        ld h,a                      ; still showing (the pulses start
        ld a,(KEYPC)                ; the moment VBLANK does)
        and 80h
        cp l
        jr nz,.x
        ld a,(joy_braw)             ; and pressed in two reads running
        ld l,a
        ld a,h
        ld (joy_braw),a
        or l
        ld (joy_btn),a
.x:     pop hl
        ret
.s1:    ld a,(JOYP)
        ld (joy_s1),a
        ld hl,joy_got
        set 0,(hl)
        pop hl
        ret

; game frame, after the flush: stay until the second stick sample of
; this field has been taken (at most ~29 lines into the blanking)
joy_catch:
        ld a,(joy_on)
        or a
        ret z
        ld a,(vb_ok)
        or a
        ret z
        push hl
.l:     call joy_service
        ld a,(joy_got)
        bit 1,a
        jr nz,.x
        call joy_lines
        ld a,h
        or a
        jr nz,.x
        ld a,l
        cp JS2_HI
        jr c,.l
.x:     pop hl
        ret

; C |= the stick's K_ bits.  Keeps HL.
joy_bits:
        push de
        ld a,(joy_s1)
        ld d,a
        ld a,(joy_s2)
        ld e,a
        ; a pulse that is low at the first sample and over by the second is
        ; a centred stick: that line works
        ld a,d
        cpl
        and e
        and 06h
        ld b,a
        ld a,(joy_seen)
        or b
        ld (joy_seen),a
        ld b,a
        ; X: bit 1
        bit 1,b
        jr z,.ny
        bit 1,d
        jr z,.xr
        ld a,c                      ; over at once: left
        or K_LEFT
        ld c,a
        jr .ny
.xr:    bit 1,e
        jr nz,.ny
        ld a,c                      ; still low: right
        or K_RIGHT
        ld c,a
.ny:    ; Y: bit 2
        bit 2,b
        jr z,.nb
        bit 2,d
        jr z,.yd
        ld a,c
        or K_UP
        ld c,a
        jr .nb
.yd:    bit 2,e
        jr nz,.nb
        ld a,c
        or K_DOWN
        ld c,a
.nb:    ; buttons: count only after the line has been seen released
        ld a,(joy_btn)
        ld d,a
        and 06h
        rlca
        rlca                        ; released bits -> 3,4 of joy_seen
        ld e,a
        ld a,(joy_seen)
        or e
        ld (joy_seen),a
        ld b,a
        bit 3,b
        jr z,.n1
        bit 1,d
        jr nz,.n1
        ld a,c                      ; fire 1: jump
        or K_JUMP
        ld c,a
.n1:    bit 4,b
        jr z,.n2
        bit 2,d
        jr nz,.n2
        ld a,c                      ; fire 2: tongue, or with UP: colour
        and K_UP
        ld a,K_TONGUE
        jr z,$+4
        ld a,K_SWAP
        or c
        ld c,a
.n2:    pop de
        ret

; NZ if a joystick button is held (demo abort)
joy_fire:
        ld a,(joy_on)
        or a
        ret z
        push bc
        ld c,0
        call joy_bits
        ld a,c
        and K_JUMP|K_TONGUE|K_SWAP
        pop bc
        ret

; turn the joystick on or off
joy_toggle:
        ld a,(joy_on)
        xor 1
        ld (joy_on),a
        xor a
        ld (joy_seen),a
        ld a,0FFh
        ld (joy_s1),a               ; "left, released" until sampled
        ld (joy_s2),a
        ld (joy_btn),a
        ret

; J key newly pressed?  NZ if so
j_pressed:
        ld a,3                      ; row 3 bit 6 = J
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        and 40h
        ld b,a
        ld a,(j_prev)
        cpl
        and b
        ld c,a
        ld a,b
        ld (j_prev),a
        ld a,c
        or a
        ret

; ---------------------------------------------------------------------
; joystick set-up and test screen (J on the title pages)
; ---------------------------------------------------------------------
joy_screen:
        ld a,(joy_on)
        set 1,a                     ; keep sampling while testing
        ld (joy_on),a
        xor a
        call cls
        xor a
        call rainbow_row
        ld a,24
        call rainbow_row
        ld hl,txt_joy
        ld c,2
        ld a,60h
        call print_centre
        ld hl,JOYTXT
.l:     ld a,(hl)
        inc hl
        cp 0FFh
        jr z,.go
        ld c,a
        ld a,(hl)
        inc hl
        ld b,a
        ld a,(hl)
        inc hl
        push af
        call vaddr
        pop af
        ld c,a
        call print
        jr .l
.go:    call fe_reset
        ld a,40h
        ld (j_prev),a               ; the J that opened this page
.f:     call joy_measure
        call joy_show
        call j_pressed
        jr z,.nj
        call joy_toggle             ; bit 1 (testing) stays set
        ld hl,SFX_SELECT
        ld a,4
        call sfx
.nj:    ld a,6                      ; SPACE (keyboard) goes back
        ld (KEYPA),a
        ld a,(KEYPB)
        and 10h
        jr nz,.f
        ld a,(joy_on)
        res 1,a
        ld (joy_on),a
        jp wait_release

; one field: from the VBLANK start, the length of the low pulse on each
; of bits 1-4 in lines (60 = never went high) -> joy_w[0..3]
joy_measure:
        ld a,(fieldcnt)
        ld b,a
.w:     call poll
        ld a,(fieldcnt)
        cp b
        jr z,.w
        ld hl,joy_w
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
.m:     call joy_lines              ; (no VBLANK edge in these 60 lines)
        ld a,h
        or a
        ret nz
        ld a,l
        cp 60
        ret nc
        cp JS2_HI
        call c,joy_service          ; the game's own samples too
        ld a,l
        inc a
        ld c,a
        ld a,(JOYP)
        ld b,a
        cpl
        and 1Eh
        jr z,.m                     ; all high: nothing to record
        ld hl,joy_w
        srl b                       ; bit 0: not the stick
        ld e,4
.b:     srl b
        jr c,$+3
        ld (hl),c
        inc hl
        dec e
        jr nz,.b
        jr .m

joy_show:
        ; on / off
        ld a,(joy_on)
        and 1
        ld hl,txt_joyoff
        ld a,20h
        jr z,$+7
        ld hl,txt_joyon
        ld a,40h
        ld c,a
        ld b,29
        push bc
        ld c,5
        call vaddr
        pop bc
        call print
        ; what the game sees
        ld c,0
        call joy_bits
        ld a,c
        ld (joy_seen_k),a
        ld hl,JOYLIVE
        ld b,6
.k:     push bc
        ld a,(hl)                   ; K_ bit
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)                   ; VRAM
        inc hl
        ld c,(hl)                   ; length
        inc hl
        ld b,a
        ld a,(joy_seen_k)
        and b
        ld a,70h                    ; lit: white on blue
        jr nz,$+4
        ld a,10h                    ; idle: blue on black
        ld b,c
        set 3,d
.kc:    ld (de),a
        inc de
        djnz .kc
        pop bc
        djnz .k
        ; raw pulse lengths
        ld hl,joy_w
        ld de,VRAM+40*16+7
        ld b,4
.w:     ld a,(hl)
        inc hl
        push bc
        call put2
        inc de
        inc de
        inc de
        inc de
        pop bc
        djnz .w
        ; raw button lines during the picture: 1 = up, 0 = pressed
        ld a,(joy_btn)
        ld de,VRAM+40*19+6
        ld b,4
        rrca
.r:     rrca
        push af
        ld a,20h
        adc a,0
        ld c,70h
        call putc
        inc de
        inc de
        inc de
        inc de
        inc de
        inc de
        pop af
        djnz .r
        ret

; A (0-99) as two digits at DE (DE += 2), white
put2:
        ld b,0
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     push af
        ld a,b
        add a,20h
        ld c,70h
        call putc
        inc de
        pop af
        add a,20h
        call putc
        inc de
        ret

txt_joy:        db "JOYSTICK",0
txt_joyon:      db "ON ",0
txt_joyoff:     db "OFF",0
JOYTXT:
        db 5,4,70h,  "SHARP MZ-1X03 IN PORT 1:",0
        db 7,4,70h,  "STICK ...... RUN, CLIMB, DUCK",0
        db 8,4,70h,  "FIRE 1 ................. JUMP",0
        db 9,4,70h,  "FIRE 2 ............... TONGUE",0
        db 10,4,70h, "UP + FIRE 2 ... CHANGE COLOUR",0
        db 11,4,50h, "  (THE KEYS STILL WORK TOO)",0
        db 13,4,60h, "TEST:",0
        db 13,10,10h,"LEFT RIGHT UP DOWN F1 F2",0
        db 15,4,50h, "PULSE AFTER VBLANK (LINES)",0
        db 16,4,70h, "X1    Y1    X2    Y2",0
        db 18,4,50h, "LINES IN THE PICTURE (0=LOW)",0
        db 19,4,70h, "1     2     3     4",0
        db 21,4,60h, "J ON/OFF          SPACE BACK",0
        db 0FFh
; the test row: K_ bit, VRAM address, length
JOYLIVE:
        db K_LEFT
        dw VRAM+40*13+10
        db 4
        db K_RIGHT
        dw VRAM+40*13+15
        db 5
        db K_UP
        dw VRAM+40*13+21
        db 2
        db K_DOWN
        dw VRAM+40*13+24
        db 4
        db K_JUMP
        dw VRAM+40*13+29
        db 2
        db K_TONGUE|K_SWAP
        dw VRAM+40*13+32
        db 2
