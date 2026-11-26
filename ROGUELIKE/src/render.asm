; =====================================================================
;  render.asm - one frame of the play view (rows 0-19)
;
;  1. light_pass   LVL[i] = brightest of the static light and the
;                  player's torch, for cells the player sees (bit 3 set)
;  2. dyn_lights   spells, glowing monsters, flares and the beam
;  3. overlays     items, monsters, the player, particles -> OVA/OVG
;  4. compose      tile looks + overlays, written to VRAM only where the
;                  screen differs from SCH/SAT
;
;  The view buffers are 800 bytes each in 1K slots (80xx LVL, 84xx OVA,
;  88xx OVG, 8Cxx SCH, 90xx SAT), so one index moves between them by
;  flipping bits of H.
; =====================================================================

; the screen must be redrawn from scratch (after a full-screen page)
shadow_reset:
        call mark_all
        ld hl,SCH
        ld de,SCH+1
        ld bc,799
        ld (hl),0FFh
        ldir
        ld hl,SAT
        ld de,SAT+1
        ld bc,799
        ld (hl),0FFh
        ldir
        ret

; clear all overlays (after a page that used the buffers)
ova_clear:
        ld hl,OVA
        ld de,OVA+1
        ld bc,799
        ld (hl),0
        ldir
        ret

; the view origin from the player's position: vx, vy, viewmap
set_view:
        ld a,(px)
        sub VIEWW/2
        jr nc,$+3
        xor a
        cp MAPW-VIEWW+1
        jr c,$+4
        ld a,MAPW-VIEWW
        ld (vx),a
        ld a,(py)
        sub VIEWH/2
        jr nc,$+3
        xor a
        cp MAPH-VIEWH+1
        jr c,$+4
        ld a,MAPH-VIEWH
        ld (vy),a
        ld b,0
        ld c,a
        call map_addr
        ld a,(vx)
        add a,l
        ld l,a
        ld (viewmap),hl
        ret

; whole frame
render_frame:
        ld a,(dlg_on)               ; a dialogue: only its box, once
        or a
        jr z,.world
        ld a,(dlg_dirty)
        or a
        ret z
        xor a
        ld (dlg_dirty),a
        call dlg_draw
        jp compose
.world: ; everything when the torch's strength changed, its inner glow
        ; when it flickers, and a row each frame
        ld a,(torch)
        ld hl,last_torch
        cp (hl)
        ld (hl),a
        call nz,mark_all
        ld a,(torch_fl)
        ld hl,last_fl
        cp (hl)
        ld (hl),a
        jr z,.roll
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call to_view_signed
        ld l,6                      ; (the flicker reaches d = 5)
        ld a,b
        sub l
        ld d,a
        ld a,b
        add a,l
        ld b,d
        ld d,a
        ld a,c
        add a,l
        ld e,a
        ld a,c
        sub l
        ld c,a
        call mark_box
.roll:  ld a,(roll_row)
        inc a
        cp VIEWH
        jr c,$+3
        xor a
        ld (roll_row),a
        ld c,a
        ld e,a
        ld b,0
        ld d,VIEWW-1
        call mark_box
        call light_pass
        call poll
        call dyn_lights
        call overlays
        call poll
        call compose
        ret

; ---------------------------------------------------------------------
light_pass:
        ld a,(torch)
        inc a
        ld (light_pass.t+1),a
        ld a,(torch_fl)
        ld (light_pass.f+1),a
        ld a,(torch_hue)
        or 08h
        ld (light_pass.h+1),a
        xor a
        ld (rp_y),a
.row:   call span_start             ; HL = LVL, DE = map, B = count
        jr z,.nrow
        ld a,d
        or high VISM
        ld d,a
        ld a,b
        exx
        ld b,a
        exx
.cell:  ld a,(de)                   ; distance + 1 (0 = unseen)
        or a
        jr z,.inv
        dec a
        srl a                       ; d/2: the lantern reaches 2T cells
        cp 3
        jr nc,.far
.f:     add a,0                     ; the flicker dims the inner glow
.far:   ld b,a
        ld a,d
        xor high VISM ^ high SLIGHT
        ld d,a
        ld a,(de)
        ld c,a                      ; static light
        ld a,d
        xor high VISM ^ high SLIGHT
        ld d,a
.t:     ld a,0                      ; torch + 1
        sub b
        jr c,.st
        jr z,.st
        cp 8
        jr c,$+4
        ld a,7
        ld b,a
        ld a,c
        and 7
        cp b
        jr nc,.st
        ld a,b
.h:     or 08h
        ld (hl),a
        jr .next
.st:    ld a,c
        or 08h
        ld (hl),a
        jr .next
