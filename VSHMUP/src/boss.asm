; =====================================================================
;  boss.asm - the five bosses
;
;  A boss is one big sprite (owner 80h in the collision map) that flies
;  in, then moves in its own way and runs an attack script: steps of
;  (action, gun column, gun row, parameter, repeats, gap).  Below half
;  its hit points it switches to a second, nastier script.
; =====================================================================

BA_LOOP   equ 0
BA_AIM    equ 1                 ; one aimed bullet
BA_SPREAD equ 2                 ; parameter bullets, aimed
BA_FAN    equ 3                 ; parameter bullets, fanned downwards
BA_RING   equ 4                 ; parameter bullets all round
BA_SPIRAL equ 5                 ; one bullet, turning parameter each time
BA_SPAWN  equ 6                 ; an enemy of type parameter
BA_RAIN   equ 7                 ; straight down from anywhere under it
BA_WAIT   equ 8
BA_TWIN   equ 9                 ; aimed, from the gun and its mirror

BSTEP   MACRO act, gx, gy, par, rep, gap
        db act, gx, gy, par, rep, gap
        ENDM

; per boss: sprite, w, h, hp, points, script 1, script 2, movement
bosstab:
        dw BOSS_WARDEN
        db BW_WARDEN, BH_WARDEN
        dw 300, 1000h, bs_war1, bs_war2
        db 0, 0
        dw BOSS_HIVE
        db BW_HIVE, BH_HIVE
        dw 360, 1500h, bs_hive1, bs_hive2
        db 1, 0
        dw BOSS_FORT
        db BW_FORT, BH_FORT
        dw 440, 2000h, bs_fort1, bs_fort2
        db 2, 0
        dw BOSS_CLAW
        db BW_CLAW, BH_CLAW
        dw 520, 2500h, bs_claw1, bs_claw2
        db 3, 0
        dw BOSS_MIND
        db BW_MIND, BH_MIND
        dw 700, 5000h, bs_mind1, bs_mind2
        db 1, 0
BTSZ    equ 14

bs_war1:
        BSTEP BA_SPREAD, 4, 4, 3, 3, 12
        BSTEP BA_WAIT, 0, 0, 0, 1, 20
        BSTEP BA_FAN, 2, 3, 5, 2, 20
        BSTEP BA_FAN, 7, 3, 5, 2, 20
        BSTEP BA_TWIN, 1, 2, 0, 3, 10
        BSTEP BA_WAIT, 0, 0, 0, 1, 15
        db BA_LOOP
bs_war2:
        BSTEP BA_RING, 4, 3, 12, 1, 25
        BSTEP BA_SPREAD, 4, 4, 5, 3, 10
        BSTEP BA_TWIN, 1, 2, 0, 5, 7
        BSTEP BA_RING, 5, 3, 12, 1, 25
        BSTEP BA_FAN, 4, 4, 5, 3, 12
        db BA_LOOP
bs_hive1:
        BSTEP BA_SPAWN, 4, 5, T_BUG, 3, 12
        BSTEP BA_FAN, 4, 5, 5, 2, 25
        BSTEP BA_WAIT, 0, 0, 0, 1, 20
        BSTEP BA_SPREAD, 4, 2, 3, 3, 10
        BSTEP BA_WAIT, 0, 0, 0, 1, 20
        db BA_LOOP
bs_hive2:
        BSTEP BA_SPIRAL, 4, 2, 5, 24, 2
        BSTEP BA_SPAWN, 4, 5, T_SKULL, 2, 20
        BSTEP BA_RING, 4, 2, 16, 1, 25
        BSTEP BA_SPAWN, 4, 5, T_BUG, 3, 10
        BSTEP BA_FAN, 4, 5, 5, 2, 20
        db BA_LOOP
