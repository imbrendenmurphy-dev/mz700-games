; =====================================================================
;  fx.asm - explosions, sparks, debris, score pop-ups, big captions
; =====================================================================

FX_BOOM  equ 1
FX_SPARK equ 2
FX_TEXT  equ 3
FX_BITS  equ 4

; B = row, C = column -> IY = a free effect (Z set if none)
fx_new:
        ld iy,FXL
        ld de,FXSZ
        ld a,MAXFX
.f:     ex af,af'
        ld a,(iy+FK)
        or a
        jr z,.got
        add iy,de
        ex af,af'
        dec a
        jr nz,.f
        xor a                   ; Z: none
        ret
.got:   ld (iy+FX_),c
        ld (iy+FY),b
        ld (iy+FT),0
        or 1                    ; NZ
        ret

; B = row, C = column: a small explosion (BC kept)
explode:
        xor a
explode_d:                      ; A = delay in ticks (as a negative age)
        push bc
        push af
        call fx_new
        pop de
        pop bc
        ret z
        ld (iy+FK),FX_BOOM
        xor a
        sub d
        ld (iy+FT),a
        ld (iy+FL),7
        ret

; B = row, C = column: one short spark (BC kept)
spark:
        push bc
        call fx_new
        pop bc
        ret z
        ld (iy+FK),FX_SPARK
        ld (iy+FL),3
        ret

; B = row, C = column: a big explosion - a cluster and flying debris
big_burst:
        push bc
        call explode
        dec b
        dec c
        ld a,2
        call explode_d
        inc c
        inc c
        ld a,3
        call explode_d
        inc b
        inc b
        ld a,4
        call explode_d
        dec c
        dec c
        ld a,5
        call explode_d
        pop bc
        ld hl,bitdirs
        ld a,8
.d:     push af
        push hl
        push bc
        call fx_new
        pop bc
        pop hl
        jr z,.x
        ld (iy+FK),FX_BITS
        ld (iy+FL),14
        ld a,(hl)
        ld (iy+FA),a
        inc hl
        ld a,(hl)
        ld (iy+FB),a
        dec hl
.x:     inc hl
        inc hl
        pop af
        dec a
        jr nz,.d
        ret
bitdirs: db 1,0, 1,1, 0,1, -1,1, -1,0, -1,-1, 0,-1, 1,-1

; HL = text, B = row, C = column: a rising pop-up
popup:
        push hl
        call fx_new
        pop hl
        ret z
        ld (iy+FK),FX_TEXT
        ld (iy+FL),30
        ld (iy+FA),l
        ld (iy+FB),h
        ret

; HL = text: a pop-up just above the ship
popup_ship:
        ld a,(py+1)
        dec a
        ld b,a
        ld a,(px+1)
        dec a
        ld c,a
        jr popup

fx_tick:
        ld iy,FXL
        ld b,MAXFX
.f:     push bc
        ld a,(iy+FK)
        or a
        call nz,fx_one
        ld de,FXSZ
        add iy,de
        pop bc
        djnz .f
        jp caption_draw

fx_one:
        inc (iy+FT)
        ld a,(iy+FT)
        bit 7,a
        ret nz                  ; (still waiting)
        cp (iy+FL)
        jr c,.live
        ld (iy+FK),0
        ret
.live:  ld e,a                  ; E = age
        ld b,(iy+FY)
        ld c,(iy+FX_)
        ld a,(iy+FK)
        cp FX_BOOM
        jr nz,.n1
        ld hl,boomseq
        ld a,e
        add a,a
        add a,l
        ld l,a
        jr nc,.b
        inc h
.b:     ld d,(hl)
        inc hl
        ld e,(hl)
        xor a
        jp put_one
.n1:    cp FX_SPARK
        jr nz,.n2
        ld d,6Bh
        ld e,60h
        xor a
        jp put_one
.n2:    cp FX_BITS
        jr nz,.n3
        bit 0,e                 ; every other tick a cell further
        jr z,.bd
        ld a,(iy+FX_)
        add a,(iy+FA)
        ld (iy+FX_),a
        ld c,a
        ld a,(iy+FY)
        add a,(iy+FB)
        ld (iy+FY),a
        ld b,a
.bd:    ld d,0A0h
        ld a,e
        and 4
        ld e,0E0h               ; yellow, then red
        jr z,.bc
        ld e,0A0h
