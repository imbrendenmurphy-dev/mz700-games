; =====================================================================
;  particles.asm - debris, sparkles and fireworks
;
;  Up to MAXPART particles fly out from a point, shrinking from a star to
;  dots as they die.  They are transients (drawn into W each tick, never
;  into the object layer or the collision map), so they cost nothing once
;  they're gone.  Attribute bit 3 (unused by the hardware) = gravity.
; =====================================================================

; B = row, C = column, A = attribute, E = count, D = speed (0 fast,
; 1 half, 2 quarter).  Set A bit 3 for gravity.
burst:
        ld (bat),a
        ld a,d
        ld (bspd),a
        ld a,e
        or a
        ret z
        push iy                 ; (IY preserved)
        push bc
        ld b,0                  ; direction step = 16 / count
        ld a,16
.dv:    inc b
        sub e
        jr z,.dd
        jr nc,.dv
.dd:    ld a,b
        ld (bstep),a
        call rand8
        ld (bdir),a
        pop bc
.l:     push de
        push bc
        call part_slot          ; IY = a slot
        pop bc
        push bc
        ld (iy+P_X),c
        ld (iy+P_Y),b
        call rand8              ; one random byte: offsets and life
        ld (iy+P_XL),a
        rrca
        rrca
        rrca
        ld (iy+P_YL),a
        and 3
        add a,5
        ld (iy+P_LIFE),a
        ld a,(bat)
        ld (iy+P_AT),a
        ld a,(bdir)
        and 15
        ld hl,pvxtab
        add a,l
        ld l,a
        jr nc,.n1
        inc h
.n1:    ld a,(hl)
        call bscale
        ld (iy+P_VX),a
        ld de,pvytab-pvxtab
        add hl,de
        ld a,(hl)
        call bscale
        bit 3,(iy+P_AT)         ; fireworks get a kick upwards
        jr z,.n2
        sub 24
.n2:    ld (iy+P_VY),a
        ld a,(bstep)
        ld hl,bdir
        add a,(hl)
        ld (hl),a
        pop bc
        pop de
        dec e
        jr nz,.l
        pop iy
        ret

bscale:                         ; A >>= (bspd), arithmetic
        push bc
        ld b,a
        ld a,(bspd)
        or a
        ld c,a
        ld a,b
        jr z,.e
.s:     sra a
        dec c
        jr nz,.s
.e:     pop bc
        ret

; IY = the next slot round the ring (the oldest particle, if it's busy)
part_slot:
        ld a,(pnext)
        inc a
        and MAXPART-1
        ld (pnext),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PART
        add hl,de
        push hl
        pop iy
        jp perase               ; take it off the screen first

; IY = particle: take it out of W (back to the object layer) if drawn
perase:
        ld a,(iy+P_DRAWN)
        or a
        ret z
        ld (iy+P_DRAWN),0
        ld l,(iy+P_DOFS)
        ld h,(iy+P_DOFS+1)
        ld c,l
        ld a,h
        add a,high OLCH
        ld b,a
        ld a,(bc)
        ld d,a
        set 2,b
        ld a,(bc)
        ld e,a
        ld a,h
        add a,high WCH
        ld b,a
        ld a,d
        ld (bc),a
        set 2,b
        ld a,e
        ld (bc),a
        jp dl_add

clear_particles:
        ld hl,PART
        ld de,PART+1
        ld bc,MAXPART*PSZ-1
        ld (hl),0
        ldir
        ret

; Particles are drawn straight into W and only redrawn when their cell
; or look changes.  (Anything else drawn over one just hides it.)
update_particles:
        ld iy,PART              ; half the particles each tick, double speed
        ld a,(framecnt)
        and 1
        jr z,.h
        ld iy,PART+PSZ
.h:     ld b,MAXPART/2
.l:     push bc
        ld a,(iy+P_LIFE)
        or a
        jp z,.nx
        dec (iy+P_LIFE)
        jp z,.kill
        bit 3,(iy+P_AT)         ; gravity
        jr z,.ng
        ld a,(iy+P_VY)
        cp 70
        jr c,.g                 ; 0..69: fine
        cp 80h
        jr c,.ng                ; 70..127: fast enough already
.g:     add a,10
        ld (iy+P_VY),a
.ng:    ld a,(iy+P_VX)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(iy+P_XL)
        ld h,(iy+P_X)
        add hl,de
        add hl,de
        ld a,h
        cp XMIN
        jp c,.kill
        cp XMAX+1
        jp nc,.kill
        ld (iy+P_XL),l
        ld (iy+P_X),h
        ld a,(iy+P_VY)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(iy+P_YL)
        ld h,(iy+P_Y)
        add hl,de
        add hl,de
        ld a,h
        cp YMIN
        jp c,.kill
        cp YMAX+1
        jp nc,.kill
        ld (iy+P_YL),l
        ld (iy+P_Y),h
        ld b,h
        ld c,(iy+P_X)
        call calc_ofs
        ld a,(iy+P_LIFE)
        ld d,0B3h               ; star, then dots, then fewer dots
        cp 6
        jr nc,.gl
        ld d,0EEh
        cp 3
        jr nc,.gl
        ld d,0EFh
.gl:    ld a,(iy+P_AT)
        and 0F7h
        or 80h
        ld e,a
        ld a,(iy+P_DRAWN)       ; unchanged?
        or a
        jr z,.draw
        ld a,l
        cp (iy+P_DOFS)
        jr nz,.mv
        ld a,h
        cp (iy+P_DOFS+1)
        jr nz,.mv
        ld a,d
        cp (iy+P_DCH)
        jr nz,.mv
        ld a,e
        cp (iy+P_DAT)
        jr z,.nx
.mv:    push hl
        push de
        call perase
        pop de
        pop hl
.draw:  ld (iy+P_DOFS),l
        ld (iy+P_DOFS+1),h
        ld (iy+P_DCH),d
        ld (iy+P_DAT),e
        ld (iy+P_DRAWN),1
        ld c,l
        ld a,h
        add a,high WCH
        ld b,a
        ld a,d
        ld (bc),a
        set 2,b
        ld a,e
        ld (bc),a
        call dl_add
        jr .nx
.kill:  call perase
        ld (iy+P_LIFE),0
.nx:    pop bc
        ld de,PSZ*2
        add iy,de
        dec b
        jp nz,.l
        ret

; 16 directions, speed 100/256 cell per tick
pvxtab: db 100,92,71,38,0,(-38)&255,(-71)&255,(-92)&255
        db (-100)&255,(-92)&255,(-71)&255,(-38)&255,0,38,71,92
pvytab: db 0,38,71,92,100,92,71,38
        db 0,(-38)&255,(-71)&255,(-92)&255,(-100)&255,(-92)&255,(-71)&255,(-38)&255
