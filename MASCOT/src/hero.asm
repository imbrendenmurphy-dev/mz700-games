; =====================================================================
;  hero.asm - Kiko: controls, physics, collision, tongue, colour swap
;
;  Position: kx/ky = cell of the hit box (2 wide x 3 tall; kx = left
;  column, ky = bottom row), kxf/kyf = 1/256-cell fractions.  The sprite
;  is drawn at whole cells; the fractions keep acceleration and jump arcs
;  smooth in time.  Speeds are 1/256 cells per frame (50 fps).
; =====================================================================

ACC_G           equ 5               ; ground acceleration
ACC_A           equ 4               ; air acceleration
FRIC_G          equ 6               ; ground friction
FRIC_A          equ 2               ; air drag
SKID            equ 12              ; turning on the ground
MAXV            equ 60              ; top running speed (11.7 cells/s)
G_LO            equ 6               ; gravity while rising with jump held
G_HI            equ 15              ; gravity otherwise
VMAXY           equ 160             ; terminal velocity
JUMPV           equ -128            ; jump: 5.3 cells held, ~1.8 tapped
VINEJV          equ -96
STOMPV          equ -96
STOMPV_HI       equ -150
SPRINGV         equ -176
COYOTE          equ 6
JBUF            equ 7
TMAX            equ 5               ; tongue reach (cells beyond the snout)

HS_NORMAL       equ 0
HS_CLIMB        equ 1
HS_HURT         equ 2
HS_DEAD         equ 3
HS_WIN          equ 4

; animation ids (index into HFRAMES)
HA_STAND        equ 0
HA_BLINK        equ 1
HA_SLEEP        equ 2
HA_RUN1         equ 3
HA_RUN2         equ 4
HA_RUN3         equ 5
HA_JUMP         equ 6
HA_FALL         equ 7
HA_SQUASH       equ 8
HA_TONGUE       equ 9
HA_CLIMB1       equ 10
HA_CLIMB2       equ 11
HA_HURT         equ 12
HA_WIN          equ 13
HA_DEAD         equ 14

HFRAMES:
        dw FR_K_STAND_R, FR_K_STAND_L, FR_K_BLINK_R, FR_K_BLINK_L
        dw FR_K_SLEEP_R, FR_K_SLEEP_L, FR_K_RUN1_R, FR_K_RUN1_L
        dw FR_K_RUN2_R, FR_K_RUN2_L, FR_K_RUN3_R, FR_K_RUN3_L
        dw FR_K_JUMP_R, FR_K_JUMP_L, FR_K_FALL_R, FR_K_FALL_L
        dw FR_K_SQUASH_R, FR_K_SQUASH_L, FR_K_TONGUE_R, FR_K_TONGUE_L
        dw FR_K_CLIMB1_R, FR_K_CLIMB1_L, FR_K_CLIMB2_R, FR_K_CLIMB2_L
        dw FR_K_HURT_R, FR_K_HURT_L, FR_K_WIN_R, FR_K_WIN_L
        dw FR_K_DEAD_R, FR_K_DEAD_L
RUNSEQ: db HA_RUN1, HA_RUN2, HA_RUN3, HA_RUN2

; Kiko's three colours: red, green, blue (index 0-2)
CIDX:   db RED, GREEN, BLUE

; ---------------------------------------------------------------------
; place Kiko: B = x, C = y (feet row), A = facing
; ---------------------------------------------------------------------
hero_place:
        ld (hdir),a
        ld a,b
        ld (kx),a
        ld a,c
        ld (ky),a
        ld a,80h
        ld (kxf),a
        ld (kyf),a
        xor a
        ld (hvx),a
        ld (hstate),a
        ld (hcoy),a
        ld (hjbuf),a
        ld (htngst),a
        ld (htngl),a
        ld (hsquash),a
        ld (hdrop),a
        ld (pending_exit),a
        ld hl,0
        ld (hvy),hl
        ld a,0FFh
        ld (hplat),a
        jp hero_ground_probe

; set hgnd from what is under Kiko's feet now
hero_ground_probe:
        call hero_supported
        ld (hgnd),a
        ret

