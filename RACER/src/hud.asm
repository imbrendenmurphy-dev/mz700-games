; =====================================================================
;  hud.asm - text, the HUD (rows 0-1) and messages (row 4)
;  The HUD is written straight to VRAM, only where something changed.
; =====================================================================

MSGROW  equ 4

; ---------------------------------------------------------------------
; text.  Strings are ASCII, 0-terminated, converted to display codes.
asc2dc:
        sub 20h
        ret c
        cp 40h
        jr c,.ok
        sub 20h                 ; lower case -> upper case
.ok:    push hl
        ld hl,asctab
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,(hl)
        pop hl
        ret

asctab: ;  sp  !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /
        db 00h,61h,62h,63h,64h,65h,66h,67h,68h,69h,6Bh,6Ah,2Fh,2Ah,2Eh,2Dh
        ;   0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?
        db 20h,21h,22h,23h,24h,25h,26h,27h,28h,29h,4Fh,2Ch,51h,2Bh,57h,49h
        ;   @   A ...
        db 55h,01h,02h,03h,04h,05h,06h,07h,08h,09h,0Ah,0Bh,0Ch,0Dh,0Eh,0Fh
        db 10h,11h,12h,13h,14h,15h,16h,17h,18h,19h,1Ah,52h,59h,54h,50h,00h

; B = row, C = column -> HL = cell offset 0..999
cell_ofs:
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; 8r
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl               ; 32r
        add hl,de               ; 40r
        ld e,c
        ld d,0
        add hl,de
        ret

; HL = text, B = row, C = column, A = attribute.  HL past the end.
print_at:
        push af
        push hl
        call cell_ofs
        ld de,VRAM
        add hl,de
        ex de,hl                ; DE = VRAM cell
        pop hl
        pop af
        ld c,a
print_de:
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        call asc2dc
        ld (de),a
        set 3,d                 ; colour RAM is 800h above
        ld a,c
        ld (de),a
        res 3,d
        inc de
        jr .l

; HL = text, B = row, A = attribute: centred
print_centre:
        push af
        push hl
        ld c,0
.n:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        inc c
        jr .n
.e:     ld a,40
        sub c
        srl a
        ld c,a
        pop hl
        pop af
        jr print_at

; A = 0..9 at DE (advanced), attribute C
put_digit:
        add a,20h
put_char:
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        ret

; A = BCD byte as two digits at DE, attribute C
put_bcd:
        push af
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        call put_digit
        pop af
        and 0Fh
        jr put_digit

; fill B cells at DE with char A, attribute C
fill_cells:
        push af
        call put_char
        pop af
        djnz fill_cells
        ret

; clear rows: B = first row, C = count, A = attribute (char 0)
clear_rows:
        push af
        push bc
        ld c,0
        call cell_ofs
        pop bc
        ld de,VRAM
        add hl,de
        pop af
.r:     push bc
        ld b,40
.c:     ld (hl),0
        set 3,h
        ld (hl),a
        res 3,h
        inc hl
        djnz .c
        pop bc
        dec c
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; the HUD frame (once per race)
HUDA    equ CYAN*16+BLACK
HUDV    equ WHITE*16+BLACK
hud_init:
        ld a,HUDV
        ld b,0
        ld c,2
        call clear_rows
        ld hl,hudtxt
.t:     ld a,(hl)
        cp 0FFh
        jr z,.d
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        call print_at
        jr .t
.d:     ld a,0FFh               ; force every field to redraw
        ld (hud_time),a
        ld (hud_spd),a
        ld (hud_boost),a
        ld (hud_stage),a
        ld (hud_prog),a
        ld a,1
        ld (hudscore),a
        ret

hudtxt: db 0,0,YELLOW*16+BLACK,"TIME",0
        db 0,8,HUDA,"SCORE",0
        db 0,24,HUDA,"STAGE",0
        db 1,3,HUDA,"KM/H",0
        db 1,9,HUDA,"GEAR",0
        db 1,16,HUDA,"BOOST",0
        db 0FFh

; per frame (at the blank, after the road): the parts that changed
hud_update:
        ; time
        ld a,(timesec)
        ld hl,hud_time
        cp (hl)
        jr z,.t1
        ld (hl),a
        ld de,VRAM+5
        ld c,YELLOW*16+BLACK
        cp 11h
        jr nc,.tc
        ld c,RED*16+BLACK
.tc:    call put_bcd
.t1:    ; score (7 digits: six BCD and a 0)
        ld a,(hudscore)
        or a
        jr z,.s1
        xor a
        ld (hudscore),a
        ld de,VRAM+14
        ld c,HUDV
        ld a,(score+2)
        call put_bcd
        ld a,(score+1)
        call put_bcd
        ld a,(score)
        call put_bcd
        xor a
        call put_digit
.s1:    ; stage
        ld a,(stage)
        ld hl,hud_stage
        cp (hl)
        jr z,.g1
        ld (hl),a
        ld de,VRAM+30
        ld c,HUDV
        call put_digit
