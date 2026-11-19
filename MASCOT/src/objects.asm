; =====================================================================
;  objects.asm - enemies, platforms, the goal prism, shots and effects
;
;  Objects live in OBJS, 32 bytes each, addressed through IX.  The hit box
;  is O_W x O_H cells with (O_X, O_Y) = left column, bottom row; sprite
;  art is the same size as the box (see tools/sprites.py).
; =====================================================================

O_T             equ 0               ; type (0 = free slot)
O_X             equ 1
O_XF            equ 2
O_Y             equ 3
O_YF            equ 4
O_VY            equ 5               ; 16-bit, 1/256 cells per frame
O_DIR           equ 7               ; 0 right, 1 left
O_ST            equ 8
O_TM            equ 9
O_AN            equ 10
O_HP            equ 11
O_COL           equ 12              ; recolour (green -> this colour)
O_W             equ 13
O_H             equ 14
O_P1            equ 15
O_P2            equ 16
O_FL            equ 17
O_FR            equ 18              ; frame to draw (16-bit)
O_GFX           equ 20              ; frame set: R1, R2, L1, L2 (16-bit)
O_FLASH         equ 22
O_SPD           equ 23              ; horizontal speed (fraction per frame)
O_DX            equ 24              ; platforms: moved this frame
O_DY            equ 25
O_HX            equ 26              ; home position
O_HY            equ 27
O_PTS           equ 28              ; score, BCD hundreds
O_GND           equ 29
OSZ             equ 32
MAXOBJ          equ 14

OF_STOMP        equ 01h             ; can be stomped
OF_EAT          equ 02h             ; can be eaten by the tongue
OF_HARM         equ 04h             ; hurts Kiko on contact
OF_PLAT         equ 08h             ; carries Kiko
OF_BOSS         equ 10h
OF_GOAL         equ 20h

; object types (match tools/rooms.py OBJ_TYPES)
OT_WALKER       equ 1
OT_FLYER        equ 2
OT_HOPPER       equ 3
OT_SPIKY        equ 4
OT_BAT          equ 5
OT_SPITTER      equ 6
OT_DROPPER      equ 7
OT_INK          equ 8
OT_PLATH        equ 9
OT_PLATV        equ 10
OT_GOAL         equ 11
OT_BOSS         equ 12
OT_SHOT         equ 13
OT_FX           equ 14

; per type: update handler, flags, speed, points (BCD hundreds), gfx table
OTAB:
        dw 0, 0                  : db 0, 0, 0, 0
        dw upd_walker, OG_WALKER : db OF_STOMP|OF_EAT|OF_HARM, 18h, 01h, 0
        dw upd_flyer, OG_FLYER   : db OF_STOMP|OF_EAT|OF_HARM, 14h, 02h, 0
        dw upd_hopper, OG_HOPPER : db OF_STOMP|OF_EAT|OF_HARM, 0, 02h, 0
        dw upd_walker, OG_SPIKY  : db OF_EAT|OF_HARM, 10h, 03h, 0
        dw upd_bat, OG_BAT       : db OF_STOMP|OF_EAT|OF_HARM, 0, 02h, 0
        dw upd_spitter, OG_SPIT  : db OF_STOMP|OF_HARM, 0, 03h, 0
        dw upd_dropper, OG_DROP  : db OF_HARM, 0, 01h, 0
        dw upd_ink, OG_INK       : db OF_HARM, 0, 05h, 0
        dw upd_plath, OG_PLAT    : db OF_PLAT, 0, 0, 0
        dw upd_platv, OG_PLAT    : db OF_PLAT, 0, 0, 0
        dw upd_goal, OG_GOAL     : db OF_GOAL, 0, 0, 0
        dw boss_update, OG_BOSS  : db OF_BOSS|OF_HARM, 0, 50h, 0
        dw upd_shot, OG_SHOT     : db OF_HARM|OF_EAT, 30h, 0, 0
        dw upd_fx, OG_FX         : db 0, 0, 0, 0
OTSZ            equ 8

