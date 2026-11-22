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
        ret

; ---------------------------------------------------------------------
; poll: call at least every ~15000 T.  On each VBLANK start it counts a
; field and runs the sound tick; at each VBLANK end the flight effects
; take a half step.  Keeps every register except AF.
; ---------------------------------------------------------------------
poll:
        ld a,(KEYPC)
        and 80h
pollcmp:
        cp 0                        ; last level seen (self-modified)
        jr nz,.edge
        ld a,(noise_on)
        or a
        ret z
        jp noise_step
.edge:  ld (pollcmp+1),a
        push bc
        push de
        push hl
vblev:  cp 0                        ; VBLANK level (set by detect_vblank)
        jr nz,.half
        ld a,(joy_on)               ; first, while the stick's pulses run
        or a
        call nz,joy_poll
        ld hl,fieldcnt
        inc (hl)
        jr .clk
.half:  ld a,(joy_on)               ; the picture starts: joystick buttons
        or a
        call nz,joy_btns
.clk:   call snd_clock              ; sound ticks by the scan-line clock
        pop hl
        pop de
        pop bc
        ret

; wait for the start of the next game frame (FRAMEF fields after the last
; one, always at the start of a VBLANK)
; Frames are timed with 8253 counter 1, which counts scan lines (HSYNC)
; down from 65536, so no time is lost however rarely poll runs.
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

wait_frame:
.w:     call poll
        call read_ctr1
        ex de,hl                    ; DE = now
        ld hl,(last_ctr)
        or a
        sbc hl,de                   ; lines since the last frame
        ld bc,FRAME_LINES
        or a
        sbc hl,bc
        jr c,.w                     ; early: wait
        or a
        sbc hl,bc
        jr nc,.late
        ld hl,(last_ctr)            ; on time: keep a steady beat
        or a
        sbc hl,bc
        ld (last_ctr),hl
        ret
.late:  ld (last_ctr),de            ; a frame or more behind: carry on
        ld hl,drops
        inc (hl)
        ret

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
        ret

; wait for one field (handy in front-end loops)
wait_field:
        ld a,1
        jr wait_fields

; ---------------------------------------------------------------------
; keyboard
; ---------------------------------------------------------------------
; read_keys: A = K_ bits.  Left: Z or cursor left; right: X or cursor
; right; flip (K_FIRE): SPACE or CR; K_UP / K_DOWN: cursor up / down.
; key_extra: bit 0 P, 1 S, 2 D, 3 Q, 4 BREAK, 5 Y, 6 N
read_keys:
        push bc
        push de
        push hl
        ld hl,KEYPA
        ld c,0
        ld e,0
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
        ld (hl),0                   ; row 0: CR
        inc l
        ld a,(hl)
        dec l
        bit 0,a
        jr nz,$+4
        set B_FIRE,c
        ld (hl),1                   ; row 1: Y (7), Z (6)
        inc l
        ld a,(hl)
        dec l
        bit 7,a
        jr nz,$+4
        set 5,e
        bit 6,a
        jr nz,$+4
        set B_LEFT,c
        ld (hl),2                   ; row 2: Q (7), S (5), X (0)
        inc l
        ld a,(hl)
        dec l
        bit 7,a
        jr nz,$+4
        set 3,e
        bit 5,a
        jr nz,$+4
        set 1,e
        bit 0,a
        jr nz,$+4
        set B_RIGHT,c
        ld (hl),3                   ; row 3: N (2), P (0)
        inc l
        ld a,(hl)
        dec l
        bit 2,a
        jr nz,$+4
        set 6,e
        bit 0,a
        jr nz,$+4
        set 0,e
        ld (hl),4                   ; row 4: D (4)
        inc l
        ld a,(hl)
        dec l
        bit 4,a
        jr nz,$+4
        set 2,e
        ld (hl),8                   ; row 8: BREAK (7)
        inc l
        ld a,(hl)
        bit 7,a
        jr nz,$+4
        set 4,e
        ld a,e
        ld (key_extra),a
        call joy_read
        or c
        pop hl
        pop de
        pop bc
        ret

; getkey: A = ASCII of a letter key held (A-Z), 13 for CR, 8 for cursor
; left / BREAK, or 0.  Lowest row wins.
getkey:
        push bc
        push de
        push hl
        ld hl,KEYPA
        ld (hl),0
        inc l
        ld a,(hl)
        dec l
        bit 0,a
        ld a,13
        jr z,.x
        ld (hl),7
        inc l
        ld a,(hl)
        dec l
        bit 2,a
        ld a,8
        jr z,.x
        ld (hl),8
        inc l
        ld a,(hl)
        dec l
        bit 7,a
        ld a,8
        jr z,.x
        ld de,gk_tab
        ld c,1                      ; rows 1..4
.r:     ld (hl),c
        inc l
        ld a,(hl)
        dec l
        ld b,8
.b:     rla                         ; bit 7 first
        jr nc,.hit
        inc de
        djnz .b
        inc c
        ld a,c
        cp 5
        jr c,.r
        xor a
        jr .x
.hit:   ld a,(de)
.x:     pop hl
        pop de
        pop bc
        ret

gk_tab: db "YZ",0,0,0,0,0,0
        db "QRSTUVWX"
        db "IJKLMNOP"
        db "ABCDEFGH"


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
        ld a,c
        or a
        pop hl
        pop bc
        ret

; wait until no key is held
wait_release:
.w:     call wait_field
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
        jp shadow_reset             ; the play view must redraw everything

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
