; =====================================================================
;  gen.asm - island generator (matches tools/model.py step for step)
;
;  9 x 9 random grid -> bilinear 33 x 33 corners + noise -> stretched,
;  sunk at the edges, cut into levels 0..9 -> one plateau filter pass.
;  Then the 128 x 128 sub-cell map, tile flags, objects and the survey
;  of what the Lantern can see.
; =====================================================================

gen_island:
        ld a,(island)
        ld l,a
        ld h,0
        ld de,2F1Bh
        call mul16u
        ld de,51C7h
        add hl,de
        ld a,h
        or l
        jr nz,.s
        inc l
.s:     ld (rseed),hl
        ld hl,GRID
        ld b,81
.g:     call rng
        ld (hl),a
        inc hl
        djnz .g
        ; ---- smooth noise
        ld hl,HRAW
        ld (gp),hl
        xor a
        ld (gy),a
.yl:    xor a
        ld (gx),a
.xl:    call corner_noise
        ld hl,(gp)
        ld (hl),a
        inc hl
        ld (gp),hl
        ld hl,gx
        inc (hl)
        ld a,(hl)
        cp 33
        jr c,.xl
        call poll
        ld hl,gy
        inc (hl)
        ld a,(hl)
        cp 33
        jr c,.yl
        call stretch
        call plateaus
        call gen_fine
        call place_objects
        jp survey

; A = smoothed value of corner (gx, gy)
corner_noise:
        ld a,(gy)
        and 3
        ld (wy1),a
        neg
        add a,4
        ld (wy0),a
        ld a,(gx)
        and 3
        ld (wx1),a
        neg
        add a,4
        ld (wx0),a
        ld a,(gy)
        rrca
        rrca
        and 3Fh
        ld c,9
        call mul8u                  ; HL = cgy * 9
        ld a,(gx)
        rrca
        rrca
        and 3Fh
        add a,l
        ld l,a
        ld de,GRID
        add hl,de
        ld (gptr),hl
        ld hl,0
        ld (acc),hl
        ld a,(wx0)                  ; g00 * (4-fx)(4-fy)
        ld c,a
        ld a,(wy0)
        ld de,0
        call .term
        ld a,(wx1)                  ; g(x+1) * fx(4-fy)
        ld c,a
        ld a,(wy0)
        ld de,1
        call .term
        ld a,(wx0)                  ; g(y+1) * (4-fx)fy
        ld c,a
        ld a,(wy1)
        ld de,9
        call .term
        ld a,(wx1)                  ; g(x+1,y+1) * fx fy
        ld c,a
        ld a,(wy1)
        ld de,10
        call .term
        ld hl,(acc)                 ; >> 4
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        call rng
        and 15
        add a,b
        ret nc
        ld a,255
        ret
; acc += grid[gptr + DE] * (A * C)
.term:  call mul8u
        ld b,l
        ld hl,(gptr)
        add hl,de
        ld a,(hl)
; (acc) += A * B
macc:   push hl
        push de
        ld hl,(acc)
        ld e,a
        ld d,0
        inc b
        jr .t
.l:     add hl,de
.t:     djnz .l
        ld (acc),hl
        pop de
        pop hl
        ret

; stretch to 0..255, sink the rim, cut into levels -> CORN
stretch:
        ld hl,HRAW
        ld bc,33*33
        ld de,0FF00h                ; D = lo, E = hi
.m:     ld a,(hl)
        cp d
        jr nc,$+3
        ld d,a
        cp e
        jr c,$+3
        ld e,a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.m
        ld a,d
        ld (lo),a
        ld a,e
        sub d
        jr nz,.sp
        inc a
.sp:    ld (span),a
        ld hl,HRAW
        ld (gp),hl
        ld hl,CORN
        ld (gq),hl
        xor a
        ld (gy),a
.y:     xor a
        ld (gx),a