; gfx: per world (W1..W4) a frame set R1, R2, L1, L2
OG_WALKER:      dw gs_lady, gs_rocky, gs_cog, gs_knight
OG_FLYER:       dw gs_bee, gs_ember, gs_bird, gs_ghost
OG_HOPPER:      dw gs_frog, gs_frog, gs_frog, gs_frog
OG_SPIKY:       dw gs_snail, gs_snail, gs_snail, gs_snail
OG_BAT:         dw gs_bat, gs_bat, gs_bat, gs_bat
OG_SPIT:        dw gs_spit, gs_spit, gs_spit, gs_spit
OG_DROP:        dw gs_stalac, gs_stalac, gs_stalac, gs_stalac
OG_INK:         dw gs_ink, gs_ink, gs_ink, gs_ink
OG_PLAT:        dw gs_plat, gs_plat, gs_plat, gs_plat
OG_GOAL:        dw gs_prism, gs_prism, gs_prism, gs_prism
OG_BOSS:        dw gs_bb, gs_mole, gs_phantom, gs_baron
OG_SHOT:        dw gs_fire, gs_fire, gs_spark, gs_spark
OG_FX:          dw gs_poof, gs_poof, gs_poof, gs_poof

gs_lady:        dw FR_LADY1_R, FR_LADY2_R, FR_LADY1_L, FR_LADY2_L
gs_rocky:       dw FR_ROCKY1_R, FR_ROCKY2_R, FR_ROCKY1_L, FR_ROCKY2_L
gs_cog:         dw FR_COG1_R, FR_COG2_R, FR_COG1_L, FR_COG2_L
gs_knight:      dw FR_KNIGHT1_R, FR_KNIGHT2_R, FR_KNIGHT1_L, FR_KNIGHT2_L
gs_bee:         dw FR_BEE1_R, FR_BEE2_R, FR_BEE1_L, FR_BEE2_L
gs_ember:       dw FR_EMBER1_R, FR_EMBER2_R, FR_EMBER1_L, FR_EMBER2_L
gs_bird:        dw FR_BIRD1_R, FR_BIRD2_R, FR_BIRD1_L, FR_BIRD2_L
gs_ghost:       dw FR_GHOST1_R, FR_GHOST2_R, FR_GHOST1_L, FR_GHOST2_L
gs_frog:        dw FR_FROG1_R, FR_FROG2_R, FR_FROG1_L, FR_FROG2_L
gs_snail:       dw FR_SNAIL1_R, FR_SNAIL2_R, FR_SNAIL1_L, FR_SNAIL2_L
gs_bat:         dw FR_BAT1_R, FR_BAT2_R, FR_BAT1_L, FR_BAT2_L
gs_spit:        dw FR_SPIT1_R, FR_SPIT2_R, FR_SPIT1_L, FR_SPIT2_L
gs_stalac:      dw FR_STALAC, FR_STALAC, FR_STALAC, FR_STALAC
gs_ink:         dw FR_INK1_R, FR_INK2_R, FR_INK1_L, FR_INK2_L
gs_plat:        dw FR_PLAT, FR_PLAT, FR_PLAT, FR_PLAT
gs_prism:       dw FR_PRISM1, FR_PRISM2, FR_PRISM1, FR_PRISM2
gs_bb:          dw FR_BB_WALK1_R, FR_BB_WALK2_R, FR_BB_WALK1_L, FR_BB_WALK2_L
gs_mole:        dw FR_MOLE1_R, FR_MOLE2_R, FR_MOLE1_L, FR_MOLE2_L
gs_phantom:     dw FR_PHANTOM1, FR_PHANTOM2, FR_PHANTOM1, FR_PHANTOM2
gs_baron:       dw FR_BARON1_R, FR_BARON2_R, FR_BARON1_L, FR_BARON2_L
gs_fire:        dw FR_FIREBALL1_R, FR_FIREBALL2_R, FR_FIREBALL1_L, FR_FIREBALL2_L
gs_spark:       dw FR_SPARK1_R, FR_SPARK2_R, FR_SPARK1_L, FR_SPARK2_L
gs_poof:        dw FR_POOF1, FR_POOF2, FR_POOF1, FR_POOF2

