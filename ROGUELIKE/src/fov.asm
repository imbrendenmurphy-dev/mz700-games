; =====================================================================
;  fov.asm - what the player sees, and the light that falls on it
;
;  Rays (tools/build.py, RAYS_*) go from a cell to every cell on the
;  edge of a square of radius r, as Bresenham lines.  A ray is 3 bytes:
;  its octant (major and minor map steps) and a 16-bit mask, one bit per
;  step, set where the minor coordinate moves.  The distance along a ray
;  is approximated as major + minor/2, tracked doubled in C.
;
;  VISM (one byte per map cell): 0 unseen this turn, else distance + 1.
;  SLIGHT: the static light of each cell (braziers, lava, crystals ...)
;  as level (0-7) | hue << 4, rebuilt when a zone is entered or a light
;  changes.  The map byte's bit 7 marks opaque cells.
; =====================================================================

; set the ray loop's map steps for octant A (0-7); code at IY
; (keeps BC, DE, HL; IY = address of the "ld de,nn" pair)
set_octant:
        push hl
        add a,a
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,OCTT
        add hl,de
        pop de
        ld a,(hl)
        ld (iy+1),a
        inc hl
        ld a,(hl)
        ld (iy+2),a
        inc hl
        ld a,(hl)
        ld (iy+OCT_MNR+1),a
        inc hl
        ld a,(hl)
        ld (iy+OCT_MNR+2),a
        pop hl
        ret

; ---------------------------------------------------------------------
; fov: fill VISM from the player's cell (radius 16)
; ---------------------------------------------------------------------
fov:
        call mark_all
        ld hl,VISM
        ld b,8
.clr:   push bc
        ld (hl),0
        ld d,h
        ld e,l
        inc de
        ld bc,255
        ldir
        inc hl
        call poll
        pop bc
        djnz .clr
        ld hl,(pmap)
        ld a,h
        or high VISM
        ld h,a
        ld (hl),1                   ; the player's own cell
        ld hl,RAYS16
        ld b,RAYS16_N
.ray:   push bc
        ld a,(hl)
        inc hl
        ld iy,fov.maj
        call set_octant
        ld a,(hl)
        inc hl
        ld ixh,a
        ld a,(hl)
        inc hl
        ld ixl,a
        push hl
        ld hl,(pmap)
        ld bc,16*256+0              ; B = steps, C = distance x 2
.maj: ld de,0
        add hl,de
        inc c
        inc c
        add ix,ix
        jr nc,.nm
.mnr: ld de,0
        add hl,de
        inc c
.nm:    ld a,c
        cp 33
        jr nc,.end
        ld e,(hl)
        ld a,h
        or high VISM
        ld h,a
        ld a,c
        inc a
        rra
        inc a
        ld (hl),a
        ld a,h
        and 07h
        ld h,a
        bit 7,e
        jr nz,.end
        djnz fov.maj
.end:   pop hl
        pop bc
        ld a,b
        and 15
        call z,poll
        djnz .ray
        ret
OCT_MNR equ fov.mnr-fov.maj

; ---------------------------------------------------------------------
; static light
; ---------------------------------------------------------------------
; relight: clear SLIGHT and cast every light in the map
relight:
        call mark_all
        ld hl,SLIGHT
        ld b,8
.clr:   push bc
        ld (hl),0
        ld d,h
        ld e,l
        inc de
        ld bc,255
        ldir
        inc hl
        call poll
        pop bc
        djnz .clr
        ld hl,MAP
.scan:  ld a,(hl)
        and 3Fh
        push hl
        add a,low TLIGHT
        ld l,a
        ld h,high TLIGHT
        ld a,(hl)                   ; S | hue << 4
        pop hl
        or a
        call nz,cast_light
        inc hl
        ld a,l
        or a
        call z,poll
        ld a,h
        cp high SLIGHT
        jr c,.scan
        ; lights that are not tiles: the zone's lit beam (puzzle.asm)
        call beam_relight
; dark-glass doors stand open while steady light of level 5+ falls on
; them; if one changed, light again (it now passes, or is stopped)
        xor a
        ld (ld_chg),a
        ld hl,MAP
.ld:    ld a,(hl)
        and 3Fh
        cp T_LDOOR
        jr z,.lg
        cp T_LDOPEN
        jr nz,.ln
.lg:    ld c,a
        set 3,h
        ld a,(hl)                   ; its static light
        res 3,h
        and 7
        cp 5
        ld a,T_LDOPEN
        jr nc,.lo
        ld a,T_LDOOR
.lo:    cp c
        jr z,.ln
        call set_tile
        ld a,1
        ld (ld_chg),a
        ld (need_fov),a
.ln:    inc hl
        ld a,h
        cp high SLIGHT
        jr c,.ld
        ld a,(ld_chg)
        or a
        jp nz,relight
        ret

; cast light A (strength | hue << 4) from map cell HL (keeps HL)
cast_light:
        push hl
        ld c,a
        and 70h
        ld (cl_put.hue+1),a
        ld a,c
        and 0Fh
        ld (cast_light.s+1),a
        inc a                       ; level at the origin = S+1 (max 7)
        cp 8
        jr c,$+4
        ld a,7
        call cl_put
        ; the ray set for radius S
        ld a,(cast_light.s+1)
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,RAYSETS
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)                   ; DE = ray set (count, rays)
        pop hl
        ld (cl_org),hl
        ex de,hl
        ld b,(hl)
        inc hl
