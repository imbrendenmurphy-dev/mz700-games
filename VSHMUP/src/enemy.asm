; =====================================================================
;  enemy.asm - enemies, their bullets, wave spawners, capsules, medals
; =====================================================================

; A = enemy index -> IY = enemy (A, DE kept)
enemy_iy:
        push de
        push af
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ENEMY
        add hl,de
        push hl
        pop iy
        pop af
        pop de
        ret

; type table: frame 0, frame 1, w, h, hp, points (BCD tens), flags, fire
TYSZ    equ 10
ENTYPE  MACRO s0, s1, w, h, hp, pts, fl, fire
        dw s0, s1
        db w, h, hp
        dw pts
        db fl
        ENDM
entypes:
        ENTYPE SPR_DART0, SPR_DART1, 1, 1, 1, 0010h, 0, 0        ; dart
        ENTYPE SPR_WASP0, SPR_WASP1, 1, 1, 1, 0010h, 0, 0        ; wasp
        ENTYPE SPR_CRAB0, SPR_CRAB1, 1, 1, 2, 0015h, 0, 0        ; crab
        ENTYPE SPR_BUG0, SPR_BUG1, 1, 1, 1, 0010h, 0, 0          ; bug
        ENTYPE SPR_SKULL0, SPR_SKULL1, 1, 1, 3, 0020h, 0, 0      ; skull
        ENTYPE SPR_EYE0, SPR_EYE1, 1, 1, 5, 0030h, 0, 0          ; eye
        ENTYPE SPR_MINE0, SPR_MINE1, 1, 1, 3, 0020h, 0, 0        ; mine
        ENTYPE SPR_FISHL, SPR_FISHL, 1, 1, 1, 0010h, 0, 0        ; fish
        ENTYPE SPR_UFO0, SPR_UFO1, 2, 1, 4, 0050h, 0, 0          ; ufo
        ENTYPE SPR_GUN0, SPR_GUN0, 2, 2, 10, 0050h, EF_BIG, 0    ; gunship
        ENTYPE SPR_ROCK, SPR_ROCK, 3, 2, 8, 0030h, EF_BIG, 0     ; rock
        ENTYPE SPR_ROCKS, SPR_ROCKS, 1, 1, 2, 0005h, 0, 0        ; rock chip
        ENTYPE SPR_TUR0, SPR_TUR1, 1, 1, 4, 0030h, EF_GROUND, 0  ; turret
        ENTYPE SPR_HEAVY, SPR_HEAVY, 3, 2, 60, 0200h, EF_BIG, 0  ; heavy

entupd: dw upd_dart, upd_wasp, upd_crab, upd_bug, upd_skull, upd_eye
        dw upd_mine, upd_fish, upd_ufo, upd_gun, upd_rock, upd_none
        dw upd_tur, upd_heavy

; A = type, C = column, B = row, E = parameter, D = drop
; -> IX = the new enemy (NC), or C set when there is no room
spawn_enemy:
        ld (sptype),a
        push de
        push bc
        ld ix,ENEMY
        ld de,ENSZ
        ld b,MAXEN
.f:     ld a,(ix+ET)
        or a
        jr z,.got
        add ix,de
        djnz .f
        pop bc
        pop de
        scf
        ret
.got:   push ix                 ; clear it
        pop hl
        ld b,ENSZ
.c:     ld (hl),0
        inc hl
        djnz .c
        pop bc
        pop de
        ld (ix+EX),c
        ld (ix+EY),b
        ld (ix+EX0),c
        ld (ix+EPAR),e
        ld (ix+EDROP),d
        ld a,(sptype)
        ld (ix+ET),a
        dec a
        ld l,a                  ; HL = entypes + (type-1)*TYSZ
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,entypes
        add hl,de
        ld a,(hl)
        ld (ix+ESP0),a
        inc hl
        ld a,(hl)
        ld (ix+ESP0+1),a
        inc hl
        ld a,(hl)
        ld (ix+ESP1),a
        inc hl
        ld a,(hl)
        ld (ix+ESP1+1),a
        inc hl
        ld a,(hl)
        ld (ix+EW),a
        inc hl
        ld a,(hl)
        ld (ix+EH),a
        inc hl
        ld a,(diff)             ; hit points grow a little with the loop
        srl a
        srl a
        add a,(hl)
        ld (ix+EHP),a
        inc hl
        ld a,(hl)
        ld (ix+EPTS),a
        inc hl
        ld a,(hl)
        ld (ix+EPTS+1),a
        inc hl
        ld a,(hl)
        ld (ix+EFLG),a
        ld a,40                 ; first shot after a while
        call rand_n
        add a,25
        ld (ix+EFT),a
        ld a,(sptype)           ; the type's own start
        call en_init
        or a                    ; NC
        ret

