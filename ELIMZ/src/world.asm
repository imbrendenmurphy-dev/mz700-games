; =====================================================================
;  world.asm - flight: objects, 3D transform, AI, combat, docking
;
;  The player sits at the origin looking down +z (x right, y up).
;  Turning the ship rotates the whole universe the other way; flying
;  forward moves everything towards -z.  Objects carry a position and
;  an orientation (side / roof / nose unit vectors, 4000h = 1.0).
; =====================================================================

PLANET_R        equ 6000
NDUST           equ 10
DOTZ            equ 2600                ; ships beyond this are drawn as a dot
MAXSPEED        equ 32

; ---------------------------------------------------------------------
; flight: one sortie.  Returns A = 1 docked, 0 destroyed.
; ---------------------------------------------------------------------
flight:
        call mus_stop
        ld a,WHITE<<4
        call cls
        call hud_frame
        call world_init
        ld hl,txt_launch
        ld a,(arrive)
        or a
        jr z,$+5
        ld hl,txt_arrive
        ld de,msgbuf
        call strcpy
        ld a,(cur_sys)
        call sys_name
        call strcpy
        ld hl,msgbuf
        call message
        ld a,(arrive)
        or a
        call z,customs
.loop:  ld a,(turbo)
        or a
        call z,wait_frame
        call read_flight
        ld (keys),a
        ld hl,frame
        inc (hl)
        ld a,(state)
        or a
        jr nz,.nocon
        call controls
.nocon: call world_step
        call render
        call present
        call hud_update
        ld a,(state)
        cp 1
        jr z,.docked
        cp 3
        jr z,.jumped
        cp 2
        jr nz,.loop
        ld hl,state_t                   ; destroyed: let the debris fly
        dec (hl)
        jr nz,.loop
        xor a
        ret
.docked:
        ld a,1
        ret
.jumped:
        ld a,2
        ret

world_init:
        ld hl,objects
        ld de,objects+1
        ld bc,MAXOBJ*OBJSZ-1
        ld (hl),0
        ldir
        ld ix,objects
        ld (ix+O_TYPE),T_STATION
        ld a,(arrive)
        or a
        jr nz,.arr
        ld hl,-420                      ; launched: the station just behind us
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        call ori_forward                ; port faces us (nose = +z)
        ld hl,6000                      ; the planet, far ahead
        ld (planet),hl
        ld hl,-4000
        ld (planet+2),hl
        ld hl,20000
        ld (planet+4),hl
        jr .pl
.arr:   ld hl,1600                      ; out of hyperspace: station in orbit ahead
        ld (ix+O_X),l
        ld (ix+O_X+1),h
        ld hl,-900
        ld (ix+O_Y),l
        ld (ix+O_Y+1),h
        ld hl,9000
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        call ori_toward
        ld hl,3200
        ld (planet),hl
        ld hl,-2600
        ld (planet+2),hl
        ld hl,21000
        ld (planet+4),hl
.pl:
        ld a,10
        ld (speed),a
        ld a,64
        ld (shield),a
        ld (energy),a
        xor a
        ld (heat),a
        ld (hyper_t),a
        ld (hkey),a
        ld (laser_on),a
        ld (lcd),a
        ld (state),a
        ld (msg_t),a
        ld a,200
        ld (spawn_t),a
        ld hl,dust
        ld b,NDUST
.d:     push bc
        push hl
        call dust_new
        pop hl
        ld de,6
        add hl,de
        pop bc
        djnz .d
        ret

; orientation: identity (nose +z)
ori_forward:
        call ori_clear
        ld (ix+O_SIDE+1),40h
        ld (ix+O_ROOF+3),40h
        ld (ix+O_NOSE+5),40h
        ret

; orientation: facing the player (nose -z, side -x)
ori_toward:
        call ori_clear
        ld (ix+O_SIDE+1),0C0h
        ld (ix+O_ROOF+3),40h
        ld (ix+O_NOSE+5),0C0h
        ret

; orientation: crossing left to right (nose +x, side +z)
ori_cross:
        call ori_clear
        ld (ix+O_SIDE+5),0C0h
        ld (ix+O_ROOF+3),40h
        ld (ix+O_NOSE+1),40h
        ret

ori_clear:
        push ix
        pop hl
        ld de,O_SIDE
        add hl,de
        ld b,18
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; HL -> dust particle: new random position ahead
dust_new:
        push hl
        call rand
        ld e,a
        call sext_e                     ; DE = -128..127
        ld b,d
        ld c,e
        ld h,b
        ld l,c
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,bc                       ; x9: +-1150
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        push hl
        call rand
        ld e,a
        call sext_e
        ex de,hl
        add hl,hl
        add hl,hl                       ; x4: +-512
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        push hl
        call rand
        and 7Fh
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl                       ; 0..1016
        ld de,500
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; DE = sign-extended E
sext_e:
        ld d,0
        bit 7,e
        ret z
        dec d
        ret

; ---------------------------------------------------------------------
; keyboard: cursor keys pitch / roll, SPACE fire, A faster, Z slower
; ---------------------------------------------------------------------
read_flight:
        ld a,(autoplay)
        or a
        jr z,.k
        ld a,(demo_keys)
        ret