; ---------------------------------------------------------------------
; per-frame update.  hkeys = this frame's controls.
; ---------------------------------------------------------------------
hero_update:
        ld a,(hkeys)
        ld b,a
        ld a,(hprev)
        cpl
        and b
        ld (hpress),a
        ld a,b
        ld (hprev),a
        ld a,(hstate)
        cp HS_DEAD
        jp z,hero_dead_update
        cp HS_WIN
        jp z,hero_win_update
        ; timers
        ld hl,hinv
        call dec_nz
        ld hl,hsquash
        call dec_nz
        ld hl,hswapf
        call dec_nz
        ld hl,hdrop
        call dec_nz
        ld hl,hcoy
        call dec_nz
        ; jump buffer
        ld a,(hpress)
        and K_JUMP
        jr z,.nob
        ld a,JBUF
        ld (hjbuf),a
        jr .b1
.nob:   ld hl,hjbuf
        call dec_nz
.b1:    ld a,(hstate)
        cp HS_HURT
        jr nz,.ctl
        ld hl,htimer                ; knocked back: no control for a moment
        dec (hl)
        jr nz,.nocontrol
        xor a
        ld (hstate),a
        jr .ctl
.nocontrol:
        xor a
        ld (hkeys),a
        ld (hpress),a
        ld (hjbuf),a
.ctl:   ld a,(hpress)
        and K_SWAP
        call nz,try_swap
        ld a,(hpress)
        and K_TONGUE
        call nz,tongue_start
        call tongue_update
        ld a,(hstate)
        cp HS_CLIMB
        jr nz,.walk
        call hero_climb
        jr .post
.walk:  call hero_walk
        call hero_move_x
        ld a,(pending_exit)
        or a
        ret nz
        call vine_grab
        ld a,(hstate)
        cp HS_CLIMB
        jr z,.post
        call hero_jump_check
        call hero_gravity
        call hero_move_y
        ld a,(pending_exit)
        or a
        ret nz
.post:  call hero_touch
        jp hero_anim

; HL -> byte: decrement unless zero
dec_nz:
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

; ---------------------------------------------------------------------
; horizontal control
; ---------------------------------------------------------------------
hero_walk:
        ld a,(hkeys)
        and K_LEFT|K_RIGHT
        cp K_RIGHT
        jr z,.right
        cp K_LEFT
        jr z,.left
        ; no input: friction toward 0
        ld a,(hgnd)
        or a
        ld c,FRIC_G
        jr nz,$+4
        ld c,FRIC_A
        ld a,(hvx)
        or a
        ret z
        jp m,.negf
        sub c
        jr nc,.st
        xor a
        jr .st
.negf:  add a,c
        jr nc,.st
        xor a
.st:    ld (hvx),a
        ret
.right: xor a
        ld (hdir),a
        ld a,(hvx)
        ld c,a
        ld a,(hgnd)
        or a
        ld b,ACC_A
        jr z,.ra
        ld b,ACC_G
        bit 7,c
        jr z,.ra
        ld b,SKID
.ra:    ld a,c
        add a,b
        jp m,.st                    ; still negative
        cp MAXV
        jr c,.st
        ld a,MAXV
        jr .st
.left:  ld a,1
        ld (hdir),a
        ld a,(hvx)
        ld c,a
        ld a,(hgnd)
        or a
        ld b,ACC_A
        jr z,.la
        ld b,ACC_G
        ld a,c
        dec a
        jp m,.la                    ; already moving left (or still)
        ld b,SKID
.la:    ld a,c
        sub b
        jp p,.st                    ; still positive
        cp -MAXV
        jr nc,.st
        ld a,-MAXV
        jr .st

; ---------------------------------------------------------------------
; horizontal movement: at most one cell per frame
; ---------------------------------------------------------------------
hero_move_x:
        ld a,(hvx)
        or a
        ret z
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld a,(kx)
        ld h,a
        ld a,(kxf)
        ld l,a
        add hl,de
        ld a,(kx)
        cp h
        jr nz,.cross
        ld a,l
        ld (kxf),a
        ret
.cross: ld a,l
        ld (mx_frac),a
        ld a,(hvx)
        or a
        jp m,.left
        call hero_try_right
        jr c,.blockr
        ld a,(mx_frac)
        ld (kxf),a
        ret
.blockr:
        ld a,0F0h
        ld (kxf),a
        xor a
        ld (hvx),a
        ret
.left:  call hero_try_left
        jr c,.blockl
        ld a,(mx_frac)
        ld (kxf),a
        ret
.blockl:
        ld a,10h
        ld (kxf),a
        xor a
        ld (hvx),a
        ret

