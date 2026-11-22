; =====================================================================
;  stage.asm - the route, themes, the start and the checkpoints
;  STAGES: 15 records (course, theme, left child, right child, tier).
;  At a checkpoint the side of the road you are on picks the next
;  course: left the easier one, right the harder.
; =====================================================================

STSZ    equ 7

; A = stage record index -> HL = its record
stage_rec:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; 7n
        ld de,STAGES
        add hl,de
        ret

; set up course A (record index): build it, take its theme
load_stage:
        ld (node),a
        ld hl,forkshown
        ld (hl),0
        push af                 ; on the route (for the map)
        ld hl,1
        or a
        jr z,.rb
.rs:    add hl,hl
        dec a
        jr nz,.rs
.rb:    ld de,(routebits)
        ld a,e
        or l
        ld e,a
        ld a,d
        or h
        ld d,a
        ld a,(demo)
        or a
        jr nz,.rd
        ld (routebits),de
.rd:    pop af
        call stage_rec
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (thptr),de
        ld de,nodel
        ld bc,3
        ldir                    ; left, right, tier
        ld hl,(thptr)
        call set_theme
        pop hl
        jp build_course

; HL = theme record
set_theme:
        ld de,pal_a
        ld bc,13
        ldir
        ld e,(hl)               ; sky
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)               ; name
        inc hl
        ld d,(hl)
        inc hl
        ld (thname),de
        ld de,carsmax
        ld bc,6
        ldir
        call make_pairs
        pop hl
        jp sky_init

; build CPAIR (runs: grass rumble road line road line road rumble grass)
; and CPAIRF (a fork: grass rumble road rumble grass rumble road rumble
; grass) from pal_a, pal_b, pal_far
make_pairs:
        ld hl,ord_road
        ld de,CPAIR
        call .pairs
        ld hl,ord_fork
        ld de,CPAIRF
.pairs: ld (mp_ord),hl
        push de
        ld ix,pal_a             ; the three 9-run tables
        ld de,tt_a
        call .tab
        ld ix,pal_b
        ld de,tt_b
        call .tab
        ld hl,tt_f
        ld a,(pal_far)
        ld b,9
.f:     ld (hl),a
        inc hl
        djnz .f
        pop de                  ; [top][bottom][run]
        ld ix,tt_a
        ld c,3
.t:     ld hl,tt_a
        ld b,3
.b:     push bc
        push ix
        ld b,9
.k:     ld a,(ix+0)
        rlca
        rlca
        rlca
        rlca
        or (hl)
        ld (de),a
        inc de
        inc hl
        inc ix
        djnz .k
        pop ix
        pop bc
        djnz .b
        push de
        ld de,9
        add ix,de
        pop de
        dec c
        jr nz,.t
        ret
; IX = palette (grass, rumble, road, line, line-on) -> 9 run colours at DE
.tab:   ld a,(ix+3)
        ld c,a
        ld a,(ix+4)
        or a
        jr nz,.ln
        ld c,(ix+2)             ; no lines: the line runs are road
.ln:    ld hl,(mp_ord)
        ld b,9
.o:     push bc
        ld a,(hl)
        inc hl
        cp 3
        jr nz,.n
        ld a,c
        jr .w
.n:     push hl
        push ix
        pop hl
        add a,l
        ld l,a
        jr nc,.n2
        inc h
.n2:    ld a,(hl)
        pop hl
.w:     ld (de),a
        inc de
        pop bc
        djnz .o
        ret
ord_road: db 0,1,2,3,2,3,2,1,0
ord_fork: db 0,1,2,1,0,1,2,1,0

; ---------------------------------------------------------------------
; a new race
new_race:
        xor a
        ld (stage),a
        ld hl,score
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld (boost),a
        ld (combo),a
        ld (gameend),a
        ld a,65h
        ld (timesec),a
        ld a,50
        ld (tfield),a
        ld a,(startnode)        ; (tests: start further on)
        call load_stage
        ld a,1
        ld (stage),a
        call clear_cars
        ld hl,0
        ld (pos),hl
        ld (px),hl
        ld (speed),hl
        ld (skyx),hl
        ld a,BOOSTMAX/2
        ld (boost),a
        ld a,GS_START
        ld (gstate),a
        ld a,200
        ld (gtimer),a
        ld a,40
        ld (spawnt),a
        ld a,1
        ld (cdown),a
        ret

clear_cars:
        ld hl,CARS
        ld b,MAXCARS
        ld de,CARSZ
.c:     ld (hl),0
        add hl,de
        djnz .c
        ret

; the countdown: messages and beeps while gtimer runs down from 200
countdown:
        ld a,(gstate)
        cp GS_START
        ret nz
        ld a,(gtimer)
        ld hl,txt_3
        cp 150
        jr z,.say
        ld hl,txt_2
        cp 100
        jr z,.say
        ld hl,txt_1
        cp 50
        jr z,.say
        cp 1
        ret nz
        ld hl,txt_go
        ld a,WHITE*16+RED
        ld (msgcol),a
        xor a
        call hud_message
        ld hl,SFX_GO
        ld a,5
        jp sfx
