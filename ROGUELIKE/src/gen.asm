; =====================================================================
;  gen.asm - builds a zone the first time the player enters it
;
;  The 62 x 30 interior is a 3 x 3 grid of cells (20 x 10).  Each cell
;  holds a random room or one of the zone's hand-made prefabs (their
;  entrances face up, so a prefab sits in row 1 or 2 under a room).  A
;  random spanning tree of corridors (plus a couple of loops) joins the
;  rooms; then the theme decorates them, and exits, monsters, items and
;  the zone's resident are placed.
; =====================================================================

ZD_THEME        equ 0
ZD_STYLE        equ 1
ZD_LTILE        equ 2
ZD_LCOUNT       equ 3
ZD_POOL         equ 4
ZD_MLO          equ 8
ZD_MHI          equ 9
ZD_LOOT         equ 10
ZD_PF           equ 14
ZD_SLOTS        equ 17
ZD_LINKS        equ 26
ZD_NPC          equ 32
ZD_NAME         equ 33

ST_CAVE         equ 01h
ST_WATER        equ 02h
ST_LAVA         equ 04h
ST_PILLARS      equ 08h
ST_FUNGUS       equ 10h
ST_CRYSTAL      equ 20h
ST_BOOKS        equ 40h
ST_BONES        equ 80h

; IX = this zone's definition
zone_def:
        ld a,(zone)
        call mul40
        ld de,ZONEDEFS
        add hl,de
        push hl
        pop ix
        ret

; ---------------------------------------------------------------------
; tile helpers
; ---------------------------------------------------------------------
; set map cell HL to tile A (keeps the seen bit; sets the opaque bit).
; Keeps BC, DE, HL.
set_tile:
        push de
        ld e,a
        ld d,high TFLAGS
        ld a,(de)
        and 1                       ; F_OPAQUE
        rrca                        ; -> bit 7
        ld d,a
        ld a,(hl)
        and 40h
        or e
        or d
        ld (hl),a
        pop de
        ret

; A = flags of tile A.  Keeps BC, DE, HL.
tile_flags:
        push hl
        ld l,a
        ld h,high TFLAGS
        ld a,(hl)
        pop hl
        ret

; A = tile at (B, C).  HL = its address.  Keeps BC, DE.
tile_at:
        call map_addr
        ld a,(hl)
        and 3Fh
        ret

; ---------------------------------------------------------------------
gen_zone:
        call zone_def
.retry: call poll
        ; everything rock
        ld hl,MAP
        ld de,MAP+1
        ld bc,2047
        ld (hl),80h+T_WALL
        ldir
        ld hl,g_kind
        ld b,9
.k:     ld (hl),0
        inc hl
        djnz .k
        ld hl,g_own                 ; no halls yet
        ld b,9
.o:     ld (hl),0FFh
        inc hl
        djnz .o
        ld (hl),b                   ; g_nmerge
        inc hl
        ld (hl),b                   ; g_big
        ; prefab cells
        ld a,(zone)                 ; no exits yet
        call exits_addr
        ld b,9
.xc:    ld (hl),0FFh
        inc hl
        djnz .xc
        ld b,0                      ; prefab slot
.pf:    push bc
        ld e,b
        ld d,0
        push ix
        add ix,de
        ld a,(ix+ZD_PF)
        pop ix
        pop bc
        or a
        jr z,.pfdone
        push bc
        call pick_pf_cell           ; A = cell (or carry: no room)
        pop bc
        jr c,.retry
        ld e,a
        ld d,0
        ld hl,g_kind
        add hl,de
        ld a,b
        inc a
        ld (hl),a                   ; kind = slot + 1
        inc b
        ld a,b
        cp 3
        jr c,.pf
.pfdone:
        ; rooms in the other cells
        ld c,0
.room:  ld a,c
        call cell_kind
        jr nz,.nr
        ld a,c
        call own_addr
        ld a,(hl)
        push bc
        inc a
        jr nz,.hall
        call make_room
        jr .nr0
.hall:  dec a                       ; part of a hall: the owner's room
        ld b,a
        call room_rec
        ld d,h
        ld e,l
        ld c,b
        call room_rec
        ld bc,4
        ldir
.nr0:   pop bc
.nr:    inc c
        ld a,c
        cp 9
        jr c,.room
        ; ragged cave edges
        bit 0,(ix+ZD_STYLE)
        call nz,cave_bites
        ; corridors: a spanning tree over the room cells
        call span_tree
        jp c,.retry
        call poll
        ; prefabs, each joined to the room above it
        ld c,0
.stamp: ld a,c
        call cell_kind
        jr z,.ns
        push bc
        call stamp_prefab
        pop bc
.ns:    inc c
        ld a,c
        cp 9
        jr c,.stamp
        call poll
        call make_doors
        call decorate
        ld a,(zone)                 ; the sun-stone rests in the crypt
        or a
        call z,place_stone
        call poll
        call place_exits
        ld a,(newgame)
        or a
        call nz,place_start
        call place_monsters
        call place_items
        call poll
        ret

