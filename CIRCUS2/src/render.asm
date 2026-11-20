; =====================================================================
;  render.asm - the play screen compositor
;
;  The background (BGC/BGA) holds everything static or slow: canopy,
;  poles, balloon rows, rope, floor, HUD.  Moving things are "objects":
;  each frame they are put into a list of cells (NLO..NAT) and the OCC
;  map remembers which list entry covers a cell.  present() then writes
;  to VRAM only the cells that differ from the shadow copy (SHC/SHA):
;  rows marked in ROWDIRTY, this frame's object cells and last frame's
;  object cells (which fall back to the background).
; =====================================================================

; forget what is on the screen: the next present() rewrites every cell
; it touches; also empties the object lists
shadow_reset:
        ld hl,SHA
        ld de,SHA+1
        ld bc,999
        ld (hl),OWNBG               ; an attr the compositor never produces
        ldir
        ld hl,OCC
        ld de,OCC+1
        ld bc,999
        ld (hl),0
        ldir
        xor a
        ld (nent),a
        ld (onent),a
        ld (ndirty),a
        ld hl,ROWDIRTY
        ld b,25
.d:     ld (hl),a
        inc hl
        djnz .d
        ret

; mark every row dirty (full recompose on the next present)
all_dirty:
        ld hl,ROWDIRTY
        ld b,25
.d:     ld (hl),1
        inc hl
        djnz .d
        ret

; fill the background with blanks of attr A
bg_fill:
        push af
        ld hl,BGC
        ld de,BGC+1
        ld bc,999
        ld (hl),0
        ldir
        pop af
        ld hl,BGA
        ld de,BGA+1
        ld bc,999
        ld (hl),a
        ldir
        jr all_dirty

; HL = BGC address of (D = row, E = col)
bg_addr:
        ld a,d
        add a,a
        ld l,a
        ld h,high ROWTAB
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,e
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; background cell: D = row, E = col, C = char, B = attr (marks the row)
bg_put:
        push hl
        call bg_addr
        ld (hl),c
        set 2,h
        ld (hl),b
        call row_dirty
        pop hl
        ret

; a background cell changed on its own: HL = BGC address, D = its row
; (if the list is full the whole row is redone)
bg_touch:
        ld a,(ndirty)
        cp MAXENT
        jr nc,row_dirty
        inc a
        ld (ndirty),a
        push de
        ld e,a
        ld d,high DLO
        ld a,l
        ld (de),a
        inc d
        ld a,h
        ld (de),a
        pop de
        ret

; ROWDIRTY[D] = 1
row_dirty:
        push hl
        ld hl,ROWDIRTY
        ld a,l
        add a,d
        ld l,a
        ld (hl),1
        pop hl
        ret

; background text: HL = ASCII (0-terminated), D = row, E = col, B = attr
; returns E after the text
bg_print:
        call row_dirty
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        push hl
        ld l,a
        ld h,high ATOD
        ld c,(hl)
        call bg_put
        pop hl
        inc e
        jr .l

; centred background text: HL = text, D = row, B = attr
bg_centre:
        push hl
        call strlen
        pop hl
        ld c,a
        ld a,40
        sub c
        srl a
        ld e,a
        jr bg_print

; A = length of the string at HL
strlen:
        push hl
        ld c,0
.l:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        inc c
        jr .l
.e:     ld a,c
        pop hl
        ret

; fill background cells: D = row, E = col, B = attr, C = char, A = count
bg_fill_run:
        push af
        call bg_addr
        call row_dirty
        pop af
.l:     ld (hl),c
        set 2,h
        ld (hl),b
        res 2,h
        inc hl
        dec a
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; objects
; ---------------------------------------------------------------------
; put an object cell at (D = row, E = col), C = char, B = attr spec
; (fg/bank; the background colour comes from the background unless
; OWNBG is set).  Clipped to rows 1..22, columns 1..38.
put_at:
        ld a,d
        dec a
        cp 22
        ret nc
        ld a,e
        dec a
        cp 38
        ret nc
        call bg_addr
; HL = BGC address
put_cell:
        ld a,h
        add a,10h
        ld h,a                      ; OCC
        ld a,(hl)
        or a
        jr nz,.over
        ld a,(nent)
        cp MAXENT
        ret nc
        inc a
        ld (nent),a
        ld (hl),a
        push de
        ld e,a
        ld d,high NLO
        ld a,l
        ld (de),a
        inc d
        ld a,h
        sub 10h
        ld (de),a
        inc d
        ld a,c
        ld (de),a
        inc d
        ld a,b
        ld (de),a
        pop de
        ret
.over:  push de                     ; a later object covers an earlier one
        ld e,a
        ld d,high NCH
        ld a,c
        ld (de),a
        inc d
        ld a,b
        ld (de),a
        pop de
        ret

