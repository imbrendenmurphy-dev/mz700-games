; =====================================================================
;  sys.asm - field sync, keyboard, random numbers, screen helpers
; =====================================================================

; ---------------------------------------------------------------------
; VBLANK: E002h bit 7 is /VBLK, but sources disagree on its polarity,
; so measure it: the level that lasts ~112 of 312 lines is the blanking.
; ---------------------------------------------------------------------
detect_vblank:
        ld hl,KEYPC
        ld a,(hl)
        and 80h
        ld b,a
.e0:    ld a,(hl)
        and 80h
        cp b
        jr z,.e0
        ld b,a
        ld de,0
.m1:    inc de
        ld a,(hl)
        and 80h
        cp b
        jr z,.m1
        ld c,a
        push de
        ld de,0
.m2:    inc de
        ld a,(hl)
        and 80h
        cp c
        jr z,.m2
        pop hl
        or a
        sbc hl,de                   ; carry if level B was shorter
        ld a,b
        jr c,.bshort
        ld a,c
.bshort:
        ld (vblev+1),a              ; level seen during VBLANK
        ld (vblev2+1),a
        jp timer_init               ; and start the scan-line clock

; ---------------------------------------------------------------------
; poll: call at least every ~15000 T.  On each VBLANK start it counts a
; field and runs the sound tick.  Keeps every register except AF.
; ---------------------------------------------------------------------
poll:
        ld a,(KEYPC)
        and 80h
pollcmp:
        cp 0                        ; last level seen (self-modified)
        jr nz,poll_edge
        ld a,(joy_on)
        or a
        jr z,poll_nj
        ld a,(JOYPORT)              ; read the lines first, then make sure
        ld (joy_tmp),a              ; VBLANK had not started: outside it the
        ld a,(KEYPC)                ; pulses are over, so a line held low
        and 80h                     ; is a button
vblev2: cp 0                        ; VBLANK level (set by detect_vblank)
        jr z,poll_nj
        ld a,(joy_tmp)
        ld (joy_disp),a
poll_nj:
        ld a,(noise_on)
        or a
        ret z
        jp noise_step
poll_edge:
        ld (pollcmp+1),a
vblev:  cp 0                        ; VBLANK level (set by detect_vblank)
        ret nz
        push bc
        push de
        push hl
        call read_ctr1              ; when VBLANK began, for the joystick
        ld (joy_edge),hl
        ld hl,fieldcnt
        inc (hl)
        call snd_tick
        pop hl
        pop de
        pop bc
        ret

; wait for the start of the next game frame: the first VBLANK start at
; least FRAMEF fields after the last frame.  The fields are measured with
; 8253 counter 1 (it counts scan lines), so a long stretch of work that
; misses a VBLANK edge in poll no longer makes the next frame wait extra
; fields.  Keeps BC and DE.
FRAME_LINES     equ FRAMEF*312
CTR1            equ 0E005h

timer_init:
        ld a,74h                    ; counter 1: LSB/MSB, mode 2, binary
        ld (CTRL),a
        xor a
        ld (CTR1),a
        ld (CTR1),a
        call read_ctr1
        ld (last_ctr),hl
        ret

; HL = counter 1 (latched)
read_ctr1:
        ld a,40h
        ld (CTRL),a
        ld a,(CTR1)
        ld l,a
        ld a,(CTR1)
        ld h,a
        ret

; HL = lines since the last frame, DE = counter now
lines_since:
        call read_ctr1
        ex de,hl
        ld hl,(last_ctr)
        or a
        sbc hl,de
        ret

last_ctr:       dw 0

wait_frame:
        push bc
        push de
        call lines_since
        ld bc,FRAME_LINES+156
        or a
        sbc hl,bc
        jr c,.w
        ld hl,drops                 ; already late
        inc (hl)
.w:     ld a,(fieldcnt)
        ld b,a
.e:     call poll                   ; next VBLANK start
        ld a,(fieldcnt)
        cp b
        jr z,.e
        call lines_since
        ld bc,FRAME_LINES-156
        or a
        sbc hl,bc
        jr c,.w                     ; too early: another field
        ld (last_ctr),de
        ld a,(fieldcnt)
        ld (lastframe),a
        pop de
        pop bc
        jp joy_sample

; wait A fields
wait_fields:
        ld b,a
.f:     ld a,(fieldcnt)
        ld c,a
.w:     call poll
        ld a,(fieldcnt)
        cp c
        jr z,.w
        djnz .f
        jp joy_sample

; wait for one field (handy in front-end loops)
wait_field:
        ld a,1
        jr wait_fields

