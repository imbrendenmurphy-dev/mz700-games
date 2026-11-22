; =====================================================================
;  fight.asm - the fighters: input, state machines, moves, hits
;
;  Two player records (IY): positions in 1/16 cell, the ground row is
;  GROUND; P_Y is the height above it in 1/16 row.  All logic runs at
;  25 frames a second.
; =====================================================================

PL1     equ 0E00h
PL2     equ 0E80h
; player record
P_ID    equ 0       ; fighter number
P_X     equ 1       ; word: x in 1/16 cell (anchor column = x / 16)
P_Y     equ 3       ; height in 1/16 row
P_VX    equ 4       ; signed, 1/16 cell per frame
P_VY    equ 5       ; signed, 1/16 row per frame (negative = up)
P_FACE  equ 6       ; 0 faces right, 1 faces left
P_ST    equ 7       ; state
P_T     equ 8       ; frames in state
P_FR    equ 9       ; pose (frame number)
P_HP    equ 10      ; health 0..HPMAX
P_MV    equ 11      ; current move
P_HITD  equ 12      ; the move has connected
P_STUN  equ 13      ; frames of hit/block stun left
P_IN    equ 14      ; inputs this frame: IN_* bits (absolute)
P_INP   equ 15      ; last frame's
P_NEW   equ 16      ; newly pressed
P_REL   equ 17      ; this frame's direction relative to facing (R_* bits)
P_HIST  equ 18      ; 16 frames of P_REL
P_HI    equ 34      ; history index
P_FLASH equ 35      ; hit flash frames
P_WINS  equ 36      ; rounds won
P_CPU   equ 37      ; 1 = computer controlled
P_OBJ   equ 38      ; low byte of the object slot
P_DICT  equ 39      ; dictionary page
P_XLAT  equ 40      ; palette page
P_PROJ  equ 41      ; projectile: 0 none, else frames alive
P_PX    equ 42      ; word: projectile x (1/16 cell)
P_PVX   equ 44      ; projectile speed
P_PRW   equ 45      ; projectile row (up from ground)
P_AIT   equ 46      ; AI: frames until the next decision
P_AIS   equ 47      ; AI: held input
P_COMBO equ 48      ; hits in the current combo
P_SC    equ 49      ; word: score / 10
P_FB    equ 51      ; word: box table
P_FF    equ 53      ; word: frame pointer table
P_INFO  equ 55      ; word: fighter info
P_MASH  equ 57      ; punch presses in the last frames (flurry)
P_MASHT equ 58
P_KO    equ 59      ; knocked out
P_PUSH  equ 60      ; knockback speed (signed, decays)
P_THROWN equ 61     ; frames being thrown
P_SPEC  equ 62      ; special move being performed (for AI and sfx)
P_DMGT  equ 63      ; total damage taken (for "perfect")
P_SPA   equ 64      ; special A move number
P_SPB   equ 65      ; special B move number
P_MOTB  equ 66      ; motion for special B: 0 QCB+K, 1 DP+P
P_SPD   equ 67      ; walk speed
P_PWR   equ 68      ; extra damage
P_PART  equ 69      ; word: projectile art (2 frames x 2 facings)
PSZ     equ 128

; inputs
IN_U    equ 0
IN_D    equ 1
IN_L    equ 2
IN_R    equ 3
IN_P    equ 4
IN_K    equ 5
; relative directions
R_U     equ 1
R_D     equ 2
R_B     equ 4
R_F     equ 8

; states
ST_STAND equ 0
ST_CROUCH equ 1
ST_JUMP equ 2
ST_ATK  equ 3
ST_HIT  equ 4
ST_BLOCK equ 5
ST_FALL equ 6
ST_DOWN equ 7
ST_GETUP equ 8
ST_WIN  equ 9
ST_KO   equ 10
ST_THROWN equ 11
ST_INTRO equ 12

GROUND  equ 22
HPMAX   equ 136
XMIN    equ 3*16
XMAX    equ 37*16
MINDIST equ 6*16        ; closest the anchors get when both stand

; move table entries (moves:, MVSZ bytes each)
MV_START equ 0
MV_ACT  equ 1
MV_REC  equ 2
MV_FS   equ 3           ; pose in startup
MV_FA   equ 4           ; pose when active
MV_FR   equ 5           ; pose in recovery
MV_DMG  equ 6
MV_FL   equ 7           ; flags
MV_STUN equ 8           ; hitstun
MV_PUSH equ 9           ; knockback speed
MV_VX   equ 10          ; own speed while active
MV_VY   equ 11          ; launch (uppercut)
MV_SFX  equ 12
MVSZ    equ 16
F_LOW   equ 1
F_HIGH  equ 2           ; overhead: stand to block
F_KD    equ 4           ; knockdown
F_SPEC  equ 8           ; special: chip damage
F_PROJ  equ 16          ; spawns a projectile at the first active frame
F_INV   equ 32          ; invincible during startup
F_AIR   equ 64          ; jump attack
F_THROW equ 128

M_JAB   equ 0
M_KICK  equ 1
M_CPUNCH equ 2
M_SWEEP equ 3
M_JATK  equ 4
M_THROW equ 5
M_FIRE  equ 6
M_UPPER equ 7
M_SPIN  equ 8
M_RUSH  equ 9
M_FLURRY equ 10
M_DIVE  equ 11

