; =====================================================================
;  render.asm - the cell compositor
;
;  Screen images (40 x 25, chars then attrs 800h on): BG B000h (the
;  stage), COMP C000h (stage + sprites, built only inside boxes), SHOWN
;  C400h (what VRAM holds; interleaved with COMP: 1000 bytes fit in 400h)
;  and VRAM D000h.  From a COMP address: SHOWN = set 2,h, VRAM = set 4,h,
;  attrs = set 3,h, BG = COMP - 1000h.
;
;  Each frame, for every object the union of its previous and current
;  box is copied BG -> COMP, every object is drawn into COMP, and the
;  unions are compared with SHOWN: only cells that changed are written
;  to VRAM.  Animated stage cells go through the same path (anim list).
; =====================================================================

; object slots (OBJ, NOBJ x 32 bytes)
O_TYPE  equ 0           ; 0 off, 1 fighter frame, 2 cell block
O_COL   equ 1           ; anchor column (frames) / left column (blocks), signed
O_ROW   equ 2           ; ground row (frames) / top row (blocks)
O_PTR   equ 3           ; data pointer (word)
O_FLAGS equ 5           ; bit 0 mirrored
O_DICT  equ 6           ; dict page (frames)
O_XLAT  equ 7           ; attribute translation page
O_PBOX  equ 8           ; previous box c0,r0,c1,r1 (c0 = FFh none)
O_BOX   equ 12          ; current box
O_UBOX  equ 16          ; union box
OBJSZ   equ 32

ROW_MIN equ 3           ; sprites never draw over the HUD
ROW_MAX equ 24

; ---------------------------------------------------------------------
; render: one composited frame
render:
        ; current boxes and unions
        ld ix,OBJ
        ld b,NOBJ
.bx:    push bc
        call obj_box
        call obj_union
        ld de,OBJSZ
        add ix,de
        pop bc
        djnz .bx
        ; restore the stage under every union
        ld ix,OBJ
        ld b,NOBJ
.cp:    push bc
        ld a,(ix+O_UBOX)
        cp 0FFh
        call nz,box_copy
        ld de,OBJSZ
        add ix,de
        pop bc
        djnz .cp
        call anim_copy
        ; sprites
        call hi_in
        ld ix,OBJ
        ld b,NOBJ
.dr:    push bc
        ld a,(ix+O_TYPE)
        dec a
        call z,draw_frame
        ld a,(ix+O_TYPE)
        cp 2
        call z,draw_block
        ld de,OBJSZ
        add ix,de
        pop bc
        djnz .dr
        call hi_out
        ; compare and write
        ld ix,OBJ
        ld b,NOBJ
.df:    push bc
        ld a,(ix+O_UBOX)
        cp 0FFh
        call nz,box_diff
        ; current box becomes previous
        ld a,(ix+O_BOX)
        ld (ix+O_PBOX),a
        ld a,(ix+O_BOX+1)
        ld (ix+O_PBOX+1),a
        ld a,(ix+O_BOX+2)
        ld (ix+O_PBOX+2),a
        ld a,(ix+O_BOX+3)
        ld (ix+O_PBOX+3),a
        ld de,OBJSZ
        add ix,de
        pop bc
        djnz .df
        jp anim_diff

; ---------------------------------------------------------------------
; obj_box: IX = object -> current box (clipped) at O_BOX
obj_box:
        ld (ix+O_BOX),0FFh
        ld a,(ix+O_TYPE)
        or a
        ret z
        ld l,(ix+O_PTR)
        ld h,(ix+O_PTR+1)
        cp 2
        jr z,.block
        call hi_in
        ld b,(hl)               ; height
        inc hl
        ld d,(hl)               ; minc
        inc hl
        ld e,(hl)               ; maxc
        call hi_out
        ld a,(ix+O_COL)
        bit 0,(ix+O_FLAGS)
        jr nz,.mir
        ld c,a
        add a,d
        ld d,a                  ; c0
        ld a,c
        add a,e
        ld e,a                  ; c1
        jr .rows
