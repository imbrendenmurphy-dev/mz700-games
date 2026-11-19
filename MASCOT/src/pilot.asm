; =====================================================================
;  pilot.asm - the attract-mode demo player
;
;  Runs right; jumps (holding the button for a full jump) when there is a
;  wall, a gap or a hazard ahead, or when stuck; tongues edible enemies
;  ahead and jumps over the rest.
; =====================================================================

pilot_keys:
        ld c,K_RIGHT
        ld a,(pilot_hold)
        or a
        jr z,.free
        dec a
        ld (pilot_hold),a
        ld a,c
        or K_JUMP
        ld c,a
        jr .tongue
.free:  ld a,(hgnd)
        or a
        jr z,.tongue
        call pilot_should_jump
        jr nc,.tongue
        ld a,18
        ld (pilot_hold),a
        ld a,c
        or K_JUMP
        ld c,a
.tongue:
        ; an edible enemy at head height, close ahead: lick it
        ld a,(pilot_t)
        or a
        jr z,.tt
        dec a
        ld (pilot_t),a
        jr .done
.tt:    push bc
        ld a,(ky)
        sub 2
        ld c,a
        ld a,(kx)
        add a,3
        ld b,a
        ld e,4
.scan:  push de
        call obj_at_point
        pop de
        jr c,.found
        inc b
        dec e
        jr nz,.scan
        pop bc
        jr .done
.found: pop bc
        ld a,(ix+O_FL)
        and OF_EAT
        jr z,.done
        ld a,c
        or K_TONGUE
        ld c,a
        ld a,12
        ld (pilot_t),a
.done:  ; stuck against something: jump
        ld a,(kx)
        ld hl,pilot_lastx
        cp (hl)
        ld (hl),a
        ld hl,pilot_stuck
        jr nz,.moved
        inc (hl)
        ld a,(hl)
        cp 30
        jr c,.out
        ld (hl),0
        ld a,18
        ld (pilot_hold),a
        jr .out
.moved: ld (hl),0
.out:   ld a,c
        ret

; C if Kiko should jump now
pilot_should_jump:
        push bc
        ; wall (or anything solid) right ahead
        ld a,(kx)
        add a,2
        ld b,a
        ld a,(ky)
        ld c,a
        ld d,3
        call tflags_col
        and F_SOLID|F_HURT
        jr nz,.yes
        ; hazard or gap under the next two columns
        ld a,(ky)
        inc a
        ld c,a
        call .under
        jr c,.yes
        inc b
        call .under
        jr c,.yes
        ; enemy close ahead
        ld a,(ky)
        ld c,a
        ld a,(kx)
        add a,2
        ld b,a
        ld e,3
.e:     push de
        call obj_at_point
        pop de
        jr c,.enemy
        dec c
        push de
        call obj_at_point
        pop de
        inc c
        jr c,.enemy
        inc b
        dec e
        jr nz,.e
        pop bc
        or a
        ret
.enemy: ld a,(ix+O_FL)
        and OF_HARM
        jr z,.no
.yes:   pop bc
        scf
        ret
.no:    pop bc
        or a
        ret
; C if column B, row C has nothing to stand on (or a hazard)
.under: ld a,c
        cp ROOMH
        jr nc,.nu                   ; bottom edge: room below
        call tflags
        ld e,a
        and F_HURT
        jr nz,.bad
        ld a,e
        and F_SOLID|F_ONEWAY
        jr nz,.nu
        ; check one more row down (a single step down is fine)
        inc c
        call tflags
        dec c
        and F_SOLID|F_ONEWAY
        jr nz,.nu
.bad:   scf
        ret
.nu:    or a
        ret