moves:
;          start act rec  fs        fa        fr        dmg flags              stun push vx  vy  sfx
        db 2,    2,  3,   FR_WALK1,  FR_PUNCH, FR_STANCE, 6,  0,             8,   6,   0,  0,  SFX_WHOOSH, 0,0,0
        db 3,    3,  5,   FR_WALK1,  FR_KICK,  FR_WALK1,  10, 0,              10,  9,   0,  0,  SFX_WHOOSH2,0,0,0
        db 2,    2,  3,   FR_CROUCH, FR_CPUNCH, FR_CROUCH, 5, 0,              7,   5,   0,  0,  SFX_WHOOSH, 0,0,0
        db 4,    3,  8,   FR_CROUCH, FR_SWEEP, FR_CROUCH, 10, F_LOW+F_KD,     12,  8,   0,  0,  SFX_WHOOSH2,0,0,0
        db 1,    40, 0,   FR_JKICK,  FR_JKICK, FR_JUMP,   10, F_HIGH+F_AIR,   10,  7,   0,  0,  SFX_WHOOSH2,0,0,0
        db 1,    2,  10,  FR_PUNCH,  FR_PUNCH, FR_STANCE, 16, F_THROW+F_KD,   0,   20,  0,  0,  SFX_GRAB,   0,0,0
        db 5,    1,  10,  FR_SPEC_A, FR_SPEC_A, FR_SPEC_A, 10, F_SPEC+F_PROJ, 12,  9,   0,  0,  SFX_FIRE,   0,0,0
        db 1,    6,  10,  FR_SPEC_B, FR_SPEC_B, FR_JUMP,  14, F_SPEC+F_KD+F_INV, 14, 10, 4, -14, SFX_UPPER, 0,0,0
        db 3,    12, 6,   FR_JUMP,   FR_JKICK, FR_JUMP,   12, F_SPEC+F_KD,    12,  10,  9,  0,  SFX_SPIN,   0,0,0
        db 4,    8,  8,   FR_CROUCH, FR_PUNCH, FR_STANCE, 13, F_SPEC+F_KD,   12,  10,  13, 0,  SFX_RUSH,   0,0,0
        db 1,    10, 6,   FR_SPEC_A, FR_PUNCH, FR_STANCE, 3,  F_SPEC,        6,   3,   0,  0,  SFX_FLURRY, 0,0,0
        db 3,    14, 8,   FR_JUMP,   FR_JKICK, FR_JUMP,   12, F_SPEC+F_KD+F_HIGH, 12, 10, 10, -8, SFX_SPIN, 0,0,0

; ---------------------------------------------------------------- setup
; player_init: IY = player, A = fighter number, B = 0 for P1 / 1 for P2
player_init:
        push bc
        push iy
        pop hl
        ld e,l
        ld d,h
        inc de
        ld (hl),0
        push bc
        ld bc,PSZ-1
        ldir
        pop bc
        ld (iy+P_ID),a
        ld (iy+P_HP),HPMAX
        ; fighter record: dict, frames, boxes, info
        add a,a
        ld l,a
        ld h,0
        ld de,ftr_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        inc hl
        inc hl
        ld a,(hl)
        ld (iy+P_FF),a
        inc hl
        ld a,(hl)
        ld (iy+P_FF+1),a
        inc hl
        ld a,(hl)
        ld (iy+P_FB),a
        inc hl
        ld a,(hl)
        ld (iy+P_FB+1),a
        inc hl
        ld a,(hl)
        ld (iy+P_INFO),a
        inc hl
        ld a,(hl)
        ld (iy+P_INFO+1),a
        ; info: special A, special B, motion B, speed, power, projectile art
        ld l,(iy+P_INFO)
        ld h,(iy+P_INFO+1)
        ld a,(hl)
        ld (iy+P_SPA),a
        inc hl
        ld a,(hl)
        ld (iy+P_SPB),a
        inc hl
        ld a,(hl)
        ld (iy+P_MOTB),a
        inc hl
        ld a,(hl)
        ld (iy+P_SPD),a
        inc hl
        ld a,(hl)
        ld (iy+P_PWR),a
        inc hl
        ld a,(hl)
        ld (iy+P_PART),a
        inc hl
        ld a,(hl)
        ld (iy+P_PART+1),a
        pop bc
        ld a,b
        or a
        jr nz,.p2
        ld (iy+P_OBJ),low OBJ
        ld (iy+P_DICT),high DICT1
        ld (iy+P_XLAT),high XLAT1
        ld hl,12*16
        ld (iy+P_FACE),0
        jr .pos
.p2:    ld (iy+P_OBJ),low (OBJ+OBJSZ)
        ld (iy+P_DICT),high DICT2
        ld (iy+P_XLAT),high XLAT2
        ld hl,28*16
        ld (iy+P_FACE),1
.pos:   ld (iy+P_X),l
        ld (iy+P_X+1),h
        ld (iy+P_ST),ST_INTRO
        ld (iy+P_FR),FR_STANCE
        ret

; round_reset: both players to their marks, full health
round_reset:
        ld iy,PL1
        ld hl,12*16
        ld (iy+P_FACE),0
        call .one
        ld iy,PL2
        ld hl,28*16
        ld (iy+P_FACE),1
.one:   ld (iy+P_X),l
        ld (iy+P_X+1),h
        xor a
        ld (iy+P_Y),a
        ld (iy+P_VX),a
        ld (iy+P_VY),a
        ld (iy+P_T),a
        ld (iy+P_STUN),a
        ld (iy+P_PROJ),a
        ld (iy+P_FLASH),a
        ld (iy+P_KO),a
        ld (iy+P_PUSH),a
        ld (iy+P_COMBO),a
        ld (iy+P_DMGT),a
        ld (iy+P_THROWN),a
        ld (iy+P_ST),ST_INTRO
        ld (iy+P_FR),FR_STANCE
        ld (iy+P_HP),HPMAX
        ret

; ---------------------------------------------------------------- input
; read_inputs: fills P_IN / P_NEW for both players (keys, or the AI)
read_inputs:
        ld iy,PL1
        ld a,(iy+P_CPU)
        or a
        jr nz,.c1
        ld hl,keys_p1
        ld a,(two_players)
        or a
        jr z,.k1
        ld hl,keys_p1b
.k1:    call keys_read
        ld hl,joy_in1
        or (hl)
        jr .s1
.c1:    call ai_think
.s1:    call input_store
        ld iy,PL2
        ld a,(iy+P_CPU)
        or a
        jr nz,.c2
        ld hl,keys_p2
        call keys_read
        ld hl,joy_in2
        or (hl)
        jr .s2
.c2:    call ai_think
.s2:    jp input_store

; keys_read: HL = key list (code per IN_ bit, 0FFh = none; two lists of 6
; for alternatives) -> A = input bits
keys_read:
        ld c,0
        ld b,12
        ld e,1
.k:     ld a,(hl)
        inc hl
        cp 0FFh
        jr z,.n
        call key_held
        jr z,.n
        ld a,c
        or e
        ld c,a
.n:     rlc e
        ld a,e
        cp 40h
        jr nz,.nx
        ld e,1
.nx:    djnz .k
        ld a,c
        ret