.k:     ld hl,KEYPA
        ld c,0
        ld (hl),7
        inc l
        ld a,(hl)
        dec l
        bit 5,a
        jr nz,$+4
        set 2,c                         ; up
        bit 4,a
        jr nz,$+4
        set 3,c                         ; down
        bit 2,a
        jr nz,$+4
        set 0,c                         ; left
        bit 3,a
        jr nz,$+4
        set 1,c                         ; right
        ld (hl),6
        inc l
        ld a,(hl)
        dec l
        bit 4,a
        jr nz,$+4
        set 4,c                         ; space
        ld (hl),4
        inc l
        ld a,(hl)
        dec l
        bit 7,a
        jr nz,$+4
        set 5,c                         ; A
        and 1
        xor 1
        ld (hkey),a                     ; H
        ld (hl),1
        inc l
        ld a,(hl)
        dec l
        bit 6,a
        jr nz,$+4
        set 6,c                         ; Z
        ld (hl),3
        inc l
        ld a,(hl)
        dec l
        cpl
        and 48h                         ; J (bit 6), M (bit 3)
        ld (mkey),a
        ld (hl),8
        inc l
        ld a,(hl)
        bit 7,a
        jr nz,$+4
        set 7,c                         ; BREAK
        ld a,c
        ret

; ---------------------------------------------------------------------
; controls: steering, speed, lasers
; ---------------------------------------------------------------------
controls:
        ld a,(hkey)
        or a
        call nz,hyper_start
        ld a,(prevx)                    ; M / J: on the press only
        cpl
        ld hl,mkey
        and (hl)
        ld b,(hl)
        ld hl,prevx
        ld (hl),b
        push af
        bit 3,a
        call nz,fire_seeker
        pop af
        bit 6,a
        call nz,use_jammer
        ld a,(keys)
        bit 1,a                         ; roll right: world turns anticlockwise
        jr z,.nr
        ld a,4
        call set_rot
        ld a,0
        ld (ro1),a
        ld a,2
        ld (ro2),a
        call rotate_world
        jr .np
.nr:    ld a,(keys)
        bit 0,a
        jr z,.np
        ld a,4
        call set_rot
        ld a,2
        ld (ro1),a
        xor a
        ld (ro2),a
        call rotate_world
.np:    ld a,(keys)
        bit 3,a                         ; down: climb (nose up)
        jr z,.nd
        ld a,5
        call set_rot
        ld a,2
        ld (ro1),a
        ld a,4
        ld (ro2),a
        call rotate_world
        jr .sp
.nd:    ld a,(keys)
        bit 2,a
        jr z,.sp
        ld a,5
        call set_rot
        ld a,4
        ld (ro1),a
        ld a,2
        ld (ro2),a
        call rotate_world
.sp:    ld a,(keys)
        ld hl,speed
        bit 5,a
        jr z,.ns
        ld a,(hl)
        cp MAXSPEED
        jr nc,.ns
        inc (hl)
.ns:    ld a,(keys)
        bit 6,a
        jr z,.fire
        ld a,(hl)
        or a
        jr z,.fire
        dec (hl)
.fire:  ld hl,lcd
        ld a,(hl)
        or a
        jr z,.ready
        dec (hl)
        jr .cool
.ready: ld a,(keys)
        bit 4,a
        jr z,.cool
        ld a,(heat)
        cp 56
        jr nc,.cool
        add a,8
        ld (heat),a
        ld a,4
        ld (lcd),a
        ld a,2
        ld (laser_on),a
        ld hl,SFX_LASER
        ld a,2
        call sfx
        call laser_hit
        ret
.cool:  ld a,(frame)
        and 1
        ret nz
        ld hl,heat
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

; ---------------------------------------------------------------------
; rotate_world: rotate component pair (ro1, ro2) of every position and
; orientation vector by the angle in rot_k
; ---------------------------------------------------------------------
rotate_world:
        ld ix,objects
        ld b,MAXOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        ld c,O_X
        call .vec
        ld c,O_SIDE
        call .vec
        ld c,O_ROOF
        call .vec
        ld c,O_NOSE
        call .vec
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ld hl,planet
        call .vhl
        ld hl,dust
        ld b,NDUST
.d:     push bc
        push hl
        call .vhl
        pop hl
        ld de,6
        add hl,de
        pop bc
        djnz .d
        ret
.vec:   push ix
        pop hl
        ld b,0
        add hl,bc
.vhl:   ld a,(ro2)
        ld e,a
        ld d,0
        push hl
        add hl,de
        ex de,hl                        ; DE -> Q
        pop hl
        ld a,(ro1)
        ld c,a
        ld b,0
        add hl,bc                       ; HL -> P
        jp rot_pair

; obj_rot: rotate the object's own vectors: P = vector (rb1), Q = (rb2)
; for each component.  IX = object, rot_k set.
obj_rot:
        ld c,0
.l:     push bc
        push ix
        pop hl
        ld a,(rb1)
        add a,c
        ld e,a
        ld d,0
        add hl,de
        push hl
        push ix
        pop hl
        ld a,(rb2)
        add a,c
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        call rot_pair
        pop bc
        inc c
        inc c
        ld a,c
        cp 6
        jr c,.l
        ret

; pitch IX's nose towards its roof (A = k)
pitch_up:
        call set_rot
        ld a,O_ROOF
        ld (rb1),a
        ld a,O_NOSE
        ld (rb2),a
        jr obj_rot
pitch_down:
        call set_rot
        ld a,O_NOSE
        ld (rb1),a
        ld a,O_ROOF
        ld (rb2),a
        jr obj_rot
; roll so the roof turns towards the side vector
roll_to_side:
        call set_rot
        ld a,O_SIDE
        ld (rb1),a
        ld a,O_ROOF
        ld (rb2),a
        jr obj_rot
roll_from_side:
        call set_rot
        ld a,O_ROOF
        ld (rb1),a
        ld a,O_SIDE
        ld (rb2),a
        jr obj_rot