; Z if cell A holds a room (not a prefab).  A = kind.  Keeps BC, DE.
cell_kind:
        push hl
        ld l,a
        ld h,0
        push de
        ld de,g_kind
        add hl,de
        pop de
        ld a,(hl)
        pop hl
        or a
        ret

; choose a free cell for a prefab: rows 1-2, not the centre, under a
; room cell.  A = cell; carry if none found.
pick_pf_cell:
        ld e,40
.t:     dec e
        scf
        ret z
        ld b,5
        call rand_below
        ld hl,pf_cells
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)                   ; candidate
        ld d,a
        call cell_kind
        jr nz,.t
        ld a,d
        sub 3
        call cell_kind              ; the cell above must be a room
        jr nz,.t
        ld a,d                      ; and nothing may sit under it yet
        cp 6
        jr nc,.ok
        add a,3
        call cell_kind
        jr nz,.t
.ok:    ld a,d
        or a
        ret
pf_cells:
        db 3,5,6,7,8

; cell C -> B = x0, C = y0 (its top-left).  Keeps DE, HL.
cell_origin:
        ld a,c
        ld b,0
.r:     cp 3
        jr c,.c
        sub 3
        inc b
        jr .r
.c:     ; A = column, B = row
        push de
        ld c,a
        add a,a
        add a,a                     ; *4
        ld e,a
        add a,a
        add a,a                     ; *16
        add a,e                     ; *20
        add a,c                     ; *21
        inc a
        push af
        ld a,b
        add a,a
        ld c,a
        add a,a
        add a,a
        add a,c                     ; *10
        inc a
        ld c,a
        pop af
        ld b,a
        pop de
        ret

; HL = g_rooms + 4 * C.  Keeps BC, DE.
room_rec:
        ld a,c
        add a,a
        add a,a
        ld hl,g_rooms
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; a random room in cell C.  Up to two halls a zone join this cell to
; the next (wide), the one below (tall) or both (the great hall, one a
; zone, nearly the size of the view): rooms wider than the light reaches,
; so it falls in rays between the columns.
make_room:
        push bc
        ld a,c
        ld (g_cell),a
        call room_rec
        push hl
        call cell_origin            ; B = x0, C = y0
        push bc
        ld bc,8*256+17              ; width 8..17 (caves 10..17)
        bit 0,(ix+ZD_STYLE)
        jr z,$+4
        ld b,10
        call rand_range
        ld d,a                      ; w
        ld bc,5*256+8
        call rand_range
        ld e,a                      ; h
        ld hl,19*256+9              ; H, L = x, y span + 1
        ld a,(g_nmerge)
        cp 2
        jp nc,.place
        ld b,4
        call rand_below
        or a
        jp z,.place                 ; 1 in 4 stays a room
        ld c,0                      ; bit 0: right free, bit 1: below
        ld a,(g_cell)
        call col_of
        cp 2
        jr nc,.nr
        ld a,(g_cell)
        inc a
        call cell_free
        jr nz,.nr
        inc c
.nr:    ld a,(g_cell)
        cp 6
        jr nc,.nd
        add a,3
        call cell_free
        jr nz,.nd
        set 1,c
.nd:    ld a,c
        or a
        jr z,.place
        cp 3
        jr nz,.one
        ld a,(g_big)
        or a
        jr nz,.pick
        ld a,(g_cell)
        add a,4
        call cell_free
        jr z,.great
.pick:  ld b,2
        call rand_below
        inc a
.one:   ld c,a
        ld hl,g_nmerge
        inc (hl)
        dec c
        jr nz,.tall
        ld a,1                      ; the cell to the right
        call own_set
        call .w
        ld hl,40*256+9
        jr .place
.tall:  ld a,3                      ; the cell below
        call own_set
        call .h
        ld hl,19*256+19
        jr .place
.great: ld hl,g_nmerge
        inc (hl)
        inc (hl)
        ld a,1
        ld (g_big),a
        call own_set
        ld a,3
        call own_set
        ld a,4
        call own_set
        call .w
        call .h
        ld hl,40*256+19
.place: pop bc                      ; x0, y0
        ; x = x0 + 1 + rand(H - w), y = y0 + 1 + rand(L - h)
        ld a,h
        sub d
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,b
        inc a
        ld b,a
        ld a,l
        sub e
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,c
        inc a
        ld c,a
        pop hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        ; carve it
        call fill_rect_floor
        pop bc
        ret
.w:     ld bc,30*256+38
        call rand_range
        ld d,a
        ret
.h:     ld bc,15*256+18
        call rand_range
        ld e,a
        ret

; g_own[g_cell + A] = g_cell.  Keeps BC, DE.
own_set:
        ld hl,g_cell
        add a,(hl)
        call own_addr
        ld a,(g_cell)
        ld (hl),a
        ret

; HL = g_own + A.  Keeps BC, DE.
own_addr:
        push de
        ld hl,g_own
        ld e,a
        ld d,0
        add hl,de
        pop de
        ret

