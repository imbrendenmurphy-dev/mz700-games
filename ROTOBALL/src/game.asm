; ======================================================================
;  game.asm - game states, levels, lives, bombs
; ======================================================================

game_logic:
    ld a,(state)
    or a
    jp z,play
    cp S_DYING
    jp z,dying
    cp S_CLEAR
    jp z,clearing
    cp S_READY
    jp z,ready
    ; S_OVER: after a pause, high-score entry or back to the title
    ld hl,timer
    dec (hl)
    ret nz
    call qualifies
    jp c,hientry
    ld a,2
    jp title

ready:                  ; level intro / respawn: look around, no gravity yet
    call rotate
    ld hl,timer
    dec (hl)
    ret nz
    xor a
    ld (state),a
    ld hl,txt_go
    jp set_msg

play:
    call rotate
    call physics
    call objects_update
    ld a,(state)
    or a
    ret nz
    call fire_check
    ld a,(shield)
    or a
    jr z,.ns
    dec a
    ld (shield),a
.ns:
    jp spin_hiss

dying:
    ld hl,timer
    dec (hl)
    ret nz
    ld a,(demo)         ; attract mode ends at the first mishap
    or a
    jr nz,demo_end
    ld a,(lives)
    or a
    jr z,.over
    jp respawn
.over:
    ld a,S_OVER
    ld (state),a
    ld a,40
    ld (timer),a
    ld hl,txt_over
    call set_msg
    ld hl,sfx_gameover
    ld a,SFXP_GAMEOVER
    jp play_sfx

clearing:
    ld hl,timer
    dec (hl)
    ret nz
    ld a,(demo)
    or a
    jr nz,demo_end
    ld a,(level)
    inc a
    cp NUM_LEVELS
    jr c,.ok
    xor a
.ok:
    ld (level),a
    jp start_level

demo_end:
    xor a
    jp title

; ----------------------------------------------------------------------
; Attract-mode autopilot: steer gravity towards the next waypoint of the
; route worked out by tools/levels.py. Rotating the angle up turns gravity
; anticlockwise; P = C*dx + S*dy is minus the cross product g x d.
autopilot:
    ld hl,(demo_wp)
    ld a,(hl)
    cp 0FFh
    jr z,.none
    add a,MAZE_COL0
    ld d,a
    ld e,80h
    push hl
    ld hl,(ballx)
    ex de,hl
    or a
    sbc hl,de           ; dx = target - ball
    ld (cdx),hl
    pop hl
    inc hl
    ld a,(hl)
    add a,MAP_PAGE+MAZE_ROW0
    ld d,a
    ld e,80h
    ld hl,(bally)
    ex de,hl
    or a
    sbc hl,de
    ld (cdy),hl
    ld hl,(cdx)         ; close enough: next waypoint
    call abs_hi
    or a
    jr nz,.far
    ld a,l
    cp 0C0h
    jr nc,.far
    ld hl,(cdy)
    call abs_hi
    or a
    jr nz,.far
    ld a,l
    cp 0C0h
    jr nc,.far
    ld hl,(demo_wp)
    inc hl
    inc hl
    ld (demo_wp),hl
.none:
    xor a
    ret
.far:
    ld hl,(cdx)
    call clamp_q
    ld (t_dx),a
    ld hl,(cdy)
    call clamp_q
    ld (t_dy),a
    call get_cs
    call dot_g          ; HL = dot(g, d)
    push hl
    ld a,(cos8v)        ; P = C*dx + S*dy
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
    pop de              ; DE = dot
    bit 7,d
    jr nz,.turn         ; pointing away: always turn
    push hl             ; |P| < dot/4: close enough, hold still
    bit 7,h
    call nz,neg_hl
    srl d
    rr e
    srl d
    rr e
    or a
    sbc hl,de
    pop hl
    jr c,.none
.turn:
    bit 7,h
    ld a,K_RIGHT        ; P < 0 (cross > 0): angle up
    ret nz
    ld a,K_LEFT
    ret

clamp_q:                ; HL (8.8 cells) -> A = quarter cells, clamped to +-60
    ld a,h
    bit 7,h
    jr nz,.neg
    cp 15
    jr c,.ok
    ld a,60
    ret
.neg:
    cp -15
    jr nc,.ok
    ld a,-60
    ret
.ok:
    add hl,hl
    add hl,hl
    ld a,h
    ret

; ----------------------------------------------------------------------
start_level:
    call load_level
    call respawn_pos
    ld a,S_READY
    ld (state),a
    ld a,40
    ld (timer),a
    xor a
    ld (shield),a
    ld hl,sfx_start
    ld a,SFXP_START
    call play_sfx
    ld hl,txt_level
    call set_msg
    ld a,(level)
    inc a
    ld de,msgbuf+6
    jp print_dec2

respawn:
    call respawn_pos
    ld a,S_READY
    ld (state),a
    ld a,20
    ld (timer),a
    ld hl,txt_ready
    jp set_msg