; ---------------------------------------------------------------------
; world_step: motion, AI, spawning, collisions, docking
; ---------------------------------------------------------------------
world_step:
        ; laser beam display and heat
        ld hl,laser_on
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        ; objects
        ld ix,objects
        ld b,MAXOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        call nz,obj_step
        ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ; planet and dust drift towards us
        ld hl,planet+4
        call sub_speed
        ld hl,planet
        call clamp_far
        call planet_crash
        ld hl,dust
        ld b,NDUST
.d:     push bc
        push hl
        inc hl
        inc hl
        inc hl
        inc hl
        call sub_speed
        pop hl
        push hl
        call dust_check
        pop hl
        ld de,6
        add hl,de
        pop bc
        djnz .d
        call spawn
        call regen
        call hyper_tick
        ld a,(state)
        or a
        ret nz
        ld a,(energy)
        or a
        ret nz
        ; destroyed
        ld a,2
        ld (state),a
        ld a,40
        ld (state_t),a
        xor a
        ld (speed),a
        ld hl,SFX_CRASH
        ld a,9
        call sfx
        ld hl,txt_dead
        jp message

; (HL) word -= speed
sub_speed:
        ld a,(speed)
        ld c,a
        ld a,(hl)
        sub c
        ld (hl),a
        ret nc
        inc hl
        dec (hl)
        ret

; HL -> vector: keep |x|+|y|+|z| <= 31000 (scale far things inwards)
clamp_far:
        push hl
        call .sum
        pop hl
        ld de,31000
        or a
        sbc hl,de
        ret c
        ld b,3                          ; v -= v/16
.c:     push bc
        push hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,4
        call asr_bc
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        or a
        sbc hl,bc
        ex de,hl
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
        inc hl
        pop bc
        djnz .c
        ret
.sum:   ld de,0                         ; HL = sum of |components|, from (HL)
        ld b,3
.s:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
        call abs_hl
        add hl,de
        ex de,hl
        pop hl
        pop bc
        djnz .s
        ex de,hl
        ret

; HL -> dust: respawn if it is behind us or out of view
dust_check:
        push hl
        inc hl
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        push hl
        call z_ok
        pop de
        pop hl
        jr nc,.new                      ; z < NEAR
        ld a,d
        cp 8                            ; z >= 2048
        ret c
.new:   jp dust_new

; HL -> vector: copy to vx_, vy_, vz_
load_v:
        ld de,vx_
        ld bc,6
        ldir
        ret

; planet collision
planet_crash:
        ld hl,planet
        call clamp_far.sum
        ld de,PLANET_R+PLANET_R/2
        or a
        sbc hl,de
        ret nc
        xor a
        ld (energy),a
        ret

; ---------------------------------------------------------------------
; obj_step: IX = object
; ---------------------------------------------------------------------
obj_step:
        ; everyone drifts towards us at our speed
        push ix
        pop hl
        ld de,O_Z
        add hl,de
        call sub_speed
        ld a,(ix+O_TYPE)
        cp T_DEBRIS
        jr nz,.notdeb
        inc (ix+O_TMR)
        ld a,(ix+O_TMR)
        cp 16
        ret c
        ld (ix+O_TYPE),T_NONE
        ret
.notdeb:
        cp T_STATION
        jr nz,.ship
        ld a,6                          ; the station spins slowly
        call roll_to_side
        push ix
        pop hl
        inc hl
        inc hl
        call clamp_far
        jp dock_check
.ship:  ; far away: gone
        push ix
        pop hl
        inc hl
        inc hl
        call clamp_far.sum
        ld de,24000
        or a
        sbc hl,de
        jr c,.near
        ld (ix+O_TYPE),T_NONE
        ret
.near:  ld a,(ix+O_TYPE)
        cp T_SEEKER
        jr nz,.nsk
        call ai_seeker
        ld a,(ix+O_TYPE)
        cp T_SEEKER
        ret nz                          ; it went off
        jr obj_move
.nsk:   cp T_WARDEN
        jr nz,.nw
        bit 1,(ix+O_FLAG)               ; police: only when hostile
        call nz,ai_pirate
        jr .mvc
.nw:    cp T_HAULER
        call nz,ai_pirate
.mvc:   ld a,(ix+O_TYPE)
        cp T_DEBRIS
        ret z
        call obj_move
        jp collide

; move IX along its nose at its speed
obj_move:
        ld c,(ix+O_SPD)
        ld b,(ix+O_NOSE+1)
        ld l,O_X
        call .mv
        ld b,(ix+O_NOSE+3)
        ld l,O_Y
        call .mv
        ld b,(ix+O_NOSE+5)
        ld l,O_Z
; pos(L) += B*C >> 6
.mv:    push hl
        call mul8s
        add hl,hl
        add hl,hl
        ld e,h
        call sext_e
        pop hl
        ld h,0
        push ix
        pop bc
        add hl,bc
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        ld c,(ix+O_SPD)
        ret

; ship near the player: ram damage
collide:
        call obj_dist
        ld de,60
        or a
        sbc hl,de
        ret nc
        ld a,(energy)
        sub 24
        jr nc,$+3
        xor a
        ld (energy),a
        ld hl,SFX_CRASH
        ld a,8
        call sfx
        jp explode

; HL = max(|x|,|y|,|z|) of IX
obj_dist:
        ld l,(ix+O_X)
        ld h,(ix+O_X+1)
        call abs_hl
        ex de,hl
        ld l,(ix+O_Y)
        ld h,(ix+O_Y+1)
        call abs_hl
        call .max
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        call abs_hl
.max:   or a                            ; DE = max(DE, HL), HL = same
        sbc hl,de
        add hl,de
        jr c,.k
        ex de,hl