; ---------------------------------------------------------------------
; spawning
; ---------------------------------------------------------------------
objs_clear:
        xor a
        ld (boss_on),a
        ld hl,OBJS
        ld de,OBJS+1
        ld bc,MAXOBJ*OSZ-1
        ld (hl),0
        ldir
        ret

; IX = a free slot (NC), or C if none
obj_alloc:
        ld ix,OBJS
        ld de,OSZ
        ld b,MAXOBJ
.l:     ld a,(ix+O_T)
        or a
        ret z                       ; NC from the 'or'
        add ix,de
        djnz .l
        scf
        ret

spawn_objects:
        call objs_clear
        ld hl,(room_objs)
.l:     ld a,(hl)
        cp 0FFh
        ret z
        push hl
        call obj_alloc
        pop hl
        jr c,.skip
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl
        ld (ix+O_P1),d
        ld (ix+O_P2),e
        call obj_init
        pop hl
        jr .l
.skip:  ld de,5
        add hl,de
        jr .l

; IX = slot, A = type, B = x, C = y.  Sets the standard fields.
obj_init:
        ld d,(ix+O_P1)
        ld e,(ix+O_P2)
        push de
        push ix
        pop hl
        push bc
        ld e,l
        ld d,h
        inc de
        ld (hl),0
        push af
        ld bc,OSZ-1
        ldir
        pop af
        pop bc
        pop de
        ld (ix+O_P1),d
        ld (ix+O_P2),e
        ld (ix+O_T),a
        ld (ix+O_X),b
        ld (ix+O_Y),c
        ld (ix+O_HX),b
        ld (ix+O_HY),c
        ld (ix+O_XF),80h
        ld (ix+O_YF),80h
        ld (ix+O_COL),GREEN
        ld (ix+O_DIR),1             ; enemies start facing Kiko's way in
        ; type table
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,OTAB+2
        add hl,de
        ld e,(hl)                   ; gfx table
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (ix+O_FL),a
        inc hl
        ld a,(hl)
        ld (ix+O_SPD),a
        inc hl
        ld a,(hl)
        ld (ix+O_PTS),a
        ex de,hl
        ld a,(world)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ix+O_GFX),l
        ld (ix+O_GFX+1),h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ix+O_FR),l
        ld (ix+O_FR+1),h
        ld a,(hl)
        ld (ix+O_W),a
        inc hl
        ld a,(hl)
        ld (ix+O_H),a
        ; per-type extras
        ld a,(ix+O_T)
        cp OT_INK
        jr nz,.n1
        ld a,(ix+O_P1)
        ld (ix+O_COL),a
        ret
.n1:    cp OT_PLATH
        jr c,.n2
        cp OT_PLATV+1
        jr nc,.n2
        ld a,(wt+WT_PLATCOL)
        ld (ix+O_COL),a
        ld (ix+O_TM),1
        ret
.n2:    cp OT_HOPPER
        jr nz,.n3
        ld (ix+O_GND),1
        ld (ix+O_TM),40
        ret
.n3:    cp OT_SPITTER
        jr nz,.n4
        ld (ix+O_TM),60
        ret
.n4:    cp OT_BOSS
        jp z,boss_init
        ret

; ---------------------------------------------------------------------
; per-frame update of every object
; ---------------------------------------------------------------------
objects_update:
        ld ix,OBJS
        ld b,MAXOBJ
.l:     push bc
        ld a,(ix+O_T)
        or a
        jr z,.next
        ld (ix+O_DX),0
        ld (ix+O_DY),0
        inc (ix+O_AN)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,OTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,.next
        push de
        jp (hl)
.next:  ld de,OSZ
        add ix,de
        pop bc
        djnz .l
        ret

; standard 2-frame walk animation in the facing direction
obj_frame_std:
        ld a,(ix+O_AN)
        rrca
        rrca
        and 2                       ; frame 0/1 every 8 frames -> byte offset 0/2
        ld e,a
        ld a,(ix+O_DIR)
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
obj_frame_n:                        ; DE = byte offset into the frame set
        ld l,(ix+O_GFX)
        ld h,(ix+O_GFX+1)
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ix+O_FR),l
        ld (ix+O_FR+1),h
        ret

