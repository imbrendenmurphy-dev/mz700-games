; =====================================================================
;  fx.asm - full-screen effects for the mixer screens: the launch
;  tunnel, hyperspace and our own ship blowing up.
;
;  The mixer only plays while the program waits, so these effects are
;  cheap on purpose: nine rings of thin quarter-block characters around
;  the view's centre, drawn once, then animated by rewriting their
;  colours (about 500 attribute bytes a frame, a tenth of the frame).
; =====================================================================

NRINGS          equ 9

; ring k (0 = innermost): rows 9-k .. 10+k, columns 18-2k .. 21+2k
; A = k -> HL = VRAM of its top-left cell, B = width, C = height
ring_geom:
        ld e,a
        ld a,VIEW_ROW+8
        sub e
        call row_addr
        ld a,18
        sub e
        sub e
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,e
        add a,a
        add a,a
        add a,4
        ld b,a
        ld a,e
        add a,a
        add a,2
        ld c,a
        ret

; draw ring A's outline characters
ring_chars:
        call ring_geom
        push hl
        ld (hl),0F7h                    ; top: corner, edge, corner
        inc hl
        ld a,b
        sub 2
        ld d,a
.t:     ld (hl),0F3h
        inc hl
        dec a
        jr nz,.t
        ld (hl),0FBh
        pop hl
        ld e,b
        dec e                           ; E = offset of the right side
        ld a,c
        sub 2
        jr z,.bot
.s:     push af                         ; sides
        ld a,l
        add a,40
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),0F5h
        push hl
        ld a,l
        add a,e
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),0FAh
        pop hl
        pop af
        dec a
        jr nz,.s
.bot:   ld a,l                          ; bottom
        add a,40
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),0FDh
        inc hl
        ld a,d
.b:     ld (hl),0FCh
        inc hl
        dec a
        jr nz,.b
        ld (hl),0FEh
        ret

; colour ring A with attribute D, unless it has that colour already
ring_col:
        ld e,a
        push de
        ld d,0
        ld hl,fx_last
        add hl,de
        pop de
        ld a,(hl)
        cp d
        ret z
        ld (hl),d
        ld a,e
        ; fall through
; colour ring A with attribute D
ring_attr:
        push ix
        push de
        call ring_geom
        pop de
        set 3,h
        ld a,d
        push hl
        ld d,b                          ; D = width
.t:     ld (hl),a                       ; top row
        inc hl
        djnz .t
        dec hl
        push hl
        pop ix                          ; IX = right side
        pop hl                          ; HL = left side
        ld e,c
        dec e                           ; rows below the top
        ld bc,40
.s:     add hl,bc
        add ix,bc
        ld (hl),a
        ld (ix+0),a
        dec e
        jr nz,.s
        ld b,d                          ; bottom row
.b:     ld (hl),a
        inc hl
        djnz .b
        pop ix
        ret

; clear the view and draw every ring (in black)
rings_init:
        ld hl,fx_last
        ld b,NRINGS
.l:     ld (hl),0FFh
        inc hl
        djnz .l
        ld a,WHITE<<4
        call cls
        ld c,NRINGS
.r:     dec c
        ld a,c
        push bc
        call ring_chars
        pop bc
        ld a,c
        or a
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; tunnel: HL = 8-colour palette, B = frames, C = 1 rings rush outwards,
; -1 inwards.  The colour of ring k is palette[(k - phase) & 7].
; ---------------------------------------------------------------------
tunnel_fx:
        ld (fx_pal),hl
        ld a,b
        ld (fx_n),a
        ld a,c
        ld (fx_dir),a
        xor a
        ld (fx_ph),a
        call rings_init
.f:     call wait_frame
        ld a,(fx_ph)
        ld hl,fx_dir
        add a,(hl)
        ld (fx_ph),a
        ld c,NRINGS
.r:     dec c
        ld a,(fx_ph)
        ld b,a
        ld a,c
        sub b
        and 7
        ld e,a
        ld d,0
        ld hl,(fx_pal)
        add hl,de
        ld a,(hl)
        add a,a
        add a,a
        add a,a
        add a,a
        ld d,a
        ld a,c
        push bc
        call ring_col
        pop bc
        ld a,c
        or a
        jr nz,.r
        ld hl,fx_n
        dec (hl)
        jr nz,.f
        ret

LAUNCH_PAL:     db WHITE,CYAN,CYAN,BLUE,BLACK,BLACK,BLACK,BLUE
HYPER_PAL:      db WHITE,WHITE,CYAN,CYAN,MAGENTA,MAGENTA,BLUE,BLUE

; out through the station's tunnel
launch_fx:
        ld hl,SFX_LAUNCH
        ld a,9
        call sfx
        ld hl,LAUNCH_PAL
        ld bc,20*256+1
        jp tunnel_fx

; ---------------------------------------------------------------------
; death: rings of fire burst out over the view and fade
; ---------------------------------------------------------------------
DEATH_FRAMES    equ 34
FADE:           db WHITE,YELLOW,YELLOW,RED,RED,MAGENTA,BLUE,BLACK

death_seq:
        call snd_fe                     ; the big bang gets the mixer
        ld hl,SFX_DEATH
        ld a,9
        call sfx
        ld hl,fx_last
        ld b,NRINGS
.l:     ld (hl),0FFh
        inc hl
        djnz .l
        ld bc,VIEW_ROW*256+18           ; a white flash, then darkness
        ld a,(WHITE<<4)|WHITE
        call clear_rows
        call wait_frame
        ld bc,VIEW_ROW*256+18
        ld a,WHITE<<4
        call clear_rows
        xor a
        ld (fx_ph),a
.f:     call wait_frame
        ld a,(fx_ph)                    ; a new ring every second frame
        srl a
        jr c,.col
        cp NRINGS
        jr nc,.col
        push af
        ld e,a
        ld d,0
        ld hl,fx_last
        add hl,de
        ld (hl),0FFh
        pop af
        call ring_chars
.col:   ld c,0                          ; ring k: FADE[t - 2k], once t >= 2k
.r:     ld a,(fx_ph)
        sub c
        sub c
        jr c,.nx
        cp 8
        jr c,$+4
        ld a,7
        ld e,a
        ld d,0
        ld hl,FADE
        add hl,de
        ld a,(hl)
        add a,a
        add a,a
        add a,a
        add a,a
        ld d,a
        ld a,c
        push bc
        call ring_col
        pop bc
.nx:    inc c
        ld a,c
        cp NRINGS
        jr c,.r
        ld hl,fx_ph
        inc (hl)
        ld a,(hl)
        cp DEATH_FRAMES
        jr c,.f
        ret