en_init:
        cp T_DART
        jr nz,.n1
        ld (ix+EVYL),58h
        ret
.n1:    cp T_WASP
        jr nz,.n2
        ld (ix+EVYL),2Ch
        ret
.n2:    cp T_CRAB
        jr nz,.n3
        ld (ix+EVYL),40h
        ret
.n3:    cp T_BUG
        jr z,.side
        cp T_FISH
        jr z,.side
        cp T_UFO
        jr nz,.n4
.side:  ; enter from the side named by the column, at the row in the parameter
        ld a,(ix+ET)
        cp T_BUG
        jr nz,.sr
        ld a,5
        call rand_n
        jr .sy
.sr:    ld a,(ix+EPAR)
.sy:    ld (ix+EY),a
        ld a,(ix+ET)            ; speed
        ld e,48h
        cp T_BUG
        jr z,.sp
        ld e,40h
        cp T_FISH
        jr z,.sp
        ld e,2Ch
.sp:    ld a,(ix+EX)
        cp 15
        jr nc,.fromr
        ld (ix+EX),-2
        ld (ix+EVXL),e
        ret
.fromr: ld (ix+EX),PFW
        xor a
        sub e
        ld (ix+EVXL),a
        ld (ix+EVXH),0FFh
        ld a,(ix+ET)
        cp T_FISH
        ret nz
        ld (ix+ESP0),low SPR_FISHR
        ld (ix+ESP0+1),high SPR_FISHR
        ld (ix+ESP1),low SPR_FISHR
        ld (ix+ESP1+1),high SPR_FISHR
        ret
.n4:    cp T_SKULL
        jr nz,.n5
        ld (ix+EVYL),30h
        ret
.n5:    cp T_EYE
        jr nz,.n6
        ld (ix+EVYL),40h
        ret
.n6:    cp T_MINE
        jr nz,.n7
        ld (ix+EVYL),18h
        ld a,100
        call rand_n
        add a,110
        ld (ix+ETM),a
        jr .drift
.n7:    cp T_GUN
        jr nz,.n8
        ld (ix+EVYL),28h
        ret
.n8:    cp T_ROCK
        jr nz,.n9
        ld a,20h
        call rand_n
        add a,18h
        ld (ix+EVYL),a
.drift: ld a,30h                ; vx -18h .. 17h
        call rand_n
        sub 18h
        ld (ix+EVXL),a
        rla
        sbc a,a
        ld (ix+EVXH),a
        ret
.n9:    cp T_HEAVY
        ret nz
        ld (ix+EVYL),20h
        ld (ix+ETM),0
        ret

; ---------------------------------------------------------------------
enemies_tick:
        ld ix,ENEMY
        xor a
        ld (curid),a
.e:     ld a,(ix+ET)
        or a
        call nz,enemy_one
        ld de,ENSZ
        add ix,de
        ld a,(curid)
        inc a
        ld (curid),a
        cp MAXEN
        jr c,.e
        ret

enemy_one:
        call snd_clock
        ; behaviour
        ld a,(ix+ET)
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,entupd
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
        ld a,(ix+ET)
        or a
        ret z                   ; (gone)
        ; move
        ld l,(ix+EXL)
        ld h,(ix+EX)
        ld e,(ix+EVXL)
        ld d,(ix+EVXH)
        add hl,de
        ld (ix+EXL),l
        ld (ix+EX),h
        ld l,(ix+EYL)
        ld h,(ix+EY)
        ld e,(ix+EVYL)
        ld d,(ix+EVYH)
        add hl,de
        ld (ix+EYL),l
        ld (ix+EY),h
        bit 0,(ix+EFLG)         ; on the scenery: it scrolls too
        jr z,.ng
        ld a,(scrolled)
        add a,(ix+EY)
        ld (ix+EY),a
