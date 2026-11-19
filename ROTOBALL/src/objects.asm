; ======================================================================
;  objects.asm - gems, exit, mines, crawlers, pickups; overlay sprites
; ======================================================================

objects_update:
    ld ix,OBJS
    ld b,MAXOBJ
.lp:
    ld a,(ix+O_TYPE)
    or a
    jr z,.next
    push bc
    cp T_CRAWLER
    call z,move_crawler
    call obj_collide
    pop bc
    ld a,(state)
    or a
    ret nz              ; died or cleared
.next:
    ld de,8
    add ix,de
    djnz .lp
    ret

; crawlers patrol along one axis, turning round at walls
move_crawler:
    ld a,(ix+O_SPD)
    ld e,a
    rla
    sbc a,a
    ld d,a              ; DE = speed, sign-extended
    bit 0,(ix+O_AXIS)
    jr nz,.vert
    ld l,(ix+O_XF)
    ld h,(ix+O_XC)
    add hl,de
    push hl
    call lead_edge
    ld l,h
    ld h,(ix+O_YP)
    bit 7,(hl)
    pop hl
    jr nz,reverse
    ld (ix+O_XF),l
    ld (ix+O_XC),h
    ret
.vert:
    ld l,(ix+O_YF)
    ld h,(ix+O_YP)
    add hl,de
    push hl
    call lead_edge
    ld l,(ix+O_XC)
    bit 7,(hl)
    pop hl
    jr nz,reverse
    ld (ix+O_YF),l
    ld (ix+O_YP),h
    ret

reverse:
    ld a,(ix+O_SPD)
    neg
    ld (ix+O_SPD),a
    ret

lead_edge:              ; HL += +-half a cell in the direction of DE
    bit 7,d
    ld de,80h
    jr z,.p
    ld de,-80h
.p:
    add hl,de
    ret

; does the ball overlap object IX? if so, act on it
obj_collide:
    ld hl,(ballx)
    ld e,(ix+O_XF)
    ld d,(ix+O_XC)
    or a
    sbc hl,de
    ld (cdx),hl
    call near_hit
    ret nc
    ld hl,(bally)
    ld e,(ix+O_YF)
    ld d,(ix+O_YP)
    or a
    sbc hl,de
    ld (cdy),hl
    call near_hit
    ret nc
    ld a,(ix+O_TYPE)
    cp T_GEM
    jr z,hit_gem
    cp T_MINE
    jp z,hit_mine
    cp T_CRAWLER
    jp z,hit_crawler
    cp T_BOMB
    jp z,hit_bomb
    cp T_SHIELD
    jp z,hit_shield
    cp T_EXITOPEN
    jp z,hit_exit
    ret

near_hit:               ; carry if |HL| < HIT_R
    bit 7,h
    call nz,neg_hl
    ld a,h
    or a
    ret nz
    ld a,l
    cp HIT_R
    ret

hit_gem:
    ld (ix+O_TYPE),0
    ld de,0050h
    call add_score
    ld hl,sfx_gem
    ld a,SFXP_GEM
    call play_sfx
    ld hl,gems
    dec (hl)
    ret nz
    push ix             ; last gem: open the exit
    ld ix,OBJS
    ld b,MAXOBJ
    ld de,8
.ex:
    ld a,(ix+O_TYPE)
    cp T_EXIT
    jr nz,.nx
    ld (ix+O_TYPE),T_EXITOPEN
.nx:
    add ix,de
    djnz .ex
    pop ix
    ld hl,txt_exit
    call set_msg
    ld hl,sfx_exitopen
    ld a,SFXP_EXITOPEN
    jp play_sfx

hit_mine:
    ld a,(shield)
    or a
    jp z,die
    ld (ix+O_TYPE),0
    ld de,0025h
    call add_score
    ld hl,sfx_shieldhit
    ld a,SFXP_SHIELDHIT
    jp play_sfx

hit_crawler:
    ld a,(shield)
    or a
    jr nz,.kill
    call is_stomp
    jp nc,die
    call bounce_up
.kill:
    ld (ix+O_TYPE),0
    ld de,0100h
    call add_score
    ld hl,txt_stomp
    call set_msg
    ld hl,sfx_stomp
    ld a,SFXP_STOMP
    jp play_sfx