; step one cell right if possible (NC = moved, C = blocked)
hero_try_right:
        ld a,(kx)
        add a,2
        cp ROOMW
        jr c,.in
        ld a,(room_exits+1)
        cp 0FFh
        scf
        ret z
        ld a,2
        ld (pending_exit),a
        scf
        ret
.in:    ld b,a
        ld a,(ky)
        ld c,a
        ld d,3
        call tflags_col
        and F_SOLID
        scf
        ret nz
        ld hl,kx
        inc (hl)
        ld hl,hstep
        inc (hl)
        or a
        ret

hero_try_left:
        ld a,(kx)
        or a
        jr nz,.in
        ld a,(room_exits)
        cp 0FFh
        scf
        ret z
        ld a,1
        ld (pending_exit),a
        scf
        ret
.in:    dec a
        ld b,a
        ld a,(ky)
        ld c,a
        ld d,3
        call tflags_col
        and F_SOLID
        scf
        ret nz
        ld hl,kx
        dec (hl)
        ld hl,hstep
        inc (hl)
        or a
        ret

; ---------------------------------------------------------------------
; jumping and gravity
; ---------------------------------------------------------------------
hero_jump_check:
        ld a,(hjbuf)
        or a
        ret z
        ld a,(hgnd)
        or a
        jr nz,hero_jump
        ld a,(hcoy)
        or a
        ret z
hero_jump:
        ld hl,JUMPV
hero_launch:
        ld (hvy),hl
        xor a
        ld (hgnd),a
        ld (hcoy),a
        ld (hjbuf),a
        ld a,0FFh
        ld (hplat),a
        ld hl,SFX_JUMP
        ld a,1
        jp sfx

hero_gravity:
        ld a,(hgnd)
        or a
        ret nz
        ld hl,(hvy)
        ld de,G_HI
        bit 7,h
        jr z,.add
        ld a,(hkeys)
        and K_JUMP
        jr z,.add
        ld de,G_LO
.add:   add hl,de
        bit 7,h
        jr nz,.ok
        ld de,VMAXY
        or a
        sbc hl,de
        add hl,de
        jr c,.ok
        ld hl,VMAXY
.ok:    ld (hvy),hl
        ret

; A = 1 if something under Kiko's feet holds him up (ground, plank,
; platform); also notes crumbling blocks
hero_supported:
        ld a,(ky)
        inc a
        cp ROOMH
        jr nc,.none
        ld c,a
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        ld e,a
        and F_SOLID
        jr nz,.yes
        ld a,(hdrop)
        or a
        jr nz,.plat
        ld a,e
        and F_ONEWAY
        jr nz,.yes
.plat:  call plat_under
        jr nc,.none
        ld a,1
        ret
.yes:   ld a,e
        and F_CRUMBLE
        call nz,crumble_under
        ld a,1
        ret
.none:  xor a
        ret

; start the crumble timers of the blocks under Kiko
crumble_under:
        ld a,(ky)
        inc a
        ld c,a
        ld a,(kx)
        ld b,a
        call .one
        inc b
.one:   call tflags
        and F_CRUMBLE
        ret z
        push bc
        call cell_t
        ld a,(wt+WT_CRUMBLE)
        cp (hl)
        jr nz,.no                   ; already cracked
        ld a,1
        ld c,16
        call tt_add
.no:    pop bc
        ret

hero_move_y:
        ld a,(hgnd)
        or a
        jr z,.air
        ; on the ground: still supported?
        ld a,(hkeys)
        and K_DOWN
        jr z,.nodrop
        ld a,(ky)                   ; DOWN on a plank: drop through
        inc a
        ld c,a
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        ld e,a
        and F_SOLID
        jr nz,.nodrop
        ld a,e
        and F_ONEWAY
        jr z,.nodrop
        ld a,10
        ld (hdrop),a
.nodrop:
        call hero_supported
        or a
        ret nz
        xor a
        ld (hgnd),a
        ld a,0FFh
        ld (hplat),a
        ld a,(hvy+1)                ; walked off an edge: coyote time
        or a
        ret m
        ld a,COYOTE
        ld (hcoy),a
        ret
.air:   ld hl,(hvy)
        ld a,(ky)
        ld d,a
        ld a,(kyf)
        ld e,a
        ex de,hl
        add hl,de
        ld a,(ky)
        cp h
        jr nz,.cross
        ld a,l
        ld (kyf),a
        ret
