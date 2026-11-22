; =====================================================================
;  track.asm - build a course's segment arrays from its runs
;  (run = count, curve, slope, objmode; see tools/track.py)
; =====================================================================

; HL = course runs.  Fills TRK_CURV/HGT/OBJ/OX/SPL, sets crs_len.
build_course:
        ld (bc_run),hl
        ld hl,0
        ld (bc_h),hl
        ld (bc_seg),hl
        xor a
        ld (bc_curv),a
        ld (bc_slope),a
        ld a,63
        ld (bc_gap),a
        xor a
        ld (bc_side),a
.run:   ld hl,(bc_run)
        ld a,(hl)
        or a
        jr z,.end
        ld (bc_cnt),a
        inc hl
        ld a,(hl)
        ld (bc_tcurv),a
        inc hl
        ld a,(hl)
        ld (bc_tslope),a
        inc hl
        ld a,(hl)
        ld (bc_mode),a
        inc hl
        ld (bc_run),hl
.seg:   call .one
        ld hl,bc_cnt
        dec (hl)
        jr nz,.seg
        jr .run
.end:   ld hl,(bc_seg)
        ld (crs_len),hl
        xor a                   ; then straight, flat road to the end
        ld (bc_curv),a
        ld (bc_slope),a
        ld (bc_tcurv),a
        ld (bc_tslope),a
        ld (bc_mode),a
.pad:   call .one
        ld hl,(bc_seg)
        ld de,MAXSEG+64
        or a
        sbc hl,de
        jr c,.pad
        ld hl,0
        ld (ghostend),hl
        ld a,(nodet)            ; the last tier ends at the goal
        cp 4
        ret nc
        ; the fork: the last 64 segments split into two roads, apart by
        ; k^2/32 (in 8s of world units, at most 127), and on past the end
        ld hl,(crs_len)
        ld de,-64
        add hl,de
        ld (forkseg),hl
        ld de,TRK_SPL
        add hl,de
        ld bc,0                 ; k
.fk:    push hl
        ld hl,SQL               ; k^2/4 >> 3
        add hl,bc
        ld e,(hl)
        inc h
        inc h
        ld d,(hl)
        ex de,hl
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,h
        or a
        ld a,l
        jr nz,.cap
        cp 128
        jr c,.ok
.cap:   ld a,127
.ok:    pop hl
        ld (hl),a
        ld de,TRK_OBJ-TRK_SPL   ; no scenery in the fork
        add hl,de
        ld (hl),0
        ld de,TRK_SPL-TRK_OBJ
        add hl,de
        inc hl
        inc bc
        ld a,c
        cp 128
        jr nz,.fk
        ; arrows where it starts to split
        ld hl,(forkseg)
        ld de,TRK_OBJ+4
        add hl,de
        ld (hl),O_SIGNL
        ld de,TRK_OX-TRK_OBJ
        add hl,de
        ld (hl),-(ROADW/4+20)
        ld de,TRK_OBJ-TRK_OX+4
        add hl,de
        ld (hl),O_SIGNR
        ld de,TRK_OX-TRK_OBJ
        add hl,de
        ld (hl),ROADW/4+20
        ret

.one:   ld hl,bc_curv          ; ease towards the section's targets
        ld a,(bc_tcurv)
        call .ease
        ld hl,bc_slope
        ld a,(bc_tslope)
        call .ease
        ld hl,(bc_seg)
        ld de,TRK_CURV
        add hl,de
        ld a,(bc_curv)
        ld (hl),a
        ; height
        ld a,(bc_slope)
        ld e,a
        rla
        sbc a,a
        ld d,a
        push hl
        ld hl,(bc_h)
        add hl,de
        ld (bc_h),hl
        sra h
        rr l
        sra h
        rr l
        ld a,l
        pop hl
        ld de,TRK_HGT-TRK_CURV
        add hl,de
        ld (hl),a
        ; objects
        ld de,TRK_OBJ-TRK_HGT
        add hl,de
        ld (hl),0
        ld de,TRK_SPL-TRK_OBJ
        add hl,de
        ld (hl),0
        ld de,TRK_OBJ-TRK_SPL
        add hl,de
        ld a,(bc_gap)
        inc a
        jr z,.g
        ld (bc_gap),a
.g:     ld a,(bc_mode)
        and 0Fh
        jr z,.nx
        ld a,(bc_seg)
        and 3
        jr nz,.nx
        ld a,(bc_mode)          ; gap since the last >= 4p?
        and 0Fh
        add a,a
        add a,a
        ld b,a
        ld a,(bc_gap)
        cp b
        jr c,.nx
        xor a
        ld (bc_gap),a
        call place_object
.nx:    ld hl,(bc_seg)
        inc hl
        ld (bc_seg),hl
        ret

; (HL) one step towards A (signed)
.ease:  sub (hl)
        ret z
        jp pe,.ov               ; (overflow: the sign is flipped)
        jp m,.dn
.up:    inc (hl)
        ret
.ov:    jp m,.up
.dn:    dec (hl)
        ret

; HL = TRK_OBJ entry: choose an object and its side from bc_mode
place_object:
        ld a,(bc_mode)
        ld c,a
        and 30h
        cp 30h
        jr nz,.one
        ld a,(bc_side)          ; both sides: take turns
        xor 1
        ld (bc_side),a
        jr .side
.one:   and 10h                 ; left only?
        ld a,1
        jr nz,.side
        xor a
.side:  ld b,a                  ; B = 1 left, 0 right
        bit 7,c                 ; a bend sign: on the outside
        jr z,.nsg
        ld b,1                  ; right bend: sign on the left
        ld e,O_SIGNR
        bit 6,c
        jr nz,.sg
        ld b,0
        ld e,O_SIGNL
        jr .sg
.nsg:   ld a,(th_obja)
        bit 6,c
        jr z,.ta
        ld a,(th_objb)
.ta:    ld e,a
.sg:    ld (hl),e
        ld de,TRK_OX-TRK_OBJ
        add hl,de
        call rand8              ; distance from the road edge
        and 15
        add a,ROADW/4+14
        bit 0,b
        jr z,.r
        neg
.r:     ld (hl),a
        ld de,TRK_OBJ-TRK_OX
        add hl,de
        ret
