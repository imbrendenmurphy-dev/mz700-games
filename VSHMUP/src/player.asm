; =====================================================================
;  player.asm - the ship, its weapons, options, bombs and shield
;
;  The ship is 3 cells wide and 2 tall; px/py is its nose cell (the
;  centre column).  Only the centre column (nose and body) can be hit.
;  Weapons: VULCAN (spread, 1..5 streams) or LASER (piercing beams,
;  1..3), power 1..5.  Options trail the ship and fire straight ahead.
; =====================================================================

PX0     equ 14                  ; start: column, row
PY0     equ 21

player_reset:                   ; a fresh ship (new game or after a loss)
        ld hl,PX0*256
        ld (px),hl
        ld hl,PY0*256
        ld (py),hl
        ld hl,TRAIL             ; the options start on the ship
        ld b,32
.t:     ld (hl),PX0
        inc hl
        ld (hl),PY0+1
        inc hl
        djnz .t
        xor a
        ld (trailp),a
        ld (firecd),a
        ld (bombtm),a
        ld a,75                 ; 3 seconds of grace
        ld (invuln),a
        ld a,1
        ld (hudpow),a
        ret

; ---------------------------------------------------------------------
player_tick:
        ld a,(gstate)
        cp G_DEAD
        jp z,dead_tick
        cp G_OVER
        ret z
        ld a,(invuln)
        or a
        jr z,.ni
        dec a
        ld (invuln),a
.ni:    call move_ship
        call fire_tick
        call bomb_tick
        ret

move_ship:
        ld a,(gstate)
        cp G_CLEAR              ; stage clear: fly up and away
        jr nz,.ctl
        ld a,(cleartm)
        cp 100
        ret nc
        ld hl,(py)
        ld de,-80h
        add hl,de
        bit 7,h
        jr nz,.gone
        ld (py),hl
        ret
.gone:  ld hl,0FE00h            ; off the top
        ld (py),hl
        ret
.ctl:   ld a,(speed)            ; speed 0..3 -> 0.5 .. 0.875 cells a tick
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,80h
        ld e,a
        ld d,0
        ld a,(keys)
        ld c,a
        ld hl,(px)
        bit 2,c
        jr z,.r
        or a
        sbc hl,de
        call clamp_lo
.r:     bit 3,c
        jr z,.x
        add hl,de
        ld a,h
        cp PFW-2+1              ; column <= 28
        jr c,.x
        ld hl,(PFW-2)*256
.x:     ld (px),hl
        ld hl,(py)
        bit 0,c
        jr z,.d
        or a
        sbc hl,de
        call clamp_lo
.d:     bit 1,c
        jr z,.y
        add hl,de
        ld a,h
        cp PFH-2+1              ; row <= 23
        jr c,.y
        ld hl,(PFH-2)*256
.y:     ld (py),hl
        ; options follow the trail of cells the ship has been to
        ld a,(px+1)
        ld b,a
        ld a,(py+1)
        inc a
        ld c,a                  ; B, C = body cell
        ld a,(trailp)
        add a,a
        ld l,a
        ld h,high TRAIL
        ld a,(hl)
        cp b
        jr nz,.push
        inc l
        ld a,(hl)
        cp c
        ret z
.push:  ld a,(trailp)
        inc a
        and 31
        ld (trailp),a
        add a,a
        ld l,a
        ld (hl),b
        inc l
        ld (hl),c
        ret

; HL = position: at least 1.0
clamp_lo:
        bit 7,h
        jr nz,.c
        ld a,h
        or a
        ret nz
.c:     ld hl,256
        ret

; A = 1 or 2 -> B, C = that option's cell (row, column order: B row)
option_pos:
        ld b,a
        ld a,(trailp)
.k:     sub 7
        djnz .k
        and 31
        add a,a
        ld l,a
        ld h,high TRAIL
        ld c,(hl)               ; column
        inc l
        ld b,(hl)               ; row
        ret

; ---------------------------------------------------------------------
fire_tick:
        ld a,(firecd)
        or a
        jr z,.r
        dec a
        ld (firecd),a
        ret
