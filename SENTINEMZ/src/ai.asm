; =====================================================================
;  ai.asm - the demo pilot
;
;  Think -> aim (the cursor walks to the target cell) -> act, through the
;  same action routines the player uses.  Priorities: put the Lantern
;  out when its tile is in view; absorb what it can see; otherwise climb
;  to the best visible tile (cairns + shell + move), preferring ground
;  near the Lantern; otherwise turn a quarter and look again.
; =====================================================================

AI_THINK        equ 0
AI_AIM          equ 1
AI_ACT          equ 2

ai_step:
        ld a,(need_render)
        or a
        ret nz
        ld hl,ai_wait
        ld a,(hl)
        or a
        jr z,.go
        dec (hl)
        ret
.go:    ld a,(ai_state)
        or a
        jp z,ai_think
        dec a
        jp z,ai_aim
        jp ai_do

; ---------------------------------------------------------------------
ai_think:
        ld a,15
        ld (ai_wait),a
        ; a climb in progress?
        ld a,(ai_plan)
        or a
        jr z,.lant
        ld hl,(ai_goal)
        call tf_addr
        bit 7,(hl)
        jr z,.drop
        ld hl,(ai_goal)
        call obj_addr
        ld a,(hl)
        and 7
        ld b,'T'
        cp O_SHELL
        jr z,.plan_go
        or a
        jr nz,.drop
        ld a,(hl)                   ; cairns so far
        rrca
        rrca
        rrca
        rrca
        and 7
        ld c,a
        ld a,(ai_want)
        cp c
        ld b,'S'
        jr z,.plan_go
        jr c,.plan_go
        ld b,'B'
.plan_go:
        ld hl,(ai_goal)
        jp ai_target
.drop:  xor a
        ld (ai_plan),a
        ; the Lantern in view?
.lant:  ld hl,(lant_t)
        call tf_addr
        bit 7,(hl)
        jr z,.abs
        ld hl,(lant_t)
        ld b,'A'
        call ai_target
        ret nc
        ; something to absorb?
.abs:   call ai_find_absorb
        jr c,.climb
        ld b,'A'
        call ai_target
        ret nc
.climb: call ai_find_climb
        jr c,.turn
        ld hl,(ai_best)
        ld a,(ai_plan)              ; (ai_find_climb chose B, S or T)
        ld b,a
        ld a,1
        ld (ai_plan),a
        call ai_target
        ret nc
        xor a
        ld (ai_plan),a
.turn:  ld a,(heading)              ; nothing: look a quarter further round
        add a,8
        and 31
        ld (heading),a
        ld hl,ai_turns
        inc (hl)
        ld a,(hl)
        and 3
        jr nz,.t
        ld a,(pitch)                ; every full circle: tilt the gaze
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (pitch),a
.t:     xor a
        ld (ai_fail),a
        ld (ai_fail+1),a
        ld hl,SFX_TURN
        ld a,1
        call sfx
        ld a,1
        ld (need_render),a
        ret

; aim at tile HL with action B; carry if it is not on screen
ai_target:
        ld (ai_goal),hl
        ld a,b
        ld (ai_act),a
        ld de,(ai_fail)             ; just failed there: skip
        or a
        sbc hl,de
        jr z,.no
        ld hl,(ai_goal)
        call project_tile
        jr c,.no
        ld hl,(pcol)                ; cell = pixel / 2, inside the view
        bit 7,h
        jr nz,.no
        ld a,h
        or a
        jr nz,.no
        ld a,l
        cp VIEW_W
        jr nc,.no
        srl a
        ld (ai_cx),a
        ld hl,(prow)
        ld a,(ai_act)               ; objects: aim a little above the ground
        cp 'S'
        jr z,.b
        cp 'B'
        jr nz,.o
.b:
        ld hl,(ai_goal)             ; cairns already there: aim at them
        call obj_addr
        ld a,(hl)
        ld hl,(prow)
        or a
        jr z,.g