; Z if nothing to stand on under the object
obj_supported:
        ld b,(ix+O_X)
        ld a,(ix+O_Y)
        inc a
        ld c,a
        ld d,(ix+O_W)
        call tflags_row
        and F_SOLID|F_ONEWAY
        ret

; fall when unsupported (cell based, ~0.4 cells per frame).  NZ = falling
obj_gravity:
        call obj_supported
        jr z,.fall
        ld (ix+O_GND),1
        xor a
        ret
.fall:  ld (ix+O_GND),0
        ld a,(ix+O_YF)
        add a,70h
        ld (ix+O_YF),a
        jr nc,.nf
        inc (ix+O_Y)
        ld a,(ix+O_Y)
        cp ROOMH+3
        jr c,.nf
        ld (ix+O_T),0               ; fell out of the room
.nf:    or 1
        ret

; walk along: turn at walls and (if A bit 0 = 1) at ledges.  C = moved
obj_walk:
        ld (ow_ledge),a
        ld a,(ix+O_XF)
        add a,(ix+O_SPD)
        ld (ix+O_XF),a
        ret nc
obj_step:
        ld a,(ix+O_DIR)
        or a
        ld a,(ix+O_X)
        jr nz,.l
        add a,(ix+O_W)
        jr .chk
.l:     dec a
.chk:   ld b,a
        ld c,(ix+O_Y)
        ld d,(ix+O_H)
        call tflags_col
        and F_SOLID
        jr nz,obj_turn
        ld a,(ow_ledge)
        or a
        jr z,.go
        ld a,(ix+O_Y)
        inc a
        ld c,a
        call tflags
        and F_SOLID|F_ONEWAY
        jr z,obj_turn
.go:    ld a,(ix+O_DIR)
        or a
        jr nz,.gl
        inc (ix+O_X)
        scf
        ret
.gl:    dec (ix+O_X)
        scf
        ret
obj_turn:
        ld a,(ix+O_DIR)
        xor 1
        ld (ix+O_DIR),a
        or a
        ret

; vertical physics with gravity A (per frame): lands on solid/one-way,
; bonks on solid.  Sets O_GND.
obj_move_v:
        ld e,a
        ld d,0
        ld l,(ix+O_VY)
        ld h,(ix+O_VY+1)
        add hl,de
        ld a,h
        cp 1
        jr c,.cap                   ; < 1 cell per frame (or rising)
        bit 7,a
        jr nz,.cap
        ld hl,0A0h
.cap:   ld (ix+O_VY),l
        ld (ix+O_VY+1),h
        ld d,(ix+O_Y)
        ld e,(ix+O_YF)
        add hl,de
        ld a,h
        cp (ix+O_Y)
        jr nz,.cross
        ld (ix+O_YF),l
        ret
.cross: ld (ix+O_YF),l
        bit 7,(ix+O_VY+1)
        jr nz,.up
        ld a,(ix+O_Y)               ; down
        inc a
        cp ROOMH+3
        jr c,.dn
        ld (ix+O_T),0
        ret
.dn:    ld c,a
        ld b,(ix+O_X)
        ld d,(ix+O_W)
        call tflags_row
        and F_SOLID|F_ONEWAY
        jr nz,.land
        inc (ix+O_Y)
        ret
.land:  ld (ix+O_GND),1
        ld (ix+O_YF),0C0h
        xor a
        ld (ix+O_VY),a
        ld (ix+O_VY+1),a
        ret
.up:    ld a,(ix+O_Y)
        sub (ix+O_H)                ; row above the box
        ld c,a
        ld b,(ix+O_X)
        ld d,(ix+O_W)
        call tflags_row
        and F_SOLID
        jr nz,.bonk
        dec (ix+O_Y)
        ret
.bonk:  xor a
        ld (ix+O_VY),a
        ld (ix+O_VY+1),a
        ld (ix+O_YF),a
        ret

; A = 0 if Kiko is to the right of the object's centre, else 1
obj_face_hero:
        ld a,(ix+O_W)
        srl a
        add a,(ix+O_X)
        ld b,a
        ld a,(kx)
        inc a
        cp b
        ld a,0
        ret nc
        inc a
        ret