; ---------------------------------------------------------------------
; MZ-1X03 joystick (port 1), as Sharp's own routine reads it: at the
; start of VBLANK each axis line (E008h bit 1 = X, bit 2 = Y) goes low
; for a time set by the stick, about 270 + 28 T per step of 0-255.  A
; button holds its line low (SW1 on X, SW2 on Y), which poll notices
; outside VBLANK.  Directions need only two looks: line already high 10
; lines in = low end (left / up), still low 22 lines in = high end
; (right / down), timed from the VBLANK start poll saw.  Call soon
; after that start; it waits until 22 lines in.
; ---------------------------------------------------------------------
JOY_EARLY       equ 10
JOY_LATE        equ 22

joy_sample:
        ld a,(joy_on)
        or a
        ret z
        push bc
        push de
        push hl
        ld de,(joy_edge)            ; the counter when VBLANK began
        ld b,JOY_EARLY
        call .until
        ld a,(JOYPORT)
        ld c,a                      ; early look
        ld b,JOY_LATE
        call .until
        ld a,(JOYPORT)
        ld b,a                      ; late look
        ld a,(joy_disp)
        ld l,a
        ld h,0
        bit 1,l                     ; X line held: SW1
        jr nz,.xa
        set B_FIRE,h
        jr .y
.xa:    bit 1,c
        jr z,.xr
        set B_LEFT,h
        jr .y
.xr:    bit 1,b
        jr nz,.y
        set B_RIGHT,h
.y:     bit 2,l                     ; Y line held: SW2
        jr nz,.ya
        set B_FIRE,h
        jr .done
.ya:    bit 2,c
        jr z,.yd
        set B_UP,h
        jr .done
.yd:    bit 2,b
        jr nz,.done
        set B_DOWN,h
.done:  ld a,h
        ld (joy_bits),a
        pop hl
        pop de
        pop bc
        ret
; wait until B scan lines have passed since counter value DE
.until: call read_ctr1
        push de
        ex de,hl
        or a
        sbc hl,de                   ; lines gone (the counter counts down)
        pop de
        ld a,l
        cp b
        jr c,.until
        ret

; ---------------------------------------------------------------------
; keyboard
; ---------------------------------------------------------------------
; read_keys: A = K_ bits of the game controls (cursor keys or Q/A/O/P,
; SPACE or Z to fire).  Also sets key_pause / key_quit.
read_keys:
        push bc
        push hl
        ld hl,KEYPA
        ld c,0
        ld (hl),7                   ; row 7: cursor keys
        inc l
        ld a,(hl)
        cpl
        dec l
        bit 5,a
        jr z,$+4
        set B_UP,c
        bit 4,a
        jr z,$+4
        set B_DOWN,c
        bit 2,a
        jr z,$+4
        set B_LEFT,c
        bit 3,a
        jr z,$+4
        set B_RIGHT,c
        ld (hl),6                   ; row 6: space
        inc l
        ld a,(hl)
        dec l
        bit 4,a
        jr nz,$+4
        set B_FIRE,c
        ld (hl),1                   ; row 1: Z
        inc l
        ld a,(hl)
        dec l
        bit 6,a
        jr nz,$+4
        set B_FIRE,c
        ld (hl),2                   ; row 2: Q
        inc l
        ld a,(hl)
        dec l
        bit 7,a
        jr nz,$+4
        set B_UP,c
        ld (hl),4                   ; row 4: A
        inc l
        ld a,(hl)
        dec l
        bit 7,a
        jr nz,$+4
        set B_DOWN,c
        ld (hl),3                   ; row 3: O (bit 1), P (bit 0)
        inc l
        ld a,(hl)
        dec l
        bit 1,a
        jr nz,$+4
        set B_LEFT,c
        bit 0,a
        jr nz,$+4
        set B_RIGHT,c
        ld (hl),0                   ; row 0: CR = pause
        inc l
        ld a,(hl)
        dec l
        cpl
        and 1
        ld (key_pause),a
        ld (hl),8                   ; row 8: BREAK = quit
        inc l
        ld a,(hl)
        cpl
        and 80h
        ld (key_quit),a
        ld a,(joy_on)
        or a
        ld a,c
        jr z,.nj
        ld hl,joy_bits
        or (hl)
.nj:    pop hl
        pop bc
        ret

; any key down? NZ if so (rows 0-9)
anykey:
        push bc
        push hl
        ld hl,KEYPA
        ld b,10
        ld c,0
.r:     ld a,b
        dec a
        ld (hl),a
        inc l
        ld a,(hl)
        dec l
        cpl
        or c
        ld c,a
        djnz .r
        ld a,(joy_on)
        or a
        jr z,.nj
        ld a,(joy_bits)
        and K_FIRE
        or c
        ld c,a
.nj:    ld a,c
        or a
        pop hl
        pop bc
        ret

; wait until no key is held
wait_release:
.w:     call poll
        call anykey
        jr nz,.w
        ret

; keys already held don't count as presses for fe_keys
fe_reset:
        call read_keys
        ld (fe_prev),a
        ld a,14
        ld (fe_rep),a
        ret