.say:   ld a,YELLOW*16+BLACK
        ld (msgcol),a
        xor a
        call hud_message
        ld hl,SFX_BEEP
        ld a,5
        jp sfx

txt_3:  db "3",0
txt_2:  db "2",0
txt_1:  db "1",0
txt_go: db "GO!",0

; ---------------------------------------------------------------------
; past the end of a course: the checkpoint (or the goal)
next_stage:
        ld a,(nodet)
        cp 4
        jp nc,.goal
        ; the fork's width at the end: D = SPL[len] * 8
        ld hl,(crs_len)
        ld de,TRK_SPL
        add hl,de
        ld a,(hl)
        ld (fk_end),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (fk_d),hl
        ; which road?  right of the middle: the right one
        srl h
        rr l
        ex de,hl
        ld hl,(px)
        or a
        sbc hl,de
        ld a,1
        jp p,.right
        xor a
.right: ld (fk_side),a
        or a
        jr z,.left
        ; the right road: it is the road now; the left one goes with
        ; the traffic on it
        ld de,(fk_d)
        ld hl,(px)
        or a
        sbc hl,de
        ld (px),hl
        ld ix,CARS
        ld b,MAXCARS
.cm:    ld l,(ix+C_X)
        ld h,(ix+C_X+1)
        or a
        sbc hl,de
        ld (ix+C_X),l
        ld (ix+C_X+1),h
        ld l,(ix+C_TX)
        ld h,(ix+C_TX+1)
        or a
        sbc hl,de
        ld (ix+C_TX),l
        ld (ix+C_TX+1),h
        push de
        ld de,CARSZ
        add ix,de
        pop de
        djnz .cm
        ld a,(noder)
        jr .ld
.left:  ld a,(nodel)
.ld:    call load_stage
        ; the road not taken, close by, drifting away
        ld hl,TRK_SPL
        ld a,(fk_end)
        ld c,a
        ld b,48
.gh:    ld a,c
        cp 127
        jr nc,.gs1
        inc c
.gs1:   ld a,(fk_side)
        or a
        ld a,c
        jr z,.gs2
        neg
.gs2:   ld (hl),a
        inc hl
        djnz .gh
        ld hl,48
        ld (ghostend),hl
        ld hl,stage
        inc (hl)
        ; more time: the next course's bonus
        ld a,(timesec)
        add a,TIMEBONUS
        daa
        jr nc,.t
        ld a,99h
.t:     ld (timesec),a
        ld a,GREEN*16+BLACK
        ld (msgcol),a
        ld hl,txt_ext
        xor a
        call hud_message
        ld hl,SFX_CHECK
        ld a,6
        call sfx
        ; time left as points: 1000 a second
        ret
.goal:  ld a,GS_GOAL
        ld (gstate),a
        ld a,1
        ld (goalhit),a
        ld hl,TRK_GOAL
        call play_tune
        ld a,250
        ld (gtimer),a
        ld a,YELLOW*16+BLUE
        ld (msgcol),a
        ld a,(node)             ; the goal's name
        sub 10
        add a,a
        ld e,a
        ld d,0
        ld hl,GOALS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,forkbuf
        push de
        ld bc,txt_goal
.gc:    ld a,(bc)
        ld (de),a
        inc bc
        inc de
        or a
        jr nz,.gc
        dec de
.gn:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.gn
        pop hl
        xor a
        call hud_message
        ld a,250
        ld (msgtime),a
        ; bonus: 10,000 points a second left
        ld a,(timesec)
        or a
        jr z,.g2
.gb:    push af
        ld de,1000h
        call add_score
        pop af
        sub 1
        daa
        jr nz,.gb
.g2:    ld hl,SFX_GOAL
        ld a,7
        jp sfx

TIMEBONUS equ 45h
txt_ext:  db "CHECKPOINT  EXTENDED TIME",0
txt_goal: db "GOAL! ",0

; the banner as the fork comes up: "< LEFT   RIGHT >"
fork_banner:
        ld a,(forkshown)
        or a
        ret nz
        ld a,(nodet)
        cp 4
        ret nc
        call cur_seg
        ld de,(forkseg)
        or a
        sbc hl,de
        ret c
        ld a,1
        ld (forkshown),a
        ld a,(nodel)
        call stage_name
        ld de,forkbuf
        ld a,'<'
        ld (de),a
        inc de
        ld a,' '
        ld (de),a
        inc de
        call .copy
        ld b,4
        ld a,' '
.sp:    ld (de),a
        inc de
        djnz .sp
        push de
        ld a,(noder)
        call stage_name
        pop de
        call .copy
        ld a,' '
        ld (de),a
        inc de
        ld a,'>'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld a,YELLOW*16+BLUE
        ld (msgcol),a
        ld hl,forkbuf
        xor a
        call hud_message
        ld a,200
        ld (msgtime),a
        call rand8              ; the computer picks a road at random
        and 1
        ld (ai_fork),a
        ret
.copy:  ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr .copy

; A = stage record -> HL = its theme's name
stage_name:
        call stage_rec
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,15
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret
