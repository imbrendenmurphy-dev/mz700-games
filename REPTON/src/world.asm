; =====================================================================
;  world.asm - the persistent world: every region lives unpacked in RAM
;  (WORLD + region * 768).  Packed maps are only used to start a new
;  game or to reset a region.
; =====================================================================

; HL = WORLD + A * RSZ  (A = region).  Keeps DE, BC.
region_addr:
        push de
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl                   ; *2
        add hl,de                   ; *3
        ld h,l
        ld l,0                      ; *768
        ld de,WORLD
        add hl,de
        pop de
        ret

; HL = header of region A: db theme / dw name, hint / packed cells
region_hdr:
        push de
        add a,a
        ld l,a
        ld h,0
        ld de,REGTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ret

; unpack region A from the packed maps (RLE: code | (n-1) << 6, or
; 0C0h | code, n)
unpack_region:
        push af
        call region_addr
        ex de,hl                    ; DE = destination
        ld hl,RSZ
        add hl,de
        ld (upk_end),hl
        pop af
        call region_hdr
        ld bc,5
        add hl,bc
.l:     ld a,(hl)
        inc hl
        ld c,a
        cp 0C0h
        jr c,.s
        ld b,(hl)
        inc hl
        jr .f
.s:     rlca
        rlca
        and 3
        inc a
        ld b,a
.f:     ld a,c
        and 3Fh
.w:     ld (de),a
        inc de
        djnz .w
        ld a,(upk_end)
        cp e
        jr nz,.l
        ld a,(upk_end+1)
        cp d
        jr nz,.l
        ret

unpack_all:
        xor a
.r:     push af
        call unpack_region
        call poll
        pop af
        inc a
        cp NREG
        jr c,.r
        ret

; ---------------------------------------------------------------------
; switches: SWTAB entries are region, pos(2), target, x1, y1, x2, y2
; ---------------------------------------------------------------------
; fixup: apply the thrown switches to region A (after an unpack or a
; restore): thrown switches show as thrown, their barriers are gone
fixup:
        ld (fx_region),a
        ld ix,SWTAB
        ld hl,(sw_flags)
        ld b,NSWITCH
        inc b
        jr .next
.sw:    srl h
        rr l
        jr nc,.skip
        push hl
        push bc
        ld a,(fx_region)
        cp (ix+0)
        jr nz,.nt
        call region_addr
        ld e,(ix+1)
        ld d,(ix+2)
        add hl,de
        ld (hl),E_SWITCHON
.nt:    ld a,(fx_region)
        cp (ix+3)
        call z,clear_rect
        pop bc
        pop hl
.skip:  ld de,8
        add ix,de
.next:  djnz .sw
        ret

; clear the barriers of switch IX in its target region
clear_rect:
        ld a,(ix+3)
        call region_addr
        ld a,(ix+5)                 ; y1
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; y1 * 32
        add hl,de
        ld e,(ix+4)                 ; x1
        ld d,0
        add hl,de                   ; first cell
        ld a,(ix+7)
        sub (ix+5)
        inc a
        ld c,a                      ; rows
.row:   push hl
        ld a,(ix+6)
        sub (ix+4)
        inc a
        ld b,a                      ; columns
.col:   ld a,(hl)
        and 3Fh
        cp E_BARRIER
        jr nz,.n
        ld (hl),E_SPACE
.n:     inc hl
        djnz .col
        pop hl
        ld de,RW
        add hl,de
        dec c
        jr nz,.row
        ret

; find the switch at cell HL of the current region: IX = entry, B = its
; number (0..), Z if found
find_switch:
        call cell_pos               ; DE = position in the region
        ld ix,SWTAB
        ld b,0
.l:     ld a,b
        cp NSWITCH
        jr nc,.no
        ld a,(region)
        cp (ix+0)
        jr nz,.n
        ld a,(ix+1)
        cp e
        jr nz,.n
        ld a,(ix+2)
        cp d
        ret z
.n:     push de
        ld de,8
        add ix,de
        pop de
        inc b
        jr .l
.no:    or 1
        ret

; find the transporter at cell HL: IX = entry (region, pos(2), dest
; region, dest pos(2)), Z if found
find_trans:
        call cell_pos
        ld ix,TRANSTAB
        ld b,NTRANS
.l:     ld a,(region)
        cp (ix+0)
        jr nz,.n
        ld a,(ix+1)
        cp e
        jr nz,.n
        ld a,(ix+2)
        cp d
        ret z
.n:     push de
        ld de,6
        add ix,de
        pop de
        djnz .l
        or 1
        ret

; DE = HL - rbase (position of a cell in the current region)
cell_pos:
        push hl
        ld de,(rbase)
        or a
        sbc hl,de
        ex de,hl
        pop hl
        ret

; ---------------------------------------------------------------------
; recount: count what is left in the whole world (per region in RCOUNT:
; gems / cages / safes, pieces, crowns, eggs / monsters) and the totals
; ---------------------------------------------------------------------
recount:
        ld hl,RCOUNT
        ld b,NREG*4
.z:     ld (hl),0
        inc hl
        djnz .z
        ld ix,RCOUNT
        ld hl,WORLD
        xor a
.reg:   push af
        ld bc,RSZ
        ld d,high CNTCLASS
.cell:  ld a,(hl)
        and 3Fh
        or low CNTCLASS
        ld e,a
        ld a,(de)
        or a
        jr z,.nx
        push bc
        ld c,a
        ld b,0
        push ix
        add ix,bc
        inc (ix-1)
        pop ix
        pop bc
.nx:    inc hl
        dec bc
        ld a,c
        or a
        jr nz,.cell
        call poll
        ld a,b
        or a
        jr nz,.cell
        ld de,4
        add ix,de
        pop af
        inc a
        cp NREG
        jr c,.reg
        ; totals
        ld hl,0
        xor a
        ld (pieces_left),a
        ld (crowns_left),a
        ld (mons_left),a
        ld ix,RCOUNT
        ld b,NREG
.t:     ld e,(ix+0)
        ld d,0
        add hl,de
        ld a,(pieces_left)
        add a,(ix+1)
        ld (pieces_left),a
        ld a,(crowns_left)
        add a,(ix+2)
        ld (crowns_left),a
        ld a,(mons_left)
        add a,(ix+3)
        ld (mons_left),a
        ld de,4
        add ix,de
        djnz .t
        ld (gems_left),hl
        ; fall through
; done_flag = every requirement met
check_done:
        ld hl,(gems_left)
        ld a,h
        or l
        ld hl,pieces_left
        or (hl)
        ld hl,mons_left
        or (hl)
        ld a,0
        jr nz,.n
        inc a
.n:     ld (done_flag),a
        ld a,1
        ld (hud_dirty),a
        ret

; count one item of class A (1 gem, 2 piece, 3 crown, 4 monster) as gone,
; in the totals and in the current region's RCOUNT entry
count_gone:
        push hl
        push de
        ld e,a
        ld a,(region)
        add a,a
        add a,a
        add a,e
        dec a
        ld l,a
        ld h,0
        ld d,h
        push de
        ld de,RCOUNT
        add hl,de
        dec (hl)
        pop de
        ld a,e
        dec a
        jr nz,.n1
        ld hl,(gems_left)
        dec hl
        ld (gems_left),hl
        jr .d
.n1:    dec a
        jr nz,.n2
        ld hl,pieces_left
        dec (hl)
        jr .d
.n2:    dec a
        jr nz,.n3
        ld hl,crowns_left
        dec (hl)
        jr .d
.n3:    ld hl,mons_left
        dec (hl)
.d:     call check_done
        pop de
        pop hl
        ret
