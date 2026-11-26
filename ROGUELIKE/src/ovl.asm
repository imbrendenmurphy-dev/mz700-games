; =====================================================================
;  ovl.asm - each frame's moving lights and overlays (part of render)
; =====================================================================

; map (B, C) -> view (B, C), unclipped (signed)
to_view_signed:
        ld a,(vx)
        neg
        add a,b
        ld b,a
        ld a,(vy)
        neg
        add a,c
        ld c,a
        ret

; map (B, C) -> view (B, C); Z if outside the view.  Keeps DE, HL.
to_view:
        ld a,(vx)
        neg
        add a,b
        cp VIEWW
        jr nc,.no
        ld b,a
        ld a,(vy)
        neg
        add a,c
        cp VIEWH
        jr nc,.no
        ld c,a
        or 1
        ret
.no:    xor a
        ret

; stamp light A at map cell (B, C) when it is in view
light_at:
        or a
        ret z
        push af
        call to_view
        jr z,.x
        pop af
        jp stamp_light
.x:     pop af
        ret

dyn_lights:
        ; creatures that glow
        ld ix,(monbase)
        ld b,NMON
.m:     push bc
        ld a,(ix+MO_TYPE)
        or a
        jr z,.mn
        call mon_type
        ld a,(iy+MT_LIGHT)
        or a
        jr z,.mn
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call light_at
.mn:    ld de,MONSZ
        add ix,de
        pop bc
        djnz .m
        ; the player's blade
        ld a,(weapon)
        add a,a
        add a,a
        add a,3
        ld e,a
        ld d,0
        ld hl,WEAPONS
        add hl,de
        ld a,(hl)
        ld hl,px
        ld b,(hl)
        inc hl
        ld c,(hl)
        call light_at
        ; flares
        ld hl,flares
        ld d,NFLARE
.f:     ld a,(hl)
        or a
        jr z,.fn
        push hl
        push de
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld a,6+(6<<4)               ; S 6, SUN
        call light_at
        pop de
        pop hl
.fn:    inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        ; a bolt in flight
        ld a,(bolt_on)
        or a
        jr z,.nb
        ld a,(bolt_x)
        ld b,a
        ld a,(bolt_y)
        ld c,a
        ld a,(bolt_light)
        call light_at
.nb:    ; a flash
        ld a,(flash_t)
        or a
        ret z
        dec a
        ld (flash_t),a
        ld a,(flash_x)
        ld b,a
        ld a,(flash_y)
        ld c,a
        ld a,(flash_l)
        jp light_at

; a flash of light A at (B, C) for E frames
flash:
        ld (flash_l),a
        ld a,b
        ld (flash_x),a
        ld a,c
        ld (flash_y),a
        ld a,e
        ld (flash_t),a
        ret

clear_effects:
        xor a
        ld (flash_t),a
        ld (bolt_on),a
        ld (banner_t),a
        ld (beam_n),a
        ld hl,flares
        ld b,NFLARE*3
.c:     ld (hl),0
        inc hl
        djnz .c
        jp parts_clear

; ---------------------------------------------------------------------
overlays:
        call beam_draw
        ; items (seen in light)
        ld hl,ITEMS
        ld b,NITEM
.i:     push bc
        push hl
        ld a,(hl)
        or a
        jr z,.in
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        call itype
        ld a,(hl)
        ld (ov_g),a
        inc hl
        ld a,(hl)
        ld (ov_a),a
        call view_index
        jr z,.in
        ld a,(hl)
        and 7
        cp 2
        jr c,.in
        ld a,(ov_a)
        call ov_put
.in:    pop hl
        ld de,ITEMSZ
        add hl,de
        pop bc
        djnz .i
        ; creatures
        ld ix,(monbase)
        ld b,NMON
.m:     push bc
        ld a,(ix+MO_TYPE)
        or a
        jp z,.mn
        call mon_type
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call view_index
        jp z,.mn
        ld a,(hl)
        bit 3,a
        jp z,.mn
        and 7
        jp z,.mn
        ld e,a                      ; level
        bit 4,(iy+MT_FL)            ; shades need bright light
        jr z,.ns
        cp 4
        jr c,.mn
.ns:    ld a,(iy+MT_G)
        ld (ov_g),a
        ld a,(iy+MT_A)
        bit 1,(ix+MO_FL)
        jr z,.nd
        ld a,(iy+MT_DG)
        ld (ov_g),a
        ld a,(iy+MT_DA)
.nd:    ld d,a
        ld a,e
        cp 3
        jr nc,.lit
        ld a,d
        and 80h
        or BLUE<<4
        ld d,a
.lit:   ld a,(ix+MO_ST)             ; frozen: ice blue
        or a
        jr z,.nf
        ld a,d
        and 80h
        or CYAN<<4
        ld d,a
.nf:    ld a,(ix+MO_AUX)            ; hit flash
        or a
        jr z,.nh
        dec (ix+MO_AUX)
        ld a,(framecnt)
        and 1
        ld a,d
        and 80h
        jr z,.fr
        or WHITE<<4
        jr .fh
.fr:    or RED<<4
.fh:    ld d,a
.nh:    ld a,d
        call ov_put
.mn:    ld de,MONSZ
        add ix,de
        pop bc
        dec b
        jp nz,.m
        ; the player
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call view_index
        jr z,.np
        ld a,0CAh
        ld (ov_g),a
        ld a,(pflash)
        and 2
        ld a,WHITE<<4
        jr z,$+4
        ld a,RED<<4
        call ov_put
.np:    ; a bolt
        ld a,(bolt_on)
        or a
        jr z,.nb
        ld a,(bolt_x)
        ld b,a
        ld a,(bolt_y)
        ld c,a
        call view_index
        jr z,.nb
        ld a,(bolt_g)
        ld (ov_g),a
        ld a,(bolt_a)
        call ov_put
.nb:    call parts_draw
        jp banner_draw

; overlay glyph ov_g with attr A at LVL address HL.  Keeps BC, DE.
ov_put:
        push af
        call mark_ov
        pop af
        set 2,h
        ld (hl),a
        ld a,h
        xor 0Ch
        ld h,a
        ld a,(ov_g)
        ld (hl),a
        ret
