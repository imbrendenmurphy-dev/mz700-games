; =====================================================================
;  pilot.asm - the demo player
;
;  Once per tick (in the frame after the physics) it marks danger cells
;  (next to creatures, under falling rocks) in DIST, then runs a
;  breadth-first search from the player through space, dirt and
;  diamonds.  The first diamond found (or the open exit) decides the
;  move.  DIST cell values: 0 unseen, 1-4 first move + 1, 0FEh danger,
;  0FFh seen from the start cell.
; =====================================================================

pilot_think:
        xor a
        ld (ai_keys),a
        ld a,(pl_frozen)
        or a
        ret nz
        ld a,(pl_dead)
        or a
        ret nz
        ld hl,(pl_addr)
        ld a,(hl)
        and 1Fh
        cp E_PLAYER
        ret nz                      ; not born yet
        ; clear the map
        ld hl,DIST
        ld de,DIST+1
        ld bc,CAVESZ-1
        ld (hl),0
        ldir
        call poll
        ; mark danger
        ld hl,CAVE+CAVEW
        ld bc,CAVESZ-2*CAVEW
.dz:    ld a,(hl)
        and 1Fh
        cp E_FIRE0
        jr c,.rock
        cp E_AMOEBA
        jr nc,.nx
        call danger_fly
        jr .nx
.rock:  cp E_BOULDER
        jr c,.nx
        call danger_rock
.nx:    inc hl
        dec bc
        ld a,c
        and 7Fh
        call z,poll
        ld a,b
        or c
        jr nz,.dz
        ; breadth-first search from the player
        ld hl,(pl_addr)
        set 3,h                     ; DIST
        ld (hl),0FFh
        res 3,h
        ld (QUEUE),hl
        ld hl,QUEUE
        ld (bfs_head),hl
        ld hl,QUEUE+2
        ld (bfs_tail),hl
        xor a
        ld (bfs_cnt),a
        ld (ai_dgood),a
        ld h,a
        ld l,a
        ld (ai_drop),hl
.next:  ld hl,(bfs_head)
        ld de,(bfs_tail)
        or a
        sbc hl,de
        jp z,.none
        ld hl,(bfs_head)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (bfs_head),hl
        ld hl,bfs_cnt
        inc (hl)
        ld a,(hl)
        and 1Fh
        call z,poll
        ; DE = cell; try the four neighbours
        ld b,0
.dir:   push bc
        push de
        ld a,b
        cp 3
        jr nz,.notdown
        ; never step down with a rock above: it follows you into the hole
        ld hl,-CAVEW
        add hl,de
        ld a,(hl)
        and 1Fh
        sub E_BOULDER
        cp E_DIAMONDF-E_BOULDER+1
        jp c,.skip
        set 3,h
        ld a,(hl)
        cp 0FEh
        jp z,.skip
        ld a,3
.notdown:
        add a,a
        add a,low DIROFF
        ld l,a
        ld h,high DIROFF
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        add hl,de                   ; HL = neighbour
        set 3,h
        ld a,(hl)
        res 3,h
        or a
        jr nz,.skip                 ; seen or dangerous
        ld a,(hl)
        and 1Fh
        cp E_DIRT+1
        jr c,.walk
        cp E_DIAMOND
        jr z,.gem
        cp E_EXITO
        jr nz,.skip
        ; the open exit: go
        ld a,(exit_open)
        or a
        jr nz,.found
        jr .skip
.gem:   ld a,(exit_open)            ; once the exit is open, diamonds are
        or a                        ; just stepping stones
        jr z,.found
.walk:  ; first move: inherit from DE, or B + 1 if DE is the start
        ex de,hl
        set 3,h
        ld a,(hl)
        res 3,h
        ex de,hl
        cp 0FFh
        jr nz,.inh
        pop de
        pop bc
        push bc
        push de
        ld a,b
        inc a
.inh:   set 3,h
        ld (hl),a
        res 3,h
        ; a drop site?  earth with a resting rock above: dig it out and the
        ; rock falls (best of all onto a creature or the magic wall)
        ld a,(ai_dgood)
        or a
        jr nz,.enq                  ; already have a good one
        ld a,(hl)
        and 1Fh
        cp E_DIRT
        jr nz,.enq
        push hl
        ld bc,-CAVEW
        add hl,bc
        ld a,(hl)
        pop hl
        and 1Fh
        cp E_BOULDER
        jr z,.rk
        cp E_DIAMOND
        jr nz,.enq
.rk:    call drop_good              ; A = 1 if something worth hitting is below
        ld b,a
        ld a,(ai_drop+1)
        or a
        jr z,.take                  ; the first (nearest) site
        ld a,b
        or a
        jr z,.enq