; input_store: A = absolute input bits -> P_IN, P_NEW, P_REL, history
input_store:
        ld (iy+P_IN),a
        ld c,a
        ld a,(iy+P_INP)
        cpl
        and c
        ld (iy+P_NEW),a
        ld (iy+P_INP),c
        ; relative direction
        ld a,c
        and 3                   ; U, D
        ld b,a
        bit IN_L,c
        jr z,.nl
        ld a,(iy+P_FACE)
        or a
        ld a,R_B
        jr z,$+4
        ld a,R_F
        or b
        ld b,a
.nl:    bit IN_R,c
        jr z,.nr
        ld a,(iy+P_FACE)
        or a
        ld a,R_F
        jr z,$+4
        ld a,R_B
        or b
        ld b,a
.nr:    ld (iy+P_REL),b
        ; history ring
        ld a,(iy+P_HI)
        inc a
        and 15
        ld (iy+P_HI),a
        push iy
        pop hl
        add a,P_HIST
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),b
        ; punch mashing
        ld a,(iy+P_MASHT)
        or a
        jr z,.m0
        dec (iy+P_MASHT)
        jr nz,.m1
.m0:    ld (iy+P_MASH),0
.m1:    bit IN_P,(iy+P_NEW)
        ret z
        inc (iy+P_MASH)
        ld (iy+P_MASHT),9
        ret

; motion: HL = pattern (relative dir masks, newest last, 0 ends), searched
; backwards through the last 12 frames of history.  Z if found.
; An element matches a history entry when the entry equals it exactly.
motion:
        ; find the end of the pattern
        ld b,0
.e:     ld a,(hl)
        or a
        jr z,.ee
        inc hl
        inc b
        jr .e
.ee:    dec hl                  ; HL = last element, B = count
        ld c,12                 ; frames to look back
        ld a,(iy+P_HI)
        ld e,a
.l:     push hl
        push iy
        pop hl
        ld a,e
        add a,P_HIST
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)               ; history entry
        pop hl
        cp (hl)
        jr nz,.no
        dec hl
        dec b
        ret z                   ; all matched: Z
.no:    ld a,e
        dec a
        and 15
        ld e,a
        dec c
        jr nz,.l
        or 1                    ; NZ
        ret

pat_qcf: db R_D, R_D+R_F, R_F, 0
pat_qcb: db R_D, R_D+R_B, R_B, 0
pat_dp:  db R_F, R_D, R_D+R_F, 0

; ---------------------------------------------------------------- update
; update_player: IY = player, IX = opponent
update_player:
        inc (iy+P_T)
        ld a,(iy+P_FLASH)
        or a
        jr z,$+5
        dec (iy+P_FLASH)
        ld a,(iy+P_ST)
        add a,a
        ld l,a
        ld h,0
        ld de,st_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

st_tab: dw st_stand, st_crouch, st_jump, st_atk, st_hit, st_block, st_fall, st_down
        dw st_getup, st_win, st_ko, st_thrown, st_intro

set_state:
        ld (iy+P_ST),a
        ld (iy+P_T),0
        ret

st_intro:
        ld (iy+P_FR),FR_STANCE
        ret

; face the opponent (only when on the ground and free)
face_opp:
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        ld e,(ix+P_X)
        ld d,(ix+P_X+1)
        or a
        sbc hl,de
        ret z
        ld a,0
        jr c,$+4
        ld a,1
        ld (iy+P_FACE),a
        ret

; dir_fwd: Z clear if holding forward etc.
; free actions shared by stand / crouch: specials, attacks, jumps.
; Returns NZ (and has changed state) if something started.
try_actions:
        ld a,(iy+P_NEW)
        and (1<<IN_P)+(1<<IN_K)
        jp z,.nobtn
        ; specials first
        bit IN_P,(iy+P_NEW)
        jr z,.notp
        ld a,(iy+P_MOTB)
        cp 1
        jr nz,.nodp
        ld hl,pat_dp
        call motion
        jr nz,.nodp
        ld a,(iy+P_SPB)
        jp start_move
.nodp:  ld hl,pat_qcf
        call motion
        jr nz,.noqcf
        ld a,(iy+P_SPA)
        cp M_FIRE
        jr nz,.go
        ld a,(iy+P_PROJ)        ; one projectile at a time
        or a
        jr nz,.noqcf
        ld a,M_FIRE
.go:    jp start_move
.noqcf: ld a,(iy+P_SPA)
        cp M_FLURRY
        jr nz,.notp
        ld a,(iy+P_MASH)
        cp 3
        jr c,.notp
        ld (iy+P_MASH),0
        ld a,M_FLURRY
        jp start_move
.notp:  bit IN_K,(iy+P_NEW)
        jr z,.nok
        ld a,(iy+P_MOTB)
        or a
        jr nz,.nok
        ld hl,pat_qcb
        call motion
        jr nz,.nok
        ld a,(iy+P_SPB)
        jp start_move
.nok:   ; throw: close, toward, punch
        bit IN_P,(iy+P_NEW)
        jr z,.nothrow
        bit 3,(iy+P_REL)        ; R_F
        jr z,.nothrow
        call distance
        cp MINDIST/16+2
        jr nc,.nothrow
        ld a,(ix+P_Y)
        or a
        jr nz,.nothrow
        ld a,(ix+P_ST)
        cp ST_STAND
        jr z,.th
        cp ST_CROUCH
        jr nz,.nothrow
.th:    ld a,M_THROW
        jp start_move
.nothrow:
        ; plain attacks
        bit 1,(iy+P_REL)        ; crouching?
        jr nz,.low
        bit IN_P,(iy+P_NEW)
        ld a,M_JAB
        jp nz,start_move
        ld a,M_KICK
        jp start_move
.low:   bit IN_P,(iy+P_NEW)
        ld a,M_CPUNCH
        jp nz,start_move
        ld a,M_SWEEP
        jp start_move
.nobtn: ; jump
        bit 0,(iy+P_REL)
        jr z,.nojump
        ld (iy+P_VY),-13
        ld a,(iy+P_REL)
        ld b,0
        bit 3,a
        jr z,$+4
        ld b,5
        bit 2,a
        jr z,$+4
        ld b,-5
        ld a,(iy+P_FACE)
        or a
        ld a,b
        jr z,$+4
        neg
        ld (iy+P_VX),a
        ld (iy+P_FR),FR_JUMP
        ld a,SFX_JUMP
        call sfx_play
        ld a,ST_JUMP
        call set_state
        or 1
        ret