hit_bomb:
    ld (ix+O_TYPE),0
    ld a,(bombs)
    inc a
    ld (bombs),a
    ld de,0010h
    call add_score
    ld hl,txt_bomb
    call set_msg
    ld hl,sfx_pickup
    ld a,SFXP_PICKUP
    jp play_sfx

hit_shield:
    ld (ix+O_TYPE),0
    ld a,SHIELD_TIME
    ld (shield),a
    ld de,0010h
    call add_score
    ld hl,txt_shield
    call set_msg
    ld hl,sfx_pickup
    ld a,SFXP_PICKUP
    jp play_sfx

hit_exit:
    ld a,S_CLEAR
    ld (state),a
    ld a,40
    ld (timer),a
    ld de,1000h
    call add_score
    ld hl,txt_clear
    call set_msg
    ld hl,sfx_clear
    ld a,SFXP_CLEAR
    jp play_sfx

; Stomp = the ball is on the "up" side of the crawler (relative to gravity)
; and moving down. Gravity direction g = (-sin, cos); with d = ball - crawler,
; up-side means d.g < 0: dy*cos - dx*sin < 0.  Down means v.g > 0.
is_stomp:
    call get_cs
    ld hl,(cdx)
    add hl,hl
    add hl,hl
    ld a,h
    ld (t_dx),a         ; dx in quarter cells
    ld hl,(cdy)
    add hl,hl
    add hl,hl
    ld a,h
    ld (t_dy),a
    call dot_g          ; HL = dy*C - dx*S
    bit 7,h
    jr z,.no
    ld hl,(vx)
    sra h
    rr l
    ld a,l
    ld (t_dx),a
    ld hl,(vy)
    sra h
    rr l
    ld a,l
    ld (t_dy),a
    call dot_g
    bit 7,h
    jr nz,.no
    ld a,h
    or l
    jr z,.no
    scf
    ret
.no:
    or a
    ret

get_cs:                 ; (sin8v), (cos8v) = 127 sin/cos of the angle
    ld a,(angle)
    ld l,a
    ld h,hi(SIN8)
    ld a,(hl)
    ld (sin8v),a
    ld a,l
    add a,64
    ld l,a
    ld a,(hl)
    ld (cos8v),a
    ret

dot_g:                  ; HL = t_dy*C - t_dx*S
    ld a,(cos8v)
    ld e,a
    ld a,(t_dy)
    call mul_s8
    push hl
    ld a,(sin8v)
    ld e,a
    ld a,(t_dx)
    call mul_s8
    ex de,hl
    pop hl
    or a
    sbc hl,de
    ret

; HL = A * E, signed, |A| + |E| < 256. Quarter squares: ab = f(a+b) - f(|a-b|)
mul_s8:
    ld b,a
    xor e
    ld c,a              ; bit 7 = sign of the result
    ld a,b
    or a
    jp p,.p1
    neg
.p1:
    ld b,a
    ld a,e
    or a
    jp p,.p2
    neg
.p2:
    ld e,a
    add a,b
    ld l,a
    ld h,hi(SQL)
    ld a,(hl)
    inc h
    ld h,(hl)
    ld l,a              ; HL = f(|a|+|b|)
    ld a,b
    sub e
    jr nc,.p3
    neg
.p3:
    ld e,a
    ld d,hi(SQL)
    ld a,(de)
    push af
    inc d
    ld a,(de)
    ld d,a
    pop af
    ld e,a              ; DE = f(||a|-|b||)
    or a
    sbc hl,de
    bit 7,c
    ret z
    jp neg_hl

; ----------------------------------------------------------------------
; Project every object near the ball onto the screen:
;   column = C + round(dx cos + dy sin), row = C + round(dy cos - dx sin)
build_overlay:
    call get_cs
    xor a
    ld (ovlcount),a
    ld iy,OVL+1
    ld ix,OBJS
    ld b,MAXOBJ