.cross: ld a,l
        ld (mx_frac),a
        ld a,(hvy+1)
        or a
        jp m,.up
        ; ---- down one cell
        ld a,(ky)
        inc a
        cp ROOMH
        jr c,.inroom
        ld a,(room_exits+3)
        cp 0FFh
        jr z,.pit
        ld a,4
        ld (pending_exit),a
        ret
.pit:   ld a,(ky)                   ; falling out of the room
        inc a
        ld (ky),a
        cp ROOMH+3
        ret c
        jp hero_die
.inroom:
        ld c,a
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        ld e,a
        and F_SOLID
        jr nz,.land
        ld a,(hdrop)
        or a
        jr nz,.noone
        ld a,e
        and F_ONEWAY
        jr nz,.land
.noone: call plat_under_next
        jr c,.landp
        ld hl,ky
        inc (hl)
        ld a,(mx_frac)
        ld (kyf),a
        ret
.landp: ld a,e
        ld (hplat),a
        xor a
.land:  ld (land_flags),a
        ld a,0C0h
        ld (kyf),a
        ld a,1
        ld (hgnd),a
        ld hl,(hvy)
        ld de,0
        ld (hvy),de
        ld a,(land_flags)
        and F_SPRING
        jr nz,.spring
        ld a,l
        cp 70
        ret c
        ld a,4
        ld (hsquash),a
        ld hl,SFX_LAND
        xor a
        jp sfx
.spring:
        ld a,(ky)                   ; squash the spring(s) under Kiko
        inc a
        ld c,a
        ld a,(kx)
        ld b,a
        call .sq
        inc b
        call .sq
        ld hl,SFX_SPRING
        ld a,2
        call sfx
        ld hl,SPRINGV
        ld (hvy),hl
        xor a
        ld (hgnd),a
        ret
.sq:    call tflags
        and F_SPRING
        ret z
        push bc
        call cell_t
        ld a,(wt+WT_SPRINGC)
        ld (hl),a
        push hl
        ld de,1000h
        add hl,de
        call mark_static
        pop hl
        ld a,3
        ld c,10
        call tt_add
        pop bc
        ret
        ; ---- up one cell
.up:    ld a,(ky)
        sub 3                       ; new head row
        jr nc,.inup
        ld a,(room_exits+2)
        cp 0FFh
        jr z,.bonk
        ld a,3
        ld (pending_exit),a
        ret
.inup:  ld c,a
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        and F_SOLID
        jr nz,.bonk
        ld hl,ky
        dec (hl)
        ld a,(mx_frac)
        ld (kyf),a
        ret
.bonk:  ld hl,0
        ld (hvy),hl
        xor a
        ld (kyf),a
        ret

; ---------------------------------------------------------------------
; vines
; ---------------------------------------------------------------------
; A = F_VINE bits of the cells Kiko covers (B,C kept free)
hero_on_vine:
        ld a,(kx)
        ld b,a
        ld a,(ky)
        ld c,a
        ld d,3
        call tflags_col
        ld e,a
        inc b
        call tflags_col
        or e
        and F_VINE
        ret

vine_grab:
        ld a,(hkeys)
        and K_UP|K_DOWN
        ret z
        ld a,(htngst)
        or a
        ret nz
        call hero_on_vine
        jr nz,.grab
        ld a,(hkeys)                ; DOWN onto a vine just below
        and K_DOWN
        ret z
        ld a,(hgnd)
        or a
        ret z
        ld a,(ky)
        inc a
        ld c,a
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        and F_VINE
        ret z
        ld a,(ky)                   ; through the floor gap
        inc a
        ld (ky),a
.grab:  ld a,HS_CLIMB
        ld (hstate),a
        xor a
        ld (hvx),a
        ld (hgnd),a
        ld (htimer),a
        ld hl,0
        ld (hvy),hl
        ld a,80h
        ld (kyf),a
        ret

hero_climb:
        ld a,(hpress)
        and K_JUMP
        jr z,.nojump
        xor a
        ld (hstate),a
        ld hl,VINEJV
        jp hero_launch
.nojump:
        ld hl,htimer
        ld a,(hl)
        or a
        jr z,.go
        dec (hl)
        ret