.k:     ex de,hl
        ret

; ---------------------------------------------------------------------
; pirate AI: roll the player above, pitch onto them, fire when lined up
; ---------------------------------------------------------------------
ai_pirate:
        ld l,(ix+O_X)                   ; direction to the player = -pos
        ld h,(ix+O_X+1)
        call neg_hl
        ld (tin),hl
        ld l,(ix+O_Y)
        ld h,(ix+O_Y+1)
        call neg_hl
        ld (tin+2),hl
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        call neg_hl
        ld (tin+4),hl
        ld hl,tin
        call vec_to_bytes
        push ix
        pop iy
        ld de,O_SIDE
        add iy,de
        call dot3
        ld (ai_ds),hl
        ld de,O_ROOF-O_SIDE
        add iy,de
        call dot3
        ld (ai_dr),hl
        ld de,O_NOSE-O_ROOF
        add iy,de
        call dot3
        ld (ai_dn),hl
        ; cooldown
        ld a,(ix+O_CD)
        or a
        jr z,$+5
        dec (ix+O_CD)
        res 0,(ix+O_FLAG)
        ; evading?
        ld a,(ix+O_EV)
        or a
        jr z,.hunt
        dec (ix+O_EV)
        ld a,4
        jp pitch_up                     ; loop away
.hunt:  call obj_dist
        ld de,320
        or a
        sbc hl,de
        jr nc,.far
        ld (ix+O_EV),24                 ; too close: break off
        ret
.far:   ; roll the player towards our roof
        ld hl,(ai_ds)
        call abs_hl
        ld de,500
        or a
        sbc hl,de
        jr c,.noroll
        ld a,(ai_ds+1)
        rla
        ld a,4
        jr c,.rl
        call roll_to_side
        jr .noroll
.rl:    call roll_from_side
.noroll:
        ld hl,(ai_dr)
        ld a,h
        rla
        jr c,.dn
        ld de,300
        or a
        sbc hl,de
        jr c,.pnone
        ld a,4
        call pitch_up
        jr .pnone
.dn:    ; player below our wings: if they are behind us, keep looping up
        ld hl,(ai_dn)
        bit 7,h
        ld a,4
        jr z,.dn2
        call pitch_up
        jr .pnone
.dn2:   ld hl,(ai_dr)
        ld de,300
        add hl,de
        jr c,.pnone
        ld a,4
        call pitch_down
.pnone: ld a,(ix+O_AIM)                 ; a seeker to spare?
        or a
        jr z,.nosk
        ld a,(ix+O_TYPE)
        cp T_MANTIS
        jr nz,.nosk
        ld hl,(ai_dn)
        bit 7,h
        jr nz,.nosk
        call rand
        cp 5
        call c,pirate_seeker
.nosk:  ; fire when lined up and in range
        ld a,(ix+O_CD)
        or a
        ret nz
        ld hl,(ai_dn)
        bit 7,h
        ret nz
        srl h
        rr l
        srl h
        rr l                            ; dn/4
        ex de,hl
        ld hl,(ai_ds)
        call abs_hl
        or a
        sbc hl,de
        ret nc
        ld hl,(ai_dr)
        call abs_hl
        or a
        sbc hl,de
        ret nc
        call obj_dist
        ld de,2400
        or a
        sbc hl,de
        ret nc
        ; fire!
        call rand
        and 15
        add a,24
        ld (ix+O_CD),a
        set 0,(ix+O_FLAG)               ; draw the beam this frame
        ld a,(shield)
        sub 6
        jr nc,.sh
        ld b,a                          ; shields gone: energy takes it
        ld a,(energy)
        add a,b
        jr c,$+3
        xor a
        ld (energy),a
        xor a
.sh:    ld (shield),a
        ld a,3
        ld (hitflash),a
        ld hl,SFX_OUCH
        ld a,5
        jp sfx

; ---------------------------------------------------------------------
; explode: IX becomes debris
; ---------------------------------------------------------------------
explode:
        ld (ix+O_TYPE),T_DEBRIS
        ld (ix+O_TMR),0
        ld hl,SFX_BOOM
        ld a,6
        jp sfx

; ---------------------------------------------------------------------
; laser_hit: the nearest ship whose outline covers the crosshair
; ---------------------------------------------------------------------
laser_hit:
        ld hl,0
        ld (hit_obj),hl
        ld hl,7FFFh
        ld (hit_z),hl
        ld ix,objects+OBJSZ
        ld b,MAXOBJ-1
.o:     push bc
        ld a,(ix+O_TYPE)
        cp T_DART
        jr c,.n
        cp T_DEBRIS
        jr nc,.n
        call obj_screen                 ; C if in front: psx/psy, A = radius px
        jr nc,.n
        ld c,a
        ld hl,(psx)
        ld de,-CX
        add hl,de
        call abs_hl
        ld a,h
        or a
        jr nz,.n
        ld a,c
        cp l
        jr c,.n
        ld hl,(psy)
        ld de,-CY
        add hl,de
        call abs_hl
        ld a,h
        or a
        jr nz,.n
        ld a,c
        cp l
        jr c,.n
        ld l,(ix+O_Z)                   ; nearer than the best so far?
        ld h,(ix+O_Z+1)
        ld de,(hit_z)
        or a
        sbc hl,de
        jr nc,.n
        add hl,de
        ld (hit_z),hl
        ld (hit_obj),ix
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ld hl,(hit_obj)
        ld a,h
        or l
        ret z
        push hl
        pop ix
        ld hl,SFX_HIT
        ld a,3
        call sfx
        ld a,(ix+O_TYPE)
        cp T_WARDEN
        jr nz,.notcop
        bit 1,(ix+O_FLAG)
        jr nz,.notcop
        ld a,64                         ; shooting the police
        call legal_add
        push ix
        call police_angry
        pop ix
        ld hl,txt_copshot
        call message
