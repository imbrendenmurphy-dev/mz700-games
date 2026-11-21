; =====================================================================
;  boss.asm - the four bosses
;
;  W1 BIG BUMBLE   giant ladybird: walks, charges, crashes into the wall
;                  and sits dizzy - stomp it then.            3 hits
;  W2 MAGMA MOLE   pops out of the ground, spits fireballs; stomp or
;                  tongue it while it is out.                 4 hits
;  W3 PRISM PHANTOM floats and drops icicles; its colour cycles; it can
;                  only be hurt while Kiko is the same colour. 5 hits
;  W4 BARON GREYSCALE walks, jumps and throws sparks; his shield changes
;                  colour; match it to hurt him.              6 hits
; =====================================================================

BS_DYING        equ 99
OF_HIDE         equ 40h             ; not drawn, not touchable

boss_init:
        ld a,(world)
        ld (boss_kind),a
        ld e,a
        ld d,0
        ld hl,BOSS_HP
        add hl,de
        ld a,(hl)
        ld (ix+O_HP),a
        ld (boss_hpv),a
        ld (ix+O_TM),120
        ld (ix+O_ST),0
        ld (ix+O_SPD),10h
        ld a,(boss_kind)
        cp 1
        jr nz,.n1
        ld (ix+O_FL),OF_BOSS|OF_HIDE    ; mole starts underground
        ld (ix+O_TM),60
.n1:    cp 2
        jr nz,.n2
        ld (ix+O_COL),RED
        ld (ix+O_SPD),40h
.n2:    cp 3
        jr nz,.n3
        ld (ix+O_COL),RED
.n3:    ld a,1
        ld (boss_on),a
        jp boss_hud

BOSS_HP:        db 3, 4, 5, 6

; ---------------------------------------------------------------------
boss_update:
        ld a,(ix+O_ST)
        cp BS_DYING
        jp z,boss_dying
        ld a,(boss_kind)
        or a
        jp z,bb_update
        dec a
        jp z,mole_update
        dec a
        jp z,ph_update
        jp baron_update

; Kiko landed on top of the boss
boss_stomp:
        ld a,(boss_kind)
        or a
        jr nz,.n1
        ld a,(ix+O_ST)              ; ladybird: only while dizzy
        cp 3
        jr z,boss_hit_bb
        ld hl,SFX_BUMP
        ld a,2
        jp sfx
.n1:    cp 1
        jr z,boss_tongue            ; mole: stomp = tongue rules
        ; phantom / baron: colour must match
        call hero_colour
        cp (ix+O_COL)
        jp z,boss_hit
        ld hl,SFX_DENY
        ld a,2
        jp sfx

; the tongue touched the boss
boss_tongue:
        ld a,(boss_kind)
        or a
        jr nz,.n1
        ld (ix+O_FLASH),4
        ld hl,SFX_BUMP              ; ladybird shell: no effect
        ld a,2
        jp sfx
.n1:    cp 1
        jr nz,.n2
        ld a,(ix+O_ST)              ; mole: while out of the ground
        cp 2
        jp nz,.no
        call boss_hit
        ld a,(ix+O_ST)
        cp BS_DYING
        ret z
        ld (ix+O_ST),3              ; dive back down
        ld (ix+O_TM),0
        ret
.n2:    call hero_colour
        cp (ix+O_COL)
        jp z,boss_hit
.no:    ld hl,SFX_DENY
        ld a,2
        jp sfx

boss_hit_bb:
        call boss_hit
        ld a,(ix+O_ST)
        cp BS_DYING
        ret z
        ld (ix+O_ST),0              ; recover with a hop
        ld (ix+O_TM),80
        ld (ix+O_FL),OF_BOSS|OF_HARM
        ld (ix+O_VY),low -110
        ld (ix+O_VY+1),high -110
        ld (ix+O_GND),0
        ret

