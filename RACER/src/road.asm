; =====================================================================
;  road.asm - the pseudo-3D road
;
;  The road picture is character rows 9-24, every cell the upper-half
;  block: its foreground colour is the top half of the cell and its
;  background the bottom half, so the road is a 40 x 32 colour picture
;  held as attributes only (PK, 16 rows of 64 bytes).
;
;  road_draw walks the segments ahead of the camera (every segment near,
;  every 2nd, then every 4th further away), accumulating the curve, and
;  projects each sampled segment: screen row from its height, centre and
;  half width from its scale.  Between two samples it fills the sub-rows
;  the strip covers, nearest first, interpolating centre and width; a
;  strip behind a crest is skipped (rows already covered stay).  Each
;  sub-row is a list of runs: grass, rumble, road, lane line, road, lane
;  line, road, rumble, grass.  Odd sub-rows (the cell's bottom half,
;  drawn first because rows go upwards) store the colour; even ones OR
;  the colour into the high nibble.
;  At the next vertical blank road_blit copies PK to colour RAM.
; =====================================================================

; ---------------------------------------------------------------------
; road_draw: project and rasterise the road for the camera at (pos, px)
road_draw:
        ; s0 = pos / 16, frac = pos & 15
        ld hl,(pos)
        ld a,l
        and 15
        ld (rd_frac),a
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld (rd_s0),hl
        ; camera height: road under the camera (interpolated) + CAMH + bounce
        ld de,TRK_HGT
        add hl,de
        ld a,(hl)
        ld c,a                  ; h0
        inc hl
        ld a,(hl)
        sub c                   ; h1 - h0 (signed, small)
        ld e,a
        ld a,(rd_frac)
        call smul_frac16        ; A = (h1-h0)*frac/16
        add a,c
        ld l,a
        rla
        sbc a,a
        ld h,a                  ; HL = sign-extended road height
        ld a,(bounce)
        add a,CAMH
        ld e,a
        ld d,0
        add hl,de
        ld (rd_hcam),hl
        ; curve: x = 0, dx = -(curv[s0] * frac / 16)
        ld hl,(rd_s0)
        ld de,TRK_CURV
        add hl,de
        ld (rd_cptr),hl
        ld e,(hl)
        ld a,(rd_frac)
        call smul_frac16
        neg
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld (rd_dx),hl
        ld hl,0
        ld (rd_x),hl
        ld a,NSR
        ld (rd_ymax),a
        ; the baseline (n = 0): just in front of the camera
        ld hl,(rd_s0)
        ld (rd_seg),hl
        ld a,255
        call rd_project
        ld a,(rd_y)
        ld (rd_py),a
        ld hl,(rd_cx)
        ld (rd_pcx),hl
        ld a,(rd_hw)
        ld (rd_phw),a
        xor a
        ld (rd_n),a
        ld iy,XS
        ld hl,(rd_x)
        ld de,(rd_dx)
        ld bc,(rd_cptr)
.seg:   ; next segment: n += 1, curve accumulation (HL = x, DE = dx,
        ; BC = curve pointer, IY = XS entry)
        ld a,(rd_n)
        inc a
        cp NSAMP+1
        jp nc,.done
        ld (rd_n),a
        add hl,de               ; x += dx
        ld (iy+0),l             ; XS[n] = x, clip
        ld (iy+1),h
        ld a,(rd_ymax)
        ld (iy+2),a
        inc iy
        inc iy
        inc iy
        inc bc                  ; dx += curve[seg]
        ld a,(bc)
        or a
        jp p,.cp
        dec d
.cp:    add a,e
        ld e,a
        jr nc,.cn
        inc d
.cn:    ; sampled?  STRM[n]: n < 8 every segment, < 16 even ones, < 32
        ; every 4th, then every 8th
        push hl
        ld l,a
        ld h,high STRM
        ld a,(rd_s0)
        add a,l
        and (hl)
        pop hl
        jp nz,.seg
.samp0: ld (rd_x),hl
        ld (rd_dx),de
        ld (rd_cptr),bc
        ld (rd_iy),iy
        ld hl,(rd_s0)
        ld a,(rd_n)
        ld e,a
        ld d,0
        add hl,de
        ld (rd_seg),hl
.samp:  ; z = n*16 - frac -> scale
        ld a,(rd_n)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(rd_frac)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld de,RECIP
        add hl,de
        ld a,(hl)
        call rd_project
        ld a,(rd_y)             ; visible: y < ymax (signed)
        or a
        jp m,.vis
        ld b,a
        ld a,(rd_ymax)
        cp b
        jp z,.next
        jp c,.next              ; y >= ymax: behind a crest