.r:     ld a,(gstate)
        cp G_PLAY
        ret nz
        ld a,(keys)
        and K_FIRE
        ret z
        ld a,(weapon)
        or a
        jp nz,fire_laser
        ; vulcan
        ld a,2
        ld (firecd),a
        ld hl,SFX_SHOT
        ld a,1
        call sfx
        ld a,(power)
        add a,a
        ld l,a
        ld h,0
        ld de,vulc_tab-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; HL = list: dx, vx; 80h ends
.v:     ld a,(hl)
        cp 80h
        jr z,.opt
        inc hl
        ld c,a
        ld a,(hl)
        inc hl
        push hl
        ld b,a                  ; B = vx, C = dx
        ld a,(px+1)
        add a,c
        ld c,a
        ld a,(py+1)
        dec a
        ld e,a                  ; E = row
        ld d,1                  ; type vulcan
        call new_shot
        pop hl
        jr .v
.opt:   ld a,(options)          ; each option fires straight ahead
        or a
        ret z
        ld b,a
.o:     push bc
        ld a,b
        call option_pos
        ld a,b
        dec a
        ld e,a
        ld b,0
        ld a,(weapon)
        inc a
        ld d,a
        call new_shot
        pop bc
        djnz .o
        ret

fire_laser:
        ld a,1
        ld (firecd),a
        ld hl,SFX_LASER
        ld a,1
        call sfx
        ld a,(power)            ; beams: 1 (power 1-2), 2 (3-4), 3 (5)
        ld c,0
        cp 3
        jr c,.one
        cp 5
        jr c,.two
        call .beam              ; centre
.two:   ld c,-1
        call .beam
        ld c,1
        call .beam
        jp fire_tick.opt
.one:   call .beam
        jp fire_tick.opt
.beam:  ld a,(px+1)
        add a,c
        ld c,a
        ld a,(py+1)
        dec a
        ld e,a
        ld b,0
        ld d,2
        ; fall through
; C = column, E = row, B = vx, D = type: a new player shot
new_shot:
        ld a,c
        cp PFW
        ret nc
        ld hl,SHOTS
        push de
        ld de,SHSZ
        ld a,MAXSH
.f:     ex af,af'
        ld a,(hl)
        or a
        jr z,.got
        add hl,de
        ex af,af'
        dec a
        jr nz,.f
        pop de
        ret
.got:   pop de
        ld (hl),d               ; ST
        inc hl
        ld (hl),80h             ; SXL: the middle of the cell
        inc hl
        ld (hl),c               ; SX
        inc hl
        ld (hl),e               ; SY
        inc hl
        ld (hl),b               ; SVX
        inc hl
        ld (hl),2               ; SDY: 2 rows a tick
        ret

; vulcan patterns by power: (column offset, vx) pairs, 80h ends
vulc_tab:
        dw .p1,.p2,.p3,.p4,.p5
.p1:    db 0,0, 80h
.p2:    db -1,0, 1,0, 80h
.p3:    db 0,0, -1,-40h, 1,40h, 80h
.p4:    db -1,0, 1,0, -1,-50h, 1,50h, 80h
.p5:    db 0,0, -1,0, 1,0, -1,-60h, 1,60h, 80h

; ---------------------------------------------------------------------
; shots: move 2 rows a tick, looking at both cells for something to hit
shots_tick:
        ld ix,SHOTS
        ld b,MAXSH
.s:     push bc
        ld a,(ix+ST)
        or a
        call nz,shot_one
        ld de,SHSZ
        add ix,de
        pop bc
        djnz .s
        ret

shot_one:
        ld a,(ix+SDY)
        ld (shstep),a
