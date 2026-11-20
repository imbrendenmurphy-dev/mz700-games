; =====================================================================
;  objects.asm - hoop, monkey and pies, power-up tokens, bonus-round
;  balloons, particles and score pop-ups
; =====================================================================
NPARTS          equ 14
PT_SIZE         equ 10              ; +0 life, +1 colour, +2/3 x, +4/5 y, +6/7 vx, +8/9 vy
NPOPS           equ 4
PU_SIZE         equ 14              ; +0 life, +1 col, +2 row, +3 spare, +4.. text

; A = signed byte from the rng in -32..31 style ranges -> HL sign-extended
sx_hl:
        ld l,a
        rla
        sbc a,a
        ld h,a
        ret

; ---------------------------------------------------------------------
; ring of fire: swings left and right across row 16
; ---------------------------------------------------------------------
hoop_update:
        ld a,(hoop)
        or a
        ret z
        ld hl,hoop+2
        inc (hl)
        ld a,(hl)
        and 63
        ld hl,SINTAB
        call add_hl_a
        ld a,(hl)
        sra a                       ; -64..63
        ld b,a
        sra a
        sra a
        sra a
        sra a
        ld c,a
        ld a,b
        sub c                       ; ~ -60..60
        add a,80
        ld (hoop+1),a
        ret

clown_hoop:
        ld a,(hoop)
        or a
        ret z
        ld a,(ix+CS_Y+1)            ; did the centre cross the hoop line?
        add a,8
        ld c,a
        ld a,(prev_cy)
        cp HOOP_CY
        jr c,.wasabove
        ld a,c                      ; was below: crossing upward?
        cp HOOP_CY
        ret nc
        ld e,1
        jr .cross
.wasabove:
        ld a,c
        cp HOOP_CY
        ret c
        ld e,2
.cross: ld a,(hoop+1)
        rrca
        rrca
        and 3Fh
        ld d,a
        ld a,(ix+CS_X+1)
        rrca
        rrca
        and 3Fh
        sub d
        jr nc,$+4
        neg
        or a
        jr z,.through
        cp 2
        ret nc
        call neg_vx                 ; the rim: too hot!
        ld hl,SFX_BONK
        ld a,2
        call sfx
        ld hl,txt_hot
        ld c,14
        jp popup_clown
.through:
        ld a,(ix+CS_FL)
        and e
        ret nz
        ld a,(ix+CS_FL)
        or e
        ld (ix+CS_FL),a
        ld hl,combo
        inc (hl)
        inc (ix+CS_POPS)
        ld de,0300h
        call add_pts
        ld hl,txt_hoop
        ld a,(hoop+1)
        ld c,14
        call popup_at
        ld a,(hoop+1)
        ld b,a
        ld c,HOOP_CY
        ld a,YELLOW
        ld e,8
        call burst
        ld hl,SFX_HOOP
        ld a,2
        jp sfx

draw_hoop:
        ld a,(hoop)
        or a
        ret z
        ld a,(hoop+1)
        rrca
        rrca
        and 3Fh
        ld e,a
        ld d,HOOP_ROW
        ld a,(tickpar)
        and 2
        ld a,RED*16
        jr z,$+4
        ld a,YELLOW*16
        ld b,a
        push de
        dec e
        ld c,68h                    ; (
        call put_at
        pop de
        push de
        inc e
        ld c,69h                    ; )
        call put_at
        pop de
        dec d                       ; flames on top
        ld a,b
        xor (RED^YELLOW)*16
        ld b,a
        ld c,0BEh                   ; ^
        push de
        dec e
        call put_at
        pop de
        push de
        call put_at
        pop de
        inc e
        jp put_at

; ---------------------------------------------------------------------
; the monkey on the tightrope, and its custard pies
; monkey: +0 on, +1 x, +2 dir, +3 anim, +4 throw timer, +5 stunned
; pie:    +0 1 falling / 2 on the floor, +1 x, +2/3 y, +4/5 vy, +6 timer
; ---------------------------------------------------------------------
monkey_update:
        ld ix,monkey
        ld a,(ix+0)
        or a
        ret z
        ld a,(ix+5)
        or a
        jr z,.ns
        dec (ix+5)
        ret
.ns:    inc (ix+3)
        ld a,(ix+3)
        and 1
        jr nz,.nomove
        ld a,(ix+1)
        add a,(ix+2)
        ld (ix+1),a
        cp 10
        jr c,.flip
        cp 149
        jr c,.nomove
