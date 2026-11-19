; =====================================================================
;  room.asm - room loading, tile queries, pickups, chroma blocks,
;             animated tiles and tile timers (crumbling, springs)
; =====================================================================

; ---------------------------------------------------------------------
; tile queries
; ---------------------------------------------------------------------
; HL = ROOMT address of (B = col, C = row), no range check (BC, DE kept)
cell_t:
        ld a,c
        add a,a
        add a,low ROWT
        ld l,a
        ld h,high ROWT
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,b
        ld l,a
        ret nc
        inc h
        ret

; A = flags of the tile at (B, C).  Rows outside the room are empty,
; columns outside are solid.  BC, DE, HL kept.
tflags:
        ld a,c
        cp ROOMH
        jr nc,.none
        ld a,b
        cp ROOMW
        jr nc,.wall
        push hl
        call cell_t
        ld l,(hl)
        ld h,high TFLG
        ld a,(hl)
        pop hl
        ret
.none:  xor a
        ret
.wall:  ld a,F_SOLID
        ret

; OR of the flags of D cells going up from (B, C) (a column)
tflags_col:
        push bc
        push de
        ld e,0
.l:     call tflags
        or e
        ld e,a
        dec c
        dec d
        jr nz,.l
        ld a,e
        pop de
        pop bc
        ret

; OR of the flags of D cells going right from (B, C) (a row)
tflags_row:
        push bc
        push de
        ld e,0
.l:     call tflags
        or e
        ld e,a
        inc b
        dec d
        jr nz,.l
        ld a,e
        pop de
        pop bc
        ret

; ---------------------------------------------------------------------
; load_room: A = room index.  Decodes the map, applies pickups already
; taken, numbers the pickups, lists animated cells, sets chroma blocks,
; spawns the room's objects and builds the overlay.  Draw it with wipe.
; ---------------------------------------------------------------------
load_room:
        ld (room),a
        add a,a
        ld l,a
        ld h,0
        ld de,ROOMTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,room_exits
        ld bc,4
        ldir
        ld a,(hl)
        ld (world),a
        inc hl
        ld a,(hl)
        ld (gembase),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (room_objs),de
        ; RLE: FFh n t = n copies of t
        ld de,ROOMT
        ld bc,NCELLS
.d:     ld a,(hl)
        inc hl
        cp 0FFh
        jr z,.run
        ld (de),a
        inc de
        dec bc
.dn:    ld a,b
        or c
        jr nz,.d
        jr .decoded
.run:   ld a,(hl)                   ; n
        inc hl
        push hl
        push bc
        ld b,a
        ld c,a
        ld a,(hl)                   ; tile
.r:     ld (de),a
        inc de
        djnz .r
        ld a,c
        pop hl                      ; HL = cells left
        ld c,a
        ld b,0
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        inc hl
        jr .dn
.decoded:
        ; world table
        ld a,(world)
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,WORLDTAB
        add hl,de
        ld de,wt
        ld bc,16
        ldir
        ; scan: pickups, gem ripple, animated cells
        xor a
        ld (gem_n),a
        ld (anim_n),a
        ld hl,ROOMT
        ld bc,0                     ; offset
.scan:  ld e,(hl)
        ld d,high TFLG
        ld a,(de)
        and F_GEM|F_ITEM
        jr z,.notpick
        push hl
        ld a,(gem_n)
        cp MAXGEMS
        jr nc,.pfull
        ld l,a
        inc a
        ld (gem_n),a
        ld h,0
        add hl,hl
        ld de,gem_offs
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),b
        dec a
        ld e,a
        ld a,(gembase)
        add a,e
        push bc
        call taken_bit              ; Z = not taken
        pop bc
        pop hl
        jr z,.fresh
        ld a,(wt+WT_SKY)
        ld (hl),a
        jr .next
.pfull: pop hl
.fresh: ld a,(wt+WT_GEM0)           ; gems: start the colour cycle by column
        ld e,a
        ld a,(hl)
        cp e
        jr nz,.notpick
        ld a,c
        and 3
        add a,e
        ld (hl),a
.notpick:
        ld e,(hl)
        ld d,high TANIM
        ld a,(de)
        cp e
        jr z,.next
        ld a,(anim_n)
        cp MAXANIM
        jr nc,.next
        push hl
        ld l,a
        inc a
        ld (anim_n),a
        ld h,0
        add hl,hl
        ld de,anim_list
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),b
        pop hl