; front-end input with auto-repeat: returns A = newly pressed K_ bits
; (held directions repeat every 5 fields after a 14-field delay)
fe_keys:
        call read_keys
        ld c,a
        ld a,(fe_prev)
        cpl
        and c                       ; newly pressed
        ld b,a
        ld a,c
        ld (fe_prev),a
        ld a,b
        or a
        jr z,.rep
        ld a,14
        ld (fe_rep),a
        ld a,b
        ret
.rep:   ld a,c
        and K_DIRS
        ret z
        ld hl,fe_rep
        dec (hl)
        jr z,.fire
        xor a
        ret
.fire:  ld (hl),5
        ld a,c
        and K_DIRS
        ret

; ---------------------------------------------------------------------
; random numbers: HL = xorshift16, A = L
; ---------------------------------------------------------------------
rand:
        push de
        ld hl,(seed)
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
        ld (seed),hl
        ld a,r
        xor l
        ld l,a
        pop de
        ret

; A = random 0..B-1 (B > 0)
rand_below:
        push bc
        push de
        push hl
        call rand
        ld c,a
        ld e,b
        ld d,0
        ld hl,0
        ld b,8
.m:     add hl,hl
        sla c
        jr nc,.n
        add hl,de
.n:     djnz .m
        ld a,h
        pop hl
        pop de
        pop bc
        ret

; ---------------------------------------------------------------------
; screen helpers (front end): VRAM written directly
; ---------------------------------------------------------------------
; cls: chars = 0, attrs = A
cls:
        push af
        ld hl,VRAM
        ld de,VRAM+1
        ld (hl),0
        ld bc,999
        ldir
        call poll
        pop af
        ld hl,ARAM
        ld de,ARAM+1
        ld (hl),a
        ld bc,999
        ldir
        call poll
        jp shadow_reset             ; the cave view must redraw everything

; fill a row range with attr A and blank chars: B = first row, C = count
clear_rows:
        push af
        ld a,b
        call row_addr               ; HL = VRAM + row*40
        pop af
.r:     push bc
        push hl
        ld b,40
.c:     ld (hl),0
        set 3,h
        ld (hl),a
        res 3,h
        inc hl
        djnz .c
        push af
        call poll
        pop af
        pop hl
        ld de,40
        add hl,de
        pop bc
        dec c
        jr nz,.r
        ret

; HL = VRAM + A*40
row_addr:
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl                   ; *8
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl                   ; *32
        add hl,de                   ; *40
        ld de,VRAM
        add hl,de
        pop de
        ret

; DE = VRAM address of (B = col, C = row)
vaddr:
        push hl
        ld a,c
        call row_addr
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ex de,hl
        pop hl
        ret

; print: HL = ASCII string (0-terminated), DE = VRAM address, C = attr.
; Returns DE after the last char.  Codes 01h-07h inside the string set
; the foreground colour (keeping the background of C).
print:
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        cp 8
        jr c,.col
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        jr .l
.col:   rlca
        rlca
        rlca
        rlca
        ld b,a
        ld a,c
        and 8Fh
        or b
        ld c,a
        jr .l

; print raw display codes: HL = codes (0-terminated), DE = VRAM, C = attr
print_raw:
        ld a,(hl)
        inc hl
        or a
        ret z
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        jr print_raw

; print at (B = col, C = row) with attr in A
print_at:
        push af
        call vaddr
        pop af
        ld c,a
        jr print

; print centred on row C, attr A
print_centre:
        push af
        push hl
        ld b,0
.n:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        cp 8
        jr c,.n
        inc b
        jr .n
.e:     ld a,40
        sub b
        srl a
        ld b,a
        pop hl
        pop af
        jr print_at

; fill attributes: DE = VRAM address of first cell, B = count, A = attr
fill_attr:
        set 3,d
.l:     ld (de),a
        inc de
        djnz .l
        res 3,d
        ret

; put one cell: DE = VRAM address, A = char, C = attr (DE kept)
putc:
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        ret

; ---------------------------------------------------------------------
; BCD numbers
; ---------------------------------------------------------------------
; add_score: DE = BCD points (D = high byte: thousands/hundreds, E = tens/ones)
add_score:
        ld hl,score
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,1
        ld (hud_dirty),a
        ret

; print BCD bytes: HL = most significant byte, B = byte count,
; DE = VRAM address, C = attr
print_bcd:
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        call .dig
        ld a,(hl)
        call .dig
        dec hl
        djnz .l
        ret
.dig:   and 0Fh
        add a,20h
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        ret

; A (0-255) -> 3 decimal digits at DE (display codes), attr C
print_dec3:
        ld b,100
        call .d
        ld b,10
        call .d
        ld b,1
.d:     push af
        ld l,0
.s:     sub b
        jr c,.x
        inc l
        jr .s
.x:     ld a,l
        add a,20h
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        pop af
.s2:    cp b
        ret c
        sub b
        jr .s2