.flip:  ld a,(ix+2)
        neg
        ld (ix+2),a
.nomove:
        dec (ix+4)
        ret nz
        ld b,64
        call rand_below
        add a,40
        ld (ix+4),a
        ld iy,pies                  ; throw a pie
        ld b,3
.f:     ld a,(iy+0)
        or a
        jr z,.got
        ld de,8
        add iy,de
        djnz .f
        ret
.got:   ld (iy+0),1
        ld a,(ix+1)
        ld (iy+1),a
        ld (iy+3),(MONKEY_ROW+1)*8
        ld (iy+2),0
        ld (iy+4),0
        ld (iy+5),0
        ld hl,SFX_THROW
        ld a,1
        jp sfx

pies_update:
        ld iy,pies
        ld b,3
.l:     push bc
        call .one
        pop bc
        ld de,8
        add iy,de
        djnz .l
        ret
.one:   ld a,(iy+0)
        or a
        ret z
        cp 2
        jr nz,.fall
        dec (iy+6)
        ret nz
        ld (iy+0),0
        ret
.fall:  ld l,(iy+4)
        ld h,(iy+5)
        ld de,41
        add hl,de
        ld (iy+4),l
        ld (iy+5),h
        ld e,(iy+2)
        ld d,(iy+3)
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld ix,clown0
        call .vsclown
        ld ix,clown1
        call .vsclown
        ld a,(iy+0)
        or a
        ret z
        ld a,(iy+3)                 ; the seesaw?
        cp LAND_Y0
        ret c
        cp FLOOR_FEET
        jr nc,.floor
        ld a,(see_x+1)
        sub (iy+1)
        jr nc,$+4
        neg
        ld b,a
        ld a,(see_hw)
        add a,2
        cp b
        ret c
        ld a,75                     ; splat on the plank: sticky!
        ld (piestick),a
        ld (iy+0),0
        ld hl,SFX_SPLAT
        ld a,2
        call sfx
        ld hl,txt_splat
        ld a,(iy+1)
        ld c,17
        jp popup_at
.floor: ld (iy+0),2
        ld (iy+3),FLOOR_FEET-8
        ld (iy+6),25
        ret
.vsclown:
        ld a,(ix+CS_STATE)
        cp S_FLY
        ret nz
        ld a,(iy+0)
        or a
        ret z
        ld a,(iy+1)
        sub (ix+CS_X+1)
        add a,5
        cp 11
        ret nc
        ld a,(iy+3)
        add a,4
        sub (ix+CS_Y+1)
        cp 20
        ret nc
        ld (iy+0),0                 ; a pie in the face!
        ld b,128
        call rand_below
        sub 64
        call sx_hl
        ld e,(ix+CS_VX)
        ld d,(ix+CS_VX+1)
        add hl,de
        ld (ix+CS_VX),l
        ld (ix+CS_VX+1),h
        ld hl,SFX_SPLAT
        ld a,2
        call sfx
        ld a,(ix+CS_Y+1)
        rrca
        rrca
        rrca
        and 1Fh
        ld c,a
        ld hl,txt_pied
        jp popup_clown

clown_monkey:
        ld a,(monkey)
        or a
        ret z
        ld a,(monkey+5)
        or a
        ret nz
        ld a,(monkey+1)
        sub (ix+CS_X+1)
        add a,6
        cp 12
        ret nc
        ld a,(ix+CS_Y+1)
        cp (MONKEY_ROW+1)*8
        ret nc
        add a,16
        cp MONKEY_ROW*8+1
        ret c
        ld a,100
        ld (monkey+5),a
        ld de,0250h
        call add_pts
        ld hl,txt_ook
        ld a,(monkey+1)
        ld c,MONKEY_ROW-1
        call popup_at
        ld hl,SFX_BONK
        ld a,2
        jp sfx

draw_monkey:
        ld a,(monkey)
        or a
        ret z
        ld a,(monkey+1)
        rrca
        rrca
        and 3Fh
        ld e,a
        ld d,MONKEY_ROW
        ld a,(monkey+5)
        or a
        jr z,.ok
        and 4                       ; stunned: seeing stars
        ld a,WHITE*16
        jr z,$+4
        ld a,YELLOW*16
        ld b,a
        ld c,G_STAR
        push de
        dec d
        call put_at
        pop de