.go:    ld a,(hkeys)
        bit 0,a                     ; K_UP
        jr nz,.up
        bit 1,a                     ; K_DOWN
        jr nz,.down
        and K_LEFT|K_RIGHT
        ret z
        ; sideways along / off the vine
        ld a,6
        ld (htimer),a
        ld a,(hkeys)
        and K_RIGHT
        jr z,.sl
        xor a
        ld (hdir),a
        call hero_try_right
        jr .sx
.sl:    ld a,1
        ld (hdir),a
        call hero_try_left
.sx:    call hero_on_vine
        ret nz
        xor a                       ; let go
        ld (hstate),a
        ret
.up:    ld a,5
        ld (htimer),a
        ld a,(ky)
        sub 3
        jr nc,.uin
        ld a,(room_exits+2)
        cp 0FFh
        ret z
        ld a,3
        ld (pending_exit),a
        ret
.uin:   ld c,a                      ; head row above
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        and F_SOLID
        ret nz
        ld hl,ky
        dec (hl)
        inc hl
        ld hl,hstep
        inc (hl)
        call hero_on_vine
        ret nz
        xor a                       ; top of the vine: hop off
        ld (hstate),a
        ld hl,-80
        ld (hvy),hl
        ret
.down:  ld a,4
        ld (htimer),a
        ld a,(ky)
        inc a
        cp ROOMH
        jr c,.din
        ld a,(room_exits+3)
        cp 0FFh
        ret z
        ld a,4
        ld (pending_exit),a
        ret
.din:   ld c,a
        ld a,(kx)
        ld b,a
        ld d,2
        call tflags_row
        and F_SOLID|F_ONEWAY
        jr z,.dgo
        and F_SOLID
        jr nz,.stand
        call hero_on_vine           ; plank with the vine passing through
        jr z,.stand
.dgo:   ld hl,ky
        inc (hl)
        ld hl,hstep
        inc (hl)
        call hero_on_vine
        ret nz
        xor a                       ; bottom of the vine: drop
        ld (hstate),a
        ret
.stand: xor a
        ld (hstate),a
        jp hero_ground_probe

; ---------------------------------------------------------------------
; tongue
; ---------------------------------------------------------------------
tongue_start:
        ld a,(htngst)
        or a
        ret nz
        ld a,(hstate)
        cp HS_CLIMB
        ret z
        ld a,1
        ld (htngst),a
        xor a
        ld (htngl),a
        ld (htngt),a
        ld hl,SFX_TONGUE
        ld a,1
        jp sfx

tongue_update:
        ld a,(htngst)
        or a
        ret z
        cp 1
        jr nz,.retract
        ld hl,htngt
        inc (hl)
        bit 0,(hl)
        ret nz
        ld hl,htngl
        inc (hl)
        call tongue_tip
        ret c                       ; tip blocked: retracting
        ld a,(htngl)
        cp TMAX
        ret c
.back:  ld a,2
        ld (htngst),a
        ret
.retract:
        ld hl,htngl
        dec (hl)
        ret nz
        xor a
        ld (htngst),a
        ret

; B,C = tongue tip cell (from kx, ky, hdir, htngl)
tongue_tip_pos:
        ld a,(ky)
        sub 2
        ld c,a
        ld a,(hdir)
        or a
        ld a,(kx)
        jr nz,.l
        add a,2
        ld hl,htngl
        add a,(hl)
        ld b,a
        ret
.l:     dec a
        ld hl,htngl
        sub (hl)
        ld b,a
        ret

; check what the tip touched.  C = tongue stopped (now retracting)
tongue_tip:
        call tongue_tip_pos
        ld a,b
        cp ROOMW
        jr nc,.stop
        ld a,c
        cp ROOMH
        jr nc,.stop
        call tflags
        ld e,a
        and F_SOLID
        jr nz,.stop
        ld a,e
        and F_GEM|F_ITEM
        jr z,.noitem
        push bc
        call cell_t
        call collect_at
        pop bc
.noitem:
        call obj_at_point           ; IX = object at (B, C), C flag if found
        ret nc
        call tongue_hit_obj
.stop:  ld hl,htngl                 ; pull back from the blocked cell
        ld a,(hl)
        or a
        jr z,.z
        dec (hl)
.z:     ld a,2
        ld (htngst),a
        ld a,(htngl)
        or a
        jr nz,.c
        xor a
        ld (htngst),a
.c:     scf
        ret

