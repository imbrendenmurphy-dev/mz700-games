; =====================================================================
;  actors.asm - player and ghosts: movement, AI, collisions, scoring,
;  items, pop-ups and particles.
;
;  Every actor stands on a grid character; a speed accumulator (A_ACC)
;  decides on which frames it steps to the next one.  Directions:
;  0 right, 1 left, 2 up, 3 down (xor 1 reverses).
; =====================================================================
A_X     equ 0
A_Y     equ 1
A_DIR   equ 2
A_NEXT  equ 3
A_ACC   equ 4
A_PX    equ 5                       ; position at the start of the frame
A_PY    equ 6
A_ST    equ 7
A_ANIM  equ 8
A_ID    equ 9                       ; 0 player, 1-4 ghosts
A_TIM   equ 10
A_TX    equ 11
A_TY    equ 12
A_FLG   equ 13                      ; bit 0 stopped, bit 1 reverse due
ST_HOUSE equ 0
ST_EXIT  equ 1
ST_ACT   equ 2
ST_FRT   equ 3
ST_EYES  equ 4
ST_ENTER equ 5
PLAYER  equ actors
GHOST1  equ actors+16

; pop-up strings
P_100 equ 0
P_200 equ 1
P_300 equ 2
P_400 equ 3
P_500 equ 4
P_700 equ 5
P_800 equ 6
P_1000 equ 7
P_1600 equ 8
P_2000 equ 9
P_3200 equ 10
P_5000 equ 11
P_X2 equ 12
P_SPEED equ 13
P_FREEZE equ 14
P_DECOY equ 15
P_SHIELD equ 16
P_HUNT equ 17
P_PERFECT equ 18
P_STREAK equ 19
P_POP equ 20
P_250 equ 21
P_50 equ 22
P_BOO equ 23
P_EEK equ 24
P_ZZZ equ 25
P_WOW equ 26

popstr: dw s100,s200,s300,s400,s500,s700,s800,s1000,s1600,s2000,s3200,s5000
        dw sx2,sspeed,sfreeze,sdecoy,sshield,shunt,sperfect,sstreak,spop,s250,s50
        dw sboo,seek,szzz,swow
popval: dw 0100h,0200h,0300h,0400h,0500h,0700h,0800h,1000h,1600h,2000h,3200h,5000h
s100:   db "100",0
s200:   db "200",0
s300:   db "300",0
s400:   db "400",0
s500:   db "500",0
s700:   db "700",0
s800:   db "800",0
s1000:  db "1000",0
s1600:  db "1600",0
s2000:  db "2000",0
s3200:  db "3200",0
s5000:  db "5000",0
sx2:    db "X2!",0
sspeed: db "ZOOM!",0
sfreeze: db "BRRR!",0
sdecoy: db "DECOY",0
sshield: db "SHIELD",0
shunt:  db "HUNT!",0
sperfect: db "PERFECT",0
sstreak: db "STREAK",0
spop:   db "POP!",0
s250:   db "250",0
s50:    db "50",0
sboo:   db "BOO!",0
seek:   db "EEK!",0
szzz:   db "ZZZ",0
swow:   db "WOW!",0

; ---------------------------------------------------------------------
; move_actor: IX, A = speed (steps per frame * 256)
move_actor:
        add a,(ix+A_ACC)
        ld (ix+A_ACC),a
        ret nc
one_step:
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        ld a,(ix+A_ID)
        or a
        jr nz,.gh
        call player_choose
        ret c
        jr .go
.gh:    call ghost_choose
        ret c
.go:    res 0,(ix+A_FLG)
        ld b,(ix+A_X)
        ld c,(ix+A_Y)
        ld a,(ix+A_DIR)
        call neighbour
        ld (ix+A_X),b
        ld (ix+A_Y),c
        inc (ix+A_ANIM)
        ld a,(ix+A_ID)
        or a
        ret nz
        jp player_arrive

; ---------------------------------------------------------------------
; PLAYER
; choose a direction at B, C: NC = go (A_DIR set), C = blocked
player_choose:
        ld a,(demo)
        or a
        call nz,demo_ai
        ld a,(ix+A_NEXT)
        cp 0FFh
        jr z,.keep
        push bc
        call neighbour
        call passable
        pop bc
        jr nc,.keep
        ld a,(ix+A_NEXT)
        ld (ix+A_DIR),a
        or a
        ret
