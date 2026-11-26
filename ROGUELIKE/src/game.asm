; =====================================================================
;  game.asm - a game: the turn loop and the player's actions
; =====================================================================

new_game:
        ld hl,pvars_start
        ld de,pvars_start+1
        ld bc,pvars_end-pvars_start-1
        ld (hl),0
        ldir
        ld a,20
        ld (hp),a
        ld (hpmax),a
        ld a,1
        ld (plevel),a
        ld hl,20
        ld (xpnext),hl
        ld a,120
        ld (oil),a
        ld a,1
        ld (spells),a               ; FIREBOLT
        ld a,1
        ld (hpot),a
        call calc_stats
        ld a,(mpmax)
        ld (mp),a
        xor a
        ld (zone),a
        ld (zone_live),a
        ld (zgen),a
        ld (zvisit),a
        ld (dead),a
        ld (won),a
        ld a,1
        ld (newgame),a
        ld (bot_wait),a
        ; no creatures or items anywhere yet
        ld hl,ESTORE
        ld de,ESTORE+1
        ld bc,NZONES*ESIZE-1
        ld (hl),0
        ldir
        ld hl,zexits
        ld b,NZONES*9
.x:     ld (hl),0FFh
        inc hl
        djnz .x
        ret

; ---------------------------------------------------------------------
game:
        call snd_fe
        call mus_stop
        ld a,(demo)
        or a
        jr nz,.seeded
        ld hl,(dbg_seed)            ; (tests fix the dungeon here)
        ld a,h
        or l
        jr z,.rnd
        ld (seed),hl
        jr .seeded
.rnd:   ld a,(framecnt)             ; a new dungeon every game
        ld h,a
        ld a,r
        ld l,a
        ld a,(fieldcnt)
        xor l
        ld l,a
        ld de,(seed)
        add hl,de
        ld a,h
        or l
        jr nz,$+3
        inc l
        ld (seed),hl
.seeded:
        call new_game
        call descend_screen
        xor a
        call enter_zone
        xor a
        ld (newgame),a
        call play_setup
        call zone_banner
.turn:  call begin_turn
.idle:  ld a,(dbg_warp)             ; (tests poke a zone + 1 here)
        or a
        jr z,.nw
        dec a
        push af
        xor a
        ld (dbg_warp),a
        pop af
        call travel
        jr .turn
.nw:    call frame
        ld a,(demo)
        or a
        jr z,.human
        call bot_action             ; Z: none this frame
        jr .got
.human: ld a,1                      ; (tests watch this: waiting for a key)
        ld (in_input),a
        call get_action
        jr z,.got
        push af
        xor a
        ld (in_input),a
        pop af
.got:   jr z,.idle
        ld a,(quit)
        or a
        ret nz
        call do_action              ; NZ = a turn passed
        jr z,.idle
        call end_turn
        ld a,(dead)
        or a
        jp nz,death
        ld a,(won)
        or a
        jp nz,victory
        ld a,(quit)
        or a
        ret nz
        jr .turn

; full redraw of the play screen
play_setup:
        ld a,BLUE<<4
        call cls
        call ova_clear
        call parts_clear
        call hud_frame
        ld a,1
        ld (hud_dirty),a
        ld (need_fov),a
        ret

; start of the player's turn: what they see, the monsters' paths
begin_turn:
        call set_pmap
        call set_view
        call fov
        ld a,(demo)                 ; the paths: for hunters, and the bot
        or a
        jr nz,.b
        call any_awake
        jr z,.nb
.b:     call bfs
.nb:    xor a
        ld (need_fov),a
        ret

; one animation frame of the play view
frame:
        call wait_frame
        ld a,(need_fov)
        or a
        jr z,.nf
        call set_view
        call fov
        xor a
        ld (need_fov),a
.nf:    ; the torch: strength from the oil, a flicker
        ; (strength T lights 2T cells; without oil only a few; the
        ; sun-stone outshines the lantern with a golden light)
        ld a,(relic)
        or a
        jr z,.lan
        ld a,6<<4                   ; SUN
        ld (torch_hue),a
        ld a,8
        jr .t
.lan:   ld (torch_hue),a            ; WARM
        ld a,(oil)
        or a
        ld a,2
        jr z,.t
        ld a,7
.t:     ld (torch),a
        ld a,(framecnt)
        and 3
        jr nz,.tk
        call rand
        and 3
        ld a,0
        jr nz,.tk1
        inc a
.tk1:   ld (torch_fl),a
.tk:    call parts_update
        call ambient
        call render_frame
        ld a,(hud_dirty)
        or a
        call nz,hud_draw
        call msg_tick
        ld hl,pflash
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

