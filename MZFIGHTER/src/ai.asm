; =====================================================================
;  ai.asm - the computer opponent.  It "presses" the same inputs a
;  player would: relative directions and buttons, single frames or short
;  scripted sequences (the motions of special moves).
; =====================================================================

P_AIQ   equ 71          ; word: sequence pointer (0 = none)
P_AIN   equ 73          ; frames left on the current sequence entry
P_AIB   equ 74          ; current sequence byte

; sequence entries: relative input byte (bit0 U, 1 D, 2 B, 3 F, 4 P, 5 K),
; frame count; FFh ends
AU      equ 1
AD      equ 2
AB      equ 4
AF      equ 8
AP      equ 16
AK      equ 32

sq_qcf_p:  db AD,1, AD+AF,1, AF+AP,1, 0,8, 0FFh
sq_dp_p:   db AF,1, AD,1, AD+AF+AP,1, 0,4, 0FFh
sq_qcb_k:  db AD,1, AD+AB,1, AB+AK,1, 0,6, 0FFh
sq_jumpin: db AU+AF,1, AF,6, AF+AK,1, 0,12, 0FFh
sq_jumpup: db AU,1, 0,5, AK,1, 0,10, 0FFh
sq_jumpb:  db AU+AB,1, 0,16, 0FFh
sq_flurry: db AP,1, 0,1, AP,1, 0,1, AP,1, 0,1, AP,1, 0,10, 0FFh
sq_throw:  db AF,2, AF+AP,1, 0,6, 0FFh
sq_sweep:  db AD,2, AD+AK,1, AD,10, 0FFh
sq_cpunch: db AD,2, AD+AP,1, AD,5, 0FFh
sq_jab:    db AP,1, 0,4, 0FFh
sq_jab2:   db AP,1, 0,3, AP,1, 0,5, 0FFh
sq_kick:   db AK,1, 0,7, 0FFh
sq_block:  db AB,10, 0FFh
sq_cblock: db AD+AB,10, 0FFh
sq_walkf:  db AF,7, 0FFh
sq_walkf2: db AF,14, 0FFh
sq_walkb:  db AB,6, 0FFh
sq_wait:   db 0,6, 0FFh
sq_wait2:  db 0,14, 0FFh
sq_crouch: db AD,8, 0FFh

; ai_think: IY = computer player -> A = absolute input bits
ai_think:
        call restore_ix         ; IX = opponent
        ld a,(iy+P_AIQ+1)
        or a
        jr nz,.seq
        call ai_decide
        ld a,(iy+P_AIQ+1)
        or a
        jr nz,.seq
        xor a
        ret
.seq:   ld a,(iy+P_AIN)
        or a
        jr nz,.cur
        ; fetch the next entry
        ld l,(iy+P_AIQ)
        ld h,(iy+P_AIQ+1)
        ld a,(hl)
        cp 0FFh
        jr z,.end
        ld (iy+P_AIB),a
        inc hl
        ld a,(hl)
        ld (iy+P_AIN),a
        inc hl
        ld (iy+P_AIQ),l
        ld (iy+P_AIQ+1),h
.cur:   dec (iy+P_AIN)
        ld a,(iy+P_AIB)
        ; relative -> absolute
        ld c,a
        and 33h                 ; U, D, P, K stay
        ld b,a
        ld a,(iy+P_FACE)
        or a
        jr nz,.left
        bit 3,c                 ; forward = right
        jr z,$+4
        set IN_R,b
        bit 2,c
        jr z,$+4
        set IN_L,b
        ld a,b
        ret
.left:  bit 3,c
        jr z,$+4
        set IN_L,b
        bit 2,c
        jr z,$+4
        set IN_R,b
        ld a,b
        ret
.end:   ld (iy+P_AIQ),0
        ld (iy+P_AIQ+1),0
        xor a
        ret

; start sequence HL
ai_seq:
        ld (iy+P_AIQ),l
        ld (iy+P_AIQ+1),h
        ld (iy+P_AIN),0
        ret

; choose what to do next
ai_decide:
        ld a,(iy+P_ST)
        cp ST_STAND
        jr z,.free
        cp ST_CROUCH
        jr z,.free
        ; when getting hit or knocked down: hold back for when it ends
        cp ST_HIT
        jr nz,.nh
        ld a,(ai_level)
        cp 3
        ret c
        ld hl,sq_block
        jp ai_seq
.nh:    ret
.free:  call distance
        ld (ai_d),a
        ; 1. danger: opponent attacking near, or a projectile coming
        call ai_threat
        jr z,.calm
        call rand
        ld b,a
        ld a,(ai_level)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; level * 32
        add a,60
        cp b
        jr c,.calm              ; failed to react
        ; projectile far enough: jump over it sometimes
        ld a,(ai_threat_k)
        cp 2
        jr nz,.blk
        call rand
        cp 90
        jr nc,.blk
        ld hl,sq_jumpin
        jp ai_seq