.vis:
        call rd_strip
.next:  ld a,(rd_y)
        ld (rd_py),a
        ld hl,(rd_cx)
        ld (rd_pcx),hl
        ld a,(rd_hw)
        ld (rd_phw),a
        ld hl,(rd_x)
        ld de,(rd_dx)
        ld bc,(rd_cptr)
        ld iy,(rd_iy)
        ld a,(rd_ymax)
        or a
        jp nz,.seg
        ; the screen is full: the rest are hidden
        ld a,(rd_n)
.fillc: inc a                   ; (their clip is 0)
        cp NSAMP+1
        jr nc,.done
        ld (iy+2),0
        inc iy
        inc iy
        inc iy
        jr .fillc
.done:  ; above the last strip: distant land
        ld a,2                  ; (the flat colour table)
        ld (st_ct),a
        xor a
        ld (st_spl),a
        ld a,(rd_ymax)
        or a
        ret z
.far:   dec a
        push af
        ld de,160
        ld b,0
        call fill_sub
        pop af
        or a
        jr nz,.far
        ret

; A = scale of the segment rd_seg -> rd_y, rd_cx, rd_hw, rd_s, rd_line
rd_project:
        ld (rd_s),a
        ld c,a
        ; y = (hcam - hgt[seg]) * s >> 8, clamped to -127..127
        ld hl,(rd_seg)
        ld de,TRK_HGT
        add hl,de
        ld a,(hl)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld hl,(rd_hcam)
        or a
        sbc hl,de
        ld a,c
        call mul_hs
        call clamp_s8
        ld (rd_y),a
        ; hw = HWT[s]
        ld a,(rd_s)
        ld l,a
        ld h,high HWT
        ld a,(hl)
        ld (rd_hw),a
        ; cx = 160 + ((x >> 2) - px) * s >> 8
        ld hl,(rd_x)
        sra h
        rr l
        sra h
        rr l
        ld de,(px)
        or a
        sbc hl,de
        ld a,(rd_s)
        call mul_hs
        ld de,160
        add hl,de
        ld (rd_cx),hl
        ; stripe: colours for this segment
        ld a,(rd_seg)
        and 2
        rrca
        ld (rd_stripe),a
        ; a second road (fork, or the road not taken)?
        ld hl,(rd_seg)
        ld de,TRK_SPL
        add hl,de
        ld a,(hl)
        or a
        jr z,.sp
        ld c,a
        ld hl,(rd_seg)          ; the road not taken shows only close by
        ld de,(ghostend)
        or a
        sbc hl,de
        ld a,c
        jr nc,.sp
        ld a,(rd_s)
        cp 24
        ld a,c
        jr nc,.sp
        xor a
.sp:    ld (rd_spl),a
        ret

; HL signed -> A clamped to -127..127
clamp_s8:
        ld a,h
        or a
        jr z,.pos
        inc a
        jr z,.neg
        bit 7,h
        ld a,127
        ret z
        ld a,-127
        ret
.pos:   ld a,l
        cp 128
        ret c
        ld a,127
        ret
.neg:   ld a,l
        cp 129
        ret nc
        ld a,-127
        ret

; ---------------------------------------------------------------------
; fill the strip between the previous sample (rd_py/pcx/phw, near) and
; this one (rd_y/cx/hw, far): sub-rows max(y,0) .. ymax-1
rd_strip:
        ld a,(rd_stripe)        ; the strip's colours: table 0 or 1
        ld (st_ct),a
        ld a,(rd_spl)
        ld (st_spl),a
        ; rows = py - y (1..254)
        ld a,(rd_y)
        ld b,a
        ld a,(rd_py)
        sub b
        ld c,a                  ; C = rows
        ld a,(rd_y)             ; only one row shows?  (ymax = y + 1)
        inc a
        ld b,a
        ld a,(rd_ymax)
        cp b
        jr z,.one
        ld a,c
        cp 2
        jr c,.one
        jp nz,.interp
        ; two rows: the middle, then the far values
        ld hl,(rd_cx)
        ld de,(rd_pcx)
        add hl,de
        sra h
        rr l
        ld (st_cx),hl
        ex de,hl
        ld hl,(rd_cx)
        or a
        sbc hl,de
        ld h,l
        ld l,0
        ld (st_dcx),hl
        ld a,(rd_hw)
        ld b,a
        ld a,(rd_phw)
        add a,b
        rra
        ld (st_hw),a
        ld c,a
        ld a,b
        sub c
        ld h,a
        ld l,0
        ld (st_dhw),hl
        xor a
        ld (st_cxf),a
        ld (st_hwf),a
        jp .rows