.next:  inc hl
        inc bc
        ld a,b
        cp high NCELLS
        jr nz,.scan
        ld a,c
        cp low NCELLS
        jr nz,.scan
        ; per-room state
        xor a
        ld (tt_n),a
        call refresh_chroma_quiet
        call spawn_objects
        ; overlay <- whole room, shadow invalid
        ld hl,OVC
        ld bc,NCELLS
.ov:    push bc
        call restore_cell
        set 2,h
        ld (hl),0FFh
        set 3,h
        ld (hl),0FFh
        res 3,h
        res 2,h
        inc hl
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.ov
        jp lists_reset

; ---------------------------------------------------------------------
; draw the overlay to the screen in 10 frames, 4 columns at a time.
; A = 0 left to right, 1 right to left
; ---------------------------------------------------------------------
wipe_in:
        ld (wipe_dir),a
        xor a
        ld (wipe_k),a
.f:     call wait_frame
        ld a,(wipe_k)
        add a,a
        add a,a                     ; first column of this strip
        ld b,a
        ld a,(wipe_dir)
        or a
        jr z,.ltr
        ld a,36
        sub b
        ld b,a
.ltr:   ld c,4
.col:   push bc
        ld a,b
        call wipe_col
        pop bc
        inc b
        dec c
        jr nz,.col
        ld hl,wipe_k
        inc (hl)
        ld a,(hl)
        cp 10
        jr c,.f
        ret

; copy one overlay column (A = col) to shadow and VRAM
wipe_col:
        ld e,a
        ld d,0
        ld hl,OVC
        add hl,de
        ld b,ROOMH
.r:     ld a,(hl)
        set 2,h
        ld (hl),a
        res 2,h
        set 4,h
        ld (hl),a
        res 4,h
        set 3,h
        ld a,(hl)
        set 2,h
        ld (hl),a
        res 2,h
        set 4,h
        ld (hl),a
        res 4,h
        res 3,h
        ld de,ROOMW
        add hl,de
        djnz .r
        ret

; draw the overlay at once (no animation)
draw_all:
        xor a
.c:     push af
        call wipe_col
        pop af
        call poll
        inc a
        cp ROOMW
        jr c,.c
        ret

; ---------------------------------------------------------------------
; pickups: the level's bitmap of collected gems and items
; ---------------------------------------------------------------------
; A = pickup index -> HL = byte in taken[], B = mask; Z = not taken
taken_bit:
        push de
        ld e,a
        and 7
        ld b,a
        inc b
        ld a,80h
.m:     rlca
        djnz .m
        ld b,a
        ld a,e
        rrca
        rrca
        rrca
        and 1Fh
        ld e,a
        ld d,0
        ld hl,taken
        add hl,de
        ld a,(hl)
        and b
        pop de
        ret

; HL = ROOMT address of a pickup cell: collect it
collect_at:
        ld a,(hl)
        ld (pick_tile),a
        ld a,(wt+WT_SKY)
        ld (hl),a
        push hl
        ld de,-ROOMT
        add hl,de                   ; offset
        ex de,hl
        ; find its index
        ld hl,gem_offs
        ld a,(gem_n)
        or a
        jr z,.noidx
        ld b,a
        ld c,0
.f:     ld a,(hl)
        inc hl
        cp e
        jr nz,.nx
        ld a,(hl)
        cp d
        jr z,.found
.nx:    inc hl
        inc c
        djnz .f
        jr .noidx
.found: ld a,(gembase)
        add a,c
        call taken_bit
        ld a,(hl)
        or b
        ld (hl),a
.noidx: pop hl
        ld de,1000h
        add hl,de                   ; OVC address
        call mark_static
        ; reward
        ld a,(pick_tile)
        ld l,a
        ld h,high TFLG
        ld a,(hl)
        and F_GEM
        jr nz,got_gem
        ld a,(pick_tile)
        ld hl,wt+WT_APPLE
        cp (hl)
        jr z,got_apple
        inc hl
        cp (hl)
        jr z,got_oneup
        jr got_golden

got_gem:
        ld a,(gems)
        add a,1
        daa
        ld (gems),a
        jr nz,.n100
        call extra_life             ; every 100 gems
.n100:  ld hl,gems_level
        inc (hl)
        ld de,0010h
        call add_score
        ld hl,SFX_GEM
        ld a,1
        jp sfx

got_apple:
        ld a,(hearts)
        cp 3
        jr nc,.full
        inc a
        ld (hearts),a
.full:  ld de,0500h
        call add_score
        ld hl,SFX_APPLE
        ld a,3
        jp sfx

got_oneup:
        ld de,1000h
        call add_score