.bc:    xor a
        jp put_one
.n3:    ; text: rises a row every 6 ticks
        ld a,e
        ld d,0
.r:     sub 6
        jr c,.rr
        inc d
        jr .r
.rr:    ld a,b
        sub d
        ld b,a
        ld l,(iy+FA)
        ld h,(iy+FB)
        ld a,e
        and 2
        ld e,70h
        jr z,.t
        ld e,60h
.t:     ld a,(hl)
        or a
        ret z
        push hl
        push bc
        push de
        call asc2dc
        ld d,a
        xor a
        call put_one
        pop de
        pop bc
        pop hl
        inc hl
        inc c
        jr .t

; explosion frames (bank 2 glyphs): char, attribute
boomseq:
        db 85h,0F0h, 82h,0E0h, 83h,0E0h, 84h,0E0h, 84h,0A0h, 0A0h,0A0h, 0A0h,0B0h, 0A0h,0B0h

; ---------------------------------------------------------------------
; big captions ("STAGE 1", "WARNING", "STAGE CLEAR", "GAME OVER"):
; up to two lines of the 3 x 4 dotted-block font, drawn once into BG
; (stars pass behind them), recoloured every 4 ticks, and wiped at the
; end (the scenery comes back).
; HL = line 1, DE = line 2 (0 = none), A = ticks
caption:
        push af
        push hl
        push de
        call caption_wipe
        pop de
        pop hl
        pop af
        ld (captm),a
        ld (cap1),hl
        ld (cap2),de
        xor a
        ld (capmode),a          ; draw
        jp caption_all

caption_draw:
        ld a,(captm)
        or a
        ret z
        dec a
        ld (captm),a
        jr z,caption_wipe
        and 3
        ret nz
        ld a,(framecnt)
        ld (capcol0),a
        jr caption_all

; take the caption off the screen
caption_wipe:
        ld hl,(cap1)
        ld a,h
        or l
        ret z
        ld a,1
        ld (capmode),a
        call caption_all
        ld hl,0
        ld (cap1),hl
        xor a
        ld (captm),a
        ret

caption_all:
        ld hl,(cap1)
        ld b,6
        call .line
        ld hl,(cap2)
        ld a,h
        or l
        ret z
        ld b,11
.line:  ; centre: column = (30 - 3 * length) / 2
        push hl
        ld c,0
.n:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc c
        jr .n
.e:     ld a,c
        add a,a
        add a,c
        ld c,a
        ld a,PFW
        sub c
        srl a
        ld c,a
        pop hl
        ld a,(capcol0)
        ld (capcol),a
.ch:    ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push bc
        cp ' '
        call nz,big_letter
        pop bc
        pop hl
        ld a,c
        add a,3
        ld c,a
        ld a,(capcol)
        inc a
        ld (capcol),a
        jr .ch

; A = letter, B = row, C = column: into BG (or wiped, capmode 1)
big_letter:
        ld hl,bigchars
        ld e,0
.f:     ld d,(hl)
        inc d
        dec d
        ret z                   ; (not in the font)
        cp d
        jr z,.got
        inc hl
        inc e
        jr .f
.got:   ld l,e                  ; HL = bigfont + 12 * index
        ld h,0
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,bigfont
        add hl,de
        ld a,(capcol)
        and 7
        push hl
        ld hl,capcols
        add a,l
        ld l,a
        jr nc,.cc
        inc h
.cc:    ld a,(hl)
        pop hl
        ld (capat),a
        ld a,4
.r:     push af
        push bc
        ld a,3
.c:     push af
        ld a,(hl)
        inc hl
        cp 0F0h
        jr z,.sk
        push hl
        push bc
        ld d,a
        ld a,(capat)
        ld e,a
        call calc_ofs
        ld a,(capmode)
        or a
        jr z,.put
        call scn_at             ; wipe: the scenery, or space
        ld d,a
        jr nz,.put
        ld de,A_SPACE
.put:   call bg_put
        pop bc
        pop hl
.sk:    inc c
        pop af
        dec a
        jr nz,.c
        pop bc
        inc b
        pop af
        dec a
        jr nz,.r
        ret
capcols: db 70h,60h,50h,40h,60h,70h,50h,30h