.nojump:
        xor a
        ret

; start_move: A = move number
start_move:
        ld (iy+P_MV),a
        ld (iy+P_HITD),0
        call move_ptr
        ld a,(hl)               ; MV_START
        ld (iy+P_STUN),a        ; (reused as phase timer)
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (iy+P_FR),a
        ld a,ST_ATK
        call set_state
        ; air moves keep the jump; specials set their speed later
        ld (iy+P_VX),0
        ld a,(iy+P_MV)
        cp M_JATK
        jr nz,.g
.g:     ld a,(iy+P_MV)
        ld (iy+P_SPEC),a
        or 1
        ret

; HL = this player's current move entry
move_ptr:
        ld a,(iy+P_MV)
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,moves
        add hl,de
        ret

; A = |x1 - x2| in cells
distance:
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        ld e,(ix+P_X)
        ld d,(ix+P_X+1)
        or a
        sbc hl,de
        jr nc,.p
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.p:     ld a,l
        srl h
        rra
        srl h
        rra
        srl h
        rra
        srl h
        rra
        ret

; is the player holding back (away from the opponent)?  NZ if so
holding_back:
        bit 2,(iy+P_REL)
        ret

st_stand:
        call face_opp
        call try_actions
        ret nz
        bit 1,(iy+P_REL)
        jr z,.walk
        ld a,ST_CROUCH
        call set_state
        ld (iy+P_FR),FR_CROUCH
        ret
.walk:  ld b,0
        bit 3,(iy+P_REL)
        jr z,$+5
        ld b,(iy+P_SPD)
        bit 2,(iy+P_REL)
        jr z,.nb
        ld a,(iy+P_SPD)
        srl a
        srl a
        neg
        add a,(iy+P_SPD)        ; backing off at 3/4 speed
        neg
        ld b,a
.nb:    ld a,(iy+P_FACE)
        or a
        ld a,b
        jr z,$+4
        neg
        ld (iy+P_VX),a
        push bc
        call move_x
        pop bc
        ld a,b
        or a
        jr z,.idle
        ; walk cycle: stance, walk1, stance2, walk2 every 3 frames
        ld a,(iy+P_T)
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,walk_poses
        add hl,de
        ld a,(hl)
        ld (iy+P_FR),a
        ret
.idle:  ld (iy+P_FR),FR_STANCE
        ret
walk_poses: db FR_WALK1, FR_STANCE, FR_WALK2, FR_STANCE

st_crouch:
        call face_opp
        ld (iy+P_VX),0
        bit 1,(iy+P_REL)
        jr nz,.stay
        ld a,ST_STAND
        call set_state
        ld (iy+P_FR),FR_STANCE
        jp st_stand             ; (a button pressed as down is let go counts)
.stay:  ld (iy+P_FR),FR_CROUCH
        bit 2,(iy+P_REL)
        jr z,.nb
        ld (iy+P_FR),FR_CBLOCK  ; crouch guard shown when holding back
.nb:    call try_actions
        ret

st_jump:
        ; jump attacks
        ld a,(iy+P_NEW)
        and (1<<IN_P)+(1<<IN_K)
        jr z,.fly
        ld a,(iy+P_HITD)
        or a
        jr nz,.fly
        ld (iy+P_MV),M_JATK
        ld (iy+P_FR),FR_JKICK
        ld (iy+P_HITD),2        ; 2 = attacking, not yet connected
        ld a,SFX_WHOOSH2
        call sfx_play
.fly:   call air_move
        ret nc                  ; still in the air
        ; landed
        ld (iy+P_HITD),0
        ld (iy+P_VX),0
        ld a,ST_STAND
        call set_state
        ld (iy+P_FR),FR_CROUCH
        ld a,SFX_LAND
        jp sfx_play

; air_move: apply VX/VY and gravity; C set when landed
air_move:
        call move_x
        ld a,(iy+P_VY)
        ld b,a
        ld a,(iy+P_Y)
        sub b                   ; y -= vy (vy negative = rising)
        jr c,.land
        bit 7,b
        jr nz,.up               ; rising: no underflow possible
        ; falling: if y went "up" past 255 that is a wrap; treat as landing
.up:    ld (iy+P_Y),a
        inc (iy+P_VY)           ; gravity
        ld a,(iy+P_VY)
        cp 16
        jr c,$+5
        ld (iy+P_VY),15
        or a
        ret
.land:  ld (iy+P_Y),0
        ld (iy+P_VY),0
        scf
        ret

; move_x: x += vx (signed), clamped to the walls
move_x:
        ld a,(iy+P_VX)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        add hl,de
clamp_x:
        ld de,XMIN
        or a
        push hl
        sbc hl,de
        pop hl
        jr nc,.lo
        ld hl,XMIN
.lo:    ld de,XMAX
        or a
        push hl
        sbc hl,de
        pop hl
        jr c,.hi
        ld hl,XMAX
.hi:    ld (iy+P_X),l
        ld (iy+P_X+1),h
        ret

st_atk:
        call move_ptr
        push hl
        pop ix                  ; IX = move (opponent restored below)
        ld a,(iy+P_T)
        ld b,(ix+MV_START)
        cp b
        jr c,.startup
        jr z,.first
        sub b
        cp (ix+MV_ACT)
        jr c,.active
        sub (ix+MV_ACT)
        cp (ix+MV_REC)
        jp nc,.done
        ; recovery
        ld a,(ix+MV_FR)
        ld (iy+P_FR),a
        ld (iy+P_VX),0
        jr .air
.startup:
        ld a,(ix+MV_FS)
        ld (iy+P_FR),a
        jr .air
.first: ; the first active frame: sound, launches, projectiles
        ld a,(ix+MV_SFX)
        call sfx_play
        ld a,(ix+MV_VY)
        or a
        jr z,.novy
        ld (iy+P_VY),a
.novy:  bit 4,(ix+MV_FL)
        call nz,spawn_proj
.active:
        ld a,(ix+MV_FA)
        ld (iy+P_FR),a
        ; flurry and spin alternate poses
        ld a,(iy+P_MV)
        cp M_FLURRY
        jr nz,.nf
        ld a,(iy+P_T)
        and 1
        ld a,FR_PUNCH
        jr z,$+4
        ld a,FR_SPEC_A
        ld (iy+P_FR),a
        ld (iy+P_HITD),0        ; every other frame may hit again
        ld a,(iy+P_T)
        and 1
        jr z,.nf
        ld (iy+P_HITD),1