.one:   ; one row: the far values
        ld hl,(rd_cx)
        ld (st_cx),hl
        ld a,(rd_hw)
        ld (st_hw),a
        ld hl,0
        ld (st_dcx),hl
        ld (st_dhw),hl
        xor a
        ld (st_cxf),a
        ld (st_hwf),a
        jp .rows
.interp:
        ld a,c
        cp 128
        jr c,.rc
        ld a,127
.rc:    ld l,a
        ld h,high QT
        ld a,(hl)
        ld (st_q),a             ; Q = 256 / rows
        ; dcx = clamp(cx - pcx, +-255) * Q  (8.8)
        ld hl,(rd_cx)
        ld de,(rd_pcx)
        or a
        sbc hl,de
        call clamp_s9
        ld a,(st_q)
        call mul_full           ; AHL = HL * A
        ld (st_dcx),hl
        ; dhw = (hw - phw) * Q
        ld a,(rd_hw)
        ld l,a
        ld h,0
        ld a,(rd_phw)
        ld e,a
        ld d,h
        or a
        sbc hl,de
        ld a,(st_q)
        call mul_full
        ld (st_dhw),hl
        ; k = py - (ymax - 1): start values = p + d*k
        ld a,(rd_ymax)
        dec a
        ld b,a
        ld a,(rd_py)
        sub b
        ld (st_k),a
        dec a
        jr nz,.kmul
        ld hl,(st_dcx)          ; k = 1: p + d
        ld a,l
        ld (st_cxf),a
        ld a,h
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld hl,(rd_pcx)
        add hl,de
        ld (st_cx),hl
        ld hl,(st_dhw)
        ld a,l
        ld (st_hwf),a
        ld a,(rd_phw)
        add a,h
        ld (st_hw),a
        jr .rows
.kmul:  ld a,(st_k)
        ld hl,(st_dcx)
        call mul_full           ; AHL = dcx * k  (16.8)
        ld e,h
        ld d,a
        ld a,l
        ld (st_cxf),a
        ld hl,(rd_pcx)
        add hl,de
        ld (st_cx),hl
        ld a,(st_k)
        ld hl,(st_dhw)
        call mul_full
        ld a,l
        ld (st_hwf),a
        ld a,(rd_phw)
        add a,h
        ld (st_hw),a
.rows:  ; sub-rows ymax-1 down to max(y, 0)
        ld a,(rd_y)
        or a
        jp p,.t0
        xor a
.t0:    ld (st_top),a
        ld a,(rd_ymax)
.row:   dec a
        ld (st_yy),a
        rra
        jr nc,.even
        ld hl,(st_cx)           ; a bottom half: remember it (fill_sub)
        ld (fc_cx),hl
        ld a,(st_hw)
        ld (fc_hw),a
        ld a,(st_ct)
        ld (fc_bot),a
        ld a,(st_spl)
        ld (fc_spl),a
        jr .step
.even:  ld de,(st_cx)
        ld a,(st_hw)
        ld b,a
        ld a,(st_yy)
        call fill_sub
.step:  ; step
        ld hl,(st_dcx)
        ld a,h
        ld e,a
        rla
        sbc a,a
        ld d,a                  ; DE = int part of dcx, sign-extended
        ld a,(st_cxf)
        add a,l
        ld (st_cxf),a
        ld hl,(st_cx)
        adc hl,de
        ld (st_cx),hl
        ld a,(st_hwf)
        ld hl,(st_dhw)
        add a,l
        ld (st_hwf),a
        ld a,(st_hw)
        adc a,h
        ld (st_hw),a
        ld a,(st_top)
        ld b,a
        ld a,(st_yy)
        cp b
        jr z,.end
        jr .row
.end:   ld (rd_ymax),a
        ret

; HL signed -> HL clamped to -255..255
clamp_s9:
        ld a,h
        or a
        ret z
        inc a
        ret z
        bit 7,h
        ld hl,255
        ret z
        ld hl,-255
        ret

; ---------------------------------------------------------------------
; fill_sub: one sub-row of the road.  DE = centre (1/8 cells), B = half
; width (1/8 cells), A = sub-row (0..31), (st_ct) = colour table (0 =
; stripe A, 1 = stripe B, 2 = flat).  Sub-rows arrive from the bottom up,
; so a cell's bottom half (odd sub-row) comes first: it is remembered, and
; the top half then fills the whole character row in one pass.  The edges
; come from the bottom half's centre and width; each run's colour pair is
; CPAIR[top*3 + bottom][run].
; Edges: for a centre 8C+f and an offset o the right edge is C + EDT[f][o]
; and the left one C + 1 - EDT[7-f][o], clamped to 0..40 by CLMP.
; Runs: grass, rumble, road, line, road, line, road, rumble, grass.
fill_sub:
        srl a
        jr nc,.top
        ld (fc_cx),de
        ld a,b
        ld (fc_hw),a
        ld a,(st_ct)
        ld (fc_bot),a
        ld a,(st_spl)
        ld (fc_spl),a
        ret
.top:   ld (fc_row),a
        ld a,(fc_spl)
        or a
        jp nz,fork_row
.norm:
        ld a,(st_ct)            ; IX = CPAIR + (top*3 + bottom) * 9
        ld c,a
        add a,a
        add a,c
        ld hl,fc_bot
        add a,(hl)
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld e,a
        ld d,0
        ld ix,CPAIR
        add ix,de
        ; centre cell C (clamped to -40..80) and fraction f
        ld de,(fc_cx)
        ld a,e
        and 7
        ld c,a
        add a,high EDT
        ld (fc_pr),a
        ld a,c
        xor 7
        add a,high EDT
        ld (fc_pl),a
        sra d
        rr e
        sra d
        rr e
        sra d
        rr e
        ld a,d
        or a
        jr z,.cp
        inc a
        jr z,.cn
        bit 7,d
        ld e,80
        jr z,.cok
        ld e,-40
        jr .cok
.cp:    ld a,e
        cp 81
        jr c,.cok
        ld e,80
        jr .cok
.cn:    ld a,e
        cp -40
        jr nc,.cok
        ld e,-40
.cok:   ld d,e
        inc d                   ; D = C + 1 (left edges), E = C (right)
        ld a,(fc_hw)
        ld b,a                  ; B = hw
        ld l,a
        ld h,high O1T
        ld c,(hl)               ; C = hw + rumble
        ld a,c
        ld l,a
        ld a,(fc_pl)
        ld h,a
        ld a,d
        sub (hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+0),a
        ld a,b
        ld l,a
        ld a,(fc_pl)
        ld h,a
        ld a,d
        sub (hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+1),a
        ; lane lines: theme has them, a half is stripe A, wide enough
        ld a,(pal_a+4)
        or a
        jr z,.nol
        ld l,b
        ld h,high LWT
        ld a,(hl)
        or a
        jr z,.nol
        ld a,(st_ct)
        or a
        jr z,.lin
        ld a,(fc_bot)
        or a
        jr nz,.nol
.lin:
        ld l,b
        ld h,high LPT
        ld a,(hl)
        ld l,a
        ld a,(fc_pl)
        ld h,a
        ld a,d
        sub (hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+2),a
        ld l,b
        ld h,high LMT
        ld a,(hl)
        ld l,a
        ld a,(fc_pl)
        ld h,a
        ld a,d
        sub (hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+3),a
        ld l,b
        ld h,high LMT
        ld a,(hl)
        ld l,a
        ld a,(fc_pr)
        ld h,a
        ld a,e
        add a,(hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+4),a
        ld l,b
        ld h,high LPT
        ld a,(hl)
        ld l,a
        ld a,(fc_pr)
        ld h,a
        ld a,e
        add a,(hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+5),a
        jr .rr
.nol:   ld a,(fc_e+1)           ; no lines: empty runs
        ld (fc_e+2),a
        ld (fc_e+3),a
        ld (fc_e+4),a
        ld (fc_e+5),a
.rr:
        ld a,b
        ld l,a
        ld a,(fc_pr)
        ld h,a
        ld a,e
        add a,(hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+6),a
        ld a,c
        ld l,a
        ld a,(fc_pr)
        ld h,a
        ld a,e
        add a,(hl)
        ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (fc_e+7),a
        ; fill the runs into PK row
.fill:  ld a,(fc_row)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PK
        add hl,de
        ld b,0
        ld a,(fc_e+0)
        sub b
        jr z,.r0
        jr c,.r0
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+0)
        call run_store
.r0:
        ld a,(fc_e+1)
        sub b
        jr z,.r1
        jr c,.r1
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+1)
        call run_store
.r1:
        ld a,(fc_e+2)
        sub b
        jr z,.r2
        jr c,.r2
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+2)
        call run_store
.r2:
        ld a,(fc_e+3)
        sub b
        jr z,.r3
        jr c,.r3
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+3)
        call run_store
.r3:
        ld a,(fc_e+4)
        sub b
        jr z,.r4
        jr c,.r4
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+4)
        call run_store