.o:     dec hl
        dec hl
.g:     bit 7,h
        jr nz,.no
        ld a,h
        or a
        jr nz,.no
        ld a,l
        cp VIEW_H
        jr nc,.no
        srl a
        ld (ai_cy),a
        ld a,AI_AIM
        ld (ai_state),a
        or a
        ret
.no:    scf
        ret

; walk the cursor one cell towards (ai_cx, ai_cy)
ai_aim:
        ld a,2
        ld (ai_wait),a
        ld a,(ccx)
        ld c,a
        ld a,(ai_cx)
        ld b,0
        cp c
        jr z,.y
        ld b,1
        jr nc,.y
        ld b,-1
.y:     ld a,(ccy)
        ld c,a
        ld a,(ai_cy)
        ld e,0
        cp c
        jr z,.m
        ld e,1
        jr nc,.m
        ld e,-1
.m:     ld a,b
        or e
        jr z,.there
        ld c,e
        jp cursor_move
.there: ld a,AI_ACT
        ld (ai_state),a
        ld a,6
        ld (ai_wait),a
        ret

; act, after making sure the cursor picks the goal (searching nearby cells)
ai_do:
        ld a,AI_THINK
        ld (ai_state),a
        ld a,20
        ld (ai_wait),a
        call ai_picks
        jr z,.act
        call cursor_hide
        ld a,(ccx)                  ; try the cells around
        ld (ai_cx),a
        ld a,(ccy)
        ld (ai_cy),a
        ld hl,AI_NEAR
        ld b,12
.n:     push bc
        push hl
        ld a,(ai_cx)
        add a,(hl)
        cp 40
        jr nc,.nx
        ld (ccx),a
        inc hl
        ld a,(ai_cy)
        add a,(hl)
        cp VIEW_ROWS
        jr nc,.nx
        ld (ccy),a
        call ai_picks
        jr z,.found
.nx:    pop hl
        inc hl
        inc hl
        pop bc
        djnz .n
        ld a,(ai_cx)                ; give up on this one
        ld (ccx),a
        ld a,(ai_cy)
        ld (ccy),a
        call pick
        call cursor_show
        ld hl,(ai_goal)
        ld (ai_fail),hl
        xor a
        ld (ai_plan),a
        ret
.found: pop hl
        pop bc
        call cursor_show
        call hud_target
.act:   ld a,(ai_act)
        cp 'A'
        jp z,act_absorb
        cp 'B'
        jp z,act_cairn
        cp 'S'
        jp z,act_shell
        xor a
        ld (ai_plan),a
        ld (ai_turns),a
        jp act_move

; Z if the cursor cell picks ai_goal
ai_picks:
        call pick
        ld a,(tgt_kind)
        or a
        jr z,.no
        ld hl,(tgt_t)
        ld de,(ai_goal)
        or a
        sbc hl,de
        ret
.no:    or 1
        ret

AI_NEAR:
        db 0,1, 0,-1, 1,0, -1,0, 0,2, 0,-2, 1,1, -1,1, 1,-1, -1,-1, 0,3, 0,-3

; ---------------------------------------------------------------------
; HL = best visible thing to absorb (not the Lantern); carry if none
; value: wisp 4, shard 3, shell 2 (if energy < 12), cairn 1 (if energy < 5)
ai_find_absorb:
        xor a
        ld (ai_bests),a
        ld hl,0
.t:     push hl
        call tf_addr
        bit 7,(hl)
        pop hl
        jr z,.n
        push hl
        call obj_addr
        ld a,(hl)
        pop hl
        or a
        jr z,.n
        ld c,a
        ld de,(ptile)
        call .same
        jr z,.n
        ld de,(lant_t)
        call .same
        jr z,.n
        ld de,(ai_fail)
        call .same
        jr z,.n
        ld a,c
        and 7
        ld b,4
        cp O_WISP
        jr z,.v
        ld b,3
        cp O_SHARD
        jr z,.v
        ld b,0
        cp O_SHELL
        jr nz,.cr
        ld a,(energy)
        cp 12
        jr nc,.v
        ld b,2
        jr .v
