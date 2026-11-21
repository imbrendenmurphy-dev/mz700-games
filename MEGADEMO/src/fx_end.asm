; ---------------------------------------------------------------------------
; fx_end.asm - end credits: lines are revealed one by one and a colour wave
; runs down the text.
; end_text: 25 rows x 40 display codes
; ---------------------------------------------------------------------------

end_init:
        ld hl,end_text
        ld de,CBUF
        ld bc,1000
        ldir
        call blit_char_hidden
        xor a
        ld (en_rows),a
        ld (en_delay),a
        ret

blit_char_hidden:               ; attrs black first, then the characters
        xor a
        ld hl,ABUF
        call fill_buf
        call blit_attr
        jp blit_char

end_frame:
        call wait_vbl
        call blit_attr
        ; reveal a row every 8 frames
        ld hl,en_delay
        inc (hl)
        ld a,(hl)
        and 7
        jr nz,.nr
        ld a,(en_rows)
        cp 25
        jr nc,.nr
        inc a
        ld (en_rows),a
.nr:    ; build attributes
        ld hl,ABUF
        ld b,0
.row:   ld a,(en_rows)
        cp b
        ld a,0
        jr c,.fill
        jr z,.fill
        ; colour wave
        ld a,(mtick)
        rrca
        rrca
        sub b
        and 15
        ld e,a
        ld d,0
        push hl
        ld hl,en_wave
        add hl,de
        ld a,(hl)
        pop hl
.fill:  ld c,40
.f:     ld (hl),a
        inc hl
        dec c
        jr nz,.f
        inc b
        ld a,b
        cp 25
        jr c,.row
        ret

en_wave: db 10h,10h,50h,50h,70h,70h,70h,50h,10h,10h,30h,30h,60h,70h,60h,30h

en_rows:  db 0
en_delay: db 0
