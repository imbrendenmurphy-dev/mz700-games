; =====================================================================
;  physics.asm - one tick of the current region (mirrors tools/engine.py)
;
;  A region is 32 x 24 cells, one byte each: bits 0-5 element, bit 7 =
;  "already moved this tick".  The scan runs over rows 1..22, left to
;  right.  An object that moves right or down (into a cell the scan has
;  not reached yet) is written with bit 7 set, and the scan clears the bit
;  instead of handling that cell, so nothing moves twice per tick.
; =====================================================================

region_scan:
        ld hl,(tick)
        inc hl
        ld (tick),hl
        ld hl,(rbase)
        ld de,RW
        add hl,de
        ld c,RH-2
.row:   ld b,RW
.cell:  ld a,(hl)
        or a
        jr z,.next
        jp m,.flag
        cp E_ROCK
        jr nc,.go
        cp E_PLAYER
        jr nz,.next
.go:    push bc
        ld (scan_ptr),hl
        add a,a
        ld e,a
        ld d,high JTAB
        ld a,(de)
        ld (.cs+1),a
        inc e
        ld a,(de)
        ld (.cs+2),a
        ld a,(hl)
.cs:    call 0
        ld hl,(scan_ptr)
        pop bc
.next:  inc hl
        djnz .cell
        call poll
        dec c
        jr nz,.row
        ret
.flag:  and 3Fh
        ld (hl),a
        jr .next

h_none:
        ret

kill_player:
        ld a,1
        ld (pl_dead),a
        ret

; ---------------------------------------------------------------------
; rock / egg at rest.  HL = cell, A = element
h_rest:
        ld c,a
        ld de,RW
        push hl
        add hl,de
        ld a,(hl)                   ; below
        pop hl
        or a
        jr nz,.nf
        ld (hl),0                   ; start falling
        add hl,de
        ld a,c
        inc a
        or 80h
        ld (hl),a
        ret
.nf:    call round_dirs
        ret z
        ld b,a
        inc c                       ; rolls as a falling object
        jp try_roll

; A = cell below (any flags) -> A = roll directions (bit 0 left, bit 1
; right), Z if none.  Keeps BC, HL.
round_dirs:
        and 3Fh
        or low ROUNDTAB
        ld e,a
        ld d,high ROUNDTAB
        ld a,(de)
        or a
        ret

; roll the object at HL left or right if both the side and the cell below
; the side are empty.  C = element (falling code) to move, B = allowed
; directions.  Carry set if it moved.
try_roll:
        ld de,RW
        bit 0,b
        jr z,.right
        dec hl
        ld a,(hl)
        or a
        jr nz,.r1
        push hl
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.r1
        ld (hl),c                   ; left: already scanned, no flag
        inc hl
        ld (hl),0
        scf
        ret
.r1:    inc hl
.right: bit 1,b
        jr z,.no
        inc hl
        ld a,(hl)
        or a
        jr nz,.r2
        push hl
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.r2
        ld a,c
        or 80h
        ld (hl),a
        dec hl
        ld (hl),0
        scf
        ret
.r2:    dec hl
.no:    or a
        ret

; ---------------------------------------------------------------------
; falling rock / egg.  HL = cell, A = element
h_fall:
        ld c,a
        ld de,RW
        push hl
        add hl,de
        ld a,(hl)
        ex de,hl                    ; DE = below
        pop hl
        or a
        jr nz,.hit
        ld (hl),0                   ; keep falling
        ld a,c
        or 80h
        ld (de),a
        ret
.hit:   and 3Fh
        cp E_PLAYER
        jp z,kill_player
        cp E_MONSTER
        jr z,.crush
        cp E_ROCKF
        ret z                       ; resting on a falling object: wait
        cp E_EGGF
        ret z
        push de
        call round_dirs
        pop de
        jr z,.land
        ld b,a
        push hl
        push bc
        call try_roll
        pop bc
        pop hl
        ret c
.land:  ld a,c
        cp E_EGGF
        ld a,E_HATCH1               ; an egg cracks when it lands
        jr z,.st
        ld a,c
        dec a
.st:    ld (hl),a
        ld hl,SFX_LAND
        ld a,1
        jp sfx
.crush: xor a                       ; a monster squashed
        ld (de),a
        ld a,4
        call count_gone
        ld de,0100h
        call add_score
        ld hl,SFX_CRUSH
        ld a,4
        jp sfx

; ---------------------------------------------------------------------
; cracked egg: a stage every 4 ticks, the last becomes a monster
h_hatch:
        ld c,a
        ld a,(tick)
        and 3
        ret nz
        ld a,c
        inc a
        ld (hl),a
        cp E_MONSTER
        ret nz
        ld hl,SFX_HATCH
        ld a,3
        jp sfx

