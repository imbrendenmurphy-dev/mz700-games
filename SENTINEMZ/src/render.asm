; =====================================================================
;  render.asm - the landscape view
;
;  Each of the 80 pixel columns casts a ray over the sub-cell map in 102
;  depth steps (z = 1..16 by 1/2, 17..48 by 1, 50..126 by 2 sub-cells).
;  Screen row of a sample:  y = hor + 8 (E - f) / z, done as
;      y16 = Y0[i] - f * S[i]      (Y0 = hor << k + E * S, f*S by quarter squares)
;  with k = 4 for the first 31 steps and 8 after.  A sample is drawn when it
;  rises above everything nearer (ybuf), front to back, so each pixel is
;  written once.  ZB keeps the step index for object occlusion and picking.
; =====================================================================

HORTAB: db 30,16,4                  ; pitch: up, level, down

render:
        call poll
        ld hl,TILEF                 ; forget what was visible
        ld b,0
.cv:    res 7,(hl)
        inc hl
        res 7,(hl)
        inc hl
        res 7,(hl)
        inc hl
        res 7,(hl)
        inc hl
        djnz .cv
        ld a,(pitch)
        ld e,a
        ld d,0
        ld hl,HORTAB
        add hl,de
        ld a,(hl)
        ld (hor),a
        ld a,(beam)
        or 8
        ld (beamcode),a
        ; per-step constants
        ld ix,STEPD
        ld hl,STEPS_S
        ld b,0
.sd:    ld a,(hl)
        ld (ix+0),a
        ld (ix+3),b
        push hl
        push bc
        ld c,a
        ld a,(eye)
        call mul8u                  ; E * S
        ld a,(hor)
        ld e,a
        ld d,0
        pop bc
        push bc
        ld a,b
        cp 31
        jr nc,.k8
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        jr .st
.k8:    ld d,e
        ld e,0
        add hl,de
.st:    ld (ix+1),l
        ld (ix+2),h
        pop bc
        pop hl
        inc hl
        ld de,4
        add ix,de
        inc b
        ld a,b
        cp NSTEP
        jr c,.sd
        call load_dirs
        ld hl,(d_x0)
        ld (cdx),hl
        ld hl,(d_y0)
        ld (cdy),hl
        call player_pos
        xor a
        ld (col),a
.col:   call render_col
        ld hl,(cdx)
        ld de,(d_dx)
        add hl,de
        ld (cdx),hl
        ld hl,(cdy)
        ld de,(d_dy)
        add hl,de
        ld (cdy),hl
        ld a,(col)
        inc a
        ld (col),a
        cp VIEW_W
        jr c,.col
        call draw_objects
        jp present

; heading -> d_x0, d_y0, d_dx, d_dy, f_x, f_y, r_x, r_y
load_dirs:
        ld a,(heading)
        and 31
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,DIRTAB
        add hl,de
        ld de,d_x0
        ld bc,16
        ldir
        ret

; ppx, ppy = player position (8.8 sub-cells); eye
player_pos:
        ld hl,(ptile)
        call tile_xy
        ld a,e
        add a,a
        add a,a
        add a,2
        ld (ppx+1),a
        ld a,d
        add a,a
        add a,a
        add a,2
        ld (ppy+1),a
        xor a
        ld (ppx),a
        ld (ppy),a
        call tile_f
        ld b,a
        ld hl,(ptile)
        call obj_addr
        ld a,(hl)
        rrca
        rrca
        and 1Ch                     ; cairns * 4
        add a,b
        add a,EYE
        ld (eye),a
        ret

; HL = HL >> 1 arithmetic
sra_hl: sra h
        rr l
        ret

; ---------------------------------------------------------------------
; one column
; ---------------------------------------------------------------------
        MACRO STEPFETCH sx, sy
sx:     ld bc,0
        add hl,bc
        ex de,hl
