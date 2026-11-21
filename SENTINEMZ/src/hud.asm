; =====================================================================
;  hud.asm - status rows 21-24, messages, effects, the island map
;
;  row 21  ENERGY nn  [bar]                         compass
;  row 22  what the cursor points at                (3 x 3, right)
;  row 23  messages
;  row 24  island, score, facing
; =====================================================================

HUD_ATTR        equ 70h             ; white on black
MSG_ROW         equ 23

hud_draw:
        ld b,HUD_ROW
        ld c,4
        ld a,HUD_ATTR
        call clear_rows
        call hud_energy
        call hud_info
        call hud_compass
        jp hud_target

hud_energy:
        ld bc,HUD_ROW*256+0
        call .at
        ld hl,TXT_ENERGY
        ld c,50h
        call print
        ld a,(energy)
        ld c,70h
        call print_dec2
        inc de
        ; bar: 2 units per cell, 22 cells
        ld a,(energy)
        ld c,50h                    ; cyan
        cp 5
        jr nc,.cl
        ld c,20h                    ; low: red
.cl:    ld h,a
        ld b,22
.b:     ld a,h
        cp 2
        jr c,.half
        dec h
        dec h
        ld a,43h
        jr .put
.half:  or a
        jr z,.put
        ld h,0
        ld a,7Bh                    ; left half
.put:   ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        djnz .b
        ret
.at:    ld a,b
        jp vaddr_bc
; DE = VRAM of (C = col, B = row)
vaddr_bc:
        push bc
        ld a,b
        ld b,c
        ld c,a
        call vaddr
        pop bc
        ret

hud_info:
        ld bc,24*256+0
        call vaddr_bc
        ld hl,TXT_ISLAND
        ld c,60h
        call print
        ld a,(island)
        ld c,70h
        call print_dec2
        inc de
        inc de
        ld hl,TXT_SCORE
        ld c,60h
        call print
        ld hl,(score)
        ld c,70h
        call print_dec5
        inc de
        inc de
        ld hl,TXT_KEYS
        ld a,(autoplay)
        or a
        jr z,.k
        ld hl,TXT_DEMOKEYS
.k:     ld c,40h
        jp print

; the 3 x 3 compass at the right of rows 21-23
COMPASS:        db 37,21, 38,21, 38,22, 38,23, 37,23, 36,23, 36,22, 36,21
hud_compass:
        ld hl,(ptile)               ; the player's sector, FFh if unseen
        call tf_addr
        ld a,(hl)
        bit 3,a
        ld a,0FFh
        jr z,.ps
        ld a,(hl)
        and 7
.ps:    ld (psec),a
        ld hl,COMPASS
        ld b,0
.s:     push bc
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        push bc
        ld b,a
        call vaddr_bc
        pop bc
        ld a,(beam)
        cp b
        ld a,2Eh                    ; '.'
        ld c,10h
        jr nz,.nb
        ld a,43h                    ; the beam: yellow block
        ld c,60h
.nb:    ld h,a
        ld a,(psec)
        cp b
        jr nz,.np
        ld h,0Fh                    ; 'O': you
        ld a,c
        cp 60h
        ld c,70h
        jr nz,.np
        ld c,72h                    ; white on red: in the light
.np:    ld a,h
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        pop hl
        pop bc
        inc b
        ld a,b
        cp 8
        jr c,.s
        ld bc,22*256+37             ; the Lantern in the middle
        call vaddr_bc
        ld a,6Bh                    ; '*'
        ld (de),a
        set 3,d
        ld a,(lit)
        or a
        ld a,60h
        jr z,$+4
        ld a,27h
        ld (de),a
        ret

; describe the cursor's target on row 22
hud_target:
        ld bc,(HUD_ROW+1)*256+0
        call vaddr_bc
        push de
        ld b,35
        ld a,HUD_ATTR
        call fill_blank
        pop de
        ld a,(tgt_kind)
        or a
        ld hl,TT_NONE
        jr z,.pr
        ld a,(tgt_ok)
        or a
        ld hl,TT_UNSEEN
        jr z,.pr
        ld hl,(tgt_t)
        ld bc,(ptile)
        or a
        sbc hl,bc
        ld hl,TT_OWN
        jr z,.pr
        ld hl,(tgt_t)
        call obj_addr
        ld a,(hl)
        and 7
        jr z,.ground
        ld hl,TT_SHARD
        dec a
        jr z,.pr
        ld hl,TT_SHELL
        dec a
        jr z,.pr
        ld hl,TT_LANTERN
        dec a
        jr z,.pr
        ld hl,TT_WISP
        jr .pr