.notcop:
        ld a,(has_twin)
        or a
        jr z,.one
        dec (ix+O_HP)
        jr z,.dead
.one:   dec (ix+O_HP)
        ret nz
.dead:  ; destroyed: bounty for pirates
        ld a,(ix+O_TYPE)
        cp T_SEEKER
        jp z,explode
        cp T_WARDEN
        jp z,explode
        cp T_HAULER
        push af
        call explode
        pop af
        jr z,.trader
        ld hl,kills
        inc (hl)
        ld de,150                       ; 15.0 credits, Mantis 25.0
        ld a,(ix+O_SPD)
        cp 13
        jr nc,$+5
        ld de,250
        call cr_add
        ld hl,txt_kill
        jp message
.trader:
        ld a,32
        call legal_add
        ld hl,txt_trader
        jp message

; obj_screen: IX -> psx, psy of its centre; A = radius in dots (min 1).
; NC if behind the near plane.
obj_screen:
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        call z_ok
        ret nc
        push ix
        pop hl
        inc hl
        inc hl
        call load_v
        call project
        call obj_model
        ld a,(mrad)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                       ; radius * 32
        ld e,(ix+O_Z)
        ld d,(ix+O_Z+1)
        call div16u
        ld a,h
        or a
        ld a,l
        jr z,$+4
        ld a,0FFh
        inc a
        jr nz,$+3
        dec a
        scf
        ret

; ---------------------------------------------------------------------
; spawning: pirates and traders arrive from deep space
; ---------------------------------------------------------------------
spawn:
        ld hl,spawn_t
        dec (hl)
        ret nz
        call gov_a                      ; peaceful systems: fewer arrivals
        add a,a
        add a,a
        add a,a
        ld b,a
        call rand
        and 127
        add a,60
        add a,b
        ld (spawn_t),a
        ; free slot?
        ld ix,objects+OBJSZ
        ld b,MAXOBJ-1
.f:     ld a,(ix+O_TYPE)
        or a
        jr z,.got
        ld de,OBJSZ
        add ix,de
        djnz .f
        ret
.got:   call rand                       ; position: ahead, scattered
        ld e,a
        call sext_e
        ex de,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,bc
        add hl,bc                       ; x11
        ld (ix+O_X),l
        ld (ix+O_X+1),h
        call rand
        ld e,a
        call sext_e
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ix+O_Y),l
        ld (ix+O_Y+1),h
        call rand
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,3600
        add hl,de
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        xor a
        ld (ix+O_FLAG),a
        ld (ix+O_TMR),a
        ld (ix+O_CD),60
        ld (ix+O_EV),a
        ld (ix+O_AIM),a
        call gov_a                      ; police patrol orderly systems
        cp 3
        jr c,.nocop
        call rand
        cp 50
        jr nc,.nocop
        call warden_init
        jp ori_toward
.nocop: call gov_a                      ; and more of them are traders
        add a,a
        add a,a
        add a,a
        add a,a
        add a,50
        ld b,a
        call rand
        cp b
        jr c,.trader
        cp 170
        jr c,.mantis
        ld (ix+O_TYPE),T_DART
        ld (ix+O_SPD),14
        ld (ix+O_HP),2
        jr .pir
.mantis:
        ld (ix+O_TYPE),T_MANTIS
        ld (ix+O_SPD),11
        ld (ix+O_HP),4
        ld (ix+O_AIM),1                 ; carries a seeker
.pir:   call ori_toward
        ld hl,txt_contact
        jp message
.trader:
        ld (ix+O_TYPE),T_HAULER
        ld (ix+O_SPD),6
        ld (ix+O_HP),5
        jp ori_cross

; shields and energy recharge
regen:
        ld a,(state)
        or a
        ret nz
        ld a,(frame)
        and 7
        ret nz
        ld hl,energy
        ld a,(hl)
        cp 64
        jr nc,.s
        inc (hl)
.s:     ld a,(has_booster)
        or a
        ld a,(frame)
        jr z,$+4
        add a,a
        and 15
        ret nz
        ld hl,shield
        ld a,(hl)
        cp 64
        ret nc
        inc (hl)
        inc (hl)
        ret

; ---------------------------------------------------------------------
; docking: work out where we are in the station's own frame
; ---------------------------------------------------------------------
dock_check:
        ld a,(state)
        or a
        ret nz
        call obj_dist
        ld de,400
        or a
        sbc hl,de
        ret nc
        ld l,(ix+O_X)                   ; us relative to the station = -pos, /4
        ld h,(ix+O_X+1)
        call .q
        ld (dbx),a
        ld l,(ix+O_Y)
        ld h,(ix+O_Y+1)
        call .q
        ld (dby),a
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        call .q
        ld (dbz),a
        push ix
        pop iy
        ld de,O_NOSE
        add iy,de
        call dot3                       ; along the axis, units of 4 (x64)
        call .s6
        ld (loc_z),a
        ld de,O_SIDE-O_NOSE
        add iy,de
        call dot3
        call .s6
        ld (loc_x),a
        ld de,O_ROOF-O_SIDE
        add iy,de
        call dot3
        call .s6
        ld (loc_y),a
        ; inside the hull? |z| < 16 (64 units), |x|,|y| < 22
        ld a,(loc_z)
        call .abs
        cp 16
        ret nc
        ld a,(loc_x)
        call .abs
        cp 22
        ret nc
        ld b,a
        ld a,(loc_y)
        call .abs
        cp 22
        ret nc
        ; in the slot?  |x| < 10, |y| < 5
        cp 5
        jr nc,.crash
        ld a,b
        cp 10
        jr nc,.crash
        ld a,1
        ld (state),a
        ret