.ok:    ld a,(pal+P_HAT)
        rlca
        rlca
        rlca
        rlca
        or 80h
        ld b,a
        ld c,49h                    ; a monkey face (bank 1)
        jp put_at

draw_pies:
        ld iy,pies
        ld b,3
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        ld a,(iy+1)
        rrca
        rrca
        and 3Fh
        ld e,a
        ld a,(iy+3)
        rrca
        rrca
        rrca
        and 1Fh
        ld d,a
        ld b,YELLOW*16+80h
        ld c,0A3h                   ; a pie dish (bank 1)
        call put_at
.n:     ld de,8
        add iy,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; power-up tokens: +0 kind+1, +1 x, +2/3 y
; ---------------------------------------------------------------------
; B = x, C = y
spawn_token:
        push iy
        push de
        call .go
        pop de
        pop iy
        ret
.go:    ld iy,tokens
        ld e,3
.f:     ld a,(iy+0)
        or a
        jr z,.got
        push de
        ld de,8
        add iy,de
        pop de
        dec e
        jr nz,.f
        ret
.got:   push bc
        ld b,16
        call rand_below
        ld hl,token_odds
        call add_hl_a
        ld a,(hl)
        inc a
        ld (iy+0),a
        pop bc
        ld a,b
        cp XMAX
        jr c,$+4
        ld a,XMAX
        cp XMIN
        jr nc,$+4
        ld a,XMIN
        ld (iy+1),a
        ld (iy+3),c
        ld (iy+2),0
        ret

token_odds:     db 0,0,1,1,2,2,3,3,4,4,5,5,0,3,2,6

tokens_update:
        ld iy,tokens
        ld b,3
.l:     push bc
        call .one
        pop bc
        ld de,8
        add iy,de
        djnz .l
        ret
.one:   ld a,(iy+0)
        or a
        ret z
        ld l,(iy+2)
        ld h,(iy+3)
        ld de,374
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld a,h
        cp LAND_Y0-8
        ret c
        cp FLOOR_FEET
        jr nc,.gone
        ld a,(see_x+1)              ; caught on the plank?
        sub (iy+1)
        jr nc,$+4
        neg
        ld b,a
        ld a,(see_hw)
        add a,4
        cp b
        ret c
        jp collect_token
.gone:  ld (iy+0),0
        ret

clown_tokens:
        ld iy,tokens
        ld b,3
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        ld a,(iy+1)
        sub (ix+CS_X+1)
        add a,5
        cp 11
        jr nc,.n
        ld a,(iy+3)
        add a,8
        sub (ix+CS_Y+1)
        cp 24
        jr nc,.n
        call collect_token
.n:     pop bc
        ld de,8
        add iy,de
        djnz .l
        ret

; IY = token
collect_token:
        ld a,(iy+0)
        dec a
        ld (iy+0),0
        push af
        ld hl,SFX_POWER
        ld a,2
        call sfx
        ld a,1
        ld (hud_req),a
        pop af
        push af
        add a,a
        ld hl,tokname
        call add_hl_a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,10
        call popup_centre
        ld de,0100h
        call add_pts
        pop af
        or a
        jr nz,.n0
        ld a,250                    ; W: wide seesaw
        ld (pw_wide),a
        ld a,HW_WIDE
        ld (see_hw),a
        jp clamp_see
.n0:    dec a
        jr nz,.n1
        ld a,200                    ; S: slow motion
        ld (pw_slow),a
        ret
.n1:    dec a
        jr nz,.n2
        ld a,(pw_net)               ; N: safety net
        cp 3
        ret nc
        inc a
        ld (pw_net),a
        ret
.n2:    dec a
        jr nz,.n3
        ld a,250                    ; 2: double points
        ld (pw_x2),a
        ret
.n3:    dec a
        jr nz,.n4
        ld a,250                    ; U: umbrella
        ld (pw_umb),a
        ret
.n4:    dec a
        jr nz,.n5
        jp fireworks                ; F: fireworks
.n5:    ld a,(lives)                ; 1: extra life
        cp 9
        ret nc
        inc a
        ld (lives),a
        ld hl,SFX_1UP
        ld a,3
        jp sfx

tokname:        dw txt_wide,txt_slow,txt_net,txt_x2,txt_umb,txt_fire,txt_1up
; bold letters (bank 1): W S N 2 U F 1
tokglyph:       db 17h,13h,0Eh,22h,15h,06h,21h

