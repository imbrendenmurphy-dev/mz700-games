; =====================================================================
;  scroll.asm - the scrolling scenery and the parallax stars
;
;  Scenery lives in a ring of 32 rows x 32 bytes (SCNC chars, SCNA
;  attributes; char 0 = empty space).  Screen row r shows ring row
;  (scntop + r) & 31, so a scroll step is scntop-1 and a new top row.
;  Only rows that hold scenery (now or before the step) are rebuilt in
;  BG and W and compared in full at the flush, so open space is free.
;  Stars are single cells in BG in 3 layers at 3 speeds, drawn only where
;  the scenery is empty.
; =====================================================================

A_SPACE equ 70h                 ; empty space: (white on) black

; clear the scenery ring and the pieces
scn_clear:
        ld hl,SCNC
        ld de,SCNC+1
        ld bc,3FFh
        ld (hl),0
        ldir
        ld hl,SCNA
        ld de,SCNA+1
        ld bc,3FFh
        ld (hl),0
        ldir
        ld hl,SCNOCC
        ld b,32
.o:     ld (hl),0
        inc hl
        djnz .o
        ld hl,PIECEL
        ld b,MAXPC*PCSZ
.p:     ld (hl),0
        inc hl
        djnz .p
        xor a
        ld (scntop),a
        ret

; A = piece number, C = column: start a scenery piece entering at the top
add_piece:
        add a,a
        ld l,a
        ld h,0
        ld de,piecetab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = piece: w, h, rows
        ld hl,PIECEL
        ld b,MAXPC
.f:     inc hl
        ld a,(hl)
        dec hl
        or a
        jr z,.got
        push de
        ld de,PCSZ
        add hl,de
        pop de
        djnz .f
        ret                     ; (no room)
.got:   ld a,(de)               ; width
        inc de
        push af
        ld a,(de)               ; height
        inc de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c               ; PCX
        inc hl
        ld b,a
        pop af
        ld (hl),a               ; PCW
        inc hl
        ld (hl),b               ; PCR
        ret

; one scroll step of the scenery
scroll_step:
        ld a,(scntop)
        dec a
        and 31
        ld (scntop),a
        ; clear the new top ring row
        call scn_row            ; HL = SCNC row
        push hl
        ld b,PFW
.c:     ld (hl),0
        inc hl
        djnz .c
        ld a,(scntop)
        ld hl,SCNOCC
        add a,l
        ld l,a
        ld (hl),0
        pop hl
        ; pieces add their next row
        ld ix,PIECEL
        ld b,MAXPC
.pc:    push bc
        ld a,(ix+PCP+1)
        or a
        jr z,.pn
        call piece_row
.pn:    ld de,PCSZ
        add ix,de
        pop bc
        djnz .pc
        ; screen rows that show scenery now or did before: write the cells
        ; that differ from what the row showed before the step
        ld b,0
.r:     ld a,(scntop)
        add a,b
        and 31
        ld e,a
        ld h,high SCNOCC
        ld l,a
        ld c,(hl)
        inc a
        and 31
        ld l,a
        ld a,(hl)
        or c
        jr z,.rn
        push bc
        ld a,e
        call row_diff
        pop bc
.rn:    inc b
        ld a,b
        cp PFH
        jr nz,.r
        ret

