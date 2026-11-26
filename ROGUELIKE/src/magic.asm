; =====================================================================
;  magic.asm - spells, bolts, bombs and flares
;
;  A bolt flies a cell per frame, carrying its own light and leaving a
;  trail of particles; it bursts on the first creature or obstacle.
;  Fire lights braziers and burns webs; frost freezes water to ice and
;  lava to obsidian as it passes over them.
; =====================================================================
NFLARE          equ 4

; bolt kinds: glyph, attr, light, trail particle, burst particle, element
BOLTDEF:
        db 06Bh, YELLOW<<4, 4+(0<<4), P_EMBER, P_SPARK, 1      ; FIRE
        db 06Bh, CYAN<<4,   4+(1<<4), P_FROST, P_FROST, 2      ; FROST
        db 06Bh, MAGENTA<<4, 4+(3<<4), P_MAGIC, P_MAGIC, 0     ; ARCANE
        db 047h, WHITE<<4,  6+(6<<4), P_GOLD, P_GOLD, 3        ; LIGHT (flare)
        db 06Bh, WHITE<<4,  5+(4<<4), P_BOLT, P_SPARK, 0       ; SPARK

; ---------------------------------------------------------------------
cast_spell:
        ld a,(curspell)
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,SPELLS
        add hl,de
        ld a,(hl)                   ; MP cost
        ld (sp_cost),a
        ld b,a
        ld a,(mp)
        cp b
        jr nc,.ok
        ld hl,msg_nomp
        call msg
        jp deny
.ok:    ld a,(curspell)
        cp SP_HEAL
        jr z,.heal
        ; aimed spells: a direction
        ld hl,msg_aim
        call msg
        call ask_dir
        jp c,no_turn
        ld (bolt_dir),a
        call msg_clear
        call spend_mp
        ld a,(curspell)
        or a
        jr z,.fire
        dec a
        jr z,.frost
        dec a
        jr z,.flare
        cp SP_BLINK-2
        jp z,blink
        jp lightning
.fire:  ld a,BOLT_FIRE
        ld bc,4*256+8
        jr .bolt
.frost: ld a,BOLT_FROST
        ld bc,2*256+5
        jr .bolt
.flare: ld a,BOLT_LIGHT
        ld bc,1*256+2
.bolt:  ld (bolt_kind),a
        call rand_range
        ld b,a
        ld a,(plevel)
        srl a
        add a,b
        ld (bolt_dmg),a
        ld a,1
        ld (bolt_owner),a
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call fire_bolt
        or 1
        ret
.heal:  call spend_mp
        ld a,(plevel)
        add a,a
        add a,8
        call heal_by
        ld hl,SFX_HEAL
        ld a,2
        call sfx
        ld hl,msg_healed
        call msg
        or 1
        ret

no_turn:
        xor a
        ret

spend_mp:
        ld a,(sp_cost)
        ld b,a
        ld a,(mp)
        sub b
        ld (mp),a
        ld a,1
        ld (hud_dirty),a
        ret

; ---------------------------------------------------------------------
; fire a bolt of bolt_kind from (B, C) toward bolt_dir; bolt_dmg,
; bolt_owner (1 = the player).  Animates until it bursts.
fire_bolt:
        ld a,(bolt_kind)
        ld l,a
        add a,a
        add a,l
        add a,a                     ; *6
        ld e,a
        ld d,0
        ld hl,BOLTDEF
        add hl,de
        ld a,(hl)
        ld (bolt_g),a
        inc hl
        ld a,(hl)
        ld (bolt_a),a
        inc hl
        ld a,(hl)
        ld (bolt_light),a
        inc hl
        ld a,(hl)
        ld (bolt_trail),a
        inc hl
        ld a,(hl)
        ld (bolt_burst),a
        inc hl
        ld a,(hl)
        ld (mo_elem),a
        ld a,b
        ld (bolt_x),a
        ld a,c
        ld (bolt_y),a
        ld a,1
        ld (bolt_on),a
        ld a,(bolt_kind)
        ld hl,SFX_FIRE
        cp BOLT_FROST
        jr nz,$+5
        ld hl,SFX_FROST
        cp BOLT_LIGHT
        jr nz,$+5
        ld hl,SFX_FLARE
        ld a,2
        call sfx
        ld a,10
        ld (bolt_left),a
