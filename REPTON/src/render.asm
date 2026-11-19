; =====================================================================
;  render.asm - the scrolling 20 x 12 tile view, HUD and messages
;
;  Every tile is 2 x 2 character cells.  CUR[element] is this frame's look
;  index; LKTAB holds, for each look, the four characters and colours (8
;  pages: char TL, attr TL, char TR, attr TR, BL, BR).  SHADOW keeps the
;  look on screen for every tile, so only tiles whose look changed are
;  written to VRAM - when the view scrolls, runs of earth, wall and space
;  that line up stay put.
; =====================================================================

HUDROW          equ 0

; ---------------------------------------------------------------------
; build_cur: CUR = ANIM row for this phase, then the themed elements, the
; player and the gate
; ---------------------------------------------------------------------
build_cur:
        ld a,(anim)
        and 7
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; phase * 64
        ld de,ANIM
        add hl,de
        ld de,CUR
        ld bc,64
        ldir
        ; themed elements
        ld a,(theme)
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,THEMELK
        add hl,de
        ld de,THEMED_E
        ld b,NTHEMED
.th:    ld a,(de)
        inc de
        push de
        ld e,a
        ld d,high CUR
        ld a,(hl)
        inc hl
        ld (de),a
        pop de
        djnz .th
        ; player
        ld a,(pl_dead)
        or a
        ld a,LK_PLDEAD
        jr nz,.pl
        ld a,(pl_moved)
        or a
        ld a,LK_PLIDLE
        jr z,.pl
        ld a,(pl_face)
        or a
        ld a,LK_PLLEFT
        jr z,.pl
        ld a,(pl_face)
        cp 2
        ld a,LK_PLRIGHT
        jr z,.pl
        ld a,LK_PLUP
.pl:    ld e,E_PLAYER
        call .extra
        ld a,(done_flag)
        or a
        ld a,LK_GATESHUT
        jr z,.g
        ld a,LK_GATEOPEN
.g:     ld e,E_GATE
; CUR[E] = ANIMX[A + phase]
.extra: ld b,a
        ld a,(anim)
        and 7
        add a,b
        ld l,a
        ld h,0
        ld bc,ANIMX
        add hl,bc
        ld a,(hl)
        ld d,high CUR
        ld (de),a
        ret

; ---------------------------------------------------------------------
; camera: keep the player in the middle of the view (clamped)
; ---------------------------------------------------------------------
camera:
        ld de,(pl_pos)
        ld a,e
        and 1Fh
        sub VIEWW/2
        jr nc,$+3
        xor a
        cp RW-VIEWW+1
        jr c,$+4
        ld a,RW-VIEWW
        ld (cam_x),a
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
        or b                        ; player y
        sub VIEWH/2
        jr nc,$+3
        xor a
        cp RH-VIEWH+1
        jr c,$+4
        ld a,RH-VIEWH
        ld (cam_y),a
        ; cam_ptr = rbase + cam_y * 32 + cam_x
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(cam_x)
        ld e,a
        ld d,0
        add hl,de
        ld de,(rbase)
        add hl,de
        ld (cam_ptr),hl
        ret

; ---------------------------------------------------------------------
; render: diff the view against SHADOW, draw the tiles that changed
; ---------------------------------------------------------------------
render:
        call build_cur
        ld hl,(cam_ptr)
        ld de,SHADOW
        ld b,high CUR
        ld ixh,VIEWH
.row:   ld ixl,VIEWW
.tile:  ld a,(hl)
        and 3Fh
        ld c,a
        ld a,(bc)                   ; look index
        ex de,hl
        cp (hl)
        jr nz,.chg
        ex de,hl
.nx:    inc hl
        inc de
        dec ixl
        jr nz,.tile
        push de
        ld de,RW-VIEWW
        add hl,de
        pop de
        call poll
        dec ixh
        jr nz,.row
        ret
.chg:   ld (hl),a                   ; shadow
        ex de,hl
        push bc
        push de
        push hl
        ld c,a
        ; VRAM address: VROWS[row] + 2 * column
        ld a,VIEWH
        sub ixh
        add a,a
        ld l,a
        ld h,0
        ld de,VROWS
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,VIEWW
        sub ixl
        add a,a
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld a,c
        call draw_tile
        pop hl
        pop de
        pop bc
        jr .nx

; draw look A with its top-left cell at VRAM address DE
draw_tile:
        ld l,a
        ld h,high LKTAB
        ld a,(hl)                   ; TL
        ld (de),a
        inc h
        ld a,(hl)
        set 3,d
        ld (de),a
        res 3,d
        inc de
        inc h
        ld a,(hl)                   ; TR
        ld (de),a
        inc h
        ld a,(hl)
        set 3,d
        ld (de),a
        res 3,d
        ld a,e
        add a,39
        ld e,a
        jr nc,$+3
        inc d
        inc h
        ld a,(hl)                   ; BL
        ld (de),a
        inc h
        ld a,(hl)
        set 3,d
        ld (de),a
        res 3,d
        inc de
        inc h
        ld a,(hl)                   ; BR
        ld (de),a
        inc h
        ld a,(hl)
        set 3,d
        ld (de),a
        res 3,d
        ret

VROWS:
        dw VRAM+VIEWTOP*40+0*80, VRAM+VIEWTOP*40+1*80, VRAM+VIEWTOP*40+2*80, VRAM+VIEWTOP*40+3*80
        dw VRAM+VIEWTOP*40+4*80, VRAM+VIEWTOP*40+5*80, VRAM+VIEWTOP*40+6*80, VRAM+VIEWTOP*40+7*80
        dw VRAM+VIEWTOP*40+8*80, VRAM+VIEWTOP*40+9*80, VRAM+VIEWTOP*40+10*80, VRAM+VIEWTOP*40+11*80

