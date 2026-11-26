; =====================================================================
;  monsters.asm - creatures: spawning, the distance map, AI, combat
;
;  The current zone's 24 records of 8 bytes are at MONS (the others wait
;  in ESTORE with their zones):
; =====================================================================
MO_TYPE         equ 0               ; 0 = empty slot
MO_X            equ 1
MO_Y            equ 2
MO_HP           equ 3
MO_FL           equ 4               ; MOF_ bits
MO_EN           equ 5               ; energy
MO_ST           equ 6               ; frozen turns
MO_AUX          equ 7               ; hit flash (frames)

MOF_AWAKE       equ 01h
MOF_DORMANT     equ 02h
MOF_TALKED      equ 04h

; type record (16 bytes, MTYPES)
MT_G            equ 0
MT_A            equ 1
MT_HP           equ 2
MT_ATK          equ 3
MT_DEF          equ 4
MT_SPD          equ 5
MT_AI           equ 6
MT_FL           equ 7
MT_XP           equ 8
MT_LIGHT        equ 9
MT_BOLT         equ 10
MT_DG           equ 11
MT_DA           equ 12
MT_NAME         equ 13

MTF_FLY         equ 01h
MTF_FIRE        equ 02h
MTF_COLD        equ 04h
MTF_UNDEAD      equ 08h
MTF_SHADE       equ 10h
MTF_POISON      equ 20h
MTF_DRAIN       equ 40h
MTF_BURST       equ 80h

; IY = type record of monster type A (1-based).  Keeps BC, DE, HL.
mon_type:
        push hl
        push de
        dec a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,MTYPES
        add hl,de
        push hl
        pop iy
        pop de
        pop hl
        ret

; IX = first monster record of the current zone
mon_base:
        ld ix,(monbase)
        ret

set_monbase:
        ld hl,MONS
        ld (monbase),hl
        ret

; clear the current zone's monsters
mon_clear:
        ld hl,(monbase)
        ld b,NMON*MONSZ
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; spawn monster type A at (B, C).  Keeps IX, IY.  Z if no free slot.
spawn_monster:
        push ix
        push iy
        push af
        ld ix,(monbase)
        ld de,MONSZ
        ld l,NMON
.f:     ld a,(ix+MO_TYPE)
        or a
        jr z,.put
        add ix,de
        dec l
        jr nz,.f
        pop af
        pop iy
        pop ix
        xor a
        ret
.put:   pop af
        ld (ix+MO_TYPE),a
        ld (ix+MO_X),b
        ld (ix+MO_Y),c
        call mon_type
        ld a,(iy+MT_HP)
        ld (ix+MO_HP),a
        xor a
        ld (ix+MO_EN),a
        ld (ix+MO_ST),a
        ld (ix+MO_AUX),a
        ld a,(iy+MT_AI)
        cp AI_AMBUSH
        ld a,MOF_DORMANT
        jr z,$+3
        xor a
        ld (ix+MO_FL),a
        pop iy
        pop ix
        or 1
        ret

; monster at (B, C)?  NZ and IX = its record if so.  Keeps BC, DE, HL.
mon_at:
        push de
        push hl
        ld ix,(monbase)
        ld de,MONSZ
        ld l,NMON
.f:     ld a,(ix+MO_TYPE)
        or a
        jr z,.n
        ld a,(ix+MO_X)
        cp b
        jr nz,.n
        ld a,(ix+MO_Y)
        cp c
        jr nz,.n
        pop hl
        pop de
        or 1
        ret
.n:     add ix,de
        dec l
        jr nz,.f
        pop hl
        pop de
        xor a
        ret

; NZ if (B, C) holds a monster, an item or the player.  Keeps BC, DE, HL, IX.
occupied:
        push ix
        call mon_at
        pop ix
        ret nz
        push hl
        call item_at
        pop hl
        ret nz
        ld a,(px)
        cp b
        jr nz,.no
        ld a,(py)
        cp c
        jr nz,.no
        or 1
        ret
.no:    xor a
        ret

; NZ if any creature (not folk) is awake
any_awake:
        ld ix,(monbase)
        ld de,MONSZ
        ld b,NMON
.f:     ld a,(ix+MO_TYPE)
        or a
        jr z,.n
        cp M_HERMIT
        jr nc,.n
        bit 0,(ix+MO_FL)
        ret nz
.n:     add ix,de
        djnz .f
        xor a
        ret

