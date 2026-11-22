; =====================================================================
;  sprite.asm - roadside objects and traffic, drawn into the road picture
;
;  Sprites are chunky pictures in sub-rows (half cells), pre-scaled at
;  build time (tools/art.py): SPR_x = 13 words, one image per size.  An
;  image is  w, h, then per row runs of (skip, length, colours...) and
;  0FFh at the row's end.  Colours are c*17, so one AND mask picks the
;  cell's top or bottom half.
;  spr_draw goes from the far end of the road to the camera, drawing each
;  segment's object and then the traffic on that segment, so nearer ones
;  cover farther ones; road nearer than a sprite covers its bottom (clip).
; =====================================================================

spr_draw:
        ; bucket the traffic by segment ahead: CARN[n] = car + 1
        ld hl,CARN
        ld b,NSAMP+2
        xor a
.cl:    ld (hl),a
        inc hl
        djnz .cl
        ld ix,CARS
        ld b,MAXCARS
.cb:    ld a,(ix+C_ON)
        or a
        jr z,.cn
        ld (ix+C_NEXT),0
        ld l,(ix+C_Z)           ; rz = z - pos
        ld h,(ix+C_Z+1)
        ld de,(pos)
        or a
        sbc hl,de
        jr c,.cn                ; behind the camera
        ld (ix+C_RZ),l
        ld (ix+C_RZ+1),h
        ld de,8
        sbc hl,de
        jr c,.cn
        ld l,(ix+C_RZ)
        ld h,(ix+C_RZ+1)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; H = rz / 16 = n
        ld a,h
        cp NSAMP
        jr nc,.cn
        ld e,a
        ld d,0
        ld hl,CARN
        add hl,de
        ld a,(hl)               ; chain onto whatever is there
        ld (ix+C_NEXT),a
        ld a,MAXCARS
        sub b
        inc a
        ld (hl),a
.cn:    ld de,CARSZ
        add ix,de
        djnz .cb
        ; far to near
        ld hl,(rd_s0)
        ld de,TRK_OBJ+NSAMP
        add hl,de
        ld (sd_optr),hl
        ld a,NSAMP
.n:     ld (sd_n),a
        ld hl,(sd_optr)         ; the object on segment s0 + n
        ld a,(hl)
        dec hl
        ld (sd_optr),hl
        or a
        jr z,.no
        inc hl
        ld de,-TRK_OBJ
        add hl,de
        ld (sd_seg),hl
        call draw_object
.no:    ld a,(sd_n)             ; the traffic on it
        ld e,a
        ld d,0
        ld hl,CARN
        add hl,de
        ld a,(hl)
.car:   or a
        jr z,.nc
        dec a
        call car_ix
        call draw_car
        ld a,(ix+C_NEXT)
        jr .car
.nc:    ld a,(sd_n)
        dec a
        jr nz,.n
        ret

; A = car index -> IX = its record
car_ix:
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld ix,CARS
        add ix,de
        ret

; A = object type on segment sd_seg (n = sd_n): project and draw it
draw_object:
        ld (sd_type),a
        ; z = n*16 - frac
        ld a,(sd_n)
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
        ; side position: TRK_OX * 4
        push hl
        ld hl,(sd_seg)
        ld de,TRK_OX
        add hl,de
        ld a,(hl)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        ld (sd_ox),hl
        pop hl
        ld a,(sd_type)
        jp draw_at

; IX = car: project and draw it
draw_car:
        push ix
        ld l,(ix+C_X)
        ld h,(ix+C_X+1)
        ld (sd_ox),hl
        ld a,(ix+C_Z)           ; the car's own segment (for its height)
        ld l,a
        ld h,(ix+C_Z+1)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld (sd_seg),hl
        ld l,(ix+C_RZ)
        ld h,(ix+C_RZ+1)
        ld a,(ix+C_ON)
        add a,O_CAR0-1
        call draw_at
        pop ix
        ret

; HL = z ahead of the camera, A = sprite number, sd_seg = segment for
; the height, sd_n = segment ahead (curve x, clip), sd_ox = side offset
draw_at:
        ld (sd_type),a
        ld de,RECIP
        add hl,de
        ld a,(hl)
        ld (sd_s),a
        ; image: SPRTAB[type] -> size table, SCLS[s] -> image
        ld a,(sd_type)
        add a,a
        ld l,a
        ld h,0
        ld de,SPRTAB-2
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(sd_s)
        ld l,a
        ld h,high SCLS
        ld a,(hl)
        add a,a
        ld l,a
        ld h,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sd_img),de
        ; base row: (hcam - hgt[seg]) * s >> 8
        ld hl,(sd_seg)
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
        ld a,(sd_s)
        call mul_hs
        call clamp_s8
        ld (sd_y),a
        ; curve x and clip at n
        ld a,(sd_n)
        or a
        jr nz,.xs
        ld hl,0
        ld a,NSR
        jr .xd
