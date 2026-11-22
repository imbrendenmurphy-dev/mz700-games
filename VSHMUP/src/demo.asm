; =====================================================================
;  demo.asm - the computer pilot for the attract demo
;
;  Every other tick it builds a small danger map round the ship (7 x 6
;  cells): where bullets will be over the next 4 ticks and where the
;  enemies are.  Then it scores the 9 moves (and staying put): danger
;  first, then lining up under its target (a capsule or medal if there
;  is one, else the nearest enemy or the boss), then keeping low.
;  It always fires, and bombs when it is cornered.
; =====================================================================

DMW     equ 7                   ; danger map: columns px-3..px+3
DMH     equ 6                   ;             rows    py-2..py+3

demo_ctl:
        ld a,(demo)
        or a
        ret z
        ld a,(skeys)            ; SPACE (or any button) ends the demo
        and KS_SPACE
        jr z,.go
        ld a,1
        ld (gameend),a
        ld a,1
        ld (demoquit),a
        ret
.go:    ld hl,(demotm)
        dec hl
        ld (demotm),hl
        ld a,h
        or l
        jr nz,.t
        ld a,1
        ld (gameend),a
.t:     ld a,(framecnt)
        and 1
        jr z,.think
        ld a,(dkeys)
        ld (keys),a
        ret
.think: call danger_map
        call pick_target
        call choose_move
        ld (dkeys),a
        ld (keys),a
        ret

; ---------------------------------------------------------------------
danger_map:
        ld hl,dmap
        ld b,DMW*DMH
.c:     ld (hl),0
        inc hl
        djnz .c
        ; bullets: now and the next 4 ticks
        ld ix,EBUL
        ld b,MAXEB
.b:     push bc
        ld a,(ix+BT)
        or a
        jr z,.bn
        ld l,(ix+BXL)
        ld h,(ix+BX)
        ld e,(ix+BYL)
        ld d,(ix+BY)
        ld b,5
.p:     push bc
        push hl
        push de
        ld c,h
        ld b,d
        ld a,30
        call dmark
        pop de
        pop hl
        ld a,(ix+BVX)           ; on a tick
        ld c,a
        rla
        sbc a,a
        ld b,a
        add hl,bc
        ld a,(ix+BVY)
        ld c,a
        rla
        sbc a,a
        ld b,a
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        djnz .p
.bn:    ld de,EBSZ
        add ix,de
        pop bc
        djnz .b
        ; enemies: their cells and the one below
        ld ix,ENEMY
        ld b,MAXEN
.e:     push bc
        ld a,(ix+ET)
        or a
        jr z,.en
        ld b,(ix+EH)
        inc b
        ld a,(ix+EY)
        ld d,a
.er:    push bc
        ld b,(ix+EW)
        ld c,(ix+EX)
.ec:    push bc
        ld b,d
        ld a,40
        call dmark
        pop bc
        inc c
        djnz .ec
        inc d
        pop bc
        djnz .er
.en:    ld de,ENSZ
        add ix,de
        pop bc
        djnz .e
        ; the boss: its bottom rows
        ld a,(bossact)
        or a
        ret z
        ld a,(bh)
        ld b,a
        ld a,(by+1)
        ld d,a
.br:    push bc
        ld a,(bw)
        ld b,a
        ld a,(bx+1)
        ld c,a
.bc:    push bc
        ld b,d
        ld a,60
        call dmark
        pop bc
        inc c
        djnz .bc
        inc d
        pop bc
        djnz .br
        ret

; B = row, C = column, A = weight: add to the danger map if inside
dmark:
        push de
        call .mk
        pop de
        ret
.mk:    ld e,a
        ld a,(py+1)
        sub 2
        ld d,a
        ld a,b
        sub d
        cp DMH
        ret nc
        ld b,a                  ; map row
        ld a,(px+1)
        sub 3
        ld d,a
        ld a,c
        sub d
        cp DMW
        ret nc
        ld c,a
        ld a,b                  ; dmap + row*7 + column
        add a,a
        add a,a
        add a,a
        sub b
        add a,c
        ld hl,dmap
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        add a,e
        jr nc,.s
        ld a,255