; Z if cell A is a room cell no hall has taken.  Keeps BC, DE, HL.
cell_free:
        push hl
        push af
        call own_addr
        ld a,(hl)
        inc a
        pop hl                      ; H = the cell
        jr nz,.x
        ld a,h
        call cell_kind
.x:     pop hl
        ret

; carve B,C (x,y) D x E (w,h) to FLOOR (only wall cells)
fill_rect_floor:
        ld a,T_FLOOR
; fill rect B,C,D,E with tile A over wall cells only
fill_rect_wall:
        ld (fill_rect_wall.t+1),a
.row:   push bc
        push de
.col:   push bc
        call map_addr
        ld a,(hl)
        and 3Fh
        cp T_WALL
        jr nz,.skip
.t:   ld a,0
        call set_tile
.skip:  pop bc
        inc b
        dec d
        jr nz,.col
        pop de
        pop bc
        inc c
        dec e
        jr nz,.row
        ret

; fill rect B,C,D,E with tile A over anything
fill_rect:
        ld (fill_rect.t+1),a
.row:   push bc
        push de
.col:   push bc
        call map_addr
.t:  ld a,0
        call set_tile
        pop bc
        inc b
        dec d
        jr nz,.col
        pop de
        pop bc
        inc c
        dec e
        jr nz,.row
        ret

; ---------------------------------------------------------------------
; ragged edges: bite random cells around each room
cave_bites:
        ld c,0
.r:     ld a,c
        call cell_kind
        jr nz,.n
        push bc
        ld a,c
        ld (cb_cell),a
        call room_rec
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld (cb_room),bc
        ld (cb_size),de
        ld a,d
        add a,e
        ld (cb_n),a
.b:     ld bc,(cb_room)
        ld de,(cb_size)
        ld a,d
        add a,2
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,b
        dec a
        ld (cb_x),a
        ld a,e
        add a,2
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,c
        dec a
        ld (cb_y),a
        ld a,(cb_cell)
        ld c,a
        call cell_origin
        ld a,(cb_x)
        sub b
        jr c,.no
        jr z,.no
        cp 19
        jr nc,.no
        ld a,(cb_y)
        sub c
        jr c,.no
        jr z,.no
        cp 9
        jr nc,.no
        ld a,(cb_x)
        ld b,a
        ld a,(cb_y)
        ld c,a
        call map_addr
        ld a,T_FLOOR
        call set_tile
.no:    ld hl,cb_n
        dec (hl)
        jr nz,.b
        pop bc
.n:     inc c
        ld a,c
        cp 9
        jp c,.r
        ret

; ---------------------------------------------------------------------
; spanning tree over room cells (random Prim), then 2 extra loops.
; Carry if the room cells are not all joined.
span_tree:
        ld hl,g_vis
        ld b,9
.c:     ld (hl),0
        inc hl
        djnz .c
        ; count room cells, start at a random one
        ld c,0
        ld e,0
.cnt:   ld a,c
        call cell_kind
        jr nz,$+3
        inc e
        inc c
        ld a,c
        cp 9
        jr c,.cnt
        ld a,e
        ld (g_need),a
.st:    ld b,9
        call rand_below
        ld c,a
        call cell_kind
        jr nz,.st
        ld a,c
        call vis_set
        ld a,1
        ld (g_have),a
        ld de,1500                  ; tries
.grow:  ld a,(g_have)
        ld hl,g_need
        cp (hl)
        jr nc,.loops
        dec de
        ld a,d
        or e
        scf
        ret z
        push de
        call rand_edge              ; B = from, C = to (Z if valid edge)
        jr nz,.g2
        ld a,c
        call vis_get
        jr nz,.g2
        ld a,b
        call vis_get
        jr z,.g2
        ld a,c
        call cell_kind
        jr nz,.g2
        ld a,c
        call vis_set
        ld hl,g_have
        inc (hl)
        call join_cells
.g2:    pop de
        jr .grow
.loops: ld e,2
        bit 0,(ix+ZD_STYLE)
        jr z,$+4
        ld e,3
.lp:    push de
.lt:    call rand_edge
        jr nz,.lt
        ld a,c
        call cell_kind
        jr nz,.lt
        ld a,b
        call cell_kind
        jr nz,.lt
        call join_cells
        pop de
        dec e
        jr nz,.lp
        or a
        ret

; random grid edge: B = a cell, C = a neighbour; Z if C exists
rand_edge:
        push hl
        ld b,9
        call rand_below
        ld b,a
        push bc
        ld b,4
        call rand_below
        pop bc
        or a
        jr z,.l
        dec a
        jr z,.r
        dec a
        jr z,.u
        ld a,b                      ; down
        add a,3
        cp 9
        jr nc,.no
        jr .ok
.u:     ld a,b
        sub 3
        jr c,.no
        jr .ok
.l:     ld a,b
        call col_of
        or a
        jr z,.no
        ld a,b
        dec a
        jr .ok
.r:     ld a,b
        call col_of
        cp 2
        jr z,.no
        ld a,b
        inc a
.ok:    ld c,a
        pop hl
        xor a
        ret
