; =====================================================================
;  sys.asm - timing, keyboard, random numbers, screen and text helpers
;  (keyboard, rand and print come from LUMEN's sys.asm)
; =====================================================================

; ---------------------------------------------------------------- timing
; The 100 Hz interrupt counts mtick.  wait_ticks waits A ticks (10 ms each)
; and scans the keyboard every tick.  Keeps BC, DE, HL.
wait_ticks:
        push bc
        ld b,a
.t:     ld a,(mtick)
        ld c,a
.w:     halt
        ld a,(mtick)
        cp c
        jr z,.w
        djnz .t
        pop bc
        ret

wait_field:
        ld a,2
        jr wait_ticks

; ---------------------------------------------------------------- keyboard
; scan_keys reads the whole matrix into keymat (1 = down), keynew (went down
; at this scan) and keyacc (gathers keynew until kb_clear).
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
        push af
        ld a,e
        add a,10
        ld e,a
        jr nc,$+3
        inc d
        pop af
        push hl
        ex de,hl
        or (hl)
        ld (hl),a                   ; keyacc
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

; NZ if any key is down
anykey:
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

; NZ if any key went down since kb_clear
anyhit:
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
        di
        ld hl,keyacc
        ld b,10
.c:     ld (hl),0
        inc hl
        djnz .c
        ei
        pop bc
        pop hl
        ret

; wait for a key press; returns when one went down
wait_key:
        call wait_release
.w:     call wait_field
        call anyhit
        jr z,.w
        ret

; ---------------------------------------------------------------- random
; A = random (xorshift16).  Keeps BC, DE, HL.
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

; ---------------------------------------------------------------- screen
; cls: chars = 0, attrs = A
cls:
        push af
        ld hl,VRAM
        ld de,VRAM+1
        ld (hl),0
        ld bc,999
        ldir
        pop af
        ld hl,ARAM
        ld de,ARAM+1
        ld (hl),a
        ld bc,999
        ldir
        ret

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
        ld de,(scr_base)
        add hl,de
        pop de
        ret
scr_base: dw VRAM

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
; Codes 01h-07h set the foreground colour, 0Ah = newline (back to the
; column the text started at, next row).  Returns DE after the text.
print:
        ld (pr_start),de
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        cp 0Ah
        jr z,.nl
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
.nl:    push hl
        ld hl,(pr_start)
        ld de,40
        add hl,de
        ld (pr_start),hl
        ex de,hl
        pop hl
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
        cp 0Ah
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

; blit a cell art block: HL = data (db cols, rows, then rows*cols (char,attr)),
; DE = VRAM address of the top-left
blit_block:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
.r:     push bc
        push de
        ld b,c
.c:     ld a,(hl)
        inc hl
        ld (de),a
        set 3,d
        ld a,(hl)
        inc hl
        ld (de),a
        res 3,d
        inc de
        djnz .c
        pop de
        ex de,hl
        ld bc,40
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret

; HL = HL * A (8-bit A).  Keeps BC.
mul_hl_a:
        push bc
        push de
        ex de,hl
        ld hl,0
        ld b,8
.m:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .m
        pop de
        pop bc
        ret

pr_start: dw 0
pn_w:     db 0
numbuf:   ds 5
seed:     dw 0ACE1h
keymat:   ds 10
keynew:   ds 10
keyacc:   ds 10