.inv:   ld (hl),a
.next:  inc hl
        inc de
        exx
        dec b
        exx
        jr nz,.cell
.nrow:  ld hl,rp_y
        inc (hl)
        ld a,(hl)
        cp VIEWH
        jr c,.row
        ret

; the span of view row rp_y: HL = its LVL address, DE = its map address,
; B = cells; Z if the row has nothing to do.  Keeps C.
span_start:
        ld a,(rp_y)
        ld e,a
        ld d,0
        ld hl,dirty_lo
        add hl,de
        ld a,(hl)                   ; lo
        ld b,a
        ld hl,dirty_hi
        add hl,de
        ld a,(hl)
        sub b
        ret z
        jr nc,.go
        xor a                       ; (empty: hi < lo)
        ret
.go:    push af                     ; count
        ld a,e
        call mul40
        ld a,l
        add a,b
        ld l,a
        jr nc,$+3
        inc h
        push hl
        ; map: viewmap + y * 64 + lo
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(viewmap)
        add hl,de
        ld a,l
        add a,b
        ld l,a
        jr nc,$+3
        inc h
        ex de,hl
        pop hl
        ld bc,LVL
        add hl,bc
        pop af
        ld b,a
        or a
        ret

; ---------------------------------------------------------------------
; dirty spans: per view row, the columns [lo, hi) that must be redrawn
spans_clear:
        ld hl,dirty_lo
        ld b,VIEWH
.c:     ld (hl),VIEWW
        inc hl
        djnz .c
        ld b,VIEWH
.d:     ld (hl),0
        inc hl
        djnz .d
        ret

mark_all:
        push hl
        push bc
        ld hl,dirty_lo
        ld b,VIEWH
.c:     ld (hl),0
        inc hl
        djnz .c
        ld b,VIEWH
.d:     ld (hl),VIEWW
        inc hl
        djnz .d
        pop bc
        pop hl
        ret

; mark view cells x B..D, rows C..E (signed; clipped).  Keeps all but AF.
mark_box:
        push bc
        push de
        push hl
        bit 7,b
        jr z,$+4
        ld b,0
        bit 7,c
        jr z,$+4
        ld c,0
        bit 7,d
        jr nz,.x
        ld a,d
        cp VIEWW
        jr c,$+4
        ld d,VIEWW-1
        bit 7,e
        jr nz,.x
        ld a,e
        cp VIEWH
        jr c,$+4
        ld e,VIEWH-1
        ld a,d
        cp b
        jr c,.x
        ld a,e
        cp c
        jr c,.x
        inc d                       ; hi is exclusive
.r:     ld hl,dirty_lo
        ld a,l
        add a,c
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        cp b
        jr c,$+3
        ld (hl),b
        push de
        ld de,VIEWH
        add hl,de
        pop de
        ld a,(hl)
        cp d
        jr nc,$+3
        ld (hl),d
        ld a,c
        inc c
        cp e
        jr c,.r
.x:     pop hl
        pop de
        pop bc
        ret

; mark view cell (ov_vx, ov_vy).  Keeps all but AF.
mark_ov:
        push hl
        push de
        ld a,(ov_vy)
        ld e,a
        ld d,0
        ld hl,dirty_lo
        add hl,de
        ld a,(ov_vx)
        cp (hl)
        jr nc,$+3
        ld (hl),a
        ld de,VIEWH
        add hl,de
        inc a
        cp (hl)
        jr c,$+3
        ld (hl),a
        pop de
        pop hl
        ret

; mark map cell (B, C) if it is in view.  Keeps all but AF.
mark_map:
        push bc
        call to_view
        jr z,.x
        ld a,b
        ld (ov_vx),a
        ld a,c
        ld (ov_vy),a
        call mark_ov
.x:     pop bc
        ret

; ---------------------------------------------------------------------
; compose the view.  HL = LVL index, DE = map, IXL = glyph, C = attr.
compose:
        ld a,(framecnt)
        rrca
        rrca
        and 1
        ld (compose.ph+1),a
        xor a
        ld (rp_y),a
.row:   call span_start
        jp z,.nrow
        ld a,b
        exx
        ld b,a
        exx
.cell:  set 2,h                     ; OVA
        ld a,(hl)
        or a
        jp nz,.ovl
        res 2,h
        ld a,(hl)
        ld c,a
        and 7
        jr z,.mem
        ; lit: remember the cell
        ld a,(de)
        or 40h
        ld (de),a
        and 3Fh
        push hl
        ld l,a
        ld h,high TLP
        set 7,l
        ld b,(hl)                   ; info: bank, anim, mode, bg
        res 7,l
        bit 6,b
        jr nz,.anim
        ld a,c
        and 7
        cp 6
        jr c,.gd