.no:    pop hl
        or 1
        ret

col_of:
.s:     cp 3
        ret c
        sub 3
        jr .s

vis_get:
        push hl
        call vis_addr
        ld a,(hl)
        or a
        pop hl
        ret
vis_set:
        push hl
        call vis_addr
        ld (hl),1
        pop hl
        ret
vis_addr:
        ld hl,g_vis
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; corridor between the rooms of cells B and C
join_cells:
        push bc
        push bc
        call room_centre            ; of C
        ld a,b
        ld (jc_x2),a
        ld a,c
        ld (jc_y2),a
        pop bc
        ld c,b
        call room_centre
        ld a,(jc_x2)
        ld e,a
        ld a,(jc_y2)
        ld d,a
        ld a,r
        and 1
        call dig
        pop bc
        ret

; BC = centre (B = x, C = y) of the room in cell C
room_centre:
        call room_rec
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        srl a
        add a,b
        ld b,a
        inc hl
        ld a,(hl)
        srl a
        add a,c
        ld c,a
        ret

; dig an L-shaped corridor from (B, C) to (E, D); A bit 0: 0 = across
; first, 1 = up/down first.  Only wall cells become floor.
dig:
        and 1
        jr nz,.vfirst
        call dig_h
        jp dig_v
.vfirst:
        call dig_v
        jp dig_h
; along x from B to E at row C (B ends = E)
dig_h:
.l:     call dig_cell
        ld a,b
        cp e
        ret z
        jr c,.inc
        dec b
        jr .l
.inc:   inc b
        jr .l
; along y from C to D at column B
dig_v:
.l:     call dig_cell
        ld a,c
        cp d
        ret z
        jr c,.inc
        dec c
        jr .l
.inc:   inc c
        jr .l
dig_cell:
        push hl
        call map_addr
        ld a,(hl)
        and 3Fh
        cp T_WALL
        jr nz,.x
        ld a,T_FLOOR
        call set_tile
.x:     pop hl
        ret

; ---------------------------------------------------------------------
; stamp the prefab of cell C (kind = slot + 1) and join it to the room
; of the cell above
stamp_prefab:
        dec a
        ld (sp_slot),a
        ld e,a
        ld d,0
        push ix
        add ix,de
        ld a,(ix+ZD_PF)
        pop ix
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,PREFABS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (sp_ptr),hl              ; w, h, ex, ey, side, cells
        push bc
        call cell_origin            ; B = x0, C = y0
        ld hl,(sp_ptr)
        ld a,19
        sub (hl)                    ; slack x = 18 - w (+1 for rand)
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,b
        inc a
        ld b,a                      ; prefab x
        inc hl
        ld a,10
        sub (hl)                    ; slack y = 9 - h
        jr nc,$+3
        xor a
        inc a
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,c
        ld c,a                      ; prefab y
        ld a,b
        ld (sp_x),a
        ld a,c
        ld (sp_y),a
        ; copy the cells
        ld hl,(sp_ptr)
        ld e,(hl)                   ; w
        inc hl
        ld d,(hl)                   ; h
        ld a,d
        ld (sp_h),a
        ld a,e
        ld (sp_w),a
        ld de,5
        ld hl,(sp_ptr)
        add hl,de
        ld (sp_src),hl
        ld a,(sp_x)
        ld b,a
        ld a,(sp_y)
        ld c,a
        ld a,(sp_h)
        ld d,a
.row:   push bc
        ld a,(sp_w)
        ld e,a
.col:   push de
        push bc
        call map_addr
        ld de,(sp_src)
        ld a,(de)
        inc de
        ld (sp_src),de
        cp 0C0h
        jr nc,.mark
        call set_tile
        jr .nx
.mark:  push af
        ld a,T_FLOOR
        call set_tile
        pop af
        pop bc
        push bc
        call pf_marker
.nx:    pop bc
        pop de
        inc b
        dec e
        jr nz,.col
        pop bc
        inc c
        dec d
        jr nz,.row
        ; the entrance: (x + ex, y + ey - 1); join from the room above
        ld hl,(sp_ptr)
        inc hl
        inc hl
        ld a,(sp_x)
        add a,(hl)
        ld e,a                      ; x2
        inc hl
        ld a,(sp_y)
        add a,(hl)
        dec a
        ld d,a                      ; y2
        pop bc                      ; C = cell
        ld a,c
        sub 3
        ld c,a
        call room_centre
        xor a                       ; across first, then down
        call dig
        ret

; prefab marker A (C1-C3 item slot, C8 monster, C9 boss, CA exit) at B, C
pf_marker:
        cp 0C8h
        jr z,.mon
        cp 0C9h
        jr z,.boss
        cp 0CAh
        jr z,.exit
        ; item slot: ZD_SLOTS + slot*3 + (A - C1)
        sub 0C1h
        ld e,a
        ld a,(sp_slot)
        ld d,a
        add a,a
        add a,d
        add a,e
        ld e,a
        ld d,0
        push ix
        add ix,de
        ld a,(ix+ZD_SLOTS)
        pop ix
        or a
        ret z
        ld d,a
        ld e,1                      ; quantity
        jp add_item
