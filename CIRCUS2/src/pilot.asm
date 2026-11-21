; =====================================================================
;  pilot.asm - the demo's seesaw operator
;
;  Every ten updates it predicts where the flying clown will come down
;  (gravity, walls and the roof, as in clown_step) and slides the seesaw
;  so that the raised tip is underneath.  Returns K_ bits in A.
; =====================================================================
ai_input:
        ld ix,clown0
        ld a,(ix+CS_STATE)
        cp S_FLY
        jr z,.f
        ld ix,clown1
        ld a,(ix+CS_STATE)
        cp S_FLY
        jr z,.f
        ld a,80                     ; nobody flying: wait in the middle
        ld (ai_target),a
        jp steer_to
.f:     ld hl,ai_t
        dec (hl)
        jp p,steer_to
        ld (hl),9
        ld l,(ix+CS_X)
        ld h,(ix+CS_X+1)
        ld (ai_x),hl
        ld l,(ix+CS_Y)
        ld h,(ix+CS_Y+1)
        ld (ai_y),hl
        ld l,(ix+CS_VX)
        ld h,(ix+CS_VX+1)
        ld (ai_vx),hl
        ld e,(ix+CS_VY)
        ld d,(ix+CS_VY+1)
        ld b,250
.sim:   ld hl,(ph_grav)
        bit 7,d
        jr nz,.g
        ld a,(pw_umb)
        or a
        jr z,.g
        ld hl,(ph_umb)
.g:     add hl,de
        ex de,hl                    ; DE = vy
        bit 7,d                     ; fall-speed cap
        jr nz,.nc
        ld a,(pw_umb)
        or a
        ld hl,(ph_vmax)
        jr z,.cap
        ld hl,(ph_vumb)
.cap:   push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.nc
        ex de,hl
.nc:    ld hl,(ai_y)
        add hl,de
        ld (ai_y),hl
        ld a,h
        cp CEIL_Y
        jr nc,.yp
        ld hl,CEIL_Y*256            ; the roof: bounce at half speed
        ld (ai_y),hl
        bit 7,d
        jr z,.yp
        ex de,hl
        sra h
        rr l
        call neg_hl
        ex de,hl
.yp:    ld hl,(ai_x)
        push de
        ld de,(ai_vx)
        add hl,de
        pop de
        ld a,h
        cp XMIN
        jr c,.bw
        cp XMAX+1
        jr c,.nw
.bw:    push de
        ld hl,(ai_vx)
        call neg_hl
        ld (ai_vx),hl
        pop de
        ld hl,(ai_x)
.nw:    ld (ai_x),hl
        bit 7,d
        jr nz,.cont
        ld a,(ai_y+1)
        add a,16
        cp LAND_Y0
        jr nc,.land
.cont:  djnz .sim
.land:  ld a,(ai_x+1)               ; landing cell
        rrca
        rrca
        and 3Fh
        ld c,a
        call see_cells              ; B = half width
        ld a,(tilt)                 ; tilt 0: the right end is raised
        or a
        ld a,c
        jr nz,.tl
        sub b
        jr .tt
.tl:    add a,b
.tt:    cp 5                        ; out of reach with this tilt (the
        jr c,.flip                  ; centre must stay in cells 4..35 or so):
        cp 35                       ; flip the seesaw instead
        jr nc,.flip
        add a,a
        add a,a
        add a,2
        ld (ai_target),a
        jr steer_to
.flip:  ld a,(flipcool)
        or a
        jr nz,steer_to
        ld hl,ai_t                  ; think again next update
        ld (hl),0
        ld a,K_FIRE
        ret
; slide the seesaw toward ai_target: K_ bits in A
steer_to:
        ld a,(ai_target)
        ld c,a
        ld a,(see_hw)               ; clamp to the legal range
        add a,4
        cp c
        jr c,$+3
        ld c,a
        ld a,(see_hw)
        ld b,a
        ld a,155
        sub b
        cp c
        jr nc,$+3
        ld c,a
        ld a,(see_x+1)
        sub c                       ; > 0: move left
        jr z,.none
        jp m,.right
        cp 2
        jr c,.none
        cp 6
        jr nc,.goleft
        ld hl,(see_v)               ; close: brake, then step
        ld a,h
        or l
        jr nz,.none
.goleft:
        ld a,K_LEFT
        ret
.right: neg
        cp 2
        jr c,.none
        cp 6
        jr nc,.goright
        ld hl,(see_v)
        ld a,h
        or l
        jr nz,.none
.goright:
        ld a,K_RIGHT
        ret
.none:  xor a
        ret

; ---------------------------------------------------------------------
; joystick directions ORed into A (the keys so far).  Stick: lean past a
; dead zone to slide.  Paddle: the stick's position is the seesaw's.
; ---------------------------------------------------------------------
JOY_MINRANGE    equ 40

joy_dir:
        push bc
        push de
        push hl
        ld e,a
        ld a,(joy_min)
        ld c,a
        ld a,(joy_max)
        sub c
        jr c,.out                   ; nothing seen yet
        cp JOY_MINRANGE
        jr c,.out                   ; range not learned: move the stick
        ld d,a                      ; D = range
        ld a,(joy_x)
        sub c
        ld b,a                      ; B = x - min
        ld a,(joy_mode)
        cp 2
        jr z,.paddle
        ld a,d                      ; stick: dead zone of range/8 each side
        srl a
        ld c,a                      ; C = centre
        srl a
        srl a
        ld h,a                      ; H = range/8
        ld a,c
        sub h
        cp b
        jr c,.nl
        jr z,.nl
        set B_LEFT,e
        jr .out
.nl:    ld a,c
        add a,h
        cp b
        jr nc,.out
        set B_RIGHT,e
        jr .out
.paddle:
        ld h,b                      ; HL = (x - min) * 128
        ld l,0
        srl h
        rr l
        ld c,d
        call div16_8                ; L = 0..128
        ld a,l
        add a,16                    ; seesaw centre 16..144
        ld hl,ai_target             ; ignore jitter of a few units
        ld c,a
        sub (hl)
        jr nc,$+4
        neg
        cp 4
        jr c,.keep
        ld (hl),c
.keep:  call steer_to
        or e
        ld e,a
.out:   ld a,e
        pop hl
        pop de
        pop bc
        ret