; ---------------------------------------------------------------------
; behaviours
; ---------------------------------------------------------------------
upd_walker:
        call obj_gravity
        jr nz,.fr
        ld a,1
        call obj_walk
.fr:    jp obj_frame_std

upd_flyer:
        ld a,(ix+O_XF)
        add a,(ix+O_SPD)
        ld (ix+O_XF),a
        jr nc,.bob
        ; patrol within 6 cells of home
        ld a,(ix+O_X)
        sub (ix+O_HX)
        jp p,.pos
        neg
        cp 6
        jr c,.step
        ld (ix+O_DIR),0
        jr .step
.pos:   cp 6
        jr c,.step
        ld (ix+O_DIR),1
.step:  xor a
        ld (ow_ledge),a
        call obj_step
.bob:   ld a,(ix+O_AN)
        rrca
        rrca
        rrca
        rrca
        and 1
        add a,(ix+O_HY)
        ld (ix+O_Y),a
        jp obj_frame_std

upd_hopper:
        ld a,(ix+O_GND)
        or a
        jr z,.air
        ld de,0
        call obj_frame_n0
        dec (ix+O_TM)
        ret nz
        ; jump at Kiko
        call obj_face_hero
        ld (ix+O_DIR),a
        ld (ix+O_VY),low -120
        ld (ix+O_VY+1),high -120
        ld (ix+O_GND),0
        ld (ix+O_YF),0
        ret
.air:   ld de,2
        call obj_frame_n0
        ld a,(ix+O_AN)
        and 3
        jr nz,.v
        xor a
        ld (ow_ledge),a
        call obj_step
.v:     ld a,12
        call obj_move_v
        ld a,(ix+O_GND)
        or a
        ret z
        call rand
        and 31
        add a,45
        ld (ix+O_TM),a
        ret

; frame DE (0 = first, 2 = second) for the facing direction
obj_frame_n0:
        ld a,(ix+O_DIR)
        add a,a
        add a,a
        add a,e
        ld e,a
        jp obj_frame_n

upd_bat:
        ld a,(ix+O_ST)
        or a
        jr nz,.fly
        ld hl,FR_BATHANG            ; hanging: wait for Kiko below
        ld (ix+O_FR),l
        ld (ix+O_FR+1),h
        ld a,(ky)
        cp (ix+O_Y)
        ret c
        ret z
        ld a,(kx)
        sub (ix+O_X)
        jp p,$+5
        neg
        cp 6
        ret nc
        ld (ix+O_ST),1
        call obj_face_hero
        ld (ix+O_DIR),a
        ret
.fly:   call obj_frame_std
        ld a,(ix+O_AN)
        and 1
        ret nz
        ld a,(ix+O_ST)
        cp 1
        jr nz,.rise
        ; diving: down and across until level with Kiko's head
        ld a,(ky)
        dec a
        cp (ix+O_Y)
        jr c,.turnup
        jr z,.turnup
        ld a,(ix+O_Y)
        inc a
        ld c,a
        ld b,(ix+O_X)
        ld d,(ix+O_W)
        call tflags_row
        and F_SOLID|F_ONEWAY
        jr nz,.turnup
        inc (ix+O_Y)
        jr .across
.turnup:
        ld (ix+O_ST),2
        ret
.rise:  ld a,(ix+O_Y)
        cp (ix+O_HY)
        jr z,.home
        jr c,.home
        dec (ix+O_Y)
.across:
        xor a
        ld (ow_ledge),a
        jp obj_step
.home:  ld (ix+O_ST),0
        ret

upd_spitter:
        call obj_face_hero
        ld (ix+O_DIR),a
        ld de,0
        ld a,(ix+O_TM)
        cp 20
        jr nc,$+5
        ld de,2                     ; mouth glows before a shot
        call obj_frame_n0
        dec (ix+O_TM)
        ret nz
        ld (ix+O_TM),110
        ld a,(kx)                   ; only when Kiko is within 18 columns
        sub (ix+O_X)
        jp p,$+5
        neg
        cp 18
        ret nc
        ld a,(ix+O_DIR)
        ld (spit_dir),a
        ld b,(ix+O_X)
        or a
        jr z,.r
        dec b
        jr .sp