.step:  ld a,(bolt_x)
        ld b,a
        ld a,(bolt_y)
        ld c,a
        ld a,(bolt_dir)
        call dir_step
        ; the player?
        ld a,(bolt_owner)
        or a
        jr nz,.np
        ld a,(px)
        cp b
        jr nz,.np
        ld a,(py)
        cp c
        jr nz,.np
        ld a,(bolt_dmg)
        ld (m_dmg),a
        call player_hurt
        ld hl,msg_bolthit
        call msg
        jp .burst
.np:    ; a creature?
        call mon_at
        jr z,.nm
        ld a,(bolt_owner)
        or a
        jp z,.burst                 ; monsters' bolts don't hurt monsters
        ld a,(ix+MO_TYPE)
        call mon_type
        ld a,(bolt_dmg)
        ld (m_dmg),a
        ld hl,msg_spellhit
        call msg_mon
        push bc
        ld a,(bolt_dmg)
        call mon_damage
        pop bc
        jr .burst
.nm:    call tile_at
        ld (mv_tile),a
        ; liquids: frost freezes, everything flies over
        cp T_WATER
        jr nz,.nw
        ld a,(bolt_kind)
        cp BOLT_FROST
        jr nz,.fly
        call map_addr
        ld a,T_ICE
        call set_tile
        ld a,1
        ld (relight_req),a
        jr .fly
.nw:    cp T_LAVA
        jr nz,.nl
        ld a,(bolt_kind)
        cp BOLT_FROST
        jr nz,.fly
        call map_addr
        ld a,T_OBSIDIAN
        call set_tile
        ld a,1
        ld (relight_req),a
        jr .fly
.nl:    call tile_flags
        and F_SOLID|F_OPAQUE
        jr z,.fly
        ; it hits something solid
        ld a,(bolt_kind)
        or a
        jr nz,.burst
        ld a,(mv_tile)
        cp T_BRAZOFF
        jr nz,.nbz
        push bc
        call light_brazier
        pop bc
        jr .burst
.nbz:   cp T_WEB
        jr nz,.burst
        call map_addr
        ld a,T_FLOOR
        call set_tile
        jr .burst
.fly:   ld a,b
        ld (bolt_x),a
        ld a,c
        ld (bolt_y),a
        ld a,(bolt_trail)
        ld e,1
        call burst
        call anim_frame
        ld hl,bolt_left
        dec (hl)
        jp nz,.step
        ; out of range
.burst: ld a,(bolt_x)
        ld b,a
        ld a,(bolt_y)
        ld c,a
        ld a,(bolt_kind)
        cp BOLT_LIGHT
        jr nz,.nfl
        call new_flare
.nfl:   ld a,(bolt_burst)
        ld e,6
        call burst
        ld a,(bolt_light)
        inc a
        ld e,6
        call flash
        xor a
        ld (bolt_on),a
        ld a,(relight_req)
        or a
        jr z,.nr
        xor a
        ld (relight_req),a
        call relight
.nr:    ld a,1
        ld (need_fov),a
        ld a,4
        call anim_frames
        xor a
        ret

; ---------------------------------------------------------------------
; flares: a hovering light for 40 turns (records: turns, x, y)
new_flare:
        ld hl,flares
        ld d,NFLARE
.f:     ld a,(hl)
        or a
        jr z,.put
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        ld hl,flares                ; all in use: replace the first
.put:   ld (hl),40
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        ret

; each turn: flares burn down, and burn shades near them
flares_tick:
        ld hl,flares
        ld d,NFLARE
.f:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        push hl
        push de
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        call burn_shades
        pop de
        pop hl
.n:     inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        ret

; shades within 3 cells of (B, C) take 2 damage
burn_shades:
        ld ix,(monbase)
        ld e,NMON
.m:     ld a,(ix+MO_TYPE)
        or a
        jr z,.n
        call mon_type
        bit 4,(iy+MT_FL)
        jr z,.n
        ld a,(ix+MO_X)
        sub b
        jr nc,$+4
        neg
        cp 4
        jr nc,.n
        ld a,(ix+MO_Y)
        sub c
        jr nc,$+4
        neg
        cp 4
        jr nc,.n
        push bc
        push de
        ld a,3
        ld (mo_elem),a
        ld a,2
        call mon_damage
        pop de
        pop bc
.n:     push de
        ld de,MONSZ
        add ix,de
        pop de
        dec e
        jr nz,.m
        ret