; an animation frame inside a turn (spells, slides): no flicker work
anim_frame:
        push bc
        push de
        push hl
        push ix
        push iy
        call wait_frame
        call parts_update
        call render_frame
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        ret

; A frames of animation
anim_frames:
        push af
        call anim_frame
        pop af
        dec a
        jr nz,anim_frames
        ret

; ---------------------------------------------------------------------
; input: Z = nothing.  Else act_code / act_dir set.
ACT_MOVE        equ 1
ACT_CAST        equ 2
ACT_WAIT        equ 3
ACT_HPOT        equ 4
ACT_MPOT        equ 5
ACT_BOMB        equ 6
ACT_TELE        equ 7
ACT_MAP         equ 8

get_action:
        call .get
        jp kb_clear
.get:   ; spell choice 1-6 (no turn)
        ld b,0
        ld hl,spell_keys
.sk:    ld a,(hl)
        call key_hit
        jp nz,.pick
        inc hl
        inc b
        ld a,b
        cp NSPELLS
        jr c,.sk
        ld a,KC_BREAK
        call key_hit
        jp nz,ask_quit
        ld a,KC_CR
        call key_hit
        jp nz,pause
        ; directions: a press since last time, else held with repeat
        call read_dirs_acc
        or a
        jr z,.held
        ld c,a
        jr .first
.held:  call read_dirs
        ld c,a
        or a
        jr z,.nodir
        ld a,(dir_prev)
        or a
        jr z,.first
        ld hl,dir_rep
        dec (hl)
        jr nz,.keys
        ld (hl),3
        jr .go
.first: ld a,7
        ld (dir_rep),a
.go:    ld a,c
        ld (dir_prev),a
        call bits_dir
        ld (act_dir),a
        ld a,ACT_MOVE
        jr .act
.nodir: xor a
        ld (dir_prev),a
.keys:  ld a,KC_SPACE
        call key_hit
        ld b,ACT_CAST
        jr nz,.actb
        ld a,KC_W
        call key_hit
        ld b,ACT_WAIT
        jr nz,.actb
        ld a,KC_DOT
        call key_hit
        jr nz,.actb
        ld a,KC_H
        call key_hit
        ld b,ACT_HPOT
        jr nz,.actb
        ld a,KC_M
        call key_hit
        ld b,ACT_MPOT
        jr nz,.actb
        ld a,KC_B
        call key_hit
        ld b,ACT_BOMB
        jr nz,.actb
        ld a,KC_T
        call key_hit
        ld b,ACT_TELE
        jr nz,.actb
        ld a,KC_R
        call key_hit
        ld b,ACT_MAP
        jr nz,.actb
        xor a
        ret
.actb:  ld a,b
.act:   ld (act_code),a
        or a
        ret
.pick:  ; spell B, if known
        ld a,b
        call zbit
        ld hl,spells
        and (hl)
        jr z,.unk
        ld a,b
        ld (curspell),a
        ld a,1
        ld (hud_dirty),a
        ld hl,SFX_TALK
        ld a,1
        call sfx
        xor a
        ret
.unk:   ld hl,msg_unknown
        call msg
        call deny
        xor a
        ret

spell_keys:
        db KC_1,KC_2,KC_3,KC_4,KC_5,KC_6

; K_ bits in A -> direction 0 up, 1 down, 2 left, 3 right
bits_dir:
        bit B_UP,a
        jr z,$+4
        xor a
        ret
        bit B_DOWN,a
        jr z,$+5
        ld a,1
        ret
        bit B_LEFT,a
        jr z,$+5
        ld a,2
        ret
        ld a,3
        ret

; wait for a direction key (for spells and bombs): A = 0-3, or carry if
; cancelled (SPACE / BREAK)
ask_dir:
        ld a,(demo)
        or a
        jr nz,.demo
        call wait_release_play
.w:     call frame
        call read_dirs_acc
        or a
        jr nz,.d
        ld a,KC_SPACE
        call key_hit
        jr nz,.c
        ld a,KC_BREAK
        call key_hit
        jr z,.w
.c:     call msg_clear
        scf
        ret
.d:     call bits_dir
        call kb_clear
        or a
        ret
.demo:  ld a,(bot_dir)
        or a
        ret

; wait until no key is held, animating the view
wait_release_play:
.w:     call frame
        call anykey
        jr nz,.w
        jp kb_clear

; ---------------------------------------------------------------------
do_action:
        ld a,(act_code)
        cp ACT_MOVE
        jp z,act_move
        cp ACT_CAST
        jp z,cast_spell
        cp ACT_WAIT
        jr z,.wait
        cp ACT_HPOT
        jp z,use_hpot
        cp ACT_MPOT
        jp z,use_mpot
        cp ACT_BOMB
        jp z,throw_bomb
        cp ACT_TELE
        jp z,use_tele
        cp ACT_MAP
        jp z,use_map
        xor a
        ret
