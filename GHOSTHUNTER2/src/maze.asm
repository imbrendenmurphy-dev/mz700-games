; =====================================================================
;  maze.asm - maze grid, cell drawing, maze setup
;
;  GRID: code per character (C_ codes), 21 rows of 64 bytes.
;  CLS:  colour class per character (= code, or CL_INNER for wall
;        interiors), same layout at GRID+600h.
;  LOOK: wall/door glyph per character at GRID+0C00h.
;  Grid (x, y) is on screen at column x-1, row y+1; x 1..39 and y 1..19
;  are visible (x 0 and 40 are the hidden ends of the tunnels).
; =====================================================================

; HL = GRID + C*64 + B.  Keeps BC, DE.
grid_addr:
        ld a,c
        rrca
        rrca
        ld l,a
        and 3Fh
        add a,high GRID
        ld h,a
        ld a,l
        and 0C0h
        or b
        ld l,a
        ret

; cell_at: B = x (-1 and 41 wrap round), C = y -> A = code, HL = grid
; address.  Rows outside the maze count as wall.  Keeps C, DE.
cell_at:
        ld a,c
        cp GH
        jr c,.y
        ld a,C_WALL
        ret
.y:     ld a,b
        cp GW
        jr c,.x
        cp 0F0h
        ld a,0
        jr c,.w
        ld a,GW-1
.w:     ld b,a
.x:     call grid_addr
        ld a,(hl)
        ret

; neighbour: B, C = cell, A = direction -> B, C = next cell, A = code
neighbour:
        push de
        ld e,a
        ld d,0
        ld hl,dxtab
        add hl,de
        ld a,b
        add a,(hl)
        ld b,a
        ld hl,dytab
        add hl,de
        ld a,c
        add a,(hl)
        ld c,a
        pop de
        jr cell_at

dxtab:  db 1,-1,0,0
dytab:  db 0,0,-1,1

; passable code?  A -> carry set if an actor may walk there
passable:
        cp 3
        ret c
        cp 6
        ccf
        ret

; cell_put: B = x, C = y (visible) -> glyph and attribute from the class
; tables, written to the background.  Returns HL = VRAM address,
; D = char, E = attr.  Keeps BC.
cell_put:
        call grid_addr
        ld a,h
        add a,6
        ld h,a
        ld e,(hl)                   ; class
        ld a,h
        add a,6
        ld h,a
        ld d,(hl)                   ; look
        ld hl,CLSG
        ld a,l
        add a,e
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        or a
        jr z,.lk
        ld d,a
.lk:    ld hl,PALCUR
        ld a,l
        add a,e
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        call grid_scr
        push hl
        res 6,h
        ld (hl),d
        set 3,h
        ld (hl),e
        pop hl
        ret

; set the class (and code) of cell B, C to A and show it next frame
cell_set:
        push af
        call grid_addr
        pop af
        ld (hl),a
        push af
        ld a,h
        add a,6
        ld h,a
        pop af
        ld (hl),a
        call grid_vis
        ret c
        call cell_put
        jp dirty_add

; redraw cell B, C next frame (class unchanged)
cell_refresh:
        call grid_vis
        ret c
        call cell_put
        jp dirty_add

; ---------------------------------------------------------------------
; setup_maze: build maze (mazeidx) into the grid, background and screen
setup_maze:
        ld a,(mazeidx)
        add a,a
        ld e,a
        ld d,0
        ld hl,MAZETAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)
        ld (mstyle),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (mname),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pal_norm),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pal_power),de
        ; classes -> CLS (GRID+600h)
        ld a,6
        call .copy
        ld a,0Ch                    ; looks -> LOOK
        call .copy
        ; codes from classes
        ld hl,CLS
        ld de,GRID
        ld bc,GH*64
.g:     ld a,(hl)
        cp CL_INNER
        jr nz,$+4
        ld a,C_WALL
        ld (de),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.g
        ; buffet: no pellets at all
        ld a,(roundtype)
        cp 1
        jr nz,.nb
        ld hl,GRID
        ld bc,GH*64
.b:     ld a,(hl)
        cp C_PELLET
        jr z,.b0
        cp C_ENERG
        jr nz,.b1
.b0:    xor a
        ld (hl),a
        ld a,h
        add a,6
        ld h,a
        ld (hl),0
        ld a,h
        sub 6
        ld h,a
.b1:    inc hl
        dec bc
        ld a,b
        or c
        jr nz,.b
.nb:    ; count pellets, list energisers and teleporters
        ld hl,0
        ld (pellets),hl
        ld (eaten),hl
        xor a
        ld (ntele),a
        ld (nenerg),a
        ld c,0
.cy:    ld b,0
.cx:    call grid_addr
        ld a,(hl)
        cp C_PELLET
        jr z,.pel
        cp C_ENERG
        jr nz,.n2
        ld hl,nenerg
        ld a,(hl)
        cp 8
        jr nc,.pel
        inc (hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,energ_list
        add hl,de
        ld (hl),b
        inc hl
        ld (hl),c
.pel:   ld hl,(pellets)
        inc hl
        ld (pellets),hl
        jr .nx
.n2:    cp C_TELE
        jr nz,.nx
        ld hl,ntele
        ld a,(hl)
        cp 4
        jr nc,.nx
        inc (hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,tele_list
        add hl,de
        ld (hl),b
        inc hl
        ld (hl),c
.nx:    inc b
        ld a,b
        cp GW
        jr nz,.cx
        inc c
        ld a,c
        cp GH
        jr nz,.cy
        ld hl,(pellets)
        ld (pellets_total),hl
        ; palette and glyphs
        ld hl,(pal_norm)
        ld de,PALCUR
        ld bc,9
        ldir
        xor a
        ld (palette),a
        ld (rc_row),a
        ld hl,clsg_init
        ld de,CLSG
        ld bc,9
        ldir
        ; draw it
        ld c,1
.dy:    ld b,1
.dx:    call cell_put
        inc b
        ld a,b
        cp 40
        jr nz,.dx
        call poll
        inc c
        ld a,c
        cp 20
        jr nz,.dy
        ret

; copy 21 rows of 41 bytes from HL to GRID + A*256 + row*64; HL advances
.copy:  ld (.hi+1),a
        ld c,0
.cr:    push hl
        ld b,0
        call grid_addr
        ld a,h
.hi:    add a,0
        ld h,a
        ex de,hl
        pop hl
        push bc
        ld bc,GW
        ldir
        pop bc
        inc c
        ld a,c
        cp GH
        jr nz,.cr
        ret

clsg_init:
        db 0, 85h, 86h, 0, 0, 0, 84h, 0, 0

; energisers: show (energvis = 1) or hide
draw_energisers:
        ld a,(energvis)
        or a
        ld a,86h
        jr nz,$+3
        xor a
        ld (CLSG+C_ENERG),a
        ld a,(nenerg)
        or a
        ret z
        ld hl,energ_list
.l:     push af
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call cell_at
        cp C_ENERG
        call z,cell_refresh
        pop hl
        pop af
        dec a
        jr nz,.l
        ret

; teleporters: two looks
draw_teleporters:
        ld a,(televis)
        or a
        ld a,84h
        jr z,$+4
        ld a,8Dh
        ld (CLSG+C_TELE),a
        ld a,(ntele)
        or a
        ret z
        ld hl,tele_list
.l:     push af
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call cell_refresh
        pop hl
        pop af
        dec a
        jr nz,.l
        ret