.nf:    ld a,(iy+P_MV)
        cp M_SPIN
        jr nz,.ns
        ld a,(iy+P_T)
        and 2
        ld a,FR_JKICK
        jr z,$+4
        ld a,FR_SPEC_B
        ld (iy+P_FR),a
.ns:    ld a,(ix+MV_VX)
        ld b,a
        ld a,(iy+P_FACE)
        or a
        ld a,b
        jr z,$+4
        neg
        ld (iy+P_VX),a
.air:   ; moves that leave the ground fall back to it
        ld a,(iy+P_Y)
        or (iy+P_VY)
        jr z,.ground
        call air_move
        jr nc,.ret
        ld (iy+P_VX),0
        ld a,(iy+P_MV)
        cp M_SPIN
        jr z,.ret
        cp M_DIVE
        jr z,.done
        jr .ret
.ground:
        call move_x
.ret:   jp restore_ix
.done:  ld (iy+P_VX),0
        ld a,(iy+P_Y)
        or a
        jr z,.std
        ; still airborne after the move: fall as a jump
        ld (iy+P_HITD),1
        ld a,ST_JUMP
        call set_state
        ld (iy+P_FR),FR_JUMP
        jp restore_ix
.std:   ld a,ST_STAND
        call set_state
        ld (iy+P_FR),FR_STANCE
restore_ix:
        ld ix,PL1
        ld a,iyl
        cp low PL1
        ret nz
        ld ix,PL2
        ret

st_hit:
        ld (iy+P_FR),FR_HIT
        call knockback
        dec (iy+P_STUN)
        ret nz
        ld (iy+P_COMBO),0
        ld a,ST_STAND
        call set_state
        ld (iy+P_FR),FR_STANCE
        ret

st_block:
        call knockback
        dec (iy+P_STUN)
        ret nz
        ld a,ST_STAND
        bit 1,(iy+P_REL)
        jr z,.s
        ld a,ST_CROUCH
.s:     jp set_state

; knockback: slide by P_PUSH (decays); pushes the attacker if at the wall
knockback:
        ld a,(iy+P_PUSH)
        or a
        ret z
        ld b,a
        ld a,(iy+P_FACE)
        or a
        ld a,b
        jr nz,$+4
        neg                     ; facing right: pushed left
        ld (iy+P_VX),a
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        push hl
        call move_x
        pop de
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        or a
        sbc hl,de
        jr nz,.moved
        ; at the wall: the attacker recoils instead (if on the ground)
        ld a,(ix+P_Y)
        or a
        jr nz,.moved
        push iy
        push ix
        pop iy
        ld a,(iy+P_VX)
        push af
        ld a,b
        ld c,a
        ld a,(iy+P_FACE)
        or a
        ld a,c
        jr z,$+4
        neg
        neg
        ld (iy+P_VX),a
        call move_x
        pop af
        ld (iy+P_VX),a
        pop iy
.moved: ld (iy+P_VX),0
        ld a,(iy+P_PUSH)
        sub 2
        jr nc,$+3
        xor a
        ld (iy+P_PUSH),a
        ret

st_fall:
        ld (iy+P_FR),FR_FALL
        call air_move
        ret nc
        ld a,SFX_THUD
        call sfx_play
        ld (iy+P_VX),0
        ld a,ST_DOWN
        call set_state
        ld (iy+P_FR),FR_DOWN
        ret

st_down:
        ld (iy+P_FR),FR_DOWN
        ld a,(iy+P_KO)
        or a
        jr z,.n
        ld a,ST_KO
        jp set_state
.n:     ld a,(iy+P_T)
        cp 18
        ret c
        ld a,ST_GETUP
        call set_state
        ld (iy+P_FR),FR_CROUCH
        ret

st_getup:
        ld (iy+P_FR),FR_CROUCH
        ld a,(iy+P_T)
        cp 5
        ret c
        ld (iy+P_COMBO),0
        ld a,ST_STAND
        call set_state
        ld (iy+P_FR),FR_STANCE
        ret

st_win:
        ld (iy+P_VX),0
        ld a,(iy+P_T)
        cp 10
        ld a,FR_STANCE
        jr c,$+4
        ld a,FR_WIN
        ld (iy+P_FR),a
        ld a,(iy+P_Y)
        or a
        ret z
        jp air_move

st_ko:
        ld (iy+P_FR),FR_DOWN
        ret

st_thrown:
        ; carried over the thrower's head, then dropped behind
        ld a,(iy+P_T)
        cp 6
        jr nc,.drop
        ld (iy+P_FR),FR_FALL
        ret
.drop:  ld (iy+P_VY),-6
        ld a,(iy+P_FACE)
        or a
        ld a,-8
        jr nz,$+4
        ld a,8
        neg
        ld (iy+P_VX),a
        ld (iy+P_Y),16
        ld a,ST_FALL
        jp set_state

; ---------------------------------------------------------------- projectiles
spawn_proj:
        ld a,(iy+P_PROJ)
        or a
        ret nz
        ld (iy+P_PROJ),1
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        ld de,3*16
        ld a,(iy+P_FACE)
        or a
        jr z,.r
        ld de,-4*16
.r:     add hl,de
        ld (iy+P_PX),l
        ld (iy+P_PX+1),h
        ld a,(iy+P_FACE)
        or a
        ld a,9
        jr z,$+4
        ld a,-9
        ld (iy+P_PVX),a
        ld (iy+P_PRW),8
        ret

; move_proj: IY = owner
move_proj:
        ld a,(iy+P_PROJ)
        or a
        ret z
        inc (iy+P_PROJ)
        ld a,(iy+P_PVX)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(iy+P_PX)
        ld h,(iy+P_PX+1)
        add hl,de
        ld (iy+P_PX),l
        ld (iy+P_PX+1),h
        ; off screen?
        bit 7,h
        jr nz,.gone
        ld de,42*16
        or a
        sbc hl,de
        ret c
.gone:  ld (iy+P_PROJ),0
        ret

; ---------------------------------------------------------------- hits
; check_hits: IY attacker, IX defender
check_hits:
        call proj_hit
        ld a,(iy+P_ST)
        cp ST_ATK
        jr z,.atk
        cp ST_JUMP
        ret nz
        ld a,(iy+P_HITD)
        cp 2
        ret nz                  ; not attacking in the air
        ld (iy+P_MV),M_JATK
        jr .test