bs_fort1:
        BSTEP BA_TWIN, 1, 1, 0, 6, 6
        BSTEP BA_RAIN, 0, 4, 0, 10, 3
        BSTEP BA_WAIT, 0, 0, 0, 1, 20
        BSTEP BA_FAN, 4, 4, 5, 2, 15
        BSTEP BA_WAIT, 0, 0, 0, 1, 15
        db BA_LOOP
bs_fort2:
        BSTEP BA_RING, 4, 2, 16, 2, 25
        BSTEP BA_TWIN, 1, 3, 0, 8, 4
        BSTEP BA_SPAWN, 4, 4, T_DART, 3, 10
        BSTEP BA_RAIN, 0, 4, 0, 14, 2
        BSTEP BA_SPREAD, 4, 4, 5, 2, 15
        db BA_LOOP
bs_claw1:
        BSTEP BA_SPREAD, 0, 2, 5, 2, 12
        BSTEP BA_SPREAD, 9, 2, 5, 2, 12
        BSTEP BA_RING, 4, 4, 12, 1, 20
        BSTEP BA_TWIN, 1, 1, 0, 4, 8
        BSTEP BA_WAIT, 0, 0, 0, 1, 15
        db BA_LOOP
bs_claw2:
        BSTEP BA_SPIRAL, 4, 3, 7, 32, 1
        BSTEP BA_TWIN, 0, 2, 0, 6, 5
        BSTEP BA_RAIN, 0, 4, 0, 12, 2
        BSTEP BA_RING, 4, 4, 16, 2, 18
        db BA_LOOP
bs_mind1:
        BSTEP BA_RING, 5, 3, 16, 3, 18
        BSTEP BA_SPREAD, 5, 6, 5, 3, 10
        BSTEP BA_SPAWN, 5, 6, T_SKULL, 2, 15
        BSTEP BA_TWIN, 1, 3, 0, 4, 8
        db BA_LOOP
bs_mind2:
        BSTEP BA_SPIRAL, 5, 3, 5, 48, 1
        BSTEP BA_RING, 5, 3, 16, 2, 15
        BSTEP BA_SPREAD, 5, 6, 5, 4, 8
        BSTEP BA_SPAWN, 5, 6, T_EYE, 1, 10
        BSTEP BA_RAIN, 0, 6, 0, 12, 2
        db BA_LOOP

; A = boss number: it starts flying in
boss_start:
        ld (bossid),a
        ld l,a
        ld h,0
        add hl,hl               ; x 14
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,bosstab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (bspr),de
        ld a,(hl)
        inc hl
        ld (bw),a
        ld a,(hl)
        inc hl
        ld (bh),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld a,(diff)             ; + 40 hit points a loop/stage step
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,bc               ; diff * 40
        add hl,de
        ld (bhp),hl
        ld (bhpmax),hl
        ; a bar cell per eighth
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        inc hl
        ld (bhp8),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (bpts),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (bscr),de
        ld (bscr0),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (bscr2),de
        ld a,(hl)
        ld (bmove),a
        ; place it above the top, centred
        ld a,(bw)
        ld c,a
        ld a,PFW
        sub c
        srl a
        ld (bx+1),a
        ld (bxc),a
        xor a
        ld (bx),a
        ld (by),a
        ld (btm),a
        ld (bphase),a
        ld (brep),a
        ld (bflash),a
        ld a,(bh)
        neg
        ld (by+1),a
        ld a,1
        ld (bossact),a
        ld a,40
        ld (bwait),a
        ld a,1
        ld (hudboss),a
        ret

boss_tick:
        ld a,(bossact)
        or a
        ret z
        cp 3
        jp z,boss_dying
        cp 1
        jr nz,.fight
        ; flying in
        ld hl,(by)
        ld de,18h
        add hl,de
        ld (by),hl
        ld a,h
        cp 1
        jr nz,.draw
        ld a,2
        ld (bossact),a
        jr .draw
.fight: call boss_move
        call boss_script
