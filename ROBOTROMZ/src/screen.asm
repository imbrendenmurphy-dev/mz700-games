; =====================================================================
;  screen.asm - vertical blank, work screen, draw lists, text
;
;  BG  = background (arena, frame, HUD, captions)
;  W   = BG + this tick's sprites, built in RAM
;  S   = shadow of VRAM
;  Each tick: restore() puts BG back into W under last tick's sprites,
;  the game put_cell()s this tick's sprites into W, and in the next
;  vertical blank flush() compares W with S over both lists and writes
;  only the cells that differ.
; =====================================================================

; ---------------------------------------------------------------------
; E002h bit 7 = /VBLK; measure which level is the short (blanking) one.
detect_vblank:
        ld hl,PPIC
        xor a
        ld (polx),a
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
        ld (polx),a             ; xor with this -> bit 7 = 0 in VBLANK
        ret

; wait for the start of the next vertical blank
; (a tick always starts at the start of a vertical blank, so if we are
;  still inside one it is the same one: wait for the next)
wait_vblank:
        ld hl,PPIC
        ld a,(polx)
        ld c,a
        ld de,0
.w0:    inc de
        ld a,(hl)
        xor c
        rla
        jr nc,.w0
.w1:    inc de
        ld a,(hl)
        xor c
        rla
        jr c,.w1
        ld (slack),de           ; idle time, 33 T per count
        ret

; ---------------------------------------------------------------------
; Layers (all page aligned, 1000-byte VRAM layout, so a buffer address is
; offset + high byte * 256):
;   BG  background: arena, frame, HUD, captions
;   OL  BG + robots, humans and effects.  Persistent: an object only touches
;       it when its cell or look changes ("sticky" sprites)
;   W   OL + this tick's transients (player, shots, bullets, pop-ups)
;   S   shadow of VRAM
; OCC holds the id of the object that owns (is visible in) each OL cell.
; When an owner leaves a cell, REDRAW is set there so that any object hidden
; underneath draws itself again.  Changed OL cells go on the dirty list.
; BOCC holds enemy bullets (transient, cleared every tick).

; HL = cell offset, D = char, E = attribute: draw a transient this tick
put_cell:
        ld bc,(curptr)
        ld a,b                  ; list full? (252 entries)
        rra
        jr nc,.ok
        ld a,c
        cp 0F8h
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

; same, for an enemy bullet: BOCC = A (80h + bullet index)
put_bocc:
        ld b,a
        ld a,h
        add a,high BOCC
        ld c,h
        ld h,a
        ld (hl),b
        ld h,c
        jr put_cell

; A = owner of cell HL (HL preserved, BC clobbered)
occ_at:
        ld a,h
        add a,high OCC
        ld b,a
        ld c,l
        ld a,(bc)
        ret

; A = enemy bullet in cell HL (HL preserved, BC clobbered)
bocc_at:
        ld a,h
        add a,high BOCC
        ld b,a
        ld c,l
        ld a,(bc)
        ret

; HL = cell: add it to the dirty list (or flag a full compare when full)
dl_add:
        ld bc,(dlptr)
        ld a,b
        rra
        jr nc,.ok
        ld a,c
        cp 0F8h
        jr c,.ok
        ld a,1
        ld (dlfull),a
        ret
.ok:    ld a,l
        ld (bc),a
        inc bc
        ld a,h
        ld (bc),a
        inc bc
        ld (dlptr),bc
        ret

; IX = object (id in curid), HL = its cell, D/E = its look.  Draws it into
; OL and W unless it's unchanged since last time.
obj_draw:
        ld a,(ix+ODRAWN)
        or a
        jr z,.new
        ld a,l
        cp (ix+OLOFS)
        jr nz,.mv
        ld a,h
        cp (ix+OLOFS+1)
        jr nz,.mv
        ld a,d
        cp (ix+OLC)
        jr nz,.mv
        ld a,e
        cp (ix+OLA)
        jr nz,.mv
        ld a,h                  ; uncovered since last time?
        add a,high REDRAW
        ld b,a
        ld c,l
        ld a,(bc)
        or a
        ret z                   ; steady: nothing to do
.mv:    push hl
        push de
        call obj_erase
        pop de
        pop hl
.new:   ld (ix+OLOFS),l
        ld (ix+OLOFS+1),h
        ld (ix+OLC),d
        ld (ix+OLA),e
        ld (ix+ODRAWN),1
        ld c,l
        ld a,h
        add a,high OLCH
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
        ld a,h
        add a,high OCC
        ld b,a
        ld a,(curid)
        ld (bc),a
        ld a,h
        add a,high REDRAW
        ld b,a
        xor a
        ld (bc),a
        jp dl_add

; IX = object (id in curid): take it off OL if it is drawn there
obj_erase:
        ld a,(ix+ODRAWN)
        or a
        ret z
        ld (ix+ODRAWN),0
        ld (ix+ODIRTY),1        ; (not drawn => dirty, always)
        ld l,(ix+OLOFS)
        ld h,(ix+OLOFS+1)
        ld c,l
        ld a,h
        add a,high OCC
        ld b,a
        ld a,(curid)
        ld e,a
        ld a,(bc)
        cp e
        ret nz                  ; something else is showing there now
        xor a
        ld (bc),a
        ld a,h
        add a,high REDRAW
        ld b,a
        ld a,1
        ld (bc),a
        ld a,h
        add a,high BGCH
        ld b,a
        ld a,(bc)
        ld d,a
        set 2,b
        ld a,(bc)
        ld e,a
        ld a,h
        add a,high OLCH
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
        jp dl_add

