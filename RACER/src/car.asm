; =====================================================================
;  car.asm - the player's car: 12 x 4 cells of ROM characters at the
;  bottom of the road picture (rows 21-24).
;  A frame is 48 cells of (glyph, colour): glyph 0 = see-through; colour
;  bit 3 set = the background is the road's colour under the cell.
;  car_draw puts the colours into PK (before the blit); car_chars writes
;  the characters that changed (after it).
; =====================================================================

CARROW  equ 12          ; road picture row of the car's top (screen row 21)
CARCOL  equ 14

; pick a frame and colour the cells into PK
car_draw:
        ld hl,CARF_S
        ld a,(gstate)
        cp GS_CRASH
        jr nz,.st
        ld a,(gtimer)           ; crashing: spin (left, right ...)
        cp 20
        jr c,.pick
        and 4
        ld hl,CARF_L
        jr z,.pick
        ld hl,CARF_R
        jr .pick
.st:    ld a,(ckeys)
        and K_LEFT+K_RIGHT
        jr z,.pick
        ld hl,CARF_L
        cp K_LEFT
        jr z,.pick
        ld hl,CARF_R
.pick:  ld (carframe),hl
        ; shaken (bumps, the grass): the camera bounces
        xor a
        ld (carshift),a
        ld a,(shake)
        or a
        jr nz,.sh
        ld a,(offroad)
        or a
        jr z,.nb
        ld a,(speed+1)
        or a
        jr z,.nb
.sh:    ld a,(framecnt)
        and 1
.nb:    ld (bounce),a
.nosh:  ld a,(carshift)
        add a,CARCOL
        ld e,a
        ld d,(PK>>8)+CARROW/4
        ld a,CARROW&3
        rrca
        rrca
        add a,e
        ld e,a                  ; DE = PK + CARROW*64 + column
        ld hl,(carframe)
        ld c,4
.row:   push de
        ld b,12
.cell:  ld a,(hl)
        inc hl
        or a
        jr z,.skip
        ld a,(hl)
        bit 3,a
        jr z,.fix
        and 0F0h                ; foreground, the road's bottom colour
        ex de,hl
        xor (hl)
        and 0F0h
        xor (hl)
        ex de,hl
.fix:   ld (de),a
.skip:  inc hl
        inc e
        djnz .cell
        pop de
        ld a,e
        add a,64
        ld e,a
        jr nc,.nr
        inc d
.nr:    dec c
        jr nz,.row
        ret

; at the blank: the car's characters that changed (rows 21-24,
; columns 13-26, so a shaken car leaves no trail)
car_chars:
        ld hl,(carframe)        ; the same as last time?
        ld de,(carlast)
        or a
        sbc hl,de
        jr nz,.go
        ld a,(carshift)
        ld hl,carlshift
        cp (hl)
        ret z
.go:    ld hl,(carframe)
        ld (carlast),hl
        ld a,(carshift)
        ld (carlshift),a
        ld hl,carwant           ; build what should be there
        ld b,4*14
.cl:    ld (hl),HALF
        inc hl
        djnz .cl
        ld a,(carshift)
        inc a                   ; column within the 14
        ld e,a
        ld d,0
        ld hl,carwant
        add hl,de
        ex de,hl
        ld hl,(carframe)
        ld c,4
.r:     ld b,12
        push de
.c:     ld a,(hl)
        inc hl
        inc hl
        or a
        jr z,.n
        ld (de),a
.n:     inc de
        djnz .c
        pop de
        ld a,e
        add a,14
        ld e,a
        jr nc,.r2
        inc d
.r2:    dec c
        jr nz,.r
        ; compare with what is on screen and write the changes
        ld hl,carwant
        ld de,carhave
        ld ix,VRAM+(ROADROW+CARROW)*40+CARCOL-1
        ld c,4
.wr:    ld b,14
.wc:    ld a,(de)
        cp (hl)
        jr z,.same
        ld a,(hl)
        ld (de),a
        ld (ix+0),a
.same:  inc hl
        inc de
        inc ix
        djnz .wc
        push de
        ld de,40-14
        add ix,de
        pop de
        dec c
        jr nz,.wr
        ret

; after a full redraw of the road characters
car_reset:
        ld hl,0
        ld (carlast),hl
        ld hl,carhave
        ld b,4*14
.c:     ld (hl),HALF
        inc hl
        djnz .c
        ret