.r:     inc b
.sp:    ld a,(ix+O_Y)
        dec a
        ld c,a
        push ix
        push bc
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

upd_shot:
        call obj_frame_std
        ld a,(ix+O_XF)
        add a,(ix+O_SPD)
        ld (ix+O_XF),a
        ret nc
        ld a,(ix+O_DIR)
        or a
        ld a,(ix+O_X)
        jr nz,.l
        inc a
        jr .c
.l:     dec a
.c:     ld (ix+O_X),a
        cp ROOMW
        jr nc,.gone
        ld b,a
        ld c,(ix+O_Y)
        call tflags
        and F_SOLID
        ret z
.gone:  jp obj_poof

upd_dropper:
        ld a,(ix+O_ST)
        or a
        jr nz,.act
        ld a,(ky)                   ; Kiko passing underneath?
        cp (ix+O_Y)
        ret c
        ld a,(kx)
        inc a
        sub (ix+O_X)
        cp 4
        ret nc
        ld (ix+O_ST),1
        ld (ix+O_TM),16
        ret
.act:   cp 1
        jr nz,.fall
        ld a,(ix+O_TM)              ; shake
        and 2
        ld (ix+O_FLASH),a
        dec (ix+O_TM)
        ret nz
        ld (ix+O_ST),2
        ld hl,SFX_DROP
        ld a,1
        jp sfx
.fall:  ld a,14
        call obj_move_v
        ld a,(ix+O_GND)
        or a
        ret z
        jp obj_poof

upd_ink:
        call obj_frame_std
        ; camouflage: an inkblot can't see Kiko in its own colour
        call hero_colour
        cp (ix+O_COL)
        jr nz,.hunt
        ld (ix+O_FL),OF_STOMP|OF_EAT
        ret
.hunt:  ld (ix+O_FL),OF_HARM
        ld a,(ix+O_AN)
        and 7
        jr nz,.v
        call obj_face_hero
        ld (ix+O_DIR),a
        or a
        jr nz,.l
        inc (ix+O_X)
        jr .v
.l:     dec (ix+O_X)
.v:     ld a,(ix+O_AN)
        and 15
        ret nz
        ld a,(ky)
        cp (ix+O_Y)
        ret z
        jr c,.up
        inc (ix+O_Y)
        ret
.up:    dec (ix+O_Y)
        ret

; A = Kiko's current colour
hero_colour:
        push hl
        push de
        ld a,(hcol)
        ld e,a
        ld d,0
        ld hl,CIDX
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

upd_plath:
        dec (ix+O_TM)
        ret nz
        ld (ix+O_TM),7
        ld a,(ix+O_DIR)
        or a
        jr nz,.l
        ld a,(ix+O_X)
        cp (ix+O_P2)
        jr nc,.turn
        inc (ix+O_X)
        ld (ix+O_DX),1
        ret
.l:     ld a,(ix+O_P1)
        cp (ix+O_X)
        jr nc,.turn
        dec (ix+O_X)
        ld (ix+O_DX),-1
        ret
.turn:  ld a,(ix+O_DIR)
        xor 1
        ld (ix+O_DIR),a
        ret

upd_platv:
        dec (ix+O_TM)
        ret nz
        ld (ix+O_TM),9
        ld a,(ix+O_DIR)
        or a
        jr z,.down                  ; DIR 1 = up (starts upward)
        ld a,(ix+O_P1)
        cp (ix+O_Y)
        jr nc,.turn
        dec (ix+O_Y)
        ld (ix+O_DY),-1
        ret
.down:  ld a,(ix+O_Y)
        cp (ix+O_P2)
        jr nc,.turn
        inc (ix+O_Y)
        ld (ix+O_DY),1
        ret
.turn:  ld a,(ix+O_DIR)
        xor 1
        ld (ix+O_DIR),a
        ret