.atk:   ld a,(iy+P_HITD)
        or a
        ret nz
        ; in the active window?
        push ix
        call move_ptr
        push hl
        pop ix
        ld a,(iy+P_T)
        sub (ix+MV_START)
        jr c,.no
        cp (ix+MV_ACT)
        jr nc,.no
        pop ix
        jr .test
.no:    pop ix
        ret
.test:  ; attacker's hit box in world cells
        ld a,(iy+P_FR)
        call box_ptr_iy         ; HL = box entry (hurt 4, hit 4)
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        cp 80h
        ret z
        call world_box          ; -> hb_x0, hb_x1, hb_y0, hb_y1 (attacker)
        ld hl,hb_x0
        ld de,ab_x0
        ld bc,4
        ldir
        ; defender's hurt box
        ld a,(ix+P_ST)
        cp ST_DOWN
        ret z
        cp ST_KO
        ret z
        cp ST_FALL
        jr nz,.nf
        ld a,(iy+P_MV)          ; only rising specials juggle
        cp M_UPPER
        ret nz
.nf:    ld a,(ix+P_ST)
        cp ST_THROWN
        ret z
        ; invincible?
        cp ST_ATK
        jr nz,.ninv
        push ix
        push iy
        push ix
        pop iy
        call move_ptr
        push hl
        pop ix
        ld a,(iy+P_T)
        cp (ix+MV_START)
        ld a,0
        jr nc,.vul
        bit 5,(ix+MV_FL)
        jr z,.vul
        inc a
.vul:   pop iy
        pop ix
        or a
        ret nz
.ninv:  push iy
        push ix
        pop iy
        ld a,(iy+P_FR)
        call box_ptr_iy
        ld a,(hl)
        cp 80h
        jr z,.nohurt
        call world_box
        pop iy
        ; overlap?
        ld a,(ab_x1)
        ld hl,hb_x0
        call scmp               ; ab_x1 < hb_x0 -> miss
        ret c
        ld a,(hb_x1)
        ld hl,ab_x0
        call scmp
        ret c
        ld a,(ab_y1)
        ld hl,hb_y0
        call scmp
        ret c
        ld a,(hb_y1)
        ld hl,ab_y0
        call scmp
        ret c
        jp connect
.nohurt:
        pop iy
        ret

; signed compare: C if A < (HL)
scmp:   xor 80h
        ld b,a
        ld a,(hl)
        xor 80h
        ld c,a
        ld a,b
        cp c
        ret

; HL = box entry of pose A for player IY
box_ptr_iy:
        add a,a
        add a,a
        add a,a                 ; *8
        ld e,a
        ld d,0
        ld l,(iy+P_FB)
        ld h,(iy+P_FB+1)
        add hl,de
        ret

; world_box: HL = 4 box bytes (x0,x1,y0,y1 relative) of player IY ->
; hb_x0..hb_y1 in world cells (x = column, y = rows up from the ground)
world_box:
        ld a,(iy+P_X)
        ld b,(iy+P_X+1)
        srl b
        rra
        srl b
        rra
        srl b
        rra
        srl b
        rra
        ld c,a                  ; C = anchor column
        ld a,(iy+P_FACE)
        or a
        jr nz,.mir
        ld a,(hl)
        add a,c
        ld (hb_x0),a
        inc hl
        ld a,(hl)
        add a,c
        ld (hb_x1),a
        inc hl
        jr .y
.mir:   dec c
        ld a,c
        inc hl
        sub (hl)
        ld (hb_x0),a            ; col-1-x1
        dec hl
        ld a,c
        sub (hl)
        ld (hb_x1),a            ; col-1-x0
        inc hl
        inc hl
.y:     ld a,(iy+P_Y)
        add a,8
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        ld c,a
        ld a,(iy+P_Y)
        cp 0F8h
        jr c,$+4
        ld c,0
        ld a,(hl)
        add a,c
        ld (hb_y0),a
        inc hl
        ld a,(hl)
        add a,c
        ld (hb_y1),a
        ret

; connect: IY's attack hits IX (maybe blocked)
connect:
        ld a,(iy+P_ST)
        cp ST_JUMP
        jr nz,.g
        ld (iy+P_HITD),1
        jr .mv
.g:     ld (iy+P_HITD),1
.mv:    call move_ptr
        push hl
        pop hl
        ld (cur_move),hl
        ; throws can't be blocked
        push hl
        pop de
        ld hl,MV_FL
        add hl,de
        bit 7,(hl)
        jr nz,.throw
        ; block?  defender standing / crouching / blocking, holding back
        ld a,(ix+P_ST)
        cp ST_STAND
        jr z,.cb
        cp ST_CROUCH
        jr z,.cb
        cp ST_BLOCK
        jr nz,.hit
.cb:    bit 2,(ix+P_REL)
        jr z,.hit
        ; height: low must be crouch-blocked, overhead stand-blocked
        ld b,(hl)               ; flags
        bit 1,(ix+P_REL)        ; crouching?
        jr nz,.cr
        bit 0,b
        jr nz,.hit
        jr .blocked
.cr:    bit 1,b
        jr nz,.hit
.blocked:
        jp do_block
.throw: jp do_throw
.hit:   jp do_hit

do_block:
        ld hl,(cur_move)
        ld de,MV_FL
        add hl,de
        bit 3,(hl)
        jr z,.nochip
        ld a,(ix+P_HP)          ; chip damage
        sub 2
        jr nc,$+3
        xor a
        ld (ix+P_HP),a
        or a
        jr nz,.nochip
        jp do_hit               ; chipped out: a real KO
.nochip:
        push ix
        push iy
        push ix
        pop iy
        ld a,ST_BLOCK
        call set_state
        pop iy
        pop ix
        ld (ix+P_STUN),6
        ld (ix+P_PUSH),8
        ld a,FR_BLOCK
        bit 1,(ix+P_REL)
        jr z,$+4
        ld a,FR_CBLOCK
        ld (ix+P_FR),a
        ld a,SFX_BLOCK
        call sfx_play
        ld a,1
        jp spark