.blk:   ld a,(ix+P_MV)
        cp M_SWEEP
        jr z,.low
        cp M_CPUNCH
        jr z,.low
        ld a,(ix+P_ST)
        cp ST_JUMP
        jr z,.high
        call rand
        cp 100
        jr c,.low
.high:  ld hl,sq_block
        jp ai_seq
.low:   ld hl,sq_cblock
        jp ai_seq
.calm:  ; 2. opponent in the air coming in: anti-air
        ld a,(ix+P_ST)
        cp ST_JUMP
        jr nz,.ground
        ld a,(ai_d)
        cp 9
        jr nc,.ground
        call rand
        ld b,a
        ld a,(ai_level)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,40
        cp b
        jr c,.ground
        ld a,(iy+P_MOTB)
        cp 1
        jr nz,.aa
        ld hl,sq_dp_p
        jp ai_seq
.aa:    ld hl,sq_jab
        ld a,(ai_d)
        cp 5
        jp c,ai_seq
        ld hl,sq_cblock
        jp ai_seq
.ground:
        ; slow reactions at low levels: sometimes just wait
        call rand
        and 7
        ld b,a
        ld a,(ai_level)
        cp b
        jr nc,.act
        call rand
        cp 80
        jr nc,.act
        ld hl,sq_wait
        jp ai_seq
.act:   ld a,(ai_d)
        cp 12
        jr c,.mid
        ; far
        ld a,(iy+P_SPA)
        cp M_FIRE
        jr nz,.walk
        ld a,(iy+P_PROJ)
        or a
        jr nz,.walk
        call rand
        cp 110
        jr nc,.walk
        ld hl,sq_qcf_p
        jp ai_seq
.walk:  call rand
        cp 40
        ld hl,sq_jumpin
        jp c,ai_seq
        ld hl,sq_walkf2
        jp ai_seq
.mid:   cp 7
        jr c,.close
        call rand
        ld b,a
        ld hl,sq_walkf
        cp 110
        jp c,ai_seq
        ld a,(iy+P_SPA)
        cp M_FIRE
        jr nz,.m2
        ld a,(iy+P_PROJ)
        or a
        jr nz,.m2
        ld a,b
        cp 160
        ld hl,sq_qcf_p
        jp c,ai_seq
.m2:    ld a,b
        cp 200
        ld hl,sq_jumpin
        jp c,ai_seq
        ld a,(iy+P_MOTB)
        or a
        jr nz,.m3
        ld hl,sq_qcb_k          ; spin / rush from mid range
        jp ai_seq
.m3:    ld hl,sq_walkf
        jp ai_seq
.close: ; in range: attack
        call rand
        and 15
        ld e,a
        ld d,0
        ld hl,ai_close
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ; specials that need a motion: check the fighter has one
        ld de,sq_qcb_k
        or a
        sbc hl,de
        add hl,de
        jr nz,.c1
        ld a,(iy+P_MOTB)
        or a
        jr z,.go
        ld hl,sq_dp_p
        jr .go
.c1:    ld de,sq_flurry
        or a
        sbc hl,de
        add hl,de
        jr nz,.go
        ld a,(iy+P_SPA)
        cp M_FLURRY
        jr z,.go
        ld hl,sq_qcf_p
.go:    jp ai_seq

ai_close:
        dw sq_jab, sq_jab2, sq_kick, sq_kick, sq_sweep, sq_cpunch, sq_throw, sq_qcb_k
        dw sq_jab, sq_flurry, sq_kick, sq_sweep, sq_walkb, sq_throw, sq_wait, sq_jumpup

; ai_threat: NZ if the opponent threatens us; ai_threat_k = 1 attack, 2 projectile
ai_threat:
        xor a
        ld (ai_threat_k),a
        ld a,(ix+P_PROJ)
        or a
        jr z,.np
        ; projectile distance
        ld l,(ix+P_PX)
        ld h,(ix+P_PX+1)
        call x_col
        ld b,a
        ld l,(iy+P_X)
        ld h,(iy+P_X+1)
        call x_col
        sub b
        jr nc,$+4
        neg
        cp 9
        jr nc,.np
        ld a,2
        ld (ai_threat_k),a
        or a
        ret
.np:    ld a,(ai_d)
        cp 9
        jr nc,.no
        ld a,(ix+P_ST)
        cp ST_ATK
        jr z,.yes
        cp ST_JUMP
        jr nz,.no
        ld a,(ix+P_HITD)
        cp 2
        jr z,.yes
.no:    xor a
        ret
.yes:   ld a,1
        ld (ai_threat_k),a
        or a
        ret

ai_level: db 2
ai_d:   db 0
ai_threat_k: db 0
