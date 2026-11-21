; =====================================================================
;  sys.asm - field sync, keyboard, random numbers, screen helpers
;  (field sync and BCD helpers carried over from OVERRIDE)
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
        jr nz,.edge
        ld a,(noise_on)
        or a
        ret z
        jp noise_step
.edge:  ld (pollcmp+1),a
vblev:  cp 0                        ; VBLANK level (set by detect_vblank)
        ret nz
        push bc
        push de
        push hl
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
        ret

; wait A fields
wait_fields:
        or a
        ret z
        ld b,a
.f:     ld a,(fieldcnt)
        ld c,a
.w:     call poll
        ld a,(fieldcnt)
        cp c
        jr z,.w
        djnz .f
        ret

wait_field:
        ld a,1
        jr wait_fields

; ---------------------------------------------------------------------
; keyboard (matrix rows 0-9, active-low columns)
; ---------------------------------------------------------------------
; read_keys: A = K_ bits.  Cursor keys or O/P/Q/A move, SPACE / Z jump,
; X tongue, C colour.  Also sets key_pause (CR) and key_quit (BREAK).
read_keys:
        push bc
        push de
        push hl
        ld c,0
        ld de,KEYMAP
.l:     ld a,(de)                   ; row (FFh = end)
        inc de
        cp 0FFh
        jr z,.e
        ld (KEYPA),a
        ld a,(de)                   ; column mask
        inc de
        ld b,a
        ld a,(KEYPB)
        and b
        ld a,(de)                   ; K_ bit to set if pressed
        inc de
        jr nz,.l
        or c
        ld c,a
        jr .l
.e:     ld a,c
        and K_PAUSE
        ld (key_pause),a
        ld a,8                      ; row 8 bit 7: BREAK
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        and 80h
        ld (key_quit),a
        ld a,c
        and K_GAME
        pop hl
        pop de
        pop bc
        ret

KEYMAP:
        db 7,20h,K_UP, 7,10h,K_DOWN, 7,04h,K_LEFT, 7,08h,K_RIGHT
        db 2,80h,K_UP, 4,80h,K_DOWN, 3,02h,K_LEFT, 3,01h,K_RIGHT     ; Q A O P
        db 6,10h,K_JUMP, 1,40h,K_JUMP                              ; SPACE Z
        db 2,01h,K_TONGUE, 3,08h,K_TONGUE                          ; X M
        db 4,20h,K_SWAP, 3,04h,K_SWAP                              ; C N
        db 0,01h,K_PAUSE                                           ; CR
        db 0FFh

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
.w:     call poll
        call anykey
        jr nz,.w
        ret

; front end: keys already held don't count as presses for fe_keys
fe_reset:
        call read_keys
        ld (fe_prev),a
        ret

; front-end input: A = newly pressed K_ bits (Z clear if none)
fe_keys:
        call read_keys
        ld c,a
        ld a,(fe_prev)
        cpl
        and c
        ld b,a
        ld a,c
        ld (fe_prev),a
        ld a,b
        or a
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
        pop de
        ld a,l
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
        jp poll

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
        call poll
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

; draw cell art: HL = picture (db w, h, then ch/at pairs; at bit 3 =
; transparent -> keep the attr's background from the screen), DE = VRAM
draw_pic:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
draw_pic_wh:                        ; C = w, B = h, HL = cell pairs
.r:     push bc
        push de
.c:     ld a,(hl)
        inc hl
        or (hl)
        jr z,.skip
        dec hl
        ld a,(hl)
        inc hl
        ld (de),a
        ld a,(hl)
        bit 3,a
        jr z,.op
        and 0F0h
        ld b,a
        set 3,d
        ld a,(de)
        and 07h
        or b
        res 3,d
.op:    set 3,d
        ld (de),a
        res 3,d
.skip:  inc hl
        inc de
        dec c
        jr nz,.c
        pop de
        ex de,hl
        ld bc,40
        add hl,bc
        ex de,hl
        pop bc
        call poll
        djnz .r
        ret

; ---------------------------------------------------------------------
; BCD numbers
; ---------------------------------------------------------------------
; add_score: DE = BCD points (D = high byte: thousands/hundreds, E = tens/ones)
add_score:
        ld a,(demo)
        or a
        ret nz
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

; A (0-99) -> 2 decimal digits at DE, attr C
print_dec2:
        ld b,0
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     push af
        ld a,b
        add a,20h
        call putc
        inc de
        pop af
        add a,20h
        call putc
        inc de
        ret