extra_life:
        ld a,(lives)
        cp 9
        jr nc,.max
        inc a
        ld (lives),a
.max:   ld a,1
        ld (hud_dirty),a
        ld hl,SFX_ONEUP
        ld a,4
        jp sfx

got_golden:
        ld hl,secrets_level
        inc (hl)
        ld de,2000h
        call add_score
        ld hl,SFX_GOLDEN
        ld a,4
        jp sfx

; ---------------------------------------------------------------------
; chroma blocks: solid in Kiko's colour, ghosts otherwise
; ---------------------------------------------------------------------
refresh_chroma_quiet:
        xor a
        jr refresh_chroma_go
refresh_chroma:
        ld a,1
refresh_chroma_go:
        ld (rc_live),a
        ld a,(wt+WT_CHROMA)
        ld d,a
        ld a,(hcol)
        ld e,a
        ld hl,ROOMT
        ld bc,NCELLS
.l:     ld a,(hl)
        sub d
        cp 6
        jr nc,.n
        push bc
        ld b,a
        srl a                       ; colour index
        ld c,a
        add a,a
        add a,d                     ; solid tile of that colour
        push af
        ld a,c
        cp e
        pop bc                      ; B = solid tile (pop af into BC: B=A)
        jr z,.s
        inc b                       ; ghost
.s:     ld a,b
        cp (hl)
        jr z,.same
        ld (hl),a
        ld a,(rc_live)
        or a
        jr z,.same
        push de
        push hl
        ld de,1000h
        add hl,de
        call mark_static
        pop hl
        pop de
.same:  pop bc
.n:     inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; animated tiles: every ANIMRATE frames each listed cell steps its cycle
; ---------------------------------------------------------------------
anim_tick:
        ld a,(anim_n)
        or a
        ret z
        ld b,a
        ld hl,anim_list
.l:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,ROOMT
        add hl,de
        ld e,(hl)
        ld d,high TANIM
        ld a,(de)
        cp e
        jr z,.s
        ld (hl),a
        ld de,1000h
        add hl,de
        call mark_static
.s:     pop hl
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; tile timers: (off lo, off hi, frames, action)
;   1 crumble -> crack   2 crack -> gone   3 squashed spring -> spring
; ---------------------------------------------------------------------
; HL = ROOMT address, A = action, C = frames.  Ignored if that cell
; already has a timer.
tt_add:
        push hl
        ld de,-ROOMT
        add hl,de
        ex de,hl                    ; DE = offset
        ld b,a
        ld hl,tt_list
        ld a,(tt_n)
        or a
        jr z,.add
        push bc
        ld b,a
.f:     ld a,(hl)
        cp e
        jr nz,.nx
        inc hl
        ld a,(hl)
        dec hl
        cp d
        jr nz,.nx
        pop bc
        pop hl
        ret                         ; already ticking
.nx:    inc hl
        inc hl
        inc hl
        inc hl
        djnz .f
        pop bc
        ld a,(tt_n)
        cp MAXTT
        jr nc,.full
.add:   ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        ld hl,tt_n
        inc (hl)
.full:  pop hl
        ret

tt_tick:
        ld a,(tt_n)
        or a
        ret z
        ld b,a
        ld ix,tt_list
.l:     dec (ix+2)
        jr nz,.next
        ld e,(ix+0)
        ld d,(ix+1)
        ld hl,ROOMT
        add hl,de
        ld a,(ix+3)
        cp 1
        jr nz,.a2
        ld a,(wt+WT_CRACK)          ; crumble -> crack, then gone
        ld (hl),a
        ld (ix+3),2
        ld (ix+2),20
        push bc
        ld hl,SFX_CRUMBLE
        ld a,1
        call sfx
        pop bc
        jr .mark
.a2:    cp 2
        jr nz,.a3
        ld a,(wt+WT_SKY)
        ld (hl),a
        jr .del
.a3:    ld a,(wt+WT_SPRING)
        ld (hl),a
.del:   ; remove entry: copy the last one over it
        push bc
        push hl
        ld hl,tt_n
        dec (hl)
        ld a,(hl)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,tt_list
        add hl,de
        push ix
        pop de
        ld bc,4
        ldir
        pop hl
        pop bc
        ld de,1000h
        add hl,de
        push bc
        call mark_static
        pop bc
        jr .again                   ; same slot now holds the moved entry
.mark:  ld de,1000h
        add hl,de
        push bc
        call mark_static
        pop bc
.next:  ld de,4
        add ix,de
.again: djnz .l
        ret