upd_goal:
        ld a,(ix+O_AN)
        rrca
        rrca
        and 2
        ld e,a
        ld d,0
        call obj_frame_n
        ld a,(ix+O_AN)              ; bob
        rrca
        rrca
        rrca
        rrca
        and 1
        add a,(ix+O_HY)
        ld (ix+O_Y),a
        ret

upd_fx:
        ld a,(ix+O_AN)
        rrca
        rrca
        and 2
        ld e,a
        ld d,0
        call obj_frame_n
        ld a,(ix+O_AN)
        cp 12
        ret c
        ld (ix+O_T),0
        ret

; turn the object into a puff of smoke
obj_poof:
        ld a,(ix+O_T)
        cp OT_BOSS
        ret z
        ld (ix+O_T),OT_FX
        ld (ix+O_AN),0
        ld (ix+O_FL),0
        ld (ix+O_FLASH),0
        ld (ix+O_COL),GREEN
        ld a,(ix+O_W)               ; puff at the middle of the old box
        srl a
        add a,(ix+O_X)
        ld (ix+O_X),a
        ld a,(ix+O_H)
        srl a
        ld b,a
        ld a,(ix+O_Y)
        sub b
        ld (ix+O_Y),a
        ld (ix+O_W),1
        ld (ix+O_H),1
        ld hl,gs_poof
        ld (ix+O_GFX),l
        ld (ix+O_GFX+1),h
        ld hl,FR_POOF1
        ld (ix+O_FR),l
        ld (ix+O_FR+1),h
        ret

; defeated by Kiko: score, puff
obj_defeat:
        ld d,(ix+O_PTS)
        ld e,0
        call add_score
        jp obj_poof

; ---------------------------------------------------------------------
; Kiko versus objects
; ---------------------------------------------------------------------
; C if Kiko's box overlaps the object's
obj_overlap:
        ld a,(kx)
        inc a
        sub (ix+O_X)
        jr c,.no                    ; Kiko entirely left of it
        ld a,(ix+O_X)
        add a,(ix+O_W)
        dec a
        ld b,a
        ld a,(kx)
        cp b
        jr z,.x
        jr nc,.no                   ; Kiko right of it
.x:     ld a,(ix+O_Y)
        sub (ix+O_H)
        inc a                       ; object's top row
        ld (ov_top),a
        ld b,a
        ld a,(ky)
        cp b
        jr c,.no                    ; Kiko above it
        ld a,(ky)
        sub 2                       ; Kiko's top row
        ld b,a
        ld a,(ix+O_Y)
        cp b
        jr c,.no                    ; object above Kiko
        scf
        ret
.no:    or a
        ret

objects_interact:
        ld a,(hstate)
        cp HS_DEAD
        ret nc
        ld ix,OBJS
        ld b,MAXOBJ
.l:     push bc
        ld a,(ix+O_T)
        or a
        jr z,.next
        ld a,(ix+O_FL)
        bit 6,a                     ; OF_HIDE
        jr nz,.next
        and OF_STOMP|OF_HARM|OF_GOAL|OF_BOSS
        jr z,.next
        call obj_overlap
        jr nc,.next
        ld a,(ix+O_FL)
        and OF_GOAL
        jr z,.notgoal
        ld a,1
        ld (level_done),a
        jr .next
.notgoal:
        ; stomp: falling onto the top row
        ld a,(hvy+1)
        or a
        jp m,.hit
        ld a,(hvy)
        or a
        jr z,.hit
        ld a,(ky)
        ld hl,ov_top
        cp (hl)
        jr nz,.hit
        ld a,(ix+O_FL)
        and OF_STOMP|OF_BOSS
        jr z,.hit
        call do_stomp
        jr .next
.hit:   ld a,(ix+O_FL)
        and OF_HARM
        jr z,.next
        call obj_face_hero          ; knocked away from it
        call hero_hurt
.next:  ld de,OSZ
        add ix,de
        pop bc
        djnz .l
        ret

do_stomp:
        ld hl,STOMPV
        ld a,(hkeys)
        and K_JUMP
        jr z,$+5
        ld hl,STOMPV_HI
        ld (hvy),hl
        xor a
        ld (hgnd),a
        ld a,0C0h
        ld (kyf),a
        ld a,(ix+O_FL)
        and OF_BOSS
        jp nz,boss_stomp
        ld hl,SFX_STOMP
        ld a,2
        call sfx
        jp obj_defeat