.ground:
        ld a,(hl)
        or a
        ld hl,TT_CAIRN
        jr nz,.pr
        ld hl,(tgt_t)
        call tf_addr
        bit 4,(hl)
        ld hl,TT_FLAT
        jr nz,.pr
        ld hl,TT_SLOPE
.pr:    ld c,HUD_ATTR
        jp print

; B = count, A = attr: blank cells from DE
fill_blank:
        ld c,a
.l:     xor a
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        djnz .l
        ret

; show message HL on row 23 for 3 seconds
hud_msg:
        ld a,150
        ld (msg_t),a
hud_msg_now:
        push hl
        ld bc,MSG_ROW*256+0
        call vaddr_bc
        ld b,35
        ld a,HUD_ATTR
        push de
        call fill_blank
        pop de
        pop hl
        ld c,HUD_ATTR
        jp print

hud_tick:
        ld a,(msg_t)
        or a
        ret z
        dec a
        ld (msg_t),a
        ret nz
        ld hl,MSG_EMPTY
        call hud_msg_now
        jp hud_info

; A (0..99) -> 2 digits at DE, attr C
print_dec2:
        ld b,0
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     push af
        ld a,b
        add a,20h
        call .put
        pop af
        add a,20h
.put:   ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        ret

; HL (0..65535) -> 5 digits at DE, attr C
print_dec5:
        ld a,c
        ld (p5attr),a
        push bc
        ld bc,-10000
        call .d
        ld bc,-1000
        call .d
        ld bc,-100
        call .d
        ld bc,-10
        call .d
        ld bc,-1
        call .d
        pop bc
        ret
.d:     ld a,1Fh
.l:     inc a
        add hl,bc
        jr c,.l
        sbc hl,bc
        ld (de),a
        set 3,d
        ld a,(p5attr)
        ld (de),a
        res 3,d
        inc de
        ret

; ---------------------------------------------------------------------
; effects
; ---------------------------------------------------------------------
; sparkle over the target: its object's box, or the cursor cell
fx_target_sparkle:
        ld a,(ccx)
        dec a
        jp p,$+4
        xor a
        ld (fx_x0),a
        add a,2
        ld (fx_x1),a
        ld a,(ccy)
        sub 2
        jp p,$+4
        xor a
        ld (fx_y0),a
        add a,3
        ld (fx_y1),a
        ld a,(tgt_kind)
        cp 2
        jr nz,fx_sparkle
        ld a,(nobj)                 ; find the target's list entry
        or a
        jr z,fx_sparkle
        ld b,a
        xor a
.f:     push af
        push bc
        call ol_addr
        push hl
        pop ix
        ld de,(tgt_t)
        ld a,(ix+OL_T)
        cp e
        jr nz,.nx
        ld a,(ix+OL_T+1)
        cp d
        jr nz,.nx
        ld a,(ix+OL_BX)
        cp 0FFh
        jr z,.nx
        srl a
        ld (fx_x0),a
        ld a,(ix+OL_BX+1)
        srl a
        ld (fx_y0),a
        ld a,(ix+OL_BX+2)
        srl a
        ld (fx_x1),a
        ld a,(ix+OL_BX+3)
        srl a
        ld (fx_y1),a
        pop bc
        pop af
        jr fx_sparkle
.nx:    pop bc
        pop af
        inc a
        djnz .f
; random dotted glyphs in the box (cells fx_x0..fx_x1, fx_y0..fx_y1)
fx_sparkle:
        call cursor_hide
        ld a,14
        ld (fx_t),a
.fr:    ld a,(fx_y0)
        ld c,a
.r:     ld a,(fx_x0)
        ld b,a
.c:     push bc
        call vaddr
        call rand
        and 0Fh
        or 0F0h
        ld (de),a
        set 3,d
        call rand
        and 70h
        or 10h
        ld (de),a
        pop bc
        inc b
        ld a,(fx_x1)
        cp b
        jr nc,.c
        inc c
        ld a,(fx_y1)
        cp c
        jr nc,.r
        call wait_field
        ld hl,fx_t
        dec (hl)
        jr nz,.fr
        ret

