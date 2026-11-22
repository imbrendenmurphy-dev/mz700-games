; =====================================================================
;  fx.asm - full-screen effects for the mixer screens: the launch
;  tunnel, hyperspace and our own ship blowing up.
;
;  The mixer only plays while the program waits, so these effects are
;  cheap on purpose: nine rings of thin quarter-block characters around
;  the view's centre, drawn once, then animated by rewriting their
;  colours (about 500 attribute bytes a frame, a tenth of the frame).
; =====================================================================

NRINGS          equ 9

; ring k (0 = innermost): rows 9-k .. 10+k, columns 18-2k .. 21+2k
; A = k -> HL = VRAM of its top-left cell, B = width, C = height
ring_geom:
        ld e,a
        ld a,VIEW_ROW+8
        sub e
        call row_addr
        ld a,18
        sub e
        sub e
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,e
        add a,a
        add a,a
        add a,4
        ld b,a
        ld a,e
        add a,a
        add a,2
        ld c,a
        ret

; draw ring A's outline characters
ring_chars:
        call ring_geom
        push hl
        ld (hl),0F7h                    ; top: corner, edge, corner
        inc hl
        ld a,b
        sub 2
        ld d,a
.t:     ld (hl),0F3h
        inc hl
        dec a
        jr nz,.t
        ld (hl),0FBh
        pop hl
        ld e,b
        dec e                           ; E = offset of the right side
        ld a,c
        sub 2
        jr z,.bot
.s:     push af                         ; sides
        ld a,l
        add a,40
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),0F5h
        push hl
        ld a,l
        add a,e
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),0FAh
        pop hl
        pop af
        dec a
        jr nz,.s
.bot:   ld a,l                          ; bottom
        add a,40
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),0FDh
        inc hl
        ld a,d
.b:     ld (hl),0FCh
        inc hl
        dec a
        jr nz,.b
        ld (hl),0FEh
        ret

; colour ring A with attribute D, unless it has that colour already
ring_col:
        ld e,a
        push de
        ld d,0
        ld hl,fx_last
        add hl,de
        pop de
        ld a,(hl)
        cp d
        ret z
        ld (hl),d
        ld a,e
        ; fall through
; colour ring A with attribute D
ring_attr:
        push ix
        push de
        call ring_geom
        pop de
        set 3,h
        ld a,d
        push hl
        ld d,b                          ; D = width
.t:     ld (hl),a                       ; top row
        inc hl
        djnz .t
        dec hl
        push hl
        pop ix                          ; IX = right side
        pop hl                          ; HL = left side
        ld e,c
        dec e                           ; rows below the top
        ld bc,40
.s:     add hl,bc
        add ix,bc
        ld (hl),a
        ld (ix+0),a
        dec e
        jr nz,.s
        ld b,d                          ; bottom row
.b:     ld (hl),a
        inc hl
        djnz .b
        pop ix
        ret

; clear the view and draw every ring (in black)
rings_init:
        ld hl,fx_last
        ld b,NRINGS
.l:     ld (hl),0FFh
        inc hl
        djnz .l
        ld a,WHITE<<4
        call cls
        ld c,NRINGS
.r:     dec c
        ld a,c
        push bc
        call ring_chars
        pop bc
        ld a,c
        or a
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; tunnel: HL = 8-colour palette, B = frames, C = 1 rings rush outwards,
; -1 inwards.  The colour of ring k is palette[(k - phase) & 7].
; ---------------------------------------------------------------------
tunnel_fx:
        ld (fx_pal),hl
        ld a,b
        ld (fx_n),a
        ld a,c
        ld (fx_dir),a
        xor a
        ld (fx_ph),a
        call rings_init
.f:     call wait_frame
        ld a,(fx_ph)
        ld hl,fx_dir
        add a,(hl)
        ld (fx_ph),a
        ld c,NRINGS
.r:     dec c
        ld a,(fx_ph)
        ld b,a
        ld a,c
        sub b
        and 7
        ld e,a
        ld d,0
        ld hl,(fx_pal)
        add hl,de
        ld a,(hl)
        add a,a
        add a,a
        add a,a
        add a,a
        ld d,a
        ld a,c
        push bc
        call ring_col
        pop bc
        ld a,c
        or a
        jr nz,.r
        ld hl,fx_n
        dec (hl)
        jr nz,.f
        ret