.xs:    ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; 3n
        ld de,XS-3
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ex de,hl
.xd:    ld (sd_clip),a
        ; cx = 160 + ((x >> 2) + ox - px) * s >> 8
        sra h
        rr l
        sra h
        rr l
        ld de,(sd_ox)
        add hl,de
        ld de,(px)
        or a
        sbc hl,de
        ld a,(sd_s)
        call mul_hs
        ld de,160
        add hl,de
        ex de,hl
        ld hl,(sd_img)
        ld a,(sd_y)
        ld b,a
        ld a,(sd_clip)
        ld c,a
        ; fall through

; ---------------------------------------------------------------------
; blit: HL = image, DE = centre (1/8 cells), B = base sub-row (signed:
; the sprite sits on the rows above it), C = clip (rows >= C are hidden)
blit:
        ld a,(hl)
        ld (bl_w),a
        inc hl
        ld a,(hl)
        inc hl
        ld (bl_src),hl
        ld l,a                  ; L = h
        ; last row + 1 = min(base, clip) (signed base; clip 0..32)
        ld a,b
        bit 7,a
        ret nz                  ; base above the top: nothing shows
        cp c
        jr c,.b1
        ld a,c
.b1:    or a
        ret z
        ld (bl_end),a
        ld a,b
        sub l
        ld (bl_row),a           ; top row (signed)
        ; left column = ((cx + 4) >> 3) - w/2, kept if -w < left < 40
        ex de,hl
        ld de,4
        add hl,de
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,(bl_w)
        srl a
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld a,h
        or a
        jr z,.lp
        inc a
        ret nz                  ; far off to the left
        ld a,l
        cp -60
        ret c
        jr .lok
.lp:    ld a,l
        cp 40
        ret nc
.lok:   ld a,l
        ld (bl_left),a
        ld de,(bl_src)          ; DE = picture data
.row:   ld a,(bl_row)
        or a
        jp m,.skiprow
        ; destination: PK + (row >> 1) * 64; mask by parity
        ld c,0F0h               ; even sub-row: the top half
        srl a
        jr nc,.ev
        ld c,0Fh
.ev:    rrca
        rrca
        ld h,a
        and 0C0h
        ld (bl_dl),a
        ld a,h
        and 3
        add a,high PK
        ld (bl_dh),a
        ld a,(bl_left)
        ld b,a                  ; B = column of the next pixel (signed)
.run:   ld a,(de)
        inc de
        cp 0FFh
        jr z,.nextrow
        add a,b                 ; skip
        ld b,a
        ld a,(de)               ; length
        inc de
        ld (bl_len),a
        ld a,b
        or a
        jp m,.clipl
        cp 40
        jr nc,.skipall
.vis:   ; from column B (0..39): n = min(len, 40 - B) pixels
        ld a,40
        sub b
        ld h,a
        ld a,(bl_len)
        cp h
        jr c,.n1
        ld a,h
.n1:    ld (bl_n),a
        push bc
        ld a,(bl_dl)
        add a,b
        ld l,a
        ld a,(bl_dh)
        ld h,a
        ld a,(bl_n)
        ld b,a
.px:    ld a,(de)
        xor (hl)
        and c
        xor (hl)
        ld (hl),a
        inc l
        inc de
        djnz .px
        pop bc
        ld a,(bl_len)           ; past the rest of the run
        ld h,a
        ld a,(bl_n)
        ld l,a
        ld a,h
        sub l
        add a,e
        ld e,a
        jr nc,.r1
        inc d
.r1:    ld a,b
        add a,h
        ld b,a
        jr .run
.skipall:                       ; the whole run is off the screen
        ld a,(bl_len)
        ld h,a
        add a,e
        ld e,a
        jr nc,.s1
        inc d
.s1:    ld a,b
        add a,h
        ld b,a
        jr .run
.clipl: ; starts left of the screen: drop -B pixels
        neg
        ld h,a
        ld a,(bl_len)
        cp h
        jr c,.skipall           ; (all of it)
        jr z,.skipall
        sub h
        ld (bl_len),a
        ld a,h
        add a,e
        ld e,a
        jr nc,.c1
        inc d
.c1:    ld b,0
        jr .vis
.nextrow:
        ld a,(bl_row)
        inc a
        ld (bl_row),a
        ld b,a
        ld a,(bl_end)
        cp b
        jp nz,.row
        ret
.skiprow:                       ; above the top: skip this row's data
        ld a,(de)
        inc de
        cp 0FFh
        jr z,.nextrow
        ld a,(de)
        inc de
        add a,e
        ld e,a
        jr nc,.skiprow
        inc d
        jr .skiprow