respawn_pos:
    ld a,(startx)
    add a,MAZE_COL0
    ld h,a
    ld l,80h
    ld (ballx),hl
    ld a,(starty)
    add a,MAP_PAGE+MAZE_ROW0
    ld h,a
    ld l,80h
    ld (bally),hl
    ld hl,0
    ld (vx),hl
    ld (vy),hl
    xor a
    ld (angle),a
    ret

die:
    ld a,(shield)
    or a
    ret nz
    ld a,(lives)
    dec a
    ld (lives),a
    ld a,S_DYING
    ld (state),a
    ld a,30
    ld (timer),a
    ld a,6
    ld (flash),a
    ld hl,txt_splat
    call set_msg
    ld hl,sfx_death
    ld a,SFXP_DEATH
    jp play_sfx

; ----------------------------------------------------------------------
; level data: wbytes, rows, startx, starty, wall bits, objects (5 bytes), 0
load_level:
    ld hl,MAP_PAGE*256  ; whole map: indestructible rock
    ld de,MAP_PAGE*256+1
    ld bc,MAP_ROWS*256-1
    ld (hl),82h
    ldir
    ld a,(level)
    add a,a
    ld e,a
    ld d,0
    ld hl,LEVELTAB
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl
    ld a,(hl)
    inc hl
    ld (lv_wb),a
    ld a,(hl)
    inc hl
    ld (lv_h),a
    ld a,(hl)
    inc hl
    ld (startx),a
    ld a,(hl)
    inc hl
    ld (starty),a
    ld d,MAP_PAGE+MAZE_ROW0
    ld a,(lv_h)
    ld c,a
.row:
    ld e,MAZE_COL0
    ld a,(lv_wb)
    ld b,a
.byte:
    ld a,(hl)
    inc hl
    push bc
    ld b,8
.bit:
    rla
    ex de,hl
    ld (hl),0
    jr nc,.open
    ld (hl),81h         ; level wall (bombs can break it)
.open:
    ex de,hl
    inc e
    djnz .bit
    pop bc
    djnz .byte
    inc d
    dec c
    jr nz,.row
    ; objects
    push hl
    ld hl,OBJS
    ld de,OBJS+1
    ld bc,MAXOBJ*8-1
    ld (hl),0
    ldir
    pop hl
    ld ix,OBJS
    xor a
    ld (gems),a
.obj:
    ld a,(hl)
    or a
    ret z
    inc hl
    ld (ix+O_TYPE),a
    cp T_GEM
    jr nz,.ng
    ld a,(gems)
    inc a
    ld (gems),a
.ng:
    ld a,(hl)
    inc hl
    add a,MAZE_COL0
    ld (ix+O_XC),a
    ld (ix+O_XF),80h
    ld a,(hl)
    inc hl
    add a,MAP_PAGE+MAZE_ROW0
    ld (ix+O_YP),a
    ld (ix+O_YF),80h
    ld a,(hl)
    inc hl
    ld (ix+O_AXIS),a
    ld a,(hl)
    inc hl
    ld (ix+O_SPD),a
    ld de,8
    add ix,de
    jr .obj

; ----------------------------------------------------------------------
; SPACE: set off a bomb - smash level walls in a 5x5 square, destroy
; mines and crawlers within 3 cells.
fire_check:
    ld a,(keyedge)
    and K_FIRE
    ret z
    ld a,(bombs)
    or a
    ret z
    dec a
    ld (bombs),a
    ld a,(bally+1)
    sub 2
    ld h,a
    ld c,5
.brow:
    ld a,(ballx+1)
    sub 2
    ld l,a
    ld b,5
.bcol:
    ld a,(hl)
    cp 81h
    jr nz,.keep
    ld (hl),0
.keep:
    inc l
    djnz .bcol
    inc h
    dec c
    jr nz,.brow
    ld ix,OBJS
    ld b,MAXOBJ
.obj:
    ld a,(ix+O_TYPE)
    cp T_MINE
    jr z,.near
    cp T_CRAWLER
    jr nz,.next
.near:
    push bc
    ld hl,(ballx)
    ld e,(ix+O_XF)
    ld d,(ix+O_XC)
    or a
    sbc hl,de
    call abs_hi
    cp 3
    jr nc,.far
    ld hl,(bally)
    ld e,(ix+O_YF)
    ld d,(ix+O_YP)
    or a
    sbc hl,de
    call abs_hi
    cp 3
    jr nc,.far
    ld (ix+O_TYPE),0
    ld de,0050h
    call add_score
.far:
    pop bc
.next:
    ld de,8
    add ix,de
    djnz .obj
    ld a,8
    ld (flash),a
    ld hl,txt_boom
    call set_msg
    ld hl,sfx_bomb
    ld a,SFXP_BOMB
    jp play_sfx

abs_hi:                 ; A = high byte of |HL|
    bit 7,h
    call nz,neg_hl
    ld a,h
    ret

; DE = BCD points (4 digits) added to the 6-digit BCD score
add_score:
    ld hl,score
    ld a,(hl)
    add a,e
    daa
    ld (hl),a
    inc hl
    ld a,(hl)
    adc a,d
    daa
    ld (hl),a
    inc hl
    ld a,(hl)
    adc a,0
    daa
    ld (hl),a
    ret