.s:     ld (hl),a
        ret

; the column to line up with: an item, else the nearest enemy, else boss
pick_target:
        ld a,(px+1)
        ld (dtx),a
        ld iy,ITEMS             ; an item on the screen?
        ld b,MAXIT
.i:     ld a,(iy+IK)
        or a
        jr z,.in
        ld a,(iy+IY)
        cp 8
        jr c,.in                ; (not too high up)
        ld a,(iy+IX_)
        ld (dtx),a
        ret
.in:    ld de,ITSZ
        add iy,de
        djnz .i
        ld a,(bossact)
        cp 2
        jr nz,.en
        ld a,(bw)
        srl a
        ld hl,bx+1
        add a,(hl)
        ld (dtx),a
        ret
.en:    ld ix,ENEMY             ; the lowest enemy on the screen
        ld b,MAXEN
        ld c,0                  ; best row so far
.e:     ld a,(ix+ET)
        or a
        jr z,.ex
        ld a,(ix+EY)
        cp PFH-4
        jr nc,.ex
        cp c
        jr c,.ex
        ld c,a
        ld a,(ix+EX)
        cp PFW
        jr nc,.ex
        ld (dtx),a
.ex:    ld de,ENSZ
        add ix,de
        djnz .e
        ret

; -> A = keys: the move with the lowest cost
choose_move:
        ld a,0FFh
        ld (dbest),a
        ld (dbest+1),a
        xor a
        ld (dbk),a
        ld hl,dmoves
.m:     ld a,(hl)
        cp 0FFh
        jr z,.done
        ld (dmk),a
        inc hl
        ld c,(hl)               ; dx
        inc hl
        ld b,(hl)               ; dy
        inc hl
        push hl
        ; new place (in the map: column 3+dx, row 2+dy) inside the field?
        ld a,(px+1)
        add a,c
        cp 1
        jr c,.no
        cp PFW-1
        jr nc,.no
        ld a,(py+1)
        add a,b
        cp 1
        jr c,.no
        cp PFH-1
        jr nc,.no
        ; danger at the nose and body
        ld a,b
        add a,2
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e                   ; row * 7
        add a,3
        add a,c
        ld e,a
        ld d,0
        ld hl,dmap
        add hl,de
        ld a,(hl)
        ld de,DMW
        add hl,de
        add a,(hl)
        jr nc,.d1
        ld a,255
.d1:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; danger x 8
        push hl
        ; distance from the target column
        ld a,(px+1)
        add a,c
        ld d,a
        ld a,(dtx)
        sub d
        jr nc,.ab
        neg
.ab:    ld e,a
        ld d,0
        pop hl
        add hl,de
        add hl,de
        ; keep near row 20
        ld a,(py+1)
        add a,b
        sub 20
        jr nc,.ay
        neg
.ay:    ld e,a
        add hl,de
        ; better?
        ld de,(dbest)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.no
        ld (dbest),hl
        ld a,(dmk)
        ld (dbk),a
.no:    pop hl
        jr .m
.done:  ld a,(dbk)
        or K_FIRE
        ld b,a
        ; cornered (danger even at the best) with a bomb: use it
        ld hl,(dbest)
        ld de,8*30
        or a
        sbc hl,de
        ld a,b
        ret c
        or K_BOMB
        ret

; key bits, dx, dy
dmoves: db 0,0,0
        db K_LEFT,-1,0
        db K_RIGHT,1,0
        db K_UP,0,-1
        db K_DOWN,0,1
        db K_LEFT|K_UP,-1,-1
        db K_RIGHT|K_UP,1,-1
        db K_LEFT|K_DOWN,-1,1
        db K_RIGHT|K_DOWN,1,1
        db 0FFh