.lp:
    ld a,(ix+O_TYPE)
    or a
    jp z,.next
    push bc
    ld l,(ix+O_XF)
    ld h,(ix+O_XC)
    ld de,(ballx)
    or a
    sbc hl,de
    ld a,h
    add a,17
    cp 34
    jp nc,.skip
    add hl,hl
    add hl,hl
    ld a,h
    ld (t_dx),a
    ld l,(ix+O_YF)
    ld h,(ix+O_YP)
    ld de,(bally)
    or a
    sbc hl,de
    ld a,h
    add a,17
    cp 34
    jp nc,.skip
    add hl,hl
    add hl,hl
    ld a,h
    ld (t_dy),a
    ld a,(cos8v)        ; column
    ld e,a
    ld a,(t_dx)
    call mul_s8
    push hl
    ld a,(sin8v)
    ld e,a
    ld a,(t_dy)
    call mul_s8
    pop de
    add hl,de
    ld de,256
    add hl,de
    ld a,h
    sra a
    add a,VIEW_C
    cp VIEW_CHARS
    jr nc,.skip
    ld (t_col),a
    call dot_g          ; row
    ld de,256
    add hl,de
    ld a,h
    sra a
    add a,VIEW_C
    cp VIEW_CHARS
    jr nc,.skip
    ld (iy+0),a
    ld a,(t_col)
    ld (iy+1),a
    call obj_glyph
    ld (iy+2),d
    ld (iy+3),e
    ld de,4
    add iy,de
    ld hl,ovlcount
    inc (hl)
.skip:
    pop bc
.next:
    ld de,8
    add ix,de
    dec b
    jp nz,.lp
    ld a,(ovlcount)
    ld (OVL),a
    jp ball_glyph

; D = char, E = attribute for object IX (4-frame animation)
obj_glyph:
    ld a,(framecnt)
    rra
    ld c,a
    ld a,ixl
    rrca
    rrca
    rrca
    add a,c
    and 3
    add a,a
    ld c,a
    ld a,(ix+O_TYPE)
    add a,a
    add a,a
    add a,a
    add a,c
    ld e,a
    ld d,0
    ld hl,GLYPHS
    add hl,de
    ld d,(hl)
    inc hl
    ld e,(hl)
    ret

ball_glyph:
    ld a,(state)
    cp S_DYING
    jr z,.dying
    cp S_CLEAR
    jr z,.clear
    ld a,(shield)
    or a
    jr z,.norm
    ld a,(framecnt)
    and 2
    jr z,.norm
    ld hl,0D088h        ; shielded: cyan double ring (set 1)
    jr .set
.norm:
    ld hl,7047h         ; white ball
    jr .set
.dying:
    ld a,(timer)
    rra
    and 6
    ld e,a
    ld d,0
    ld hl,DEATHG
    add hl,de
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    jr .set
.clear:
    ld a,(framecnt)
    and 7
    ld e,a
    ld d,hi(STRIP)
    ld a,(de)
    ld h,a
    ld l,47h
.set:
    ld a,l
    ld (ballch),a
    ld a,h
    ld (ballat),a
    ret

; char, attribute (bit7 = second character set, bits 6-4 = colour)
GLYPHS:
    db 0,0, 0,0, 0,0, 0,0                       ; 0 (unused)
    db 44h,50h, 6Bh,70h, 6Ah,60h, 6Bh,70h       ; 1 gem: sparkle
    db 8Bh,90h, 8Bh,90h, 8Bh,90h, 8Bh,90h       ; 2 exit, closed: blue box
    db 1Eh,0A0h, 1Eh,0E0h, 6Bh,20h, 1Eh,0B0h    ; 3 mine: flicker
    db 2Ch,0B0h, 2Dh,0B0h, 2Ch,0C0h, 2Dh,0C0h   ; 4 crawler: walking
    db 9Dh,0F0h, 9Dh,0A0h, 9Dh,0F0h, 9Dh,0A0h   ; 5 bomb pickup
    db 8Fh,0D0h, 8Fh,0F0h, 8Fh,0D0h, 8Fh,0F0h   ; 6 shield pickup
    db 82h,0C0h, 83h,0D0h, 84h,0F0h, 88h,0D0h   ; 7 exit, open: pulsing ring

DEATHG:                 ; ball bursting (timer counts down)
    db 82h,0E0h, 83h,0A0h, 84h,0E0h, 88h,0A0h