.keep:  ld a,(ix+A_DIR)
        push bc
        call neighbour
        call passable
        pop bc
        ccf
        ret nc
        set 0,(ix+A_FLG)
        scf
        ret

; arrived at B, C
player_arrive:
        call cell_at
        cp C_PELLET
        jr z,eat_pellet
        cp C_ENERG
        jr z,eat_energiser
        cp C_TELE
        jp z,teleport
        ret

eat_pellet:
        xor a
        call cell_set
        ld de,0010h
        call add_points
        call pellet_count
        ld a,(streaktim)
        or a
        jr z,.s0
        ld a,(streak)
        inc a
        ld (streak),a
        cp 60
        jr nz,.s1
        xor a
        ld (streak),a
        ld de,0500h
        call add_points
        ld a,P_STREAK
        call popup_at_player
        jr .s1
.s0:    xor a
        ld (streak),a
.s1:    ld a,40
        ld (streaktim),a
        ld a,(wakaflip)
        xor 1
        ld (wakaflip),a
        ld hl,SFX_WAKA1
        jr z,$+5
        ld hl,SFX_WAKA2
        ld a,1
        jp sfx

eat_energiser:
        xor a
        call cell_set
        ld de,0050h
        call add_points
        call pellet_count
        call frighten_all
        ld hl,SFX_POWER
        ld a,4
        jp sfx

pellet_count:
        ld hl,(pellets)
        dec hl
        ld (pellets),hl
        ld hl,(eaten)
        inc hl
        ld (eaten),hl
        ret

; teleporters come in diagonal pairs: partner = index xor 3
teleport:
        ld a,(ntele)
        cp 4
        ret c
        ld hl,tele_list
        ld e,0
.f:     ld a,(hl)
        cp b
        jr nz,.n
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr z,.found
.n:     inc hl
        inc hl
        inc e
        ld a,e
        cp 4
        jr nz,.f
        ret
.found: push de
        ld a,CYAN
        call burst
        pop de
        ld a,e
        xor 3
        add a,a
        ld e,a
        ld d,0
        ld hl,tele_list
        add hl,de
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld (ix+A_X),b
        ld (ix+A_Y),c
        ld a,YELLOW
        call burst
        ld hl,SFX_TELE
        ld a,3
        jp sfx

; ---------------------------------------------------------------------
; GHOSTS
; choose a direction at B, C: NC = go, C = stay (state changed)
ghost_choose:
        ld a,(ix+A_ST)
        cp ST_EYES
        jr nz,.ne
        ld a,b
        cp DOORX
        jr nz,.ne
        ld a,c
        cp EXITY
        jr nz,.ne
        ld (ix+A_ST),ST_ENTER
        scf
        ret
.ne:    bit 1,(ix+A_FLG)            ; reverse due?
        jr z,.nrev
        res 1,(ix+A_FLG)
        ld a,(ix+A_DIR)
        xor 1
        push bc
        call neighbour
        call passable
        pop bc
        jr nc,.nrev
        ld a,(ix+A_DIR)
        xor 1
        ld (ix+A_DIR),a
        or a
        ret
.nrev:  ld a,(ix+A_ST)
        cp ST_FRT
        jr z,.random
        ld a,(ix+A_ID)              ; DIZZY takes random turns
        cp 3
        jr nz,.tgt
        ld a,(ix+A_ST)
        cp ST_EYES
        jr z,.tgt
        call rand
        ld hl,dizzy_chance
        cp (hl)
        jr c,.random
.tgt:   push bc
        call ghost_target
        pop bc
        ld a,0FFh
        ld (best),a
        ld (bestd),a
        ld hl,dirorder
        ld a,4
.dl:    push af
        ld a,(hl)
        inc hl
        push hl
        ld d,a
        ld a,(ix+A_DIR)
        xor 1
        cp d
        jr z,.skip
        ld a,d
        push bc
        push de
        call neighbour
        call passable
        jr nc,.skip2
        ld a,b
        sub (ix+A_TX)
        jp p,.p1
        neg
.p1:    ld e,a
        ld a,c
        sub (ix+A_TY)
        jp p,.p2
        neg
.p2:    add a,e
        jr c,.skip2
        ld hl,bestd
        cp (hl)
        jr nc,.skip2
        ld (hl),a
        pop de
        push de
        ld a,d
        ld (best),a
.skip2: pop de
        pop bc
