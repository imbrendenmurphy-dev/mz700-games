; ---------------------------------------------------------------------------
; fx_cube.asm - a solid, flat-shaded rotating cube in half-block mode.
; Rotation and perspective use the dots part's tables (TROT, PROJT).
; Faces facing away are dropped by the sign of their 2D cross product; the
; size of the cross product picks a bright or dark colour.  Each visible
; face is a convex quad: its edges set XL[y] / XR[y], then spans are poked
; into the top or bottom nibble of ABUF.
; ---------------------------------------------------------------------------

CXL     equ WORK+800h           ; 50 left edges
CXR     equ WORK+900h           ; 50 right edges

cube_init:
        call gen_proj
        call chunky_init
        ld hl,cb_cap
        ld de,VCHR+24*40
        ld a,50h
        jp print_at

cube_frame:
        call wait_vbl
        ld bc,24
        call blit_attr_rows
        ; clear the picture
        ld hl,ABUF
        ld de,ABUF+1
        ld bc,24*40-1
        ld (hl),0
        ldir
        call dt_angles
        ; transform the 8 corners
        ld ix,cb_verts
        ld iy,cb_2d
        ld b,8
.v:     push bc
        ld a,(ix+0)
        and 7Fh
        ld e,a                  ; x
        ld a,(ix+2)
        and 7Fh
        ld d,a                  ; z
        ld h,TROT/256
        ld l,e
        ld a,(hl)
        ld l,d
        set 7,l
        add a,(hl)
        ld (dt_x1),a
        ld l,d
        ld a,(hl)
        ld l,e
        set 7,l
        sub (hl)
        and 7Fh
        ld d,a                  ; z1
        ld a,(ix+1)
        and 7Fh
        ld e,a                  ; y
        inc h
        ld l,e
        ld a,(hl)
        ld l,d
        set 7,l
        sub (hl)
        ld (dt_y2),a
        ld l,e
        set 7,l
        ld a,(hl)
        ld l,d
        res 7,l
        add a,(hl)              ; z2
        add a,64
        and 7Fh
        ld c,a
        rrca
        rrca
        rrca
        rrca
        and 7
        add a,PROJT/256
        ld h,a
        ld a,c
        and 8
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(dt_x1)
        and 7Fh
        or c
        ld l,a
        ld a,(hl)
        sra a                   ; chunky pixels are 2 dots wide
        add a,20
        ld (iy+0),a
        ld a,(dt_y2)
        and 7Fh
        or c
        ld l,a
        ld a,(hl)
        add a,24
        ld (iy+1),a
        ld de,3
        add ix,de
        inc iy
        inc iy
        pop bc
        djnz .v
        ; faces
        ld ix,cb_faces
        ld b,6
.f:     push bc
        call cb_face
        ld de,6
        add ix,de
        pop bc
        djnz .f
        ret

; IX = face: 4 corner numbers, bright colour, dark colour
cb_face:
        ; cross = (b - a) x (c - a)
        ld a,(ix+0)
        call cb_pt              ; D = ax, E = ay
        ld (cb_a),de
        ld a,(ix+1)
        call cb_pt
        ld hl,(cb_a)
        ld a,d
        sub h
        ld (cb_bx),a
        ld a,e
        sub l
        ld (cb_by),a
        ld a,(ix+2)
        call cb_pt
        ld hl,(cb_a)
        ld a,d
        sub h
        ld (cb_cx),a
        ld a,e
        sub l
        ld (cb_cy),a
        ld a,(cb_cy)
        ld e,a
        ld a,(cb_bx)
        call muls16
        push hl
        ld a,(cb_cx)
        ld e,a
        ld a,(cb_by)
        call muls16
        ex de,hl
        pop hl
        or a
        sbc hl,de               ; cross
        bit 7,h
        ret nz                  ; facing away
        ld de,-24
        add hl,de
        ret nc                  ; (nearly) edge-on: skip the sliver
        ld de,24
        add hl,de
        ; colour: big area = facing us = bright
        ld de,-70
        add hl,de
        ld a,(ix+4)
        jr c,.br
        ld a,(ix+5)
.br:    ld (cb_col),a
        ; clear the edge tables over 0-49
        ld hl,CXL
        ld de,CXR
        ld b,50
.c:     ld (hl),0FFh
        xor a
        ld (de),a
        inc l
        inc e
        djnz .c
        ; 4 edges
        ld a,(ix+0)
        ld c,(ix+1)
        call cb_edge
        ld a,(ix+1)
        ld c,(ix+2)
        call cb_edge
        ld a,(ix+2)
        ld c,(ix+3)
        call cb_edge
        ld a,(ix+3)
        ld c,(ix+0)
        call cb_edge
        ; spans, a cell row (two pixel rows) at a time, over the face's rows
        ld c,255                ; ymin
        ld e,0                  ; ymax
        ld b,4
        push ix
.yr:    ld a,(ix+0)
        push de
        call cb_pt              ; E = y
        ld a,e
        pop de
        cp c
        jr nc,.y1
        ld c,a
.y1:    cp e
        jr c,.y2
        ld e,a
.y2:    inc ix
        djnz .yr
        pop ix
        ld a,e
        inc a
        cp 48
        jr c,.y3
        ld a,48
.y3:    ld (cb_ymax),a
        ld a,c
        bit 7,a
        jr z,.y4
        xor a
.y4:    and 0FEh
        ld b,a
        srl a
        call mul40
        ld de,ABUF
        add hl,de
        ld (cb_row),hl