.x:     ld hl,(gp)
        ld a,(hl)
        inc hl
        ld (gp),hl
        ld hl,lo
        sub (hl)                    ; h - lo
        ld h,a
        ld l,0
        ld e,a
        ld d,0
        or a
        sbc hl,de                   ; * 255
        ld a,(span)
        ld c,a
        call div16u8
        ld b,l                      ; v
        ld a,(gx)
        sub 16
        jr nc,$+4
        neg
        ld c,a
        ld a,(gy)
        sub 16
        jr nc,$+4
        neg
        cp c
        jr nc,$+3
        ld a,c                      ; d = max(|x-16|, |y-16|)
        sub 10
        jr c,.nf
        inc a                       ; d - 9
        ld e,a
        add a,a
        add a,a
        ld d,a                      ; 4(d-9)
        add a,a
        add a,a
        add a,a                     ; 32(d-9)
        add a,d                     ; 36(d-9)
        ld c,a
        ld a,b
        sub c
        jr nc,$+3
        xor a
        ld b,a
.nf:    ld a,b                      ; level = v / 28
        ld c,0
.dv:    sub 28
        jr c,.dd
        inc c
        jr .dv
.dd:    ld a,(gx)                   ; rim corners are sea
        or a
        jr z,.bz
        cp 32
        jr z,.bz
        ld a,(gy)
        or a
        jr z,.bz
        cp 32
        jr nz,.st
.bz:    ld c,0
.st:    ld hl,(gq)
        ld (hl),c
        inc hl
        ld (gq),hl
        ld hl,gx
        inc (hl)
        ld a,(hl)
        cp 33
        jr c,.x
        call poll
        ld hl,gy
        inc (hl)
        ld a,(hl)
        cp 33
        jp c,.y
        ret

; one pass: each inner corner takes the commonest level around it -> CORN2
plateaus:
        ld hl,CORN
        ld de,CORN2
        ld bc,33*33
        ldir
        ld a,1
        ld (gy),a
.y:     ld a,1
        ld (gx),a
.x:     ld hl,cnt
        ld b,16
        xor a
.c:     ld (hl),a
        inc hl
        djnz .c
        ld a,(gy)
        ld c,33
        call mul8u
        ld a,(gx)
        ld e,a
        ld d,0
        add hl,de
        ld (gc),hl                  ; offset of the corner
        ld de,CORN-34
        add hl,de                   ; top-left neighbour
        ld c,3
.r:     ld b,3
.cc:    ld e,(hl)
        ld d,0
        push hl
        ld hl,cnt
        add hl,de
        inc (hl)
        pop hl
        inc hl
        djnz .cc
        ld de,30
        add hl,de
        dec c
        jr nz,.r
        ld hl,cnt                   ; first (lowest) level with the top count
        ld b,0
        ld c,(hl)
        ld e,1
.bl:    inc hl
        ld a,(hl)
        cp c
        jr z,.nb
        jr c,.nb
        ld c,a
        ld b,e
.nb:    inc e
        ld a,e
        cp 16
        jr c,.bl
        ld hl,(gc)
        ld de,CORN2
        add hl,de
        ld (hl),b
        ld hl,gx
        inc (hl)
        ld a,(hl)
        cp 32
        jr c,.x
        call poll
        ld hl,gy
        inc (hl)
        ld a,(hl)
        cp 32
        jr c,.y
        ret

; A signed -> HL
sext:   ld l,a
        rla
        sbc a,a
        ld h,a
        ret

; the 128 x 128 sub-cell map and the flat flags
gen_fine:
        ld hl,CORN2
        ld (gp),hl
        ld hl,FMAP
        ld (fp),hl
        ld hl,TILEF
        ld (tp),hl
        xor a
        ld (gy),a
.ty:    xor a
        ld (gx),a
.tx:    ld hl,(gp)
        ld a,(hl)
        ld (h00),a
        inc hl
        ld a,(hl)
        ld (h10),a
        ld de,32
        add hl,de
        ld a,(hl)
        ld (h01),a
        inc hl
        ld a,(hl)
        ld (h11),a
        ld a,(h00)
        ld b,a
        ld a,(h10)
        cp b
        jr nz,.slope
        ld a,(h01)
        cp b
        jr nz,.slope
        ld a,(h11)
        cp b
        jr nz,.slope
        ld hl,(tp)                  ; flat tile
        ld (hl),10h
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld c,a                      ; f << 2 = level * 16, shade 0
        ld hl,(fp)
        ld de,125
        ld b,4
