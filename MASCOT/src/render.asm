; =====================================================================
;  render.asm - overlay compositing and dirty-cell flushing
;
;  Each frame:  [VBLANK] flush: every cell in list A (sprites last frame)
;  and list B (cells touched since) whose overlay differs from the shadow
;  is written to VRAM.  Then A := B, B := empty.
;  Logic:       tile changes call mark_static (overlay <- tile, add to B).
;  Compose:     restore_old puts the background back into the overlay for
;  every cell in A, then sprites are drawn into the overlay (added to B).
;  So the screen is only ever written once per cell per frame, with its
;  final value: no flicker, and no full redraws.
; =====================================================================

; ---------------------------------------------------------------------
; list management
; ---------------------------------------------------------------------
lists_reset:
        ld hl,LISTA
        ld (lista),hl
        ld (lista_end),hl
        ld hl,LISTB
        ld (listb),hl
        ld (listb_end),hl
        ret

; HL = overlay char address -> append to list B (HL kept)
list_add:
        push de
        ex de,hl
        ld hl,(listb_end)
        ld (hl),e
        inc l
        ld (hl),d
        inc hl
        ; a list is 512 bytes from a 512-aligned base: stop when full
        ld a,h
        and 1
        or l
        jr z,.full
        ld (listb_end),hl
.full:  ex de,hl
        pop de
        ret

; ---------------------------------------------------------------------
; flush (call at the start of VBLANK)
; ---------------------------------------------------------------------
flush:
        ld hl,(lista)
        ld de,(lista_end)
        call flush_list
        ld hl,(listb)
        ld de,(listb_end)
        call flush_list
        ; A := B, B := old A storage, emptied
        ld hl,(lista)
        ld de,(listb)
        ld (lista),de
        ld de,(listb_end)
        ld (lista_end),de
        ld (listb),hl
        ld (listb_end),hl
        ret

; HL = list start, DE = list end
flush_list:
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
        ex de,hl                    ; HL = OVC address
        ld a,(hl)
        set 2,h                     ; SHC
        cp (hl)
        jr z,.a
        ld (hl),a
        res 2,h
        set 4,h                     ; VRAM char
        ld (hl),a
        res 4,h
.a:     res 2,h
        set 3,h                     ; OVA
        ld a,(hl)
        set 2,h                     ; SHA
        cp (hl)
        jr z,.n
        ld (hl),a
        res 2,h
        set 4,h                     ; VRAM attr
        ld (hl),a
.n:     pop hl
        pop de
        jr .l

; ---------------------------------------------------------------------
; background restore
; ---------------------------------------------------------------------
; HL = overlay char address: overlay <- the tile's char/attr (HL kept)
restore_cell:
        ld a,h
        sub 10h                     ; ROOMT
        ld b,a
        ld c,l
        ld a,(bc)
        ld c,a
        ld b,high TCHR
        ld a,(bc)
        ld (hl),a
        inc b                       ; TATR
        ld a,(bc)
        set 3,h
        ld (hl),a
        res 3,h
        ret

; overlay <- background for every cell drawn last frame
restore_old:
        ld hl,(lista)
        ld de,(lista_end)
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
        ex de,hl
        call restore_cell
        pop hl
        pop de
        jr .l

; a tile changed: HL = offset (0-919) -> overlay refresh + flush next frame
mark_static_off:
        ld de,OVC
        add hl,de
mark_static:
        call restore_cell
        jp list_add

; HL = OVC address of (B = col, C = row) (no range check)
cell_ov:
        ld a,c
        add a,a
        ld l,a
        ld h,high ROWOV
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,b
        ld l,a
        ret nc
        inc h
        ret

; ---------------------------------------------------------------------
; draw_sprite: HL = frame, B = x, C = y (signed cells), A = remap page
; (high byte of a 256-byte attribute table)
; ---------------------------------------------------------------------
draw_sprite:
        ld (.remap+1),a
        ld a,(hl)
        ld (ds_w),a
        inc hl
        ld a,(hl)
        ld (ds_h),a
        inc hl
        ld a,(hl)
        add a,b
        ld (ds_col0),a
        inc hl
        ld a,(hl)
        add a,c
        ld (ds_row),a
        inc hl
.row:   ld a,(ds_row)
        cp ROOMH
        jr nc,.skiprow              ; above or below the playfield
        add a,a
        ld e,a
        ld d,high ROWOV
        ld a,(de)
        inc e
        push af
        ld a,(de)
        ld d,a
        pop af
        ld e,a                      ; DE = row base in the overlay
        ld a,(ds_col0)
        ld c,a
        ld a,(ds_w)
        ld b,a
.cell:  ld a,c
        cp ROOMW
        jr nc,.skip2                ; off the sides
        ld a,(hl)
        inc hl
        ld (ds_ch),a
        or (hl)
        jr z,.skip1                 ; empty cell
        ld a,(hl)
        inc hl
        push hl
        push bc
        ld l,a
.remap: ld h,0
        ld b,(hl)                   ; recoloured attribute
        ld a,e
        add a,c
        ld l,a
        ld a,d
        adc a,0
        ld h,a                      ; HL = overlay char address
        bit 3,b
        jr z,.opaque
        set 3,h                     ; transparent: keep the bg colour below
        ld a,(hl)
        and 07h
        ld c,a
        ld a,b
        and 0F0h
        or c
        ld b,a
        res 3,h
.opaque:
        ld a,(ds_ch)
        ld (hl),a
        set 3,h
        ld (hl),b
        res 3,h
        call list_add
        pop bc
        pop hl
        jr .next
.skip2: inc hl
.skip1: inc hl
.next:  inc c
        djnz .cell
        ld (ds_ptr),hl
.nextrow:
        ld hl,ds_row
        inc (hl)
        ld hl,ds_h
        dec (hl)
        ret z
        ld hl,(ds_ptr)
        jr .row
.skiprow:
        ld a,(ds_w)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld (ds_ptr),hl
        jr .nextrow
