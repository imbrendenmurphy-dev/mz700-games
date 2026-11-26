; =====================================================================
;  hidden.asm - hidden-line ships and the back-lit crescent planet
;
;  Back faces: each model carries the planes of its convex hull
;  (build.py model_faces): a normal n (unit 64) and d = n.v.  The camera
;  is moved into the model's space once per object (c = -M'P, scaled to
;  bytes), then a face is towards us when n.c > d: three byte multiplies
;  a face.  An edge is drawn when either face it lies on is towards us
;  (edges on no hull face, in a ship's hollows, are always drawn).
;
;  Ships hide the planet behind them: the planet is placed first but
;  drawn after the ships.  While a ship that overlaps it is drawn, plot
;  is patched to note each dot row's leftmost and rightmost dot; the
;  planet then skips every dot inside those spans.
; =====================================================================

SPMIN           equ 0B200h              ; per dot row: span of the outline
SPMAX           equ 0B240h
FVIS            equ 0B280h              ; per face: 1 = towards us
HWT             equ 0B300h              ; planet: half width per row offset

; ---------------------------------------------------------------------
; cull_faces: IY -> the model's face block (db nfaces, faces), IX =
; object, mtx set.  Fills FVIS; returns IY -> the per-edge face table.
; ---------------------------------------------------------------------
cull_faces:
        ld a,(iy+0)
        ld (nfc),a
        inc iy
        ld a,(mrad)                     ; far away (under ~4 dots across):
        ld l,a                          ; hidden lines would not show, so
        ld h,0                          ; draw every edge and save the time
        add hl,hl
        add hl,hl
        add hl,hl                       ; radius * 8
        ld e,(ix+O_Z)
        ld d,(ix+O_Z+1)
        or a
        sbc hl,de
        jr nc,.near
        ld a,(nfc)
        or a
        ret z
        ld b,a
        ld hl,FVIS
        ld de,5
.fa:    ld (hl),1
        inc hl
        add iy,de
        djnz .fa
        ret
.near:  push iy
        push ix
        pop hl
        ld de,O_X
        add hl,de
        call vtb_fast                   ; P >> s
        ld (cs_k),a
        xor a                           ; c' = -M'P (three columns)
        call mcol
        call neg_hl
        ld (cwv),hl
        ld a,1
        call mcol
        call neg_hl
        ld (cwv+2),hl
        ld a,2
        call mcol
        call neg_hl
        ld (cwv+4),hl
        ld hl,cwv
        call vtb_fast                   ; c''' = c' >> s2
        ld hl,cs_k
        add a,(hl)
        sub 6                           ; k = s + s2 - 6
        ld (hl),a
        pop iy
        ld hl,FVIS
        ld a,(nfc)
        or a
        ret z
        ld b,a
        ld c,0                          ; faces towards us
.f:     push bc
        push hl
        ld hl,0                         ; n.c''' (zero parts skipped)
        ld a,(iy+0)
        or a
        jr z,.f1
        ld c,a
        ld a,(dbx)
        ld b,a
        call mul8s
.f1:    push hl
        ld hl,0
        ld a,(iy+1)
        or a
        jr z,.f2
        ld c,a
        ld a,(dby)
        ld b,a
        call mul8s
.f2:    pop de
        add hl,de
        push hl
        ld hl,0
        ld a,(iy+2)
        or a
        jr z,.f3
        ld c,a
        ld a,(dbz)
        ld b,a
        call mul8s
.f3:    pop de
        add hl,de
        ld e,(iy+3)
        ld d,(iy+4)                     ; DE = d
        ld a,(cs_k)
        or a
        jr z,.cmp
        jp m,.lsh
        cp 16                           ; d >>= k
        jr c,$+4
        ld a,15
        ld b,a
.ds:    sra d
        rr e
        djnz .ds
        jr .cmp
.lsh:   neg                             ; n.c''' >>= -k
        cp 16
        jr c,$+4
        ld a,15
        ld b,a
.ls:    sra h
        rr l
        djnz .ls
.cmp:   or a                            ; towards us if HL > DE (signed)
        sbc hl,de
        ld a,0
        jp pe,.ovf
        jr z,.put
        bit 7,h
        jr nz,.put
        inc a
        jr .put
.ovf:   bit 7,h                         ; overflowed: the sign is flipped
        jr z,.put
        inc a
.put:   pop hl
        ld (hl),a
        inc hl
        pop bc
        add a,c
        ld c,a
        ld de,5
        add iy,de
        dec b
        jp nz,.f
        ld a,c                          ; none towards us: we are inside
        or a                            ; it (flying into the station),
        ret nz                          ; so draw every edge
        ld a,(nfc)
        ld b,a
        ld hl,FVIS
.all:   ld (hl),1
        inc hl
        djnz .all
        ret

; ---------------------------------------------------------------------
; vtb_fast: as vec_to_bytes (3 words at HL -> dbx, dby, dbz within
; -100..100, A = the shift), but finds the shift at once
; ---------------------------------------------------------------------
vtb_fast:
        ld de,tvec
        ld bc,6
        ldir
        ld hl,(tvec)                    ; M = |x| or |y| or |z|
        call abs_hl
        ex de,hl
        ld hl,(tvec+2)
        call abs_hl
        ld a,h
        or d
        ld d,a
        ld a,l
        or e
        ld e,a
        ld hl,(tvec+4)
        call abs_hl
        ld a,h
        or d
        ld h,a
        ld a,l
        or e
        ld l,a
        ld b,0                          ; shift until M <= 100
.s:     ld a,h
        or a
        jr nz,.more
        ld a,l
        cp 101
        jr c,.got
.more:  srl h
        rr l
        inc b
        jr .s
.got:   ld a,b
        ld (vtb_s),a
        ld hl,tvec
        ld de,dbx
        call .one
        ld de,dby
        call .one
        ld de,dbz
        call .one
        ld a,(vtb_s)
        ret
; (HL) word >> shift -> (DE) byte; HL += 2
.one:   ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,a
        ld l,c
        ld a,(vtb_s)
        or a
        jr z,.put
        cp 8
        jr c,.sh
        sub 8                           ; take the high byte first
        ld b,a
        ld a,h
        jr z,.put1
.sb:    sra a
        djnz .sb
.put1:  ld (de),a
        pop hl
        ret
.sh:    ld b,a
.sw:    sra h
        rr l
        djnz .sw
.put:   ld a,l
        ld (de),a
        pop hl
        ret

; HL = mtx[A]*dbx + mtx[A+3]*dby + mtx[A+6]*dbz
mcol:   ld e,a
        ld d,0
        ld hl,mtx
        add hl,de
        ld (mcp),hl
        ld c,(hl)
        ld a,(dbx)
        ld b,a
        call mul8s
        ld (macc),hl
        ld hl,(mcp)
        inc hl
        inc hl
        inc hl
        ld (mcp),hl
        ld c,(hl)
        ld a,(dby)
        ld b,a
        call mul8s
        ld de,(macc)
        add hl,de
        ld (macc),hl
        ld hl,(mcp)
        inc hl
        inc hl
        inc hl
        ld c,(hl)
        ld a,(dbz)
        ld b,a
        call mul8s
        ld de,(macc)
        add hl,de
        ret

; A = face -> NZ if it is towards us.  Keeps BC, DE.
fvis:   add a,low FVIS
        ld l,a
        ld h,high FVIS
        ld a,(hl)
        or a
        ret

; ---------------------------------------------------------------------
; obj_edges: draw the edges whose faces are towards us
; (ed0) -> edge list, (ef0) -> per-edge faces, (ne) edges
; ---------------------------------------------------------------------
obj_edges:
        ld iy,(ed0)
        ld hl,(ef0)
        ld (efp),hl
        ld a,(ne)
        ld b,a
.e:     push bc
        ld hl,(efp)
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld (efp),hl
        cp 0FFh
        jr z,.draw
        call fvis
        jr nz,.draw
        ld a,c
        cp 0FFh
        jr z,.skip
        call fvis
        jr z,.skip
.draw:  ld a,(iy+0)
        ld (ea),a
        ld a,(iy+1)
        ld (eb),a
        push iy
        call draw_edge
        pop iy
.skip:  inc iy
        inc iy
        pop bc
        djnz .e
        ret

; ---------------------------------------------------------------------
; occlusion: NZ if object IX lies in front of the planet drawn this
; frame and overlaps its disc (then its outline is cleared first)
; ---------------------------------------------------------------------
occl_check:
        call occl_one                   ; the planet
        ret nz
        ld a,(mn_blk+pl_r-PL_BLK)       ; then the moon, if it is drawn
        cp 6                            ; and big enough to matter
        jr nc,.m
        xor a
        ret
.m:     ld a,(mn_blk)
        or a
        ret z
        call body_swap_blk
        call occl_one
        push af
        call body_swap_blk
        pop af
        ret
occl_one:
        ld a,(pl_on)
        or a
        ret z
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        ld de,(pl_vz)
        or a
        sbc hl,de
        jr nc,.no                       ; not in front of it
        call obj_screen
        ld l,(ix+O_Z)                   ; rs = radius * 32 / z
        ld h,(ix+O_Z+1)
        ld a,h
        or a
        jr nz,.zok
        ld a,l
        cp 16
        jr nc,.zok
        ld hl,16
.zok:   ex de,hl
        ld a,(mrad)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        call div16u
        ld a,h                          ; tiny (under 2 dots): no need
        or a
        jr nz,.big
        ld a,l
        cp 2
        jr c,.no
.big:   ld (oc_rs),hl
        call .night                     ; wholly on the dark side: nothing
        jr c,.no                        ; lit lies behind it
        ld hl,(oc_rs)
        ld a,(pl_r)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl                        ; DE = reach
        ld hl,(psx)
        ld bc,(pl_cx)
        call .near
        jr nc,.no
        ld hl,(psy)
        ld bc,(pl_cy)
        call .near
        jr nc,.no
        or 1
        ret
.no:    xor a
        ret
; C if the ship's disc (psx, psy, oc_rs) lies inside both the planet
; and its dark disc, where the screen is black anyway
.night: ld hl,(pl_cx)
        ld de,(pl_cy)
        call .inside
        ret nc
        ld a,(pl_ox)
        call sext_a
        ld hl,(pl_cx)
        add hl,de
        push hl
        ld a,(pl_oy)
        call sext_a
        ld hl,(pl_cy)
        add hl,de
        ex de,hl
        pop hl
; C if |psx - HL| + |psy - DE| + rs + 2 < r
.inside:
        push de
        ld de,(psx)
        or a
        sbc hl,de
        call abs_hl
        ex (sp),hl
        ld de,(psy)
        or a
        sbc hl,de
        call abs_hl
        pop de
        add hl,de
        ld de,(oc_rs)
        add hl,de
        inc hl
        inc hl
        ld a,(pl_r)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ret
; C if |HL - BC| < DE
.near:  or a
        sbc hl,bc
        call abs_hl
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------------
; the ship mask: per dot row, the span of the ships drawn over the planet
; ---------------------------------------------------------------------
span_clear:
        ld hl,SPMIN
        ld b,VH
.i:     ld (hl),0FFh
        set 6,l
        ld (hl),0
        res 6,l
        inc l
        djnz .i
        ret

; plot detours through HL (plot_rec, plot_mask) until plot_unhook
plot_hook:
        ld a,0C3h
        ld (plot),a
        ld (plot+1),hl
        ret

plot_unhook:
        ld a,26h                        ; ld h,high YLO
        ld (plot),a
        ld a,high YLO
        ld (plot+1),a
        ld a,69h                        ; ld l,c
        ld (plot+2),a
        ret

rec_on: ld hl,plot_rec
        jr plot_hook

; plot, noting the dot in the mask
plot_rec:
        ld h,high SPMIN
        ld l,c
        ld a,b
        cp (hl)
        jr nc,$+3
        ld (hl),a
        set 6,l
        cp (hl)
        jr c,$+3
        ld (hl),a
        ld h,high YLO
        ld l,c
        jp plot+3

; plot, unless the dot lies under a ship
plot_mask:
        ld h,high SPMIN
        ld l,c
        ld a,b
        cp (hl)
        jr c,.draw
        set 6,l
        cp (hl)
        ret z
        ret c
.draw:  ld h,high YLO                    ; plot, but a cell that has dots
        ld l,c                          ; already keeps its colour
        ld a,b
        srl a
        or (hl)
        inc h
        ld h,(hl)
        ld l,a
        ld a,b
        and 1
        inc a
        bit 0,c
        jr z,$+4
        add a,a
        add a,a
        push de
        ld d,a
        ld a,(hl)
        and 0Fh
        jr z,.new
        ld a,(hl)
        or d
        ld (hl),a
        pop de
        ret
.new:   ld a,(plotcol+1)
        or d
        ld (hl),a
        ld a,l
        or 3Fh
        ld l,a
        ld (hl),a
        pop de
        ret

; dots B..E of row C, less the mask's span on that row
mfill:  ld h,high SPMIN
        ld l,c
        ld d,(hl)
        set 6,l
        ld a,(hl)
        cp d
        jp c,hspan                      ; no ship on this row
        ld (mf_m1),a
        ld a,e
        ld (mf_e),a
        ld a,d                          ; left of it: B .. min(E, m0 - 1)
        or a
        jr z,.right
        dec a
        cp e
        jr c,$+3
        ld a,e
        cp b
        jr c,.right
        ld e,a
        push bc
        call hspan
        pop bc
.right: ld a,(mf_m1)                    ; right of it: max(B, m1 + 1) .. E
        cp VW-1
        ret nc
        inc a
        cp b
        jr nc,$+3
        ld a,b
        ld b,a
        ld a,(mf_e)
        ld e,a
        cp b
        ret c
        jp hspan

; ---------------------------------------------------------------------
; hspan: dots B..E (0..79, B <= E) of dot row C (0..35): set them in the
; plot colour, or clear them when (hs_mode) = 1.  Clobbers everything.
; ---------------------------------------------------------------------
hspan:
        ld h,high YLO
        ld l,c
        ld a,(hl)
        inc h
        ld h,(hl)
        or 3Fh                          ; mark the row drawn
        ld l,a
        ld (hl),a
        and 0C0h
        ld l,a
        ld d,3                          ; this dot row's two dots in a cell
        bit 0,c
        jr z,$+4
        ld d,0Ch
        ld a,b
        srl a
        add a,l
        ld l,a
.l:     bit 0,b
        jr nz,.right
        ld a,b
        cp e
        jr z,.left
        ld a,(hs_mode)                  ; whole cells while two dots remain
        or a
        jr nz,.both
        ld a,(plotcol+1)
        ld c,a
.run:   ld a,(hl)                       ; (a cell with dots keeps its colour)
        and 0Fh
        jr z,.rn
        ld a,(hl)
        or d
        jr .rw
.rn:    ld a,d
        or c
.rw:    ld (hl),a
        inc l
        inc b
        ld a,b
        cp e
        ret z                           ; that was the last dot
        inc b
        ld a,b
        cp e
        jr c,.run                       ; two or more dots left
        jr z,.l                         ; one left: the left dot
        ret
.both:  ld a,d                          ; both dots of the cell
        inc b
        jr .ap
.left:  ld a,d
        and 05h
        jr .ap
.right: ld a,d
        and 0Ah
.ap:    ld c,a
        ld a,(hs_mode)
        or a
        ld a,c
        jr nz,.clr
        ld a,(hl)
        and 0Fh
        jr z,.apn
        ld a,(hl)
        or c
        jr .apw
.apn:   ld a,(plotcol+1)
        or c
.apw:   ld (hl),a
        jr .nx
.clr:   cpl
        and (hl)
        ld (hl),a
.nx:    inc l
        ld a,b
        cp e
        ret z
        inc b
        jr .l

; ---------------------------------------------------------------------
; the planet: a dark limb in blue and a lit crescent in cyan where the
; sun (sunv, which turns with the world) shines past it.  The lit part
; is the disc minus the same disc shifted away from the sun by
; r * (p - s) on screen, p and s unit vectors to the planet and the sun.
; In: (ccx), (ccy) = centre, A = r (2..119)
; ---------------------------------------------------------------------
crescent:
        ld (pl_r),a
        ld hl,(ccx)
        ld (pl_cx),hl
        ld hl,(ccy)
        ld (pl_cy),hl
        ld a,1
        ld (pl_on),a
        call half_widths
        ld hl,(bp_v)                    ; p: the body's direction, unit 64
        call vtb_fast
        call vlen                       ; A = |(dbx,dby,dbz)|
        ld (pl_len),a
        ld a,(dbx)
        call unit64
        ld b,a
        ld a,(sunv+1)                   ; s.x (unit 64)
        ld c,a
        ld a,b
        sub c
        jp pe,.cx
        call shift_r                    ; ox = r * (p - s).x * 3/4 / 64
        jr .sx
.cx:    xor a
.sx:    ld (pl_ox),a
        ld a,(dby)
        call unit64
        ld b,a
        ld a,(sunv+3)
        ld c,a
        ld a,c                          ; screen y is down: (s - p).y
        sub b
        jp pe,.cy
        call shift_r
        jr .sy
.cy:    xor a
.sy:    ld (pl_oy),a
        ret

; draw the crescent (after the ships: the fill skips the mask)
crescent_rows:
        call cres_fits                  ; wholly in the view: the quick way
        jp nc,cres_fast
        ld a,(pl_col)
        call set_col
        ld a,(pl_r)                     ; rows cy - r .. cy + r in the view
        ld e,a
        ld d,0
        ld hl,(pl_cy)
        or a
        sbc hl,de
        bit 7,h
        jr z,$+5
        ld hl,0
        ld a,h
        or a
        ret nz
        ld a,l
        cp VH
        ret nc
        ld c,a
.row:   push bc
        call poll
        call .span
        pop bc
        jr nc,.rnext
        ld hl,(pl_cy)                   ; outside the disc: below it?
        bit 7,h
        ret nz
        ld a,h
        or a
        jr nz,.rnext
        ld a,c
        cp l
        ret nc
.rnext: inc c
        ld a,c
        cp VH
        jr c,.row
        ret
; dot row C: the lit spans
.span:  ld hl,(pl_cy)
        call .hw                        ; A = half width at this row, C if none
        ret c
        ld (pl_w),a
        ld e,a
        ld d,0
        ld hl,(pl_cx)
        or a
        sbc hl,de
        ld (pl_a0),hl                   ; a0 = cx - w
        add hl,de
        add hl,de
        ld (pl_a1),hl                   ; a1 = cx + w
        ld a,(pl_oy)                    ; the dark disc
        call sext_a
        ld hl,(pl_cy)
        add hl,de
        call .hw
        jr c,.whole                     ; no dark disc on this row
        ld e,a
        ld d,0
        push de
        ld a,(pl_ox)
        call sext_a
        ld hl,(pl_cx)
        add hl,de
        pop de
        push hl
        or a
        sbc hl,de
        dec hl
        ld (pl_b0),hl                   ; b0 - 1
        pop hl
        add hl,de
        inc hl
        ld (pl_b1),hl                   ; b1 + 1
        ld hl,(pl_a1)                   ; [a0, min(a1, b0-1)]
        ld de,(pl_b0)
        call min_s
        ex de,hl
        ld hl,(pl_a0)
        push bc
        call .fill
        pop bc
        ld hl,(pl_b1)                   ; [max(a0, b1+1), a1]
        ld de,(pl_a0)
        call max_s
        ld de,(pl_a1)
        call .fill
        or a
        ret
.whole: ld hl,(pl_a0)
        ld de,(pl_a1)
        call .fill
        or a
        ret
; fill dots HL..DE (signed) of row C, clipped to the view
.fill:  bit 7,h                         ; x0 < 0: 0
        jr z,$+5
        ld hl,0
        ld a,d                          ; x1 < 0: nothing
        bit 7,a
        ret nz
        or a
        jr nz,.x1c
        ld a,e
        cp VW
        jr c,.x1k
.x1c:   ld de,VW-1
.x1k:   ld a,h
        or a
        ret nz
        ld a,l
        cp VW
        ret nc
        ld a,e
        cp l
        ret c                           ; empty
        ld b,l
        call mfill
        or a
        ret
; A = half width of the disc centred on row HL at row C; C if outside
.hw:    ld e,c
        ld d,0
        ex de,hl
        or a
        sbc hl,de                       ; y - centre
        call abs_hl
        ld a,h
        or a
        scf
        ret nz
        ld a,(pl_r)
        cp l
        ret c
        ld h,high HWT
        ld a,(hl)
        or a
        ret

; HWT[dy] = half width of a disc of radius (pl_r) at row offset dy
half_widths:
        ld a,(pl_r)
        ld b,a                          ; x = r
        ld c,0                          ; y = 0
        neg
        inc a
        ld l,a
        ld h,0FFh
        ld (cr_d),hl                    ; d = 1 - r
        ld hl,HWT
        ld a,(pl_r)
        inc a
.cl:    ld (hl),0
        inc l
        dec a
        jr nz,.cl
.l:     ld h,high HWT
        ld l,c                          ; row y: at least x wide
        ld a,b
        cp (hl)
        jr c,$+3
        ld (hl),a
        ld l,b                          ; row x: at least y wide
        ld a,c
        cp (hl)
        jr c,$+3
        ld (hl),a
        inc c                           ; y++
        ld hl,(cr_d)
        bit 7,h
        jr nz,.dneg
        dec b                           ; x--: d += 2(y - x) + 1
        push bc
        ld a,c
        sub b
        ld e,a
        sbc a,a
        ld d,a
        ex de,hl
        add hl,hl
        inc hl
        add hl,de
        pop bc
        jr .t
.dneg:  ld e,c                          ; d += 2y + 1
        ld d,0
        ex de,hl
        add hl,hl
        inc hl
        add hl,de
.t:     ld (cr_d),hl
        ld a,b
        cp c
        jr nc,.l
        ret

; A = |(dbx, dby, dbz)| ~ max + 3/8 (the other two)
vlen:   ld a,(dbx)
        call .abs
        ld b,a
        ld a,(dby)
        call .abs
        ld c,a
        ld a,(dbz)
        call .abs
        ld d,a
        ld a,b                          ; the largest
        cp c
        jr nc,$+3
        ld a,c
        cp d
        jr nc,$+3
        ld a,d
        ld (vl_max),a
        ld h,0                          ; HL = the sum of all three
        ld l,b
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,d
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(vl_max)                   ; less the largest
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld d,h                          ; * 3 / 8
        ld e,l
        add hl,hl
        add hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,(vl_max)
        add a,l
        ret
.abs:   or a
        ret p
        neg
        ret

; A = byte component -> A = component * 64 / (pl_len)
unit64: push af
        call vlen.abs
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(pl_len)
        ld e,a
        ld d,0
        or a
        jr z,.z
        call div16u
        ld a,h
        or a
        ld a,l
        jr z,$+4
        ld a,127
        cp 128
        jr c,$+4
        ld a,127
.z:     ld b,a
        pop af
        or a
        ld a,b
        ret p
        neg
        ret

; A = (p - s) component (-128..127) -> A = A * r * 3 / 256 (an offset)
shift_r:
        ld b,a
        ld a,(pl_r)
        ld c,a
        call mul8s
        sra h                           ; / 2, so that * 3 fits
        rr l
        ld d,h
        ld e,l
        add hl,hl
        add hl,de                       ; * 3
        add hl,hl                       ; / 128
        ld a,h
        ret

; DE = A sign-extended
sext_a: ld e,a
        add a,a
        sbc a,a
        ld d,a
        ret

; HL = min(HL, DE) / max(HL, DE), signed
min_s:  call cmp_s
        ret c
        ex de,hl
        ret
max_s:  call cmp_s
        ret nc
        ex de,hl
        ret
; C if HL < DE (signed)
cmp_s:  push hl
        ld a,h
        xor d
        jp m,.diff
        or a
        sbc hl,de
        pop hl
        ret
.diff:  pop hl
        bit 7,h
        scf
        ret nz
        or a
        ret

; the sun's direction at launch and arrival (unit 4000h): beyond the
; planet, so it shows as a crescent; one of four sides by system
SUN0:           dw -2735,5083,15334             ; up and left
                dw 10292,3051,12378             ; up and right
                dw -4014,-7316,14100            ; down and left
                dw 9025,-7249,11595             ; down and right

; ---------------------------------------------------------------------
; the quick way, in bytes, when the whole disc lies in the view (the
; usual case): per row, the limb as two short runs and the lit spans
; ---------------------------------------------------------------------
; NC if cx - r >= 0, cx + r < VW, cy - r >= 0, cy + r < VH
cres_fits:
        ld hl,(pl_cx)
        ld a,h
        or a
        scf
        ret nz
        ld a,(pl_r)
        ld b,a
        ld a,l
        sub b
        ret c
        ld a,l
        add a,b
        cp VW
        ccf
        ret c
        ld hl,(pl_cy)
        ld a,h
        or a
        scf
        ret nz
        ld a,l
        sub b
        ret c
        ld a,l
        add a,b
        cp VH
        ccf
        ret

cres_fast:
        ld a,(pl_cx)
        ld (f_cx),a
        ld b,a
        ld a,(pl_ox)
        add a,b
        ld (f_dx),a                     ; the dark disc's centre (signed)
        ld a,(pl_cy)
        ld (f_cy),a
        ld b,a
        ld a,(pl_oy)
        add a,b
        ld (f_dy),a
        ld a,(pl_r)
        ld b,a
        ld a,(f_cy)
        sub b
        ld (f_y),a                      ; first row
.row:   call poll                       ; (the joystick and sound keep time)
        ld a,(f_y)                      ; this row's PIX, dot mask, ship mask
        ld c,a
        ld h,high YLO
        ld l,a
        ld a,(hl)
        inc h
        ld h,(hl)
        or 3Fh                          ; mark the row drawn
        ld l,a
        ld (hl),a
        and 0C0h
        ld l,a
        ld (f_base),hl
        ld a,3
        bit 0,c
        jr z,$+4
        ld a,0Ch
        ld (f_rm),a
        ld h,high SPMIN
        ld l,c
        ld a,(hl)
        ld (f_m0),a
        set 6,l
        ld a,(hl)
        ld (f_m1),a
        ld a,(f_y)                      ; |dy| -> w, a0, a1
        ld hl,f_cy
        sub (hl)
        jr nc,$+4
        neg
        ld (f_ady),a
        ld l,a
        ld h,high HWT
        ld b,(hl)
        ld a,b
        ld (f_w),a
        ld a,(f_cx)
        sub b
        ld (f_a0),a
        add a,b
        add a,b
        ld (f_a1),a
        ld a,(pl_col)                   ; the lit part
        call set_col
        ld a,(f_y)                      ; this row of the dark disc
        ld hl,f_dy
        sub (hl)
        jp p,$+5
        neg
        ld hl,pl_r
        cp (hl)
        jr z,.dk
        jr c,.dk
        ld a,(f_a0)                     ; no dark disc here: all lit
        ld b,a
        ld a,(f_a1)
        call .run
        jr .next
.dk:    ld l,a
        ld h,high HWT
        ld c,(hl)                       ; w'
        ld a,(f_dx)
        sub c
        dec a
        ld (f_b0),a                     ; b0 - 1 (signed)
        ld a,(f_dx)
        add a,c
        inc a
        ld (f_b1),a                     ; b1 + 1 (signed)
        ld a,(f_b0)                     ; left: a0 .. min(a1, b0 - 1)
        ld c,a
        ld a,(f_a1)
        ld b,a
        ld a,c
        call lt_sb
        jr c,.e1
        ld c,b
.e1:    ld a,(f_a0)
        ld b,a
        ld a,c
        call lt_sb                      ; the end before a0: nothing
        jr c,.rt
        ld a,c
        call .run
.rt:    ld a,(f_b1)                     ; right: max(a0, b1 + 1) .. a1
        ld c,a
        ld a,(f_a0)
        ld b,a
        ld a,c
        call lt_sb
        jr nc,.s1
        ld c,b
.s1:    ld b,c
        ld a,(f_a1)
        call lt_sb                      ; a1 before the start: nothing
        jr c,.next
        ld a,(f_a1)
        call .run
.next:  ld hl,f_y
        ld a,(f_cy)
        ld b,a
        ld a,(pl_r)
        add a,b
        cp (hl)
        ret z                           ; that was the last row
        inc (hl)
        jp .row
; dots B..A of this row, round the ships
.run:   ld (f_e),a
        ld a,b
        ld (f_s),a
        ld a,(f_m1)                     ; the ship mask on this row
        ld c,a
        ld a,(f_m0)
        cp c
        jr z,.cut
        jr nc,.whole                    ; none
.cut:   or a                            ; left of it: start .. min(end, m0 - 1)
        jr z,.cr
        dec a
        ld hl,f_e
        cp (hl)
        jr c,$+3
        ld a,(hl)
        ld e,a
        ld a,(f_s)
        ld b,a
        ld a,e
        cp b
        jr c,.cr
        call .piece
.cr:    ld a,(f_m1)                     ; right of it: max(start, m1 + 1) .. end
        cp VW-1
        ret nc
        inc a
        ld b,a
        ld a,(f_s)
        cp b
        jr c,$+3
        ld b,a
        ld a,(f_e)
        ld e,a
        cp b
        ret c
        jr .piece
.whole: ld a,(f_e)
        ld e,a
        ld a,(f_s)
        ld b,a
; dots B..E (B <= E) of this row in the plot colour; a cell with dots
; already keeps its colour
.piece: ld hl,(f_base)
        ld a,b
        srl a
        add a,l
        ld l,a
        ld a,(f_rm)
        ld d,a
        ld a,(plotcol+1)
        ld c,a
.p:     bit 0,b
        jr nz,.pr
        ld a,b
        cp e
        jr z,.pl
        ld a,d                          ; both dots
        inc b
        jr .pw
.pl:    ld a,d                          ; the left dot
        and 05h
        jr .pw
.pr:    ld a,d                          ; the right dot
        and 0Ah
.pw:    push af
        ld a,(hl)
        and 0Fh
        jr z,.pn
        pop af
        or (hl)
        jr .ps
.pn:    pop af
        or c
.ps:    ld (hl),a
        inc l
        ld a,b
        cp e
        ret nc
        inc b
        jr .p

; C if A < B (signed bytes).  Keeps BC.
lt_sb:  xor 80h
        push bc
        ld c,a
        ld a,b
        xor 80h
        ld b,a
        ld a,c
        cp b
        pop bc
        ret

; ---------------------------------------------------------------------
; the system's colours: pl_col = the planet's, sun_col = its star's
; ---------------------------------------------------------------------
sys_look:
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_LOOK
        ld a,(hl)
        and 7
        ld (pl_col),a
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 7
        ld (sun_col),a
        ld a,(hl)                       ; the corona: bits 7 and 3
        rlca
        rlca                            ; bit 7 -> 1
        and 2
        bit 3,(hl)
        jr z,$+3
        inc a
        ld (sun_var),a
        ret

; ---------------------------------------------------------------------
; the sun: a small ring in the star's colour with a corona of rays that
; flicker in and out, where sunv points (it lights the crescent too).
; Drawn after the ships: dots under a ship or behind the planet's disc
; (the night side as well) are left out.
; ---------------------------------------------------------------------
SUN_R           equ 3                   ; the ring's radius

sun_draw:
        xor a                           ; (sun_by: where it was last time)
        ld (sun_seen),a
        ld hl,(sunv+4)                  ; ahead of us, inside the view's
        ld de,-2800h                    ; angle (z > 0.62)?
        add hl,de
        bit 7,h
        ret nz
        ld hl,(sunv)
        ld (vx_),hl
        ld hl,(sunv+2)
        ld (vy_),hl
        ld hl,(sunv+4)
        ld (vz_),hl
        call project
        ld hl,(psx)                     ; in the view, give or take the rays
        ld de,8
        add hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp VW+16
        ret nc
        sub 8
        ld (sun_x),a
        ld hl,(psy)
        add hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp VH+16
        ret nc
        sub 8
        ld (sun_y),a
        ld a,1
        ld (sun_seen),a
        call sun_clear
        ld hl,plot_sun                  ; near the planet: test each dot
        jr c,$+5
        ld hl,plot_mask                 ; clear of it: just round the ships
        call plot_hook
        ld a,(sun_col)                  ; a ring with a burnt-out centre,
        call set_col                    ; as if the bright star had dazzled
        ld hl,SUN_RING                  ; the sensor
        ld b,16
        xor a
        ld (sun_dbl),a
        call .pts
        ld hl,(sun_d)                   ; close in: a second ring, twice
        ld de,4000                      ; the size - the sun swells
        or a
        sbc hl,de
        jr nc,.far
        ld a,1
        ld (sun_dbl),a
        ld hl,SUN_RING
        ld b,16
        call .pts
.far:   call poll
        ld a,(sun_col)                  ; the corona: eight rays, each one
        add a,a                         ; or two dots long by turns, in
        add a,a                         ; this star's own colour
        ld hl,sun_var
        add a,(hl)
        ld e,a
        ld d,0
        ld hl,CORONA
        add hl,de
        ld a,(hl)
        call set_col
        ld hl,RAYS
        ld b,8
.ray:   push bc
        push hl
        ld a,(hl)                       ; the inner dot
        inc hl
        ld c,(hl)
        call .pt
        pop hl
        pop bc
        push bc
        push hl
        ld a,(frame)
        rrca
        add a,b
        and 3
        jr z,.rn                        ; short this time
        inc hl
        inc hl
        ld a,(hl)                       ; the outer dot
        inc hl
        ld c,(hl)
        call .pt
.rn:    pop hl
        ld de,4
        add hl,de
        pop bc
        djnz .ray
        jp plot_unhook
; B dots from (HL): dx, dy pairs
.pts:   push bc
        push hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        ld b,a
        ld a,(sun_dbl)
        or a
        ld a,b
        jr z,.p1
        add a,a                         ; (doubled)
        sla c
.p1:    call .pt
        pop hl
        inc hl
        inc hl
        pop bc
        djnz .pts
        ret
; plot sun + (A, C) if it lies in the view
.pt:    ld hl,sun_x
        add a,(hl)
        cp VW
        ret nc
        ld b,a
        ld a,(sun_y)
        add a,c
        cp VH
        ret nc
        ld c,a
        jp plot

; the ring: a circle of radius 3
SUN_RING:
        db 3,0, 3,1, 2,2, 1,3, 0,3, -1,3, -2,2, -3,1
        db -3,0, -3,-1, -2,-2, -1,-3, 0,-3, 1,-3, 2,-2, 3,-1
; the rays: the inner dot (radius 5), then the outer one (radius 6)
RAYS:   db 5,0, 6,0,  3,3, 4,4,  0,5, 0,6,  -3,3, -4,4
        db -5,0, -6,0,  -3,-3, -4,-4,  0,-5, 0,-6,  3,-3, 4,-4
; the corona's colour: four choices for each star colour
CORONA: db BLUE,BLUE,BLUE,BLUE, BLUE,BLUE,BLUE,BLUE
        db MAGENTA,YELLOW,WHITE,BLUE            ; red dwarf
        db BLUE,BLUE,BLUE,BLUE, BLUE,BLUE,BLUE,BLUE
        db BLUE,WHITE,MAGENTA,GREEN             ; blue giant
        db RED,WHITE,MAGENTA,CYAN               ; yellow
        db YELLOW,CYAN,BLUE,MAGENTA             ; white

; NC if the sun's disc lies wholly in the view and its box (rays and
; all) misses the planet's
sun_clear:
        ld a,(sun_x)
        cp SUN_R
        ret c
        cp VW-SUN_R
        ccf
        ret c
        ld a,(sun_y)
        cp SUN_R
        ret c
        cp VH-SUN_R
        ccf
        ret c
        ld a,(pl_mode)
        cp 2
        jr nz,.yes
        ld a,(pl_r)
        add a,8
        ld e,a
        ld d,0                          ; DE = r + reach of the rays
        ld a,(sun_x)
        ld l,a
        ld h,0
        ld bc,(pl_cx)
        or a
        sbc hl,bc
        call abs_hl
        or a
        sbc hl,de
        jr nc,.yes                      ; far enough across
        ld a,(sun_y)
        ld l,a
        ld h,0
        ld bc,(pl_cy)
        or a
        sbc hl,bc
        call abs_hl
        or a
        sbc hl,de
        ret                             ; NC if far enough down or up
.yes:   or a
        ret

; plot for the sun: not under a ship, not behind the planet
plot_sun:
        ld h,high SPMIN                 ; under a ship?
        ld l,c
        ld a,b
        cp (hl)
        jr c,.ns
        set 6,l
        cp (hl)
        ret z
        ret c
.ns:    ld a,(pl_mode)                  ; behind the planet's disc?
        cp 2
        jr nz,.draw
        ld a,(pl_cy+1)                  ; its centre within 0..255: bytes
        ld hl,pl_cx+1
        or (hl)
        jr nz,.wide
        ld a,(pl_cy)
        sub c
        jr nc,$+4
        neg
        ld hl,pl_r
        cp (hl)
        jr z,.in1
        jr nc,.draw
.in1:   ld l,a
        ld h,high HWT
        ld a,(pl_cx)
        sub b
        jr nc,$+4
        neg
        cp (hl)
        ret c
        ret z
        jr .draw
.wide:  push de
        ld hl,(pl_cy)
        ld e,c
        ld d,0
        ex de,hl
        or a
        sbc hl,de
        call abs_hl
        ld a,h
        or a
        jr nz,.out
        ld a,(pl_r)
        cp l
        jr c,.out
        ld h,high HWT
        ld a,(hl)                       ; half width at this row
        push af
        ld hl,(pl_cx)
        ld e,b
        ld d,0
        ex de,hl
        or a
        sbc hl,de
        call abs_hl
        pop af
        ld e,a
        ld d,0
        or a
        sbc hl,de
        pop de
        ret c                           ; inside the disc
        jr z,.ret
        jr .draw
.ret:   ret
.out:   pop de
.draw:  jp plot_mask.draw

; ---------------------------------------------------------------------
; the moon: a second body, drawn with the planet's code.  Its state
; (PL_BLK, BLKSZ bytes, and its half widths) lives in mn_blk / mn_hwt
; and is swapped in to draw it.  The nearer body is drawn first and its
; whole disc joins the ship mask, so the farther body and the sun are
; hidden behind it.
; ---------------------------------------------------------------------
MOON_R          equ 3000

; exchange the body in PL_BLK (and HWT) with the one in mn_blk (mn_hwt)
body_swap:
        ld a,(pl_r)                     ; the half widths: the larger disc's
        ld hl,mn_blk+1
        cp (hl)
        jr nc,$+3
        ld a,(hl)
        inc a
        ld b,a
        ld hl,HWT
        ld de,mn_hwt
        call xchg_b
body_swap_blk:
        ld hl,PL_BLK
        ld de,mn_blk
        ld b,BLKSZ
; exchange B bytes at HL and DE (flags kept)
xchg_b: ld c,(hl)
        ld a,(de)
        ld (hl),a
        ld a,c
        ld (de),a
        inc hl
        inc de
        djnz xchg_b
        ret

; before planet_prep: the moon's place and shape, into mn_blk
moon_prep:
        ld a,(mn_on)
        or a
        ret z
        ld hl,moon
        ld de,MOON_R
        call body_prep
        ld a,(mn_on)                    ; its colour
        and 7
        ld (pl_col),a
        jp body_swap

; the sun and the bodies, round the ships (in place of sun_draw and
; planet_draw)
bodies_draw:
        ld a,(mn_on)
        or a
        jr z,.plain
        ld a,(mn_blk+pl_mode-PL_BLK)
        or a
        jr z,.plain                     ; the moon is out of sight
        ld hl,(mn_blk+pl_vz-PL_BLK)
        ld de,(pl_vz)
        or a
        sbc hl,de
        sbc a,a                         ; FFh: the moon is the nearer
        push af
        or a
        call nz,body_swap
        call planet_draw                ; the nearer
        call discs_meet                 ; over the farther: it hides it
        call nc,disc_mask
        call body_swap
        call planet_draw                ; the farther
        call sun_by                     ; by the sun: it hides it
        call nc,disc_mask
        pop af
        or a
        call z,body_swap                ; the planet back in place
        jp sun_draw
.plain: call sun_draw
        jp planet_draw

; NC if the two bodies' discs (PL_BLK, mn_blk) may overlap on screen
discs_meet:
        ld a,(mn_blk+pl_r-PL_BLK)
        ld hl,pl_r
        add a,(hl)
        add a,2
        ld e,a
        ld d,0                          ; DE = reach
        ld hl,(pl_cx)
        ld bc,(mn_blk+pl_cx-PL_BLK)
        call .far
        ret c
        ld hl,(pl_cy)
        ld bc,(mn_blk+pl_cy-PL_BLK)
; C if |HL - BC| > DE
.far:   push de
        or a
        sbc hl,bc
        call abs_hl
        pop de
        ex de,hl
        or a
        sbc hl,de
        ret

; NC if the sun may lie behind the body in PL_BLK (where it was drawn
; last frame: it moves little)
sun_by: ld a,(sun_seen)
        or a
        scf
        ret z                           ; out of sight
        ld a,(pl_r)
        add a,12                        ; the ring and its rays
        ld e,a
        ld d,0
        ld a,(sun_x)
        call .sx
        ld bc,(pl_cx)
        push de
        call discs_meet.far
        pop de
        ret c
        ld a,(sun_y)
        call .sx
        ld bc,(pl_cy)
        jr discs_meet.far
.sx:    ld l,a                          ; HL = A sign-extended
        add a,a
        sbc a,a
        ld h,a
        ret

; the body's whole disc joins the mask (SPMIN / SPMAX) row by row
disc_mask:
        ld a,(pl_mode)
        cp 2
        ret nz
        ld a,(pl_r)                     ; rows cy - r .. cy + r
        ld e,a
        ld d,0
        ld hl,(pl_cy)
        or a
        sbc hl,de
        bit 7,h
        jr z,$+5
        ld hl,0
        ld a,h
        or a
        ret nz
        ld a,l
        cp VH
        ret nc
        ld c,a
.row:   push bc
        ld hl,(pl_cy)
        call crescent_rows.hw           ; A = half width, C if off the disc
        pop bc
        jr nc,.in
        ld hl,(pl_cy)                   ; off the disc: past it?
        bit 7,h
        ret nz
        ld a,h
        or a
        jr nz,.next
        ld a,c
        cp l
        ret nc
        jr .next
.in:    ld e,a
        ld d,0
        ld hl,(pl_cx)
        or a
        sbc hl,de
        push hl                         ; x0 = cx - w
        add hl,de
        add hl,de                       ; x1 = cx + w
        bit 7,h
        jr nz,.off                      ; all left of the view
        ld a,h
        or a
        jr nz,.c1
        ld a,l
        cp VW
        jr c,$+4
.c1:    ld a,VW-1
        ld b,a
        pop hl
        bit 7,h
        jr z,$+5
        ld hl,0
        ld a,h
        or a
        jr nz,.next
        ld a,l
        cp VW
        jr nc,.next                     ; all right of it
        ld h,high SPMIN
        ld l,c
        cp (hl)
        jr nc,$+3
        ld (hl),a
        set 6,l
        ld a,b
        cp (hl)
        jr c,$+3
        ld (hl),a
        jr .next
.off:   pop hl
.next:  inc c
        ld a,c
        cp VH
        jr c,.row
        ret

; the moon's place by its planet (world_init), by SYS_MOON bits 4-5
moon_place:
        push ix
        call .p
        pop ix
        ret
.p:     ld a,(cur_sys)
        ld l,a
        ld h,high SYS_MOON
        ld a,(hl)
        ld (mn_on),a
        rrca
        rrca
        rrca
        rrca
        and 3
        ld e,a
        add a,a
        add a,e
        add a,a                         ; * 6
        ld e,a
        ld d,0
        ld hl,MOFF
        add hl,de
        ex de,hl                        ; DE -> the offset
        ld hl,planet
        ld ix,moon
        ld b,3
.c:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ex de,hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        add hl,bc
        ld (ix+0),l
        ld (ix+1),h
        pop hl
        inc hl
        ex de,hl
        inc ix
        inc ix
        pop bc
        djnz .c
        ret

; where a moon lies from its planet: left and up, right and up, left and
; down, right and down (|x|+|y|+|z| stays near clamp_far's 31000)
MOFF:   dw -16000,3000,0
        dw 8000,5000,-4000
        dw -10000,-4000,-2000
        dw 4000,-5000,-5000