.take:  ld (ai_drop),hl
        ld a,b
        ld (ai_dgood),a
.enq:   ex de,hl                    ; enqueue
        ld hl,(bfs_tail)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (bfs_tail),hl
.skip:  pop de
        pop bc
        inc b
        ld a,b
        cp 4
        jp c,.dir
        jp .next
.found: ; HL = target, DE = the cell we reached it from
        ex de,hl
        set 3,h
        ld a,(hl)
        res 3,h
        pop de
        pop bc
        cp 0FFh
        jr nz,.go
        ld a,b                      ; target right next to the start
        inc a
.go:    dec a
        jr ai_set
.none:  ; no diamond in reach: go and bring a rock down
        ld hl,(ai_drop)
        ld a,h
        or a
        jr z,.rnd
        set 3,h
        ld a,(hl)
        dec a
        jr ai_set
.rnd:   ; nothing at all: dig at random (but never into danger)
        call rand
        and 3
        ld b,a
        ld c,4
.try:   ld a,b
        add a,a
        add a,low DIROFF
        ld l,a
        ld h,high DIROFF
        ld e,(hl)
        inc l
        ld d,(hl)
        ld hl,(pl_addr)
        add hl,de
        set 3,h
        ld a,(hl)
        res 3,h
        cp 0FEh
        jr z,.tn
        ld a,(hl)
        and 1Fh
        cp E_DIRT+1
        jr c,.ok
        cp E_BOULDER                ; or push a boulder
        jr nz,.tn
        ld a,b
        and 1
        jr nz,.tn
.ok:    ld a,b
        jr ai_set
.tn:    ld a,b
        inc a
        and 3
        ld b,a
        dec c
        jr nz,.try
        ret

; A = direction 0-3 -> ai_keys
ai_set:
        ld e,a
        ld d,0
        ld hl,dir_keys
        add hl,de
        ld a,(hl)
        ld (ai_keys),a
        ret

dir_keys:
        db K_LEFT,K_UP,K_RIGHT,K_DOWN

; a firefly or butterfly at HL: mark the cells next to it, and next to
; every empty cell it could move into by the next tick
danger_fly:
        push bc
        push hl
        call mark
        ld de,DIROFF
        ld b,4
.l:     push de
        push hl
        ld a,(de)
        inc de
        add a,l
        ld l,a
        ld a,(de)
        adc a,h
        ld h,a
        call mark
        ld a,(hl)
        or a
        call z,mark4
        pop hl
        pop de
        inc de
        inc de
        djnz .l
        pop hl
        pop bc
        ret

; mark the four neighbours of HL (keeps BC, DE, HL)
mark4:
        push bc
        push de
        ld de,DIROFF
        ld b,4
.m:     push hl
        ld a,(de)
        inc de
        add a,l
        ld l,a
        ld a,(de)
        inc de
        adc a,h
        ld h,a
        call mark
        pop hl
        djnz .m
        pop de
        pop bc
        ret

; HL = dug-out cell under a rock: A = 1 if, straight below through space
; and earth, there is a creature or the magic wall (keeps HL, DE)
drop_good:
        push hl
        push de
        ld de,CAVEW
        ld b,8
.d:     add hl,de
        ld a,(hl)
        and 1Fh
        cp E_DIRT+1
        jr c,.n
        cp E_MAGIC
        jr z,.yes
        sub E_FIRE0
        cp E_BUTT3-E_FIRE0+1
        jr c,.yes
        jr .no
.n:     djnz .d
.no:    xor a
        jr .x
.yes:   ld a,1
.x:     pop de
        pop hl
        ret

; boulder or diamond: falling, or about to fall -> the cells below
danger_rock:
        push hl
        cp E_BOULDERF
        jr z,.f
        cp E_DIAMONDF
        jr z,.f
        cp E_DIAMOND+1
        jr nc,.out
        ld de,CAVEW                 ; at rest: dangerous only over a hole
        add hl,de
        ld a,(hl)
        or a
        jr nz,.out
        call mark
        add hl,de
        call mark
        jr .out
.f:     ld de,CAVEW
        add hl,de
        call mark
        dec hl                      ; it may roll off and drop either side
        call mark
        inc hl
        inc hl
        call mark
        dec hl
        add hl,de
        ld a,(hl)
        or a
        call z,mark
.out:   pop hl
        ret

; mark HL as danger if it is inside the cave
mark:
        push de
        push hl
        ld de,CAVE
        or a
        sbc hl,de
        jr c,.out                   ; above the cave
        ld de,CAVESZ
        sbc hl,de
        jr nc,.out                  ; below it
        pop hl
        set 3,h
        ld (hl),0FEh
        res 3,h
        pop de
        ret
.out:   pop hl
        pop de
        ret
