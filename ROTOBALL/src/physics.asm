; ======================================================================
;  physics.asm - keys, rotation and ball physics
; ======================================================================

read_keys:
    ld a,0F7h           ; row 7: cursor keys (bit2 left, bit3 right)
    ld (KBD_ROW),a
    nop
    ld a,(KBD_COL)
    cpl
    and K_LEFT+K_RIGHT
    ld c,a
    ld a,0F1h           ; row 1: Z = bit6
    ld (KBD_ROW),a
    nop
    ld a,(KBD_COL)
    bit 6,a
    jr nz,.noz
    set 2,c
.noz:
    ld a,0F2h           ; row 2: X = bit0
    ld (KBD_ROW),a
    nop
    ld a,(KBD_COL)
    bit 0,a
    jr nz,.nox
    set 3,c
.nox:
    ld a,0F6h           ; row 6: SPACE = bit4
    ld (KBD_ROW),a
    nop
    ld a,(KBD_COL)
    bit 4,a
    jr nz,.nosp
    set 4,c
.nosp:
    ld a,(keys)
    ld (prevkeys),a
    cpl
    and c
    ld (keyedge),a      ; newly pressed this frame
    ld a,c
    ld (keys),a
    ret

rotate:
    ld a,(keys)
    ld c,a
    ld a,(angle)
    bit 2,c
    jr z,.nl
    sub ROTSPD
.nl:
    bit 3,c
    jr z,.nr
    add a,ROTSPD
.nr:
    ld (angle),a
    ret

; Physics in map space. Gravity = screen-down = (-sin, cos) * 1/32 cell/frame^2.
physics:
    ld a,(angle)
    call getsin         ; DE = 128 sin
    call sra4_de
    ld hl,(vx)
    or a
    sbc hl,de           ; vx -= sin/16
    call friction
    call clamp
    ld (vx),hl
    ld a,(angle)
    add a,64
    call getsin         ; DE = 128 cos
    call sra4_de
    ld hl,(vy)
    add hl,de
    call friction
    call clamp
    ld (vy),hl
    call move_x
    jp move_y

sra4_de:
    sra d
    rr e
    sra d
    rr e
    sra d
    rr e
    sra d
    rr e
    ret

friction:               ; HL -= HL/64
    push hl
    ld d,h
    ld e,l
    ld b,6
.f:
    sra d
    rr e
    djnz .f
    pop hl
    or a
    sbc hl,de
    ret

clamp:                  ; clamp HL to +-VMAX
    bit 7,h
    jr nz,.neg
    ld de,VMAX
    or a
    push hl
    sbc hl,de
    pop hl
    ret c
    ld hl,VMAX
    ret
.neg:
    ld de,-VMAX
    or a
    push hl
    sbc hl,de
    pop hl
    ret nc
    ld hl,-VMAX
    ret

; is map cell (B = column, C = row page) a wall? NZ if so
wall_at:
    ld h,c
    ld l,b
    bit 7,(hl)
    ret

move_x:
    ld de,(vx)
    ld a,d
    or e
    ret z
    ld hl,(ballx)
    add hl,de
    ld (newp),hl
    bit 7,d
    jr nz,.left
    ld de,BALL_R
    add hl,de
    jr .edge
.left:
    ld de,-BALL_R
    add hl,de
.edge:
    ld b,h              ; column of the leading edge
    ld hl,(bally)
    ld de,-BALL_R
    add hl,de
    ld c,h
    call wall_at
    jr nz,.hit
    ld hl,(bally)
    ld de,BALL_R
    add hl,de
    ld c,h
    call wall_at
    jr nz,.hit
    ld hl,(newp)
    ld (ballx),hl
    ret
.hit:
    ld hl,(vx)
    call bounce
    ld (vx),hl
    ret

move_y:
    ld de,(vy)
    ld a,d
    or e
    ret z
    ld hl,(bally)
    add hl,de
    ld (newp),hl
    bit 7,d
    jr nz,.up
    ld de,BALL_R
    add hl,de
    jr .edge
.up:
    ld de,-BALL_R
    add hl,de
.edge:
    ld c,h              ; row page of the leading edge
    ld hl,(ballx)
    ld de,-BALL_R
    add hl,de
    ld b,h
    call wall_at
    jr nz,.hit
    ld hl,(ballx)
    ld de,BALL_R
    add hl,de
    ld b,h
    call wall_at
    jr nz,.hit
    ld hl,(newp)
    ld (bally),hl
    ret
.hit:
    ld hl,(vy)
    call bounce
    ld (vy),hl
    ret

; HL = velocity that hit a wall -> HL = -HL/2, with a clink if it was fast
bounce:
    push hl
    bit 7,h
    call nz,neg_hl
    ld de,24
    or a
    sbc hl,de
    jr c,.quiet
    ld hl,sfx_clink
    ld a,SFXP_CLINK
    call play_sfx
.quiet:
    pop hl
    sra h
    rr l
    jp neg_hl

; launch the ball against gravity: v = (sin, -cos) * 3/4 * 0.5 cell/frame
bounce_up:
    ld a,(angle)
    call getsin
    ex de,hl
    call x075
    ld (vx),hl
    ld a,(angle)
    add a,64
    call getsin
    ex de,hl
    call x075
    call neg_hl
    ld (vy),hl
    ret

x075:                   ; HL = HL * 3/4
    ld d,h
    ld e,l
    sra d
    rr e
    sra d
    rr e
    or a
    sbc hl,de
    ret