sy:     ld bc,0
        add hl,bc
        ex de,hl
        ENDM

        ; alt HL = x, DE = y -> A = map byte (main set on exit), alt BC = address
        MACRO FETCH
        ld a,h
        or d
        jp m,offmap
        ld a,d
        rrca
        ld b,a
        and 80h
        or h
        ld c,a
        ld a,b
        or 80h
        ld b,a
        ld a,(bc)
        exx
        ENDM

        ; A = map byte -> HL = y16 - yb16 (minus: visible)
        MACRO YMATH
        rrca
        rrca
        and 3Fh
        ld l,a
        ld a,(ix+0)
        sub l
        jr nc,$+4
        neg
        ld e,a
        ld a,(ix+0)
        add a,l
        ld l,a
        ld h,high QLO
        ld d,h
        ld a,(de)
        sub (hl)
        ld c,a
        inc h
        inc d
        ld a,(de)
        sbc a,(hl)
        ld h,a
        ld l,c
        ld e,(ix+1)
        ld d,(ix+2)
        add hl,de
        ld de,(yb16)
        or a
        sbc hl,de
        ENDM

render_col:
        call poll
        ld a,(col)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PIX
        add hl,de
        ld (colbase),hl
        ld hl,(cdx)                 ; step vectors (8.8) from the 4.12 direction
        call sra_hl
        call sra_hl
        call sra_hl
        ld (smCx+1),hl              ; dz = 2
        call sra_hl
        ld (smBx+1),hl              ; dz = 1
        call sra_hl
        ld (smAx+1),hl              ; dz = 1/2
        ld hl,(cdy)
        call sra_hl
        call sra_hl
        call sra_hl
        ld (smCy+1),hl
        call sra_hl
        ld (smBy+1),hl
        call sra_hl
        ld (smAy+1),hl
        ld a,VIEW_H
        ld (ybuf),a
        ld hl,VIEW_H*16
        ld (yb16),hl
        ld ix,STEPD
        ld b,31
        exx
        ld hl,(smBy+1)              ; first sample at z = 1
        ld de,(ppy)
        add hl,de
        ex de,hl
        ld hl,(ppx)
        ld bc,(smBx+1)
        add hl,bc
        jr rc_a_fetch
; ---- stage A: z 1..16, k = 4
rc_a_loop:
        exx
        STEPFETCH smAx, smAy
rc_a_fetch:
        FETCH
        YMATH
        jp m,rc_a_draw
rc_a_next:
        ld de,4
        add ix,de
        djnz rc_a_loop
        ; ---- stage B / C: k = 8
        ld a,(ybuf)
        ld h,a
        ld l,0
        ld (yb16),hl
        call poll
        ld b,32
rc_b_loop:
        exx
        STEPFETCH smBx, smBy
        FETCH
        YMATH
        jp m,rc_b_draw
rc_b_next:
        ld de,4
        add ix,de
        djnz rc_b_loop
        call poll
        ld b,NSTEP-63
rc_c_loop:
        exx
        STEPFETCH smCx, smCy
        FETCH
        YMATH
        jp m,rc_c_draw
rc_c_next:
        ld de,4
        add ix,de
        djnz rc_c_loop
        jp col_end

rc_a_draw:
        add hl,de                   ; y16
        xor a
        bit 7,h
        jr nz,rc_a_ys
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h                      ; y16 >> 4
rc_a_ys:  call draw_span
        ret z                       ; column full
        ld a,(ybuf)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (yb16),hl
        jp rc_a_next
rc_b_draw:
        add hl,de
        xor a
        bit 7,h
        jr nz,rc_b_ys
        ld a,h
rc_b_ys:  call draw_span
        ret z
        ld a,(ybuf)
        ld h,a
        ld l,0
        ld (yb16),hl
        jp rc_b_next
rc_c_draw:
        add hl,de
        xor a
        bit 7,h
        jr nz,rc_c_ys
        ld a,h
rc_c_ys:  call draw_span
        ret z
        ld a,(ybuf)
        ld h,a
        ld l,0
        ld (yb16),hl
        jp rc_c_next