.gb:    set 6,l
.gd:    ld a,(hl)
        ld ixl,a
        ld a,l
        or 0C0h
        ld l,a                      ; colour
        ld a,b
        and 30h
        jr z,.ramp                  ; M_LIT
        cp 20h
        jr z,.mfix
        jr nc,.col                  ; M_SELF
        ld a,c                      ; M_TINT
        and 7
        cp 3
        jr c,.blue
        cp 5
        jr c,.col
        jr .ramp
.mfix:  ld a,c
        and 7
        cp 3
        jr c,.blue
.col:   ld a,(hl)
        jr .fg
.anim:  ld a,e
        rrca
        xor e
        rrca
        rrca
        xor d
.ph:  xor 0
        and 1
        jr z,.gd
        jr .gb
.blue:  ld a,BLUE<<4
        jr .fg
.ramp:  ld a,c
        and 70h
        rrca
        ld l,a
        ld a,c
        and 7
        or l
        add a,low RAMP
        ld l,a
        ld h,high RAMP
        ld a,(hl)
.fg:    ld l,a
        ld a,b
        and 80h
        or l
        ld l,a
        ld a,c
        and 7
        cp 3
        jr c,.nobg
        ld a,b
        and 07h
        or l
        ld l,a
.nobg:  ld c,l
        pop hl
        jr .out
.mem:   ld a,(de)
        bit 6,a
        jr z,.blank
        and 3Fh
        push hl
        ld l,a
        ld h,high TLP
        ld a,(hl)
        ld ixl,a
        set 7,l
        ld a,(hl)
        pop hl
        ld c,a
        and 30h                     ; remembered floor stays dark, so
        jr z,.blank                 ; shadows show; walls and things blue
        ld a,c
        and 80h
        or BLUE<<4
        ld c,a
        jr .out
.blank: xor a
        ld ixl,a
        ld c,a
        jr .out
.ovl:   ld c,a                      ; overlay attr
        ld (hl),0                   ; consumed
        ld a,h
        xor 0Ch                     ; OVA -> OVG
        ld h,a
        ld a,(hl)
        ld ixl,a
        ld a,h
        xor 08h                     ; -> LVL
        ld h,a
.out:   set 4,h                     ; SAT
        ld a,c
        cp (hl)
        jr nz,.diff
        ld a,h
        xor 1Ch                     ; -> SCH
        ld h,a
        ld a,ixl
        cp (hl)
        jr nz,.diff2
        ld a,h
        xor 0Ch                     ; SCH -> LVL
        ld h,a
        jr .next
.diff:  ld (hl),c
        ld a,h
        xor 1Ch
        ld h,a
.diff2: ld a,ixl
        ld (hl),a
        ld a,h
        xor SCH2VRAM                ; SCH -> VRAM
        ld h,a
        ld a,ixl
        ld (hl),a
        set 3,h
        ld (hl),c
        ld a,h
        xor ARAM2LVL                ; ARAM -> LVL
        ld h,a
        set 4,h                     ; SAT (the .diff2 path skipped it)
        ld (hl),c
        res 4,h
.next:  inc hl
        inc de
        exx
        dec b
        exx
        jp nz,.cell
        call poll
.nrow:  ld hl,rp_y
        inc (hl)
        ld a,(hl)
        cp VIEWH
        jp c,.row
        jp spans_clear

; ---------------------------------------------------------------------
; overlays: put glyph G, attr A at map (B = x, C = y) if it is in view.
; HL = the cell's LVL address on return (Z if out of view).
; Keeps BC, DE.
ov_cell:
        push af
        call view_index
        jr z,.out
        pop af
        set 2,h
        ld (hl),a
        ld a,h
        xor 0Ch
        ld h,a
        ld a,(ov_g)
        ld (hl),a
        ld a,h
        xor 08h
        ld h,a                      ; back to LVL
        or 1
        ret
.out:   pop af
        xor a
        ret

; HL = LVL address of map cell (B, C); Z (and A = 0) if out of view.
; Keeps BC, DE.
view_index:
        ld a,(vx)
        ld l,a
        ld a,b
        sub l
        jr c,.no
        cp VIEWW
        jr nc,.no
        ld l,a
        ld (ov_vx),a
        ld a,(vy)
        ld h,a
        ld a,c
        sub h
        jr c,.no
        cp VIEWH
        jr nc,.no
        ld (ov_vy),a
        push de
        ld e,l
        call mul40
        ld d,0
        add hl,de
        ld de,LVL
        add hl,de
        pop de
        or 1
        ret
.no:    xor a
        ret

; level (0-7) the player sees at map cell (B, C); 0 if not seen or out of
; view.  Keeps BC, DE.
cell_level:
        call view_index
        ret z
        ld a,(hl)
        and 7
        ret
