; =====================================================================
;  render2.asm - compositor part 2: box copy/diff, sprite drawers, anim
; =====================================================================

; box setup: O_UBOX -> HL = COMP address of the top-left, bx_w, bx_rows
box_setup:
        ld d,(ix+O_UBOX)
        ld a,(ix+O_UBOX+2)
        sub d
        inc a
        ld (bx_w),a
        ld a,(ix+O_UBOX+3)
        sub (ix+O_UBOX+1)
        inc a
        ld (bx_rows),a
        ld a,(ix+O_UBOX+1)
        jp comp_addr

; box_copy: BG -> COMP over O_UBOX
box_copy:
        call box_setup
.r:     push hl
        ld d,h
        ld e,l
        ld a,h
        sub 10h
        ld h,a                  ; BG chars
        ld bc,(bx_w)
        ldir
        pop hl
        push hl
        ld a,h
        or 8
        ld d,a                  ; COMP attrs
        sub 10h
        ld h,a                  ; BG attrs
        ld e,l
        ld bc,(bx_w)
        ldir
        pop hl
        ld de,40
        add hl,de
        ld a,(bx_rows)
        dec a
        ld (bx_rows),a
        jr nz,.r
        ret

; box_diff: COMP vs SHOWN over O_UBOX; changed bytes go to SHOWN and VRAM
box_diff:
        call box_setup
.r:     push hl
        call diff_run
        pop hl
        push hl
        set 3,h
        call diff_run
        pop hl
        ld de,40
        add hl,de
        ld a,(bx_rows)
        dec a
        ld (bx_rows),a
        jr nz,.r
        ret

; compare bx_w bytes from HL (COMP) with SHOWN; write the changes
diff_run:
        ld a,(bx_w)
        ld b,a
.c:     ld a,(hl)
        set 2,h
        cp (hl)
        jr nz,.w
        res 2,h
        inc hl
        djnz .c
        ret
.w:     ld (hl),a               ; SHOWN
        res 2,h
        set 4,h
        ld (hl),a               ; VRAM
        res 4,h
        inc hl
        djnz .c
        ret

; ---------------------------------------------------------------------
; draw_frame: IX = object (type 1).  Draws its frame into COMP, clipped to
; columns 0-39 and rows ROW_MIN-ROW_MAX.  High RAM must be paged in.
draw_frame:
        ld a,(ix+O_COL)
        ld (df_col),a
        ld a,(ix+O_XLAT)
        exx
        ld b,a                  ; B' = xlat page
        exx
        ld l,(ix+O_PTR)
        ld h,(ix+O_PTR+1)
        ld a,(ix+O_ROW)
        sub (hl)
        inc a
        ld (df_row),a           ; top row
        inc hl
        inc hl
        inc hl
        bit 0,(ix+O_FLAGS)
        jp nz,df_mirror
        xor a
        ld (df_mir),a
        ld a,(ix+O_DICT)
        exx
        ld h,a                  ; H' = char page
        exx
.row:   ld a,(hl)
        cp 80h
        jp z,.next
        ld a,(df_row)
        cp ROW_MIN
        jp c,.skiprow
        cp ROW_MAX+1
        jp nc,.skiprow
        push hl
        ld d,0
        call comp_addr
        ld (df_base),hl
        pop hl
.run:   ld a,(hl)
        inc hl
        cp 80h
        jp z,.next2
        ld c,a
        ld a,(df_col)
        add a,c                 ; S = col + c
        ld c,a
        ld b,(hl)               ; n
        inc hl
        cp 40
        jr nc,.slow             ; S < 0 or S >= 40
        add a,b
        cp 41
        jr nc,.slow             ; runs past column 39
        push hl
        ld hl,(df_base)
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ex de,hl
        pop hl
.cell:  ld a,(hl)
        inc hl
        or a
        jr z,.gap
        exx
        ld l,a
        ld a,(hl)               ; char
        inc h
        ld c,(hl)               ; attr
        dec h
        exx
        ld (de),a
        exx
        ld a,(bc)               ; translated attr
        exx
        set 3,d
        bit 3,a
        jr nz,.tr
        ld (de),a
        res 3,d
        inc de
        djnz .cell
        jr .run
.tr:    and 0F0h
        ld c,a
        ld a,(de)
        and 7
        or c
        ld (de),a
        res 3,d
.gap:   inc de
        djnz .cell
        jr .run