LAUNCH_PAL:     db WHITE,CYAN,CYAN,BLUE,BLACK,BLACK,BLACK,BLUE
HYPER_PAL:      db WHITE,WHITE,CYAN,CYAN,MAGENTA,MAGENTA,BLUE,BLUE

; ---------------------------------------------------------------------
; the station's tunnel in 3D: hexagonal rings rush at us, turning with
; the station, joined by struts; near ones white, then cyan, then blue.
; On the tone generator, so the drawing has the CPU.
; ---------------------------------------------------------------------
TN_RINGS        equ 6
TN_GAP          equ 64                  ; between rings (world units)
TN_FRAMES       equ 32

launch_fx:                              ; out through the tunnel
dock_fx:                                ; and in again
        call snd_fl
        ld hl,SFX_LAUNCH
        ld a,9
        call sfx
        ld a,WHITE<<4
        call cls
        xor a
        ld (tn_f),a
.f:     call wait_frame
        ld a,(tn_f)                     ; the nearest ring's depth
        add a,a
        add a,a
        add a,a                         ; 8 units a frame
        and TN_GAP-1
        neg
        add a,TN_GAP+40
        ld (tn_z),a
        ld c,0
.r:     push bc
        call tn_ring                    ; ring C: its corners -> TN_X/TN_Y
        pop bc
        push bc
        call tn_draw
        pop bc
        inc c
        ld a,c
        cp TN_RINGS
        jr c,.r
        call present
        ld hl,tn_f
        inc (hl)
        ld a,(hl)
        cp TN_FRAMES
        jr c,.f
        jp snd_fe

; corners of ring C at depth tn_z + C * TN_GAP, turned by the frame
tn_ring:
        ld l,c
        ld h,0
        ld b,6
.c64:   add hl,hl
        djnz .c64                       ; C * 64
        ld a,(tn_z)
        ld e,a
        ld d,0
        add hl,de
        ld (tn_d),hl                    ; depth
        ld b,6
        ld ix,TN_X
        ld hl,TN_ANG
        ld (tn_p),hl
.k:     push bc
        ld hl,(tn_p)                    ; this corner's angle, turned a
        ld a,(tn_f)                     ; step a frame
        add a,(hl)
        inc hl
        ld (tn_p),hl
        and 63
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld de,SPIN
        add hl,de
        ld a,(hl)                       ; side.x = cos (unit 64)
        push hl
        call .proj
        ld de,CX
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        pop hl
        ld de,6
        add hl,de
        ld a,(hl)                       ; nose.x = sin
        call .proj
        ex de,hl
        ld hl,CY
        or a
        sbc hl,de
        ld (ix+12),l
        ld (ix+13),h
        inc ix
        inc ix
        pop bc
        djnz .k
        ret
; HL = A * 48 / depth (signed): a ring of radius 96 units
.proj:  ld b,a
        ld c,48
        call mul8s
        ld a,h
        push af
        call abs_hl
        ld de,(tn_d)
        call div16u
        pop af
        bit 7,a
        ret z
        jp neg_hl

TN_ANG: db 0,11,21,32,43,53             ; six corners in 64ths of a turn

; draw ring C (its corners in TN_X/TN_Y) and struts to the one before
tn_draw:
        ld a,c                          ; colour by depth
        ld hl,TN_COL
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        call set_col
        ld b,6
        ld ix,TN_X
.e:     push bc
        ld l,(ix+0)
        ld h,(ix+1)
        ld (lx0),hl
        ld l,(ix+12)
        ld h,(ix+13)
        ld (ly0),hl
        ld de,2                         ; the next corner (round)
        dec b
        jr nz,$+5
        ld de,-10
        push ix
        pop hl
        add hl,de
        push hl
        pop iy
        ld l,(iy+0)
        ld h,(iy+1)
        ld (lx1),hl
        ld l,(iy+12)
        ld h,(iy+13)
        ld (ly1),hl
        call line16
        pop bc
        push bc
        bit 0,b                         ; struts on every other corner
        jr z,.ns
        ld a,c
        or a
        jr z,.ns
        ld l,(ix+0)
        ld h,(ix+1)
        ld (lx0),hl
        ld l,(ix+12)
        ld h,(ix+13)
        ld (ly0),hl
        ld l,(ix+24)                    ; the same corner, last ring
        ld h,(ix+25)
        ld (lx1),hl
        ld l,(ix+36)
        ld h,(ix+37)
        ld (ly1),hl
        call line16