.ray:   push bc
        ld a,(hl)
        inc hl
        ld iy,cast_light.maj
        call set_octant
        ld a,(hl)
        inc hl
        ld ixh,a
        ld a,(hl)
        inc hl
        ld ixl,a
        push hl
        ld hl,(cl_org)
        ld a,(cast_light.s+1)       ; a light of strength S reaches 2S
        add a,a
        cp 17
        jr c,$+4
        ld a,16
        ld b,a
        ld c,0
.maj: ld de,0
        add hl,de
        inc c
        inc c
        add ix,ix
        jr nc,.nm
.mnr: ld de,0
        add hl,de
        inc c
.nm:    ld a,c
        inc a
        srl a                       ; distance
        srl a                       ; / 2: light falls off slowly
        ld e,a
.s:   ld a,0
        inc a
        sub e                       ; level = S + 1 - d/2
        jr c,.end
        jr z,.end
        cp 8
        jr c,$+4
        ld a,7
        ld e,(hl)                   ; tile (opaque bit)
        call cl_put
        bit 7,e
        jr nz,.end
        djnz cast_light.maj
.end:   pop hl
        pop bc
        djnz .ray
        pop hl
        ret

; SLIGHT[HL] = max(SLIGHT[HL], level A with the light's hue).  Keeps HL, E.
cl_put:
        set 3,h
        ld d,a
        ld a,(hl)
        and 7
        cp d
        jr nc,.keep
        ld a,d
.hue: or 0
        ld (hl),a
.keep:  res 3,h
        ret

; ---------------------------------------------------------------------
; dynamic lights, stamped into LVL each frame (no line of sight, only
; where the player can see).  B = view x, C = view y, A = S | hue << 4
; ---------------------------------------------------------------------
stamp_light:
        push af
        and 0Fh
        ld l,a
        push bc
        ld a,b
        sub l
        ld d,a
        ld a,b
        add a,l
        ld b,d
        ld d,a
        ld a,c
        add a,l
        ld e,a
        ld a,c
        sub l
        ld c,a
        call mark_box
        pop bc
        pop af
        ld d,a
        and 70h
        or 08h
        ld (stamp_light.hue+1),a
        ld a,d
        and 0Fh
        ld (stamp_light.s+1),a
        ld e,a                      ; r = S
        ; dy from -r to r
        ld a,c
        sub e
        ld (sl_y),a
        ld a,e
        add a,a
        inc a
        ld (sl_n),a                 ; rows to do
.row:   ld a,(sl_y)
        cp VIEWH
        jr nc,.nextrow              ; (also negative)
        ; dy = |y - c|
        sub c
        jr nc,$+4
        neg
        ld (sl_dy),a
        ld a,(sl_y)                 ; the row's LVL address
        call mul40
        push de
        ld de,LVL
        add hl,de
        pop de
        ld (sl_base),hl
        ld a,b
        sub e
        ld (sl_x),a
        ld a,e
        add a,a
        inc a
        ld d,a                      ; columns to do
.col:   ld a,(sl_x)
        cp VIEWW
        jr nc,.nextcol
        push bc
        push de
        sub b
        jr nc,$+4
        neg                         ; |dx|
        ld e,a
        ld a,(sl_dy)
        ; distance ~ max + min/2
        cp e
        jr nc,.ge
        ld d,a
        ld a,e
        ld e,d
.ge:    srl e
        add a,e                     ; A = distance
        ld e,a
.s:   ld a,0
        inc a
        sub e
        jr c,.skip
        jr z,.skip
        cp 8
        jr c,$+4
        ld a,7
        ld e,a                      ; level
        ld hl,(sl_base)
        ld a,(sl_x)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ; only where the player sees (the light pass left a non-zero
        ; marker bit 3 there)
        ld a,(hl)
        bit 3,a
        jr z,.skip
        and 7
        cp e
        jr nc,.skip
        ld a,e
.hue: or 08h
        ld (hl),a
.skip:  pop de
        pop bc
.nextcol:
        ld hl,sl_x
        inc (hl)
        dec d
        jr nz,.col
.nextrow:
        ld hl,sl_y
        inc (hl)
        ld hl,sl_n
        dec (hl)
        jr nz,.row
        ret

; HL = A * 40 (A < 32).  Keeps BC, DE.
mul40:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        pop de
        ret

; HL = map address of (B = x, C = y).  Keeps BC, DE.
map_addr:
        ld a,c
        rrca
        rrca
        ld h,a
        and 0C0h
        or b
        ld l,a
        ld a,h
        and 07h
        ld h,a
        ret

; B = x, C = y of map address HL.  Keeps DE, HL.
map_xy:
        ld a,l
        and 3Fh
        ld b,a
        ld a,l
        rlca
        rlca
        and 3
        ld c,a
        ld a,h
        add a,a
        add a,a
        or c
        ld c,a
        ret