.slow:  ; per-cell clip: C = column
.sc:    ld a,(hl)
        inc hl
        or a
        jr z,.sn
        ld e,a
        ld a,c
        cp 40
        jr nc,.sn
        push bc
        push hl
        ld hl,(df_base)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,e
        call df_put
        pop hl
        pop bc
.sn:    inc c
        djnz .sc
        jp .run
.skiprow:
        inc hl                  ; col
        ld c,(hl)               ; n
        inc hl
        ld b,0
        add hl,bc
        ld a,(hl)
        cp 80h
        jr nz,.skiprow
.next:  inc hl
.next2: ld a,(df_row)
        inc a
        ld (df_row),a
        dec a
        cp (ix+O_ROW)
        jp nz,.row
        ret

; one cell: A = dict index, HL = COMP address (char).  Uses the alternate
; set's H (dict page, mirrored char page when df_mir) and B (xlat page).
df_put:
        exx
        ld l,a
        ld a,(hl)               ; char (or mirrored char)
        ld e,a
        ld a,(df_mir)
        or a
        jr z,.n
        dec h
        ld c,(hl)
        inc h
        jr .a
.n:     inc h
        ld c,(hl)
        dec h
.a:     ld a,(bc)
        ld d,a
        ld a,e
        exx
        ld (hl),a
        exx
        ld a,d
        exx
        set 3,h
        bit 3,a
        jr nz,.tr
        ld (hl),a
        ret
.tr:    and 0F0h
        ld c,a
        ld a,(hl)
        and 7
        or c
        ld (hl),a
        ret

; the mirrored drawer: column c is drawn at col-1-c, runs go leftwards.
; H' = mirrored char page (dict + 2); attrs are on dict + 1.
df_mirror:
        ld a,(ix+O_DICT)
        add a,2
        exx
        ld h,a
        exx
        ld a,1
        ld (df_mir),a
.row:   ld a,(hl)
        cp 80h
        jp z,.next
        ld a,(df_row)
        cp ROW_MIN
        jp c,.skiprow
        cp ROW_MAX+1
        jp nc,.skiprow
        push hl
        ld d,0
        call comp_addr
        ld (df_base),hl
        pop hl
.run:   ld a,(hl)
        inc hl
        cp 80h
        jp z,.next2
        ld c,a
        ld a,(df_col)
        dec a
        sub c                   ; S = col - 1 - c
        ld c,a
        ld b,(hl)
        inc hl
        cp 40
        jr nc,.slow
        inc a
        sub b
        jr c,.slow              ; S - n + 1 < 0
        push hl
        ld hl,(df_base)
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ex de,hl
        pop hl
.cell:  ld a,(hl)
        inc hl
        or a
        jr z,.gap
        exx
        ld l,a
        ld a,(hl)               ; mirrored char
        dec h
        ld c,(hl)               ; attr
        inc h
        exx
        ld (de),a
        exx
        ld a,(bc)
        exx
        set 3,d
        bit 3,a
        jr nz,.tr
        ld (de),a
        res 3,d
        dec de
        djnz .cell
        jr .run
.tr:    and 0F0h
        ld c,a
        ld a,(de)
        and 7
        or c
        ld (de),a
        res 3,d
.gap:   dec de
        djnz .cell
        jr .run
.slow:
.sc:    ld a,(hl)
        inc hl
        or a
        jr z,.sn
        ld e,a
        ld a,c
        cp 40
        jr nc,.sn
        push bc
        push hl
        ld hl,(df_base)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,e
        call df_put
        pop hl
        pop bc
.sn:    dec c
        djnz .sc
        jp .run
.skiprow:
        inc hl
        ld c,(hl)
        inc hl
        ld b,0
        add hl,bc
        ld a,(hl)
        cp 80h
        jr nz,.skiprow
.next:  inc hl
.next2: ld a,(df_row)
        inc a
        ld (df_row),a
        dec a
        cp (ix+O_ROW)
        jp nz,.row
        xor a
        ld (df_mir),a
        ret

; ---------------------------------------------------------------------
; draw_block: IX = object (type 2): db w, h, then rows of (char, attr);
; attr bit 3 = transparent paper; char 0 with attr 8 = nothing.
draw_block:
        ld l,(ix+O_PTR)
        ld h,(ix+O_PTR+1)
        ld a,(hl)
        ld (db_w),a
        inc hl
        ld a,(hl)
        ld (db_h),a
        inc hl
        ld a,(ix+O_ROW)
        ld (df_row),a