.ng:    ; gone off the screen?
        ld a,(ix+EY)
        cp PFH+1
        jr c,.iny
        cp -10
        jp c,en_remove          ; 26 .. 245: away
        ; above the top: only leaving if going up
        bit 7,(ix+EVYH)
        jr z,.iny
        cp -3
        jp c,en_remove
.iny:   ld a,(ix+EX)
        cp PFW+3
        jr c,.inx
        cp -5
        jp c,en_remove
.inx:   ; draw
        inc (ix+EAN)
        ld l,(ix+ESP0)
        ld h,(ix+ESP0+1)
        bit 3,(ix+EAN)
        jr z,.f0
        ld l,(ix+ESP1)
        ld h,(ix+ESP1+1)
.f0:    push hl
        pop iy
        xor a
        ld b,(ix+EFL)
        or b
        jr z,.nf
        dec (ix+EFL)
        ld a,1
.nf:    ld (sprflash),a
        ld b,(ix+EY)
        ld c,(ix+EX)
        ld a,(curid)
        inc a
        call draw_spr
        xor a
        ld (sprflash),a
        ret

jp_hl:  jp (hl)

; ---------------------------------------------------------------------
; IX = enemy, A = damage
en_hit:
        ld b,a
        ld a,(ix+ET)
        or a
        ret z
        ld a,(ix+EHP)
        sub b
        jr z,en_kill
        jr c,en_kill
        ld (ix+EHP),a
        ld (ix+EFL),2
        ld hl,SFX_HIT
        ld a,2
        jp sfx

; IX = enemy: destroyed by the player
en_kill:
        ld e,(ix+EPTS)
        ld d,(ix+EPTS+1)
        call add_score
        call en_centre          ; B = row, C = column
        push bc
        bit 1,(ix+EFLG)
        jr z,.small
        call big_burst
        ld hl,SFX_BOOM
        ld a,6
        call sfx
        jr .dr
.small: call explode
        ld hl,SFX_POP
        ld a,4
        call sfx
.dr:    pop bc
        ld a,(ix+EDROP)         ; a capsule or a medal
        or a
        jr z,.nd
        push bc
        call drop_item
        pop bc
        ld a,(ix+ET)
        cp T_HEAVY              ; the heavy drops a second one
        jr nz,.nd
        push bc
        ld a,IK_MED
        call drop_item
        pop bc
.nd:    ld a,(ix+ET)
        cp T_ROCK
        call z,rock_split
        ; the wave's book-keeping
        ld a,(ix+EWAVE)
        or a
        jr z,.free
        push bc
        call spawner_iy
        pop bc
        inc (iy+SPKILL)
        ld (iy+SPLX),c
        ld (iy+SPLY),b
        dec (iy+SPALIVE)
        ld a,(iy+SPN)
        or (iy+SPALIVE)
        jr nz,.free
        ld a,(iy+SPKILL)
        cp (iy+SPTOT)
        jr nz,.wdone
        cp 3
        jr c,.wdone
        call formation_bonus
.wdone: ld (iy+SPT),0
.free:  ld (ix+ET),0
        ret

; IX = enemy: left the screen (no credit)
en_remove:
        ld (ix+ET),0
        ld a,(ix+EWAVE)
        or a
        ret z
        call spawner_iy
        dec (iy+SPALIVE)
        ld a,(iy+SPN)
        or (iy+SPALIVE)
        ret nz
        ld (iy+SPT),0
        ret

; A = EWAVE (1-based) -> IY = spawner
spawner_iy:
        dec a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,high SPAWN
        push hl
        pop iy
        ret

; IY = spawner, B, C = where the last one died: every one of them shot
formation_bonus:
        push iy
        push ix
        ld de,0100h             ; 1000 points
        call add_score
        ld b,(iy+SPLY)
        ld c,(iy+SPLX)
        push bc
        ld a,IK_MED             ; and a medal
        call drop_item
        pop bc
        ld hl,txt_bonus
        call popup
        pop ix
        pop iy
        ret