; put OL back into W (and clear BOCC) under last tick's transients
restore:
        ld a,(prevcnt)
        or a
        ret z
        ld (fcount),a
        ld hl,(prevlist)
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld l,e
        ld a,d
        add a,high OLCH
        ld h,a
        ld c,(hl)               ; OL char
        set 2,h
        ld b,(hl)               ; OL attribute
        ld a,d
        add a,high WAT
        ld h,a
        ld (hl),b
        res 2,h
        ld (hl),c
        ld a,d
        add a,high BOCC
        ld h,a
        ld (hl),0
        pop hl
        ld a,(fcount)
        dec a
        ld (fcount),a
        jr nz,.l
        ret

; in vertical blank: write changed cells, then swap the transient lists
flush:
        ld a,(dlfull)
        or a
        jr nz,.full
        ld hl,(dlptr)           ; objects that changed
        ld de,DLIST
        or a
        sbc hl,de
        srl h
        rr l
        ld a,l
        ex de,hl
        call flush_list
        jr .tr
.full:  call flush_all
        xor a
        ld (dlfull),a
.tr:    ld hl,DLIST
        ld (dlptr),hl
        ld hl,(prevlist)        ; transients: last tick's and this tick's
        ld a,(prevcnt)
        call flush_list
        ld hl,(curptr)          ; count = (curptr - curlist) / 2
        ld de,(curlist)
        or a
        sbc hl,de
        srl h
        rr l
        ld a,l
        ld (prevcnt),a
        ex de,hl
        call flush_list
        call flush_bg
        ld hl,(curlist)
        ld de,(prevlist)
        ld (prevlist),hl
        ld (curlist),de
        ld (curptr),de
        ret

flush_bg:
        ld hl,BGDL
        ld a,(bgcnt)
        call flush_list
        xor a
        ld (bgcnt),a
        ret

; HL = list of cell offsets, A = count
flush_list:
        or a
        ret z
        ld (fcount),a
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        call flush_cell
        pop hl
        ld a,(fcount)
        dec a
        ld (fcount),a
        jr nz,.l
        ret

; every cell (when the dirty list overflowed)
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
        ld h,a                  ; -> SAT
        ld a,b
        cp (hl)
        jr nz,.wr
        res 2,h                 ; -> SCH
        ld a,c
        cp (hl)
        ret z
        set 2,h
.wr:    ld (hl),b               ; shadow attribute
        res 2,h
        ld (hl),c               ; shadow char
        ld a,h
        add a,high (CRAM-SCH)
        ld h,a
        ld (hl),b
        res 3,h                 ; D8xx -> D0xx
        ld (hl),c
        ret

; ---------------------------------------------------------------------
; background cell HL = (D char, E attr); shows at the next flush.
; (Also into OL and W; objects in that cell draw themselves again.)
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
        add a,high OLCH
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
        ld a,h
        add a,high REDRAW
        ld b,a
        ld a,1
        ld (bc),a
        pop bc
        ld a,(bgcnt)
        cp 250
        ret nc
        inc a
        ld (bgcnt),a
        push hl
        push bc
        push de
        ex de,hl                ; DE = offset
        ld l,a
        ld h,0
        add hl,hl
        ld bc,BGDL-2
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        pop de
        pop bc
        pop hl
        ret

; copy BG to OL, W, S and the real screen in one go (screen changes).
; Every object will draw itself again.
refresh_all:
        ld hl,BGCH
        ld de,OLCH
        ld bc,1000
        ldir
        ld hl,BGAT
        ld de,OLAT
        ld bc,1000
        ldir
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
        call wait_vblank
        ld hl,SAT
        ld de,CRAM
        ld bc,1000
        ldir
        ld hl,SCH
        ld de,VRAM
        ld bc,1000
        ldir
        ld hl,OCC
        ld de,OCC+1
        ld bc,999
        ld (hl),0
        ldir
        ld hl,BOCC
        ld de,BOCC+1
        ld bc,999
        ld (hl),0
        ldir
        ld hl,REDRAW
        ld de,REDRAW+1
        ld bc,999
        ld (hl),0
        ldir
        ld a,(objtop)           ; nothing is drawn on OL any more
        or a
        jr z,.no
        ld b,a
        ld hl,OBJ+ODRAWN
        ld de,OBJSZ
.o:     ld (hl),0               ; not drawn
        inc hl
        ld (hl),1               ; so dirty (ODIRTY follows ODRAWN)
        dec hl
        add hl,de
        djnz .o
.no:    xor a
        ld (prevcnt),a
        ld (bgcnt),a
        ld (dlfull),a
        ld hl,(curlist)
        ld (curptr),hl
        ld hl,DLIST
        ld (dlptr),hl
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

; B = row, C = column -> HL = cell offset (DE preserved)
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

; HL = text, B = row, C = attribute: centred on the row
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

; fill B cells of BG from offset HL with char D, attribute E
fill_bg:
        call bg_put
        inc hl
        djnz fill_bg
        ret