.skip:  pop hl
        pop af
        dec a
        jr nz,.dl
        ld a,(best)
        cp 0FFh
        jr nz,.set
        ld a,(ix+A_DIR)
        xor 1
.set:   ld (ix+A_DIR),a
        or a
        ret
.random:
        call rand
        and 3
        ld (best),a
        ld d,4
.r1:    push de
        ld a,(best)
        ld e,a
        ld a,(ix+A_DIR)
        xor 1
        cp e
        jr z,.r2
        ld a,e
        push bc
        call neighbour
        call passable
        pop bc
        jr c,.r3
.r2:    ld a,(best)
        inc a
        and 3
        ld (best),a
        pop de
        dec d
        jr nz,.r1
        ld a,(ix+A_DIR)
        xor 1
        ld (ix+A_DIR),a
        or a
        ret
.r3:    pop de
        ld a,(best)
        ld (ix+A_DIR),a
        or a
        ret

dirorder: db 2,1,3,0

; target for ghost IX -> A_TX, A_TY
ghost_target:
        ld a,(ix+A_ST)
        cp ST_EYES
        jr nz,.n1
        ld (ix+A_TX),DOORX
        ld (ix+A_TY),EXITY
        ret
.n1:    ld a,(decoytim)
        or a
        jr z,.n2
        ld a,(chasemode)
        or a
        jr z,.n2
        ld a,(decoyx)
        ld (ix+A_TX),a
        ld a,(decoyy)
        ld (ix+A_TY),a
        ret
.n2:    ld a,(ix+A_ID)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,scatter_t
        add hl,de
        ld a,(chasemode)
        or a
        jr nz,.chase
        ld a,(ix+A_ID)
        cp 1
        jr nz,.sc
        ld a,(elroy)                ; enraged GRUMBLE never scatters
        or a
        jr nz,.chase
.sc:    ld a,(hl)
        ld (ix+A_TX),a
        inc hl
        ld a,(hl)
        ld (ix+A_TY),a
        ret
.chase: ld a,(PLAYER+A_X)
        ld b,a
        ld a,(PLAYER+A_Y)
        ld c,a
        ld a,(PLAYER+A_DIR)
        ld (pdir_),a
        ld a,(ix+A_ID)
        cp 1
        jr z,.direct
        cp 2
        jr z,.ahead
        cp 3
        jr z,.dizzy
        ld a,4                      ; PEEKABOO: 2 * (player + 4 ahead) - GRUMBLE
        call ahead_n
        ld a,b
        add a,a
        ld b,a
        ld a,c
        add a,a
        ld c,a
        ld a,(GHOST1+A_X)
        ld d,a
        ld a,b
        sub d
        ld (ix+A_TX),a
        ld a,(GHOST1+A_Y)
        ld d,a
        ld a,c
        sub d
        ld (ix+A_TY),a
        ret
.direct:
        ld (ix+A_TX),b
        ld (ix+A_TY),c
        ret
.ahead: ld a,6                      ; SNEAKY: 6 ahead of the player
        call ahead_n
        jr .direct
.dizzy: ld a,b                      ; DIZZY: chase from afar, wander off when near
        sub (ix+A_X)
        jp p,.d1
        neg
.d1:    ld e,a
        ld a,c
        sub (ix+A_Y)
        jp p,.d2
        neg
.d2:    add a,e
        cp 12
        jr nc,.direct
        jr .sc

; B, C += A * direction (pdir_)
ahead_n:
        ld d,a
        ld a,(pdir_)
        and 3
        ld e,a
        push de
        ld d,0
        ld hl,dxtab
        add hl,de
        ld a,(hl)
        ld hl,dytab
        add hl,de
        ld l,(hl)
        ld h,a
        pop de
.ax:    ld a,b
        add a,h
        ld b,a
        ld a,c
        add a,l
        ld c,a
        dec d
        jr nz,.ax
        ret

scatter_t: db 40,-6, 0,-6, 0,26, 40,26

; one frame of ghost IX
ghost_update:
        ld a,(ix+A_ST)
        cp ST_HOUSE
        jr z,.house
        cp ST_EXIT
        jr z,.exit
        cp ST_ENTER
        jp z,.enter
        cp ST_EYES
        jr z,.eyes
        ld a,(freezetim)
        or a
        ret nz                      ; frozen solid
        call ghost_speed
        jp move_actor