; IX = enemy -> B = row, C = column of its centre
en_centre:
        ld a,(ix+EW)
        srl a
        add a,(ix+EX)
        ld c,a
        ld a,(ix+EH)
        srl a
        add a,(ix+EY)
        ld b,a
        ret

; B = row, C = column: a big rock breaks into 3 chips (IX kept)
rock_split:
        push ix
        ld hl,SFX_SPLIT
        ld a,5
        call sfx
        ld a,3
.s:     push af
        push bc
        ld a,T_ROCKS
        ld de,0
        call spawn_enemy
        jr c,.x
        ld a,40h
        call rand_n
        sub 20h
        ld (ix+EVXL),a
        rla
        sbc a,a
        ld (ix+EVXH),a
        ld a,30h
        call rand_n
        sub 8
        ld (ix+EVYL),a
        rla
        sbc a,a
        ld (ix+EVYH),a
.x:     pop bc
        pop af
        dec a
        jr nz,.s
        pop ix
        ret

; ---------------------------------------------------------------------
; behaviours (IX = enemy)
upd_none:
        ret

upd_dart:
        ld a,(ix+EPAR)          ; homing darts lean towards the ship
        or a
        jr z,.f
        ld a,(ix+EY)
        cp 12
        jr nc,.f
        call lean_x
.f:     ld a,(ix+EY)
        cp 3
        ret c
        cp 16
        ret nc
        jp fire_timer_once

upd_wasp:
        inc (ix+ETM)
        ld a,(ix+ETM)
        srl a
        and 31
        ld e,(ix+EPAR)          ; amplitude in columns
        sla e
        sla e
        sla e
        sla e
        call costab_at
        call smul
        sra a
        sra a
        sra a
        sra a
        add a,(ix+EX0)
        ld (ix+EX),a
        ld (ix+EXL),0
        jp fire_timer

upd_crab:
        ld a,(ix+EST)
        or a
        jr nz,.s1
        ld a,(ix+EY)
        cp (ix+EPAR)
        ret c
        ld (ix+EVYL),0
        ld (ix+EVXL),14h
        ld (ix+EST),1
        ld (ix+ETM),30
        ret
.s1:    cp 2
        ret z
        dec (ix+ETM)
        jr nz,.fire
        ld (ix+ETM),60
        xor a                   ; turn round
        sub (ix+EVXL)
        ld (ix+EVXL),a
        sbc a,a
        ld (ix+EVXH),a
        inc (ix+EAUX)
        ld a,(ix+EAUX)
        cp 5
        jr c,.fire
        ld (ix+EST),2           ; and leave
        ld (ix+EVYL),50h
        ld (ix+EVXL),0
        ld (ix+EVXH),0
.fire:  jp fire_timer

upd_bug:
        ld a,(ix+EVYL)          ; falls in an arc
        cp 60h
        jr nc,.f
        add a,3
        ld (ix+EVYL),a
.f:     ld a,(ix+EY)
        cp 14
        ret nc
        jp fire_timer_once

upd_skull:
        inc (ix+ETM)
        ld a,(ix+ETM)
        cp 160
        jr nc,.away
        call lean_x
        call lean_x
        ret
.away:  ld a,(ix+EVYL)
        cp 60h
        ret nc
        add a,4
        ld (ix+EVYL),a
        ret

upd_eye:
        ld a,(ix+EST)
        or a
        jr nz,.s1
        ld a,(ix+EY)
        cp (ix+EPAR)
        ret c
        ld (ix+EVYL),0
        ld (ix+EST),1
        ld (ix+ETM),20
        ld (ix+EAUX),3
        ret
.s1:    cp 2
        ret z
        dec (ix+ETM)
        ret nz
        ld (ix+ETM),35
        call en_centre
        ld a,3
        call fire_spread
        dec (ix+EAUX)
        ret nz
        ld (ix+EST),2           ; up and away
        ld (ix+EVYL),-30h
        ld (ix+EVYH),0FFh
        ret

upd_mine:
        dec (ix+ETM)
        ret nz
        ; time's up: a ring of 8 bullets, and gone
        call en_centre
        ld a,8
        call fire_ring
        call explode
        ld hl,SFX_EBIG
        ld a,3
        call sfx
        jp en_remove