; count of monsters (not folk) in the zone -> A
mon_count:
        ld ix,(monbase)
        ld de,MONSZ
        ld bc,NMON*256
.f:     ld a,(ix+MO_TYPE)
        or a
        jr z,.n
        cp M_HERMIT
        jr nc,.n
        inc c
.n:     add ix,de
        djnz .f
        ld a,c
        ret

; ---------------------------------------------------------------------
; the distance map: DMAP[cell] = steps from the player (FF = far / none)
; ---------------------------------------------------------------------
bfs:
        ld a,(demo)
        or a
        ld a,28
        jr z,$+4
        ld a,90
        ld (bfs.lim+1),a
        ld hl,DMAP
        ld b,8
.clr:   push bc
        ld (hl),0FFh
        ld d,h
        ld e,l
        inc de
        ld bc,255
        ldir
        inc hl
        call poll
        pop bc
        djnz .clr
        ld hl,(pmap)
        ld a,h
        or high DMAP
        ld h,a
        ld (hl),0
        ld a,h
        and 07h
        ld h,a
        ld (QRING),hl
        ld de,QRING                 ; DE = head (read), q_tail = write
        ld hl,QRING+2
        ld (q_tail),hl
        ld a,32
        ld (q_cnt),a
.loop:  ld hl,(q_tail)
        or a
        sbc hl,de
        ret z                       ; empty
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,h
        and 03h                     ; ring of 1K
        or high QRING
        ld h,a
        push hl                     ; next head
        ; D E = cell; its distance
        ex de,hl
        ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        inc a
.lim:   cp 28                       ; (the bot sees further)
        jr nc,.skip
        ld c,a                      ; distance of the neighbours
        ld a,h
        and 07h
        ld h,a
        ld de,1
        call .try
        ld de,-1
        call .try
        ld de,64
        call .try
        ld de,-64
        call .try
.skip:  pop de
        ld hl,q_cnt
        dec (hl)
        jr nz,.loop
        ld (hl),32
        call poll
        jr .loop
; neighbour HL+DE at distance C
.try:   push hl
        add hl,de
        ld a,(hl)
        and 3Fh
        push hl
        ld l,a
        ld h,high TFLAGS
        ld a,(hl)
        pop hl
        and F_SOLID|F_DOOR
        cp F_SOLID
        jr z,.tx                    ; solid and not a door
        ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        cp 0FFh
        jr nz,.tx
        ld (hl),c
        ld a,h
        and 07h
        ld h,a
        ex de,hl
        ld hl,(q_tail)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,h
        and 03h
        or high QRING
        ld h,a
        ld (q_tail),hl
.tx:    pop hl
        ret

F_OPAQUE        equ 01h
F_SOLID         equ 02h
F_LIQUID        equ 04h
F_BUMP          equ 08h
F_DOOR          equ 10h
F_FLOORY        equ 20h
F_ANIM          equ 40h
F_HOT           equ 80h

; ---------------------------------------------------------------------
; monsters' turn
; ---------------------------------------------------------------------
monsters_act:
        ld ix,(monbase)
        ld b,NMON
.m:     push bc
        ld a,(ix+MO_TYPE)
        or a
        jr z,.n
        call mon_type
        ld a,(ix+MO_EN)
        add a,(iy+MT_SPD)
        ld (ix+MO_EN),a
.act:   ld a,(ix+MO_EN)
        cp 2
        jr c,.n
        sub 2
        ld (ix+MO_EN),a
        push ix
        call mon_turn
        pop ix
        ld a,(dead)
        or a
        jr nz,.n
        ld a,(ix+MO_TYPE)           ; it may have died
        or a
        jr nz,.act
.n:     ld de,MONSZ
        add ix,de
        pop bc
        djnz .m
        ret

; one action of monster IX (IY = its type)
mon_turn:
        ld a,(iy+MT_AI)
        cp AI_NPC
        ret z
        ld a,(ix+MO_ST)             ; frozen
        or a
        jr z,.nf
        dec (ix+MO_ST)
        ret
.nf:    ; distance to the player along the map (DMAP), and on the grid
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call map_addr
        ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        ld (m_dist),a
        call grid_dist              ; A = |dx| + |dy| to the player
        ld (m_gdist),a
        ; asleep in disguise?
        bit 1,(ix+MO_FL)
        jr z,.nd
        cp 2
        ret nc
        res 1,(ix+MO_FL)
        set 0,(ix+MO_FL)
        ld hl,msg_ambush
        call msg_mon
        ld hl,SFX_BOSS
        ld a,2
        call sfx
        ret
.nd:    bit 0,(ix+MO_FL)
        jr nz,.awake
        ; it wakes when the player can see it, or is close
        ld a,(m_gdist)
        cp 5
        jr c,.wake
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call map_addr
        ld a,h
        or high VISM
        ld h,a
        ld a,(hl)
        or a
        ret z
        cp 9
        ret nc
.wake:  set 0,(ix+MO_FL)
.awake: ld a,(iy+MT_AI)
        cp AI_FLEE
        jp z,ai_flee
        ld a,(m_gdist)
        cp 1
        jp z,mon_attack
        ld a,(iy+MT_BOLT)
        cp 0FFh
        jr z,.move
        call ai_shoot               ; NC if it fired
        ret nc
.move:  ld a,(iy+MT_AI)
        cp AI_TURRET
        ret z
        cp AI_PHASE
        jp z,ai_phase
        cp AI_SWIM
        jp z,ai_swim
        cp AI_ERRATIC
        jr nz,.chase
        ld b,2
        call rand_below
        or a
        jp z,ai_random
.chase: ; step to the neighbour nearer the player
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        ld a,(m_dist)
        cp 0FFh
        jp z,ai_direct
        ld (m_best),a
        xor a
        ld (m_bdir),a
        ld e,0
.d:     push de
        ld a,e
        call dir_step               ; B, C moved one step in direction A
        call map_addr
        ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        ld hl,m_best
        cp (hl)
        jr nc,.dn
        push af
        call mon_can_enter
        jr nz,.dno
        pop af
        ld (m_best),a
        pop de
        push de
        ld a,e
        inc a
        ld (m_bdir),a
        jr .dn
.dno:   pop af
.dn:    pop de
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        inc e
        ld a,e
        cp 4
        jr c,.d
        ld a,(m_bdir)
        or a
        ret z
        dec a
        jp mon_step

; A = |dx| + |dy| between monster IX and the player
grid_dist:
        ld a,(px)
        sub (ix+MO_X)
        jr nc,$+4
        neg
        ld b,a
        ld a,(py)
        sub (ix+MO_Y)
        jr nc,$+4
        neg
        add a,b
        ret

; move B, C one step in direction A (0 up, 1 down, 2 left, 3 right).
; Keeps DE, HL.
dir_step:
        or a
        jr nz,.n1
        dec c
        ret
.n1:    dec a
        jr nz,.n2
        inc c
        ret
.n2:    dec a
        jr nz,.n3
        dec b
        ret
.n3:    inc b
        ret

; Z if monster IX (type IY) may step into (B, C)
mon_can_enter:
        ld a,(px)
        cp b
        jr nz,.np
        ld a,(py)
        cp c
        jr nz,.np
        or 1
        ret
.np:    push ix
        call mon_at
        pop ix
        ret nz
        call tile_at
        call tile_flags
        bit 1,a                     ; solid?
        jr z,.ok
        bit 4,a                     ; doors open for walkers
        jr nz,.door
        bit 2,a                     ; liquid: flyers only
        jr z,.no
        bit 0,(iy+MT_FL)
        jr z,.no
.ok:    xor a
        ret