; the ray left the map (alt set active)
offmap:
        exx
; sea to the horizon, then sky
col_end:
        ld a,(hor)
        ld e,a
        ld a,(ybuf)
        cp e
        jr c,.nosea
        jr z,.nosea
        ld d,a                      ; rows hor .. ybuf-1
        ld a,e
        ld (ybuf),a
        ld c,SEA
        ld b,7Eh
        call fill_rows
.nosea: ld a,(ybuf)
        or a
        ret z
        ld d,a
        ld e,0
        ld c,SKY
        ld b,7Fh
; fill rows E .. D-1 of this column with colour C, depth B
fill_rows:
        ld a,d
        sub e
        ret z
        ret c
        ld d,a
        ld hl,(colbase)
        ld a,l
        add a,e
        ld l,a
        push hl
        ld e,d
        ld a,c
        cp SEA
        jr z,.sea
.p:     ld (hl),c
        inc l
        dec e
        jr nz,.p
        jr .zb
.sea:   ld a,l                      ; the sea: blue on even rows, black on odd
        and 1
        ld a,SEA
        jr z,$+3
        xor a
        ld (hl),a
        inc l
        dec e
        jr nz,.sea
.zb:    pop hl
        ld a,h
        add a,high (ZB-PIX)
        ld h,a
.z:     ld (hl),b
        inc l
        dec d
        jr nz,.z
        ret

; a sample rose above ybuf: A = its top row (0..ybuf-1).  Fills down to
; ybuf, marks the tile visible.  Z set when the column is full.
draw_span:
        push bc
        ld (ys_t),a
        exx
        ld a,(bc)                   ; the map byte again
        ld (mb_t),a
        ld a,d                      ; tile flags: (y>>2)*32 + (x>>2)
        and 1Ch
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,h
        rrca
        rrca
        and 1Fh
        or c
        ld c,a
        ld a,d
        rlca
        rlca
        rlca
        and 3
        add a,high TILEF
        ld b,a
        ld a,(bc)
        or 80h
        ld (bc),a
        and 0Fh
        exx
        ld c,a
        ld a,(beamcode)
        cp c
        ld hl,PALN
        jr nz,.n
        ld hl,PALL
.n:     ld a,(mb_t)
        cp 4
        jr nc,.land
        ld a,SEA
        jr .colr
.land:  and 3
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
.colr:  ld c,a
        ld b,(ix+3)
        ld a,(ys_t)
        ld e,a
        ld a,(ybuf)
        ld d,a
        ld a,e
        ld (ybuf),a
        call fill_rows
        ld a,(ybuf)
        or a
        pop bc
        ret

; palettes by shade: flat, stud, slope lit, slope dark
PALN:   db GREEN,BLACK,CYAN,BLUE
PALL:   db YELLOW,RED,WHITE,YELLOW      ; in the Lantern's beam

; ---------------------------------------------------------------------
; objects: billboard sprites, far to near, depth-tested against ZB
; ---------------------------------------------------------------------
OL_Z    equ 0       ; z16 (sub-cells * 16)
OL_T    equ 2       ; tile
OL_X    equ 4       ; screen column of the centre (signed word)
OL_Y    equ 6       ; screen row of the base (signed word)
OL_SC   equ 8       ; scale 8.8 (= 32768 / z16)
OL_D    equ 10      ; depth step for the ZB test
OL_BX   equ 11      ; bounding box: x0, y0, x1, y1 (for effects)
OLSZ    equ 16
MAXOL   equ 24

draw_objects:
        xor a
        ld (nobj),a
        ld hl,0
.t:     push hl
        call obj_addr
        ld a,(hl)
        pop hl
        or a
        jr z,.n
        ld de,(ptile)
        or a
        sbc hl,de
        add hl,de
        jr z,.n
        ld a,(nobj)
        cp MAXOL
        jr nc,.n
        push hl
        call obj_project
        pop hl
