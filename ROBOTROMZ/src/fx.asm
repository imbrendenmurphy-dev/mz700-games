; =====================================================================
;  fx.asm - big captions, the arena edge flash, the heartbeat
; =====================================================================

; HL = text (ASCII, 0 end), B = top row, C = column, E = attribute.
; Each letter is 3 x 4 block characters; a space is one column.
big_text:
.l:     ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        cp ' '
        jr z,.sp
        call big_find           ; IY = its 12 block characters
        jr c,.sp
        push bc
        ld a,4
        ld (bigr),a
.r:     push bc
        call calc_ofs           ; HL = cell (DE kept)
        ld b,3
.c:     ld d,(iy+0)
        call bg_put
        inc hl
        inc iy
        djnz .c
        pop bc
        inc b
        ld a,(bigr)
        dec a
        ld (bigr),a
        jr nz,.r
        pop bc
        ld a,c
        add a,3
        ld c,a
        pop hl
        jr .l
.sp:    inc c
        pop hl
        jr .l

; A = character -> IY = its glyph (carry if there isn't one)
big_find:
        push bc
        push hl
        ld hl,bigchars
        ld b,0
.f:     ld c,(hl)
        inc c
        dec c
        jr z,.no
        cp c
        jr z,.got
        inc hl
        inc b
        jr .f
.got:   ld l,b                  ; IY = bigfont + 12 * index
        ld h,0
        add hl,hl
        add hl,hl
        push hl
        add hl,hl
        pop bc
        add hl,bc
        ld bc,bigfont
        add hl,bc
        push hl
        pop iy
        pop hl
        pop bc
        or a
        ret
.no:    pop hl
        pop bc
        scf
        ret

; width in columns of the big text at HL -> A
big_width:
        push hl
        ld c,0
.w:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        cp ' '
        jr z,.s
        inc c
        inc c
.s:     inc c
        jr .w
.e:     ld a,c
        pop hl
        ret

; big text at HL centred, top row B, attribute E
big_centre:
        push de
        call big_width
        ld d,a
        ld a,40
        sub d
        srl a
        ld c,a
        pop de
        jp big_text

; roll rainbow colours across rows 7..10 (the big caption), on blue
caption_colours:
        ld a,(framecnt)
        rrca
        rrca
        ld (phase),a
        ld hl,7*40+1
        ld b,4
.r:     push bc
        push hl
        ld b,38
        ld c,0
.c:     ld a,c                  ; only cells that hold a block character
        push hl
        ld de,BGCH
        add hl,de
        ld a,(hl)
        pop hl
        cp 0F1h
        jr c,.nx
        push bc
        ld a,c
        srl a
        ld b,a
        ld a,(phase)
        sub b
        and 7
        ld de,capcols
        add a,e
        ld e,a
        jr nc,.n1
        inc d
.n1:    ld a,(de)
        ld e,a
        call recolour
        pop bc
.nx:    inc hl
        inc c
        djnz .c
        pop hl
        ld de,40
        add hl,de
        pop bc
        djnz .r
        ret

capcols: db 60h,70h,50h,30h,20h,30h,50h,70h

; blank rows 7..10 and 14 (big caption and subtitle) back to the arena
clear_big:
        ld hl,7*40+1
        ld b,4
.r:     push bc
        push hl
        ld de,00h*256+A_ARENA
        ld b,38
        call fill_bg
        pop hl
        ld de,40
        add hl,de
        pop bc
        djnz .r
        ld hl,14*40+1
        ld de,00h*256+A_ARENA
        ld b,38
        jp fill_bg

; the arena edge flashes (extra life): edgetm counts down
edge_flash:
        ld a,(edgetm)
        or a
        ret z
        dec a
        ld (edgetm),a
        ld a,(bordcol)          ; back to the wave's colour at the end
        ld e,a
        ld a,(edgetm)
        or a
        jr z,.go
        and 7
        ret nz
        ld a,(edgetm)
        rrca
        rrca
        rrca
        and 7
        ld hl,edgecols
        add a,l
        ld l,a
        jr nc,.c
        inc h
.c:     ld e,(hl)
.go:    ld hl,40                ; top line
        ld b,40
.t:     call recolour
        inc hl
        djnz .t
        ld hl,24*40             ; bottom line
        ld b,40
.b:     call recolour
        inc hl
        djnz .b
        ld hl,2*40              ; sides
        ld b,22
.s:     call recolour
        push de
        ld de,39
        add hl,de
        pop de
        call recolour
        inc hl
        djnz .s
        ret

edgecols: db 60h,70h,50h,20h,30h,60h,70h,50h

; the heartbeat (sound mode ALL, in play): a low double thump that
; quickens as the robots thin out
heartbeat:
        ld a,(soundopt)
        or a
        ret nz
        ld a,(sndptr+1)         ; not over another sound
        or a
        ret nz
        ld hl,beattm
        dec (hl)
        ret nz
        ld a,(alive)            ; period: 14 ticks + 1 per robot (max 64)
        cp 50
        jr c,.p
        ld a,50
.p:     add a,14
        ld (hl),a
        ld hl,sfx_beat
        xor a
        jp play_sfx
