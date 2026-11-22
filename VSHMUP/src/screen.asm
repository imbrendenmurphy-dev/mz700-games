; =====================================================================
;  screen.asm - layers, draw lists, flush, sprites, text
;
;  BG  background: stars, scenery, HUD (changes go on the BG list, or
;      whole rows are marked in ROWDIRTY when the scenery scrolls)
;  W   BG + this tick's sprites, built in RAM
;  S   shadow of VRAM
;  Each tick restore() puts BG back into W under last tick's sprites,
;  the game put_cell()s this tick's sprites into W, and at the next
;  vertical blank flush() writes only the cells that differ from S.
; =====================================================================

; HL = cell offset, D = char, E = attribute: a sprite cell this tick
; (HL, DE preserved)
put_cell:
        ld bc,(curptr)
        ld a,b                  ; list full? (512 entries)
        and 3
        cp 3
        jr nz,.ok
        ld a,c
        cp 0FEh
        ret nc
.ok:    ld a,l
        ld (bc),a
        inc bc
        ld a,h
        ld (bc),a
        inc bc
        ld (curptr),bc
        ld a,h
        add a,high WCH
        ld b,a
        ld c,l
        ld a,d
        ld (bc),a
        set 2,b
        ld a,e
        ld (bc),a
        ret

; HL = cell, A = owner: put the owner in the collision map
set_occ:
        ld b,a
        ld a,h
        add a,high OCC
        ld h,a
        ld (hl),b
        sub high OCC
        ld h,a
        ret

; A = owner in cell HL (HL preserved)
occ_at:
        ld a,h
        add a,high OCC
        ld h,a
        ld a,(hl)
        push af
        ld a,h
        sub high OCC
        ld h,a
        pop af
        ret

; B = row, C = column -> HL = cell offset (BC, DE preserved).  No checks.
calc_ofs:
        ld a,b
        add a,a
        ld l,a
        ld h,high rowtab
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,c
        ld l,a
        ret nc
        inc h
        ret

; ---------------------------------------------------------------------
; IY = sprite (count, then dx dy char attr per cell), B = row, C = column
; (both signed; cells off the playfield are clipped), A = owner for the
; collision map (0 = none).  (sprflash) <> 0 draws it all in white.
draw_spr:
        ld (sprown),a
        ld a,(iy+0)
        inc iy
.l:     ld (sprcnt),a
        ld a,(iy+0)
        add a,c
        cp PFW
        jr nc,.nx
        ld e,a
        ld a,(iy+1)
        add a,b
        cp PFH
        jr nc,.nx
        add a,a
        ld l,a
        ld h,high rowtab
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,e
        ld l,a
        jr nc,.o
        inc h
.o:     ld d,(iy+2)
        ld a,(sprflash)
        or a
        ld a,(iy+3)
        jr z,.nf
        and 80h
        or 70h
.nf:    ld e,a
        push bc
        call put_cell
        ld a,(sprown)
        or a
        jr z,.no
        call set_occ
.no:    pop bc
.nx:    ld de,4
        add iy,de
        ld a,(sprcnt)
        dec a
        jr nz,.l
        ret

; B = row, C = column (signed), D = char, E = attr, A = owner: one cell
put_one:
        ld (sprown),a
        ld a,c
        cp PFW
        ret nc
        ld a,b
        cp PFH
        ret nc
        call calc_ofs
        call put_cell
        ld a,(sprown)
        or a
        ret z
        jp set_occ

; ---------------------------------------------------------------------
; put BG back into W (and clear OCC) under last tick's sprites
restore:
        ld hl,(prevlist)
        ld de,(prevend)
.l:     ld a,l
        cp e
        jr nz,.go
        ld a,h
        cp d
        ret z
.go:    push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld l,e
        ld a,d
        add a,high BGCH
        ld h,a
        ld c,(hl)
        set 2,h
        ld b,(hl)
        ld a,d
        add a,high WAT
        ld h,a
        ld (hl),b
        res 2,h
        ld (hl),c
        ld a,d
        add a,high OCC
        ld h,a
        ld (hl),0
        pop hl
        pop de
        jr .l

; in vertical blank: write the changed cells, then swap the lists
flush:
        ld a,(fullflush)
        or a
        jr z,.part
        xor a
        ld (fullflush),a
        ld hl,ROWDIRTY          ; (all compared anyway)
        ld b,PFH
.z:     ld (hl),a
        inc hl
        djnz .z
        call flush_all
        jr .bgd
.part:  call flush_rows
        ld hl,(prevlist)        ; where last tick's sprites were
        ld de,(prevend)
        call flush_list
        ld hl,(curlist)         ; this tick's sprites
        ld de,(curptr)
        call flush_list
        ld hl,BGDL              ; background changes
        ld de,(bgptr)
        call flush_list
.bgd:   ld hl,BGDL
        ld (bgptr),hl
        ld hl,(curlist)         ; swap
        ld de,(prevlist)
        ld (prevlist),hl
        ld hl,(curptr)
        ld (prevend),hl
        ld (curlist),de
        ld (curptr),de
        ret

; only the background list (while paused)
flush_bg:
        ld hl,BGDL
        ld de,(bgptr)
        call flush_list
        ld hl,BGDL
        ld (bgptr),hl
        ret

; HL = list start, DE = end.  (The compare is inlined: this is the
; busiest loop in the game.)
flush_list:
        ex de,hl
        or a
        sbc hl,de
        ret z
        srl h
        rr l
        push hl
        exx
        pop bc                  ; BC' = cells
        exx
        ex de,hl
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld l,e
        ld a,d
        add a,high WCH
        ld h,a
        ld c,(hl)               ; C = wanted char
        set 2,h
        ld b,(hl)               ; B = wanted attribute
        ld a,h
        add a,high (SAT-WAT)
        ld h,a
        ld a,b
        cp (hl)
        jr nz,.wr
        res 2,h
        ld a,c
        cp (hl)
        jr z,.nx
        set 2,h
.wr:    ld (hl),b
        res 2,h
        ld (hl),c
        ld a,h
        add a,high (CRAM-SCH)
        ld h,a
        ld (hl),b
        res 3,h
        ld (hl),c
.nx:    pop hl
        exx
        dec bc
        ld a,b
        or c
        exx
        jr nz,.l
        ret

; rows marked in ROWDIRTY: compare the 30 playfield cells
flush_rows:
        ld hl,ROWDIRTY
        ld b,0
.r:     ld a,(hl)
        or a
        jr z,.n
        ld (hl),0
        push hl
        push bc
        ld c,0
        call calc_ofs
        ex de,hl
        ld b,PFW
.c:     push bc
        call flush_cell
        pop bc
        inc de
        djnz .c
        pop bc
        pop hl
.n:     inc hl
        inc b
        ld a,b
        cp PFH
        jr nz,.r
        ret

; DE = cell: copy W to VRAM if it differs from the shadow (DE preserved)
flush_cell:
        ld l,e
        ld a,d
        add a,high WCH
        ld h,a
        ld c,(hl)               ; C = wanted char
        set 2,h
        ld b,(hl)               ; B = wanted attribute
        ld a,h
        add a,high (SAT-WAT)
        ld h,a
        ld a,b
        cp (hl)
        jr nz,.wr
        res 2,h
        ld a,c
        cp (hl)
        ret z
        set 2,h
.wr:    ld (hl),b
        res 2,h
        ld (hl),c
        ld a,h
        add a,high (CRAM-SCH)
        ld h,a
        ld (hl),b
        res 3,h
        ld (hl),c
        ret

; ---------------------------------------------------------------------
; background cell HL = (D char, E attr): into BG and W, flushed next time
; (HL, DE, BC preserved)
bg_put:
        push bc
        ld c,l
        ld a,h
        add a,high BGCH
        ld b,a
        ld a,d
        ld (bc),a
        set 2,b
        ld a,e
        ld (bc),a
        ld a,h
        add a,high WCH
        ld b,a
        ld a,d
        ld (bc),a
        set 2,b
        ld a,e
        ld (bc),a
        ld bc,(bgptr)
        ld a,b
        cp high (BGDL+400h)
        jr nc,.full
        ld a,l
        ld (bc),a
        inc bc
        ld a,h
        ld (bc),a
        inc bc
        ld (bgptr),bc
        pop bc
        ret
