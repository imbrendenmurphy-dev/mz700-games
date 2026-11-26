; =====================================================================
;  sys.asm - field sync, keyboard, random numbers, screen helpers
; =====================================================================

; VBLANK: E002h bit 7 is /VBLK; measure which level is the short one.
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
        sbc hl,de
        ld a,b
        jr c,.bshort
        ld a,c
.bshort:
        ld (vblev+1),a
        ret

; poll: call at least every ~15000 T.  Counts fields and steps the
; sound by the scan-line clock.  Keeps every register except AF.
poll:
        ld a,(KEYPC)
        and 80h
pollcmp:
        cp 0
        jr nz,.edge
        ld a,(noise_on)
        or a
        ret z
        jp noise_step
.edge:  ld (pollcmp+1),a
        push bc
        push de
        push hl
vblev:  cp 0
        jr nz,.clk
        ld hl,fieldcnt
        inc (hl)
.clk:   call snd_clock
        pop hl
        pop de
        pop bc
        ret

FRAME_LINES     equ FRAMEF*312

timer_init:
        ld a,74h                    ; counter 1: LSB/MSB, mode 2 (scan lines)
        ld (CTRL),a
        xor a
        ld (CTR1),a
        ld (CTR1),a
        call read_ctr1
        ld (last_ctr),hl
        ld (snd_clk),hl
        ret

read_ctr1:
        ld a,40h
        ld (CTRL),a
        ld a,(CTR1)
        ld l,a
        ld a,(CTR1)
        ld h,a
        ret

; wait until at least FRAMEF fields have passed since the last frame
wait_frame:
        push bc
        push de
        push hl
.w:     call poll
        call read_ctr1
        ex de,hl
        ld hl,(last_ctr)
        or a
        sbc hl,de
        ld bc,FRAME_LINES
        or a
        sbc hl,bc
        jr c,.w
        ld (last_ctr),de
        ld hl,framecnt
        inc (hl)
        call scan_keys
        pop hl
        pop de
        pop bc
        ret

; wait A fields
wait_fields:
        push bc
        ld b,a
.f:     ld a,(fieldcnt)
        ld c,a
.w:     call poll
        ld a,(fieldcnt)
        cp c
        jr z,.w
        djnz .f
        pop bc
        ret

wait_field:
        ld a,1
        jr wait_fields

; ---------------------------------------------------------------------
; keyboard: scan_keys reads the whole matrix into keymat (1 = down) and
; keynew (down now, up at the last scan).  Key codes are row*8 + bit.
; ---------------------------------------------------------------------
scan_keys:
        push bc
        push de
        push hl
        ld hl,KEYPA
        ld de,keymat
        ld b,0
.r:     ld (hl),b
        inc l
        ld a,(hl)
        dec l
        cpl
        ld c,a
        ld a,(de)                   ; previous
        cpl
        and c
        push de
        push af
        ld a,e
        add a,10
        ld e,a
        jr nc,$+3
        inc d
        pop af
        ld (de),a                   ; keynew
        push af                     ; and keyacc gathers them until used
        ld a,e
        add a,10
        ld e,a
        jr nc,$+3
        inc d
        pop af
        push hl
        ex de,hl
        or (hl)
        ld (hl),a
        pop hl
        pop de
        ld a,c
        ld (de),a
        inc de
        inc b
        ld a,b
        cp 10
        jr c,.r
        pop hl
        pop de
        pop bc
        ret

; NZ if key A is held (after scan_keys).  Keeps BC, DE, HL.
key_held:
        push hl
        ld hl,keymat
        jr key_test
; NZ if key A went down since the last kb_clear
key_hit:
        push hl
        ld hl,keyacc
key_test:
        push bc
        ld c,a
        rrca
        rrca
        rrca
        and 0Fh
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,c
        and 7
        ld b,a
        inc b
        ld a,(hl)
.s:     rrca
        djnz .s                     ; the key's bit lands in carry
        sbc a,a                     ; FF if set
        or a
        pop bc
        pop hl
        ret

; A = held directions (cursor keys or Q/A/O/P) as K_ bits
read_dirs_acc:
        push hl
        ld hl,keyacc
        jr read_dirs_hl
read_dirs:
        push hl
        ld hl,keymat