.mon:   ld b,4
        call rand_below
        ld e,a
        ld d,0
        push ix
        add ix,de
        ld a,(ix+ZD_POOL)
        pop ix
        jp spawn_monster
.boss:  ld a,M_KING
        jp spawn_monster
.exit:  ; the link whose place is this prefab slot + 1
        push bc
        ld a,(sp_slot)
        inc a
        ld d,a
        ld b,3
        ld hl,0
        push ix
.lk:    ld a,(ix+ZD_LINKS+1)
        cp d
        jr z,.found
        inc ix
        inc ix
        djnz .lk
        pop ix
        pop bc
        ret
.found: ld a,(ix+ZD_LINKS)
        pop ix
        pop bc
        push af
        call map_addr
        ld a,T_EXIT
        call set_tile
        pop af
        jp add_exit

; ---------------------------------------------------------------------
; doors where corridors enter rooms
make_doors:
        ld c,0
.r:     ld a,c
        call cell_kind
        jr nz,.n
        push bc
        call room_rec
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ; top and bottom rings: y = ry-1 and ry+h, x in rx..rx+w-1
        push bc
        push de
        dec c
        call .hring
        pop de
        pop bc
        push bc
        push de
        ld a,c
        add a,e
        ld c,a
        call .hring
        pop de
        pop bc
        ; left and right: x = rx-1 and rx+w, y in ry..ry+h-1
        push bc
        push de
        dec b
        call .vring
        pop de
        pop bc
        ld a,b
        add a,d
        ld b,a
        call .vring
        pop bc
.n:     inc c
        ld a,c
        cp 9
        jr c,.r
        ret
.hring: push bc
        call tile_at
        cp T_FLOOR
        jr nz,.hn
        dec b                       ; walls left and right?
        call tile_at
        inc b
        cp T_WALL
        jr nz,.hn
        inc b
        call tile_at
        dec b
        cp T_WALL
        jr nz,.hn
        call .maybe
.hn:    pop bc
        inc b
        dec d
        jr nz,.hring
        ret
.vring: push bc
        call tile_at
        cp T_FLOOR
        jr nz,.vn
        dec c
        call tile_at
        inc c
        cp T_WALL
        jr nz,.vn
        inc c
        call tile_at
        dec c
        cp T_WALL
        jr nz,.vn
        call .maybe
.vn:    pop bc
        inc c
        dec e
        jr nz,.vring
        ret
.maybe: call map_addr
        ld a,r
        and 3
        ret z                       ; 1 in 4: an open doorway
        ld a,T_DOOR
        jp set_tile

; ---------------------------------------------------------------------
; decoration by theme
decorate:
        ld c,0
.r:     ld a,c
        call cell_kind
        jp nz,.n
        ld a,c                      ; a hall is decorated once
        call own_addr
        ld a,(hl)
        inc a
        jp nz,.n
        push bc
        call room_rec
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld (dc_room),bc
        ld (dc_size),de
        ; columns, statues, a great brazier or a pool (rooms 9 x 5 up)
        ld a,e
        cp 5
        jr c,.small
        ld a,d
        cp 9
        jr c,.small
        cp 24
        jr c,.norm
        ld b,4                      ; halls: always set out, sparser
        call rand_below
        add a,a
        ld hl,LAYOUTS_BIG
        jr .lay2
.norm:  ld b,8
        call rand_below
        or a
        jr z,.small                 ; some rooms stay bare
        dec a
        jr nz,.lay
        ld a,(ix+ZD_STYLE)
        and ST_WATER|ST_LAVA
        jr z,.lay                   ; (no pool here: columns)
        call dc_pool
        jr .small
.lay:   add a,a
        ld hl,LAYOUTS
.lay2:  add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call dc_layout
.small: ; scatter
        bit 4,(ix+ZD_STYLE)
        ld a,T_FUNGUS
        ld b,5
        call nz,dc_scatter
        bit 7,(ix+ZD_STYLE)
        ld a,T_BONES
        ld b,2
        call nz,dc_scatter
        ld a,T_FLOOR2
        ld b,3
        call dc_scatter
        bit 6,(ix+ZD_STYLE)
        call nz,dc_books
        bit 5,(ix+ZD_STYLE)
        call nz,dc_crystal
        pop bc
.n:     inc c
        ld a,c
        cp 9
        jp c,.r
        ; wall lights: lcount of ltile in random rooms
        ld a,(ix+ZD_LCOUNT)
        or a
        ret z
        ld b,a
.wl:    push bc
        call rand_room
        ld a,(ix+ZD_LTILE)
        cp T_RUNE
        jr z,.rune
        call dc_walllight
        jr .wn
.rune:  ld b,1
        call dc_scatter
.wn:    pop bc
        djnz .wl
        ; braziers in a couple of rooms (built zones only)
        bit 0,(ix+ZD_STYLE)
        ret nz
        ld b,2