.ns:    pop bc
        push bc                         ; keep this ring for the next
        ld l,(ix+0)
        ld h,(ix+1)
        ld (ix+24),l
        ld (ix+25),h
        ld l,(ix+12)
        ld h,(ix+13)
        ld (ix+36),l
        ld (ix+37),h
        pop bc
        inc ix
        inc ix
        dec b
        jp nz,.e
        ret

TN_COL: db WHITE,WHITE,CYAN,CYAN,BLUE,BLUE

; ---------------------------------------------------------------------
; death: the camera leaves the cockpit.  The wreck bursts into tumbling
; spars and sparks; the camera pans round it, pulls back and turns to
; the ship that killed us, beyond the wreck.  (The world is frozen; the
; camera orbits by turning the world about the wreck, rotate_world, and
; stands cam_d behind it, shift_z.)
; ---------------------------------------------------------------------
NFRAG           equ 12
FRSZ            equ 18                  ; position, velocity, spar: words
DEATH_FRAMES    equ 60

death_seq:
        call snd_fe
        ld hl,SFX_DEATH
        ld a,9
        call sfx
        ld a,1
        ld (view),a                     ; (no fresh dust: the camera moves)
        ld ix,objects                   ; a fireball, in a free slot
        ld b,MAXOBJ
.fs:    ld a,(ix+O_TYPE)
        or a
        jr z,.free
        ld de,OBJSZ
        add ix,de
        djnz .fs
        jr .nofb
.free:  push ix
        pop hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,OBJSZ-1
        ldir
        ld (ix+O_TYPE),T_DEBRIS
.nofb:  call pick_killer
        ld hl,frags                     ; the pieces, at the wreck
        ld b,NFRAG
.fr:    push bc
        ld b,6
.z:     ld (hl),0
        inc hl
        djnz .z
        ld b,3                          ; velocity -4..3 a frame
.v:     push hl
        call rand
        pop hl
        and 7
        sub 4
        call .sw
        djnz .v
        ld b,3                          ; spar -32..31
.e:     push hl
        call rand
        pop hl
        and 63
        sub 32
        call .sw
        djnz .e
        pop bc
        djnz .fr
        ld hl,120
        ld (cam_d),hl
        xor a
        ld (fx_ph),a
.f:     call wait_frame
        call frag_move
        ld ix,objects                   ; the fireballs grow
        ld b,MAXOBJ
.db:    ld a,(ix+O_TYPE)
        cp T_DEBRIS
        jr nz,.dn
        ld a,(ix+O_TMR)
        cp 24
        jr nc,.dn
        inc (ix+O_TMR)
.dn:    ld de,OBJSZ
        add ix,de
        djnz .db
        ld a,(fx_ph)                    ; the camera: a pan round the
        cp 12                           ; wreck, then round to the killer
        call c,cam_pan
        call nc,cam_aim
        ld hl,(cam_d)                   ; pulling back
        ld de,5
        add hl,de
        ld (cam_d),hl
        ex de,hl
        call shift_z
        call render
        call frag_draw
        ld hl,(cam_d)
        call neg_hl
        ex de,hl
        call shift_z
        call present
        ld hl,fx_ph
        inc (hl)
        ld a,(hl)
        cp DEATH_FRAMES
        jr c,.f
        ret
; A -> a signed word at HL, HL += 2
.sw:    ld (hl),a
        inc hl
        add a,a
        sbc a,a
        ld (hl),a
        inc hl
        ret

; the killer: the last ship to fire on us if it is still there, else
; the nearest ship; 0 if none
pick_killer:
        ld hl,(killer)
        ld a,h
        or l
        jr z,.near
        push hl
        pop ix
        ld a,(ix+O_TYPE)
        call is_ship
        ret c
.near:  ld hl,0
        ld (killer),hl
        dec hl
        ld (kbest),hl
        ld ix,objects
        ld b,MAXOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        call is_ship
        jr nc,.n
        call obj_dist
        ld de,(kbest)
        or a
        sbc hl,de
        jr nc,.n
        add hl,de
        ld (kbest),hl
        ld (killer),ix
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ret
; C if type A is a ship (dart .. warden)
is_ship:
        sub T_DART
        cp T_WARDEN-T_DART+1
        ret