.step:  ; x moves by vx/2 per row
        ld a,(ix+SVX)
        sra a
        ld e,a
        rla
        sbc a,a
        ld d,a                  ; DE = vx/2 signed
        ld l,(ix+SXL)
        ld h,(ix+SX)
        add hl,de
        ld (ix+SXL),l
        ld (ix+SX),h
        ld a,h
        cp PFW
        jr nc,.kill
        dec (ix+SY)
        ld a,(ix+SY)
        cp PFH
        jr nc,.kill             ; off the top
        ld b,a
        ld c,h
        call calc_ofs
        call occ_at
        or a
        jr z,.nx
        call shot_hit           ; A = owner
        ld a,(ix+ST)
        or a
        ret z                   ; spent
.nx:    ld hl,shstep
        dec (hl)
        jr nz,.step
        ; draw
        ld b,(ix+SY)
        ld c,(ix+SX)
        ld a,(ix+ST)
        cp 2
        jr z,.laser
        ld d,31h                ; vulcan: a yellow bolt
        ld e,60h
        cp 3
        jr nz,.dv
        ld e,50h                ; an option's shot: cyan
.dv:    xor a
        jp put_one
.laser: ld d,0A2h               ; laser: two cells of ||, cyan / white
        ld e,50h
        xor a
        push bc
        call put_one
        pop bc
        inc b
        ld d,0A2h
        ld e,70h
        xor a
        jp put_one
.kill:  ld (ix+ST),0
        ret

; IX = shot that hit owner A
shot_hit:
        bit 7,a
        jr nz,.boss
        dec a                   ; an enemy: A = index + 1
        call enemy_iy
        push ix
        push iy
        pop ix
        ld a,1
        call en_hit
        pop ix
        ld a,(ix+ST)
        cp 2
        ret z                   ; lasers go through
        ld (ix+ST),0
        ret
.boss:  ld a,1
        call boss_hit
        ld (ix+ST),0
        ret

; ---------------------------------------------------------------------
; bombs: B / X / L.  Clears every bullet for a second, hurts everything.
bomb_tick:
        ld a,(bombtm)
        or a
        jr z,.idle
        dec a
        ld (bombtm),a
        call clear_bullets
        jp bomb_draw
.idle:  ld a,(gstate)
        cp G_PLAY
        ret nz
        ld a,(keys)
        and K_BOMB
        ret z
        ld a,(bombs)
        or a
        ret z
        dec a
        ld (bombs),a
        ld a,1
        ld (hudbomb),a
        ld a,25
        ld (bombtm),a
        ld a,(invuln)
        cp 30
        jr nc,.i
        ld a,30
        ld (invuln),a
.i:     ld hl,SFX_BOMB
        ld a,9
        call sfx
        ; 12 damage to every enemy on screen, 30 to the boss
        ld ix,ENEMY
        ld b,MAXEN
.e:     push bc
        ld a,(ix+ET)
        or a
        jr z,.en
        ld a,(ix+EY)
        cp PFH
        jr nc,.en
        ld a,12
        call en_hit
.en:    ld de,ENSZ
        add ix,de
        pop bc
        djnz .e
        ld a,30
        call boss_hit
        ret

; the bomb's shock ring: a diamond growing out from the ship
bomb_draw:
        ld a,25
        ld hl,bombtm
        sub (hl)
        ld (bombr),a            ; radius 1..25 (every other tick drawn)
        ld e,a
        ld d,0                  ; D = k from 0 to r: (k, r-k) in 4 mirrors
.k:     ld a,e
        sub d
        ld (bombdy),a
        ld a,(px+1)
        add a,d
        ld c,a
        call .pair
        ld a,(px+1)
        sub d
        ld c,a
        call .pair
        inc d
        ld a,d
        cp e
        jr c,.k
        jr z,.k
        ret
.pair:  push de
        ld a,(py+1)
        ld hl,bombdy
        add a,(hl)
        ld b,a
        push bc
        call .pt
        pop bc
        ld a,(py+1)
        ld hl,bombdy
        sub (hl)
        ld b,a
        call .pt
        pop de
        ret
.pt:    ld a,(bombr)
        and 3
        ld hl,bombcols
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld e,(hl)
        ld d,6Bh                ; '*'
        xor a
        jp put_one
bombcols: db 70h,60h,20h,30h