.fr:    ld (hl),c
        inc l
        ld (hl),c
        inc l
        ld (hl),c
        inc l
        ld (hl),c
        add hl,de
        djnz .fr
        ld hl,(fp)                  ; the stud
        ld de,129
        add hl,de
        ld a,c
        or 1
        ld (hl),a
        jp .next
.slope: ld hl,(tp)
        ld (hl),0
        ld a,(h11)                  ; lit when it falls towards +x/+y
        cp b
        ld a,2
        jr c,.lit
        jr z,.lit
        inc a
.lit:   ld (shd),a
        ld a,(h01)                  ; left edge: L = 8 h00 + (h01-h00) fy
        sub b
        call sext
        push hl
        add hl,hl
        ld (dL),hl
        pop de
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld (Lc),hl
        ld a,(h10)                  ; right edge: R = 8 h10 + (h11-h10) fy
        ld c,a
        ld a,(h11)
        sub c
        call sext
        push hl
        add hl,hl
        ld (dR),hl
        pop de
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld (Rc),hl
        ld hl,(fp)
        ld (rp),hl
        ld b,4
.sy:    push bc
        ld hl,(Rc)                  ; v = 8L + (R-L) fx
        ld de,(Lc)
        or a
        sbc hl,de
        push hl
        add hl,hl
        ld (dv),hl
        pop de
        ld hl,(Lc)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld (vv),hl
        ld hl,(rp)
        ld b,4
.sx:    push hl
        ld hl,(vv)
        ld de,8
        add hl,de
        srl h
        rr l
        srl h
        rr l
        ld a,l
        and 0FCh                    ; ((v + 8) >> 4) << 2
        ld c,a
        ld a,(shd)
        or c
        ld hl,(vv)
        ld de,(dv)
        add hl,de
        ld (vv),hl
        pop hl
        ld (hl),a
        inc l
        djnz .sx
        ld hl,(rp)
        ld de,128
        add hl,de
        ld (rp),hl
        ld hl,(Lc)
        ld de,(dL)
        add hl,de
        ld (Lc),hl
        ld hl,(Rc)
        ld de,(dR)
        add hl,de
        ld (Rc),hl
        pop bc
        djnz .sy
.next:  ld hl,(tp)
        inc hl
        ld (tp),hl
        ld hl,(fp)
        inc hl
        inc hl
        inc hl
        inc hl
        ld (fp),hl
        ld hl,(gp)
        inc hl
        ld (gp),hl
        ld hl,gx
        inc (hl)
        ld a,(hl)
        cp 32
        jp c,.tx
        ld hl,(gp)
        inc hl
        ld (gp),hl
        ld hl,(fp)
        ld de,384
        add hl,de
        ld (fp),hl
        call poll
        ld hl,gy
        inc (hl)
        ld a,(hl)
        cp 32
        jp c,.ty
        ret

; ---------------------------------------------------------------------
; tile helpers (HL = tile index 0..1023, kept)
; ---------------------------------------------------------------------
; HL -> FMAP address of the tile's centre sub-cell
tile_centre:
        push de
        ld a,l
        and 1Fh
        add a,a
        add a,a
        add a,2
        ld e,a
        ld a,l
        rlca
        rlca
        rlca
        and 7
        ld d,a
        ld a,h
        add a,a
        add a,a
        add a,a
        or d                        ; ty
        add a,a
        add a,high FMAP+1
        ld h,a
        ld l,e
        pop de
        ret

; A = level of a flat tile, 0 for slopes and sea
tile_flat_level:
        push hl
        push de
        ld de,TILEF
        add hl,de
        bit 4,(hl)
        pop de
        pop hl
        ld a,0
        ret z
        push hl
        call tile_centre
        ld a,(hl)
        pop hl
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        ret

; A = f (half sub-cells) at the tile centre
tile_f:
        push hl
        call tile_centre
        ld a,(hl)
        pop hl
        rrca
        rrca
        and 3Fh
        ret

; D = ty, E = tx
tile_xy:
        ld a,l
        and 1Fh
        ld e,a
        ld a,l
        rlca
        rlca
        rlca
        and 7
        ld d,a
        ld a,h
        add a,a
        add a,a
        add a,a
        or d
        ld d,a
        ret

