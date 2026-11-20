; =====================================================================
;  pilot.asm - the demo player.  At every step it scores each open
;  direction: pellets, distance to a target pellet, danger from ghosts,
;  frightened ghosts worth chasing, a dislike of turning back, and a
;  pinch of randomness.  Called from player_choose with B, C = position.
; =====================================================================
demo_ai:
        push bc
        ld a,80h
        ld (best),a                 ; best score so far (signed)
        ld a,(ix+A_DIR)
        ld (bestdir),a
        ld a,(aitx)                 ; target pellet still there?
        ld b,a
        ld a,(aity)
        ld c,a
        call cell_at
        cp C_PELLET
        jr z,.keept
        cp C_ENERG
        jr z,.keept
        pop bc                      ; a pellet next to us? then no search
        push bc
        xor a
.nb:    push af
        push bc
        call neighbour
        pop bc
        cp C_PELLET
        jr z,.nbp
        cp C_ENERG
        jr z,.nbp
        pop af
        inc a
        cp 4
        jr nz,.nb
        call nearest_pellet         ; -> D, E
        ld a,d
        ld (aitx),a
        ld a,e
        ld (aity),a
        jr .keept
.nbp:   pop af
.keept: xor a
.dl:    ld (aidir),a
        pop bc
        push bc
        call neighbour
        call passable
        jp nc,.next
        xor a
        ld (aiscore),a
        ld a,(aidir)                ; turning back
        xor 1
        cp (ix+A_DIR)
        jr nz,.nr
        ld a,-6
        ld (aiscore),a
.nr:    push bc
        call cell_at
        pop bc
        cp C_PELLET
        jr c,.np
        cp C_WALL
        jr nc,.np
        ld a,12
        call ai_add
.np:    ld a,(aitx)                 ; towards the target
        ld e,a
        ld a,b
        sub e
        jp p,.q1
        neg
.q1:    ld d,a
        ld a,(aity)
        ld e,a
        ld a,c
        sub e
        jp p,.q2
        neg
.q2:    add a,d
        cp 40
        jr c,.q3
        ld a,40
.q3:    neg
        call ai_add
        push ix                     ; ghosts
        ld ix,GHOST1
        ld e,4
.gd:    ld a,(ix+A_ST)
        cp ST_ACT
        jr z,.dang
        cp ST_FRT
        jr nz,.gn
        call ai_gdist               ; frightened ghost nearby: tasty
        cp 10
        jr nc,.gn
        ld a,(frighttim)
        cp 40
        jr c,.gn
        ld a,10
        call ai_add
        jr .gn
.dang:  ld a,(freezetim)
        or a
        jr nz,.gn
        call ai_gdist
        cp 4
        jr nc,.g2
        ld a,-60
        call ai_add
        jr .gn
.g2:    cp 8
        jr nc,.gn
        ld a,-25
        call ai_add
.gn:    push de
        ld de,16
        add ix,de
        pop de
        dec e
        jr nz,.gd
        pop ix
        call rand
        and 3
        call ai_add
        ld e,a                      ; signed compare with the best
        ld a,(best)
        sub e
        jp pe,.ov
        jp m,.better
        jr .next
.ov:    jp p,.better
        jr .next
.better:
        ld a,(aiscore)
        ld (best),a
        ld a,(aidir)
        ld (bestdir),a
.next:  ld a,(aidir)
        inc a
        cp 4
        jp nz,.dl
        pop bc
        ld a,(bestdir)
        ld (ix+A_NEXT),a
        ret

; aiscore += A (signed, saturating); returns A = aiscore.  Keeps BC, DE.
ai_add:
        push bc
        ld b,a
        ld a,(aiscore)
        add a,b
        jp po,.ok
        bit 7,b
        ld a,127
        jr z,.ok
        ld a,-128
.ok:    ld (aiscore),a
        pop bc
        ret

; distance from B, C to ghost IX -> A (keeps BC, DE)
ai_gdist:
        ld a,b
        sub (ix+A_X)
        jp p,.a
        neg
.a:     push de
        ld d,a
        ld a,c
        sub (ix+A_Y)
        jp p,.b
        neg
.b:     add a,d
        pop de
        ret

; nearest pellet to the player (cell centres only) -> D, E
nearest_pellet:
        ld a,(PLAYER+A_X)
        ld (npx),a
        ld a,(PLAYER+A_Y)
        ld (npy),a
        ld d,a
        ld a,(npx)
        ld d,a
        ld a,(npy)
        ld e,a
        ld a,255
        ld (npd),a
        ld c,0
.y:     ld b,0
.x:     call grid_addr
        ld a,(hl)
        cp C_PELLET
        jr c,.n
        cp C_WALL
        jr nc,.n
        push de
        ld a,(npx)
        sub b
        jp p,.a
        neg
.a:     ld d,a
        ld a,(npy)
        sub c
        jp p,.b
        neg
.b:     add a,d
        pop de
        ld hl,npd
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld d,b
        ld e,c
.n:     inc b
        inc b
        ld a,b
        cp GW
        jr c,.x
        inc c
        inc c
        ld a,c
        cp GH
        jr c,.y
        ret