.br:    push bc
        call rand_room
        call dc_braziers
        pop bc
        djnz .br
        ret

; a random room cell: its room in dc_room/dc_size, the cell in A
rand_room:
.t:     ld b,9
        call rand_below
        ld c,a
        call cell_kind
        jr nz,.t
        push bc
        call room_rec
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld (dc_room),bc
        ld (dc_size),de
        pop bc
        ld a,c
        ret

; ---------------------------------------------------------------------
; room layouts: multi-cell objects (columns, statues, a great brazier)
; set out in grids, so the light casts fans of shadow between them.
; A layout is a list of (object, x offset, y offset, x step, y step),
; offset 0FFh = centred, ended by dw 0.  An object only goes where it and
; the ring of cells round it are floor, so every room stays connected.
dc_layout:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        ld b,(hl)                   ; x offset
        inc hl
        ld c,(hl)                   ; y offset
        inc hl
        push hl
        ex de,hl                    ; HL = object
        ld a,b
        inc a
        jr nz,.x
        ld a,(dc_size+1)
        sub (hl)
        srl a
        ld b,a
.x:     ld a,c
        inc a
        jr nz,.y
        inc hl
        ld a,(dc_size)
        sub (hl)
        dec hl
        srl a
        ld c,a
.y:     ex (sp),hl                  ; HL = steps
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ex (sp),hl                  ; HL = object, the next entry stacked
        call dc_grid
        pop hl
        jr dc_layout

; object HL in a grid over dc_room: the first at offset (B, C), then
; every D across and E down.  Keeps HL.
dc_grid:
        ld (dg_step),de
        ld a,(dc_room+1)
        add a,b
        ld (dg_x0),a
        ld a,(dc_room)
        add a,c
        ld c,a
.gy:    ld a,(dc_room)
        ld b,a
        ld a,(dc_size)
        add a,b
        ld b,a
        ld a,c
        cp b
        ret nc
        ld a,(dg_x0)
        ld b,a
.gx:    ld a,(dc_room+1)
        ld e,a
        ld a,(dc_size+1)
        add a,e
        ld e,a
        ld a,b
        cp e
        jr nc,.ny
        call place_obj
        ld a,(dg_step+1)
        add a,b
        ld b,a
        jr .gx
.ny:    ld a,(dg_step)
        add a,c
        ld c,a
        jr .gy

; put object HL (w, h, tiles) at (B, C) if it and its ring are all floor.
; Keeps BC, HL.
place_obj:
        push bc
        push hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl                     ; tiles
        dec b
        dec c
        inc d
        inc d
        inc e
        inc e
.cr:    push bc
        push de
.cc:    call tile_at
        call tile_flags
        and F_FLOORY
        jr z,.fail
        inc b
        dec d
        jr nz,.cc
        pop de
        pop bc
        inc c
        dec e
        jr nz,.cr
        pop de                      ; tiles
        pop hl
        pop bc
        push bc
        push hl
        ld a,(hl)
        ld (dg_w),a
        inc hl
        ld a,(hl)
        ex de,hl
        ld e,a                      ; rows
.sr:    push bc
        ld a,(dg_w)
        ld d,a
.sc:    push hl
        call map_addr
        ex (sp),hl
        ld a,(hl)
        inc hl
        ex (sp),hl
        call set_tile
        pop hl
        inc b
        dec d
        jr nz,.sc
        pop bc
        inc c
        dec e
        jr nz,.sr
        pop hl
        pop bc
        ret
.fail:  pop de
        pop bc
        pop hl
        pop hl
        pop bc
        ret

; the sun-stone on its stand, in a random room (with floor all round)
place_stone:
        ld b,40
.t:     push bc
        call rand_room
        call room_cell
        jr nz,.n
        ld hl,OB_STONE
        call place_obj
        call tile_at
        cp T_PEDLIT
        jr z,.ok
.n:     pop bc
        djnz .t
        ret
.ok:    pop bc
        ret

OB_STONE: db 1,1,T_PEDLIT
OB_PED: db 1,1,T_PEDESTAL
OB_COL: db 2,2,T_COLTL,T_COLTR,T_COLBL,T_COLBR
OB_BIG: db 3,3,T_COLTL,T_COLMID,T_COLTR,T_COLMID,T_COLMID,T_COLMID
        db T_COLBL,T_COLMID,T_COLBR
OB_STATUE: db 1,2,T_STATUE,T_STATUEB
OB_URN: db 2,2,T_URNTL,T_URNTR,T_URNBL,T_URNBR
LAYOUTS:
        dw LY_COLS,LY_STAND,LY_FOREST,LY_BIG,LY_STATUES,LY_URN,LY_SHRINE
LAYOUTS_BIG:
        dw LY_HYPO,LY_GIANT,LY_BSTAND,LY_NAVE
LY_GIANT:       dw OB_URN                   ; a great brazier among giants
                db 0FFh,0FFh,99,99
                dw OB_BIG
                db 2,2,8,7
                dw 0