; ---------------------------------------------------------------------
; draw the ship (last, on top) and see if anything touched its centre
player_draw:
        ld a,(gstate)
        cp G_DEAD
        ret z
        cp G_OVER
        ret z
        ld a,(py+1)
        bit 7,a
        ret nz                  ; flown off the top
        ld a,(invuln)           ; blink while invulnerable
        and 2
        jr nz,.opts
        ld a,(shield)
        or a
        ld a,0
        jr z,.ns
        ld a,(framecnt)
        and 4
        jr z,.ns
        ld a,1
.ns:    ld (sprflash),a
        ld iy,SPR_PLAYER
        ld a,(py+1)
        ld b,a
        ld a,(px+1)
        dec a
        ld c,a
        xor a
        call draw_spr
        xor a
        ld (sprflash),a
        ld a,(framecnt)         ; engine flame
        and 1
        ld e,20h+80h
        jr z,.f
        ld e,60h+80h
.f:     ld d,0A0h
        ld a,(py+1)
        add a,2
        ld b,a
        ld a,(px+1)
        ld c,a
        xor a
        call put_one
.opts:  ld a,(options)
        or a
        jr z,.hit
        ld b,a
.o:     push bc
        ld a,b
        call option_pos         ; B = row, C = column
        ld a,(framecnt)
        rra
        and 3
        ld hl,optcols
        add a,l
        ld l,a
        jr nc,.oc
        inc h
.oc:    ld e,(hl)
        ld d,8Eh
        xor a
        call put_one
        pop bc
        djnz .o
.hit:   ld a,(gstate)
        cp G_PLAY
        ret nz
        ld a,(invuln)
        or a
        ret nz
        ld a,(py+1)             ; nose and body: anything in the map?
        ld b,a
        ld a,(px+1)
        ld c,a
        call calc_ofs
        call occ_at
        or a
        jr nz,.touch
        ld bc,40
        add hl,bc
        call occ_at
        or a
        ret z
.touch: jp player_hit
optcols: db 0E0h,0F0h,0E0h,0D0h

; ---------------------------------------------------------------------
; something hit the ship
player_hit:
        ld a,(invuln)
        or a
        ret nz
        ld a,(bombtm)
        or a
        ret nz
        ld a,(godmode)
        or a
        ret nz
        ld a,(shield)
        or a
        jr z,.die
        xor a                   ; the shield takes it
        ld (shield),a
        ld a,40
        ld (invuln),a
        ld a,1
        ld (hudpow),a
        ld hl,SFX_SHIELD
        ld a,8
        jp sfx
.die:   ld a,G_DEAD
        ld (gstate),a
        ld a,70
        ld (deadtm),a
        xor a
        ld (nomiss),a
        ld hl,SFX_DIE
        ld a,10
        call sfx
        ld a,(px+1)             ; a big burst
        ld c,a
        ld a,(py+1)
        ld b,a
        call big_burst
        ; lose some of the kit
        ld a,(power)
        cp 2
        jr c,.p
        dec a
        ld (power),a
.p:     xor a
        ld (options),a
        ld (speed),a
        ld a,1
        ld (hudpow),a
        ret

dead_tick:
        ld a,(deadtm)
        dec a
        ld (deadtm),a
        ret nz
        ld a,(trainer)
        or a
        jr nz,.again
        ld a,(lives)
        dec a
        ld (lives),a
        ld a,1
        ld (hudlives),a
        ld a,(lives)
        or a
        jr nz,.again
        jp game_over
.again: ld a,G_PLAY
        ld (gstate),a
        ld a,(bombs)            ; at least 2 bombs again
        cp 2
        jr nc,.b
        ld a,2
        ld (bombs),a
        ld a,1
        ld (hudbomb),a
.b:     jp player_reset

extra_ship:
        ld a,(lives)
        cp 9
        jr nc,.x
        inc a
        ld (lives),a
.x:     ld a,1
        ld (hudlives),a
        ld hl,SFX_ONEUP
        ld a,7
        jp sfx
