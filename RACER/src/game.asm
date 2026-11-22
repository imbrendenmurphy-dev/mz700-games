; =====================================================================
;  game.asm - driving, traffic, collisions, time and stages
;  Everything here steps once per PAL field (50 a second), so the world
;  keeps time whatever the drawing rate.
; =====================================================================

TOPV    equ 1536        ; top speed, 1/256 units a field (about 290 km/h)
TOPB    equ 1900        ; with the boost
OFFV    equ 640         ; most you can do on the grass
PLZ     equ 30          ; the player's car is this far ahead of the camera

; one field of play
game_field:
        ld a,(gstate)
        cp GS_RACE
        jr z,.race
        cp GS_CRASH
        jp z,crash_field
        cp GS_START
        jp z,start_field
        cp GS_OVER
        jp z,over_field
        cp GS_GOAL
        jp z,goal_field
        ret
.race:  call fork_banner
        call drive
        call move_player
        call obj_collide
        call tick_time
        jp check_stage

; ---------------------------------------------------------------------
; throttle, brake, boost -> speed
drive:
        ld a,(ckeys)
        ld (dk),a
        ld hl,(speed)
        ; on the grass?
        ld a,(offroad)
        or a
        jr z,.road
        ld de,OFFV
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.road              ; slow enough
        ld de,-22
        add hl,de
        jp .set
.road:  ; boost: held, some left, and going
        ld a,(dk)
        and K_FIRE
        jr z,.nob
        ld a,(boost)
        or a
        jr z,.nob
        dec a
        ld (boost),a
        ld a,1
        ld (boosting),a
        ld bc,TOPB
        ld de,22
        jr .acc
.nob:   xor a
        ld (boosting),a
        ld a,(dk)
        bit 1,a                 ; brake
        jr z,.nbr
        ld de,-26
        add hl,de
        jp .set
.nbr:   bit 0,a                 ; accelerate
        jr z,.coast
        ld bc,TOPV
        ; acceleration falls off with speed: ACC[speed >> 7]
        push hl
        add hl,hl
        ld a,h
        cp 15
        jr c,.a1
        ld a,15
.a1:    ld e,a
        ld d,0
        ld hl,acctab
        add hl,de
        ld e,(hl)
        pop hl
.acc:   add hl,de
        ; over the top speed?  ease back down
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,.set
        ld h,b
        ld l,c
        jr .set
.coast: ld de,-4
        add hl,de
.set:   ; uphill slows, downhill pulls: speed -= slope * 2
        ld a,(slope)
        or a
        jr z,.cl
        ld e,a
        rla
        sbc a,a
        ld d,a
        ex de,hl
        add hl,hl
        ex de,hl
        or a
        sbc hl,de
.cl:    bit 7,h
        jr z,.nn
        ld hl,0
.nn:    ld de,TOPB+64
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ld hl,TOPB+64
.ok:    ld (speed),hl
        ret

acctab: db 15,14,13,12,11,10,9,8,7,6,5,4,3,3,2,2

; ---------------------------------------------------------------------
; steering, the pull of the bends, moving along the road
move_player:
        ; steering: faster with speed (2..7 units a field), none standing
        ld hl,(speed)
        ld a,h
        or l
        jr z,.nost
        ld a,h
        srl a
        srl a
        add a,2
        ld c,a
        ld a,(ckeys)
        ld hl,(px)
        bit 2,a
        jr z,.nl
        ld e,c
        ld d,0
        or a
        sbc hl,de
.nl:    bit 3,a
        jr z,.nr
        ld e,c
        ld d,0
        add hl,de
.nr:    ld (px),hl
.nost:  ; the bend pushes outwards: curve * speed^2 / 32
        call cur_seg            ; HL = segment under the car
        ld de,TRK_CURV
        add hl,de
        ld a,(hl)
        or a
        jr z,.nocf
        ld c,a
        ld a,(speed+1)
        ld e,a
        ld h,0
        ld l,a
        call mul8               ; HL = spd^2
        ld a,c
        bit 7,a
        jr z,.cp
        neg