draw_tokens:
        ld iy,tokens
        ld b,3
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        dec a
        ld hl,tokglyph
        call add_hl_a
        ld c,(hl)
        ld a,(iy+1)
        rrca
        rrca
        and 3Fh
        ld e,a
        ld a,(iy+3)
        rrca
        rrca
        rrca
        and 1Fh
        ld d,a
        ld a,(pal+P_BG)             ; a yellow / white tile, letter in the
        rlca                        ; background colour
        rlca
        rlca
        rlca
        or 80h+OWNBG+YELLOW
        ld b,a
        ld a,(tickpar)
        and 4
        jr z,$+4
        set 0,b                     ; yellow -> white
        call put_at
.n:     ld de,8
        add iy,de
        pop bc
        djnz .l
        ret

; FIREWORKS: up to six random balloons pop
fireworks:
        push ix
        push iy
        call .go
        pop iy
        pop ix
        ret
.go:    ld a,6
        ld (fw_n),a
        ld a,40
        ld (fw_try),a
.l:     ld a,(nrows)
        or a
        ret z
        ld a,(balloons_left)
        or a
        ret z
        ld hl,fw_try
        dec (hl)
        ret z
        ld a,(nrows)
        ld b,a
        call rand_below
        ld c,a
        ld b,20
        call rand_below
        ld b,a
        push bc
        call slot_ptr
        pop bc
        ld a,(hl)
        or a
        jr z,.l
        cp T_STEEL+1
        jr nz,.ok
        ld (hl),T_NORM+1
.ok:    push bc
        call slot_col
        add a,a
        add a,a
        add a,2
        ld b,a
        pop de
        push de
        push ix
        ld c,e
        call row_rec
        push iy
        pop ix
        call row_cy
        pop ix
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,8
        ld e,6
        call confetti
        pop bc
        call row_rec
        ld ix,clown0                ; credit the pops to a clown
        call pop_balloon
        ld hl,fw_n
        dec (hl)
        jr nz,.l
        ld hl,SFX_BOOM
        ld a,3
        jp sfx

; ---------------------------------------------------------------------
; bonus rounds: balloons float up from the floor
; +0 kind (1-3 colour, 4 gold, 5 gift), +1 x, +2/3 y, +4/5 vy
; ---------------------------------------------------------------------
freeb_update:
        ld a,(actflags)
        and AF_BONUS
        ret z
        ld hl,(bonus_time)
        ld a,h
        or l
        jr z,.tdone
        dec hl
        ld (bonus_time),hl
        ld a,l
        and 15
        jr nz,.spawn
        ld a,1
        ld (hud_req),a
        jr .spawn
.tdone: ld a,(endtimer)
        or a
        jr nz,.move
        ld a,30
        ld (endtimer),a
        jr .move
.spawn: ld hl,spawn_t
        dec (hl)
        jp p,.move
        ld (hl),14
        ld iy,freeb
        ld b,12
.f:     ld a,(iy+0)
        or a
        jr z,.got
        ld de,8
        add iy,de
        djnz .f
        jr .move
.got:   ld b,8
        call rand_below
        ld c,a
        cp 7
        ld a,4                      ; gold
        jr z,.st
        ld a,(actflags)
        and AF_PRIZE
        jr z,.col
        ld a,c
        cp 3
        ld a,5                      ; gift
        jr c,.st
.col:   ld a,c
.m3:    cp 3
        jr c,.ok3
        sub 3
        jr .m3
.ok3:   inc a
.st:    ld (iy+0),a
        ld b,126
        call rand_below
        add a,15
        ld (iy+1),a
        ld (iy+3),FLOOR_FEET
        ld (iy+2),0
        ld b,215
        call rand_below
        add a,136
        ld l,a
        ld a,0
        adc a,0
        ld h,a
        call neg_hl
        ld (iy+4),l
        ld (iy+5),h
.move:  ld iy,freeb
        ld b,12
.m:     ld a,(iy+0)
        or a
        jr z,.mn
        ld l,(iy+2)
        ld h,(iy+3)
        ld e,(iy+4)
        ld d,(iy+5)
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld a,h
        cp CEIL_Y
        jr c,.kill
        cp 200
        jr c,.mn
.kill:  ld (iy+0),0
.mn:    ld de,8
        add iy,de
        djnz .m
        ret