.g1:    ; course progress: 8 cells, a cell per eighth
        call progress8
        ld hl,hud_prog
        cp (hl)
        jr z,.p1
        ld (hl),a
        ld b,a
        ld de,VRAM+32
        ld c,GREEN*16+BLACK
        or a
        jr z,.p0
.pf:    ld a,43h
        call put_char
        djnz .pf
.p0:    ld a,(hud_prog)
        sub 8
        neg
        jr z,.p1
        ld b,a
        ld c,BLUE*16+BLACK
.pe:    ld a,43h
        call put_char
        djnz .pe
.p1:    ; speed in km/h: speed * 47 / 256
        ld hl,(speed)
        ld a,47
        call mul_hu
        ld a,l
        ld hl,hud_spd
        cp (hl)
        jr z,.v1
        ld (hl),a
        ld hl,(speed)
        ld a,47
        call mul_hu
        call bin2bcd16          ; HL = BCD (3 digits)
        ld de,VRAM+40
        ld c,HUDV
        ld a,h
        call put_digit
        ld a,l
        call put_bcd
        ; gear 1-5 from the speed (bands of 384)
        ld hl,(speed)
        ld de,384
        ld a,1
.gr:    or a
        sbc hl,de
        jr c,.gq
        inc a
        jr .gr
.gq:    cp 6
        jr c,.gs
        ld a,5
.gs:
        ld de,VRAM+40+14
        ld c,YELLOW*16+BLACK
        call put_digit
.v1:    ; boost: 10 cells, two steps a cell
        ld a,(boost)
        srl a
        srl a
        srl a                   ; 0..20 (BOOSTMAX 160)
        ld b,a
        ld a,(boosting)
        rrca
        or b
        ld hl,hud_boost
        cp (hl)
        jr z,.b1
        ld (hl),a
        ld de,VRAM+40+22
        ld c,10
.bl:    ld a,b
        or a
        jr z,.be
        cp 2
        jr c,.bh
        dec b
        dec b
        ld a,43h                ; full
        jr .bp
.bh:    dec b
        ld a,7Bh                ; half
        jr .bp
.be:    ld a,0
.bp:    push bc
        ld c,MAGENTA*16+BLUE
        ld hl,boosting
        bit 0,(hl)
        jr z,.bc
        ld c,WHITE*16+BLUE
.bc:    call put_char
        pop bc
        dec c
        jr nz,.bl
.b1:    jp msg_update


; A = 0..8: how far along the course (pos/16 * 8 / len)
progress8:
        ld de,(crs_len)
        ld a,d
        or e
        ret z
        ld hl,(pos)
        srl h
        rr l
        ld c,0
.c:     or a
        sbc hl,de
        jr c,.d
        inc c
        ld a,c
        cp 8
        jr c,.c
.d:     ld a,c
        ret

; HL = 0..999 -> HL = BCD (H hundreds, L tens/units)
bin2bcd16:
        ld b,0
        ld de,100
.h:     or a
        sbc hl,de
        jr c,.hd
        inc b
        jr .h
.hd:    add hl,de
        ld a,l
        push bc
        call bin2bcd
        pop bc
        ld h,b
        ret

; A = 0..255 -> HL = three BCD digits (H hundreds, L tens/units)
bin2bcd:
        ld h,0
.h:     cp 100
        jr c,.t
        sub 100
        inc h
        jr .h
.t:     ld l,0
.tl:    cp 10
        jr c,.u
        sub 10
        inc l
        jr .tl
.u:     ld b,a
        ld a,l
        rlca
        rlca
        rlca
        rlca
        or b
        ld l,a
        ret

; ---------------------------------------------------------------------
; messages in the sky (row MSGROW): HL = text, A = number to add (0 none)
hud_message:
        ld (msgnum),a
        ld (msgptr),hl
        ld a,75
        ld (msgtime),a
        ld a,1
        ld (msgdraw),a
        ret

msg_update:
        ld a,(msgdraw)
        or a
        jr z,.t
        xor a
        ld (msgdraw),a
        ld a,(msgcol)           ; a banner: the whole row, blank
        ld b,MSGROW
        ld c,1
        call clear_rows
        ld hl,(msgptr)
        ld de,msgbuf
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.cp
        ld a,(msgnum)
        cp 2
        jr c,.nn
        dec de                  ; " X" and the count
        ld b,a
        ld a,' '
        ld (de),a
        inc de
        ld a,'X'
        ld (de),a
        inc de
        ld a,b
        add a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
.nn:    ld hl,msgbuf
        ld b,MSGROW
        ld a,(msgcol)
        jp print_centre
.t:     ld a,(msgtime)
        or a
        ret z
        dec a
        ld (msgtime),a
        ret nz
msg_clear:                      ; give the row back to the sky
        ld hl,SKYSH+(MSGROW-SKYROW)*40
        ld b,40
.c:     ld (hl),0FFh
        inc hl
        djnz .c
        ld a,(skyattr+MSGROW-SKYROW)
        ld b,MSGROW
        ld c,1
        call clear_rows
        ld a,1
        ld (skyforce),a
        ret