.n:     inc hl
        ld a,h
        cp 4
        jr c,.t
        ; sort far to near (insertion sort on the order list)
        ld a,(nobj)
        or a
        ret z
        ld b,a
        ld hl,olorder
        xor a
.oi:    ld (hl),a
        inc hl
        inc a
        djnz .oi
        ld a,(nobj)
        cp 2
        jr c,.drw
        ld c,1
.so:    ld b,c                      ; bubble element c down
.sb:    ld a,b
        call ol_zof                 ; DE = z of order[b]
        push de
        ld a,b
        dec a
        call ol_zof                 ; DE = z of order[b-1]
        pop hl
        or a
        sbc hl,de                   ; z[b] - z[b-1] > 0 -> swap
        jr c,.sx
        jr z,.sx
        ld hl,olorder
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        dec hl
        ld e,(hl)
        ld (hl),a
        inc hl
        ld (hl),e
        dec b
        jr nz,.sb
.sx:    inc c
        ld a,(nobj)
        cp c
        jr nz,.so
.drw:   ld a,(nobj)
        ld b,a
        ld hl,olorder
.d:     push bc
        push hl
        ld a,(hl)
        call obj_draw
        pop hl
        pop bc
        inc hl
        djnz .d
        ret

; DE = z16 of olorder[A]
ol_zof: push hl
        ld e,a
        ld d,0
        ld hl,olorder
        add hl,de
        ld a,(hl)
        call ol_addr
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ret

; HL = OLIST + A * 16
ol_addr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,OLIST
        add hl,de
        ret

; HL = tile: add it to OLIST when it is in front of the viewer
obj_project:
        call project_tile
        ret c
        jp obj_store

; HL = tile -> pz, px16, psc, pcol, prow (pixel column / row of the
; tile's centre surface).  Carry: behind, too near or off the sides.
project_tile:
        ld (pt_t),hl
        call tile_xy
        ld a,(ppx+1)                ; dx, dy in sub-cells (tile centre - player)
        ld c,a
        ld a,e
        add a,a
        add a,a
        add a,2
        sub c
        ld (pdx),a
        ld a,(ppy+1)
        ld c,a
        ld a,d
        add a,a
        add a,a
        add a,2
        sub c
        ld (pdy),a
        ; z16 = (dx Fx + dy Fy) >> 8
        ld de,(f_x)
        ld a,(pdx)
        call muls8x16
        push hl
        ld de,(f_y)
        ld a,(pdy)
        call muls8x16
        pop de
        add hl,de
        bit 7,h
        jr nz,.fail                 ; behind
        ld de,24
        or a
        sbc hl,de
        jr c,.fail                  ; nearer than 1.5 sub-cells
        add hl,de
        ld (pz),hl
        ld de,(r_x)
        ld a,(pdx)
        call muls8x16
        push hl
        ld de,(r_y)
        ld a,(pdy)
        call muls8x16
        pop de
        add hl,de
        ld (px16),hl
        ; sc = 32768 / z16
        ld de,(pz)
        ld hl,32768
        call div16u
        ld (psc),hl
        ; column = 40 + (x16 * sc) >> 9
        ld de,(px16)
        call muls16                 ; DEHL
        sra d                       ; >> 9
        rr e
        rr h
        ld l,h
        ld h,e
        ld de,40
        add hl,de
        ld (pcol),hl
        ld de,16
        add hl,de
        bit 7,h
        jr nz,.fail                 ; off the left
        ld de,-(80+32)
        add hl,de
        bit 7,h
        jr z,.fail                  ; off the right
        ; base row = hor + ((E - f) * sc) >> 8
        ld hl,(pt_t)
        call tile_f
        ld b,a
        ld a,(eye)
        sub b
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld hl,(psc)
        call muls16
        ld l,h
        ld h,e
        ld a,(hor)
        ld e,a
        ld d,0
        add hl,de
        ld (prow),hl
        or a
        ret
.fail:  scf
        ret

obj_store:
        ; depth step for occlusion: 2 sub-cells in front of the centre
        ld a,(pz+1)                 ; z16 >> 4, clamped
        cp 16
        ld a,255
        jr nc,.zc
        ld a,(pz)
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        ld c,a
        ld a,(pz+1)
        add a,a
        add a,a
        add a,a
        add a,a
        or c
.zc:    sub 2
        jr nc,$+3
        xor a
        ld e,a
        ld d,0
        ld hl,ZSTEP
        add hl,de
        ld c,(hl)
        ; store
        ld a,(nobj)
        push bc
        call ol_addr
        pop bc
        ld de,(pz)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(pt_t)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(pcol)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(prow)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(psc)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),255                 ; empty box
        inc hl
        ld (hl),255
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld hl,nobj
        inc (hl)
        ret