.cr:    or a
        jr nz,.v
        ld a,(energy)
        cp 5
        jr nc,.v
        ld b,1
.v:     ld a,(ai_bests)
        cp b
        jr nc,.n
        ld a,b
        ld (ai_bests),a
        ld (ai_best),hl
.n:     inc hl
        ld a,h
        cp 4
        jr c,.t
        ld a,(ai_bests)
        or a
        scf
        ret z
        ld hl,(ai_best)
        or a
        ret
.same:  ld a,l
        cp e
        ret nz
        ld a,h
        cp d
        ret

; best visible tile to climb to -> ai_best, ai_want, ai_plan = first action
; carry if nothing is higher than where we stand
ai_find_climb:
        ld hl,(ptile)               ; our height: f + 4 * cairns
        call ai_height
        ld b,a                      ; stuck a full circle: accept a lower
        ld a,(ai_turns)             ;   viewpoint nearer the Lantern
        cp 4
        ld a,b
        jr c,.th
        sub 5
        jr nc,.th
        xor a
.th:    ld (ai_here),a
        ld a,(energy)               ; cairns we can afford: (energy - 3) / 2, at most 3
        sub 3
        jp c,.none
        srl a
        cp 4
        jr c,$+4
        ld a,3
        ld (ai_k),a
        xor a
        ld (ai_bests),a
        ld hl,0
.t:     push hl
        call tf_addr
        ld a,(hl)
        pop hl
        bit 7,a
        jp z,.n
        bit 4,a
        jp z,.n                     ; slopes
        ld de,(ptile)
        call ai_find_absorb.same
        jp z,.n
        ld de,(ai_fail)
        call ai_find_absorb.same
        jp z,.n
        push hl
        call obj_addr
        ld a,(hl)
        pop hl
        ld c,a
        and 7
        jr z,.free
        cp O_SHELL
        jr nz,.n
        call ai_height              ; a shell already there: just move
        ld b,'T'
        jr .score
.free:  ld a,c                      ; cairns + ours
        rrca
        rrca
        rrca
        rrca
        and 7
        ld d,a
        ld a,(ai_k)
        add a,d
        cp 8
        jr c,$+4
        ld a,7
        ld (ai_wt),a                ; cairns wanted
        sub d
        ld b,'S'
        jr z,.nb
        ld b,'B'
.nb:    push bc
        call tile_f
        ld e,a
        ld a,(ai_wt)
        add a,a
        add a,a
        add a,e                     ; height after building
        pop bc
.score: ld (ai_ht),a
        ld e,a
        ld a,(ai_here)
        cp e
        jp nc,.n                    ; not higher
        ; score = 2 * height - distance to the Lantern / 2
        push hl
        push bc
        call tile_xy
        ld a,(lantx)
        sub e
        call absa
        ld c,a
        ld a,(lanty)
        sub d
        call absa
        add a,c
        srl a
        ld c,a
        ld a,(ai_ht)
        add a,a
        sub c
        jr nc,$+3
        xor a
        inc a
        ld e,a
        pop bc
        pop hl
        ld a,(ai_bests)
        cp e
        jr nc,.n
        ld a,e
        ld (ai_bests),a
        ld (ai_best),hl
        ld a,b
        ld (ai_plan),a
        ld a,(ai_wt)
        ld (ai_want),a
.n:     inc hl
        ld a,h
        cp 4
        jp c,.t
        ld a,(ai_bests)
        or a
        jr z,.none
        ld hl,(ai_best)
        or a
        ret
.none:  scf
        ret

; A = standing height of tile HL: f + 4 * cairns
ai_height:
        push hl
        call obj_addr
        ld a,(hl)
        pop hl
        rrca
        rrca
        and 1Ch
        ld c,a
        call tile_f
        add a,c
        ret
