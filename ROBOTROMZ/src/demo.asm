; =====================================================================
;  demo.asm - the computer plays: part of the attract sequence
; =====================================================================

; called every tick after read_keys: in a demo, SPACE starts a real game,
; otherwise the AI supplies the keys
demo_ctl:
        ld a,(demo)
        or a
        ret z
        ld a,(sedge)
        and KS_SPACE
        jr z,.ai
        ld sp,STACK             ; a real game
        xor a
        ld (demo),a
        call new_game
        jp main_loop
.ai:    ld hl,(demotm)
        dec hl
        ld (demotm),hl
        ld a,h
        or l
        jp z,demo_end
        ld a,(framecnt)         ; think every 4th tick, hold the keys between
        and 3
        jr z,.think
        ld a,(dmk)
        ld (mkeys),a
        ld a,(dfk)
        ld (fkeys),a
        ret
.think: call demo_ai
        ld a,(mkeys)
        ld (dmk),a
        ld a,(fkeys)
        ld (dfk),a
        ret

; start a demo game on the next wave in the list
run_demo:
        ld a,1
        ld (demo),a
        ld hl,1500              ; 30 seconds
        ld (demotm),hl
        ld a,(demoidx)
        inc a
        and 7
        ld (demoidx),a
        ld hl,demo_waves
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        call new_game_at
        jp main_loop

demo_end:
        xor a
        ld (demo),a
        call snd_off
        ld a,PG_HEROES          ; on to the high scores
        ld (page),a
        jp attract

demo_waves: db 1,3,2,8,5,4,7,11

; ---------------------------------------------------------------------
; pick movement and fire keys
demo_ai:
        ld a,0FFh
        ld (td),a               ; nearest threat
        ld (sd),a               ; nearest robot to shoot
        ld (hd),a               ; nearest human
        ld a,(objtop)
        or a
        jr z,.bul
        ld b,a
        ld ix,OBJ
.l:     ld a,(ix+OT)
        or a
        jr z,.nx
        ld a,(ix+OST)
        or a
        jr nz,.nx
        ld a,(px+1)
        ld c,a
        ld a,(ix+OX)
        sub c
        ld d,a                  ; D = dx
        ld a,(py+1)
        ld c,a
        ld a,(ix+OY)
        sub c
        ld e,a                  ; E = dy
        call cheb               ; A = max(|dx|,|dy|)
        ld c,a
        ld a,(ix+OFL)
        bit 3,a
        jr z,.rob
        ld hl,hd                ; human
        call closer
        jr .nx
.rob:   bit 0,a
        jr z,.nx
        ld hl,td                ; deadly
        call closer
        ld a,(ix+OFL)
        bit 1,a
        jr z,.nx
        call align_score        ; shootable: prefer ones lined up with a shot
        ld hl,sd
        call closer
.nx:    push de
        ld de,OBJSZ
        add ix,de
        pop de
        djnz .l
.bul:   ld ix,EBUL              ; bullets are threats too
        ld b,MAXEB
.bl:    ld a,(ix+BT)
        or a
        jr z,.bn
        ld a,(px+1)
        ld c,a
        ld a,(ix+BX)
        sub c
        ld d,a
        ld a,(py+1)
        ld c,a
        ld a,(ix+BY)
        sub c
        ld e,a
        call cheb
        ld c,a
        ld hl,td
        call closer
.bn:    ld de,EBSZ
        add ix,de
        djnz .bl

        ; fire at the nearest robot
        xor a
        ld (fkeys),a
        ld a,(sd)
        inc a
        jr z,.nf
        ld a,(sd+1)
        ld d,a
        ld a,(sd+2)
        ld e,a
        call aim_dir
        ld hl,aimbits
        add a,l
        ld l,a
        jr nc,.ab
        inc h
.ab:    ld a,(hl)
        ld (fkeys),a
.nf:    ; move
        ld a,(td)
        cp 5
        jr nc,.nothreat
        ld a,(td+1)             ; run away from it
        neg
        ld d,a
        ld a,(td+2)
        neg
        ld e,a
        ld a,d                  ; lined up on an axis: sidestep too
        or a
        jr nz,.s1
        ld a,(px+1)
        cp CX
        ld d,1
        jr c,.s1
        ld d,-1
.s1:    ld a,e
        or a
        jr nz,.go
        ld a,(py+1)
        cp CY
        ld e,1
        jr c,.go
        ld e,-1
        jr .go
.nothreat:
        ld a,(hd)               ; save a human
        inc a
        jr z,.nh
        ld a,(hd+1)
        ld d,a
        ld a,(hd+2)
        ld e,a
        jr .go
.nh:    ld a,(sd)               ; close in, but not too close
        cp 10
        jr c,.wander
        inc a
        jr z,.wander
        ld a,(sd+1)
        ld d,a
        ld a,(sd+2)
        ld e,a
        jr .go
.wander:
        ld a,(framecnt)
        and 31
        jr nz,.keep
        call rand_dir
        ld a,d
        ld (wdx),a
        ld a,e
        ld (wdy),a
.keep:  ld a,(wdx)
        ld d,a
        ld a,(wdy)
        ld e,a
.go:    ld c,0                  ; signs -> key bits, kept off the walls
        ld a,d
        or a
        jr z,.y
        jp m,.lf
        ld a,(px+1)
        cp XMAX-1
        jr nc,.y
        set 3,c
        jr .y
.lf:    ld a,(px+1)
        cp XMIN+2
        jr c,.y
        set 2,c
.y:     ld a,e
        or a
        jr z,.done
        jp m,.up
        ld a,(py+1)
        cp YMAX-1
        jr nc,.done
        set 1,c
        jr .done
.up:    ld a,(py+1)
        cp YMIN+2
        jr c,.done
        set 0,c
.done:  ld a,c
        ld (mkeys),a
        ret

; C = distance + 3 x how far (D, E) is off the nearest of the 8 directions
align_score:                    ; (B preserved; HL clobbered)
        push bc
        ld a,d
        call abs_a
        ld b,a                  ; B = |dx|
        ld a,e
        call abs_a
        ld l,a                  ; L = |dy|
        cp b
        jr c,.a1
        ld a,b
.a1:    ld h,a                  ; H = min(|dx|,|dy|): off the straight lines
        ld a,b
        sub l
        call abs_a              ; A = ||dx|-|dy||: off the diagonals
        cp h
        jr c,.a2
        ld a,h
.a2:    ld l,a
        add a,a
        add a,l
        pop bc
        add a,c
        jr c,.big
        cp 0FFh
        jr c,.ok
.big:   ld a,0FEh
.ok:    ld c,a
        ret

; A = max(|D|, |E|)
cheb:   ld a,d
        call abs_a
        ld c,a
        ld a,e
        call abs_a
        cp c
        ret nc
        ld a,c
        ret

; HL -> (distance, dx, dy): replace it if C is closer (D, E = dx, dy)
closer: ld a,c
        cp (hl)
        ret nc
        ld (hl),a
        inc hl
        ld (hl),d
        inc hl
        ld (hl),e
        ret

; aim direction 0 U .. 7 UL -> fire key bits
aimbits: db 01h,09h,08h,0Ah,02h,06h,04h,05h