LY_BSTAND:      dw OB_PED
                db 0FFh,0FFh,99,99
                dw OB_BIG
                db 3,2,9,6
                dw 0
LY_NAVE:        dw OB_URN                   ; two colonnades, statues between
                db 0FFh,0FFh,99,99
                dw OB_COL
                db 3,2,6,10
                dw OB_STATUE
                db 6,6,12,99
                dw 0
LY_HYPO:        dw OB_COL                   ; a forest of pillars
                db 2,2,5,5
                dw 0
LY_STAND:       dw OB_PED                   ; a stand for the sun-stone
                db 0FFh,0FFh,99,99
LY_COLS:        dw OB_COL
                db 1,1,4,4
                dw 0
LY_FOREST:      dw OB_COL
                db 1,1,3,3
                dw 0
LY_BIG:         dw OB_BIG
                db 2,1,5,5
                dw 0
LY_STATUES:     dw OB_STATUE
                db 1,1,3,4
                dw 0
LY_URN:         dw OB_URN
                db 0FFh,0FFh,99,99
                dw OB_COL
                db 1,1,4,4
                dw 0
LY_SHRINE:      dw OB_BIG
                db 0FFh,0FFh,99,99
                dw OB_STATUE
                db 1,1,3,4
                dw 0

; a pool two cells in from the walls
dc_pool:
        ld bc,(dc_room)
        ld de,(dc_size)
        inc b
        inc b
        inc c
        inc c
        dec d
        dec d
        dec d
        dec d
        dec e
        dec e
        dec e
        dec e
        ld a,e
        or a
        ret z
        ld a,d
        or a
        ret z
        ld a,T_WATER
        bit 2,(ix+ZD_STYLE)
        jr z,$+4
        ld a,T_LAVA
        ld (dc_pool.t+1),a
.row:   push bc
        push de
.col:   push bc
        call map_addr
        ld a,(hl)
        and 3Fh
        cp T_FLOOR
        jr nz,.sk
.t:   ld a,0
        call set_tile
.sk:    pop bc
        inc b
        dec d
        jr nz,.col
        pop de
        pop bc
        inc c
        dec e
        jr nz,.row
        ret

; B cells of tile A on random plain floor in the room
dc_scatter:
        ld (dc_scatter.t+1),a
.l:     push bc
        call room_cell
        jr nz,.n
.t:   ld a,0
        call set_tile
.n:     pop bc
        djnz .l
        ret

; HL = a random plain floor cell (B, C) in dc_room; Z if found
room_cell:
        ld e,12
.t:     push de
        ld bc,(dc_room)
        ld de,(dc_size)
        push bc
        ld b,d
        call rand_below
        pop bc
        add a,b
        ld b,a
        push bc
        ld b,e
        call rand_below
        pop bc
        add a,c
        ld c,a
        pop de
        call map_addr
        ld a,(hl)
        and 3Fh
        cp T_FLOOR
        jr nz,.no
        call occupied
        jr nz,.no
        call map_addr
        xor a
        ret
.no:    dec e
        jr nz,.t
        or 1
        ret

; library: shelves around the walls, a carpet down the middle
dc_books:
        ld bc,(dc_room)
        ld de,(dc_size)
        dec b
        dec c
        inc d
        inc d
        inc e
        inc e
        ld a,T_BOOKS
        call fill_rect_wall
        ld bc,(dc_room)
        ld de,(dc_size)
        ld a,e
        srl a
        add a,c
        ld c,a
        inc b
        dec d
        dec d
        ld e,1
        ld a,d
        or a
        ret z
        ld a,T_CARPET
.c:     push bc
        call map_addr
        ld a,(hl)
        and 3Fh
        cp T_FLOOR
        ld a,T_CARPET
        call z,set_tile
        pop bc
        inc b
        dec d
        jr nz,.c
        ret

; a crystal in the room's top wall
dc_crystal:
        ld a,T_CRYSTAL
; tile A in the wall above a random top-row cell of dc_room
dc_walllight:
        ld (dc_walllight.tt+1),a
        ld e,6
.try:   ld bc,(dc_room)
        ld a,(dc_size+1)            ; w
        push bc
        ld b,a
        call rand_below
        pop bc
        add a,b
        ld b,a
        dec c
        call tile_at
        cp T_WALL
        jr nz,.no
        ; not beside a doorway
        dec b
        call tile_at
        inc b
        cp T_WALL
        jr nz,.no
        inc b
        call tile_at
        dec b
        cp T_WALL
        jr nz,.no
        call map_addr
.tt:    ld a,0
        jp set_tile
.no:    dec e
        jr nz,.try
        ret

; two lit braziers at the room's inner top corners (if free)
dc_braziers:
        ld bc,(dc_room)
        ld de,(dc_size)
        ld a,d
        cp 6
        ret c
        ld a,e
        cp 4
        ret c
        inc b
        inc c
        call .b
        ld a,b
        add a,d
        sub 3
        ld b,a
.b:     push bc
        call map_addr
        ld a,(hl)
        and 3Fh
        cp T_FLOOR
        ld a,T_BRAZON
        call z,set_tile
        pop bc
        ret

