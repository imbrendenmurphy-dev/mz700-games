; =====================================================================
;  particles.asm - embers, sparks, spores, frost, blood and magic
;
;  28 particles of 8 bytes at PARTS.  Positions are map cells in 8.8
;  fixed point; velocities are 1/64 cell per frame.  A particle shows
;  three glyphs and colours as it ages (PKINDS), and only where the
;  player can see.
; =====================================================================
PA_KIND         equ 0
PA_XF           equ 1
PA_X            equ 2
PA_YF           equ 3
PA_Y            equ 4
PA_VX           equ 5
PA_VY           equ 6
PA_LIFE         equ 7

parts_clear:
        ld hl,PARTS
        ld b,NPART*8
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; spawn particle kind A at cell (B, C) with velocity D (vx), E (vy) and
; life L.  Keeps BC, DE.
part_spawn:
        push hl
        push af
        ld hl,(part_next)
        ld a,l
        or h
        jr nz,$+5
        ld hl,PARTS
        push de
        ld de,8
        ; find a free slot from part_next (else take it anyway)
        push bc
        ld b,NPART
.f:     ld a,(hl)
        or a
        jr z,.got
        add hl,de
        ld a,l
        cp low (PARTS+NPART*8)
        jr nz,.w
        ld a,h
        cp high (PARTS+NPART*8)
        jr nz,.w
        ld hl,PARTS
.w:     djnz .f
.got:   pop bc
        pop de
        pop af
        ld (hl),a                   ; kind
        inc hl
        ld (hl),80h                 ; centre of the cell
        inc hl
        ld (hl),b
        inc hl
        ld (hl),80h
        inc hl
        ld (hl),c
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        inc hl
        ld a,(part_life)
        ld (hl),a
        inc hl
        ld a,l
        cp low (PARTS+NPART*8)
        jr nz,.s
        ld a,h
        cp high (PARTS+NPART*8)
        jr nz,.s
        ld hl,PARTS
.s:     ld (part_next),hl
        pop hl
        ret

; E particles of kind A bursting from cell (B, C)
burst:
        ld (bu_kind),a
        ld a,e
        or a
        ret z
.l:     push de
        ; velocity: random -40..40 each way, plus the kind's drift
        call rand
        and 3Fh
        sub 20h
        sra a
        ld d,a
        call rand
        and 3Fh
        sub 20h
        sra a
        ld e,a
        ld a,(bu_kind)
        call pk_rec
        ld a,(hl)                   ; kind's vy
        add a,a
        add a,a
        add a,e
        ld e,a
        call rand
        and 7
        add a,10
        ld (part_life),a
        ld a,(bu_kind)
        call part_spawn
        pop de
        dec e
        jr nz,.l
        ret

; HL -> the vy byte of particle kind A (1-based).  Keeps BC, DE.
pk_rec:
        push de
        dec a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,PKINDS+6
        add hl,de
        pop de
        ret

; one gentle particle of kind A rising from (B, C) (ambient)
puff:
        push af
        call rand
        and 0Fh
        sub 8
        ld d,a
        pop af
        push af
        call pk_rec
        ld a,(hl)
        add a,a
        add a,a
        ld e,a
        call rand
        and 7
        add a,12
        ld (part_life),a
        pop af
        jp part_spawn

; ---------------------------------------------------------------------
; age and move every particle (once a frame)
parts_update:
        ld ix,PARTS
        ld b,NPART
.l:     ld a,(ix+PA_KIND)
        or a
        jr z,.n
        push bc
        ld b,(ix+PA_X)
        ld c,(ix+PA_Y)
        call mark_map
        pop bc
        dec (ix+PA_LIFE)
        jr nz,.live
        ld (ix+PA_KIND),0
        jr .n
.live:  ; x += vx * 4
        ld a,(ix+PA_VX)
        call .scale
        ld a,(ix+PA_XF)
        add a,e
        ld (ix+PA_XF),a
        ld a,(ix+PA_X)
        adc a,d
        ld (ix+PA_X),a
        ld a,(ix+PA_VY)
        call .scale
        ld a,(ix+PA_YF)
        add a,e
        ld (ix+PA_YF),a
        ld a,(ix+PA_Y)
        adc a,d
        ld (ix+PA_Y),a
        ; gravity
        ld a,(ix+PA_KIND)
        push hl
        call pk_rec
        inc hl
        bit 0,(hl)
        pop hl
        jr z,.ng
        inc (ix+PA_VY)
.ng:    ; off the map: gone
        ld a,(ix+PA_X)
        cp MAPW
        jr nc,.kill
        ld a,(ix+PA_Y)
        cp MAPH
        jr c,.n
.kill:  ld (ix+PA_KIND),0
.n:     ld de,8
        add ix,de
        djnz .l
        ret
; DE = A (signed) * 4
.scale: ld e,a
        add a,a
        sbc a,a
        ld d,a
        sla e
        rl d
        sla e
        rl d
        ret

; draw the particles as overlays
parts_draw:
        ld ix,PARTS
        ld b,NPART
.l:     push bc
        ld a,(ix+PA_KIND)
        or a
        jr z,.n
        ld b,(ix+PA_X)
        ld c,(ix+PA_Y)
        call view_index
        jr z,.n
        ld a,(hl)
        bit 3,a                     ; only where the player sees
        jr z,.n
        push hl
        ; stage: life >= 12 -> 0, >= 6 -> 1, else 2
        ld a,(ix+PA_LIFE)
        ld e,0
        cp 12
        jr nc,.st
        inc e
        cp 6
        jr nc,.st
        inc e
.st:    ld a,(ix+PA_KIND)
        dec a
        add a,a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,PKINDS
        add hl,de
        ld a,(hl)                   ; glyph
        ld (ov_g),a
        inc hl
        inc hl
        inc hl
        ld a,(hl)                   ; attr
        pop hl
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
.n:     ld de,8
        add ix,de
        pop bc
        djnz .l
        ret

; ambient particles: try a few random cells in view each frame
ambient:
        ld a,3
.l:     push af
        ld b,VIEWW
        call rand_below
        ld b,a
        push bc
        ld b,VIEWH
        call rand_below
        pop bc
        ld c,a
        ; LVL: must be seen and lit
        push bc
        ld a,c
        call mul40
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld de,LVL
        add hl,de
        ld a,(hl)
        pop bc
        and 7
        cp 2
        jr c,.n
        ld a,(vx)
        add a,b
        ld b,a
        ld a,(vy)
        add a,c
        ld c,a
        call tile_at
        add a,low TAMB
        ld l,a
        ld h,high TAMB
        ld a,(hl)
        or a
        jr z,.n
        push af
        ld b,b
        call rand
        and 3
        pop de                      ; D = kind
        jr nz,.n
        ld a,d
        call puff
.n:     pop af
        dec a
        jr nz,.l
        ret