shadow_reset:
        ld hl,SHADOW
        ld de,SHADOW+1
        ld bc,VIEWW*VIEWH-1
        ld (hl),0FFh
        ldir
        ret

; ---------------------------------------------------------------------
; dissolve: cover the view tile by tile in a random-looking order
; (A = 0 cover with the cover look, 1 = reveal by forcing redraws)
; ---------------------------------------------------------------------
cover_view:
        ld hl,1
        ld (lfsr),hl
        ld b,16
.f:     push bc
        ld b,16
.s:     push bc
        call lfsr_tile
        jr c,.sk
        push hl
        ld a,(CUR+E_COVER)
        ld (hl),0FFh                ; forces a redraw later
        ld c,a
        call tile_vaddr
        ld a,c
        call draw_tile
        pop hl
.sk:    pop bc
        djnz .s
        call wait_field
        pop bc
        djnz .f
        ret

; reveal the view tile by tile
reveal_view:
        call build_cur
        ld hl,1
        ld (lfsr),hl
        ld b,16
.f:     push bc
        ld b,16
.s:     push bc
        call lfsr_tile
        jr c,.sk
        push hl
        ; look of the map tile under this shadow cell
        call tile_mapaddr           ; HL = map cell
        ld a,(hl)
        and 3Fh
        ld e,a
        ld d,high CUR
        ld a,(de)
        pop hl
        push hl
        ld (hl),a
        ld c,a
        call tile_vaddr
        ld a,c
        call draw_tile
        pop hl
.sk:    pop bc
        djnz .s
        call wait_field
        ld hl,anim
        inc (hl)
        pop bc
        djnz .f
        ret

; 8-bit LFSR over 1..255; HL = SHADOW + value - 1, carry if >= 240
lfsr_tile:
        ld a,(lfsr)
        srl a
        jr nc,.n
        xor 0B8h
.n:     ld (lfsr),a
        dec a
        cp VIEWW*VIEWH
        ccf
        ret c
        ld l,a
        ld h,high SHADOW
        or a
        ret

; HL = SHADOW cell -> DE = its VRAM address (keeps HL, C)
tile_vaddr:
        push hl
        ld a,l                      ; index 0..239 (SHADOW is page aligned)
        ld b,0
.d:     cp VIEWW
        jr c,.m
        sub VIEWW
        inc b
        jr .d
.m:     add a,a
        push af
        ld a,b
        add a,a
        ld l,a
        ld h,0
        ld de,VROWS
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop af
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        pop hl
        ret

; HL = SHADOW cell -> HL = map cell under it
tile_mapaddr:
        ld a,l
        ld b,0
.d:     cp VIEWW
        jr c,.m
        sub VIEWW
        inc b
        jr .d
.m:     ld e,a
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,0
        add hl,de
        ld de,(cam_ptr)
        add hl,de
        ret

; ---------------------------------------------------------------------
; HUD (row 0): gems left, pieces found, monsters left, region name /
; a message for a few seconds
; ---------------------------------------------------------------------
hud_draw:
        xor a
        ld (hud_dirty),a
        ld de,VRAM+HUDROW*40
        ld b,40
        ld a,BLUE*16+BLACK
        push de
        call fill_attr
        pop de
        ; gems left
        ld a,44h
        ld c,CYAN*16
        call putc
        inc de
        ld hl,(gems_left)
        ld c,WHITE*16
        call print_dec3w
        inc de
        ; pieces found / total
        ld a,4Eh
        ld c,YELLOW*16
        call putc
        inc de
        ld a,(pieces_left)
        ld b,a
        ld a,TOTAL_PIECES
        sub b
        ld c,WHITE*16
        call print_dec2
        ld a,2Dh
        call putc
        inc de
        ld a,TOTAL_PIECES
        call print_dec2
        inc de
        ; monsters left
        ld a,2Fh
        ld c,MAGENTA*16+80h         ; second bank glyph
        call putc
        inc de
        ld a,(mons_left)
        ld c,WHITE*16
        call print_dec2
        inc de
        ; region name or message
        ld a,(msg_time)
        or a
        jr nz,.msg
        ld a,(region)
        call region_hdr
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,GREEN*16
        jr .txt
.msg:   ld hl,(msg_ptr)
        ld c,YELLOW*16
.txt:   push de
        ; clear the rest of the row first
        push hl
        ld h,d
        ld l,e
        ld b,40-16
.cl:    ld (hl),0
        inc hl
        djnz .cl
        pop hl
        pop de
        jp print

; msg_set: HL = message for the HUD (shown for about 3 seconds)
msg_set:
        ld (msg_ptr),hl
        ld a,75
        ld (msg_time),a
        ld a,1
        ld (hud_dirty),a
        ret

; count the message down once per frame
msg_tick:
        ld a,(msg_time)
        or a
        ret z
        dec a
        ld (msg_time),a
        ret nz
        ld a,1
        ld (hud_dirty),a
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

; HL (0-999) as three digits at DE, attr C
print_dec3w:
        ld b,0
.h:     push de
        ld de,100
        or a
        sbc hl,de
        pop de
        jr c,.h1
        inc b
        jr .h
.h1:    push de
        ld de,100
        add hl,de
        pop de
        ld a,b
        add a,20h
        call putc
        inc de
        ld a,l
        jr print_dec2