; ---------------------------------------------------------------------
; blink: up to 5 cells in a straight line, to the last free cell
blink:
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld (bl_dest),bc
        ld e,5
.s:     push de
        ld a,(bolt_dir)
        call dir_step
        call tile_at
        call tile_flags
        and F_OPAQUE
        jr nz,.end
        call tile_at
        call tile_flags
        bit 1,a
        jr nz,.skip                 ; over water and lava, not onto them
        call occupied
        jr nz,.skip
        ld (bl_dest),bc
.skip:  pop de
        dec e
        jr nz,.s
        jr .go
.end:   pop de
.go:    ld bc,(bl_dest)
        call teleport_to
        call pickup
        or 1
        ret

; lightning: everything in a line of 8 cells is struck
lightning:
        ld hl,SFX_ZAP
        ld a,3
        call sfx
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld e,8
.s:     push de
        ld a,(bolt_dir)
        call dir_step
        call tile_at
        call tile_flags
        and F_OPAQUE|F_SOLID
        cp F_OPAQUE|F_SOLID
        jr z,.end
        push bc
        ld a,P_BOLT
        ld e,2
        call burst
        pop bc
        push bc
        ld a,5+(4<<4)
        ld e,3
        call flash
        call anim_frame
        pop bc
        call mon_at
        jr z,.nm
        push bc
        ld a,(ix+MO_TYPE)
        call mon_type
        ld bc,6*256+12
        call rand_range
        ld (m_dmg),a
        ld hl,msg_zapped
        call msg_mon
        xor a
        ld (mo_elem),a
        ld a,(m_dmg)
        call mon_damage
        pop bc
.nm:    pop de
        dec e
        jr nz,.s
        jr .done
.end:   pop de
.done:  ld a,6
        call anim_frames
        or 1
        ret

; ---------------------------------------------------------------------
; a bomb: thrown up to 4 cells, bursting over a 3 x 3 square
throw_bomb:
        ld a,(bombs)
        or a
        jp z,deny_none
        ld hl,msg_aim
        call msg
        call ask_dir
        jp c,no_turn
        ld (bolt_dir),a
        call msg_clear
        ld hl,bombs
        dec (hl)
        ld a,1
        ld (hud_dirty),a
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld e,4
        ld a,13Eh & 255
        ld (bolt_g),a
        ld a,80h+(RED<<4)
        ld (bolt_a),a
        ld a,2                      ; the fuse glows
        ld (bolt_light),a
.s:     push de
        push bc
        ld a,(bolt_dir)
        call dir_step
        call tile_at
        call tile_flags
        and F_OPAQUE|F_SOLID
        cp F_OPAQUE|F_SOLID
        jr z,.stop
        call mon_at
        jr nz,.hitm
        pop af                      ; (drop the old position)
        ld a,b
        ld (bolt_x),a
        ld a,c
        ld (bolt_y),a
        ld a,1
        ld (bolt_on),a
        call anim_frame
        pop de
        dec e
        jr nz,.s
        jr .boom
.hitm:  pop af
        pop de
        jr .boom
.stop:  pop bc
        pop de
.boom:  xor a
        ld (bolt_on),a
        ld a,b
        ld (bm_x),a
        ld a,c
        ld (bm_y),a
        ld hl,SFX_BOOM
        ld a,4
        call sfx
        ld a,7+(0<<4)
        ld e,10
        call flash
        ; damage the 3 x 3 square
        dec b
        dec c
        ld d,3
.r:     ld e,3
        push bc
.c:     push bc
        push de
        ld a,P_SPARK
        ld e,3
        call burst
        call mon_at
        jr z,.cn
        ld a,(ix+MO_TYPE)
        call mon_type
        push bc
        ld bc,8*256+14
        call rand_range
        ld (m_dmg),a
        xor a
        ld (mo_elem),a
        ld hl,msg_blast
        call msg_mon
        ld a,(m_dmg)
        call mon_damage
        pop bc
.cn:    ld a,(px)
        cp b
        jr nz,.cw
        ld a,(py)
        cp c
        jr nz,.cw
        ld a,6
        ld (m_dmg),a
        call player_hurt
.cw:    call tile_at
        cp T_WEB
        jr nz,.cx
        ld a,T_FLOOR
        call set_tile
.cx:    pop de
        pop bc
        inc b
        dec e
        jr nz,.c
        pop bc
        inc c
        dec d
        jr nz,.r
        ld a,10
        call anim_frames
        or 1
        ret