read_dirs_hl:
        push bc
        push de
        ld de,7
        add hl,de
        ld c,0
        ld a,(hl)
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
        ld de,-5
        add hl,de                   ; row 2
        ld a,(hl)
        bit 7,a                     ; Q
        jr z,$+4
        set B_UP,c
        inc hl
        inc hl                      ; row 4
        ld a,(hl)
        bit 7,a                     ; A
        jr z,$+4
        set B_DOWN,c
        dec hl                      ; row 3
        ld a,(hl)
        bit 1,a                     ; O
        jr z,$+4
        set B_LEFT,c
        bit 0,a                     ; P
        jr z,$+4
        set B_RIGHT,c
        ld a,c
        pop de
        pop bc
        pop hl
        ret

; NZ if any key is down (scans the matrix)
anykey:
        call scan_keys
        push bc
        push hl
        ld hl,keymat
        ld b,10
        xor a
.o:     or (hl)
        inc hl
        djnz .o
        or a
        pop hl
        pop bc
        ret

; NZ if any key went down at this scan
anyhit:
        call scan_keys
        push bc
        push hl
        ld hl,keyacc
        ld b,10
        xor a
.o:     or (hl)
        inc hl
        djnz .o
        or a
        pop hl
        pop bc
        ret

wait_release:
.w:     call wait_field
        call anykey
        jr nz,.w
; forget the presses gathered so far
kb_clear:
        push hl
        push bc
        ld hl,keyacc
        ld b,10
.c:     ld (hl),0
        inc hl
        djnz .c
        pop bc
        pop hl
        ret

; wait for a key press (with the screen idle); A = 0
wait_key:
        call wait_release
.w:     call wait_field
        call anyhit
        jr z,.w
        ret

; ---------------------------------------------------------------------
; random numbers: A = random (xorshift16).  Keeps BC, DE, HL.
; ---------------------------------------------------------------------
rand:
        push hl
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
        xor l
        pop hl
        ret

; A = random 0..B-1 (B > 0).  Keeps BC, DE, HL.
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

; A = random in [B, C] inclusive.  Keeps BC, DE, HL.
rand_range:
        push bc
        ld a,c
        sub b
        inc a
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,b
        pop bc
        ret

; ---------------------------------------------------------------------
; screen helpers (front end)
; ---------------------------------------------------------------------
; cls: chars = 0, attrs = A; the play view must redraw everything after
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
        jp shadow_reset

; fill rows with attr A and blank chars: B = first row, C = count
clear_rows:
        push af
        ld a,b
        call row_addr
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

; HL = VRAM + A*40.  Keeps BC, DE.
row_addr:
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,VRAM
        add hl,de
        pop de
        ret

; DE = VRAM address of (B = col, C = row).  Keeps BC, HL.
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
; Codes 01h-07h set the foreground colour.  Returns DE after the text.
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

; print at (B = col, C = row) with attr A
print_at:
        push af
        call vaddr
        pop af
        ld c,a
        jr print

; string length (ignoring colour codes): HL = string -> B
str_len:
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
.e:     pop hl
        ret

; print centred on row C, attr A
print_centre:
        push af
        call str_len
        ld a,40
        sub b
        srl a
        ld b,a
        pop af
        jr print_at

; fill attributes: DE = VRAM address, B = count, A = attr
fill_attr:
        set 3,d
.l:     ld (de),a
        inc de
        djnz .l
        res 3,d
        ret

; fill chars and attrs: DE = VRAM, B = count, A = char, C = attr
fill_cells:
.l:     ld (de),a
        set 3,d
        push af
        ld a,c
        ld (de),a
        pop af
        res 3,d
        inc de
        djnz .l
        ret

; put one cell: DE = VRAM address, A = char, C = attr (DE kept)
putc:
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        ret

; print HL (0-65535) in decimal at DE, attr C, without leading zeros;
; B = minimum width (pads with spaces on the left).  DE ends after it.
print_num:
        push ix
        call .body
        pop ix
        ret
.body:  ld a,b
        ld (pn_w),a
        push de
        ld ix,numbuf
        ld de,10000
        call .dig
        ld de,1000
        call .dig
        ld de,100
        call .dig
        ld de,10
        call .dig
        ld a,l
        ld (ix+0),a
        pop de
        ld hl,numbuf
        ld b,5
.z:     ld a,b
        dec a
        jr z,.go
        ld a,(hl)
        or a
        jr nz,.go
        inc hl
        dec b
        jr .z
.go:    ld a,(pn_w)
        sub b
        jr c,.p
        jr z,.p
.pad:   push af
        xor a
        call putc
        inc de
        pop af
        dec a
        jr nz,.pad
.p:     ld a,(hl)
        inc hl
        add a,20h
        call putc
        inc de
        djnz .p
        ret
.dig:   xor a
.s:     or a
        sbc hl,de
        jr c,.u
        inc a
        jr .s
.u:     add hl,de
        ld (ix+0),a
        inc ix
        ret