; the opening pan (keeps the carry set)
cam_pan:
        xor a
        ld (ro1),a
        ld a,4
        ld (ro2),a
        call cam_turn
        scf
        ret

; turn the camera (the world, the pieces) towards the killer, beyond
; the wreck: its x, then its y, to 0 with z > 0
cam_aim:
        ld hl,(killer)
        ld a,h
        or l
        jr z,cam_pan                    ; nobody: pan on
        push hl
        pop ix
        ld l,(ix+O_X)
        ld h,(ix+O_X+1)
        xor a
        call .axis
        ld l,(ix+O_Y)
        ld h,(ix+O_Y+1)
        ld a,2
; HL = the component at offset A: turn it into z, faster when far off
.axis:  ld c,4
        bit 7,h
        jr z,.pos
        ld c,a
        ld a,4
.pos:   ld (ro1),a
        ld a,c
        ld (ro2),a
        call abs_hl
        ex de,hl                        ; DE = |component|
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        ld a,3
        bit 7,h
        jr nz,cam_turn                  ; behind the camera: swing
        srl h
        rr l
        srl h
        rr l
        or a
        sbc hl,de
        jr c,cam_turn                   ; over z/4 off: swing
        add hl,de
        srl h
        rr l
        srl h
        rr l
        ld a,5
        or a
        sbc hl,de
        ret nc                          ; lined up
; turn the world and the pieces by k = A in the pair (ro1, ro2)
cam_turn:
        push ix
        call set_rot
        call rotate_world
        ld hl,frags
        ld b,NFRAG*3
.l:     push bc
        push hl
        call rotate_world.vhl
        pop hl
        ld de,6
        add hl,de
        pop bc
        djnz .l
        pop ix
        ret

; DE added to every object's z and the dust's (the camera stands back)
shift_z:
        ld ix,objects
        ld b,MAXOBJ
.o:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        add hl,de
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
.n:     push de
        ld de,OBJSZ
        add ix,de
        pop de
        djnz .o
        ld hl,dust+4
        ld b,NDUST
.d:     ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        ld a,5
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        djnz .d
        ret

; the pieces fly apart, each spar tumbling
frag_move:
        ld hl,frags
        ld b,NFRAG
.l:     push bc
        push hl
        ld d,h                          ; position += velocity
        ld e,l
        ld bc,6
        add hl,bc
        ld b,3
.a:     ld a,(de)
        add a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        adc a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .a
        ld a,3                          ; HL -> the spar: x, y
        call set_rot
        push hl
        ld d,h
        ld e,l
        inc de
        inc de
        call rot_pair
        pop hl
        inc hl                          ; y, z
        inc hl
        ld a,4
        call set_rot
        ld d,h
        ld e,l
        inc de
        inc de
        call rot_pair
        pop hl
        ld de,FRSZ
        add hl,de
        pop bc
        djnz .l
        ret

; the pieces: white and cyan spars
frag_draw:
        ld hl,frags
        ld b,NFRAG
.l:     push bc
        push hl
        ld a,b
        and 1
        ld a,WHITE
        jr z,$+4
        ld a,CYAN
        call set_col
        call poll
        pop hl
        push hl
        ld de,fr_zero
        call .pt
        jr nc,.n
        ld hl,(psx)
        ld (lx0),hl
        ld hl,(psy)
        ld (ly0),hl
        pop hl
        push hl
        ex de,hl
        ld hl,12
        add hl,de
        ex de,hl
        call .pt
        jr nc,.n
        ld hl,(psx)
        ld (lx1),hl
        ld hl,(psy)
        ld (ly1),hl
        call line16
.n:     pop hl
        ld de,FRSZ
        add hl,de
        pop bc
        djnz .l
        ret
; (HL) + (DE), camera-relative, projected: NC if behind the camera
.pt:    ld bc,vx_
        ld a,3
.c:     push af
        ld a,(de)
        add a,(hl)
        ld (bc),a
        inc hl
        inc de
        inc bc
        ld a,(de)
        adc a,(hl)
        ld (bc),a
        inc hl
        inc de
        inc bc
        pop af
        dec a
        jr nz,.c
        ld hl,(vz_)
        ld de,(cam_d)
        add hl,de
        ld (vz_),hl
        call z_ok
        ret nc
        call project
        scf
        ret
fr_zero:        dw 0,0,0