; take one hit (ignored while flashing)
boss_hit:
        ld a,(ix+O_FLASH)
        or a
        ret nz
        ld (ix+O_FLASH),40
        ld de,1000h
        call add_score
        ld hl,SFX_BOSSHIT
        ld a,4
        call sfx
        dec (ix+O_HP)
        ld a,(ix+O_HP)
        ld (boss_hpv),a
        call boss_hud
        ld a,(boss_hpv)
        or a
        ret nz
        ; defeated
        ld (ix+O_ST),BS_DYING
        ld (ix+O_TM),90
        ld (ix+O_FL),OF_BOSS        ; visible, harmless
        call mus_stop
        ld de,5000h
        jp add_score

boss_dying:
        ld a,(ix+O_TM)
        and 1
        add a,a
        add a,a
        ld (ix+O_FLASH),a
        ld a,(ix+O_TM)
        and 15
        jr nz,.t
        ld hl,SFX_BOOM
        ld a,4
        call sfx
.t:     dec (ix+O_TM)
        ret nz
        ; gone: leave the prism behind
        xor a
        ld (boss_on),a
        call boss_hud
        ld (ix+O_T),0
        push ix
        call obj_alloc
        jr c,.none
        ld a,OT_GOAL
        ld b,19
        ld c,17
        call obj_init
        ld hl,SFX_GOLDEN
        ld a,4
        call sfx
.none:  pop ix
        ret

; boss energy on the divider row (row 1, columns 30-39)
boss_hud:
        ld a,(hint_t)               ; the level hint is still showing
        or a
        ret nz
        ld de,HUDROW+40+29
        ld a,(boss_on)
        or a
        jr z,.clear
        ld hl,txt_boss
        ld c,74h
        call print
        ld b,6
        ld a,(boss_hpv)
        ld c,a
.l:     ld a,c
        or a
        ld a,43h                    ; block per hit left
        jr nz,.on
        ld a,36h
.on:    push bc
        ld c,24h
        jr nz,.p
        ld c,40h
.p:     call putc
        pop bc
        inc de
        ld a,c
        or a
        jr z,$+3
        dec c
        djnz .l
        ret
.clear: ld b,11
.c:     ld a,36h
        ld c,40h
        call putc
        inc de
        djnz .c
        ret

txt_boss:       db "BOSS",0

; spawn a shot from the boss toward Kiko: B = x, C = y
boss_shoot:
        push ix
        push bc
        call obj_face_hero
        ld (spit_dir),a
        call obj_alloc
        pop bc
        jr c,.none
        ld a,OT_SHOT
        call obj_init
        ld a,(spit_dir)
        ld (ix+O_DIR),a
        ld hl,SFX_SHOOT
        ld a,1
        call sfx
.none:  pop ix
        ret

; frame for a boss: DE = byte offset (0 / 2) in its set, by direction
boss_frame:
        jp obj_frame_n0

; ---------------------------------------------------------------------
; W1: Big Bumble
; ---------------------------------------------------------------------
bb_update:
        ld a,(ix+O_GND)
        or a
        jr nz,.gnd
        ld a,12
        call obj_move_v
        jr .st
.gnd:   ld a,(ix+O_VY+1)
        or a
        jr nz,.st
        call obj_supported
        jr nz,.st
        ld (ix+O_GND),0
.st:    ld a,(ix+O_ST)
        or a
        jr nz,.s1
        ; walk toward Kiko
        call obj_frame_std
        ld a,(ix+O_AN)
        and 31
        jr nz,.w
        call obj_face_hero
        ld (ix+O_DIR),a
.w:     ld a,(ix+O_HP)              ; faster as it gets angrier
        cp 2
        ld a,10h
        jr nc,$+4
        ld a,18h
        ld (ix+O_SPD),a
        xor a
        call obj_walk
        dec (ix+O_TM)
        ret nz
        ld (ix+O_ST),1
        ld (ix+O_TM),40
        ret
.s1:    cp 1
        jr nz,.s2
        ; wind up: shake, face Kiko
        call obj_face_hero
        ld (ix+O_DIR),a
        ld de,0
        call boss_frame
        ld a,(ix+O_TM)
        and 4
        ld (ix+O_FLASH),a
        dec (ix+O_TM)
        ret nz
        ld (ix+O_ST),2
        ld (ix+O_SPD),60h
        ld hl,SFX_SPRING
        ld a,2
        jp sfx