; IX = object whose box holds the cell (B, C): C flag if found
obj_at_point:
        ld ix,OBJS
        ld e,MAXOBJ
.l:     ld a,(ix+O_T)
        or a
        jr z,.n
        cp OT_FX
        jr z,.n
        ld a,(ix+O_FL)
        and OF_PLAT|OF_GOAL|OF_HIDE
        jr nz,.n
        ld a,b
        sub (ix+O_X)
        jr c,.n
        cp (ix+O_W)
        jr nc,.n
        ld a,(ix+O_Y)
        sub c
        jr c,.n
        cp (ix+O_H)
        jr nc,.n
        scf
        ret
.n:     push de
        ld de,OSZ
        add ix,de
        pop de
        dec e
        jr nz,.l
        or a
        ret

tongue_hit_obj:
        ld a,(ix+O_FL)
        and OF_BOSS
        jp nz,boss_tongue
        ld a,(ix+O_FL)
        and OF_EAT
        jr z,.bonk
        ld hl,SFX_GULP
        ld a,2
        call sfx
        jp obj_defeat
.bonk:  ld (ix+O_FLASH),6
        ld hl,SFX_BUMP
        ld a,1
        jp sfx

; ---------------------------------------------------------------------
; moving platforms
; ---------------------------------------------------------------------
; C if a platform's top row is right under Kiko's feet (ky + 1);
; E = its slot number
plat_under:
plat_under_next:
        ld ix,OBJS
        ld e,0
.l:     ld a,(ix+O_FL)
        and OF_PLAT
        jr z,.n
        ld a,(ix+O_T)
        or a
        jr z,.n
        ld a,(ky)
        inc a
        cp (ix+O_Y)
        jr nz,.n
        ld a,(kx)
        inc a
        sub (ix+O_X)
        jr c,.n
        cp 5                        ; kx+1 - px in 0..4 (platform 4 wide)
        jr nc,.n
        scf
        ret
.n:     push de
        ld de,OSZ
        add ix,de
        pop de
        inc e
        ld a,e
        cp MAXOBJ
        jr c,.l
        or a
        ret

; move Kiko with the platform he stands on
plat_carry:
        ld a,(hplat)
        cp 0FFh
        ret z
        ld b,a
        ld ix,OBJS
        ld de,OSZ
        or a
        jr z,.got
.f:     add ix,de
        djnz .f
.got:   ld a,(hgnd)
        or a
        jr z,.off
        ld a,(ix+O_DX)
        or a
        jr z,.dy
        jp m,.left
        call hero_try_right
        jr .dy
.left:  call hero_try_left
.dy:    ld a,(ix+O_DY)
        or a
        ret z
        jp m,.up
        ld hl,ky
        inc (hl)
        ret
.up:    ld a,(ky)
        sub 3
        ld c,a
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        and F_SOLID
        jr nz,.off
        ld hl,ky
        dec (hl)
        ret
.off:   ld a,0FFh
        ld (hplat),a
        xor a
        ld (hgnd),a
        ret

; ---------------------------------------------------------------------
; drawing
; ---------------------------------------------------------------------
objects_draw:
        ld ix,OBJS
        ld b,MAXOBJ
.l:     push bc
        ld a,(ix+O_T)
        or a
        jr z,.next
        bit 6,(ix+O_FL)             ; OF_HIDE
        jr nz,.next
        ld a,(ix+O_FLASH)
        or a
        jr z,.col
        dec (ix+O_FLASH)
        and 2
        ld a,high REMAPW
        jr nz,.draw
.col:   ld a,(ix+O_COL)
        add a,high REMAP
.draw:  ld l,(ix+O_FR)
        ld h,(ix+O_FR+1)
        ld b,(ix+O_X)
        ld c,(ix+O_Y)
        call draw_sprite
.next:  ld de,OSZ
        add ix,de
        pop bc
        djnz .l
        ret