upd_fish:
        ld a,(ix+EX)
        cp PFW
        ret nc
        dec (ix+EFT)
        ret nz
        ld a,50
        call rand_n
        add a,40
        ld (ix+EFT),a
        call en_centre
        inc b
        ld a,8                  ; straight down
        jp fire_dir

upd_ufo:
        ret

upd_gun:
        ld a,(ix+EST)
        or a
        jr nz,.s1
        ld a,(ix+EY)
        cp 4
        ret c
        ld (ix+EVYL),0
        ld (ix+EST),1
        ld (ix+ETM),160
        ld (ix+EFT),20
        ret
.s1:    cp 2
        ret z
        dec (ix+EFT)
        jr nz,.t
        ld (ix+EFT),45
        call en_centre
        inc b
        ld a,5
        call fire_fan
.t:     dec (ix+ETM)
        ret nz
        ld (ix+EST),2
        ld (ix+EVYL),30h
        ret

upd_rock:
        ret

upd_tur:
        ld a,(ix+EY)
        cp 1
        ret c
        cp 20
        ret nc
        dec (ix+EFT)
        ret nz
        ld a,60
        call rand_n
        add a,50
        ld (ix+EFT),a
        call en_centre
        jp fire_aimed

upd_heavy:
        ld a,(ix+EST)
        or a
        jr nz,.s1
        ld a,(ix+EY)
        cp 2
        ret c
        ld (ix+EVYL),0
        ld (ix+EST),1
        ld (ix+EFT),30
        ret
.s1:    cp 2
        ret z
        inc (ix+ETM)            ; sway
        ld a,(ix+ETM)
        srl a
        srl a
        and 31
        ld e,7Fh
        call costab_at
        call smul
        sra a
        sra a
        sra a
        sra a                   ; +-8 columns
        add a,(ix+EX0)
        ld (ix+EX),a
        dec (ix+EFT)
        jr nz,.t
        ld (ix+EFT),32
        call en_centre
        inc b
        inc (ix+EAUX)
        bit 0,(ix+EAUX)
        jr z,.ring
        ld a,5
        call fire_spread
        jr .t
.ring:  ld a,12
        call fire_ring
        ld hl,SFX_EBIG
        ld a,3
        call sfx
.t:     ld a,(ix+ETM)           ; leaves after a while
        cp 250
        ret c
        ld (ix+EST),2
        ld (ix+EVYL),20h
        ret

; A = costab[A] (HL kept)
costab_at:
        push hl
        ld hl,costab
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        pop hl
        ret

; steer vx towards the ship's column
lean_x:
        ld a,(px+1)
        sub (ix+EX)
        ld d,0
        jr z,.t
        ld d,30h
        jp p,.t
        ld d,-30h
.t:     ld a,(ix+EVXL)
        sub d
        ret z
        ld a,(ix+EVXL)
        jp m,.up
        sub 6
        jr .set
.up:    add a,6
.set:   ld (ix+EVXL),a
        rla
        sbc a,a
        ld (ix+EVXH),a
        ret

; fire when the fire timer runs out (and again later)
fire_timer:
        dec (ix+EFT)
        ret nz
        ld a,(firegap)
        call rand_n
        ld b,a
        ld a,(firegap)
        add a,b
        ld (ix+EFT),a
        jr fire_now
; the same, but only one shot
fire_timer_once:
        dec (ix+EFT)
        ret nz
        ld (ix+EFT),255
fire_now:
        ld a,(ix+EY)
        cp 1
        ret c
        cp 18
        ret nc
        call en_centre
        ; fall through
; B = row, C = column: one bullet at the ship
fire_aimed:
        call aim_dir
        ; fall through
; A = direction, B = row, C = column: one bullet
fire_dir:
        push af
        ld a,(bspd)
        ld e,a
        pop af
        ld d,1
        jp new_bullet

; A = direction to the ship from (B row, C column)
aim_dir:
        push bc
        ld a,(px+1)
        sub c
        ld d,a
        ld a,(py+1)
        inc a
        sub b
        ld c,a
        ld b,d
        call atan32
        pop bc
        ret

; A = 3 or 5: an aimed spread
fire_spread:
        ld (nfan),a
        call aim_dir
        ld d,a
        ld a,(nfan)
        dec a                   ; start at -(n-1)/2 * 2 directions
        neg
        add a,d
        and 31
        jr fan_go