; draw list entry A (also its slot number for ZB marks)
obj_draw:
        ld (dslot),a
        call ol_addr
        ld (dent),hl
        push hl
        pop ix
        ld l,(ix+OL_T)
        ld h,(ix+OL_T+1)
        call obj_addr
        ld a,(hl)
        ld (dobj),a
        ld a,(ix+OL_Y)              ; base row, 8.8
        ld (dbase+1),a
        xor a
        ld (dbase),a
        ld a,(ix+OL_Y+1)
        ld (dbaseh),a
        ld a,(ix+OL_D)
        ld (ddep),a
        ld l,(ix+OL_SC)
        ld h,(ix+OL_SC+1)
        ld (dsc),hl
        ld l,(ix+OL_X)
        ld h,(ix+OL_X+1)
        ld (dcol),hl
        ; cairns
        ld a,(dobj)
        rrca
        rrca
        rrca
        rrca
        and 7
        jr z,.top
        ld b,a
.cn:    push bc
        ld hl,SPR_CAIRN
        call spr_draw
        ld hl,(dsc)                 ; base -= 4 * sc
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(dbase)
        or a
        sbc hl,de
        ld (dbase),hl
        ld a,(dbaseh)
        sbc a,0
        ld (dbaseh),a
        pop bc
        djnz .cn
.top:   ld a,(dobj)
        and 7
        ret z
        ld hl,SPR_SHARD
        dec a
        jr z,.go
        ld hl,SPR_SHELL
        dec a
        jr z,.go
        ld hl,SPR_LANTERN
        dec a
        jr z,.go
        ld hl,SPR_WISP
        ld de,(dbase)               ; wisps hover a level up
        ld hl,(dsc)
        add hl,hl
        add hl,hl
        ex de,hl
        or a
        sbc hl,de
        ld (dbase),hl
        ld a,(dbaseh)
        sbc a,0
        ld (dbaseh),a
        ld hl,SPR_WISP
.go:    jp spr_draw

; draw sprite HL scaled by dsc, bottom at dbase (24-bit dbaseh:dbase 8.8),
; centred on dcol, depth-tested against ddep; ZB marks 80h + dslot
spr_draw:
        ld a,(hl)
        ld (sw),a
        inc hl
        ld a,(hl)
        ld (shh),a
        inc hl
        ld (sdat),hl
        ld a,(sw)                   ; screen size = size * sc >> 8 (at least 1)
        ld de,(dsc)
        call mulu8x16_hi
        ld (ow),a
        ld a,(shh)
        ld de,(dsc)
        call mulu8x16_hi
        ld (oh),a
        ld ix,(dent)                ; source step (8.8) = z16 * 2
        ld l,(ix+OL_Z)
        ld h,(ix+OL_Z+1)
        add hl,hl
        ld (sstep),hl
        ld a,(ow)                   ; left = centre - w/2
        srl a
        ld e,a
        ld d,0
        ld hl,(dcol)
        or a
        sbc hl,de
        ld (ox0),hl
        ld a,(dbaseh)               ; top = base - h
        ld h,a
        ld a,(dbase+1)
        ld l,a
        ld a,(oh)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (oy0),hl
        ; row table: source row offset (row * w) for each on-screen row
        ld hl,0
        ld (sv),hl
        ld hl,(oy0)
        ld (oy),hl
        xor a
        ld (rowcnt),a
        ld a,0FFh
        ld (ystart),a
        ld a,(oh)
        ld b,a