.r4:
        ld a,(fc_e+5)
        sub b
        jr z,.r5
        jr c,.r5
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+5)
        call run_store
.r5:
        ld a,(fc_e+6)
        sub b
        jr z,.r6
        jr c,.r6
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+6)
        call run_store
.r6:
        ld a,(fc_e+7)
        sub b
        jr z,.r7
        jr c,.r7
        ld e,a
        add a,b
        ld b,a
        ld d,(ix+7)
        call run_store
.r7:
        ld a,40
        sub b
        ret z
        ret c
        ld e,a
        ld d,(ix+8)
        jp run_store

; ---------------------------------------------------------------------
; a character row with two roads: the second road's centre is the first's
; + hw * spl * 13 / 256 (spl = split in 8s of world units, 160 = ROADW)
fork_row:
        ld a,(fc_hw)
        ld l,a
        ld a,(fc_spl)
        ld b,a
        bit 7,a
        jr z,.p
        neg
.p:     ld c,a
        push bc
        call mul88              ; hw * |spl|
        ld a,13
        call mul_hu             ; * 13 / 256 (hw*|spl| < 8000h)
        pop bc
        bit 7,b
        call nz,neg_hl
        ld de,(fc_cx)
        add hl,de               ; HL = second centre
        ; left road at the lower centre
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.ord
        ex de,hl
.ord:   ld (fk_c2),hl           ; right road
        ld (fk_c1),de           ; left road
        ld a,(fc_hw)
        ld b,a
        ld l,a
        ld h,high O1T
        ld c,(hl)               ; C = hw + rumble
        ld de,(fk_c1)
        ld iy,fc_e
        call road4
        ld de,(fk_c2)
        ld iy,fc_e+4
        call road4
        ; overlapping?  (second road's outer left edge <= first's outer right)
        ld a,(fc_e+4)
        ld hl,fc_e+3
        cp (hl)
        jr c,.merge
        jr z,.merge
        ; two roads: the fork colours
        ld a,(st_ct)
        ld ix,CPAIRF
        jr .tab
.merge: ld a,(fc_e+6)           ; one wide road: left from the first,
        ld (fc_e+6),a           ; right from the second
        ld a,(fc_e+1)
        ld (fc_e+2),a
        ld (fc_e+3),a
        ld (fc_e+4),a
        ld (fc_e+5),a
        ld a,(st_ct)
        ld ix,CPAIR
.tab:   ld c,a                  ; IX += (top*3 + bottom) * 9
        add a,a
        add a,c
        ld hl,fc_bot
        add a,(hl)
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld e,a
        ld d,0
        add ix,de
        jp fill_sub.fill

; DE = centre (1/8 cells), B = hw, C = hw + rumble: four edges at IY
; (outer left, inner left, inner right, outer right)
road4:
        ld a,e
        and 7
        ld l,a
        add a,high EDT
        ld (fc_pr),a
        ld a,l
        xor 7
        add a,high EDT
        ld (fc_pl),a
        sra d
        rr e
        sra d
        rr e
        sra d
        rr e
        ld a,d                  ; clamp the cell to -40..80
        or a
        jr z,.cp
        inc a
        jr z,.cn
        bit 7,d
        ld e,80
        jr z,.cok
        ld e,-40
        jr .cok
.cp:    ld a,e
        cp 81
        jr c,.cok
        ld e,80
        jr .cok
.cn:    ld a,e
        cp -40
        jr nc,.cok
        ld e,-40
.cok:   ld d,e
        inc d
        ld a,c
        call .l
        ld a,b
        call .l
        ld a,b
        call .r
        ld a,c
.r:     ld l,a
        ld a,(fc_pr)
        ld h,a
        ld a,e
        add a,(hl)
        jr .st
.l:     ld l,a
        ld a,(fc_pl)
        ld h,a
        ld a,d
        sub (hl)
.st:    ld l,a
        ld h,high CLMP
        ld a,(hl)
        ld (iy+0),a
        inc iy
        ret

; E = count (1..40), D = colour, HL = buffer: store, HL advanced
run_store:
        ld a,40
        sub e
        add a,a
        ld (.j+1),a
.j:     jr $+2
        rept 40
        ld (hl),d
        inc l
        endr
        ret

; ---------------------------------------------------------------------
; road_blit (PK -> colour RAM) is generated: build/gen_blit.inc

; put the half-block character in every road cell (once per screen)
road_chars:
        ld hl,VRAM+ROADROW*40
        ld bc,NCR*40
.c:     ld (hl),HALF
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.c
        ret