do_throw:
        push ix
        push iy
        push ix
        pop iy
        ld a,ST_THROWN
        call set_state
        pop iy
        pop ix
        ; face the thrower, take damage
        ld a,(iy+P_FACE)
        xor 1
        ld (ix+P_FACE),a
        ld a,16
        call take_damage
        ld a,SFX_GRAB
        call sfx_play
        ret

do_hit:
        ld hl,(cur_move)
        ld de,MV_DMG
        add hl,de
        ld a,(hl)
        add a,(iy+P_PWR)
        ; combo scaling: later hits in a combo do less
        ld b,a
        ld a,(ix+P_COMBO)
        cp 2
        jr c,.ns
        srl b
        ld a,b
        srl a
        add a,b
        ld b,a                  ; 3/4
.ns:    ld a,b
        call take_damage
        inc (ix+P_COMBO)
        ld (ix+P_FLASH),3
        ; score: damage * 10 (kept as /10)
        ld hl,(cur_move)
        ld de,MV_DMG
        add hl,de
        ld e,(hl)
        ld d,0
        ld l,(iy+P_SC)
        ld h,(iy+P_SC+1)
        add hl,de
        add hl,de
        ld (iy+P_SC),l
        ld (iy+P_SC+1),h
        ld hl,(cur_move)
        ld de,MV_STUN
        add hl,de
        ld a,(hl)
        ld (ix+P_STUN),a
        inc hl
        ld a,(hl)
        ld (ix+P_PUSH),a
        ld a,SFX_HIT
        call sfx_play
        xor a
        call spark
        ; knockdown, air hit or KO -> fall
        ld hl,(cur_move)
        ld de,MV_FL
        add hl,de
        bit 2,(hl)
        jr nz,.fall
        ld a,(ix+P_Y)
        or a
        jr nz,.fall
        ld a,(ix+P_HP)
        or a
        jr z,.fall
        push ix
        push iy
        push ix
        pop iy
        ld a,ST_HIT
        call set_state
        pop iy
        pop ix
        ld (ix+P_FR),FR_HIT
        ret
.fall:  push ix
        push iy
        push ix
        pop iy
        ld a,ST_FALL
        call set_state
        ld (iy+P_VY),-9
        ld a,(iy+P_Y)
        or a
        jr nz,$+6
        ld (iy+P_Y),2
        ld a,(iy+P_FACE)
        or a
        ld a,-6
        jr z,$+4
        ld a,6
        ld (iy+P_VX),a
        ld (iy+P_PUSH),0
        pop iy
        pop ix
        ret

; take_damage: A = damage to IX; sets P_KO at 0
take_damage:
        ld b,a
        ld a,(ix+P_DMGT)
        add a,b
        jr nc,$+4
        ld a,255
        ld (ix+P_DMGT),a
        ld a,(ix+P_HP)
        sub b
        jr nc,.ok
        xor a
.ok:    ld (ix+P_HP),a
        or a
        ret nz
        ld (ix+P_KO),1
        ret

; proj_hit: IY's projectile against IX (and against IX's projectile)
proj_hit:
        ld a,(iy+P_PROJ)
        or a
        ret z
        ; projectile column
        ld l,(iy+P_PX)
        ld h,(iy+P_PX+1)
        call x_col
        ld c,a
        ; clash with the other projectile
        ld a,(ix+P_PROJ)
        or a
        jr z,.nc
        push bc
        ld l,(ix+P_PX)
        ld h,(ix+P_PX+1)
        call x_col
        pop bc
        sub c
        jr nc,$+4
        neg
        cp 3
        jr nc,.nc
        ld (iy+P_PROJ),0
        ld (ix+P_PROJ),0
        ld a,SFX_BLOCK
        call sfx_play
        ret
.nc:    ; defender hurt box
        ld a,(ix+P_ST)
        cp ST_DOWN
        ret z
        cp ST_KO
        ret z
        cp ST_FALL
        ret z
        cp ST_THROWN
        ret z
        push bc
        push iy
        push ix
        pop iy
        ld a,(iy+P_FR)
        call box_ptr_iy
        ld a,(hl)
        cp 80h
        jr z,.miss
        call world_box
        pop iy
        pop bc
        ; projectile occupies columns c-1..c+1, rows PRW-1..PRW
        ld a,c
        inc a
        ld (ab_x1),a
        sub 2
        ld (ab_x0),a
        ld a,(iy+P_PRW)
        ld (ab_y1),a
        dec a
        ld (ab_y0),a
        ld a,(ab_x1)
        ld hl,hb_x0
        call scmp
        ret c
        ld a,(hb_x1)
        ld hl,ab_x0
        call scmp
        ret c
        ld a,(ab_y1)
        ld hl,hb_y0
        call scmp
        ret c
        ld a,(hb_y1)
        ld hl,ab_y0
        call scmp
        ret c
        ; hit: the projectile is spent
        ld (iy+P_PROJ),0
        ld hl,moves+M_FIRE*MVSZ
        ld (cur_move),hl
        ld a,(ix+P_ST)
        cp ST_STAND
        jr z,.cb
        cp ST_CROUCH
        jr z,.cb
        cp ST_BLOCK
        jr nz,.h
.cb:    bit 2,(ix+P_REL)
        jp nz,do_block
.h:     jp do_hit
.miss:  pop iy
        pop bc
        ret

; HL = x in 1/16 cells -> A = column
x_col:  ld a,l
        srl h
        rra
        srl h
        rra
        srl h
        rra
        srl h
        rra
        ret

; spark: A = 0 hit / 1 block, at the middle of the overlap
spark:
        ld (sp_kind),a
        ld a,(ab_x0)
        ld b,a
        ld a,(hb_x0)
        call smax
        ld c,a
        ld a,(ab_x1)
        ld b,a
        ld a,(hb_x1)
        call smin
        add a,c
        sra a
        ld (sp_col),a
        ld a,(ab_y0)
        ld b,a
        ld a,(hb_y0)
        call smax
        ld c,a
        ld a,(ab_y1)
        ld b,a
        ld a,(hb_y1)
        call smin
        add a,c
        sra a
        ld (sp_row),a
        ld a,4
        ld (sp_t),a
        ret
; signed max/min of A and B
smax:   push af
        xor 80h
        ld c,a
        ld a,b
        xor 80h
        cp c
        jr c,.a
        pop af
        ld a,b
        ret
.a:     pop af
        ret