; A = 3 or 5: a fan straight down
fire_fan:
        ld (nfan),a
        dec a
        neg
        add a,8
        and 31
fan_go: ld d,a
.l:     push bc
        push de
        ld a,d
        call fire_dir
        pop de
        pop bc
        ld a,d
        add a,2
        and 31
        ld d,a
        ld a,(nfan)
        dec a
        ld (nfan),a
        jr nz,.l
        ret

; A = 8 or 12 or 16: a ring of bullets
fire_ring:
        ld (nfan),a
        ld d,4                  ; step: 8 -> 4 directions
        cp 8
        jr z,.st
        ld d,2                  ; 16 -> 2
        cp 16
        jr z,.st
        ld d,3                  ; 12 -> 3 (11 directions round)
.st:    ld a,(ringrot)          ; a different start each time
        add a,1
        and 3
        ld (ringrot),a
        ld e,a
.l:     push bc
        push de
        ld a,e
        and 31
        push af
        ld a,(bspd)
        sub 10h
        ld e,a
        pop af
        ld d,2                  ; big bullets
        call new_bullet
        pop de
        pop bc
        ld a,e
        add a,d
        ld e,a
        ld a,(nfan)
        dec a
        ld (nfan),a
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; enemy bullets.  A = direction, E = speed, D = kind (1 small, 2 big),
; B = row, C = column.  (IX kept)
new_bullet:
        ld (nbdir),a
        ld a,b                  ; only from on the screen
        cp PFH
        ret nc
        ld a,c
        cp PFW
        ret nc
        ld a,(bombtm)           ; none while a bomb goes off
        or a
        ret nz
        ld hl,EBUL
        ld a,MAXEB
.f:     ex af,af'
        ld a,(hl)
        or a
        jr z,.got
        push de
        ld de,EBSZ
        add hl,de
        pop de
        ex af,af'
        dec a
        jr nz,.f
        ret
.got:   ld (hl),d               ; BT
        inc hl
        ld (hl),80h
        inc hl
        ld (hl),c
        inc hl
        ld (hl),80h
        inc hl
        ld (hl),b
        inc hl
        push hl
        ld a,(nbdir)
        call dir_vel            ; B = vx, C = vy
        pop hl
        ld (hl),b
        inc hl
        ld (hl),c
        ret

bullets_tick:
        ld ix,EBUL
        ld b,MAXEB
.b:     push bc
        ld a,(ix+BT)
        or a
        call nz,bullet_one
        ld de,EBSZ
        add ix,de
        pop bc
        djnz .b
        ret

bullet_one:
        ld a,(ix+BVX)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+BXL)
        ld h,(ix+BX)
        add hl,de
        ld (ix+BXL),l
        ld (ix+BX),h
        ld a,h
        cp PFW
        jr nc,.kill
        ld a,(ix+BVY)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+BYL)
        ld h,(ix+BY)
        add hl,de
        ld (ix+BYL),l
        ld (ix+BY),h
        ld a,h
        cp PFH
        jr nc,.kill
        ; the ship?
        ld b,h
        ld c,(ix+BX)
        ld a,(gstate)
        or a                    ; G_PLAY
        jr nz,.draw
        ld a,(px+1)
        cp c
        jr nz,.draw
        ld a,(py+1)
        cp b
        jr z,.hit
        inc a
        cp b
        jr nz,.draw
.hit:   ld a,(invuln)
        or a
        jr nz,.draw
        ld (ix+BT),0
        jp player_hit
.draw:  inc (ix+BAN)
        ld a,(ix+BT)
        cp 2
        ld d,86h                ; small: a little square, flickering red/yellow
        ld e,0A0h
        jr nz,.sm
        ld d,8Fh                ; big: a ball, magenta/white
        ld e,0B0h
.sm:    bit 1,(ix+BAN)
        jr z,.c
        ld a,e
        add a,40h
        ld e,a
.c:     xor a
        jp put_one
.kill:  ld (ix+BT),0
        ret

clear_bullets:
        ld hl,EBUL
        ld de,EBSZ
        ld b,MAXEB
.c:     ld a,(hl)
        or a
        jr z,.n
        ld (hl),0
        push hl
        push de
        push bc
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        inc hl
        ld b,(hl)
        call spark
        pop bc
        pop de
        pop hl