; ---------------------------------------------------------------------
; colour swap
; ---------------------------------------------------------------------
try_swap:
        ld a,(howned)
        ld c,a
        ld a,(hcol)
        ld b,3
.n:     inc a
        cp 3
        jr c,$+3
        xor a
        ld e,a
        push bc
        ld b,a
        inc b
        ld a,c
.sh:    rrca
        djnz .sh
        pop bc
        jr c,.found
        ld a,e
        djnz .n
        ret
.found: ld a,(hcol)
        cp e
        ret z                       ; only one colour
        ; refuse if Kiko overlaps a ghost block of the new colour
        ld a,(wt+WT_CHROMA)
        add a,e
        add a,e
        inc a                       ; ghost tile of the new colour
        ld (swap_ghost),a
        ld a,e
        ld (swap_new),a
        ld a,(kx)
        ld b,a
        ld a,(ky)
        ld c,a
        call .col
        jr z,.deny
        inc b
        call .col
        jr z,.deny
        ld a,(swap_new)
        ld (hcol),a
        call refresh_chroma
        ld a,12
        ld (hswapf),a
        ld a,1
        ld (hud_dirty),a
        ld hl,SFX_SWAP
        ld a,2
        jp sfx
.deny:  ld hl,SFX_DENY
        ld a,2
        jp sfx
; Z if column B rows C-2..C holds the ghost tile (C kept)
.col:   push bc
        ld d,3
.cl:    ld a,c
        cp ROOMH
        jr nc,.cn
        call cell_t
        ld a,(swap_ghost)
        cp (hl)
        jr z,.cz
.cn:    dec c
        dec d
        jr nz,.cl
        or 1                        ; NZ
.cz:    pop bc
        ret

; ---------------------------------------------------------------------
; touching tiles: pickups and hazards in the hit box
; ---------------------------------------------------------------------
hero_touch:
        xor a
        ld (touch_hurt),a
        ld a,(kx)
        ld b,a
        call .col
        inc b
        call .col
        ld a,(touch_hurt)
        or a
        ret z
        and F_CRUMBLE               ; hurt + crumble bits = deadly liquid
        jp nz,hero_die
        ld a,(hdir)                 ; knocked back the way Kiko faces
        xor 1
        jp hero_hurt
.col:   ld a,(ky)
        ld c,a
        ld d,3
.l:     call tflags
        ld e,a
        and F_GEM|F_ITEM
        jr z,.nopick
        push bc
        push de
        call cell_t
        call collect_at
        pop de
        pop bc
.nopick:
        ld a,e
        and F_HURT
        jr z,.n
        ld a,e
        and F_HURT|F_CRUMBLE
        ld hl,touch_hurt
        or (hl)
        ld (hl),a
.n:     dec c
        dec d
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; damage and death
; ---------------------------------------------------------------------
; A = direction to be knocked (0 right, 1 left)
hero_hurt:
        ld c,a
        ld a,(hinv)
        or a
        ret nz
        ld a,(hstate)
        cp HS_DEAD
        ret nc
        ld a,(demo)                 ; the demo pilot is immortal-ish
        or a
        jr nz,.nodmg
        ld a,(hearts)
        dec a
        ld (hearts),a
        jp z,hero_die
.nodmg: ld a,1
        ld (hud_dirty),a
        ld a,HS_HURT
        ld (hstate),a
        ld a,18
        ld (htimer),a
        ld a,100
        ld (hinv),a
        xor a
        ld (htngst),a
        ld (htngl),a
        ld (hgnd),a
        ld a,c
        or a
        ld a,40
        jr z,$+4
        ld a,-40
        ld (hvx),a
        ld hl,-90
        ld (hvy),hl
        ld a,0FFh
        ld (hplat),a
        ld hl,SFX_HURT
        ld a,3
        jp sfx

hero_die:
        ld a,(hstate)
        cp HS_DEAD
        ret z
        ld a,HS_DEAD
        ld (hstate),a
        ld a,110
        ld (htimer),a
        xor a
        ld (hearts),a
        ld (htngst),a
        ld (htngl),a
        ld (hvx),a
        ld a,1
        ld (hud_dirty),a
        ld hl,-150
        ld (hvy),hl
        call sfx_stop
        ld hl,SONG_DEATH
        jp mus_play

