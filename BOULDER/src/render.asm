; =====================================================================
;  render.asm - cave view, cave reveal / cover, HUD and messages
;
;  Every cave cell maps through ANIMIDX[(phase << 5) | element] to a
;  display index, and DISP_CH / DISP_AT give its character and colour.
;  SHADOW holds the display index on screen, so only cells whose look
;  changed are written to VRAM (CAVE + 1000h is the cell's VRAM address).
; =====================================================================

HUDROW          equ 0
MSGROW          equ 1
INFOROW         equ 24

; ---------------------------------------------------------------------
; patch_looks: point the run-time looks (space flash, magic wall,
; player) at the right entries for this frame's phase
; ---------------------------------------------------------------------
patch_looks:
        ld a,(anim)
        and 7
        ld c,a                      ; C = phase
        rrca
        rrca
        rrca
        ld b,a                      ; B = phase << 5
        ; space (flashes white when the exit opens)
        ld a,(flash)
        and 1
        ld a,LK_SPACE
        jr z,$+4
        ld a,LK_FLASH
        ld e,E_SPACE
        call .set
        ; magic wall
        ld a,(magic_state)
        cp 1
        ld a,LK_BRICK
        jr nz,$+4
        ld a,LK_MAGICON
        ld e,E_MAGIC
        call .set
        ; player
        ld a,(pl_moved)
        or a
        ld a,LK_PLTAP
        jr z,.pl
        ld a,(pl_face)
        cp 1
        ld a,LK_PLLEFT
        jr z,.pl
        ld a,LK_PLRIGHT
.pl:    ld e,E_PLAYER
; A = look (index * 8), E = element: ANIMIDX[B | E] = LOOKIDX[A + C]
.set:   add a,c
        ld l,a
        ld h,0
        push de
        ld de,LOOKIDX
        add hl,de
        pop de
        ld a,(hl)
        ld h,high ANIMIDX
        ld l,b
        ld d,a
        ld a,l
        or e
        ld l,a
        ld (hl),d
        ret

; ---------------------------------------------------------------------
; set_theme: A = theme; copy its look tables over ANIMIDX and LOOKIDX
; (keeps IX)
; ---------------------------------------------------------------------
set_theme:
        add a,a
        ld l,a
        ld h,0
        ld de,THEMETAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,ANIMIDX
        ld bc,256
        ldir
        ld de,LOOKIDX
        ld bc,LOOKSZ
        ldir
        jp shadow_reset             ; every cell must be redrawn

; ---------------------------------------------------------------------
; render: diff the window onto the cave against the shadow.
; HL = cave cell, DE = shadow (its VRAM cell is + 1000h, colour + 1800h),
; C = phase << 5, H' = high ANIMIDX (DISP_CH and DISP_AT are the next pages)
; ---------------------------------------------------------------------
        ASSERT high DISP_CH == high ANIMIDX + 1 && high DISP_AT == high ANIMIDX + 2
render:
        call patch_looks
        call view_follow
        ld a,(anim)
        and 7
        rrca
        rrca
        rrca
        ld c,a
        exx
        ld h,high ANIMIDX
        exx
        ld hl,(view_ptr)
        ld de,SHADOW
        ld a,VIEWH
.row:   push af
        push hl
        ld b,VIEWW
.cell:  ld a,(hl)
        and 1Fh
        or c
        exx
        ld l,a
        ld a,(hl)                   ; display index
        exx
        ex de,hl
        cp (hl)
        jr nz,.chg
.nx:    ex de,hl
        inc hl
        inc de
        djnz .cell
        call poll
        pop hl
        ld a,l                      ; down a row of the cave
        add a,CAVEW
        ld l,a
        jr nc,$+3
        inc h
        pop af
        dec a
        jr nz,.row
        ret
.chg:   ld (hl),a                   ; shadow
        exx
        ld l,a
        inc h
        ld a,(hl)                   ; character
        inc h
        ld e,(hl)                   ; colour
        dec h
        dec h
        exx
        set 4,h
        ld (hl),a
        exx
        ld a,e
        exx
        set 3,h
        ld (hl),a
        res 3,h
        res 4,h
        jr .nx

shadow_reset:
        ld hl,SHADOW
        ld de,SHADOW+1
        ld bc,VIEWSZ-1
        ld (hl),0FFh
        ldir
        ret

; ---------------------------------------------------------------------
; the window: it stays put until the player comes within SCRL cells of
; an edge, then glides a cell per frame until the player is GOAL cells in
; (or the cave's edge is reached)
; ---------------------------------------------------------------------
SCRL_X          equ 6
GOAL_X          equ 15
SCRL_Y          equ 4
GOAL_Y          equ 9

; D = player x, E = player y
pl_xy:
        ld hl,(pl_addr)
        ld de,-CAVE
        add hl,de
        ld a,l
        and CAVEW-1
        ld d,a
        add hl,hl
        add hl,hl
        ld e,h
        ret

; at cave start: the player as near the middle as the cave allows
view_init:
        call pl_xy
        ld a,d
        sub VIEWW/2
        jr nc,$+3
        xor a
        ld b,a
        ld a,(cave_w)
        sub VIEWW
        cp b
        jr c,.x
        ld a,b
.x:     ld (view_x),a
        ld a,e
        sub VIEWH/2
        jr nc,$+3
        xor a
        ld b,a
        ld a,(cave_h)
        sub VIEWH
        cp b
        jr c,.y
        ld a,b
.y:     ld (view_y),a
        xor a
        ld (glide_x),a
        ld (glide_y),a
view_ptr_set:
        ld a,(view_y)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(view_x)
        or l
        ld l,a
        ld de,CAVE
        add hl,de
        ld (view_ptr),hl
        ret

view_follow:
        call pl_xy
        ; across
        ld a,(view_x)
        ld b,a
        ld a,(glide_x)
        or a
        jr nz,.gx
        ld a,d
        sub b                       ; player's column on screen
        jr c,.sl
        cp SCRL_X
        jr c,.sl
        cp VIEWW-SCRL_X
        jr c,.y
        ld a,1
        jr .setx
.sl:    ld a,-1
.setx:  ld (glide_x),a
.gx:    dec a
        jr z,.right
        ld a,b                      ; left
        or a
        jr z,.stopx
        dec b
        ld a,b
        ld (view_x),a
        ld a,d
        sub b
        jr c,.y                     ; (still off the left edge)
        cp GOAL_X
        jr c,.y
        jr .stopx
.right: ld a,(cave_w)
        sub VIEWW
        cp b
        jr z,.stopx
        jr c,.stopx
        inc b
        ld a,b
        ld (view_x),a
        ld a,d
        sub b
        jr c,.stopx
        cp VIEWW-GOAL_X
        jr nc,.y
.stopx: xor a
        ld (glide_x),a
        ; up and down
.y:     ld a,(view_y)
        ld b,a
        ld a,(glide_y)
        or a
        jr nz,.gy
        ld a,e
        sub b                       ; player's row on screen
        jr c,.su
        cp SCRL_Y
        jr c,.su
        cp VIEWH-SCRL_Y
        jr c,.done
        ld a,1
        jr .sety
.su:    ld a,-1
.sety:  ld (glide_y),a
.gy:    dec a
        jr z,.down
        ld a,b                      ; up
        or a
        jr z,.stopy
        dec b
        ld a,b
        ld (view_y),a
        ld a,e
        sub b
        jr c,.done
        cp GOAL_Y
        jr c,.done
        jr .stopy
.down:  ld a,(cave_h)
        sub VIEWH
        cp b
        jr z,.stopy
        jr c,.stopy
        inc b
        ld a,b
        ld (view_y),a
        ld a,e
        sub b
        jr c,.stopy
        cp VIEWH-GOAL_Y
        jr nc,.done
.stopy: xor a
        ld (glide_y),a
.done:  jp view_ptr_set

; HL = shadow address -> DE = the cave cell shown there (keeps HL)
scr_cell:
        push hl
        ld de,-SHADOW
        add hl,de                   ; offset on the window
        ld de,(view_ptr)
.r:     ld a,h
        or a
        jr nz,.sub
        ld a,l
        cp VIEWW
        jr c,.col
.sub:   ld a,l
        sub VIEWW
        ld l,a
        jr nc,$+3
        dec h
        ld a,e
        add a,CAVEW
        ld e,a
        jr nc,$+3
        inc d
        jr .r
.col:   add a,e
        ld e,a
        jr nc,$+3
        inc d
        pop hl
        ret

; draw one window cell now: HL = shadow address (keeps HL)
cell_draw:
        call scr_cell
        ld a,(anim)
        and 7
        rrca
        rrca
        rrca
        ld c,a
        ld a,(de)
        and 1Fh
        or c
        ld e,a
        ld d,high ANIMIDX
        ld a,(de)
cell_put:                           ; A = display index, HL = shadow address
        ld (hl),a
        ld e,a
        ld d,high DISP_CH
        ld a,(de)
        set 4,h
        ld (hl),a
        inc d
        ld a,(de)
        set 3,h
        ld (hl),a
        res 3,h
        res 4,h
        ret

; cover one window cell: HL = shadow address
cell_cover:
        ld de,LOOKIDX+LK_COVER
        ld a,(de)
        call cell_put
        ld (hl),0FFh                ; force a redraw later
        ret

; next value of the 10-bit LFSR (1..1023) -> HL = shadow address or
; carry set if the value is outside the window
lfsr_cell:
        ld hl,(lfsr)
        srl h
        rr l
        jr nc,.n
        ld a,h
        xor 02h
        ld h,a
        ld a,l
        xor 40h
        ld l,a
.n:     ld (lfsr),hl
        ld de,VIEWSZ
        or a
        sbc hl,de
        ccf
        ret c
        add hl,de
        ld de,SHADOW
        add hl,de
        or a
        ret

; ---------------------------------------------------------------------
; reveal: cover the window, then uncover it cell by cell
; cover:  the reverse
; ---------------------------------------------------------------------
reveal:
        call cover_all
        ld hl,SFX_REVEAL
        ld a,1
        call sfx
        ld a,0
        jr dissolve

cover:
        ld hl,SFX_REVEAL
        ld a,1
        call sfx
        ld a,1
dissolve:
        ld (dis_mode),a
        ld hl,1
        ld (lfsr),hl
        ld hl,SHADOW
        call .one
        ld b,16                     ; 16 fields x 64 steps covers 1023
.f:     push bc
        ld b,64
.s:     push bc
        call lfsr_cell
        call nc,.one
        pop bc
        djnz .s
        call wait_field
        ld hl,anim
        inc (hl)
        pop bc
        djnz .f
        ret
.one:   ld a,(dis_mode)
        or a
        jp z,cell_draw
        jp cell_cover

cover_all:
        ld hl,SHADOW
        ld bc,VIEWSZ
.l:     push bc
        call cell_cover
        pop bc
        inc hl
        dec bc
        ld a,b
        or c
        jr z,.d
        ld a,c
        and 3Fh
        call z,poll
        jr .l
.d:     ret

; ---------------------------------------------------------------------
; HUD (row 0): need, value, collected, time, score, lives, cave/level
; ---------------------------------------------------------------------
hud_draw:
        xor a
        ld (hud_dirty),a
        ld de,VRAM+HUDROW*40+1
        ld a,44h                    ; diamond
        ld c,YELLOW*16
        call putc
        inc de
        ld a,(need)
        call print_dec2
        inc de
        ld a,44h
        ld c,WHITE*16
        call putc
        inc de
        ld a,(exit_open)
        or a
        ld a,(dval)
        jr z,$+5
        ld a,(xval)
        call print_dec2
        inc de
        inc de
        ld a,(exit_open)
        or a
        ld c,CYAN*16
        jr z,$+4
        ld c,GREEN*16
        ld a,(got)
        call print_dec2
        ; time
        ld de,VRAM+HUDROW*40+15
        ld hl,txt_time
        ld c,WHITE*16
        call print
        inc de
        ld a,(ctime)
        cp 10
        ld c,YELLOW*16
        jr nc,$+4
        ld c,RED*16
        call print_dec3
        ; score
        ld de,VRAM+HUDROW*40+25
        ld hl,score+2
        ld b,3
        ld c,WHITE*16
        call print_bcd
        ; lives
        ld de,VRAM+HUDROW*40+33
        ld a,44h
        ld c,YELLOW*16+80h          ; bank 2 figure
        call putc
        inc de
        ld a,(lives)
        add a,20h
        ld c,YELLOW*16
        call putc
        inc de
        inc de
        ; cave letter and level
        ld a,(cave_no)
        inc a
        ld c,CYAN*16
        call putc
        inc de
        ld a,2Dh                    ; '/'
        call putc
        inc de
        ld a,(level)
        add a,21h
        call putc
        ret

; A (0-99) as two digits at DE, attr C
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
        call putc
        inc de
        pop af
        add a,20h
        call putc
        inc de
        ret

; info row: cave letter and name (or the demo banner)
info_draw:
        ld a,INFOROW
        ld b,a
        ld c,1
        xor a
        call clear_rows
        ld a,(demo)
        or a
        jr z,.cave
        ld hl,txt_demo
        ld c,INFOROW
        ld a,MAGENTA*16
        jp print_centre
.cave:  ld hl,PBUF
        push hl
        ld de,txt_cave
        call strcpy
        ld a,(cave_no)
        add a,'A'
        ld (hl),a
        inc hl
        ld (hl),' '
        inc hl
        ld (hl),' '
        inc hl
        ex de,hl
        ld hl,(cave_hdr)
        ld bc,CH_NAME
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        call strcpy
        ld (hl),0
        pop hl
        ld c,INFOROW
        ld a,CYAN*16
        jp print_centre

; HL = dest, DE = source (0-terminated): copies without the 0, HL = end
strcpy:
        ld a,(de)
        or a
        ret z
        ld (hl),a
        inc hl
        inc de
        jr strcpy

; message row: HL = text, A = attr (HL = 0 clears)
msg_show:
        push af
        push hl
        ld b,MSGROW
        ld c,1
        xor a
        call clear_rows
        pop hl
        pop af
        ld c,MSGROW
        ld b,a
        ld a,h
        or l
        ret z
        ld a,b
        jp print_centre

msg_clear:
        ld hl,0
        jr msg_show