clown_freeb:
        ld a,(actflags)
        and AF_BONUS
        ret z
        ld iy,freeb
        ld b,12
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        ld a,(iy+1)
        sub (ix+CS_X+1)
        add a,5
        cp 11
        jr nc,.n
        ld a,(iy+3)
        add a,8
        sub (ix+CS_Y+1)
        cp 24
        jr nc,.n
        call pop_free
.n:     pop bc
        ld de,8
        add iy,de
        djnz .l
        ret

pop_free:
        ld a,(iy+0)
        ld (iy+0),0
        push af
        ld hl,bonus_pops
        inc (hl)
        inc (ix+CS_POPS)
        ld a,(combo)
        inc a
        ld (combo),a
        cp 9
        jr c,$+4
        ld a,8
        ld (mult),a
        pop af
        push af
        ld de,0100h
        cp 4                        ; gold
        jr nz,.ng
        ld de,0500h
.ng:    call mul_bcd
        call add_pts
        call pts_text
        ld a,(iy+3)
        rrca
        rrca
        rrca
        and 1Fh
        ld c,a
        ld a,(iy+1)
        ld hl,strbuf
        call popup_at
        pop af
        push af
        call freeb_colour
        ld b,(iy+1)
        ld c,(iy+3)
        ld e,6
        call burst
        ld hl,0FF02h
        ld (sfx_pop),hl
        ld hl,600
        ld (sfx_pop+2),hl
        ld hl,0
        ld (sfx_pop+4),hl
        ld hl,sfx_pop
        ld a,1
        call sfx
        pop af
        cp 5                        ; gift
        ret nz
        ld b,(iy+1)
        ld c,(iy+3)
        jp spawn_token

; kind A -> colour A
freeb_colour:
        cp 4
        ld c,YELLOW
        jr z,.c
        ld c,WHITE
        jr nc,.c
        ld hl,pal
        call add_hl_a               ; kinds 1..3 = pal b0..b2
        ld c,(hl)
.c:     ld a,c
        ret

draw_freeb:
        ld a,(actflags)
        and AF_BONUS
        ret z
        ld iy,freeb
        ld b,12
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        call freeb_colour
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld c,G_BALLOON
        ld a,(iy+0)
        cp 4
        jr c,.k
        set 7,b
        ld c,3Eh                    ; gold: a big round balloon (bank 1)
        jr z,.k
        ld c,8Fh                    ; gift: striped
.k:     ld a,(iy+1)
        rrca
        rrca
        and 3Fh
        ld e,a
        ld a,(iy+3)
        rrca
        rrca
        rrca
        and 1Fh
        ld d,a
        push de
        call put_at
        pop de
        inc d
        ld a,(pal+P_SEAM)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld c,G_STRING
        call put_at
.n:     ld de,8
        add iy,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; particles: tiny quarter-cell specks, drawn at half-cell precision
; ---------------------------------------------------------------------
; burst at (B = x, C = y), colour A (8+ = random), E = count
burst:
        ld (pb_col),a
        xor a
        ld (pb_style),a
        jr spawn_parts
confetti:
        ld (pb_col),a
        ld a,1
        ld (pb_style),a
spawn_parts:
        push iy
        push hl
        call .go
        pop hl
        pop iy
        ret
.go:    ld iy,parts
        ld d,NPARTS
.f:     ld a,(iy+0)
        or a
        jp nz,.n
        push bc
        ld b,16
        call rand_below
        pop bc
        add a,10
        ld (iy+0),a
        ld a,(pb_col)
        cp 8
        jr c,.c
        push bc
        ld b,4
        call rand_below
        pop bc
        inc a
        push hl
        ld hl,pal
        call add_hl_a
        ld a,(hl)
        pop hl
.c:     ld (iy+1),a
        ld (iy+3),b
        ld (iy+2),128
        ld (iy+5),c
        ld (iy+4),128
        ld a,(pb_style)
        or a
        jr nz,.conf
        call rand
        and 63
        sub 32
        call sx_hl
        call .x5
        ld (iy+6),l
        ld (iy+7),h
        call rand
        and 63
        sub 48
        call sx_hl
        call .x14
        ld (iy+8),l
        ld (iy+9),h
        jr .dn
.conf:  call rand
        and 127
        sub 64
        call sx_hl
        call .x5
        ld (iy+6),l
        ld (iy+7),h
        call rand
        and 31
        sub 32
        call sx_hl
        call .x14
        ld (iy+8),l
        ld (iy+9),h
        ld (iy+0),36