.draw:  ; fall through
boss_draw:
        ld a,(bflash)
        or a
        jr z,.nf
        dec a
        ld (bflash),a
        ld a,(framecnt)         ; (alternate ticks: it keeps its colours)
        and 1
.nf:    ld (sprflash),a
        ld iy,(bspr)
        ld a,(by+1)
        ld b,a
        ld a,(bx+1)
        ld c,a
        ld a,80h
        call draw_spr
        xor a
        ld (sprflash),a
        ret

boss_move:
        ld hl,btm
        inc (hl)
        ld a,(bmove)
        cp 2
        jr z,.chase
        ; sway: x = centre + cos(t/4) * room
        ld a,(btm)
        ld e,a
        ld a,(bphase)           ; faster in phase 2
        or a
        ld a,e
        jr nz,.f
        srl a
.f:     srl a
        srl a
        and 31
        call costab_at
        ld d,a
        ld a,(bxc)              ; room each side = the centred column
        ld e,a
        ld a,d
        call smul
        ld hl,bxc
        add a,(hl)
        ld (bx+1),a
        ld a,(bmove)
        or a
        ret z
        cp 3
        jr z,.eight
        ; bob: y = 1 + (1 - cos(t/8)) * 1.5
.bob:   ld a,(btm)
        srl a
        srl a
        srl a
        and 31
        call costab_at
        neg
        add a,127
        rrca                    ; 0..127
        and 7Fh
        srl a
        srl a
        srl a
        srl a
        srl a                   ; 0..3
        inc a
        ld (by+1),a
        ret
.eight: ld a,(btm)              ; vertical at twice the horizontal rate
        srl a
        and 31
        call costab_at
        add a,128
        srl a
        srl a
        srl a
        srl a
        srl a
        srl a                   ; 0..3
        inc a
        ld (by+1),a
        ret
.chase: ld a,(btm)              ; slowly towards the ship's column
        and 3
        jr nz,.bob
        ld a,(bw)
        srl a
        ld c,a
        ld a,(px+1)
        sub c                   ; wanted left column
        ld hl,bx+1
        cp (hl)
        jr z,.bob
        jp m,.cl
        jr c,.cl
        ld a,(bw)
        add a,(hl)
        cp PFW
        jr nc,.bob
        inc (hl)
        jr .bob
.cl:    ld a,(hl)
        or a
        jr z,.bob
        dec (hl)
        jr .bob

boss_script:
        ld a,(bwait)
        or a
        jr z,.go
        dec a
        ld (bwait),a
        ret
.go:    ld hl,(bscr)
        ld a,(hl)
        or a
        jr nz,.act
        ld hl,(bscr0)           ; loop
        ld (bscr),hl
        ld a,(hl)
.act:   push hl
        pop iy                  ; IY = step
        ld a,(brep)
        or a
        jr nz,.r
        ld a,(iy+4)
        ld (brep),a
.r:     call boss_action
        ld a,(iy+5)
        ld (bwait),a
        ld hl,brep
        dec (hl)
        ret nz
        ld de,6
        add iy,de
        ld (bscr),iy
        ret

; IY = step: do it once
boss_action:
        ld a,(bx+1)             ; B = gun row, C = gun column
        add a,(iy+1)
        ld c,a
        ld a,(by+1)
        add a,(iy+2)
        ld b,a
        ld a,(iy+0)
        cp BA_AIM
        jp z,fire_aimed
        cp BA_SPREAD
        jr nz,.n2
        ld a,(iy+3)
        jp fire_spread
.n2:    cp BA_FAN
        jr nz,.n3
        ld a,(iy+3)
        jp fire_fan
.n3:    cp BA_RING
        jr nz,.n4
        ld hl,SFX_EBIG
        ld a,3
        call sfx
        ld a,(iy+3)
        jp fire_ring