hero_dead_update:
        ld a,HA_DEAD
        ld (hanim),a
        ld hl,htimer
        dec (hl)
        jr nz,.fly
        ld a,1
        ld (hdead),a
        ret
.fly:   ld a,(hl)
        cp 95                       ; hang in the air a moment first
        ret nc
        ld hl,(hvy)
        ld de,8
        add hl,de
        ld (hvy),hl
        ld a,(ky)
        ld d,a
        ld a,(kyf)
        ld e,a
        add hl,de
        ld a,h
        cp ROOMH+4                  ; stop once well below the screen
        jr c,$+4
        ld h,ROOMH+4
        bit 7,h
        jr z,$+4
        ld h,0
        ld a,h
        ld (ky),a
        ld a,l
        ld (kyf),a
        ret

hero_win_update:
        ld a,HA_WIN
        ld (hanim),a
        ld hl,htimer
        inc (hl)
        ret

; ---------------------------------------------------------------------
; animation
; ---------------------------------------------------------------------
hero_anim:
        ld a,(hstate)
        cp HS_HURT
        ld b,HA_HURT
        jr z,.set
        cp HS_CLIMB
        jr nz,.notclimb
        ld a,(hstep)
        and 1
        add a,HA_CLIMB1
        ld b,a
        jr .set
.notclimb:
        ld a,(htngst)
        or a
        ld b,HA_TONGUE
        jr nz,.set
        ld a,(hsquash)
        or a
        ld b,HA_SQUASH
        jr nz,.set
        ld a,(hgnd)
        or a
        jr nz,.ground
        ld a,(hvy+1)
        or a
        ld b,HA_JUMP
        jp m,.set
        ld b,HA_FALL
        jr .set
.ground:
        ld a,(hvx)
        or a
        jr z,.idle
        xor a
        ld (hidle),a
        ld (hidle+1),a
        ld a,(hstep)
        and 3
        ld e,a
        ld d,0
        ld hl,RUNSEQ
        add hl,de
        ld b,(hl)
        jr .set
.idle:  ld hl,(hidle)
        inc hl
        ld (hidle),hl
        ld a,h
        cp 2                        ; ~10 s: nap
        ld b,HA_SLEEP
        jr nc,.set
        ld a,l
        and 127
        cp 120
        ld b,HA_BLINK
        jr nc,.set
        ld b,HA_STAND
.set:   ld a,b
        ld (hanim),a
        ret

; ---------------------------------------------------------------------
; draw Kiko (+ tongue) into the overlay
; ---------------------------------------------------------------------
hero_draw:
        ld a,(hinv)
        and 4
        jr z,.vis
        ld a,(hstate)
        cp HS_DEAD
        ret c                       ; invulnerable flicker (hurt states)
.vis:   ld a,(hanim)
        add a,a
        ld hl,hdir
        add a,(hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,HFRAMES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        call hero_remap
        pop hl
        push af
        ld a,(kx)
        ld b,a
        ld a,(ky)
        ld c,a
        pop af
        call draw_sprite
        ; sleeping: a Z floats above
        ld a,(hanim)
        cp HA_SLEEP
        jr nz,.tongue
        ld a,(hidle)
        and 32
        ret z
        ld a,(kx)
        add a,2
        ld b,a
        ld a,(ky)
        sub 4
        ld c,a
        ld hl,FR_ZZZ
        ld a,REMAP_ID
        jp draw_sprite
.tongue:
        ld a,(htngl)
        or a
        ret z
        ld (tng_i),a
.tl:    ld a,(tng_i)
        ld hl,htngl
        cp (hl)
        ld hl,FR_TONGUE
        jr nz,$+5
        ld hl,FR_TONGUE_TIP
        ld e,a
        ld a,(ky)
        sub 2
        ld c,a
        ld a,(hdir)
        or a
        ld a,(kx)
        jr nz,.tleft
        add a,2
        add a,e
        jr .tdraw
.tleft: dec a
        sub e
.tdraw: ld b,a
        ld a,REMAP_ID
        call draw_sprite
        ld hl,tng_i
        dec (hl)
        jr nz,.tl
        ret

; A = remap page for Kiko this frame
hero_remap:
        ld a,(hswapf)
        and 2
        ld a,high REMAPW
        ret nz
        ld a,(hcol)
        ld e,a
        ld d,0
        ld hl,CIDX
        add hl,de
        ld a,(hl)
        add a,high REMAP
        ret