; A = ring row now at screen row B (the row before it was ring row A+1)
row_diff:
        ld (rdrow),a
        ld c,0
        call calc_ofs
        dec hl
        push hl                 ; screen offset - 1 (for HL')
        ld a,(rdrow)
        inc a
        and 31
        call scn_row
        ex de,hl                ; DE = the old ring row
        ld a,(rdrow)
        call scn_row            ; HL = the new one
        exx
        pop hl
        exx
        ld b,PFW
.c:     exx
        inc hl
        exx
        ld a,(hl)
        ex de,hl
        cp (hl)
        ex de,hl
        jr nz,.up
        or a
        jr z,.nx
        set 2,h                 ; same char: the same colour?
        set 2,d
        ld a,(de)
        ld c,a
        ld a,(hl)
        res 2,h
        res 2,d
        cp c
        jr z,.nx
.up:    ld c,(hl)
        set 2,h
        ld a,(hl)
        res 2,h
        inc c
        dec c
        jr nz,.sa
        ld a,A_SPACE
.sa:    push hl
        push de
        push bc
        ld d,c
        ld e,a
        exx
        push hl
        exx
        pop hl
        call bg_put
        pop bc
        pop de
        pop hl
.nx:    inc hl
        inc de
        djnz .c
        ret

; A = ring row -> HL = its SCNC address (row * 32)
scn_row:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        or high SCNC
        ld h,a
        ret

; IX = piece: copy its next row into the new top ring row
piece_row:
        ld a,(scntop)
        call scn_row            ; HL = ring row
        ld a,(ix+PCX)
        add a,l
        ld l,a                  ; (rows are 32-aligned: no carry)
        ld e,(ix+PCP)
        ld d,(ix+PCP+1)
        ld b,(ix+PCW)
        ld c,0                  ; cells used
.l:     ld a,(de)
        inc de
        or a
        jr z,.skip
        push hl
        ld (hl),a
        set 2,h
        ld a,(de)
        ld (hl),a
        pop hl
        inc c
.skip:  inc de
        ld a,l                  ; (clip at the right edge)
        and 31
        cp PFW-1
        jr nc,.clip
        inc l
        djnz .l
        jr .done
.clip:  dec b                   ; skip the rest of the row
        jr z,.done
.cs:    inc de
        inc de
        djnz .cs
.done:  ld (ix+PCP),e
        ld (ix+PCP+1),d
        ld a,(scntop)
        ld hl,SCNOCC
        add a,l
        ld l,a
        ld a,(hl)
        add a,c
        ld (hl),a
        dec (ix+PCR)
        ret nz
        ld (ix+PCP+1),0         ; finished
        ret

; HL = playfield cell, B = row, C = column -> Z if the scenery there is empty
; (A = scenery char, E = attr; BC, HL preserved)
scn_at:
        push hl
        ld a,(scntop)
        add a,b
        and 31
        call scn_row
        ld a,c
        add a,l
        ld l,a
        ld a,(hl)
        set 2,h
        ld e,(hl)
        pop hl
        or a
        ret

; ---------------------------------------------------------------------
; stars: 4 bytes each: column, row fraction, row, layer (0 far .. 2 near)
stars_init:
        ld ix,STARS
        ld b,NSTARS
.s:     push bc
        ld a,(starw)
        call rand_n
        ld (ix+0),a
        call rand8
        ld (ix+1),a
        ld a,PFH
        call rand_n
        ld (ix+2),a
        ld a,b                  ; layers: 1/2 far, 1/3 mid, 1/6 near
        and 7
        ld c,0
        cp 4
        jr c,.l
        inc c
        cp 7
        jr c,.l
        inc c
.l:     ld (ix+3),c
        ld de,4
        add ix,de
        pop bc
        djnz .s
        ret

; draw every star where the scenery is empty (after a new screen)
stars_draw:
        ld ix,STARS
        ld b,NSTARS
.s:     push bc
        call star_put
        ld de,4
        add ix,de
        pop bc
        djnz .s
        ret

starspd: db 20h,40h,80h         ; rows per tick (x 256), far .. near
starglyph:                      ; (bank 2, so never mistaken for text)
        db 85h,90h              ; far: blue dot
        db 85h,0D0h             ; mid: cyan dot
        db 85h,0F0h             ; near: white dot

; move the stars (call after the scroll step)
stars_tick:
        ld ix,STARS
        ld b,NSTARS
.s:     push bc
        ld a,(ix+3)
        ld hl,starspd
        add a,l
        ld l,a
        jr nc,.n0
        inc h
.n0:    ld a,(hl)
        add a,(ix+1)
        ld (ix+1),a
        jr nc,.same
        ; to the next row: erase, move, draw
        call star_erase
        inc (ix+2)
        ld a,(ix+2)
        cp PFH
        jr c,.dr
        ld (ix+2),0             ; off the bottom: a new star at the top
        ld a,(starw)
        call rand_n
        ld (ix+0),a
.dr:    call star_put
        jr .nx
.same:
.nx:    ld de,4
        add ix,de
        pop bc
        djnz .s
        ret

; IX = star: put it in BG if the scenery (and BG) there is empty
star_put:
        ld b,(ix+2)
        ld c,(ix+0)
        call calc_ofs
        call bg_char
        ret nz
        call scn_at
        ret nz
        ld a,(ix+3)
        add a,a
        push hl
        ld hl,starglyph
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld d,(hl)
        inc hl
        ld e,(hl)
        pop hl
        jp bg_put

; IX = star: put the scenery (or space) back in its cell
star_erase:
        ld b,(ix+2)
        ld c,(ix+0)
        call calc_ofs
        call bg_char
        ret z
        cp 85h                  ; only a star is wiped
        ret nz
        call scn_at
        ret nz                  ; scenery there: the star wasn't drawn
        ld de,A_SPACE           ; D = 0 (empty), E = space
        jp bg_put

; HL = cell -> A = BG char there, Z if empty (HL kept)
bg_char:
        ld a,h
        add a,high BGCH
        ld h,a
        ld a,(hl)
        push af
        ld a,h
        sub high BGCH
        ld h,a
        pop af
        or a
        ret