; ---------------------------------------------------------------------
; near: is element C next to HL (left, up, right, down - in that
; order)?  Z and DE = that cell if so.  Keeps HL, BC.
near:
        push hl
        dec hl
        ld a,(hl)
        and 3Fh
        cp c
        jr z,.f
        ld de,1-RW
        add hl,de
        ld a,(hl)
        and 3Fh
        cp c
        jr z,.f
        ld de,RW+1
        add hl,de
        ld a,(hl)
        and 3Fh
        cp c
        jr z,.f
        ld de,RW-1
        add hl,de
        ld a,(hl)
        and 3Fh
        cp c
        jr z,.f
        pop hl
        ret                         ; NZ
.f:     ex de,hl
        pop hl
        ret

; DE = DIROFF[A] (A = direction 0-3).  Keeps HL, BC.
dir_off:
        add a,a
        add a,low DIROFF
        ld e,a
        ld a,high DIROFF
        adc a,0
        ld d,a
        ld a,(de)
        push af
        inc de
        ld a,(de)
        ld d,a
        pop af
        ld e,a
        ret

; ---------------------------------------------------------------------
; monster: kills when next to the player, otherwise moves on even ticks
; towards the player, along the longer axis first, through space only
h_monster:
        ld c,E_PLAYER
        call near
        jp z,kill_player
        ld a,(tick)
        rra
        ret c
        ; monster x, y
        call cell_pos               ; DE = pos
        ld a,e
        and 1Fh
        ld (mx),a
        ld a,e
        rlca
        rlca
        rlca
        and 7
        ld b,a
        ld a,d
        add a,a
        add a,a
        add a,a
        or b
        ld (my),a
        ; player x, y
        ld de,(pl_pos)
        ld a,e
        and 1Fh
        ld b,a                      ; B = px
        ld a,e
        rlca
        rlca
        rlca
        and 7
        ld c,a
        ld a,d
        add a,a
        add a,a
        add a,a
        or c
        ld c,a                      ; C = py
        ; horizontal choice
        ld a,(mx)
        ld e,a
        ld a,b
        sub e                       ; dx
        ld (mdx),a
        ld a,0FFh
        jr z,.hd
        ld a,2
        jr nc,.hd
        xor a
.hd:    ld (mhor),a
        ld a,(my)
        ld e,a
        ld a,c
        sub e                       ; dy
        ld (mdy),a
        ld a,0FFh
        jr z,.vd
        ld a,3
        jr nc,.vd
        ld a,1
.vd:    ld (mver),a
        ; |dx| >= |dy| ?
        ld a,(mdx)
        call absa
        ld b,a
        ld a,(mdy)
        call absa
        ld c,a
        ld a,b
        cp c
        jr c,.vfirst
        ld a,(mhor)
        call .try
        ret z
        ld a,(mver)
        jr .try
.vfirst:
        ld a,(mver)
        call .try
        ret z
        ld a,(mhor)
; try direction A (0FFh = none): Z if moved
.try:   cp 0FFh
        jr z,.no
        ld b,a
        call dir_off
        push hl
        add hl,de
        ld a,(hl)
        or a
        jr nz,.no2
        ld a,E_MONSTER
        bit 1,b
        jr z,$+4
        or 80h
        ld (hl),a
        pop hl
        ld (hl),0
        xor a
        ret
.no2:   pop hl
.no:    or 1
        ret

absa:
        or a
        ret p
        neg
        ret

; ---------------------------------------------------------------------
; spirit: kills when next to the player, turns a cage it touches into a
; gem, otherwise follows the wall on its left (through space only)
h_spirit:
        sub E_SPIRIT0
        ld (sdir),a
        ld c,E_PLAYER
        call near
        jp z,kill_player
        ld c,E_CAGE
        call near
        jr z,.cage
        ld a,(sdir)
        dec a
        and 3
        call .try
        ret z
        ld a,(sdir)
        call .try
        ret z
        ld a,(sdir)
        inc a
        and 3
        add a,E_SPIRIT0
        ld (hl),a
        ret
.cage:  ld a,E_GEM
        ld (de),a
        ld (hl),0
        ld de,0050h
        call add_score
        ld hl,SFX_CAGE
        ld a,4
        jp sfx
; A = direction: move there if empty (Z)
.try:   ld b,a
        call dir_off
        push hl
        add hl,de
        ld a,(hl)
        or a
        jr nz,.no
        ld a,b
        add a,E_SPIRIT0
        bit 1,b
        jr z,$+4
        or 80h
        ld (hl),a
        pop hl
        ld (hl),0
        xor a
        ret
.no:    pop hl
        or 1
        ret

; ---------------------------------------------------------------------
; fungus: every 16 ticks each cell grows one way (the way turns with the
; tick count); growing onto the player kills
h_fungus:
        ld a,(tick)
        and FUNGUS_MASK
        ret nz
        ld a,(tick)
        rrca
        rrca
        rrca
        rrca
        and 3
        ld b,a
        call dir_off
        add hl,de
        ld a,(hl)
        or a
        jr nz,.occ
        ld a,E_FUNGUS
        bit 1,b
        jr z,$+4
        or 80h
        ld (hl),a
        ret
.occ:   and 3Fh
        cp E_PLAYER
        jp z,kill_player
        ret