.n4:    cp BA_SPIRAL
        jr nz,.n5
        ld a,(bspiral)
        add a,(iy+3)
        and 31
        ld (bspiral),a
        push af
        ld a,(bspd)
        sub 8
        ld e,a
        pop af
        ld d,2
        jp new_bullet
.n5:    cp BA_SPAWN
        jr nz,.n6
        push iy
        ld a,(iy+3)
        ld de,8
        call spawn_enemy
        pop iy
        ret c
        ld hl,SFX_SPAWN
        ld a,3
        jp sfx
.n6:    cp BA_RAIN
        jr nz,.n7
        ld a,(bw)
        call rand_n
        add a,c
        ld c,a
        ld a,8
        jp fire_dir
.n7:    cp BA_TWIN
        ret nz
        push bc
        call fire_aimed
        pop bc
        ld a,(iy+1)             ; the mirror gun: x + w - 1 - 2*gx
        add a,a
        neg
        ld hl,bw
        add a,(hl)
        dec a
        add a,c
        ld c,a
        jp fire_aimed

; A = damage to the boss (from a shot or a bomb)
boss_hit:
        ld b,a
        ld a,(bossact)
        cp 2
        ret nz
        ld hl,(bhp)
        ld a,l
        sub b
        ld l,a
        jr nc,.nc
        dec h
.nc:    bit 7,h
        jr nz,boss_dead
        ld a,h
        or l
        jr z,boss_dead
        ld (bhp),hl
        ld a,2
        ld (bflash),a
        ld a,1
        ld (hudboss),a
        push hl
        ld de,0001h             ; 10 points a hit
        call add_score
        ld hl,SFX_HIT
        ld a,2
        call sfx
        pop hl
        ; phase 2 below half
        ld a,(bphase)
        or a
        ret nz
        ld de,(bhpmax)
        srl d
        rr e
        or a
        sbc hl,de
        ret nc
        ld a,1
        ld (bphase),a
        ld hl,(bscr2)
        ld (bscr),hl
        ld (bscr0),hl
        xor a
        ld (brep),a
        ld a,10
        ld (bflash),a
        ld (bwait),a
        ret

boss_dead:
        ld hl,0
        ld (bhp),hl
        ld a,3
        ld (bossact),a
        ld a,80
        ld (bdeath),a
        ld a,1
        ld (hudboss),a
        call clear_bullets
        ld hl,SFX_BIGBOOM
        ld a,11
        call sfx
        ; the minions go too
        ld ix,ENEMY
        ld b,MAXEN
.k:     push bc
        ld a,(ix+ET)
        or a
        jr z,.n
        ld a,(ix+EY)
        cp PFH
        jr nc,.n
        call en_centre
        call explode
        ld (ix+ET),0
.n:     ld de,ENSZ
        add ix,de
        pop bc
        djnz .k
        ret

boss_dying:
        ld a,(bdeath)
        dec a
        ld (bdeath),a
        jr z,.done
        and 1
        jr nz,.d
        ld a,(bw)               ; an explosion somewhere on it
        call rand_n
        ld hl,bx+1
        add a,(hl)
        ld c,a
        ld a,(bh)
        call rand_n
        ld hl,by+1
        add a,(hl)
        ld b,a
        call explode
        ld a,(bdeath)
        and 15
        jr nz,.d
        ld hl,SFX_BOOM
        ld a,6
        call sfx
.d:     ld a,(bdeath)
        cp 30
        ret c                   ; (it's gone; only the smoke is left)
        and 2
        ld (bflash),a
        jp boss_draw
.done:  xor a
        ld (bossact),a
        ld a,1
        ld (hudboss),a
        ld de,(bpts)
        call add_score
        ld a,(bw)               ; a last big burst
        srl a
        ld hl,bx+1
        add a,(hl)
        ld c,a
        ld a,(bh)
        srl a
        ld hl,by+1
        add a,(hl)
        ld b,a
        call big_burst
        ld hl,SFX_BIGBOOM
        ld a,11
        call sfx
        jp stage_clear