; ---------------------------------------------------------------------
; exits: the zone's links that go in rooms
place_exits:
        ld b,0
.l:     push bc
        ld e,b
        ld d,0
        push ix
        add ix,de
        add ix,de
        ld a,(ix+ZD_LINKS)
        ld c,(ix+ZD_LINKS+1)
        pop ix
        cp 0FFh
        jr z,.n
        inc c
        dec c
        jr nz,.n                    ; prefab exits are placed by the stamp
        push af
.t:     call rand_room
        call room_cell
        jr nz,.t
        ld a,T_EXIT
        call set_tile
        pop af
        call add_exit
.n:     pop bc
        inc b
        ld a,b
        cp 3
        jr c,.l
        ret

; HL = the exit table of zone A (3 x x, y, dest)
exits_addr:
        ld l,a
        add a,a
        add a,a
        add a,a
        add a,l
        ld hl,zexits
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; record an exit to zone A at (B, C) in the current zone
add_exit:
        push af
        ld a,(zone)
        call exits_addr
        ld d,3
.f:     ld a,(hl)
        cp 0FFh
        jr z,.put
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        pop af
        ret
.put:   ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        pop af
        ld (hl),a
        ret

; ---------------------------------------------------------------------
place_monsters:
        ld b,(ix+ZD_MLO)
        ld c,(ix+ZD_MHI)
        call rand_range
        ld b,a
.l:     push bc
        ld b,4
        call rand_below
        ld e,a
        ld d,0
        push ix
        add ix,de
        ld a,(ix+ZD_POOL)
        pop ix
        ld (pm_type),a
        call mon_type               ; IY = type record
        ld a,(iy+MT_AI)
        cp AI_SWIM
        jr z,.swim
.t:     call rand_room
        call room_cell
        jr nz,.t
        call near_exit
        jr z,.t
        ld a,(pm_type)
        call spawn_monster
        jr .n
.swim:  call find_water
        jr nz,.n
        ld a,(pm_type)
        call spawn_monster
.n:     pop bc
        djnz .l
        ; the zone's resident
        ld a,(ix+ZD_NPC)
        or a
        ret z
        push af
.np:    call rand_room
        call room_cell
        jr nz,.np
        pop af
        jp spawn_monster

; Z if (B, C) is within 4 cells of an exit (or the start)
near_exit:
        push bc
        ld a,(zone)
        call exits_addr
        ld d,3
.l:     ld a,(hl)
        cp 0FFh
        jr z,.n
        sub b
        jr nc,$+4
        neg
        cp 5
        jr nc,.n
        inc hl
        ld a,(hl)
        dec hl
        sub c
        jr nc,$+4
        neg
        cp 5
        jr nc,.n
        pop bc
        xor a
        ret
.n:     inc hl
        inc hl
        inc hl
        dec d
        jr nz,.l
        pop bc
        or 1
        ret

; a random water cell -> B, C (Z if found)
find_water:
        ld e,60
.t:     ld b,62
        call rand_below
        inc a
        ld b,a
        push bc
        ld b,30
        call rand_below
        pop bc
        inc a
        ld c,a
        call tile_at
        cp T_WATER
        jr nz,.no
        call occupied
        jr nz,.no
        xor a
        ret
.no:    dec e
        jr nz,.t
        or 1
        ret

; items: loot and gold in random rooms, a chest or two
place_items:
        ld bc,4*256+6
        call rand_range
        ld b,a
.l:     push bc
.t:     call rand_room
        call room_cell
        jr nz,.t
        push bc
        ld b,4
        call rand_below
        ld e,a
        ld d,0
        push ix
        add ix,de
        ld a,(ix+ZD_LOOT)
        pop ix
        pop bc
        ld d,a
        call gold_qty
        call add_item
        pop bc
        djnz .l
        ld b,3
.g:     push bc
.gt:    call rand_room
        call room_cell
        jr nz,.gt
        ld d,I_GOLD
        call gold_qty
        call add_item
        pop bc
        djnz .g
        ; chests in rooms at an inner corner
        ld b,2
.c:     push bc
        call rand_room
        ld bc,(dc_room)
        ld de,(dc_size)
        ld a,d
        cp 5
        jr c,.cn
        ld a,e
        cp 4
        jr c,.cn
        ld a,c
        add a,e
        sub 2
        ld c,a
        ld a,b
        add a,d
        sub 2
        ld b,a
        call map_addr
        ld a,(hl)
        and 3Fh
        cp T_FLOOR
        jr nz,.cn
        ld a,T_CHEST
        call set_tile
.cn:    pop bc
        djnz .c
        ret

; E = quantity for item D (gold: 4..12 x (zone+1))
gold_qty:
        ld e,1
        ld a,d
        cp I_GOLD
        ret nz
        push bc
        ld bc,4*256+12
        call rand_range
        ld e,a
        ld a,(zone)
        inc a
        ld b,a
        xor a
.m:     add a,e
        djnz .m
        ld e,a
        pop bc
        ret