.full:  ld a,1                  ; list full: compare everything next time
        ld (fullflush),a
        pop bc
        ret

; copy BG to W, S and the real screen in one go (a new screen)
refresh_all:
        ld hl,BGCH
        ld de,WCH
        ld bc,1000
        ldir
        ld hl,BGAT
        ld de,WAT
        ld bc,1000
        ldir
        ld hl,BGCH
        ld de,SCH
        ld bc,1000
        ldir
        ld hl,BGAT
        ld de,SAT
        ld bc,1000
        ldir
        call wait_vb
        ld hl,SAT
        ld de,CRAM
        ld bc,1000
        ldir
        ld hl,SCH
        ld de,VRAM
        ld bc,1000
        ldir
        call read_ctr1
        ld (duectr),hl
        ; fall through
reset_lists:
        ld hl,OCC
        ld de,OCC+1
        ld bc,999
        ld (hl),0
        ldir
        ld hl,LISTA
        ld (curlist),hl
        ld (curptr),hl
        ld hl,LISTB
        ld (prevlist),hl
        ld (prevend),hl
        ld hl,BGDL
        ld (bgptr),hl
        xor a
        ld (fullflush),a
        ld hl,ROWDIRTY
        ld b,PFH
.z:     ld (hl),a
        inc hl
        djnz .z
        ret

; the background list overflowed: compare every cell (rare)
flush_all:
        ld de,0
.l:     call flush_cell
        inc de
        ld a,d
        cp high 1000
        jr nz,.l
        ld a,e
        cp low 1000
        jr nz,.l
        ret

; fill BG with char 0 and attribute A
clear_bg:
        ld hl,BGAT
        ld de,BGAT+1
        ld bc,999
        ld (hl),a
        ldir
        ld hl,BGCH
        ld de,BGCH+1
        ld bc,999
        ld (hl),0
        ldir
        ret

        align 256
rowtab:
        dw 0,40,80,120,160,200,240,280,320,360,400,440,480
        dw 520,560,600,640,680,720,760,800,840,880,920,960

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

; HL = text, DE = cell offset, C = attribute.  Returns HL past the end.
print_bg:
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        push hl
        push de
        call asc2dc
        ex de,hl
        ld d,a
        ld e,c
        call bg_put
        pop de
        inc de
        pop hl
        jr .l

; HL = text, B = row, C = column, A = attribute
print_at:
        push hl
        push af
        call calc_ofs
        ex de,hl
        pop af
        ld c,a
        pop hl
        jr print_bg

; HL = text, B = row, C = attribute: centred in columns 0..39
print_centre:
        push hl
        ld e,0
.n:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        inc e
        jr .n
.e:     ld a,40
        sub e
        srl a
        push bc
        ld c,a
        call calc_ofs
        ex de,hl
        pop bc
        pop hl
        jr print_bg

; A = 0..99 as two digits at DE, attribute C
print_dec2:
        ld b,0
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     push af
        ld a,b
        call digit_bg
        pop af
digit_bg:                       ; A = 0..9 at DE (DE advanced), attribute C
        add a,20h
        push hl
        push de
        ex de,hl
        ld d,a
        ld e,c
        call bg_put
        pop de
        pop hl
        inc de
        ret

; 3-byte BCD at HL (low byte first) as six digits at DE, attribute C
print_bcd6:
        inc hl
        inc hl
        ld b,3
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        push bc
        call digit_bg
        pop bc
        ld a,(hl)
        and 0Fh
        push bc
        call digit_bg
        pop bc
        dec hl
        djnz .l
        ret

; score-style: BCD at HL as six digits and a fixed 0 (7 cells)
print_score:
        call print_bcd6
        xor a
        jr digit_bg

; fill B cells of BG from offset HL with char D, attribute E
fill_bg:
        call bg_put
        inc hl
        djnz fill_bg
        ret
