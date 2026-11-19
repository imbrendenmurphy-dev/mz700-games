; =====================================================================
;  player.asm - the player, player shots, enemy bullets
; =====================================================================

player_ofs:
        ld a,(py+1)
        ld b,a
        ld a,(px+1)
        ld c,a
        jp calc_ofs

player_update:
        ld a,(mkeys)
        ld c,a
        ld hl,(px)
        bit 2,c
        jr z,.r
        ld de,-PSPDX
        add hl,de
.r:     bit 3,c
        jr z,.cx
        ld de,PSPDX
        add hl,de
.cx:    ld a,h
        cp XMIN
        jr nc,.x1
        ld hl,XMIN*256
        jr .x2
.x1:    cp XMAX+1
        jr c,.x2
        ld hl,XMAX*256+0FFh
.x2:    ld (px),hl
        ld hl,(py)
        bit 0,c
        jr z,.d
        ld de,-PSPDY
        add hl,de
.d:     bit 1,c
        jr z,.cy
        ld de,PSPDY
        add hl,de
.cy:    ld a,h
        cp YMIN
        jr nc,.y1
        ld hl,YMIN*256
        jr .y2
.y1:    cp YMAX+1
        jr c,.y2
        ld hl,YMAX*256+0FFh
.y2:    ld (py),hl
        ; fire
        ld a,(firecd)
        or a
        jr z,.cf
        dec a
        ld (firecd),a
        ret
.cf:    ld a,(fkeys)
        ld e,a
        ld d,0
        ld hl,dirtab
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld b,a
        ld iy,SHOTS
        ld de,4
        ld c,MAXSH
.s:     ld a,(iy+SDIR)
        or a
        jr z,.got
        add iy,de
        dec c
        jr nz,.s
        ret
.got:   ld (iy+SDIR),b
        ld a,(px+1)
        ld (iy+SX),a
        ld a,(py+1)
        ld (iy+SY),a
        ld a,FIRE_RATE
        ld (firecd),a
        ld hl,sfx_shoot
        ld a,1
        jp play_sfx

place_player:
        call player_ofs
        ld de,0CA71h            ; stick man, white on blue
        ld a,(state)
        cp S_DYING
        jp nz,put_cell
        ld a,(statetm)          ; dying: flash, then burst
        cp 50
        jr c,.burst
        and 7
        rlca
        rlca
        rlca
        rlca
        or 01h
        ld e,a
        jp put_cell
.burst: ld e,0F1h
        ld d,0B3h
        cp 35
        jp nc,put_cell
        ld d,0EEh
        cp 20
        jp nc,put_cell
        ld d,0EFh
        cp 8
        jp nc,put_cell
        ret

; what is in the player's cell?
player_collide:
        call player_ofs
        call bocc_at
        or a
        jr nz,player_die        ; an enemy bullet
        call occ_at
        or a
        ret z
        call id_to_iy
        ld a,(iy+OST)           ; still materialising: harmless
        or a
        ret nz
        ld a,(iy+OT)
        or a
        ret z
        cp T_MOM
        jr c,.robot
        cp T_KID+1
        jr nc,.robot
        ; rescue: 1000, 2000 ... 5000 points
        ld a,(rescues)
        ld c,a
        inc a
        ld (rescues),a
        ld a,c
        cp 4
        jr c,.r
        ld c,4
.r:     ld hl,saved
        inc (hl)
        ld a,c
        inc a
        ld b,a                  ; B = thousands
        rlca
        rlca
        rlca
        rlca
        ld d,a
        ld e,0
        ld a,b                  ; points / 25 = 40 per thousand
        add a,a
        add a,a
        add a,b
        add a,a
        add a,a
        add a,a
        call add_score
        push iy
        pop ix
        ld a,T_POP
        call set_type
        ld (iy+OTM),50
        ld (iy+OAUX),c
        ld (iy+OST),0
        ld b,(iy+OY)            ; sparkles
        ld c,(iy+OX)
        ld a,0E1h
        ld de,0108h
        call burst
        ld hl,sfx_rescue
        ld a,5
        jp play_sfx