smin:   push af
        xor 80h
        ld c,a
        ld a,b
        xor 80h
        cp c
        jr nc,.a
        pop af
        ld a,b
        ret
.a:     pop af
        ret

; ---------------------------------------------------------------- spacing
; push_apart: grounded fighters keep MINDIST between anchors
push_apart:
        ld iy,PL1
        ld ix,PL2
        ld a,(iy+P_ST)
        cp ST_THROWN
        ret z
        ld a,(ix+P_ST)
        cp ST_THROWN
        ret z
        ld a,(iy+P_ST)
        cp ST_DOWN
        ret z
        cp ST_KO
        ret z
        ld a,(ix+P_ST)
        cp ST_DOWN
        ret z
        cp ST_KO
        ret z
        ; vertical overlap: if one is high in the air they may cross
        ld a,(iy+P_Y)
        sub (ix+P_Y)
        jr nc,$+4
        neg
        cp 5*16
        ret nc
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        ld e,(ix+P_X)
        ld d,(ix+P_X+1)
        or a
        sbc hl,de               ; HL = x1 - x2
        push af
        jr nc,.p
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.p:     ld de,MINDIST
        or a
        sbc hl,de               ; HL = dist - MINDIST
        jr nc,.ok
        ; overlap of -HL: each moves half
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        inc hl
        srl h
        rr l
        ld (pa_d),hl
        pop af
        jr c,.p1left
        ; P1 right of P2
        ld de,(pa_d)
        call .mv1p
        ld de,(pa_d)
        call .mv2n
        ret
.p1left:
        ld de,(pa_d)
        call .mv1n
        ld de,(pa_d)
        jp .mv2p
.ok:    pop af
        ret
.mv1p:  ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        add hl,de
        jp clamp_x
.mv1n:  ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        or a
        sbc hl,de
        jp clamp_x
.mv2p:  push iy
        push ix
        pop iy
        call .mv1p
        pop iy
        ret
.mv2n:  push iy
        push ix
        pop iy
        call .mv1n
        pop iy
        ret

; after pushing, if one is pinned at a wall the other is moved off
; (clamp handled in .mv*)

; ---------------------------------------------------------------- objects
; set_objs: fighters, projectiles and the spark into the object slots
set_objs:
        ld iy,PL1
        call .one
        ld iy,PL2
.one:   ld l,(iy+P_OBJ)
        ld h,high OBJ
        push hl
        pop ix
        ld (ix+O_TYPE),1
        ; column, row
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        call x_col
        ld (ix+O_COL),a
        ld a,(iy+P_Y)
        add a,8
        jr nc,.yy
        ld a,255
.yy:    rrca
        rrca
        rrca
        rrca
        and 0Fh
        ld b,a
        ld a,GROUND
        sub b
        ld (ix+O_ROW),a
        ld a,(iy+P_FACE)
        ld (ix+O_FLAGS),a
        ld a,(iy+P_DICT)
        ld (ix+O_DICT),a
        ld a,(iy+P_XLAT)
        bit 0,(iy+P_FLASH)
        jr z,$+4
        ld a,high XLATW
        ld (ix+O_XLAT),a
        ; frame pointer
        ld a,(iy+P_FR)
        add a,a
        ld l,a
        ld h,0
        ld e,(iy+P_FF)
        ld d,(iy+P_FF+1)
        add hl,de
        ld a,(hl)
        ld (ix+O_PTR),a
        inc hl
        ld a,(hl)
        ld (ix+O_PTR+1),a
        ; projectile slot (2 slots after)
        ld de,OBJSZ*2
        add ix,de
        ld a,(iy+P_PROJ)
        or a
        jr nz,.pr
        ld (ix+O_TYPE),0
        ret
.pr:    ld (ix+O_TYPE),2
        ld l,(iy+P_PX)
        ld h,(iy+P_PX+1)
        call x_col
        sub 1
        ld (ix+O_COL),a
        ld a,GROUND
        sub (iy+P_PRW)
        ld (ix+O_ROW),a
        ; art: P_PART -> 4 blocks: right f0, right f1, left f0, left f1
        ld a,(iy+P_PROJ)
        rrca
        and 1
        ld b,a
        ld a,(iy+P_PVX)
        rla
        ld a,b
        jr nc,$+4
        add a,2
        add a,a
        ld e,a
        ld d,0
        ld l,(iy+P_PART)
        ld h,(iy+P_PART+1)
        add hl,de
        ld a,(hl)
        ld (ix+O_PTR),a
        inc hl
        ld a,(hl)
        ld (ix+O_PTR+1),a
        ret

set_spark:
        ld ix,OBJ+4*OBJSZ
        ld a,(sp_t)
        or a
        jr nz,.on
        ld (ix+O_TYPE),0
        ret
.on:    dec a
        ld (sp_t),a
        ld (ix+O_TYPE),2
        ld a,(sp_col)
        dec a
        ld (ix+O_COL),a
        ld a,(sp_row)
        ld b,a
        ld a,GROUND-1
        sub b
        ld (ix+O_ROW),a
        ld a,(sp_kind)
        or a
        ld hl,spark_hit0
        jr z,$+5
        ld hl,spark_blk0
        ld a,(sp_t)
        cp 2
        jr nc,.p
        ld de,spark_hit1-spark_hit0
        add hl,de
.p:     ld (ix+O_PTR),l
        ld (ix+O_PTR+1),h
        ret

hb_x0:  db 0
hb_x1:  db 0
hb_y0:  db 0
hb_y1:  db 0
ab_x0:  db 0
ab_x1:  db 0
ab_y0:  db 0
ab_y1:  db 0
cur_move: dw 0
sp_kind: db 0
sp_col: db 0
sp_row: db 0
sp_t:   db 0
pa_d:   dw 0
two_players: db 0

; key lists: up, down, left, right, punch, kick (twice: alternatives)
keys_p1:  db 7*8+5, 7*8+4, 7*8+2, 7*8+3, 1*8+6, 2*8+0
          db 2*8+1, 2*8+5, 4*8+7, 4*8+4, 6*8+4, 4*8+1
keys_p1b: db 2*8+1, 2*8+5, 4*8+7, 4*8+4, 2*8+2, 4*8+1
          db 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
keys_p2:  db 7*8+5, 7*8+4, 7*8+2, 7*8+3, 3*8+5, 3*8+4
          db 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