.rt:    push bc
        ld hl,(oy)
        ld a,h
        or a
        jr nz,.rtn
        ld a,l
        cp VIEW_H
        jr nc,.rtn
        ld a,(ystart)
        inc a
        jr nz,.rts
        ld a,l
        ld (ystart),a
.rts:   ld a,(sv+1)                 ; source row, clamped
        ld c,a
        ld a,(shh)
        dec a
        cp c
        jr nc,$+3
        ld c,a
        ld a,(sw)
        call mul8u_c
        ld a,(rowcnt)
        ld e,a
        ld d,0
        inc a
        ld (rowcnt),a
        ld a,l
        ld hl,ROWT
        add hl,de
        ld (hl),a
.rtn:   ld hl,(sv)
        ld de,(sstep)
        add hl,de
        ld (sv),hl
        ld hl,(oy)
        inc hl
        ld (oy),hl
        pop bc
        djnz .rt
        ld a,(rowcnt)
        or a
        ret z                       ; entirely above / below the view
        ld a,(dslot)
        or 80h
        ld (dmark),a
        ld hl,0
        ld (su),hl
        ld hl,(ox0)
        ld (ox),hl
        ld a,(ow)
        ld b,a
.cx:    push bc
        ld hl,(ox)
        ld a,h
        or a
        jp nz,.cn
        ld a,l
        cp VIEW_W
        jp nc,.cn
        ld (ocol),a
        ld a,(su+1)                 ; source column, clamped
        ld c,a
        ld a,(sw)
        dec a
        cp c
        jr nc,$+3
        ld c,a
        ld b,0
        ld hl,(sdat)
        add hl,bc
        ld (srow),hl
        ld a,(ocol)                 ; ZB + col*64 + ystart
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(ystart)
        or l
        ld l,a
        ld de,ZB
        add hl,de
        ld a,(rowcnt)
        ld b,a
        ld de,ROWT
.py:    push de
        ld a,(de)                   ; source row offset
        ld de,(srow)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld a,(de)
        cp 8
        jr z,.pn                    ; clear
        cp 9
        jr nz,.pc
        ld a,(lamp_col)
.pc:    ld c,a
        ld a,(ddep)
        cp (hl)
        jr nc,.pn                   ; terrain in front
        ld a,(dmark)
        ld (hl),a
        ld a,h
        sub high (ZB-PIX)
        ld h,a
        ld (hl),c
        add a,high (ZB-PIX)
        ld h,a
.pn:    inc l
        pop de
        inc de
        djnz .py
.cn:    ld hl,(su)
        ld de,(sstep)
        add hl,de
        ld (su),hl
        ld hl,(ox)
        inc hl
        ld (ox),hl
        pop bc
        dec b
        jp nz,.cx
        ; box (for effects): the clipped rectangle
        ld ix,(dent)
        ld hl,(ox0)
        call clip_x
        cp (ix+OL_BX)
        jr nc,$+5
        ld (ix+OL_BX),a
        ld a,(ow)
        ld e,a
        ld d,0
        ld hl,(ox0)
        add hl,de
        dec hl
        call clip_x
        cp (ix+OL_BX+2)
        jr c,$+5
        ld (ix+OL_BX+2),a
        ld a,(ystart)
        cp (ix+OL_BX+1)
        jr nc,$+5
        ld (ix+OL_BX+1),a
        ld b,a
        ld a,(rowcnt)
        add a,b
        dec a
        cp (ix+OL_BX+3)
        ret c
        ld (ix+OL_BX+3),a
        ret