; HL = tile index of (E = tx, D = ty)
tile_of:
        ld a,d
        rrca
        rrca
        rrca
        ld h,a
        and 0E0h
        or e
        ld l,a
        ld a,h
        and 3
        ld h,a
        ret

; HL = OBJ address of tile HL
obj_addr:                           ; (keeps A: H is 0..3)
        set 7,h
        set 6,h
        ret

; HL = TILEF address of tile HL
tf_addr:
        set 7,h
        set 6,h
        set 2,h
        ret

; ---------------------------------------------------------------------
; objects
; ---------------------------------------------------------------------
place_objects:
        ld hl,OBJ
        ld de,OBJ+1
        ld bc,1023
        ld (hl),0
        ldir
        ; the Lantern: the highest flat tile
        xor a
        ld (bestv),a
        ld hl,0
        ld (lant_t),hl
.lt:    call tile_flat_level
        ld c,a
        ld a,(bestv)
        cp c
        jr nc,.ln
        ld a,c
        ld (bestv),a
        ld (lant_t),hl
.ln:    inc hl
        ld a,h
        cp 4
        jr c,.lt
        ; the player: the lowest flat tile, southmost, away from the rim
        ld a,255
        ld (bestv),a
        xor a
        ld (bestty),a
        ld hl,(lant_t)
        ld (ptile),hl
        ld d,4
.py:    ld e,4
.px:    call tile_of
        call tile_flat_level
        or a
        jr z,.pn
        push de
        ld de,(lant_t)
        or a
        sbc hl,de
        add hl,de
        pop de
        jr z,.pn
        ld c,a
        ld a,(bestv)
        cp c
        jr c,.pn                    ; higher than the best
        jr nz,.take
        ld a,(bestty)               ; same level: further south wins
        cp d
        jr nc,.pn
.take:  ld a,c
        ld (bestv),a
        ld a,d
        ld (bestty),a
        ld (ptile),hl
.pn:    inc e
        ld a,e
        cp 28
        jr c,.px
        inc d
        ld a,d
        cp 28
        jr c,.py
        ; the Lantern's pedestal grows on later islands
        ld a,(island)
        dec a
        ld c,0
.pd:    sub 3
        jr c,.pe
        inc c
        jr .pd
.pe:    ld a,c
        cp 3
        jr c,$+4
        ld a,3
        ld (lant_cairns),a
        add a,a
        add a,a
        add a,a
        add a,a
        or O_LANTERN
        ld hl,(lant_t)
        call obj_addr
        ld (hl),a
        ; shards: 14 - island (at least 6)
        ld a,(island)
        cp 8
        jr c,$+4
        ld a,8
        neg
        add a,14
        ld b,a
.sh:    ld a,O_SHARD
        call place_random
        djnz .sh
        ld a,O_SHELL
        call place_random
        ld a,O_SHELL
        call place_random
        ld a,O_SHARD|10h            ; a shard on a cairn
        call place_random
        ; wisps from island 3: (island-1)/2, at most 3
        ld a,(island)
        dec a
        srl a
        cp 4
        jr c,$+4
        ld a,3
        ld (nwisps),a
        or a
        ret z
        ld b,a
.wi:    ld a,O_WISP
        call place_random
        djnz .wi
        ret

