; =====================================================================
;  render.asm - background buffers and per-frame overlays
;
;  BGCH/BGAT hold what the screen shows without moving things (maze,
;  pellets, HUD).  Every frame the game builds a list of overlay cells
;  (actors, items, pop-up text, particles).  render, called at the start
;  of VBLANK, puts back the cells drawn last frame from the background,
;  copies changed background cells, sweeps a palette change a few rows at
;  a time, then draws the new overlay list.  An overlay attribute without
;  bit 3 takes its background colour from the cell underneath.
; =====================================================================

ovl_init:
        ld hl,OVL0
        ld (ov_draw),hl
        ld (hl),0
        ld hl,OVL1
        ld (ov_build),hl
        ld (hl),0
        xor a
        ld (dirty_n),a
        ld (rc_row),a
        ret

; forget what is on screen (after a full redraw)
ovl_forget:
        ld hl,(ov_draw)
        ld (hl),0
        ld hl,(ov_build)
        ld (hl),0
        xor a
        ld (dirty_n),a
        ret

; start a new overlay list
ovl_clear:
        ld hl,(ov_build)
        ld (hl),0
        ret

; ovl_add: DE = VRAM address, A = char, C = attr.  Keeps BC, DE, HL.
ovl_add:
        push hl
        push af
        ld hl,(ov_build)
        ld a,(hl)
        cp OVMAX
        jr nc,.full
        inc (hl)
        add a,a
        add a,a
        inc a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop af
        ld (hl),a
        inc hl
        ld (hl),c
        pop hl
        ret
.full:  pop af
        pop hl
        ret

; grid (B = x, C = y) -> HL = VRAM address.  Keeps BC, DE.
grid_scr:
        push de
        ld a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,SROW
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,b
        add hl,de
        pop de
        ret

; is grid (B, C) on screen?  NC = yes.  Keeps BC, DE, HL.
grid_vis:
        ld a,b
        dec a
        cp 39
        ccf
        ret c
        ld a,c
        dec a
        cp 19
        ccf
        ret

; overlay at grid (B = x, C = y): A = char, E = attr.  Keeps BC, DE.
ovl_grid:
        push hl
        push de
        ld d,a
        call grid_vis
        jr c,.no
        call grid_scr
        ld a,d
        push bc
        ld c,e
        ex de,hl
        call ovl_add
        pop bc
.no:    pop de
        pop hl
        ret

; overlay text: HL = ASCII string, B = x, C = y (grid), E = attr.
; Characters off the maze are skipped.  Keeps C, E.
ovl_text:
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        call ovl_grid
        pop hl
        inc b
        jr .l

; mark a background cell for copying to the screen: HL = VRAM address.
; Keeps everything but AF.
dirty_add:
        push de
        ld a,(dirty_n)
        cp DIRTYMAX
        jr nc,.x
        inc a
        ld (dirty_n),a
        dec a
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,DIRTY
        add hl,de
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ex de,hl
.x:     pop de
        ret

; ---------------------------------------------------------------------
render:
        ld hl,(ov_draw)             ; 1. restore last frame's overlays
        ld b,(hl)
        inc hl
        inc b
        dec b
        jr z,.r9
.r1:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        inc hl
        push hl
        ld h,d
        ld l,e
        res 6,h
        ld a,(hl)
        ld (de),a
        set 3,h
        set 3,d
        ld a,(hl)
        ld (de),a
        pop hl
        djnz .r1
.r9:    ld a,(dirty_n)              ; 2. changed background cells
        or a
        jr z,.d9
        ld b,a
        ld hl,DIRTY
.d1:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld h,d
        ld l,e
        res 6,h
        ld a,(hl)
        ld (de),a
        set 3,h
        set 3,d
        ld a,(hl)
        ld (de),a
        pop hl
        djnz .d1
        xor a
        ld (dirty_n),a
.d9:    ld a,(rc_row)               ; 3. palette sweep
        or a
        call nz,recolour_step
        ld hl,(ov_build)            ; 4. new overlays
        ld b,(hl)
        inc hl
        inc b
        dec b
        jr z,.w9
.w1:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (de),a
        ld c,(hl)
        inc hl
        push hl
        ld a,c
        bit 3,a
        jr nz,.op
        ld h,d
        ld l,e
        res 6,h
        set 3,h
        ld a,(hl)
        and 07h
        or c
        jr .st
.op:    res 3,a
.st:    set 3,d
        ld (de),a
        pop hl
        djnz .w1
.w9:    ld hl,(ov_draw)             ; 5. swap lists
        ld de,(ov_build)
        ld (ov_draw),de
        ld (ov_build),hl
        ld (hl),0
        ret

; ---------------------------------------------------------------------
; palette: A = 0 normal, 1 power.  Starts a sweep down the maze.
set_palette:
        ld (palette),a
        or a
        ld hl,(pal_norm)
        jr z,.n
        ld hl,(pal_power)
.n:     ld de,PALCUR
        ld bc,9
        ldir
        ld a,1
        ld (rc_row),a
        ret

; redraw three maze rows (background and screen) with the current palette
recolour_step:
        ld e,3
.row:   ld a,(rc_row)
        ld c,a
        ld b,1
.x:     push de
        call cell_put
        ld (hl),d
        set 3,h
        ld (hl),e
        pop de
        inc b
        ld a,b
        cp 40
        jr nz,.x
        ld a,c
        inc a
        cp 20
        jr c,.ok
        xor a
.ok:    ld (rc_row),a
        or a
        ret z
        dec e
        jr nz,.row
        ret

; finish any palette sweep at once (before full-screen changes)
recolour_all:
.l:     ld a,(rc_row)
        or a
        ret z
        call recolour_step
        call poll
        jr .l

; ---------------------------------------------------------------------
; screen-position overlays (front end)
; overlay at column B, row C: A = char, E = attr.  Off-screen columns
; (including negative ones) are skipped.  Keeps BC, DE.
ovl_sc:
        push hl
        push de
        ld d,a
        ld a,b
        cp 40
        jr nc,.no
        ld a,c
        cp 25
        jr nc,.no
        push de
        call vaddr
        ex de,hl
        pop de
        ld a,d
        push bc
        ld c,e
        ex de,hl
        call ovl_add
        pop bc
.no:    pop de
        pop hl
        ret

; overlay text at column B, row C: HL = ASCII, E = attr.  Keeps C, E.
ovl_sc_text:
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        call ovl_sc
        pop hl
        inc b
        jr .l

; big sprite A at column B, row C (B may be negative)
draw_big:
        add a,a
        ld e,a
        ld d,0
        ld hl,BIGTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                      ; 9 cells: char, attr
        ld d,3
.r:     push bc
        ld e,3
.c:     ld a,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        or a
        call nz,ovl_sc
        pop de
        inc b
        dec e
        jr nz,.c
        pop bc
        inc c
        dec d
        jr nz,.r
        ret