.wait:  ; resting: a little faster healing
        ld hl,regen
        inc (hl)
        or 1
        ret

; move / attack / bump in direction act_dir
act_move:
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,(act_dir)
        call dir_step
        ; a creature there?
        call mon_at
        jr z,.nm
        bit 1,(ix+MO_FL)            ; a disguised one wakes up
        jr z,.att
        res 1,(ix+MO_FL)
        set 0,(ix+MO_FL)
        ld a,(ix+MO_TYPE)
        call mon_type
        ld hl,msg_ambush
        call msg_mon
.att:   call player_attack
        or 1
        ret
.nm:    call tile_at
        ld (mv_tile),a
        call tile_flags
        ld (mv_flags),a
        bit 3,a                     ; bump action
        jp nz,bump
        bit 1,a
        jr z,.walk
        ; solid
        ld a,(mv_tile)
        cp T_WATER
        jr z,.water
        cp T_LAVA
        jr z,.lava
        xor a
        ret
.water: ld hl,msg_water
        call msg
        xor a
        ret
.lava:  ld hl,msg_lava
        call msg
        xor a
        ret
.walk:  ld a,b
        ld (px),a
        ld a,c
        ld (py),a
        call set_pmap
        call pickup
        call step_effects
        or 1
        ret

; the cell the player now stands on: traps, ice, exits, plates
step_effects:
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call tile_at
        cp T_TRAP
        jr z,.trap
        cp T_EXIT
        jr z,.exit
        cp T_ICE
        jp z,ice_slide
        ret
.trap:  ld a,T_TRAPSEEN
        call set_tile
        ld a,4
        ld (m_dmg),a
        call player_hurt
        ld hl,msg_trap
        jp msg
.exit:  ld a,(zone)
        call exits_addr
        ld e,3
.f:     ld a,(hl)
        cp b
        jr nz,.n
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr nz,.n
        inc hl
        inc hl
        ld a,(hl)
        jp travel
.n:     inc hl
        inc hl
        inc hl
        dec e
        jr nz,.f
        ret

; go to zone A
travel:
        push af
        ld hl,SFX_STAIRS
        ld a,3
        call sfx
        ld a,8
        call anim_frames
        pop af
        call enter_zone
        call play_setup
        call begin_turn
        call zone_banner
        ret

; bump into a tile with an action (B, C = its cell)
bump:
        ld a,(mv_tile)
        cp T_DOOR
        jr z,.door
        cp T_LOCKED
        jr z,.locked
        cp T_SEAL
        jp z,.seal
        cp T_CHEST
        jp z,open_chest
        cp T_BRAZOFF
        jp z,light_brazier
        cp T_BOULDER
        jp z,push_boulder
        cp T_PLATEB
        jp z,push_boulder
        cp T_LEVER
        jp z,pull_lever
        cp T_MIRRORA
        jp z,turn_mirror
        cp T_MIRRORB
        jp z,turn_mirror
        cp T_WEB
        jp z,.web
        cp T_FOUNTAIN
        jp z,.font
        cp T_ALTAR
        jp z,.altar
        cp T_PEDESTAL
        jp z,ped_put
        cp T_PEDLIT
        jp z,ped_take
        cp T_LDOOR
        jp z,.ldoor
        xor a
        ret
.door:  call map_addr
        ld a,T_OPEN
        call set_tile
        call relight                ; light spills through
        ld hl,SFX_DOOR
        ld a,1
        call sfx
        ld a,1
        ld (need_fov),a
        or a
        ret
.locked:
        ld a,(keys)
        or a
        jr z,.nokey
        dec a
        ld (keys),a
        call map_addr
        ld a,T_OPEN
        call set_tile
        ld hl,msg_unlock
        call msg
        ld hl,SFX_GATE
        ld a,2
        call sfx
        ld a,1
        ld (need_fov),a
        ld (hud_dirty),a
        or a
        ret
.nokey: ld hl,msg_locked
        call msg
        jp deny
.seal:  ld a,(sigils)
        cp 7
        jr nz,.noseal
        call map_addr
        ld a,T_OPEN
        call set_tile
        push bc
        ld a,P_MAGIC
        ld e,12
        call burst
        pop bc
        ld hl,msg_sealopen
        call msg
        ld hl,SFX_GATE
        ld a,3
        call sfx
        ld a,1
        ld (need_fov),a
        call relight
        or a
        ret
.noseal:
        ld hl,msg_sealed
        call msg
        jp deny
.web:   call map_addr
        ld a,T_FLOOR
        call set_tile
        ld a,P_DARK
        ld e,4
        call burst
        ld hl,msg_web
        call msg
        or 1
        ret