.crash: ld a,(energy)
        sub 16
        jr nc,$+3
        xor a
        ld (energy),a
        xor a
        ld (speed),a
        ld hl,SFX_CRASH
        ld a,8
        call sfx
        ld hl,txt_bump
        call message
        ld b,3                          ; push the station away: pos *= 2
.p:     push bc
        ld a,b
        dec a
        add a,a
        add a,O_X
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de
        sla (hl)
        inc hl
        rl (hl)
        pop bc
        djnz .p
        ret
; A = -HL/4 clamped to a byte
.q:     call neg_hl
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ret
; A = HL / 64 (signed)
.s6:    add hl,hl
        add hl,hl
        ld a,h
        ret
.abs:   or a
        ret p
        neg
        ret

; ---------------------------------------------------------------------
; message: HL = text for the top line (shown ~3 s)
; ---------------------------------------------------------------------
message:
        push hl
        ld b,MSG_ROW
        ld c,1
        ld a,BLUE<<4
        call clear_rows
        pop hl
        ld c,MSG_ROW
        ld a,YELLOW<<4
        call print_centre
        ld a,50
        ld (msg_t),a
        ret

msg_tick:
        ld hl,msg_t
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret nz
        ld b,MSG_ROW
        ld c,1
        ld a,BLUE<<4
        jp clear_rows

txt_launch:     db "LAUNCHED FROM ",0
txt_arrive:     db "ARRIVED AT ",0
txt_noTarget:   db "NO TARGET - SET ONE ON THE CHART",0
txt_range:      db "TARGET OUT OF RANGE - REFUEL",0
txt_count:      db "HYPERSPACE COUNTDOWN...",0
txt_dead:       db "SHIP DESTROYED",0
txt_kill:       db "PIRATE DESTROYED - BOUNTY PAID",0
txt_trader:     db "TRADER DESTROYED - YOU ARE WANTED",0
txt_contact:    db "CONTACT: PIRATE INBOUND",0
txt_bump:       db "COLLISION - USE THE PORT!",0

; ---------------------------------------------------------------------
; render: planet, dust, ships, crosshair, lasers
; ---------------------------------------------------------------------
render:
        call draw_planet
        ld hl,dust
        ld b,NDUST
.d:     push bc
        push hl
        call load_v
        ld hl,(vz_)
        call z_ok
        jr nc,.nd
        call project
        ld hl,(psx)                     ; off the view: a new particle
        ld de,(psy)
        ld a,h
        or d
        jr nz,.respawn
        ld a,l
        cp VW
        jr nc,.respawn
        ld a,e
        cp VH
        jr nc,.respawn
        ld b,l
        ld c,e
        call plot
        jr .nd
.respawn:
        pop hl
        push hl
        call dust_new
.nd:    pop hl
        ld de,6
        add hl,de
        pop bc
        djnz .d
        ld ix,objects
        ld b,MAXOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_DEBRIS
        jr nz,.sh
        call draw_debris
        jr .n
.sh:    call draw_obj
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ld a,(state)
        or a
        ret nz
        ; crosshair
        ld bc,(CX-4)*256+CY
        call plot
        ld b,CX-3
        call plot
        ld b,CX+2
        call plot
        ld b,CX+3
        call plot
        ld bc,CX*256+CY-3
        call plot
        ld c,CY-2
        call plot
        ld c,CY+2
        call plot
        ld c,CY+3
        call plot
        ld a,(laser_on)
        or a
        ret z
        ld hl,10
        ld (lx0),hl
        ld hl,VH-1
        ld (ly0),hl
        ld hl,CX-1
        ld (lx1),hl
        ld hl,CY+1
        ld (ly1),hl
        call line16
        ld hl,VW-11
        ld (lx0),hl
        ld hl,VH-1
        ld (ly0),hl
        ld hl,CX+1
        ld (lx1),hl
        ld hl,CY+1
        ld (ly1),hl
        jp line16

draw_planet:
        ld hl,(planet+4)
        ld de,-2000
        add hl,de
        bit 7,h
        ret nz                          ; behind (or too close to draw)
        ld hl,planet
        call load_v
        call project
        ld hl,(vz_)                     ; r = R*32/z = R / (z/32)
        ld b,5
.s:     srl h
        rr l
        djnz .s
        ex de,hl
        ld hl,PLANET_R
        call div16u
        ld a,h
        or a
        ret nz
        ld a,l
        cp 120
        ret nc
        cp 2
        jr nc,.c
        ld hl,(psx)
        ld de,(psy)
        jp plot_clip
.c:     ld hl,(psx)
        ld (ccx),hl
        ld hl,(psy)
        ld (ccy),hl
        jp circle

draw_debris:
        call obj_screen                 ; uses the model radius: fine for a size
        ret nc
        ld a,(ix+O_TMR)                 ; r = tmr * 320 / z
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de                       ; x5
        ld b,6