; transfer: the view dissolves
fx_wipe:
        call cursor_hide
        xor a
        ld (fx_x0),a
        ld (fx_y0),a
        ld a,39
        ld (fx_x1),a
        ld a,VIEW_ROWS-1
        ld (fx_y1),a
        ld a,3
        ld (fx_t),a
        call fx_sparkle.fr
        ld a,BLACK
        ld hl,ARAM
        ld b,VIEW_ROWS
.r:     push bc
        ld b,40
.c:     ld (hl),0
        inc hl
        djnz .c
        call wait_field
        pop bc
        djnz .r
        ret

; white flash over the view
fx_flash:
        ld a,77h
        call .fill
        ld a,4
        call wait_fields
        ld a,66h
        call .fill
        ld a,4
        call wait_fields
        ld a,22h
        call .fill
        ld a,6
        jp wait_fields
.fill:  ld hl,ARAM
        ld bc,VIEW_ROWS*40
.l:     ld (hl),a
        inc hl
        dec bc
        ld e,a
        ld a,b
        or c
        ld a,e
        jr nz,.l
        ret

; energy row flashes red
fx_drain:
        ld bc,HUD_ROW*256+0
        call vaddr_bc
        set 3,d
        ld b,40
.l:     ld a,72h
        ld (de),a
        inc de
        djnz .l
        ld a,3
        call wait_fields
        jp hud_energy

; ---------------------------------------------------------------------
; the island map (M): one tile per half cell, 32 x 16 cells
; ---------------------------------------------------------------------
show_map:
        call cursor_hide
        ld a,BLACK
        ld b,0
        ld c,VIEW_ROWS
        call clear_rows
        ld hl,TXT_MAP
        ld c,1
        ld a,70h
        call print_centre
        ld a,2                      ; rows 2..17, cols 4..35
        ld (mrow),a
        xor a
        ld (mty),a
.r:     ld a,(mrow)
        ld c,a
        ld b,4
        call vaddr
        xor a
        ld (mtx),a
.c:     push de
        ld a,(mtx)
        ld e,a
        ld a,(mty)
        ld d,a
        call map_col                ; top tile
        ld b,a
        inc d
        call map_col                ; bottom tile
        ld c,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or c
        ld c,a
        pop de
        ld a,7Ah
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        ld hl,mtx
        inc (hl)
        ld a,(hl)
        cp 32
        jr c,.c
        call poll
        ld hl,mty
        inc (hl)
        inc (hl)
        ld hl,mrow
        inc (hl)
        ld a,(hl)
        cp 18
        jr c,.r
        ld hl,TXT_MAPKEY
        ld c,19
        ld a,70h
        call print_centre
        ld hl,TXT_MAPKEY2
        ld c,20
        ld a,70h
        call print_centre
        call wait_release
.w:     call poll
        call anykey
        jr z,.w
        call wait_release
        xor a
        ld (lastletter),a
        ld (cur_on),a
        ld a,1
        ld (need_render),a
        ret
; A = map colour of tile (E = tx, D = ty)
map_col:
        push bc
        push de
        call tile_of
        ld de,(ptile)
        or a
        sbc hl,de
        add hl,de
        ld a,WHITE
        jr z,.x
        push hl
        call obj_addr
        ld a,(hl)
        pop hl
        and 7
        jr z,.gr
        ld c,a
        ld b,0
        push hl
        ld hl,MAPOBJ-1
        add hl,bc
        ld a,(hl)
        pop hl
        jr .x
.gr:    push hl
        call obj_addr
        ld a,(hl)
        pop hl
        or a
        ld a,RED                    ; cairns
        jr nz,.x
        push hl
        call tf_addr
        ld a,(hl)
        pop hl
        and 0Fh
        ld c,a
        ld a,(beam)
        or 8
        cp c
        ld a,YELLOW
        jr z,.x
        call tile_centre
        ld a,(hl)
        cp 4
        ld a,BLUE
        jr c,.x
        ld a,(hl)
        and 2
        ld a,CYAN                   ; slopes
        jr nz,.x
        ld a,GREEN
.x:     pop de
        pop bc
        ret
MAPOBJ: db MAGENTA,WHITE,RED,MAGENTA   ; shard, shell, Lantern, wisp