.dn:    dec e
        ret z
.n:     push de
        ld de,PT_SIZE
        add iy,de
        pop de
        dec d
        jp nz,.f
        ret
.x5:    push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        pop de
        ret
.x14:   push de
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        pop de
        ret

parts_update:
        ld iy,parts
        ld b,NPARTS
.l:     ld a,(iy+0)
        or a
        jr z,.n
        dec (iy+0)
        ld l,(iy+2)
        ld h,(iy+3)
        ld e,(iy+6)
        ld d,(iy+7)
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld a,h
        cp 160
        jr nc,.kill
        ld l,(iy+8)
        ld h,(iy+9)
        ld de,34                    ; gravity
        add hl,de
        ld (iy+8),l
        ld (iy+9),h
        ld e,(iy+4)
        ld d,(iy+5)
        add hl,de
        ld (iy+4),l
        ld (iy+5),h
        ld a,h
        cp FLOOR_FEET
        jr c,.n
.kill:  ld (iy+0),0
.n:     ld de,PT_SIZE
        add iy,de
        djnz .l
        ret

parts_draw:
        ld iy,parts
        ld b,NPARTS
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        ld a,(iy+3)                 ; x: cell, and which half
        ld c,a
        rrca
        rrca
        and 3Fh
        ld e,a
        ld a,(iy+5)
        ld b,a
        rrca
        rrca
        rrca
        and 1Fh
        ld d,a
        ld a,c                      ; speck: bit 0 TL, 1 TR, 2 BL, 3 BR
        rrca
        and 1                       ; right half?
        bit 2,b
        jr z,$+4
        add a,2                     ; lower half
        ld b,a
        ld a,1
        inc b
.sh:    dec b
        jr z,.g
        add a,a
        jr .sh
.g:     or 0F0h
        ld c,a
        ld a,(iy+1)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        call put_at
.n:     ld de,PT_SIZE
        add iy,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; pop-up texts
; ---------------------------------------------------------------------
; HL = text, A = x (units, centre), C = row
popup_at:
        rrca
        rrca
        and 3Fh
        ld b,a
        push hl
        call strlen
        pop hl
        srl a
        ld e,a
        ld a,b
        sub e
        jr nc,$+3
        xor a
        ld b,a
        jr popup_col
; HL = text, C = row
popup_centre:
        call strlen
        ld b,a
        ld a,40
        sub b
        srl a
        ld b,a
; HL = text, B = column, C = row
popup_col:
        push iy
        push de
        call .go
        pop de
        pop iy
        ret
.go:    ld a,b                      ; keep it inside the poles
        or a
        jr nz,$+3
        inc b
        push hl
        call strlen
        pop hl
        add a,b
        cp 40
        jr c,.fits
        sub 39
        ld e,a
        ld a,b
        sub e
        ld b,a
.fits:  ld a,c
        or a
        jr nz,$+3
        inc c
        ld iy,popups
        ld e,NPOPS
.f:     ld a,(iy+0)
        or a
        jr z,.got
        push de
        ld de,PU_SIZE
        add iy,de
        pop de
        dec e
        jr nz,.f
        ld iy,popups                ; all busy: reuse the first
.got:   ld (iy+0),18
        ld (iy+1),b
        ld (iy+2),c
        push iy
        pop de
        inc de
        inc de
        inc de
        inc de
        ld b,9
.c:     ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        djnz .c
        xor a
        ld (de),a
        ret

popups_update:
        ld iy,popups
        ld b,NPOPS
.l:     ld a,(iy+0)
        or a
        jr z,.n
        dec (iy+0)
        ld a,(iy+0)
        cp 12
        jr z,.up
        cp 6
        jr nz,.n
.up:    ld a,(iy+2)
        cp 2
        jr c,.n
        dec (iy+2)
.n:     ld de,PU_SIZE
        add iy,de
        djnz .l
        ret

popups_draw:
        ld iy,popups
        ld b,NPOPS
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        and 2
        ld a,(pal+P_A1)
        jr z,$+5
        ld a,(pal+P_A2)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld d,(iy+2)
        ld e,(iy+1)
        push iy
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        call put_text
.n:     ld de,PU_SIZE
        add iy,de
        pop bc
        djnz .l
        ret