.s2:    cp 2
        jr nz,.s3
        ; charge until it hits a wall
        call obj_frame_std
        ld a,(ix+O_DIR)
        ld (bb_dir),a
        xor a
        call obj_walk
        ld a,(ix+O_DIR)
        ld hl,bb_dir
        cp (hl)
        ret z
        ld a,(hl)
        ld (ix+O_DIR),a
        ld (ix+O_ST),3
        ld (ix+O_TM),110
        ld (ix+O_FL),OF_BOSS|OF_STOMP
        ld hl,SFX_BOOM
        ld a,3
        jp sfx
.s3:    ; dizzy
        ld a,(ix+O_DIR)
        or a
        ld hl,FR_BB_DIZZY_R
        jr z,$+5
        ld hl,FR_BB_DIZZY_L
        ld (ix+O_FR),l
        ld (ix+O_FR+1),h
        dec (ix+O_TM)
        ret nz
        ld (ix+O_ST),0
        ld (ix+O_TM),100
        ld (ix+O_FL),OF_BOSS|OF_HARM
        ret

; ---------------------------------------------------------------------
; W2: Magma Mole.  O_HY = the row it stands on when out of the ground.
; ---------------------------------------------------------------------
MOLE_X:         db 5, 18, 31, 11, 25

mole_update:
        ld a,(ix+O_ST)
        or a
        jr nz,.s1
        ; underground
        dec (ix+O_TM)
        ret nz
        call rand
        and 7
        cp 5
        jr c,$+4
        sub 3
        ld e,a
        ld d,0
        ld hl,MOLE_X
        add hl,de
        ld a,(hl)
        ld (ix+O_X),a
        ld a,(ix+O_HY)
        add a,3
        ld (ix+O_Y),a
        ld (ix+O_ST),1
        ld (ix+O_TM),6
        ld (ix+O_FL),OF_BOSS
        ld hl,SFX_CRUMBLE
        ld a,2
        jp sfx
.s1:    cp 1
        jr nz,.s2
        ld de,2
        call boss_frame
        dec (ix+O_TM)
        ret nz
        ld (ix+O_TM),6
        dec (ix+O_Y)
        ld a,(ix+O_Y)
        cp (ix+O_HY)
        ret nz
        ld (ix+O_ST),2
        ld (ix+O_TM),110
        ld (ix+O_FL),OF_BOSS|OF_HARM|OF_STOMP
        ret
.s2:    cp 2
        jr nz,.s3
        call obj_face_hero
        ld (ix+O_DIR),a
        ld de,0
        call boss_frame
        ld a,(ix+O_TM)
        cp 75
        jr z,.fire
        cp 40
        jr z,.fire
.t2:    dec (ix+O_TM)
        ret nz
        ld (ix+O_ST),3
        ld (ix+O_TM),6
        ret
.fire:  ld a,(ix+O_DIR)
        or a
        ld a,(ix+O_X)
        jr nz,.fl
        add a,4
        jr .fs
.fl:    dec a
.fs:    ld b,a
        ld a,(ix+O_Y)
        dec a
        ld c,a
        call boss_shoot
        jr .t2
.s3:    ; sinking
        ld (ix+O_FL),OF_BOSS
        ld de,2
        call boss_frame
        dec (ix+O_TM)
        ret nz
        ld (ix+O_TM),6
        inc (ix+O_Y)
        ld a,(ix+O_HY)
        add a,3
        cp (ix+O_Y)
        ret nz
        ld (ix+O_ST),0
        ld a,(ix+O_HP)              ; less rest when hurt
        add a,a
        add a,a
        add a,a
        add a,30
        ld (ix+O_TM),a
        ld (ix+O_FL),OF_BOSS|OF_HIDE
        ret

; ---------------------------------------------------------------------
; W3: Prism Phantom
; ---------------------------------------------------------------------
PH_COLS:        db RED, GREEN, BLUE

ph_update:
        ld a,(ix+O_AN)
        rrca
        rrca
        rrca
        and 2
        ld e,a
        ld d,0
        call obj_frame_n
        ; drift side to side
        ld a,(ix+O_AN)
        and 3
        jr nz,.bob
        ld a,(ix+O_DIR)
        or a
        jr nz,.l
        ld a,(ix+O_X)
        cp 33
        jr nc,.turn
        inc (ix+O_X)
        jr .bob