.m:     add hl,hl
        djnz .m                         ; x320
        ld e,(ix+O_Z)
        ld d,(ix+O_Z+1)
        call div16u
        ld a,h
        or a
        jr nz,.big
        ld a,l
        cp 60
        jr c,.ok
.big:   ld a,60
.ok:    ld (deb_r),a
        ld iy,DEBRIS
        ld b,16
.p:     push bc
        ld a,(deb_r)
        ld c,a
        ld b,(iy+0)
        call mul8s
        call .s3
        ld de,(psx)
        add hl,de
        push hl
        ld a,(deb_r)
        ld c,a
        ld b,(iy+1)
        call mul8s
        call .s3
        ld de,(psy)
        add hl,de
        ex de,hl
        pop hl
        call plot_clip
        inc iy
        inc iy
        pop bc
        djnz .p
        ret
.s3:    sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ret

; ---------------------------------------------------------------------
; obj_model: mdl = model of IX's type, mrad = its radius
; ---------------------------------------------------------------------
obj_model:
        ld a,(ix+O_TYPE)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,MODEL_TAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (mdl),hl
        inc hl
        inc hl
        ld a,(hl)
        ld (mrad),a
        ret

MODEL_TAB:
        dw MDL_STATION,MDL_DART,MDL_MANTIS,MDL_HAULER,MDL_WARDEN,MDL_SEEKER,MDL_DART

; ---------------------------------------------------------------------
; draw_obj: transform and draw IX's wireframe
; ---------------------------------------------------------------------
draw_obj:
        call obj_model
        ld l,(ix+O_Z)                   ; nothing in front of the near plane?
        ld h,(ix+O_Z+1)
        ld a,(mrad)
        ld e,a
        ld d,0
        add hl,de
        ld de,-NEAR
        add hl,de
        bit 7,h
        ret nz
        ; far away: a dot
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        ld de,-DOTZ
        ld a,(ix+O_TYPE)
        cp T_STATION
        jr nz,$+5
        ld de,-2*DOTZ
        add hl,de
        bit 7,h
        jr nz,.full
        call obj_screen
        ret nc
        ld hl,(psx)
        ld de,(psy)
        call plot_clip
        jp beam
.full:  ; matrix rows: X = (side.x, roof.x, nose.x) ...
        ld a,(ix+O_SIDE+1)
        ld (mtx+0),a
        ld a,(ix+O_ROOF+1)
        ld (mtx+1),a
        ld a,(ix+O_NOSE+1)
        ld (mtx+2),a
        ld a,(ix+O_SIDE+3)
        ld (mtx+3),a
        ld a,(ix+O_ROOF+3)
        ld (mtx+4),a
        ld a,(ix+O_NOSE+3)
        ld (mtx+5),a
        ld a,(ix+O_SIDE+5)
        ld (mtx+6),a
        ld a,(ix+O_ROOF+5)
        ld (mtx+7),a
        ld a,(ix+O_NOSE+5)
        ld (mtx+8),a
        ld hl,(mdl)
        ld a,(hl)
        ld (nv),a
        inc hl
        ld a,(hl)
        ld (ne),a
        inc hl
        inc hl
        push hl
        pop iy                          ; IY -> vertices
        xor a
        ld (vi),a
.v:     ld hl,mtx
        call xrow
        push hl
        ld l,(ix+O_X)
        ld h,(ix+O_X+1)
        add hl,de
        ld (vx_),hl
        pop hl
        call xrow
        push hl
        ld l,(ix+O_Y)
        ld h,(ix+O_Y+1)
        add hl,de
        ld (vy_),hl
        pop hl
        call xrow
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        add hl,de
        ld (vz_),hl
        ld a,(vi)                       ; store view coords
        ld hl,TVX
        ld de,(vx_)
        call putw
        ld a,(vi)
        ld hl,TVY
        ld de,(vy_)
        call putw
        ld a,(vi)
        ld hl,TVZ
        ld de,(vz_)
        call putw
        ld hl,(vz_)
        call z_ok
        jr nc,.behind
        call project
        ld a,(vi)
        ld hl,TSX
        ld de,(psx)
        call putw
        ld a,(vi)
        ld hl,TSY
        ld de,(psy)
        call putw
.behind:
        inc iy
        inc iy
        inc iy
        ld a,(vi)
        add a,2
        ld (vi),a
        srl a
        ld hl,nv
        cp (hl)
        jp c,.v
        ; edges
        ld a,(ne)
        ld b,a
.e:     push bc
        ld a,(iy+0)
        ld (ea),a
        ld a,(iy+1)
        ld (eb),a
        push iy
        call draw_edge
        pop iy
        inc iy
        inc iy
        pop bc
        djnz .e
        call obj_screen
        ret nc
; enemy laser beam from the ship to the bottom of the view
beam:
        bit 0,(ix+O_FLAG)
        ret z
        ld hl,(psx)
        ld (lx0),hl
        ld hl,(psy)
        ld (ly0),hl
        call rand
        and 15
        add a,CX-8
        ld l,a
        ld h,0
        ld (lx1),hl
        ld hl,VH-1
        ld (ly1),hl
        jp line16

; xrow: DE = (v.x*m0 + v.y*m1 + v.z*m2) / 64 ; HL -> m0, returns HL+3
xrow:
        push hl
        ld b,(iy+0)
        ld c,(hl)
        call mul8s
        ld (acc),hl
        pop hl
        inc hl
        push hl
        ld b,(iy+1)
        ld c,(hl)
        call mul8s
        ld de,(acc)
        add hl,de
        ld (acc),hl
        pop hl
        inc hl
        push hl
        ld b,(iy+2)
        ld c,(hl)
        call mul8s
        ld de,(acc)
        add hl,de
        add hl,hl
        add hl,hl
        ld e,h
        call sext_e
        pop hl
        inc hl
        ret