.n:     add hl,de
        djnz .c
        ret

; ---------------------------------------------------------------------
; wave spawners
; HL = event (type, count, x, dx, gap, param, drop)
start_wave:
        ld iy,SPAWN
        ld de,SPSZ
        ld b,MAXSP
.f:     ld a,(iy+SPT)
        or a
        jr z,.got
        add iy,de
        djnz .f
        ret
.got:   ld a,(hl)
        ld (iy+SPT),a
        inc hl
        ld a,(hl)
        ld (iy+SPN),a
        ld (iy+SPTOT),a
        inc hl
        ld a,(hl)
        ld (iy+SPX),a
        inc hl
        ld a,(hl)
        ld (iy+SPDX),a
        inc hl
        ld a,(hl)
        ld (iy+SPI),a
        inc hl
        ld a,(hl)
        ld (iy+SPP),a
        inc hl
        ld a,(hl)
        ld (iy+SPDR),a
        ld (iy+SPC),1
        ld (iy+SPALIVE),0
        ld (iy+SPKILL),0
        ret

spawners_tick:
        ld iy,SPAWN
        ld b,0
.s:     push bc
        ld a,(iy+SPT)
        or a
        jr z,.n
        ld a,(iy+SPN)
        or a
        jr z,.n
        dec (iy+SPC)
        jr nz,.n
        ld a,(iy+SPI)
        ld (iy+SPC),a
        pop bc
        push bc
        call spawn_one
.n:     ld de,SPSZ
        add iy,de
        pop bc
        inc b
        ld a,b
        cp MAXSP
        jr c,.s
        ret

; IY = spawner, B = its index
spawn_one:
        ld a,b
        inc a
        ld (spidx),a
        ld a,(iy+SPX)
        cp 0FFh
        jr nz,.x
        ld a,PFW-4
        call rand_n
        add a,2
.x:     ld c,a
        ld b,-2                 ; from above the top
        ld a,(iy+SPT)
        cp T_HEAVY
        jr nz,.y
        ld b,-3
.y:     ld e,(iy+SPP)
        ld d,0
        ld a,(iy+SPN)           ; the last of a wave of 1 carries the drop
        dec a
        jr nz,.nd
        ld d,(iy+SPDR)
.nd:    ld a,(iy+SPT)
        push iy
        call spawn_enemy
        pop iy
        jr c,.full
        ld a,(spidx)
        ld (ix+EWAVE),a
        inc (iy+SPALIVE)
.full:  dec (iy+SPN)
        ld a,(iy+SPX)
        cp 0FFh
        ret z
        add a,(iy+SPDX)
        ld (iy+SPX),a
        ret

; ---------------------------------------------------------------------
; items: capsules drift down, bobbing; medals fall faster
; A = kind, B = row, C = column
drop_item:
        ld e,a
        ld hl,ITEMS
        push bc
        ld bc,ITSZ
        ld d,MAXIT
.f:     ld a,(hl)
        or a
        jr z,.got
        add hl,bc
        dec d
        jr nz,.f
        pop bc
        ret
.got:   pop bc
        push hl
        pop iy
        ld (iy+IK),e
        ld (iy+IXL),80h
        ld a,c
        cp PFW-1
        jr c,.c
        ld a,PFW-2
.c:     ld (iy+IX_),a
        ld (iy+IYL),0
        ld a,b
        bit 7,a
        jr z,.r
        xor a
.r:     ld (iy+IY),a
        ld a,(framecnt)
        and 1
        ld a,10h
        jr z,.v
        ld a,-10h
.v:     ld (iy+IVX),a
        ld (iy+ITM),0
        ret

items_tick:
        ld iy,ITEMS
        ld b,MAXIT
.i:     push bc
        ld a,(iy+IK)
        or a
        call nz,item_one
        ld de,ITSZ
        add iy,de
        pop bc
        djnz .i
        ret

item_one:
        inc (iy+ITM)
        ld a,(iy+IK)            ; fall
        ld e,18h
        cp IK_MED
        jr nz,.f
        ld e,30h
.f:     ld a,(iy+IYL)
        add a,e
        ld (iy+IYL),a
        jr nc,.nr
        inc (iy+IY)