.cp:    push bc
        ld c,a
        ld a,l
        ld b,h
        ld hl,0
.cm:    ld e,a                  ; HL = spd^2 * |curve|
        ld d,b
        add hl,de
        dec c
        jr nz,.cm
        pop bc
        srl h                   ; / 32
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ex de,hl
        ld hl,(px)
        bit 7,c
        jr nz,.cl
        or a                    ; bend right: pushed left
        sbc hl,de
        jr .cs
.cl:    add hl,de
.cs:    ld (px),hl
.nocf:  ; keep within the verges (of both roads in a fork)
        call cur_seg
        ld de,TRK_SPL
        add hl,de
        ld a,(hl)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl               ; D = second road's offset
        ld (fk_here),hl
        ld de,420               ; upper: 420 + max(D, 0)
        bit 7,h
        jr nz,.u1
        add hl,de
        ex de,hl
.u1:    ld hl,(px)
        push hl
        or a
        sbc hl,de
        pop hl
        jp m,.u2
        ex de,hl
        ld (px),hl
.u2:    ld hl,(fk_here)         ; lower: -420 + min(D, 0)
        ld de,-420
        bit 7,h
        jr z,.l1
        add hl,de
        ex de,hl
.l1:    ld hl,(px)
        push hl
        or a
        sbc hl,de
        pop hl
        jp p,.inr
        ex de,hl
        ld (px),hl