; word table helpers: HL = table, A = byte offset
putw:
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),e
        inc hl
        ld (hl),d
        ret
getw:
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; ---------------------------------------------------------------------
; draw_edge: vertices (ea), (eb) (byte offsets into the T* tables),
; clipped against the near plane
; ---------------------------------------------------------------------
draw_edge:
        ld a,(ea)
        call .out
        ld (outa),a
        ld a,(eb)
        call .out
        ld b,a
        ld a,(outa)
        ld c,a
        and b
        ret nz                          ; both behind
        ld a,c
        or b
        jr nz,.clip
        ld a,(ea)
        ld hl,TSX
        call getw
        ld (lx0),hl
        ld a,(ea)
        ld hl,TSY
        call getw
        ld (ly0),hl
        ld a,(eb)
        ld hl,TSX
        call getw
        ld (lx1),hl
        ld a,(eb)
        ld hl,TSY
        call getw
        ld (ly1),hl
        jp line16
.clip:  ld a,c                          ; make ea the visible end
        or a
        jr z,.ok
        ld a,(ea)
        ld b,a
        ld a,(eb)
        ld (ea),a
        ld a,b
        ld (eb),a
.ok:    ld a,(ea)                       ; md_c = zB - zA, DE = NEAR - zA
        ld hl,TVZ
        call getw
        push hl
        ld a,(eb)
        ld hl,TVZ
        call getw
        pop de
        or a
        sbc hl,de
        ld (md_c),hl
        ld hl,NEAR
        or a
        sbc hl,de
        ld (num_),hl
        ld hl,TVX
        call .interp
        ld (vx_),hl
        ld hl,TVY
        call .interp
        ld (vy_),hl
        ld hl,NEAR
        ld (vz_),hl
        call project
        ld a,(ea)
        ld hl,TSX
        call getw
        ld (lx0),hl
        ld a,(ea)
        ld hl,TSY
        call getw
        ld (ly0),hl
        ld hl,(psx)
        ld (lx1),hl
        ld hl,(psy)
        ld (ly1),hl
        jp line16
; HL = table: returns A + (B - A) * num / md_c
.interp:
        push hl
        ld a,(ea)
        call getw
        ex (sp),hl                      ; (sp) = vA, HL = table
        ld a,(eb)
        call getw
        pop de
        push de
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld de,(num_)
        call muldiv
        pop de
        add hl,de
        ret
; A = offset: A = FFh if that vertex is behind the near plane
.out:   ld hl,TVZ
        call getw
        call z_ok
        sbc a,a
        cpl
        ret

; C set if HL (signed z) >= NEAR.  Clobbers A, DE.
z_ok:
        ld de,-NEAR
        add hl,de
        ld a,h
        cpl
        rla
        ret

; ---------------------------------------------------------------------
; project: (vx_, vy_, vz_), vz_ >= NEAR  ->  psx, psy (signed words)
;   sx = CX + x*32/z, sy = CY - y*32/z
; ---------------------------------------------------------------------
project:
        ld hl,(vx_)
        ld (tx),hl
        ld hl,(vy_)
        ld (ty),hl
        ld hl,(vz_)
        ld (tz),hl
.norm:  ld hl,(tx)                      ; keep |x|, |y| < 1024
        call abs_hl
        ld a,h
        cp 4
        jr nc,.sh
        ld hl,(ty)
        call abs_hl
        ld a,h
        cp 4
        jr c,.go
.sh:    ld hl,tx+1
        sra (hl)
        dec hl
        rr (hl)
        ld hl,ty+1
        sra (hl)
        dec hl
        rr (hl)
        ld hl,(tz)
        srl h
        rr l
        ld a,h
        or l
        jr nz,$+3
        inc l
        ld (tz),hl
        jr .norm
.go:    ld hl,(tx)
        call .q
        ld de,CX
        add hl,de
        ld (psx),hl
        ld hl,(ty)
        call .q
        ex de,hl
        ld hl,CY
        or a
        sbc hl,de
        ld (psy),hl
        ret
; HL (|HL| < 1024) -> HL * 32 / tz, clamped to +-16000
.q:     ld a,h
        push af
        call abs_hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(tz)
        call div16u
        ld a,h
        cp 3Eh
        jr c,.ok
        ld hl,3E80h
.ok:    pop af
        or a
        ret p
        jp neg_hl

; ---------------------------------------------------------------------
; hyperspace: H starts a countdown to the chart's target
; ---------------------------------------------------------------------
hyper_start:
        ld a,(hyper_t)
        or a
        ret nz
        ld a,(target_sys)
        ld b,a
        ld a,(cur_sys)
        cp b
        ld hl,txt_noTarget
        jp z,message
        call target_dist
        ld a,(fuel)
        ld e,a
        ld d,0
        ex de,hl
        or a
        sbc hl,de
        ld hl,txt_range
        jp c,message
        ld a,45
        ld (hyper_t),a
        ld hl,txt_count
        jp message

hyper_tick:
        ld hl,hyper_t
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jr z,.go
        and 15
        ret nz
        ld hl,SFX_BEEP
        ld a,4
        jp sfx
.go:    ld a,(state)
        or a
        ret nz
        ld a,3
        ld (state),a
        ret

; A = government of the current system
gov_a:
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_GOV
        ld a,(hl)
        ret

; copy 0-terminated HL to DE (DE left on the terminator)
strcpy:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr strcpy
