; =====================================================================
;  demo.asm - the computer driver (the attract demo, and tests: set
;  `autopilot` to let it race a real game)
;
;  It holds a lane, leans into the bends against their pull, changes
;  lanes for slower cars ahead, brakes for the sharpest bends, and uses
;  the boost on straights.
; =====================================================================

demo_ctl:
        ld a,(demo)
        ld hl,autopilot
        or (hl)
        jr nz,ai_drive
        ld a,(keys)
        ld (ckeys),a
        ; SPACE in the demo is handled by demo_watch
        ret

ai_drive:
        ld a,(demo)
        or a
        jr z,.go
        ld a,(sedge)            ; a key in the demo: back to the title
        and KS_SPACE
        jr z,.go
        ld a,1
        ld (gameend),a
        ld (demoquit),a
.go:    ld c,K_UP               ; C = the keys it presses
        ; the bend ahead: curve 6 segments on
        call cur_seg
        ld de,TRK_CURV+6
        add hl,de
        ld a,(hl)
        ld (ai_cv),a
        ; a slower car ahead in our lane?  move over
        call ai_traffic
        ; aim: lane + lean into the bend (curve * speed hi * 3)
        ld a,(ai_cv)
        ld e,a
        ld a,(speed+1)
        ld l,a
        ld a,e
        bit 7,a
        push af
        jr z,.p
        neg
.p:     ld e,a
        call mul8               ; |curve| * speed hi
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; x 3
        pop af
        jr z,.pp
        call neg_hl
.pp:    ld de,(ai_lane)
        add hl,de               ; target
        ld a,(ai_fork)          ; in a fork: the chosen road
        or a
        jr z,.nf
        push hl
        call cur_seg
        ld de,TRK_SPL+4
        add hl,de
        ld e,(hl)
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        pop de
        add hl,de
.nf:
        ld de,(px)
        or a
        sbc hl,de               ; target - px
        ld de,6
        bit 7,h
        jr nz,.left
        or a
        sbc hl,de
        jr c,.steady
        set 3,c                 ; right
        jr .steady
.left:  add hl,de
        jr c,.steady
        set 2,c
.steady:
        ; brake for a sharp bend when quick
        ld a,(ai_cv)
        bit 7,a
        jr z,.ap
        neg
.ap:    cp 5
        jr c,.nb
        ld a,(speed+1)
        cp 5
        jr c,.nb
        ld c,K_DOWN
        jr .done
.nb:    ; boost on a straight with plenty left
        ld a,(ai_cv)
        or a
        jr nz,.done
        ld a,(boost)
        cp 60
        jr c,.done
        ld a,(speed+1)
        cp 5
        jr c,.done
        set 4,c
.done:  ld a,c
        ld (ckeys),a
        ret

; lane choice: if a car is 0..250 ahead within 70 of our lane, take the
; nearest lane that is clear
ai_traffic:
        ld hl,(ai_lane)
        call lane_blocked
        ret nc
        ld hl,(ai_lane)         ; try the others: middle first, then sides
        ld de,0
        call .try
        ret c
        ld de,-107
        call .try
        ret c
        ld de,107
.try:   ld a,e
        cp l
        jr nz,.t
        ld a,d
        cp h
        jr z,.no                ; (the one we are in)
.t:     push hl
        push de
        ex de,hl
        call lane_blocked
        pop de
        pop hl
        jr c,.no
        ld (ai_lane),de
        scf
        ret
.no:    or a
        ret

; HL = lane x: carry if a car ahead (0..250) is within 70 of it
lane_blocked:
        ld (ai_tx),hl
        ld ix,CARS
        ld b,MAXCARS
.c:     ld a,(ix+C_ON)
        or a
        jr z,.n
        ld l,(ix+C_Z)           ; rel = z - pos - PLZ
        ld h,(ix+C_Z+1)
        ld de,(pos)
        or a
        sbc hl,de
        jr c,.n
        ld de,PLZ-10
        sbc hl,de
        jr c,.n
        ld de,260
        sbc hl,de
        jr nc,.n
        ld l,(ix+C_X)
        ld h,(ix+C_X+1)
        ld de,(ai_tx)
        or a
        sbc hl,de
        bit 7,h
        call nz,neg_hl
        ld de,90
        or a
        sbc hl,de
        ret c
.n:     ld de,CARSZ
        add ix,de
        djnz .c
        or a
        ret