.row:   ld a,(df_row)
        cp ROW_MIN
        jr c,.skip
        cp ROW_MAX+1
        jr nc,.skip
        push hl
        ld d,0
        call comp_addr
        ld (df_base),hl
        pop hl
        ld a,(db_w)
        ld b,a
        ld c,(ix+O_COL)         ; C = column
.c:     ld a,c
        cp 40
        jr nc,.no
        ld e,(hl)               ; char
        inc hl
        ld a,(hl)               ; attr
        inc hl
        cp 8
        jr nz,.put
        ld a,e
        or a
        jr z,.nx
        ld a,8
.put:   push hl
        push af
        ld hl,(df_base)
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),e
        set 3,h
        pop af
        bit 3,a
        jr z,.op
        and 0F0h
        ld e,a
        ld a,(hl)
        and 7
        or e
.op:    ld (hl),a
        pop hl
        jr .nx
.no:    inc hl
        inc hl
.nx:    inc c
        djnz .c
        jr .adv
.skip:  ld a,(db_w)
        ld c,a
        ld b,0
        add hl,bc
        add hl,bc
.adv:   ld a,(df_row)
        inc a
        ld (df_row),a
        ld a,(db_h)
        dec a
        ld (db_h),a
        jr nz,.row
        ret

; ---------------------------------------------------------------------
; stage animation: anim_list holds BG addresses (words, FFFFh ends) of
; stage cells that changed this frame.
anim_copy:
        ld hl,anim_list
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        inc a
        ret z
        push hl
        ex de,hl                ; HL = BG
        ld a,h
        add a,10h
        ld d,a
        ld e,l                  ; DE = COMP
        ld a,(hl)
        ld (de),a
        set 3,h
        set 3,d
        ld a,(hl)
        ld (de),a
        pop hl
        jr .l

anim_diff:
        ld hl,anim_list
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        inc a
        jr z,.end
        ld a,d
        add a,10h
        ld d,a                  ; COMP
        call .one
        set 3,d
        call .one
        jr .l
.end:   ld hl,0FFFFh
        ld (anim_list),hl
        ld hl,anim_list
        ld (anim_ptr),hl
        ret
.one:   ld a,(de)
        set 2,d
        ex de,hl
        cp (hl)
        jr z,.s
        ld (hl),a
        res 2,h
        set 4,h
        ld (hl),a
        res 4,h
        set 2,h
.s:     res 2,h
        ex de,hl
        ret

; anim_set: put (A = char, C = attr) into BG at offset HL (0-999) and
; list the cell for the next render.
anim_set:
        ld de,BGM
        add hl,de
        ld (hl),a
        set 3,h
        ld (hl),c
        res 3,h
        ex de,hl
        ld hl,(anim_ptr)
        ld a,l
        cp low (anim_list+ANIM_MAX*2)
        ret z                   ; list full: dropped
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0FFh
        inc hl
        ld (hl),0FFh
        dec hl
        ld (anim_ptr),hl
        ret

; ---------------------------------------------------------------------
; show_all: copy BG to COMP, SHOWN and VRAM rows ROW_MIN..24 (a cut);
; the objects previous boxes are forgotten.
show_all:
        ld hl,BGM+ROW_MIN*40
        ld de,COMP+ROW_MIN*40
        call .pl
        ld hl,BGM+ROW_MIN*40
        ld de,SHOWN+ROW_MIN*40
        call .pl
        ld hl,BGM+ROW_MIN*40
        ld de,VRAM+ROW_MIN*40
        call .pl
        jr objs_forget
.pl:    push hl
        push de
        ld bc,1000-ROW_MIN*40
        ldir
        pop de
        pop hl
        set 3,h
        set 3,d
        ld bc,1000-ROW_MIN*40
        ldir
        ret

objs_forget:
        ld ix,OBJ
        ld b,NOBJ
.o:     ld (ix+O_PBOX),0FFh
        ld de,OBJSZ
        add ix,de
        djnz .o
        ret

objs_clear:
        ld hl,OBJ
        ld de,OBJ+1
        ld bc,NOBJ*OBJSZ-1
        ld (hl),0
        ldir
        jr objs_forget

; ROWTAB: COMP address of each row (page aligned table, see main.asm)

bx_w:   dw 0
bx_rows: db 0
df_col: db 0
df_row: db 0
df_base: dw 0
df_mir: db 0
db_w:   db 0
db_h:   db 0
anim_ptr: dw anim_list