; object text: HL = ASCII, D = row, E = col, B = attr; spaces are
; transparent
put_text:
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        cp ' '
        jr z,.n
        push hl
        ld l,a
        ld h,high ATOD
        ld c,(hl)
        push de
        call put_at
        pop de
        pop hl
.n:     inc e
        jr .l

; ---------------------------------------------------------------------
; present: bring the screen up to date
; ---------------------------------------------------------------------
present:
        ; 1. dirty rows
        ld de,ROWDIRTY
        ld b,0
.rows:  ld a,(de)
        or a
        jr z,.rn
        xor a
        ld (de),a
        push bc
        push de
        ld a,b
        add a,a
        ld l,a
        ld h,high ROWTAB
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,40
.rc:    push af
        call cell_out
        inc hl
        pop af
        dec a
        jr nz,.rc
        call poll
        pop de
        pop bc
.rn:    inc e
        inc b
        ld a,b
        cp 25
        jr c,.rows
        ; 1b. single background cells
        ld a,(ndirty)
        or a
        jr z,.objs
        ld b,a
        ld c,1
.dc:    push bc
        ld l,c
        ld h,high DHI
        ld a,(hl)
        dec h                       ; DLO
        ld l,(hl)
        ld h,a
        call cell_out
        pop bc
        ld a,c
        and 15
        call z,poll
        inc c
        djnz .dc
        xor a
        ld (ndirty),a
        ; 2. this frame's objects
.objs:  ld a,(nent)
        or a
        jr z,.old
        ld b,a
        ld c,1
.new:   push bc
        ld l,c
        ld h,high NHI
        ld a,(hl)
        dec h                       ; NLO
        ld l,(hl)
        ld h,a
        call cell_out
        pop bc
        ld a,c
        and 15
        call z,poll
        inc c
        djnz .new
        ; 3. last frame's objects (now background, unless covered again)
.old:   ld a,(onent)
        or a
        jr z,.clr
        ld b,a
        ld c,1
.o:     push bc
        ld l,c
        ld h,high OHI
        ld a,(hl)
        dec h                       ; OLO
        ld l,(hl)
        ld h,a
        call cell_out
        pop bc
        ld a,c
        and 15
        call z,poll
        inc c
        djnz .o
        ; 4. clear OCC, this frame's list becomes last frame's
.clr:   ld a,(nent)
        ld (onent),a
        or a
        ret z
        ld b,a
        ld c,1
.c:     ld l,c
        ld h,high NHI
        ld a,(hl)
        ld d,a
        dec h
        ld a,(hl)
        ld h,high OLO
        ld (hl),a
        inc h                       ; OHI
        ld (hl),d
        ld l,a
        ld a,d
        add a,10h
        ld h,a                      ; OCC
        ld (hl),0
        inc c
        djnz .c
        xor a
        ld (nent),a
present_done:
        ret

; cell_out: HL = BGC + offset.  Composes the cell (object or background),
; writes it to VRAM if the shadow differs.  Keeps HL; uses AF, BC, DE.
cell_out:
        ld a,h
        add a,10h                   ; OCC
        ld h,a
        ld a,(hl)
        or a
        jr nz,.obj
        ld a,h
        sub 10h-4                   ; BGA
        ld h,a
        ld b,(hl)
        res 2,h                     ; BGC
        ld c,(hl)
        jr .cmp
.obj:   ld e,a
        ld d,high NCH
        ld a,(de)
        ld c,a
        inc d                       ; NAT
        ld a,(de)
        bit 3,a
        jr nz,.own
        and 0F0h
        ld b,a
        ld a,h
        sub 10h-4                   ; BGA
        ld h,a
        ld a,(hl)
        and 07h
        or b
        ld b,a
        res 2,h                     ; BGC
        jr .cmp
.own:   and 0F7h
        ld b,a
        ld a,h
        sub 10h
        ld h,a
.cmp:   set 3,h                     ; SHC
        ld a,(hl)
        cp c
        jr nz,.wc
        set 2,h                     ; SHA
        ld a,(hl)
        cp b
        jr nz,.wa
        ld a,h
        and 0F3h                    ; BGC
        ld h,a
        ret
.wc:    ld (hl),c                   ; SHC
        ld a,h
        add a,28h
        ld h,a                      ; VRAM
        ld (hl),c
        set 3,h                     ; ARAM
        ld (hl),b
        sub 24h
        ld h,a                      ; SHA
        ld (hl),b
        sub 0Ch
        ld h,a                      ; BGC
        ret
.wa:    ld (hl),b                   ; SHA
        ld a,h
        add a,2Ch
        ld h,a                      ; ARAM
        ld (hl),b
        sub 38h
        ld h,a                      ; BGC
        ret