.s:     push bc
        ld h,CXL/256
        ld l,b
        ld a,(hl)
        ld (cb_l0),a
        inc l
        ld a,(hl)
        ld (cb_l1),a
        ld h,CXR/256
        ld a,(hl)
        ld (cb_r1),a
        dec l
        ld a,(hl)
        ld (cb_r0),a
        ; overlap = [max(l0,l1), min(r0,r1)] when both rows have a span
        ld a,(cb_l0)
        ld c,a
        ld a,(cb_l1)
        cp c
        jr nc,.m1
        ld a,c
.m1:    ld (cb_ol),a
        ld a,(cb_r0)
        ld c,a
        ld a,(cb_r1)
        cp c
        jr c,.m2
        ld a,c
.m2:    ld (cb_or),a            ; (an empty row has l = FF, r = 0: no overlap)
        ; top row: RMW outside the overlap
        ld a,(cb_col)
        and 0F0h
        ld e,a
        ld d,0Fh
        ld a,(cb_l0)
        ld c,a
        ld a,(cb_r0)
        call cb_part
        ; bottom row
        ld a,(cb_col)
        and 0Fh
        ld e,a
        ld d,0F0h
        ld a,(cb_l1)
        ld c,a
        ld a,(cb_r1)
        call cb_part
        ; overlap: whole cells
        ld a,(cb_ol)
        ld c,a
        ld a,(cb_or)
        sub c
        jr c,.no
        inc a
        ld b,a
        ld hl,(cb_row)
        ld e,c
        ld d,0
        add hl,de
        ld a,(cb_col)
.ov:    ld (hl),a
        inc hl
        djnz .ov
.no:    ld hl,(cb_row)
        ld de,40
        add hl,de
        ld (cb_row),hl
        pop bc
        inc b
        inc b
        ld a,(cb_ymax)
        cp b
        jp z,.sd
        jp nc,.s
.sd:    ret

; span [C, A] minus the overlap [ol, or]: keep D-mask, OR in E
cb_part:
        cp c
        ret c                   ; empty
        ld b,a                  ; r
        ld a,(cb_ol)
        ld l,a
        ld a,(cb_or)
        cp l
        jr c,.all               ; no overlap
        ; left piece [l, min(r, ol - 1)] if l < ol
        ld a,c
        cp l
        jr nc,.rt
        ld a,l
        dec a
        cp b
        jr c,.l1
        ld a,b
.l1:    push bc
        call cb_rmw
        pop bc
.rt:    ; right piece [max(l, or + 1), r] if or < r
        ld a,(cb_or)
        cp b
        ret nc
        inc a
        cp c
        jr nc,.r1
        ld a,c
.r1:    ld c,a
.all:   ld a,b
; RMW cells C..A of the current row
cb_rmw: sub c
        ret c
        inc a
        ld b,a
        ld hl,(cb_row)
        ld a,c
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        and d
        or e
        ld (hl),a
        inc hl
        djnz .n
        ret

; A = corner -> D = x, E = y
cb_pt:  add a,a
        ld e,a
        ld d,0
        ld hl,cb_2d
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        ret

; edge from corner A to corner C into XL / XR
cb_edge:
        push af
        ld a,c
        call cb_pt
        ld (cb_q),de
        pop af
        call cb_pt              ; D,E = p
        ld hl,(cb_q)            ; H,L = q
        ld a,e
        cp l
        ret z                   ; flat
        jr c,.ok                ; p above q
        ex de,hl
.ok:    ; from (D,E) down to (H,L)
        ld a,l
        sub e
        ld c,a                  ; dy > 0
        ld a,h
        sub d                   ; dx (signed)
        ; step = dx * 256 / dy (signed 8.8)
        push de
        ld b,a
        bit 7,a
        jr z,.p
        neg
.p:     ld h,a
        ld l,0
        call cb_div             ; HL = HL / C
        bit 7,b
        jr z,.p2
        call neg_hl
.p2:    ex de,hl                ; DE = step
        pop hl                  ; H = x, L = y
        ld b,c                  ; rows
        inc b
        ld a,h
        ld h,a
        ld c,l                  ; y
        ld l,80h                ; x in 8.8, rounded
.row:   ld a,c
        cp 48
        jr nc,.nx
        push hl
        ld a,h                  ; x
        bit 7,a
        jr z,.x0
        xor a
.x0:    cp 40
        jr c,.x1
        ld a,39
.x1:    ld h,CXL/256
        ld l,c
        cp (hl)
        jr nc,.x2
        ld (hl),a
.x2:    ld h,CXR/256
        cp (hl)
        jr c,.x3
        ld (hl),a
.x3:    pop hl
.nx:    add hl,de
        inc c
        djnz .row
        ret

; HL / C -> HL (unsigned, C > 0)
cb_div: ld a,16
        push bc
        ld b,a
        xor a
.d:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .d
        pop bc
        ret

cb_verts:
        db -21,-21,-21,  21,-21,-21,  21, 21,-21, -21, 21,-21
        db -21,-21, 21,  21,-21, 21,  21, 21, 21, -21, 21, 21
cb_faces:                       ; corners (one winding), bright, dark
        db 0,1,2,3, 22h, 22h
        db 5,4,7,6, 66h, 22h
        db 4,0,3,7, 11h, 11h
        db 1,5,6,2, 55h, 11h
        db 4,5,1,0, 33h, 33h
        db 3,2,6,7, 77h, 33h

cb_2d:  ds 16
cb_a:   dw 0
cb_q:   dw 0
cb_bx:  db 0
cb_by:  db 0
cb_cx:  db 0
cb_cy:  db 0
cb_col: db 0
cb_row: dw 0
cb_l0:  db 0
cb_l1:  db 0
cb_r0:  db 0
cb_r1:  db 0
cb_ol:  db 0
cb_or:  db 0
cb_ymax: db 0