.door:  bit 0,(iy+MT_FL)            ; (bats and wisps don't open doors)
        jr nz,.no
        xor a
        ret
.no:    or 1
        ret

; monster IX steps in direction A
mon_step:
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call dir_step
        call mon_can_enter
        ret nz
        call tile_at
        cp T_DOOR
        jr nz,.go
        ld a,T_OPEN                 ; it opens the door instead
        call set_tile
        ld a,1
        ld (need_fov),a
        ret
.go:    ld (ix+MO_X),b
        ld (ix+MO_Y),c
        ret

; a random step
ai_random:
        ld b,4
        call rand_below
        jr mon_step

; straight toward the player (no path)
ai_direct:
        call dir_toward
        jr mon_step

; A = direction from monster IX toward the player (bigger axis first,
; with a random tie-break)
dir_toward:
        ld a,(px)
        sub (ix+MO_X)
        ld d,a
        jr nc,$+4
        neg
        ld b,a
        ld a,(py)
        sub (ix+MO_Y)
        ld e,a
        jr nc,$+4
        neg
        cp b
        jr z,.tie
        jr c,.horiz
.vert:  bit 7,e
        ld a,0
        ret nz
        inc a
        ret
.tie:   ld a,r
        rra
        jr c,.vert
.horiz: bit 7,d
        ld a,2
        ret nz
        inc a
        ret

; phantoms drift through walls
ai_phase:
        call dir_toward
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call dir_step
        ld a,b                      ; keep off the map's edge
        or a
        ret z
        cp MAPW-1
        ret nc
        ld a,c
        or a
        ret z
        cp MAPH-1
        ret nc
        ld a,(px)
        cp b
        jr nz,.ok
        ld a,(py)
        cp c
        ret z
.ok:    push ix
        call mon_at
        pop ix
        ret nz
        ld (ix+MO_X),b
        ld (ix+MO_Y),c
        ret

; swimmers stay in water
ai_swim:
        call dir_toward
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call dir_step
        call tile_at
        cp T_WATER
        jr z,.w
        ld b,4                      ; else a random swim
        call rand_below
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call dir_step
        call tile_at
        cp T_WATER
        ret nz
.w:     push ix
        call mon_at
        pop ix
        ret nz
        ld (ix+MO_X),b
        ld (ix+MO_Y),c
        ret

; wisps keep their distance (and light the way)
ai_flee:
        ld a,(m_dist)
        cp 4
        jp nc,ai_random
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        ld e,0
.d:     push de
        push bc
        ld a,e
        call dir_step
        call map_addr
        ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        ld hl,m_dist
        cp (hl)
        jr c,.no
        jr z,.no
        call mon_can_enter
        jr nz,.no
        pop bc
        pop de
        ld a,e
        jp mon_step
.no:    pop bc
        pop de
        inc e
        ld a,e
        cp 4
        jr c,.d
        ret

; ranged: NC if it shot (lined up with the player within 7, clear path)
ai_shoot:
        ld b,3
        call rand_below
        or a
        scf
        ret z                       ; a third of the time, it doesn't
        ld a,(m_gdist)
        cp 8
        ccf
        ret c
        ld a,(px)
        cp (ix+MO_X)
        jr z,.line
        ld a,(py)
        cp (ix+MO_Y)
        scf
        ret nz
.line:  call dir_toward
        ld (bolt_dir),a
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        ld a,(iy+MT_BOLT)
        ld (bolt_kind),a
        ld a,(iy+MT_ATK)
        ld (bolt_dmg),a
        xor a
        ld (bolt_owner),a           ; a monster's bolt
        push ix
        push iy
        call fire_bolt
        pop iy
        pop ix
        or a
        ret

; ---------------------------------------------------------------------
; combat
; ---------------------------------------------------------------------
; monster IX (type IY) attacks the player
mon_attack:
        ld b,10
        call rand_below
        cp 2
        jr nc,.hit
        ld hl,msg_mmiss
        jp msg_mon
.hit:   ld a,(iy+MT_ATK)
        ld c,a
        srl a
        ld b,a
        inc b
        call rand_range             ; atk/2+1 .. atk
        ld b,a
        ld a,(pdef)
        ld c,a
        ld a,b
        sub c
        jr c,.one
        jr nz,.ok
.one:   ld a,1
.ok:    ld (m_dmg),a
        call player_hurt
        ld hl,msg_mhit
        call msg_mon_num
        ; poison, oil drain
        bit 5,(iy+MT_FL)
        jr z,.np
        ld a,(poison)
        add a,4
        ld (poison),a
        ld hl,msg_poisoned
        call msg
.np:    bit 6,(iy+MT_FL)
        ret z
        ld a,(oil)
        sub 12
        jr nc,$+3
        xor a
        ld (oil),a
        ld hl,msg_drain
        jp msg

; the player loses m_dmg hit points
player_hurt:
        ld a,(m_dmg)
        ld b,a
        ld a,(hp)
        sub b
        jr nc,$+3
        xor a
        ld (hp),a
        ld a,8
        ld (pflash),a
        ld hl,SFX_HURT
        ld a,3
        call sfx
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,P_BLOOD
        ld e,3
        call burst
        ld a,1
        ld (hud_dirty),a
        ld a,(hp)
        or a
        ret nz
        ld a,1
        ld (dead),a
        ret

; damage monster IX by A (element in mo_elem: 0 none, 1 fire, 2 cold, 3
; light).  Kills it at 0 HP.
mon_damage:
        ld (m_dmg),a
        ld a,(ix+MO_TYPE)
        call mon_type
        ld a,(iy+MT_AI)
        cp AI_NPC
        ret z
        res 1,(ix+MO_FL)            ; wakes it
        set 0,(ix+MO_FL)
        ld a,(mo_elem)
        cp 1
        jr nz,.nfire
        bit 1,(iy+MT_FL)
        jr z,.apply
        jr .half
.nfire: cp 2
        jr nz,.ncold
        bit 2,(iy+MT_FL)
        jr nz,.half
        ld (ix+MO_ST),2             ; cold freezes for two turns
        jr .apply
.ncold: cp 3
        jr nz,.apply
        bit 4,(iy+MT_FL)            ; light burns shades
        jr z,.apply
        ld a,(m_dmg)
        add a,a
        ld (m_dmg),a
        jr .apply
.half:  ld a,(m_dmg)
        srl a
        jr nz,$+3
        inc a
        ld (m_dmg),a
.apply: ld (ix+MO_AUX),6            ; flash
        ld a,(m_dmg)
        ld b,a
        ld a,(ix+MO_HP)
        sub b
        jr c,.die
        jr z,.die
        ld (ix+MO_HP),a
        ret
.die:   ; dead
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call mark_map
        ld a,P_SPARK
        ld e,6
        call burst
        ld a,(ix+MO_TYPE)
        ld (mo_dead),a
        ld (ix+MO_TYPE),0
        ld hl,msg_kill
        call msg_mon_iy
        ld hl,SFX_KILL
        ld a,2
        call sfx
        ld hl,(kills)
        inc hl
        ld (kills),hl
        ld a,(iy+MT_XP)
        call gain_xp
        ; spore burst
        bit 7,(iy+MT_FL)
        jr z,.nb
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        ld a,P_POISON
        ld e,8
        call burst
        call grid_dist
        cp 2
        jr nc,.nb
        ld a,(poison)
        add a,3
        ld (poison),a
        ld hl,msg_spores
        call msg
.nb:    ; the king falls: victory
        ld a,(mo_dead)
        cp M_KING
        jr nz,.drop
        ld a,1
        ld (won),a
        ret
.drop:  ; sometimes a drop
        ld b,4
        call rand_below
        or a
        ret nz
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call item_at
        ret nz
        ld d,I_GOLD
        call gold_qty
        jp add_item

; the player attacks monster IX
player_attack:
        ld a,(ix+MO_TYPE)
        call mon_type
        ld a,(iy+MT_AI)
        cp AI_NPC
        jp z,npc_talk
        ld b,20
        call rand_below
        cp 3
        jr nc,.hit
        ld hl,msg_miss
        call msg_mon_iy
        ld hl,SFX_MISS
        ld a,1
        jp sfx
.hit:   ld a,(weapon)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,WEAPONS
        add hl,de
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        ld (mo_elem),a
        call rand_range
        ld b,a
        ld a,(plevel)
        dec a
        srl a
        add a,b                     ; + (level-1)/2
        ld b,a
        ld a,(iy+MT_DEF)
        srl a
        ld c,a
        ld a,b
        sub c
        jr c,.one
        jr nz,.ok
.one:   ld a,1
.ok:    push af
        ld hl,SFX_HIT
        ld a,1
        call sfx
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        ld a,P_SPARK
        ld e,3
        call burst
        pop af
        ld (m_dmg),a
        ld hl,msg_hit
        call msg_mon_iy_num
        ld a,(m_dmg)
        jp mon_damage

; ---------------------------------------------------------------------
; occasional wanderers, far from the player
wander_spawn:
        call mon_count
        cp 14
        ret nc
        ld e,20
.t:     dec e
        ret z
        ld b,62
        call rand_below
        inc a
        ld b,a
        push bc
        ld b,30
        call rand_below
        pop bc
        inc a
        ld c,a
        call tile_at
        cp T_FLOOR
        jr nz,.t
        call occupied
        jr nz,.t
        call map_addr
        ld a,h
        or high VISM
        ld h,a
        ld a,(hl)
        or a
        jr nz,.t
        push bc
        call zone_def
        ld b,4
        call rand_below
        ld e,a
        ld d,0
        add ix,de
        ld a,(ix+ZD_POOL)
        pop bc
        push af
        call mon_type
        ld a,(iy+MT_AI)
        cp AI_SWIM
        jr z,.sw
        pop af
        jp spawn_monster
.sw:    pop af
        ret
