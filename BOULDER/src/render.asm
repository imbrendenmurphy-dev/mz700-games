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
; render: diff the whole cave against the shadow
; ---------------------------------------------------------------------
render:
        call patch_looks
        ld a,(anim)
        and 7
        rrca
        rrca
        rrca
        ld c,a
        ld hl,CAVE
        ld d,high ANIMIDX
        ld a,CAVEH
.row:   push af
        ld b,CAVEW
.cell:  ld a,(hl)
        and 1Fh
        or c
        ld e,a
        ld a,(de)                   ; display index
        set 2,h
        cp (hl)
        jr nz,.chg
        res 2,h
.nx:    inc hl
        djnz .cell
        call poll
        pop af
        dec a
        jr nz,.row
        ret
.chg:   ld (hl),a                   ; shadow
        res 2,h
        ld e,a
        ld d,high DISP_CH
        ld a,(de)
        set 4,h                     ; VRAM
        ld (hl),a
        inc d
        ld a,(de)
        set 3,h                     ; colour RAM
        ld (hl),a
        res 3,h
        res 4,h
        ld d,high ANIMIDX
        jr .nx

shadow_reset:
        ld hl,SHADOW
        ld de,SHADOW+1
        ld bc,CAVESZ-1
        ld (hl),0FFh
        ldir
        ret

; draw one cell now: HL = cave address (keeps HL)
cell_draw:
        ld a,(anim)
        and 7
        rrca
        rrca
        rrca
        ld e,a
        ld a,(hl)
        and 1Fh
        or e
        ld e,a
        ld d,high ANIMIDX
        ld a,(de)
cell_put:                           ; A = display index
        set 2,h
        ld (hl),a
        res 2,h
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

; cover one cell: HL = cave address
cell_cover:
        ld de,LOOKIDX+LK_COVER
        ld a,(de)
        call cell_put
        set 2,h
        ld (hl),0FFh                ; force a redraw later
        res 2,h
        ret

; next value of the 10-bit LFSR (1..1023) -> HL = cave address or
; carry set if the value is outside the cave
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
        ld de,CAVESZ
        or a
        sbc hl,de
        ccf
        ret c
        add hl,de
        ld de,CAVE
        add hl,de
        or a
        ret

; ---------------------------------------------------------------------
; reveal: cover the cave area, then uncover it cell by cell
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
        ld hl,CAVE
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
        ld hl,CAVE
        ld bc,CAVESZ
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