.l:     ld a,(ix+O_X)
        cp 2
        jr c,.turn
        dec (ix+O_X)
        jr .bob
.turn:  ld a,(ix+O_DIR)
        xor 1
        ld (ix+O_DIR),a
.bob:   ld a,(ix+O_AN)
        rrca
        rrca
        rrca
        rrca
        and 3
        cp 3
        jr nz,$+4
        ld a,1
        add a,(ix+O_HY)
        ld (ix+O_Y),a
        ; colour cycle: warn by flashing for the last 30 frames
        ld a,(ix+O_FLASH)           ; a hit flash wins over the warning
        cp 5
        jr nc,.nw
        ld a,(ix+O_TM)
        cp 30
        jr nc,.nw
        and 4
        ld (ix+O_FLASH),a
.nw:    dec (ix+O_TM)
        jr nz,.harm
        ld a,(ix+O_HP)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,70
        ld (ix+O_TM),a
        ld a,(ix+O_P1)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (ix+O_P1),a
        ld e,a
        ld d,0
        ld hl,PH_COLS
        add hl,de
        ld a,(hl)
        ld (ix+O_COL),a
        ld hl,SFX_SWAP
        ld a,1
        call sfx
.harm:  ; harmless while Kiko wears its colour
        call hero_colour
        cp (ix+O_COL)
        ld a,OF_BOSS
        jr z,$+4
        ld a,OF_BOSS|OF_HARM
        ld (ix+O_FL),a
        ; drop an icicle now and then
        ld a,(ix+O_AN)
        and 127
        cp 64
        ret nz
        push ix
        ld a,(ix+O_X)
        add a,2
        ld b,a
        ld a,(ix+O_Y)
        inc a
        ld c,a
        call obj_alloc
        jr c,.none
        ld a,OT_DROPPER
        call obj_init
        ld (ix+O_ST),2
.none:  pop ix
        ret

; ---------------------------------------------------------------------
; W4: Baron Greyscale
; ---------------------------------------------------------------------
baron_update:
        ld a,(ix+O_GND)
        or a
        jr nz,.g
        ld a,12
        call obj_move_v
        jr .walk
.g:     call obj_supported
        jr nz,.walk
        ld (ix+O_GND),0
.walk:  call obj_frame_std
        ld a,(ix+O_AN)
        and 15
        jr nz,.w
        call obj_face_hero
        ld (ix+O_DIR),a
.w:     ld a,(ix+O_HP)
        cp 4
        ld a,14h
        jr nc,$+4
        ld a,1Ch
        ld (ix+O_SPD),a
        xor a
        call obj_walk
        ; shield colour
        ld a,(ix+O_FLASH)           ; a hit flash wins over the warning
        cp 5
        jr nc,.nw
        ld a,(ix+O_TM)
        cp 30
        jr nc,.nw
        and 4
        ld (ix+O_FLASH),a
.nw:    dec (ix+O_TM)
        jr nz,.act
        ld a,(ix+O_HP)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,60
        ld (ix+O_TM),a
        ld a,(ix+O_P1)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (ix+O_P1),a
        ld e,a
        ld d,0
        ld hl,PH_COLS
        add hl,de
        ld a,(hl)
        ld (ix+O_COL),a
.act:   ; hop toward Kiko, throw sparks
        ld a,(ix+O_AN)
        cp 128
        jr nz,.nj
        ld a,(ix+O_GND)
        or a
        jr z,.nj
        ld (ix+O_VY),low -140
        ld (ix+O_VY+1),high -140
        ld (ix+O_GND),0
.nj:    ld a,(ix+O_FLASH)           ; no sparks while reeling from a hit
        cp 5
        ret nc
        ld a,(ix+O_AN)
        and 63
        cp 32
        ret nz
        ld a,(ix+O_DIR)
        or a
        ld a,(ix+O_X)
        jr nz,.sl
        add a,5
        jr .ss
.sl:    dec a
.ss:    ld b,a
        ld a,(ix+O_Y)
        sub 2
        ld c,a
        jp boss_shoot