.font:  call map_addr
        ld a,T_DRYFONT
        call set_tile
        ld a,(hpmax)
        call heal_by
        ld a,(mpmax)
        ld (mp),a
        xor a
        ld (poison),a
        ld hl,msg_fountain
        call msg
        ld hl,SFX_HEAL
        ld a,2
        call sfx
        call relight
        or 1
        ret
.altar: ld hl,msg_altar
        call msg
        xor a
        ret
.ldoor: ld hl,msg_ldoor
        call msg
        jp deny

; the sun-stone: set it on an empty stand, or lift it from one
ped_put:
        ld a,(relic)
        or a
        jr z,ped_empty
        xor a
        ld (relic),a
        ld a,T_PEDLIT
        ld hl,msg_setstone
ped_set:                            ; tile A at (B, C), message HL
        push hl
        push af
        call map_addr
        pop af
        call set_tile
        pop hl
        call msg
        push bc
        ld a,P_GOLD
        ld e,8
        call burst
        pop bc
        ld hl,SFX_GATE
        ld a,2
        call sfx
        ld a,1
        ld (need_fov),a
        call relight
        or 1
        ret
ped_empty:
        ld hl,msg_pedestal
        call msg
        jp deny
ped_take:
        ld a,1
        ld (relic),a
        ld a,T_PEDESTAL
        ld hl,msg_takestone
        jr ped_set

; ---------------------------------------------------------------------
end_turn:
        call monsters_act
        call poll
        ld a,(dead)
        or a
        ret nz
        ld hl,(turns)
        inc hl
        ld (turns),hl
        ld hl,bot_zturns
        inc (hl)
        jr nz,$+3
        dec (hl)
        ; poison
        ld a,(poison)
        or a
        jr z,.np
        dec a
        ld (poison),a
        ld a,(turns)
        and 1
        jr nz,.np
        ld a,1
        ld (m_dmg),a
        call player_hurt
        ld a,(dead)
        or a
        ret nz
.np:    ; regeneration
        ld hl,regen
        inc (hl)
        ld a,(hl)
        cp 7
        jr c,.nr
        ld (hl),0
        ld a,(poison)
        or a
        jr nz,.nr
        ld a,(hp)
        ld hl,hpmax
        cp (hl)
        jr nc,.nr
        inc a
        ld (hp),a
        ld a,1
        ld (hud_dirty),a
.nr:    ld a,(turns)
        and 7
        jr nz,.nm
        ld a,(mp)
        ld hl,mpmax
        cp (hl)
        jr nc,.nm
        inc a
        ld (mp),a
        ld a,1
        ld (hud_dirty),a
.nm:    ; the lantern burns oil (not while the sun-stone lights the way)
        ld a,(relic)
        or a
        jr nz,.no
        ld a,(turns)
        and 3
        jr nz,.no
        ld a,(oil)
        or a
        jr z,.no
        dec a
        ld (oil),a
        jr nz,.nw
        ld hl,msg_dark
        call msg
.nw:    cp 20
        jr nz,.no2
        ld hl,msg_lowoil
        call msg
.no2:   ld a,1
        ld (hud_dirty),a
.no:    ; flares burn down
        call flares_tick
        ; now and then a wanderer
        ld a,(turns)
        and 63
        call z,wander_spawn
        ret

; ---------------------------------------------------------------------
gain_xp:
        ld e,a
        ld d,0
        ld hl,(xp)
        add hl,de
        ld (xp),hl
        ld de,(xpnext)
        or a
        sbc hl,de
        ret c
        ; level up
        ld hl,plevel
        inc (hl)
        ld hl,(xpnext)
        add hl,hl
        ld de,10
        add hl,de
        ld (xpnext),hl
        ld a,(hpmax)
        add a,6
        ld (hpmax),a
        ld (hp),a
        call calc_stats
        ld a,(mpmax)
        ld (mp),a
        ld hl,msg_level
        call msg
        ld hl,SFX_LEVEL
        ld a,3
        call sfx
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,P_HEAL
        ld e,12
        call burst
        ld a,1
        ld (hud_dirty),a
        ret

; ---------------------------------------------------------------------
pause:
        ld hl,msg_paused
        call msg
        call wait_release_play
.w:     call wait_frame
        call anyhit
        jr z,.w
        call msg_clear
        call wait_release_play
        xor a
        ret

ask_quit:
        ld hl,msg_quit
        call msg
        call wait_release_play
.w:     call wait_frame
        call scan_keys
        ld a,KC_Y
        call key_hit
        jr nz,.yes
        ld a,KC_N
        call key_hit
        jr nz,.no
        ld a,KC_BREAK
        call key_hit
        jr z,.w
.no:    call msg_clear
        xor a
        ret
.yes:   ld a,1
        ld (quit),a
        or a
        ret