.eyes:  ld a,160
        jp move_actor
.house: inc (ix+A_ANIM)
        ld a,(ix+A_ANIM)            ; look about
        and 31
        jr nz,.h1
        ld a,(ix+A_DIR)
        xor 1
        and 1
        ld (ix+A_DIR),a
.h1:    ld a,(roundtype)
        cp 2
        ret z                       ; pellet panic: they sleep
        ld a,(ix+A_TIM)
        or a
        jr z,.go
        dec (ix+A_TIM)
        ret
.go:    ld (ix+A_ST),ST_EXIT
        ret
.exit:  inc (ix+A_ANIM)
        ld a,(ix+A_ANIM)
        and 3
        ret nz
        ld a,(ix+A_X)
        cp DOORX
        jr z,.up
        jr c,.right
        dec (ix+A_X)
        ld (ix+A_DIR),1
        ret
.right: inc (ix+A_X)
        ld (ix+A_DIR),0
        ret
.up:    ld (ix+A_DIR),2
        dec (ix+A_Y)
        ld a,(ix+A_Y)
        cp EXITY
        ret nz
        ld (ix+A_ST),ST_ACT
        ld a,(roundtype)
        cp 1
        jr z,.fr
        ld a,(supertim)
        or a
        jr z,.nf
.fr:    ld (ix+A_ST),ST_FRT
.nf:    ld (ix+A_ACC),0
        call rand
        and 1
        ld (ix+A_DIR),a
        ret
.enter: inc (ix+A_ANIM)
        ld a,(ix+A_ANIM)
        and 1
        ret nz
        ld (ix+A_DIR),3
        ld (ix+A_X),DOORX
        inc (ix+A_Y)
        ld a,(ix+A_Y)
        cp HOUSEY
        ret nz
        ld (ix+A_ST),ST_HOUSE
        ld (ix+A_TIM),20
        ret

; speed of a roaming ghost -> A
ghost_speed:
        ld a,(ix+A_ST)
        cp ST_FRT
        jr nz,.n
        ld a,(fspeed)
        ret
.n:     ld a,(ix+A_Y)               ; tunnel slowdown
        cp HOUSEY
        jr nz,.nt
        ld a,(ix+A_X)
        cp 8
        jr c,.tun
        cp 33
        jr c,.nt
.tun:   ld a,37
        ret
.nt:    ld a,(gspeed)
        ld b,a
        ld a,(ix+A_ID)
        cp 1
        ld a,b
        ret nz
        ld a,(elroy)
        or a
        ld a,b
        ret z
        add a,8
        ret nc
        ld a,255
        ret

; energiser: frighten every roaming ghost
frighten_all:
        ld a,(roundtype)
        or a
        ret nz
        push ix
        call .go
        pop ix
        ret
.go:
        ld a,(frighttime)
        ld (frighttim),a
        ld (frightmax),a
        xor a
        ld (chain),a
        ld ix,GHOST1
        ld b,4
.l:     ld a,(ix+A_ST)
        cp ST_ACT
        jr z,.f
        cp ST_FRT
        jr nz,.n
.f:     ld (ix+A_ST),ST_FRT
        set 1,(ix+A_FLG)
.n:     ld de,16
        add ix,de
        djnz .l
        ld a,(palette)
        or a
        ret nz
        ld a,1
        jp set_palette

unfrighten_all:
        push ix
        call .go
        pop ix
        ret
.go:    ld ix,GHOST1
        ld b,4
.l:     ld a,(ix+A_ST)
        cp ST_FRT
        jr nz,.n
        ld (ix+A_ST),ST_ACT
.n:     ld de,16
        add ix,de
        djnz .l
        ld a,(roundtype)
        cp 1
        ret z
        xor a
        jp set_palette

; ---------------------------------------------------------------------
; scoring: DE = BCD points (doubled while x2 is running)
add_points:
        push de
        call .add
        pop de
        ld a,(x2tim)
        or a
        call nz,.add
        ld a,(hud_dirty)
        or 1
        ld (hud_dirty),a
        ld a,(extragiven)           ; extra life at 10,000
        or a
        ret nz
        ld a,(score)
        or a
        ret z
        ld a,1
        ld (extragiven),a
        ld a,3
        ld (hud_dirty),a
        ld hl,lives
        inc (hl)
        ld hl,SFX_LIFE
        ld a,5
        jp sfx
.add:   ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ret