.robot: call tinfo_ptr
        inc hl
        inc hl
        inc hl
        bit 0,(hl)              ; F_DEADLY
        ret z
player_die:
        ld a,S_DYING
        ld (state),a
        ld a,90
        ld (statetm),a
        call clear_shots
        call player_bc          ; B = column, C = row
        ld a,b
        ld b,c
        ld c,a
        ld a,0F1h
        ld de,0010h
        call burst
        ld hl,sfx_death
        ld a,9
        jp play_sfx

; ---------------------------------------------------------------------
; player shots: one cell per tick
update_shots:
        ld iy,SHOTS
        ld b,MAXSH
.l:     push bc
        ld a,(iy+SDIR)
        or a
        jr z,.nx
        call shot_ofs           ; did something walk into it?
        call shot_check
        jr c,.kill
        ld a,(iy+SDIR)
        ld c,a
        ld b,0
        ld hl,sdxtab
        add hl,bc
        ld a,(iy+SX)
        add a,(hl)
        cp XMIN
        jr c,.kill
        cp XMAX+1
        jr nc,.kill
        ld (iy+SX),a
        ld hl,sdytab
        add hl,bc
        ld a,(iy+SY)
        add a,(hl)
        cp YMIN
        jr c,.kill
        cp YMAX+1
        jr nc,.kill
        ld (iy+SY),a
        call shot_ofs
        call shot_check
        jr c,.kill
        push hl
        ld a,(iy+SDIR)
        ld c,a
        ld b,0
        ld hl,shotch
        add hl,bc
        ld d,(hl)
        ld e,51h                ; cyan on blue
        pop hl
        call put_cell
        jr .nx
.kill:  ld (iy+SDIR),0
.nx:    pop bc
        ld de,4
        add iy,de
        djnz .l
        ret

shot_ofs:
        ld b,(iy+SY)
        ld c,(iy+SX)
        jp calc_ofs

; HL = the shot's cell: hit a bullet or the object showing there?
; Carry = the shot is used up.  HL and IY preserved.
shot_check:
        call bocc_at
        or a
        call nz,shot_hit
        ret c
        call occ_at
        or a
        ret z
; A = occupant of the shot's cell (80h+ = bullet).  Carry = used up.
shot_hit:
        push hl
        bit 7,a
        jr nz,.bul
        push ix
        call id_to_ix
        ld a,(ix+OT)
        or a
        jr z,.pass
        ld a,(ix+OST)           ; materialising: shots pass through
        or a
        jr nz,.pass
        ld a,(ix+OFL)
        bit 1,a                 ; F_SHOOT
        jr nz,.kill
        bit 4,a                 ; F_PUSH
        jr nz,.push
.pass:  pop ix
        pop hl
        or a
        ret
.kill:  call kill_obj
        pop ix
        pop hl
        scf
        ret
.push:  ld a,(iy+SDIR)          ; knock it back a cell
        ld c,a
        ld b,0
        ld hl,sdxtab
        add hl,bc
        ld d,(hl)
        ld hl,sdytab
        add hl,bc
        ld e,(hl)
        call obj_step
        ld b,(ix+OY)            ; sparks off its armour
        ld c,(ix+OX)
        ld a,0C1h
        ld de,0003h
        call burst
        ld a,(ease+E_CRUSH)
        ld (ix+OTM),a
        ld hl,sfx_push
        ld a,1
        call play_sfx
        pop ix
        pop hl
        scf
        ret
.bul:   and 7Fh                 ; shoot down an enemy bullet: 25
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,EBUL
        add hl,de
        ld a,(hl)
        or a
        jr z,.gone
        ld (hl),0
        inc hl
        inc hl
        ld c,(hl)               ; BX
        inc hl
        inc hl
        ld b,(hl)               ; BY
        ld a,0F1h
        ld de,0104h
        call burst
        ld de,0025h
        ld a,1
        call add_score
        ld hl,sfx_zap
        ld a,2
        call play_sfx
        pop hl
        scf
        ret