.nr:    ld a,(iy+IY)
        cp PFH
        jr c,.on
        ld a,(iy+IK)            ; fell off the bottom: a missed medal
        cp IK_MED
        jr nz,.gone
        xor a
        ld (medal),a
        ld a,1
        ld (hudmed),a
.gone:  ld (iy+IK),0
        ret
.on:    ld a,(iy+IVX)           ; bob from side to side
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(iy+IXL)
        ld h,(iy+IX_)
        add hl,de
        ld a,h
        cp PFW
        jr nc,.turn
        ld (iy+IXL),l
        ld (iy+IX_),h
        ld a,(iy+ITM)
        and 31
        jr nz,.col
.turn:  xor a
        sub (iy+IVX)
        ld (iy+IVX),a
.col:   ; the ship picks it up anywhere on its 3 x 2 cells
        ld a,(gstate)
        or a
        jr nz,.draw
        ld a,(iy+IY)
        ld hl,py+1
        sub (hl)
        cp 2
        jr nc,.draw
        ld a,(iy+IX_)
        ld hl,px+1
        sub (hl)
        inc a
        cp 3
        jr nc,.draw
        ld a,(iy+IK)
        ld (iy+IK),0
        jp collect
.draw:  ld a,(iy+IK)
        dec a
        add a,a
        ld hl,captab
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld d,(hl)
        inc hl
        ld e,(hl)
        ld a,(iy+ITM)           ; blink
        and 4
        jr z,.bl
        ld a,(iy+IK)
        cp IK_MED
        jr nz,.bl
        ld e,0F0h               ; medals glint white
.bl:    ld b,(iy+IY)
        ld c,(iy+IX_)
        xor a
        jp put_one

; A = item kind collected
collect:
        cp IK_MED
        jp z,got_medal
        push af
        ld hl,SFX_CAPS
        ld a,7
        call sfx
        ld a,1
        ld (hudpow),a
        ld de,0010h             ; 100 points for any capsule
        call add_score
        pop af
        cp IK_P
        jr nz,.v
.pow:   ld a,(power)
        cp 5
        jr nc,.max
        inc a
        ld (power),a
        ld hl,SFX_POWER
        ld a,8
        jp sfx
.max:   ld de,0100h             ; full power: 1000 points
        jp add_score
.v:     cp IK_V
        jr nz,.l
        ld a,(weapon)
        or a
        jr z,.pow
        xor a
        ld (weapon),a
        ret
.l:     cp IK_L
        jr nz,.o
        ld a,(weapon)
        or a
        jr nz,.pow
        ld a,1
        ld (weapon),a
        ret
.o:     cp IK_O
        jr nz,.s
        ld a,(options)
        cp 2
        jr nc,.max
        inc a
        ld (options),a
        ret
.s:     cp IK_S
        jr nz,.b
        ld a,(speed)
        cp 3
        jr nc,.max
        inc a
        ld (speed),a
        ret
.b:     cp IK_B
        jr nz,.h
        ld a,(bombs)
        cp 6
        jr nc,.max
        inc a
        ld (bombs),a
        ld a,1
        ld (hudbomb),a
        ret
.h:     cp IK_H
        jr nz,.u
        ld a,1
        ld (shield),a
        ret
.u:     jp extra_ship

; medals: each one caught is worth more (100 .. 10,000)
got_medal:
        ld a,(medal)
        add a,a
        ld l,a
        ld h,0
        ld de,medvals
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        call add_score
        pop hl
        ld a,(medal)            ; pop-up of the value
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,medtxt
        add hl,de
        call popup_ship
        ld a,(medal)
        cp 6
        jr nc,.m
        inc a
        ld (medal),a
.m:     ld a,1
        ld (hudmed),a
        ld hl,SFX_MEDAL
        ld a,6
        jp sfx

medvals: dw 0010h,0020h,0050h,0100h,0200h,0500h,1000h
medtxt:  db "100",0,0,0,0,0
         db "200",0,0,0,0,0
         db "500",0,0,0,0,0
         db "1000",0,0,0,0
         db "2000",0,0,0,0
         db "5000",0,0,0,0
         db "10000",0,0,0
txt_bonus: db "BONUS",0
