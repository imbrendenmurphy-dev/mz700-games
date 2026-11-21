; =====================================================================
;  status.asm - the world status screen (SPACE during play): every
;  cavern visited and what is left in it, the Sun Mosaic so far, the
;  totals and a hint for this cavern
; =====================================================================

status_screen:
        call sfx_stop
        call wait_release
        ld a,BLACK
        call cls
        ld hl,txt_status_h
        ld c,0
        call heading
        ld hl,txt_status_cols
        ld b,1
        ld c,2
        ld a,CYAN*16
        call print_at
        ; one line per region
        xor a
.r:     push af
        call status_line
        pop af
        inc a
        cp NREG
        jr c,.r
        ; the mosaic
        ld a,(pieces_left)
        ld b,a
        ld a,TOTAL_PIECES
        sub b
        ld de,VRAM+3*40+27
        call mosaic_draw
        ; totals
        ld hl,txt_gems
        ld b,27
        ld c,12
        ld a,CYAN*16
        call print_at
        push de
        ld hl,TOTAL_GEMS
        ld de,(gems_left)
        or a
        sbc hl,de                   ; gems found
        pop de
        ld c,WHITE*16
        call print_dec3w
        ld hl,txt_pieces
        ld b,27
        ld c,13
        ld a,CYAN*16
        call print_at
        ld a,(pieces_left)
        ld b,a
        ld a,TOTAL_PIECES
        sub b
        ld c,WHITE*16
        call print_dec2
        ld hl,txt_mons
        ld b,27
        ld c,14
        ld a,CYAN*16
        call print_at
        ld a,(mons_left)
        ld c,WHITE*16
        call print_dec2
        ld hl,txt_crowns
        ld b,27
        ld c,15
        ld a,CYAN*16
        call print_at
        ld a,(crowns_left)
        ld b,a
        ld a,TOTAL_CROWNS
        sub b
        ld c,YELLOW*16
        call print_dec2
        ld hl,txt_time
        ld b,27
        ld c,17
        ld a,CYAN*16
        call print_at
        call print_time
        ld hl,txt_deaths
        ld b,27
        ld c,18
        ld a,CYAN*16
        call print_at
        ld hl,(deaths)
        ld c,WHITE*16
        call print_dec3w
        ; the hint for this region
        ld a,(region)
        call region_hdr
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,21
        ld a,YELLOW*16
        call print_centre
        ld a,(done_flag)
        or a
        jr z,.nd
        ld hl,txt_alldone
        ld c,20
        ld a,WHITE*16+RED
        call print_centre
.nd:    ld hl,txt_status_keys
        ld c,23
        ld a,GREEN*16
        call print_centre
        ; any key goes back
.w:     call wait_field
        call anykey
        jr z,.w
        jp wait_release

; status line for region A on screen row A + 3
status_line:
        ld (st_sel),a
        add a,3
        ld c,a
        ld b,1
        call vaddr
        ld a,(st_sel)
        inc a                       ; letter A..
        ld b,a
        ld hl,region
        ld a,(st_sel)
        cp (hl)
        ld c,GREEN*16
        jr nz,.nc
        ld c,YELLOW*16+BLUE         ; the current region stands out
.nc:    ld a,b
        call putc
        inc de
        inc de
        ; visited?
        ld a,(st_sel)
        push de
        call visited_bit
        pop de
        ld hl,txt_unknown
        jr z,.nm
        ld a,(st_sel)
        call region_hdr
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.nm:    push de
        ld c,WHITE*16
        call print
        pop de
        ld hl,14
        add hl,de
        ex de,hl
        ; gems, pieces, monsters left (RCOUNT)
        ld a,(st_sel)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld bc,RCOUNT
        add hl,bc
        ld a,(hl)
        ld c,CYAN*16
        push hl
        call print_dec3
        pop hl
        inc de
        inc hl
        ld a,(hl)
        ld c,YELLOW*16
        push hl
        call print_dec2
        pop hl
        inc de
        inc hl
        inc hl
        ld a,(hl)
        ld c,MAGENTA*16
        jp print_dec2

; Z if region A has not been visited
visited_bit:
        ld c,a
        srl a
        srl a
        srl a
        ld e,a
        ld d,0
        ld hl,visited
        add hl,de
        ld a,c
        and 7
        ld b,a
        inc b
        ld a,80h
.b:     rlca
        djnz .b
        and (hl)
        ret