.gone:  pop hl
        or a
        ret

; ---------------------------------------------------------------------
; enemy bullets.  A = type (1 spark, 2 missile, 3 shell), fired from IX
fire_at_player:
        ld c,a
        ld iy,EBUL
        ld b,MAXEB
        ld de,EBSZ
.f:     ld a,(iy+BT)
        or a
        jr z,.got
        add iy,de
        djnz .f
        ret
.got:   ld (iy+BT),c
        ld a,(ix+OX)
        ld (iy+BX),a
        ld (iy+BXL),80h
        ld a,(ix+OY)
        ld (iy+BY),a
        ld (iy+BYL),80h
        ld a,220
        bit 1,c                 ; missiles (type 2) burn out sooner
        jr z,.life
        bit 0,c
        jr nz,.life
        ld a,140
.life:  ld (iy+BLIFE),a
        call aim_bullet
        ld hl,sfx_efire
        ld a,1
        jp play_sfx

; point bullet IY at the player
aim_bullet:
        ld a,(px+1)
        sub (iy+BX)
        ld d,a
        ld a,(py+1)
        sub (iy+BY)
        ld e,a
        call aim_dir
        ld l,a
        ld a,(iy+BT)
        dec a
        add a,a
        add a,a
        add a,a
        add a,l
        add a,a
        ld hl,bvtab
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,(hl)
        ld (iy+BVX),a
        inc hl
        ld a,(hl)
        ld (iy+BVY),a
        ret

; D = dx, E = dy -> A = direction 0 U, 1 UR, 2 R ... 7 UL
aim_dir:
        ld a,d
        call abs_a
        ld b,a
        ld a,e
        call abs_a
        ld c,a
        add a,a
        cp b
        jr c,.horz              ; 2|dy| < |dx|
        ld a,b
        add a,a
        cp c
        jr c,.vert              ; 2|dx| < |dy|
        bit 7,d
        jr nz,.dl
        bit 7,e
        ld a,1
        ret nz
        ld a,3
        ret
.dl:    bit 7,e
        ld a,7
        ret nz
        ld a,5
        ret
.horz:  bit 7,d
        ld a,2
        ret z
        ld a,6
        ret
.vert:  bit 7,e
        ld a,0
        ret nz
        ld a,4
        ret

update_bullets:
        ld iy,EBUL
        ld b,MAXEB
        ld c,80h
.l:     push bc
        ld a,(iy+BT)
        or a
        jp z,.nx
        dec (iy+BLIFE)
        jp z,.kill
        cp 2                    ; missiles re-aim every 16 ticks
        jr nz,.mv
        ld a,(iy+BLIFE)
        and 15
        call z,aim_bullet
.mv:    ld a,(iy+BVX)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(iy+BXL)
        ld h,(iy+BX)
        add hl,de
        ld a,h
        cp XMIN
        jr c,.wx
        cp XMAX+1
        jr nc,.wx
        ld (iy+BXL),l
        ld (iy+BX),h
        jr .y
.wx:    ld a,(iy+BT)
        cp 3
        jr nz,.kill
        ld a,(iy+BVX)
        neg
        ld (iy+BVX),a
.y:     ld a,(iy+BVY)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(iy+BYL)
        ld h,(iy+BY)
        add hl,de
        ld a,h
        cp YMIN
        jr c,.wy
        cp YMAX+1
        jr nc,.wy
        ld (iy+BYL),l
        ld (iy+BY),h
        jr .draw
.wy:    ld a,(iy+BT)
        cp 3
        jr nz,.kill
        ld a,(iy+BVY)
        neg
        ld (iy+BVY),a
.draw:  ld b,(iy+BY)
        ld c,(iy+BX)
        call calc_ofs
        ld a,(iy+BT)
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,ebglyph-2
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        pop hl
        pop bc
        push bc
        ld a,c
        call put_bocc
        jr .nx
.kill:  ld (iy+BT),0
.nx:    pop bc
        inc c
        ld de,EBSZ
        add iy,de
        dec b
        jp nz,.l
        ret