; put object byte A on a random empty flat tile (not the player's)
place_random:
        push bc
        ld (pobj),a
        ld b,0
.t:     call rng
        and 1Fh
        ld e,a
        call rng
        and 1Fh
        ld d,a
        call tile_of
        call tile_flat_level
        or a
        jr z,.no
        ld de,(ptile)
        or a
        sbc hl,de
        add hl,de
        jr z,.no
        call obj_addr
        ld a,(hl)
        or a
        jr nz,.no
        ld a,(pobj)
        ld (hl),a
        pop bc
        ret
.no:    djnz .t
        pop bc
        ret

; ---------------------------------------------------------------------
; survey: which tiles can the Lantern's lamp see, and in which sector
; ---------------------------------------------------------------------
survey:
        ld hl,(lant_t)
        call tile_xy
        ld a,e
        ld (lantx),a
        ld a,d
        ld (lanty),a
        call tile_f
        ld b,a
        ld a,(lant_cairns)
        add a,a
        add a,a
        add a,b
        add a,LAMP_F
        ld (lamph),a
        ld hl,0
        ld (st),hl
.t:     call poll
        ld hl,(st)
        call tile_centre
        ld a,(hl)
        cp 4
        jp c,.next                  ; sea
        rrca
        rrca
        and 3Fh
        add a,EYE
        ld (targh),a
        ld hl,(st)
        call tile_xy
        ld a,(lantx)
        ld c,a
        ld a,e
        sub c
        add a,a
        add a,a
        ld (sdx),a
        ld a,(lanty)
        ld c,a
        ld a,d
        sub c
        add a,a
        add a,a
        ld (sdy),a
        call sector
        ld c,a
        ld hl,(st)
        call tf_addr
        ld a,(hl)
        and 0F0h
        or c
        ld (hl),a
        ; n = max(|dx|, |dy|)
        ld a,(sdx)
        call absa
        ld c,a
        ld a,(sdy)
        call absa
        cp c
        jr nc,$+3
        ld a,c
        cp 4
        jp c,.sees                  ; own or next tile
        ld (nsteps),a
        ld c,a
        ld a,(sdx)
        call .slope
        ld (lsx),hl
        ld a,(sdy)
        call .slope
        ld (lsy),hl
        ld a,(lamph)
        ld b,a
        ld a,(targh)
        sub b
        call .slope
        ld (lsh),hl
        ld a,(nsteps)
        srl a
        dec a
        ld (nsteps),a
        ld a,(lamph)
        ld (lhv+1),a
        xor a
        ld (lhv),a
        ld a,(lantx)
        add a,a
        add a,a
        add a,2
        ld h,a
        ld l,0
        ld a,(lanty)
        add a,a
        add a,a
        add a,2
        ld d,a
        ld e,0
.lp:    ld bc,(lsx)
        add hl,bc
        ex de,hl
        ld bc,(lsy)
        add hl,bc
        ex de,hl
        push hl
        ld hl,(lhv)
        ld bc,(lsh)
        add hl,bc
        ld (lhv),hl
        ld a,h
        pop hl
        ld (lhh),a
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
        rrca
        rrca
        and 3Fh
        ld b,a
        ld a,(lhh)
        cp b
        jr c,.next                  ; ground above the line: blocked
        ld a,(nsteps)
        dec a
        ld (nsteps),a
        jr nz,.lp
.sees:  ld hl,(st)
        call tf_addr
        set 3,(hl)
.next:  ld hl,(st)
        inc hl
        ld (st),hl
        ld a,h
        cp 4
        jp c,.t
        ret
; HL = A * 256 / C, signed A
.slope: ld b,a                      ; (2-sub-cell steps)
        call absa
        add a,a
        ld h,a
        ld l,0
        push bc
        call div16u8
        pop bc
        bit 7,b
        ret z
        jp neg_hl

absa:   or a
        ret p
        neg
        ret

; A = sector 0..7 (N, NE, E, SE, S, SW, W, NW) of (sdx, sdy)
sector:
        ld a,(sdx)
        call absa
        ld c,a
        ld a,(sdy)
        call absa
        ld b,a
        ld l,c                      ; 5 ax < 2 ay: north / south
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        push hl
        ld l,b
        ld h,0
        add hl,hl
        ex de,hl
        pop hl
        or a
        sbc hl,de
        jr nc,.nv
        ld a,(sdy)
        bit 7,a
        ld a,0
        ret nz
        ld a,4
        ret
.nv:    ld l,b                      ; 5 ay < 2 ax: east / west
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        push hl
        ld l,c
        ld h,0
        add hl,hl
        ex de,hl
        pop hl
        or a
        sbc hl,de
        jr nc,.dg
        ld a,(sdx)
        bit 7,a
        ld a,2
        ret z
        ld a,6
        ret
.dg:    ld a,(sdx)
        bit 7,a
        jr nz,.w
        ld a,(sdy)
        bit 7,a
        ld a,1
        ret nz
        ld a,3
        ret
.w:     ld a,(sdy)
        bit 7,a
        ld a,7
        ret nz
        ld a,5
        ret