.mir:   dec a
        ld c,a                  ; col-1
        sub e
        ld h,a                  ; c0 = col-1-maxc
        ld a,c
        sub d
        ld e,a                  ; c1 = col-1-minc
        ld d,h
.rows:  ld a,(ix+O_ROW)
        ld c,a                  ; r1
        sub b
        inc a                   ; r0
        ld b,a
        jr clip_box
.block: ld a,(hl)               ; w (blocks live in the program)
        inc hl
        ld c,(hl)               ; h
        dec a
        add a,(ix+O_COL)
        ld e,a                  ; c1
        ld d,(ix+O_COL)         ; c0
        ld a,c
        dec a
        add a,(ix+O_ROW)
        ld c,a                  ; r1
        ld b,(ix+O_ROW)         ; r0
; clip D = c0, E = c1, B = r0, C = r1 (signed) and store at O_BOX
clip_box:
        bit 7,d
        jr z,$+4
        ld d,0
        bit 7,e
        ret nz                  ; c1 < 0: off screen
        ld a,e
        cp 40
        jr c,$+4
        ld e,39
        ld a,d
        cp 40
        ret nc                  ; c0 >= 40
        cp e
        jr z,.cok
        ret nc                  ; c0 > c1
.cok:   bit 7,c
        ret nz
        ld a,c
        cp ROW_MAX+1
        jr c,$+4
        ld c,ROW_MAX
        ld a,b
        bit 7,a
        jr nz,.r0
        cp ROW_MIN
        jr nc,.r0k
.r0:    ld b,ROW_MIN
.r0k:   ld a,b
        cp c
        jr z,.rok
        ret nc
.rok:   ld (ix+O_BOX),d
        ld (ix+O_BOX+1),b
        ld (ix+O_BOX+2),e
        ld (ix+O_BOX+3),c
        ret

; obj_union: O_UBOX = O_PBOX u O_BOX
obj_union:
        ld a,(ix+O_PBOX)
        cp 0FFh
        jr z,.cur
        ld a,(ix+O_BOX)
        cp 0FFh
        jr z,.prev
        ld a,(ix+O_PBOX)        ; min c0
        cp (ix+O_BOX)
        jr c,$+5
        ld a,(ix+O_BOX)
        ld (ix+O_UBOX),a
        ld a,(ix+O_PBOX+1)      ; min r0
        cp (ix+O_BOX+1)
        jr c,$+5
        ld a,(ix+O_BOX+1)
        ld (ix+O_UBOX+1),a
        ld a,(ix+O_PBOX+2)      ; max c1
        cp (ix+O_BOX+2)
        jr nc,$+5
        ld a,(ix+O_BOX+2)
        ld (ix+O_UBOX+2),a
        ld a,(ix+O_PBOX+3)      ; max r1
        cp (ix+O_BOX+3)
        jr nc,$+5
        ld a,(ix+O_BOX+3)
        ld (ix+O_UBOX+3),a
        ret
.cur:   ld a,(ix+O_BOX)
        ld (ix+O_UBOX),a
        ld a,(ix+O_BOX+1)
        ld (ix+O_UBOX+1),a
        ld a,(ix+O_BOX+2)
        ld (ix+O_UBOX+2),a
        ld a,(ix+O_BOX+3)
        ld (ix+O_UBOX+3),a
        ret
.prev:  ld a,(ix+O_PBOX)
        ld (ix+O_UBOX),a
        ld a,(ix+O_PBOX+1)
        ld (ix+O_UBOX+1),a
        ld a,(ix+O_PBOX+2)
        ld (ix+O_UBOX+2),a
        ld a,(ix+O_PBOX+3)
        ld (ix+O_UBOX+3),a
        ret

; HL = COMP address of (D = col, A = row).  Keeps BC, DE.
comp_addr:
        add a,a
        ld l,a
        ld h,high ROWTAB
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,d
        ld l,a
        ret nc
        inc h
        ret