; A = HL clamped to 0..79
clip_x: bit 7,h
        jr z,.p
        xor a
        ret
.p:     ld a,h
        or a
        ld a,VIEW_W-1
        ret nz
        ld a,l
        cp VIEW_W
        ret c
        ld a,VIEW_W-1
        ret

; A = (A * DE) >> 8, at least 1 (DE <= 1400h)
mulu8x16_hi:
        ld l,a
        ld h,0
        call mul16u
        ld a,l                      ; round up
        or a
        jr z,.r
        inc h
        jr nz,.r
        inc e
.r:     ld a,e                      ; DEHL >> 8 -> E:H, small
        or a
        ld a,h
        jr z,$+4
        ld a,255
        or a
        ret nz
        inc a
        ret

; HL = A * C (any sizes, shift-add)
mul8u_c:
        ld hl,0
        ld d,0
        ld e,a
        ld b,8
.l:     add hl,hl
        rlc c
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; ---------------------------------------------------------------------
; present: 2 x 2 pixels -> one cell (half / diagonal blocks)
; ---------------------------------------------------------------------
present:
        ld hl,VRAM
        ld (vp),hl
        xor a
        ld (prow_c),a
.r:     call poll
        ld a,(prow_c)
        add a,a
        ld (py2),a
        ld hl,PIX
        ld (pcp),hl
        ld b,40
.c:     push bc
        ld hl,(pcp)
        ld a,(py2)
        or l
        ld l,a
        ld b,(hl)                   ; TL
        inc l
        ld d,(hl)                   ; BL
        ld a,l
        add a,64-1
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)                   ; TR
        inc l
        ld e,(hl)                   ; BR
        call cellpat                ; A = char, L = attr
        ld h,a
        ld a,l
        ld de,(vp)
        ex de,hl
        ld (hl),d                   ; char
        set 3,h
        ld (hl),a                   ; attr
        res 3,h
        inc hl
        ld (vp),hl
        ld hl,(pcp)
        ld de,128
        add hl,de
        ld (pcp),hl
        pop bc
        djnz .c
        ld hl,prow_c
        inc (hl)
        ld a,(hl)
        cp VIEW_ROWS
        jr c,.r
        ret

; B = TL, C = TR, D = BL, E = BR -> A = char, L = attr (fg << 4 | bg)
cellpat:
        ld a,b
        cp c
        jr nz,.ntt
        ld a,d                      ; TL = TR
        cp e
        jr nz,.ttnb
        cp b
        jr z,.unib
        jr .upper
.ttnb:  ld a,b                      ; bottoms differ: 3 x TL?
        cp d
        jr z,.unib
        cp e
        jr z,.unib
        jr .upper
.ntt:   ld a,b
        cp d
        jr nz,.nlb
        ld a,c                      ; TL = BL
        cp e
        jr nz,.lbnr
        ld a,b                      ; left half
        ld d,c
        call mkattr
        ld a,7Bh
        ret
.lbnr:  ld a,d
        cp e
        jr z,.unib
        jr .upper
.nlb:   ld a,b                      ; TL != TR, TL != BL
        cp e
        jr nz,.nbr
        ld a,c                      ; TL = BR
        cp d
        jr nz,.upper
        ld a,b                      ; diagonal TL + BR
        ld d,c
        call mkattr
        ld a,5Bh
        ret
.nbr:   ld a,c                      ; TL on its own
        cp d
        jr nz,.upper
        cp e
        jr z,.unic
        ld d,b                      ; diagonal TR + BL
        call mkattr
        ld a,6Ch
        ret
.unic:  ld l,c
        xor a
        ret
.unib:  ld l,b
        xor a
        ret
.upper: ld a,b                      ; upper half: fg TL, bg BL
        call mkattr
        ld a,7Ah
        ret
mkattr: rlca                        ; L = A << 4 | D
        rlca
        rlca
        rlca
        or d
        ld l,a
        ret