; pop-up at the player: A = string index
popup_at_player:
        ld b,a
        ld a,(PLAYER+A_X)
        ld d,a
        ld a,(PLAYER+A_Y)
        ld e,a
        ld a,b
; pop-up: A = index, D = x, E = y (grid)
popup:
        push af
        ld hl,popups
        ld b,4
.f:     ld a,(hl)
        or a
        jr z,.got
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .f
        ld hl,popups
.got:   ld (hl),50
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        inc hl
        pop af
        ld (hl),a
        ret

; draw the pop-ups (and count them down)
draw_popups:
        ld hl,popups
        ld b,4
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        push hl
        push bc
        ld a,(hl)
        and 4
        ld a,WHITE*16
        jr z,$+4
        ld a,YELLOW*16
        ld (pop_attr),a
        inc hl
        ld d,(hl)                   ; x
        inc hl
        ld e,(hl)                   ; y
        inc hl
        ld a,(hl)                   ; string
        add a,a
        ld c,a
        ld b,0
        ld hl,popstr
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld b,0
.ln:    ld a,(hl)
        inc hl
        or a
        jr z,.le
        inc b
        jr .ln
.le:    pop hl                      ; B = length
        ld a,b
        srl a
        ld c,a
        ld a,d
        sub c
        jr c,.x0
        jr nz,.x1
.x0:    ld a,1
.x1:    ld c,a
        add a,b
        cp 41
        jr c,.x2
        ld a,40
        sub b
        ld c,a
.x2:    ld b,c
        ld a,e
        dec a
        jr nz,$+3
        inc a
        ld c,a
        ld a,(pop_attr)
        ld e,a
        call ovl_text
        pop bc
        pop hl
.n:     inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        ret

; ---------------------------------------------------------------------
; particles: 12 x 8 bytes: xlo, xhi, ylo, yhi (8.8 grid units), dx, dy
; (1/256 per frame), life, colour.   burst: B = x, C = y, A = colour
burst:
        ld (burstcol),a
        ld a,8
.l:     push af
        call find_pslot
        jr nc,.x
        push hl
        call rand
        and 7Fh
        sub 40h
        ld d,a
        call rand
        and 3Fh
        sub 20h
        ld e,a
        pop hl
        ld a,(burstcol)
        call put_particle
.x:     pop af
        dec a
        jr nz,.l
        ret

; trail dot: B = x, C = y, A = colour (stays put)
trail_dot:
        push af
        call find_pslot
        jr nc,.x
        ld de,0
        pop af
        jr put_particle
.x:     pop af
        ret

; HL = slot, B, C = position, D, E = velocity, A = colour
put_particle:
        ld (hl),80h
        inc hl
        ld (hl),b
        inc hl
        ld (hl),80h
        inc hl
        ld (hl),c
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        inc hl
        push af
        ld a,d
        or e
        ld a,14
        jr nz,$+4
        ld a,8
        ld (hl),a
        inc hl
        pop af
        ld (hl),a
        ret

; free particle slot -> HL, carry set if found.  Keeps BC.
find_pslot:
        push bc
        ld hl,particles+6
        ld de,8
        ld b,12
.f:     ld a,(hl)
        or a
        jr z,.got
        add hl,de
        djnz .f
        pop bc
        or a
        ret
.got:   ld de,-6
        add hl,de
        pop bc
        scf
        ret

clear_particles:
        ld hl,particles
        ld b,12*8
.c:     ld (hl),0
        inc hl
        djnz .c
        ld hl,popups
        ld b,16
.p:     ld (hl),0
        inc hl
        djnz .p
        ret

update_particles:
        ld ix,particles
        ld b,12
.l:     push bc
        ld a,(ix+6)
        or a
        jr z,.n
        dec (ix+6)
        jr z,.n
        ld a,(ix+4)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        ld a,h
        cp 41
        jr nc,.kill
        ld b,h
        ld a,(ix+5)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld a,h
        cp 21
        jr nc,.kill
        ld c,h
        ld a,(ix+7)
        rlca
        rlca
        rlca
        rlca
        ld e,a
        ld a,(ix+6)
        cp 9
        ld a,6Bh
        jr nc,$+4
        ld a,2Eh
        call ovl_grid
        jr .n
.kill:  ld (ix+6),0
.n:     ld de,8
        add ix,de
        pop bc
        djnz .l
        ret
