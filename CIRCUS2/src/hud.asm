; =====================================================================
;  hud.asm - score line (row 23) and progress bar (row 24)
;
;  0         1         2         3
;  0123456789012345678901234567890123456789
;  012340 h4 WS2UNNN x8          ACT 12
; =====================================================================
hud_draw:
        ld b,BLACK
        ld c,0
        ld d,HUD_ROW
        ld e,0
        ld a,80
        call bg_fill_run
        ld d,BAR_ROW
        call row_dirty
        ; score
        ld hl,score
        ld b,3
        ld de,strbuf
.s:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .s
        xor a
        ld (de),a
        ld hl,strbuf
        ld d,HUD_ROW
        ld e,0
        ld b,YELLOW*16
        call bg_print
        ; lives
        ld e,7
        ld c,53h                    ; heart
        ld b,RED*16
        call bg_put
        inc e
        ld a,(lives)
        add a,20h
        ld c,a
        ld b,WHITE*16
        call bg_put
        ; power-ups (blinking as they run out)
        ld e,10
        ld hl,pw_wide
        ld ix,pwletters
        ld b,4
.pw:    push bc
        ld a,(hl)
        or a
        jr z,.pn
        cp 50
        jr nc,.show
        ld a,(tickpar)
        and 8
        jr z,.pn
.show:  ld c,(ix+0)
        ld b,CYAN*16
        call bg_put
        inc e
.pn:    inc hl
        inc ix
        pop bc
        djnz .pw
        ld a,(pw_net)
        or a
        jr z,.nonet
        ld b,a
.nt:    push bc
        ld c,0Eh                    ; N
        ld b,GREEN*16
        call bg_put
        inc e
        pop bc
        djnz .nt
.nonet: ; combo
        ld a,(combo)
        cp 2
        jr c,.nocombo
        cp 9
        jr c,$+4
        ld a,8
        add a,20h
        ld c,a
        ld e,19
        ld b,MAGENTA*16
        call bg_put
        ld e,18
        ld c,18h                    ; X
        call bg_put
.nocombo:
        ; act number or time left
        ld a,(actflags)
        and AF_BONUS
        jr nz,.btime
        ld hl,txt_act
        ld de,strbuf
        call strcpy
        ld a,(encore)               ; the act number keeps counting in the encore
        ld b,a
        ld a,(act)
        inc a
        inc b
        jr .ae
.al:    add a,NACTS
.ae:    djnz .al
        call num_append
        jr .right
.btime: ld hl,(bonus_time)
        ld de,25
        ld a,-1
.dv:    inc a
        or a
        sbc hl,de
        jr nc,.dv
        push af
        ld hl,txt_time
        ld de,strbuf
        call strcpy
        pop af
        call num_append
.right: ld hl,strbuf
        call strlen
        ld b,a
        ld a,40
        sub b
        ld e,a
        ld d,HUD_ROW
        ld b,GREEN*16
        call bg_print
        ; progress bar: balloons popped, or time left in a bonus round
        ld a,(actflags)
        and AF_BONUS
        jr nz,.tbar
        ld a,(balloons_total)
        or a
        ret z
        ld c,a
        ld a,(balloons_left)
        ld b,a
        ld a,c
        sub b                       ; popped
        ld l,a
        ld h,0
        jr .bar
.tbar:  ld hl,(bonus_time)          ; 0..750 -> / 9.4: use *8/75
        add hl,hl
        add hl,hl
        add hl,hl
        ld c,75
        call div16_8
        ld h,0
        ld c,80
        jr .bar2
.bar:   ld d,h                      ; HL = popped * 80
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        call div16_8                ; / total
.bar2:  ld a,l
        cp 81
        jr c,$+4
        ld a,80
        ld c,a                      ; half cells
        ld a,(pal+P_A1)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld d,BAR_ROW
        ld e,0
.bf:    ld a,c
        cp 2
        jr c,.bh
        push bc
        ld c,43h
        call bg_put
        pop bc
        dec c
        dec c
        inc e
        jr .bf
.bh:    or a
        ret z
        ld c,7Bh                    ; left half block
        jp bg_put

pwletters:      db 17h,13h,22h,15h  ; W S 2 U

; HL / C -> L (quotient, 8 bit)
div16_8:
        push bc
        ld b,16
        xor a
.l:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .l
        pop bc
        ret