.inr:   ; on the grass?  |px| > ROADW + 16 (or in a fork's middle)
        ld hl,(px)
        bit 7,h
        call nz,neg_hl
        ld de,ROADW+16
        or a
        sbc hl,de
        ld a,0
        jr c,.on
        ; a second road here?  on it: |px - SPL*8| < ROADW + 16
        call cur_seg
        ld de,TRK_SPL
        add hl,de
        ld a,(hl)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(px)
        or a
        sbc hl,de
        bit 7,h
        call nz,neg_hl
        ld de,ROADW+16
        or a
        sbc hl,de
        ld a,0
        jr c,.on
        inc a
.on:    ld (offroad),a
        ; slope under the car (for the engine and speed)
        call cur_seg
        ld de,TRK_HGT
        add hl,de
        ld a,(hl)
        inc hl
        ld b,(hl)
        sub b
        neg
        ld (slope),a
        ; move: pos += speed
        ld hl,(speed)
        ld a,(posf)
        add a,l
        ld (posf),a
        ld e,h
        ld d,0
        ld hl,(pos)
        adc hl,de
        ld (pos),hl
        ; distance score: speed / 64 every field (in tens)
        ld a,(speed+1)
        or a
        ret z
        ld hl,distacc
        add a,(hl)
        ld (hl),a
        ret nc
        ld de,1
        jp add_score

; HL = segment the player's car is on: (pos + PLZ) / 16
cur_seg:
        ld hl,(pos)
        ld de,PLZ
        add hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ret

; E x L (unsigned bytes) -> HL
mul8:
        ld h,0
        ld d,h
        ld b,8
        xor a
        ld h,a
        ld a,l
        ld l,h
.m:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .m
        ret

; ---------------------------------------------------------------------
; traffic: move, change lanes, spawn ahead, drop behind; hits and
; near misses
; (once a frame, for dt fields)
traffic:
        ld a,(gstate)
        cp GS_GOAL
        ret z
        ld a,(dt)
        ld b,a
        ld a,(spawnt)
        sub b
        jr nc,.ns
        xor a
.ns:    ld (spawnt),a
        or a
        jr nz,.mv
        call spawn_car
.mv:    ld ix,CARS
        ld b,MAXCARS
.c:     push bc
        ld a,(ix+C_ON)
        or a
        call nz,car_field
        pop bc
        ld de,CARSZ
        add ix,de
        djnz .c
        ret

; one field for car IX
car_field:
        ; z += v * dt
        ld a,(dt)
        ld b,a
.zz:    ld a,(ix+C_ZF)
        add a,(ix+C_V)
        ld (ix+C_ZF),a
        ld a,(ix+C_Z)
        adc a,(ix+C_V+1)
        ld (ix+C_Z),a
        jr nc,.z0
        inc (ix+C_Z+1)
.z0:    djnz .zz
.z1:    ; lanes: drift towards the target, 2 units a field
        ld l,(ix+C_X)
        ld h,(ix+C_X+1)
        ld e,(ix+C_TX)
        ld d,(ix+C_TX+1)
        or a
        sbc hl,de               ; HL = x - target
        jr z,.lc
        ld a,(dt)
        add a,a
        ld c,a                  ; C = step
        bit 7,h
        jr nz,.below
        ld a,h                  ; above: x -= step (or to the target)
        or a
        jr nz,.dn
        ld a,l
        cp c
        jr c,.at
.dn:    ld b,0
        or a
        sbc hl,bc
        jr .lx
.below: ld a,h
        inc a
        jr nz,.up
        ld a,l
        neg
        cp c
        jr c,.at
.up:    ld b,0
        add hl,bc
        jr .lx
.at:    ld hl,0
.lx:    add hl,de
        ld (ix+C_X),l
        ld (ix+C_X+1),h
        jr .lc2
.lc:    dec (ix+C_LC)           ; time to change lanes?
        jr nz,.lc2
        call rand8
        and 31
        add a,20
        ld (ix+C_LC),a
        ld a,(lanechg)
        or a
        jr z,.lc2
        call pick_lane
        ld (ix+C_TX),l
        ld (ix+C_TX+1),h
.lc2:   ; relative to the player's car: rel = z - (pos + PLZ)
        ld l,(ix+C_Z)
        ld h,(ix+C_Z+1)
        ld de,(pos)
        or a
        sbc hl,de
        jr nc,.ahead
        ld de,-40               ; well behind the camera: gone
        or a
        sbc hl,de
        ret nc
        ld (ix+C_ON),0
        ret
.ahead: ld de,PLZ
        or a
        sbc hl,de               ; HL = rel (signed)
        ld (crel),hl
        bit 7,h                 ; far ahead: nothing more to check
        jr nz,.close
        ld a,h
        or a
        jr z,.close
        ld (ix+C_PASS),1
        ret
.close:
        ; dx = car x - px
        ld l,(ix+C_X)
        ld h,(ix+C_X+1)
        ld de,(px)
        or a
        sbc hl,de
        ld (cdx),hl
        bit 7,h
        call nz,neg_hl
        ld (cadx),hl
        ; passed?  (was ahead, now more than 10 behind)
        ld hl,(crel)
        bit 7,h
        jr z,.front
        ld de,10
        add hl,de
        jr c,.near
        ld a,(ix+C_PASS)
        or a
        ret z
        ld (ix+C_PASS),0
        ld a,(ix+C_HIT)
        or a
        ret nz
        ld hl,(cadx)            ; a near miss: closer than 150 sideways
        ld de,150
        or a
        sbc hl,de
        ret nc
        jp near_miss
.front: ld (ix+C_PASS),1
        ; slipstream: right behind it, quicker than it
        ld de,160
        or a
        sbc hl,de
        jr nc,.near
        ld hl,(cadx)
        ld de,50
        or a
        sbc hl,de
        jr nc,.near
        ld a,(framecnt)
        and 3
        jr nz,.near
        ld a,1
        ld (slipping),a
        call boost_add1
.near:  ; a hit?  |rel| < 12 and |dx| < 96
        ld a,(ix+C_HIT)
        or a
        jr z,.h0
        dec (ix+C_HIT)
        ret
.h0:    ld hl,(crel)
        ld de,12
        add hl,de
        ld de,24
        or a
        sbc hl,de
        ret nc
        ld hl,(cadx)
        ld de,96
        or a
        sbc hl,de
        ret nc
        jp hit_car

; IX = car we ran into
hit_car:
        ld (ix+C_HIT),25
        ld hl,(speed)           ; speed drops to the car's, less a bit
        ld e,(ix+C_V)
        ld d,(ix+C_V+1)
        or a
        sbc hl,de
        jr c,.slow
        ex de,hl
        ld de,-200
        add hl,de
        bit 7,h
        jr z,.s1
        ld hl,0
.s1:    ld (speed),hl
        ; and the car is shoved on
        ld a,(ix+C_Z)
        add a,12
        ld (ix+C_Z),a
        jr nc,.slow
        inc (ix+C_Z+1)
.slow:  ; bounce sideways, away from it
        ld hl,(cdx)
        ld de,(px)
        bit 7,h
        ld hl,-40
        jr z,.b
        ld hl,40
.b:     add hl,de
        ld (px),hl
        ld a,12
        ld (shake),a
        xor a
        ld (combo),a
        ld hl,SFX_BUMP
        ld a,4
        jp sfx

near_miss:
        ld a,(combo)
        cp 9
        jr nc,.c
        inc a
        ld (combo),a
.c:     ld a,50*3
        ld (combot),a
        ; 500 x combo points
        ld a,(combo)
        ld b,a
.p:     push bc
        ld de,50h
        call add_score
        pop bc
        djnz .p
        ld a,24
        call boost_add
        ld a,YELLOW*16+RED
        ld (msgcol),a
        ld hl,txt_close
        ld a,(combo)
        call hud_message
        ld a,35
        ld (msgtime),a
        ld hl,SFX_WHOOSH
        ld a,2
        jp sfx

txt_close: db "CLOSE!",0

boost_add1:
        ld a,1
boost_add:
        ld hl,boost
        add a,(hl)
        jr c,.f
        cp BOOSTMAX+1
        jr c,.s
.f:     ld a,BOOSTMAX
.s:     ld (hl),a
        ret

; a new car just past the horizon
spawn_car:
        ld a,(spawngap)
        ld (spawnt),a
        ld a,(demo)
        ld ix,CARS
        ld b,MAXCARS
.f:     ld a,(ix+C_ON)
        or a
        jr z,.got
        ld de,CARSZ
        add ix,de
        djnz .f
        ret
.got:   ld a,(carsmax)          ; no more than this many at once
        ld c,a
        ld a,MAXCARS
        sub b
        cp c
        ret nc
        call rand8              ; type 1..7 (7 = truck)
        and 7
        jr nz,.t
        inc a
.t:     ld (ix+C_ON),a
        ld hl,(pos)
        ld de,(NSAMP-2)*SEGL
        add hl,de
        ld (ix+C_Z),l
        ld (ix+C_Z+1),h
        ld (ix+C_ZF),0
        call pick_lane
        ld (ix+C_X),l
        ld (ix+C_X+1),h
        ld (ix+C_TX),l
        ld (ix+C_TX+1),h
        ; speed: carmin + random 0..carvar
        call rand8
        ld hl,carvar
        and (hl)
        ld e,a
        ld d,0
        ld hl,(carmin)
        add hl,de
        ld a,(ix+C_ON)
        cp 7
        jr nz,.v
        ld de,-128              ; trucks are slower
        add hl,de
.v:     ld (ix+C_V),l
        ld (ix+C_V+1),h
        call rand8
        and 63
        add a,30
        ld (ix+C_LC),a
        ld (ix+C_PASS),0
        ld (ix+C_HIT),0
        ret

; HL = x of a random lane (-107, 0, 107)
pick_lane:
        ld a,3
        call rand_n
        ld hl,-107
        or a
        ret z
        ld hl,0
        dec a
        ret z
        ld hl,107
        ret

; ---------------------------------------------------------------------
; running into roadside things
obj_collide:
        ld a,(offroad)
        or a
        ret z
        call cur_seg
        ld de,TRK_OBJ
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld c,a
        ld de,TRK_OX-TRK_OBJ
        add hl,de
        ld a,(hl)               ; object x = OX * 4
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        ld de,(px)
        or a
        sbc hl,de
        bit 7,h
        call nz,neg_hl
        ld a,c                  ; its half width
        ld e,a
        ld d,0
        push hl
        ld hl,OBJW-1
        add hl,de
        ld e,(hl)
        pop hl
        ld d,0
        or a
        sbc hl,de
        ret nc
        ; crash
crash:
        ld a,GS_CRASH
        ld (gstate),a
        ld a,100
        ld (gtimer),a
        xor a
        ld (combo),a
        ld (boosting),a
        ld hl,SFX_CRASH
        ld a,6
        call sfx
        ld a,20
        ld (shake),a
        ret

; spinning to a stop, then back on the road
crash_field:
        ld hl,(speed)           ; skid to a stop
        ld de,-40
        add hl,de
        bit 7,h
        jr z,.s
        ld hl,0
.s:     ld (speed),hl
        ld a,(speed+1)
        ld e,a
        ld a,(posf)
        add a,l
        ld (posf),a
        ld d,0
        ld hl,(pos)
        adc hl,de
        ld (pos),hl
        call tick_time
        ld hl,gtimer
        dec (hl)
        ret nz
        ; back on the road, at its edge
        ld hl,(px)
        ld de,ROADW*3/4
        bit 7,h
        jr z,.r
        ld de,-ROADW*3/4
.r:     ld (px),de
        ld a,GS_RACE
        ld (gstate),a
        ret

; ---------------------------------------------------------------------
; the clock: a second every 50 fields
tick_time:
        ld a,(demo)
        or a
        ret nz
        ld hl,tfield
        dec (hl)
        ret nz
        ld (hl),50
        ld a,(timesec)
        or a
        jr z,.out
        sub 1
        daa
        ld (timesec),a
        cp 11h
        ret nc
        or a
        jr z,.out
        ld hl,SFX_TICK          ; the last ten: a warning beep
        ld a,1
        jp sfx
.out:   ld a,GS_OVER            ; time up: coast to a stop
        ld (gstate),a
        ld a,200
        ld (gtimer),a
        ld hl,txt_timeup
        xor a
        call hud_message
        ld hl,TRK_OVER
        jp play_tune

txt_timeup: db "TIME UP",0

over_field:
        ld hl,(speed)
        ld de,-12
        add hl,de
        bit 7,h
        jr z,.s
        ld hl,0
.s:     ld (speed),hl
        call move_player
        ld hl,gtimer
        dec (hl)
        ret nz
        ld a,1
        ld (gameend),a
        ret

; the countdown before the start
start_field:
        ld hl,gtimer
        dec (hl)
        ret nz
        ld a,GS_RACE
        ld (gstate),a
        ret

goal_field:
        ld hl,(speed)
        ld de,-10
        add hl,de
        bit 7,h
        jr z,.s
        ld hl,0
.s:     ld (speed),hl
        call move_player
        ld hl,gtimer
        dec (hl)
        ret nz
        ld a,1
        ld (gameend),a
        ret

; ---------------------------------------------------------------------
; the end of the course: a checkpoint, the next stage
check_stage:
        ld hl,(crs_len)         ; past the end?  (pos >= len * 16)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(pos)
        or a
        sbc hl,de
        ret c
        ld (pos),hl             ; the next course starts here
        ; the traffic moves back with it
        ld ix,CARS
        ld b,MAXCARS
.cm:    ld l,(ix+C_Z)
        ld h,(ix+C_Z+1)
        or a
        sbc hl,de
        ld (ix+C_Z),l
        ld (ix+C_Z+1),h
        push de
        ld de,CARSZ
        add ix,de
        pop de
        djnz .cm
        jp next_stage

; the engine note from the speed: rises through each gear and drops at
; the change (sound.asm eng_out plays it)
engine:
        ld a,(gstate)
        cp GS_START
        jr z,.idle
        ld hl,(speed)
        ld de,384
        ld b,0
.g:     or a
        sbc hl,de
        jr c,.gd
        inc b
        jr .g
.gd:    add hl,de               ; HL = speed within the gear (0..383)
        srl h
        rr l
        srl l                   ; / 4
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a                 ; gear * 16
        add a,l
        ld c,a
        ld a,(boosting)
        or a
        jr z,.nb
        ld a,c
        add a,24
        ld c,a
.nb:    ld a,c
        jr .set
.idle:  ld a,(framecnt)
        and 3
        add a,4
.set:   ld (eng_r),a
        ret
