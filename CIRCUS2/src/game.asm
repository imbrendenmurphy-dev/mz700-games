; =====================================================================
;  game.asm - acts, seesaw, clowns, balloon rows
; =====================================================================
S_NONE          equ 0
S_SEAT          equ 1
S_FLY           equ 2
S_TOWER         equ 3
S_SPLAT         equ 4

CS_STATE        equ 0
CS_X            equ 1               ; 8.8 centre x (units)
CS_Y            equ 3               ; 8.8 top y (pixels)
CS_VX           equ 5
CS_VY           equ 7
CS_T            equ 9
CS_ANIM         equ 10
CS_POPS         equ 11
CS_FL           equ 12              ; bit0 hoop up, bit1 hoop down, bit2 spin, bit3 landing checked
CS_SIDE         equ 13
CS_CD           equ 14              ; balloon collision cooldown

; row record
RW_LEFT         equ 0
RW_Y            equ 1               ; char row of the balloons (without bob)
RW_OFF          equ 2               ; 8.8 offset (units, 0..159)
RW_SPD          equ 4
RW_COL          equ 6               ; colour index 0..2
RW_DCOFS        equ 7               ; drawn cell offset (FF = redraw)
RW_DY           equ 8               ; drawn char row (FF = none)
RW_CLR          equ 9               ; ROW CLEAR announced

; gravity and launch speeds come from this act's PHYS row (build.py)
PHYS_SIZE       equ 32
LAUNCH_Y        equ 140
LAND_Y0         equ 152             ; feet window for landing
LAND_Y1         equ 164
FLOOR_FEET      equ 168
HW_NORM         equ 16              ; a 9-cell plank
HW_WIDE         equ 24              ; 13 cells

T_NORM          equ 0
T_GIFT          equ 1
T_BOMB          equ 2
T_STEEL         equ 3

AF_MONKEY       equ 1
AF_HOOP         equ 2
AF_BOB          equ 4
AF_BONUS        equ 8
AF_PRIZE        equ 16

P_BG            equ 0               ; palette slots
P_B0            equ 1
P_A1            equ 4
P_A2            equ 5
P_HAT           equ 6
P_BODY          equ 7
P_PLANK         equ 8
P_HUD           equ 9
P_BOMB          equ 10
P_SEAM          equ 11

G_BALLOON       equ 47h             ; glyphs (bank 0 unless noted)
G_STRING        equ 35h
G_HAT           equ 41h
G_BODY          equ 44h             ; bank 1 little men 43h, 44h, 45h
G_STAR          equ 6Bh

; ---------------------------------------------------------------------
; game entry: A = 0 game, 1 demo.  Returns when the game (or demo) ends
; ---------------------------------------------------------------------
game_main:
        push af
        ld hl,GAMEVARS
        ld de,GAMEVARS+1
        ld bc,GAMEVARS_END-GAMEVARS-1
        ld (hl),0
        ldir
        pop af
        ld (demo),a
        call mus_stop
        call sfx_stop
        ld a,(difficulty)
        ld hl,lives_by_diff
        call add_hl_a
        ld a,(hl)
        ld (lives),a
        ld a,2
        ld (nextlife),a
        ld a,(demo)
        or a
        jr z,.actloop
        ld a,(demo_act)
        ld (act),a
        ld a,9
        ld (lives),a
.actloop:
        call act_setup
        call act_intro
        jr nz,.abort
        call play_act
        ld a,(gameresult)
        or a
        jr nz,.ended
        call act_clear
        ld a,(demo)
        or a
        jr nz,.abort
        ld a,(act)
        inc a
        cp NACTS
        jr c,.n
        ld hl,encore
        inc (hl)
        xor a
.n:     ld (act),a
        jr .actloop
.ended: cp 2
        jr z,.abort
        ld a,(demo)
        or a
        jr nz,.abort
        call game_over
        call hiscore_check
.abort: call mus_stop
        jp sfx_stop

lives_by_diff:  db 5,4,3

; HL += A
add_hl_a:
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; ---------------------------------------------------------------------
; act set-up
; ---------------------------------------------------------------------
act_ptr:
        ld a,(act)
        add a,a
        ld hl,acttab
        call add_hl_a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

act_setup:
        ld hl,ACTVARS
        ld de,ACTVARS+1
        ld bc,GAMEVARS_END-ACTVARS-1
        ld (hl),0
        ldir
        call act_ptr
        ld de,pal
        ld bc,12
        ldir
        ld a,(hl)
        ld (nrows),a
        inc hl
        ld a,(hl)
        ld (actflags),a
        inc hl
        ld de,4                     ; name, hint
        add hl,de
        push hl
        ld a,(encore)               ; this act's gravity: floaty early on
        or a
        ld a,9
        jr nz,.ph
        ld a,(act)
.ph:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; x32
        ld de,PHYS
        add hl,de
        ld de,phys
        ld bc,PHYS_SIZE
        ldir
        pop hl
        ld a,(nrows)
        or a
        jr z,.norows
        ld b,a
        ld ix,rows
        ld de,slots
.rl:    push bc
        ld a,(hl)                   ; char row
        ld (ix+RW_Y),a
        inc hl
        ld c,(hl)                   ; speed
        inc hl
        ld b,(hl)
        inc hl
        call scale_speed
        ld (ix+RW_SPD),c
        ld (ix+RW_SPD+1),b
        ld a,(hl)                   ; colour
        ld (ix+RW_COL),a
        inc hl
        ld b,20                     ; slots
        ld c,0
.sl:    ld a,(hl)
        ld (de),a
        or a
        jr z,$+3
        inc c
        inc hl
        inc de
        djnz .sl
        ld (ix+RW_LEFT),c
        ld a,(balloons_left)
        add a,c
        ld (balloons_left),a
        ld (balloons_total),a
        ld b,160
        call rand_below
        ld (ix+RW_OFF+1),a
        ld (ix+RW_OFF),0
        ld (ix+RW_DCOFS),0FFh
        ld (ix+RW_DY),0FFh
        ld (ix+RW_CLR),0
        push de
        ld de,16
        add ix,de
        pop de
        pop bc
        djnz .rl
.norows:
        call build_arena
        ; seesaw and clowns
        ld hl,80*256
        ld (see_x),hl
        ld a,HW_NORM
        ld (see_hw),a
        ld ix,clown0
        ld (ix+CS_STATE),S_SEAT
        call spawn_tower
        ld a,(actflags)
        and AF_MONKEY
        jr z,.nm
        ld ix,monkey
        ld (ix+0),1
        ld (ix+1),50
        ld (ix+2),1
        ld (ix+4),60
.nm:    ld a,(actflags)
        and AF_HOOP
        jr z,.nh
        ld a,1
        ld (hoop),a
        ld a,80
        ld (hoop+1),a
.nh:    ld a,(actflags)
        and AF_BONUS
        jr z,.nb
        ld hl,750
        ld (bonus_time),hl
.nb:    call bob_rows
        call rows_bg
        jp hud_draw

; BC = speed (signed 8.8): easy 3/4, hard 5/4, +1/4 per encore
scale_speed:
        push de
        push hl
        ld h,b
        ld l,c
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e                        ; DE = speed/4
        ld a,(difficulty)
        or a
        jr nz,.n1
        or a
        sbc hl,de
        jr .enc
.n1:    cp 2
        jr nz,.enc
        add hl,de
.enc:   ld a,(encore)
        or a
        jr z,.done
        cp 4
        jr c,$+4
        ld a,4
        ld b,a
.el:    add hl,de
        djnz .el
.done:  ld b,h
        ld c,l
        pop hl
        pop de
        ret

; ---------------------------------------------------------------------
; the arena background: canopy, poles, rope or bunting, canvas seams,
; ledges, floor, lights, HUD
; ---------------------------------------------------------------------
build_arena:
        ld a,(pal+P_BG)
        call bg_fill
        ; canopy: a zig-zag valance in the two accent colours
        ld d,CANOPY_ROW
        ld e,0
.cn:    ld a,e
        and 2
        ld a,(pal+P_A1)
        jr z,$+5
        ld a,(pal+P_A2)
        call fg_on_bg
        ld b,a
        ld c,42h                    ; upper-right triangle
        bit 0,e
        jr z,$+4
        ld c,56h                    ; upper-left
        call bg_put
        inc e
        ld a,e
        cp 40
        jr c,.cn
        ; rope (monkey acts) or bunting
        ld a,(actflags)
        and AF_MONKEY
        jr z,.bunt
        ld a,WHITE
        call fg_on_bg
        ld b,a
        ld c,70h                    ; line at the top of the cell
        ld d,ROPE_ROW
        ld e,1
        ld a,38
        call bg_fill_run
        jr .seams
.bunt:  ld d,ROPE_ROW
        ld e,2
.bn:    ld a,e
        and 4
        ld a,(pal+P_A1)
        jr z,$+5
        ld a,(pal+P_A2)
        call fg_on_bg
        ld b,a
        ld c,42h
        bit 0,e
        jr z,$+4
        ld c,56h
        call bg_put
        inc e
        ld a,e
        and 3
        jr nz,$+4
        inc e                       ; pennant, pennant, gap, gap
        inc e
        ld a,e
        cp 38
        jr c,.bn
        ; canvas seams: dotted lines every 8 columns, rows 15..19
.seams: ld a,(pal+P_SEAM)
        call fg_on_bg
        ld b,a
        ld c,4Fh
        ld d,15
.sr:    ld e,4
.sc:    call bg_put
        ld a,e
        add a,8
        ld e,a
        cp 38
        jr c,.sc
        inc d
        ld a,d
        cp 20
        jr c,.sr
        ; ledges for the tower clowns
        ld a,(pal+P_A2)
        call fg_on_bg
        ld b,a
        ld c,7Ah                    ; upper half block
        ld d,LEDGE_ROW
        ld e,1
        call bg_put
        ld e,38
        call bg_put
        ; floor (row 21): ring edge
        ld a,(pal+P_A2)
        rlca
        rlca
        rlca
        rlca
        or BLACK
        ld b,a
        ld c,7Ah
        ld d,FLOOR_ROW
        ld e,0
        ld a,40
        call bg_fill_run
        ; lights and HUD rows on black
        ld b,BLACK
        ld c,0
        ld d,LIGHTS_ROW
        ld e,0
        ld a,40*3
        call bg_fill_run
        ld d,HUD_ROW
        call row_dirty
        ld d,BAR_ROW
        call row_dirty
        xor a
        ld (poleph),a
        call poles_draw
        jp lights_draw

; A = fg colour -> A = attr with the act background
fg_on_bg:
        rlca
        rlca
        rlca
        rlca
        push bc
        ld b,a
        ld a,(pal+P_BG)
        or b
        pop bc
        ret

; barber-pole tent posts, columns 0 and 39, rows 1..20: diagonal
; stripes that roll down as poleph changes
poles_draw:
        ld d,1
.l:     ld a,d
        ld hl,poleph
        add a,(hl)
        and 2
        ld a,(pal+P_A1)
        ld c,a
        ld a,(pal+P_A2)
        jr z,.s
        ld b,c
        ld c,a
        ld a,b
.s:     rlca
        rlca
        rlca
        rlca
        or c                        ; fg one accent, bg the other
        ld b,a
        ld c,4Eh                    ; lower-right triangle
        ld e,0
        call bg_touch_put
        ld c,4Dh
        ld e,39
        call bg_touch_put
        inc d
        ld a,d
        cp FLOOR_ROW
        jr c,.l
        ret

; floor lights: one lit bulb in four, chasing
lights_draw:
        ld d,LIGHTS_ROW
        ld e,0
.l:     ld a,e
        ld hl,poleph
        add a,(hl)
        and 3
        ld a,(pal+P_A1)
        jr z,.on
        ld a,BLUE
        ld hl,pal+P_A1
        cp (hl)
        jr nz,.on
        ld a,MAGENTA
.on:    rlca
        rlca
        rlca
        rlca
        ld b,a                      ; on black
        ld c,G_BALLOON
        call bg_touch_put
        inc e
        ld a,e
        cp 40
        jr c,.l
        ret

; background cell that changes on its own (not a whole row): D = row,
; E = col, C = char, B = attr
bg_touch_put:
        push de
        call bg_addr
        ld a,(hl)
        cp c
        jr nz,.ch
        set 2,h
        ld a,(hl)
        cp b
        jr z,.same
        res 2,h
.ch:    ld (hl),c
        set 2,h
        ld (hl),b
        res 2,h
        call bg_touch
.same:  pop de
        ret

; ---------------------------------------------------------------------
; balloon rows
; ---------------------------------------------------------------------
move_rows:
        ld a,(nrows)
        or a
        ret z
        ld b,a
        ld ix,rows
.l:     ld l,(ix+RW_OFF)
        ld h,(ix+RW_OFF+1)
        ld e,(ix+RW_SPD)
        ld d,(ix+RW_SPD+1)
        add hl,de
        ld a,h
        cp 160
        jr c,.ok
        cp 208
        jr c,.sub
        add a,160                   ; below 0: wrap up
        jr .ok
.sub:   sub 160
.ok:    ld (ix+RW_OFF+1),a
        ld (ix+RW_OFF),l
        ld de,16
        add ix,de
        djnz .l
        ret

; bobbing rows (AF_BOB): the whole set moves down a row and back
bob_rows:
        ld hl,rowphase
        inc (hl)
        ld a,(actflags)
        and AF_BOB
        ret z
        ld a,(hl)
        and 32
        ld a,0
        jr z,$+3
        inc a
        ld (bob),a
        ret

; A = current char row of row IX
row_cy:
        ld a,(bob)
        add a,(ix+RW_Y)
        ret

; bring the balloon rows in the background up to date
rows_bg:
        ld a,(nrows)
        or a
        ret z
        ld b,a
        ld ix,rows
        ld hl,slots
.l:     push bc
        push hl
        call row_bg
        pop hl
        ld de,20
        add hl,de
        ld de,16
        add ix,de
        pop bc
        djnz .l
        ret

; row IX (slots at HL): redraw if it scrolled a cell, moved or changed
row_bg:
        ld (tmp_slots),hl
        ld a,(ix+RW_OFF+1)
        rrca
        rrca
        and 3Fh
        ld c,a                      ; cell offset 0..39
        call row_cy
        cp (ix+RW_DY)
        jr nz,.redo
        ld a,c
        cp (ix+RW_DCOFS)
        ret z
.redo:  ld (ix+RW_DCOFS),c
        ; clear the old band
        ld a,(ix+RW_DY)
        cp 0FFh
        call nz,.clear
        call row_cy
        ld (ix+RW_DY),a
        call .clear
        ; the balloons
        ld hl,(tmp_slots)
        ld b,0                      ; slot
.s:     ld a,(hl)
        or a
        jr z,.ns
        push hl
        push bc
        dec a
        ld (tmpc),a                 ; type
        ld a,b
        add a,a
        add a,(ix+RW_DCOFS)
        cp 40
        jr c,$+4
        sub 40
        ld e,a                      ; column
        dec a
        cp 38
        jr nc,.skip                 ; hidden behind a pole
        call row_cy
        ld d,a
        call balloon_look           ; C = char, B = attr
        call bg_put
        inc d
        ld a,(pal+P_SEAM)
        call fg_on_bg
        ld b,a
        ld c,G_STRING
        call bg_put
.skip:  pop bc
        pop hl
.ns:    inc hl
        inc b
        ld a,b
        cp 20
        jr c,.s
        ret
; blank rows A and A+1, columns 1..38
.clear: ld d,a
        ld a,(pal+P_BG)
        ld b,a
        ld c,0
        ld e,1
        ld a,38
        push de
        call bg_fill_run
        pop de
        inc d
        ld a,38
        jp bg_fill_run

; balloon of type (tmpc) in row IX -> C = char, B = attr
balloon_look:
        ld a,(tmpc)
        or a
        jr nz,.sp
        ld a,(ix+RW_COL)
        ld hl,pal+P_B0
        call add_hl_a
        ld a,(hl)
        call fg_on_bg
        ld b,a
        ld c,G_BALLOON
        ret
.sp:    cp T_GIFT
        jr nz,.nb
        ld a,(ix+RW_COL)
        ld hl,pal+P_B0
        call add_hl_a
        ld a,(hl)
        call fg_on_bg
        or 80h
        ld b,a
        ld c,8Fh                    ; striped ball (bank 1)
        ret
.nb:    cp T_BOMB
        jr nz,.st
        ld a,(pal+P_BOMB)
        call fg_on_bg
        or 80h
        ld b,a
        ld c,9Dh                    ; round bomb with a fuse (bank 1)
        ret
.st:    ld a,WHITE
        call fg_on_bg
        or 80h
        ld b,a
        ld c,84h                    ; ring (bank 1)
        ret

; slot pointer: C = row, B = slot -> HL = slots entry
slot_ptr:
        ld a,c
        add a,a
        add a,a
        ld l,a
        add a,a
        add a,a
        add a,l                     ; row * 20
        add a,b
        ld hl,slots
        jp add_hl_a

; IY = row record of row C
row_rec:
        push de
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld iy,rows
        add iy,de
        pop de
        ret

; column of slot B in row C -> A (0..39)
slot_col:
        push iy
        call row_rec
        ld a,(iy+RW_OFF+1)
        rrca
        rrca
        and 3Fh
        add a,b
        add a,b
        cp 40
        jr c,$+4
        sub 40
        pop iy
        ret

; force row C to be redrawn
row_redraw:
        push iy
        call row_rec
        ld (iy+RW_DCOFS),0FFh
        pop iy
        ret

; ---------------------------------------------------------------------
; main play loop for one act.  gameresult: 0 clear, 1 over, 2 quit
; ---------------------------------------------------------------------
play_act:
        call all_dirty
        ld a,(fieldcnt)
        ld (lastframe),a
.loop:  ld a,(turbo)
        or a
        call z,wait_frame
        call present
        call get_controls
        ld a,(demo)
        or a
        jr z,.nd
        call anykey
        jr z,.dnk
        ld a,1
        ld (demo_key),a
        ld a,2
        ld (gameresult),a
        ret
.dnk:   ld hl,(demo_timer)
        inc hl
        ld (demo_timer),hl
        ld a,h
        cp 3                        ; ~30 s of demo
        jr c,.go
        ld a,2
        ld (gameresult),a
        ret
.nd:    ld a,(key_extra)
        and 11h                     ; P or BREAK
        call nz,pause_game
        ld a,(gameresult)
        cp 2
        ret z
.go:
.hook:                              ; test harness hook (input injection)
        call update
        call draw_frame
        ld a,(endtimer)
        or a
        jr z,.loop
        dec a
        ld (endtimer),a
        jr nz,.loop
        ret

get_controls:
        ld a,(autoplay)             ; (autoplay: test harness only)
        ld hl,demo
        or (hl)
        jr z,.p
        call ai_input
        jr .s
.p:     call read_keys
        bit B_UP,a
        jr z,.j
        or K_FIRE
.j:     ld b,a
        ld a,(joy_mode)
        or a
        ld a,b
        call nz,joy_dir
.s:     and K_LEFT|K_RIGHT|K_FIRE
        ld b,a
        ld a,(inp)
        ld (inp_prev),a
        cpl
        and b
        ld (inp_new),a
        ld a,b
        ld (inp),a
        ret

; ---------------------------------------------------------------------
; one game update (25 per second)
; ---------------------------------------------------------------------
update:
        ld hl,tickpar
        inc (hl)
        ld a,(endtimer)
        or a
        call z,move_seesaw
        ld b,2
        ld a,(pw_slow)
        or a
        jr z,.ss
        ld b,1
.ss:
.sub:   push bc
        call move_rows
        ld ix,clown0
        call clown_step
        ld ix,clown1
        call clown_step
        pop bc
        djnz .sub
        call clown_tick
        call bob_rows
        call monkey_update
        call pies_update
        call hoop_update
        call tokens_update
        call freeb_update
        call parts_update
        call popups_update
        call timers_update
        call check_end
        call anim_bg
        ld a,(hud_req)
        or a
        ret z
        ld a,(tickpar)
        and 1
        ret nz
        xor a
        ld (hud_req),a
        jp hud_draw

; rolling poles every 4th update, chasing lights every 4th (offset)
anim_bg:
        ld a,(tickpar)
        and 3
        jr z,.poles
        cp 2
        ret nz
        jp lights_draw
.poles: ld hl,poleph
        dec (hl)
        jp poles_draw

; ---------------------------------------------------------------------
; seesaw control
; ---------------------------------------------------------------------
move_seesaw:
        ld hl,flipcool
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        ld hl,flipanim
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        ld a,(inp_new)
        and K_FIRE
        jr z,.nf
        ld a,(flipcool)
        or a
        jr nz,.nf
        call find_seated
        jr nz,.nf
        ld a,(tilt)
        xor 1
        ld (tilt),a
        ld a,8
        ld (flipcool),a
        ld a,2
        ld (flipanim),a
        ld hl,SFX_FLIP
        ld a,1
        call sfx
.nf:    ld a,(inp)
        and K_LEFT|K_RIGHT
        jr nz,.mv
        ld hl,0
        ld (see_v),hl
        ret
.mv:    ld c,a
        ld hl,(see_v)
        ld a,h
        or l
        jr nz,.acc
        ld hl,300                   ; first press: half a cell at once
        ld (see_v),hl
        ld de,512
        jr .mvd
.acc:   ld de,100
        add hl,de
        ld a,(piestick)
        or a
        ld de,900                   ; max 3.5 units per update
        jr z,.mx
        ld de,380                   ; custard on the plank: sticky
.mx:    push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ex de,hl
.ok:    ld (see_v),hl
        ex de,hl
.mvd:   ld hl,(see_x)
        bit B_LEFT,c
        jr z,.right
        or a
        sbc hl,de
        jr nc,clamp_see_hl
        ld hl,0
        jr clamp_see_hl
.right: add hl,de
        jr clamp_see_hl

clamp_see:
        ld hl,(see_x)
; limits: hw+4 .. 155-hw
clamp_see_hl:
        ld a,(see_hw)
        add a,4
        cp h
        jr c,.l1
        ld h,a
        ld l,0
.l1:    ld a,(see_hw)
        ld b,a
        ld a,155
        sub b
        cp h
        jr nc,.l2
        ld h,a
        ld l,0
.l2:    ld (see_x),hl
        ret

; seated clown -> IX, Z if found
find_seated:
        ld ix,clown0
        ld a,(ix+CS_STATE)
        cp S_SEAT
        ret z
        ld ix,clown1
        ld a,(ix+CS_STATE)
        cp S_SEAT
        ret

; seesaw centre cell -> A ; half width in cells -> B
see_cells:
        ld a,(see_hw)
        rrca
        rrca
        and 3Fh
        ld b,a
        ld a,(see_x+1)
        rrca
        rrca
        and 3Fh
        ret

; ---------------------------------------------------------------------
; clowns
; ---------------------------------------------------------------------
spawn_tower:                        ; the free clown slot climbs a tower
        ld ix,clown0
        ld a,(ix+CS_STATE)
        cp S_SEAT
        jr nz,.u
        ld ix,clown1
.u:     ld (ix+CS_STATE),S_TOWER
        ld (ix+CS_T),45
        ld (ix+CS_FL),0
        ld (ix+CS_POPS),0
        ld (ix+CS_CD),0
        ld a,(respawn_side)
        xor 1
        ld (respawn_side),a
        ld (ix+CS_SIDE),a
        or a
        ld a,6
        jr z,.s
        ld a,154
.s:     ld (ix+CS_X+1),a
        ld (ix+CS_X),0
        ld (ix+CS_Y+1),TOWER_Y
        ld (ix+CS_Y),0
        ret

clown_tick:
        ld ix,clown0
        call .one
        ld ix,clown1
.one:   inc (ix+CS_ANIM)
        ld a,(ix+CS_STATE)
        cp S_SEAT
        jr z,.seat
        cp S_TOWER
        jr z,.tower
        cp S_SPLAT
        jr z,.splat
        ret
.seat:  ld a,(ix+CS_T)
        or a
        ret z
        dec (ix+CS_T)
        ret
.tower: dec (ix+CS_T)
        ret nz
        ld (ix+CS_STATE),S_FLY      ; jump!
        ld (ix+CS_FL),0
        ld (ix+CS_POPS),0
        ld a,(ph_tvr)
        ld b,a
        call rand_below
        ld c,a
        ld a,(ph_tvx)               ; 0.49 .. 0.80 units per substep, scaled
        add a,c
        ld l,a
        ld h,0
        ld a,(ix+CS_SIDE)
        or a
        call nz,neg_hl
        ld (ix+CS_VX),l
        ld (ix+CS_VX+1),h
        ld hl,(ph_tvy)
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ld a,(ix+CS_SIDE)
        or a
        ld a,9
        jr z,$+4
        ld a,151
        ld (ix+CS_X+1),a
        ld hl,SFX_JUMP
        ld a,1
        jp sfx
.splat: dec (ix+CS_T)
        ret nz
        ld (ix+CS_STATE),S_NONE
        ld a,(lives)
        or a
        jr nz,.again
        ld a,1
        ld (gameresult),a
        ld a,2
        ld (endtimer),a
        ret
.again: ld a,(endtimer)
        or a
        ret nz
        jp spawn_tower

neg_hl:
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

neg_vx:
        ld l,(ix+CS_VX)
        ld h,(ix+CS_VX+1)
        call neg_hl
        ld (ix+CS_VX),l
        ld (ix+CS_VX+1),h
        ret

; physics substep for clown IX
clown_step:
        ld a,(ix+CS_STATE)
        cp S_FLY
        ret nz
        ld a,(ix+CS_CD)
        or a
        jr z,.cd
        dec (ix+CS_CD)
.cd:    ld l,(ix+CS_VY)             ; gravity
        ld h,(ix+CS_VY+1)
        ld de,(ph_grav)
        bit 7,h
        jr nz,.g                    ; rising: full gravity
        ld a,(pw_umb)
        or a
        jr z,.g
        ld de,(ph_umb)
.g:     add hl,de
        bit 7,h                     ; cap the fall speed
        jr nz,.nc
        ld a,(pw_umb)
        or a
        ld de,(ph_vmax)
        jr z,.cap
        ld de,(ph_vumb)
.cap:   push hl
        or a
        sbc hl,de
        pop hl
        jr c,.nc
        ex de,hl
.nc:    ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ld a,(ix+CS_Y+1)
        add a,8
        ld (prev_cy),a
        ld e,(ix+CS_Y)              ; y += vy
        ld d,(ix+CS_Y+1)
        add hl,de
        ld (ix+CS_Y),l
        ld (ix+CS_Y+1),h
        ld l,(ix+CS_X)              ; x += vx
        ld h,(ix+CS_X+1)
        ld e,(ix+CS_VX)
        ld d,(ix+CS_VX+1)
        add hl,de
        ld (ix+CS_X),l
        ld (ix+CS_X+1),h
        ld a,h                      ; walls
        cp XMIN
        jr c,.wl
        cp 200
        jr nc,.wl                   ; wrapped below 0
        cp XMAX+1
        jr c,.ww
        ld (ix+CS_X+1),XMAX
        jr .wneg
.wl:    ld (ix+CS_X+1),XMIN
.wneg:  call neg_vx
        ld hl,SFX_WALL
        ld a,1
        call sfx
.ww:    ld a,(ix+CS_Y+1)            ; ceiling
        cp CEIL_Y
        jr nc,.nceil
        ld (ix+CS_Y+1),CEIL_Y
        ld (ix+CS_Y),0
        ld l,(ix+CS_VY)
        ld h,(ix+CS_VY+1)
        bit 7,h
        jr z,.nceil
        sra h                       ; vy = -vy/2
        rr l
        call neg_hl
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ld hl,SFX_BONK
        ld a,1
        call sfx
.nceil: call clown_balloons
        call clown_hoop
        call clown_monkey
        call clown_tokens
        call clown_freeb
        ld a,(ix+CS_VY+1)           ; landing / floor
        bit 7,a
        ret nz                      ; rising
        ld a,(ix+CS_Y+1)
        add a,16                    ; feet
        cp LAND_Y0
        ret c
        cp LAND_Y1
        jr nc,.floor
        bit 3,(ix+CS_FL)
        ret nz
        set 3,(ix+CS_FL)
        jp try_land
.floor: cp FLOOR_FEET
        ret c
        ld a,(actflags)             ; hit the floor
        and AF_BONUS
        jr nz,.boing
        ld a,(pw_net)
        or a
        jr z,.splat
        dec a
        ld (pw_net),a
        ld a,1
        ld (hud_req),a
.boing: ld hl,(ph_boing)
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ld (ix+CS_Y+1),LAUNCH_Y
        res 3,(ix+CS_FL)
        ld hl,SFX_LAUNCH
        ld a,2
        call sfx
        ld hl,txt_boing
        ld c,17
        jp popup_clown
.splat: ld (ix+CS_STATE),S_SPLAT
        ld (ix+CS_T),40
        ld (ix+CS_Y+1),FLOOR_FEET-16
        ld hl,lives
        dec (hl)
        ld hl,misses_act
        inc (hl)
        xor a
        ld (streak),a
        ld (combo),a
        ld a,1
        ld (hud_req),a
        ld hl,SFX_SPLAT
        ld a,3
        call sfx
        ld b,(ix+CS_X+1)
        ld c,FLOOR_FEET-4
        ld a,(pal+P_BODY)
        ld e,8
        call burst
        ld hl,txt_ouch
        ld c,17
        jp popup_clown

; popup HL at clown IX's column, row C
popup_clown:
        ld a,(ix+CS_X+1)
        jp popup_at

; feet are at plank height: land, bonk or miss
try_land:
        call see_cells              ; A = centre cell, B = half width
        ld c,a
        ld a,(ix+CS_X+1)
        rrca
        rrca
        and 3Fh
        sub c                       ; d = clown cell - centre
        ld e,a
        ld a,(tilt)                 ; tilt 0: the right end is raised
        or a
        ld a,e
        jr z,.r
        neg
.r:     bit 7,a
        jr nz,.low
        cp b
        jr z,.land
        ret nc                      ; past the end: miss
        jr .land
.low:   neg
        cp b
        jr z,.bonk
        ret nc
.bonk:  ld hl,(ph_bonk)             ; the occupied end: bounce off
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        res 3,(ix+CS_FL)
        ld (ix+CS_Y+1),124
        call neg_vx
        ld a,(ix+CS_VX)             ; too slow sideways: kick him off the
        add a,64                    ; occupied end, away from the pivot
        ld a,(ix+CS_VX+1)
        adc a,0
        jr nz,.bk                   ; |vx| >= 64
        call see_cells
        ld c,a
        ld a,(ix+CS_X+1)
        rrca
        rrca
        and 3Fh
        cp c
        ld hl,(ph_kick)
        call c,neg_hl
.bs:    ld (ix+CS_VX),l
        ld (ix+CS_VX+1),h
.bk:    ld hl,SFX_BONK
        ld a,2
        call sfx
        ld hl,txt_bonk
        ld c,15
        jp popup_clown
.land:  ld e,a                      ; E = cells toward the raised end
        push ix
        call find_seated
        push ix
        pop iy                      ; IY = the clown to launch
        pop ix
        ret nz                      ; nobody on the seesaw (rare)
        ld a,(tilt)                 ; the plank tips toward the lander
        xor 1
        ld (tilt),a
        ld a,2
        ld (flipanim),a
        ld (ix+CS_STATE),S_SEAT
        ld (ix+CS_T),6
        ld a,(ix+CS_POPS)           ; an empty flight breaks the combo
        or a
        jr nz,.kc
        ld (combo),a
.kc:    ld l,(ix+CS_VX)
        ld h,(ix+CS_VX+1)
        ld (iy+CS_STATE),S_FLY
        ld (iy+CS_FL),0
        ld (iy+CS_POPS),0
        ld (iy+CS_CD),0
        ld (iy+CS_ANIM),0
        ld a,(inp)                  ; steer
        bit B_LEFT,a
        jr z,.s1
        ld bc,(ph_steer)
        or a
        sbc hl,bc
.s1:    ld a,(inp)
        bit B_RIGHT,a
        jr z,.s2
        ld bc,(ph_steer)
        add hl,bc
.s2:    bit 7,h                     ; |vx| <= 288
        jr nz,.vneg
        ld bc,(ph_vxcap)
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,.vok
        ld h,b
        ld l,c
        jr .vok
.vneg:  ld bc,(ph_vxneg)
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,.vok
        ld h,b
        ld l,c
.vok:   ld (iy+CS_VX),l
        ld (iy+CS_VX+1),h
        push de
        call see_cells              ; launch from the raised end
        ld c,a
        ld a,(tilt)
        or a
        ld a,c
        jr nz,.lr                   ; left end low now: raised right
        sub b
        jr .lp
.lr:    add a,b
.lp:    add a,a
        add a,a
        add a,2
        ld (iy+CS_X+1),a
        ld (iy+CS_X),0
        ld (iy+CS_Y+1),LAUNCH_Y
        ld (iy+CS_Y),0
        pop de                      ; E = cells toward the raised end
        call see_cells              ; B = half width
        ld a,b
        srl a
        srl a
        ld c,a
        ld a,b
        sub c                       ; tip zone from half - half/4
        cp e
        jr z,.tip
        jr c,.tip
        ld a,e
        cp 2
        ld hl,(ph_mid)
        jr nc,.setv
        ld hl,(ph_weak)
        jr .setv
.tip:   ld hl,(ph_tip)
        set 2,(iy+CS_FL)
        push hl
        push iy
        push ix
        push iy
        pop ix
        ld hl,txt_perfect
        ld c,15
        call popup_clown
        pop ix
        ld de,0100h
        call add_pts
        pop iy
        pop hl
.setv:  ld (iy+CS_VY),l
        ld (iy+CS_VY+1),h
        ld hl,SFX_LAUNCH
        ld a,2
        call sfx
        xor a
        ld (ai_t),a
        ld hl,streak                ; streaks: a bonus every 5 catches
        inc (hl)
        ld a,(hl)
        ld b,a
.m5:    sub 5
        jr z,.five
        jr nc,.m5
        ret
.five:  ld a,b
        push af
        ld hl,txt_streak
        ld de,strbuf
        call strcpy
        pop af
        call num_append
        ld hl,strbuf
        ld c,9
        call popup_centre
        ld de,0500h
        call add_pts
        ld b,80
        ld c,80
        ld a,8
        ld e,12
        call confetti
        ld hl,SFX_POWER
        ld a,2
        jp sfx

; copy the 0-terminated string HL -> DE (DE left on the terminator)
strcpy:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr strcpy

; append A (0..99) in decimal at DE, terminate
num_append:
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld c,a
        ld a,b
        cp '0'
        jr z,.one
        ld (de),a
        inc de
.one:   ld a,c
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

; ---------------------------------------------------------------------
; clown vs balloons
; ---------------------------------------------------------------------
clown_balloons:
        ld a,(ix+CS_CD)
        or a
        ret nz
        ld a,(nrows)
        or a
        ret z
        ld c,0
.r:     call row_rec
        ld a,(iy+RW_LEFT)
        or a
        jr z,.nx
        push ix
        push iy
        pop ix
        call row_cy                 ; vertical overlap
        pop ix
        add a,a
        add a,a
        add a,a                     ; balloon top y
        ld d,a
        add a,8
        ld e,a
        ld a,(ix+CS_Y+1)
        cp e
        jr nc,.nx                   ; clown below the balloons
        add a,16
        cp d
        jr c,.nx
        jr z,.nx                    ; clown above
        ld a,(ix+CS_X+1)            ; columns col-1 .. col+1
        rrca
        rrca
        and 3Fh
        dec a
        ld (tmpx),a
        ld b,3
.cl:    push bc
        call try_col
        pop bc
        ld a,(ix+CS_CD)
        or a
        ret nz
        ld hl,tmpx
        inc (hl)
        djnz .cl
.nx:    inc c
        ld a,(nrows)
        cp c
        jr nz,.r
        ret

; is there a live balloon at column (tmpx) of row C (IY) within reach of
; clown IX?  Then hit it.
try_col:
        ld a,(tmpx)
        dec a
        cp 38
        ret nc
        ld a,(iy+RW_OFF+1)
        rrca
        rrca
        and 3Fh
        ld b,a
        ld a,(tmpx)
        sub b
        jr nc,$+4
        add a,40
        bit 0,a
        ret nz                      ; between two slots
        rrca
        ld b,a                      ; slot
        push bc
        call slot_ptr
        pop bc
        ld a,(hl)
        or a
        ret z
        ld a,(tmpx)                 ; |cx - (col*4 + 2)| < 4 ?
        add a,a
        add a,a
        add a,2
        sub (ix+CS_X+1)
        jr nc,$+4
        neg
        cp 4
        ret nc
        ; fall through

; clown IX hits slot B of row C (IY = row record)
hit_balloon:
        push bc
        call slot_ptr
        pop bc
        ld a,(hl)
        dec a
        cp T_STEEL
        jp nz,pop_balloon
        ld (hl),T_NORM+1            ; steel: dents to a normal balloon
        call row_redraw
        ld (ix+CS_CD),4
        ld l,(ix+CS_VY)             ; rising clowns bounce back down
        ld h,(ix+CS_VY+1)
        bit 7,h
        jr z,.dn
        sra h
        rr l
        call neg_hl
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
.dn:    ld hl,SFX_CLANG
        ld a,2
        call sfx
        ld hl,txt_clang
        call slot_popup
        ret

; popup HL above slot B of row C
slot_popup:
        push hl
        call slot_col
        add a,a
        add a,a
        add a,2
        ld e,a
        push ix
        call row_rec
        push iy
        pop ix
        call row_cy
        pop ix
        ld c,a
        ld a,e
        pop hl
        jp popup_at

; pop slot B of row C (alive).  IX = the clown (its CS_POPS counts)
pop_balloon:
        push bc
        call slot_ptr
        pop bc
        ld a,(hl)
        dec a
        push af                     ; type
        ld (hl),0
        call row_redraw
        ld hl,balloons_left
        dec (hl)
        inc (ix+CS_POPS)
        ld a,(combo)
        cp 99
        jr nc,$+6
        inc a
        ld (combo),a
        push iy
        call row_rec
        dec (iy+RW_LEFT)
        ld a,(iy+RW_LEFT)
        ld (rowleft),a
        ld a,(iy+RW_COL)
        ld (pb_col),a
        pop iy
        ; points: (nrows - row) * 10, x min(combo, 8), x2 with DOUBLE
        ld a,(nrows)
        sub c
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld a,(combo)
        cp 9
        jr c,$+4
        ld a,8
        ld (mult),a
        call mul_bcd
        call add_pts
        push bc
        call pts_text
        pop bc
        push bc
        ld hl,strbuf
        call slot_popup
        pop bc
        ; particles in the balloon's colour
        push bc
        call slot_col
        add a,a
        add a,a
        add a,2
        ld b,a
        push ix
        call row_rec
        push iy
        pop ix
        call row_cy
        pop ix
        add a,a
        add a,a
        add a,a
        add a,4
        ld c,a
        ld a,(pb_col)
        ld hl,pal+P_B0
        call add_hl_a
        ld a,(hl)
        ld e,5
        call burst
        pop bc
        ; the pop, higher with every combo step
        ld a,(combo)
        cp 9
        jr c,$+4
        ld a,8
        add a,a
        ld hl,POPDIV
        call add_hl_a
        ld a,(hl)
        ld (sfx_pop+2),a
        inc hl
        ld a,(hl)
        ld (sfx_pop+3),a
        ld hl,0FF02h
        ld (sfx_pop),hl
        ld hl,0
        ld (sfx_pop+4),hl
        ld hl,sfx_pop
        ld a,1
        call sfx
        pop af                      ; type
        cp T_GIFT
        jr nz,.ng
        push bc
        call slot_col
        add a,a
        add a,a
        add a,2
        ld b,a
        push ix
        push bc
        call row_rec
        push iy
        pop ix
        call row_cy
        pop bc
        pop ix
        add a,a
        add a,a
        add a,a
        ld c,a
        call spawn_token
        pop bc
        jr .rowchk
.ng:    cp T_BOMB
        jr nz,.rowchk
        push bc                     ; KABOOM: the neighbours go too
        call slot_col
        add a,a
        add a,a
        add a,2
        ld b,a
        ld c,40
        ld a,RED
        ld e,10
        call burst
        ld hl,SFX_BOOM
        ld a,3
        call sfx
        pop bc
        push bc
        ld a,b
        dec a
        jp p,$+5
        ld a,19
        ld b,a
        call chain_pop
        pop bc
        push bc
        ld a,b
        inc a
        cp 20
        jr c,$+3
        xor a
        ld b,a
        call chain_pop
        pop bc
        push bc                     ; and the rows above and below
        call slot_col
        ld d,a
        ld a,c
        or a
        jr z,.nab
        dec c
        push de
        ld a,d
        call chain_at_col
        pop de
        inc c
.nab:   ld a,(nrows)
        dec a
        cp c
        jr z,.nbe
        inc c
        ld a,d
        call chain_at_col
.nbe:   pop bc
.rowchk:
        push iy
        call row_rec
        ld a,(iy+RW_LEFT)
        or (iy+RW_CLR)
        jr nz,.prog0
        inc (iy+RW_CLR)
        pop iy
        push bc                     ; row cleared!
        ld hl,txt_rowclear
        ld c,7
        call popup_centre
        ld de,0500h
        call add_pts
        ld b,80
        ld c,40
        ld a,8
        ld e,14
        call confetti
        ld hl,SFX_POWER
        ld a,2
        call sfx
        pop bc
        jr .prog
.prog0: pop iy
.prog:  ld a,1
        ld (hud_req),a
        ret

; pop the balloon at column A in row C, if any
chain_at_col:
        push bc
        push iy
        ld d,a
        call row_rec
        ld a,(iy+RW_OFF+1)
        rrca
        rrca
        and 3Fh
        ld b,a
        ld a,d
        sub b
        jr nc,$+4
        add a,40
        srl a                       ; nearest slot (left of an odd gap)
        ld b,a
        call chain_pop
        pop iy
        pop bc
        ret

; pop slot B of row C if alive and not steel
chain_pop:
        push bc
        call slot_ptr
        pop bc
        ld a,(hl)
        or a
        ret z
        dec a
        cp T_STEEL
        ret z
        push iy
        call row_rec
        call pop_balloon
        pop iy
        ret

; ---------------------------------------------------------------------
; BCD scoring
; ---------------------------------------------------------------------
; DE (BCD, 4 digits) * (mult) -> DE
mul_bcd:
        push bc
        push hl
        ld a,(mult)
        or a
        jr nz,$+3
        inc a
        ld b,a
        ld hl,0
.l:     ld a,l
        add a,e
        daa
        ld l,a
        ld a,h
        adc a,d
        daa
        ld h,a
        djnz .l
        ex de,hl
        pop hl
        pop bc
        ret

; add DE (BCD) to the score (doubled with DOUBLE); DE = amount added.
; Extra life every 20,000.
add_pts:
        push bc
        push hl
        ld a,(pw_x2)
        or a
        jr z,.n
        ld a,2
        ld (mult),a
        call mul_bcd
.n:     ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        jr nc,.nov
        ld a,99h
        ld (score),a
        ld (score+1),a
        ld (score+2),a
.nov:   ld a,(nextlife)
        ld b,a
        ld a,(score)
        cp b
        jr c,.x
        ld a,b
        add a,2
        daa
        ld (nextlife),a
        ld a,(lives)
        cp 9
        jr nc,.x
        inc a
        ld (lives),a
        push de
        ld hl,txt_extralife
        ld c,5
        call popup_centre
        ld hl,SFX_1UP
        ld a,3
        call sfx
        pop de
.x:     ld a,1
        ld (hud_req),a
        pop hl
        pop bc
        ret

; BCD DE -> "+nnnn" in strbuf (no leading zeros)
pts_text:
        ld hl,strbuf
        ld (hl),'+'
        inc hl
        ld c,0
        ld a,d
        call .two
        ld a,e
        call .two
        ld a,c
        or a
        jr nz,.e
        ld (hl),'0'
        inc hl
.e:     ld (hl),0
        ret
.two:   push af
        rrca
        rrca
        rrca
        rrca
        call .dig
        pop af
.dig:   and 15
        jr nz,.p
        bit 0,c
        ret z
.p:     add a,'0'
        ld (hl),a
        inc hl
        ld c,1
        ret

; ---------------------------------------------------------------------
; timers and the end of an act
; ---------------------------------------------------------------------
timers_update:
        ld hl,piestick
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        ld a,(tickpar)
        and 1
        ret nz
        ld hl,pw_wide
        ld b,4
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        ld a,(hl)
        cp 50
        jr nc,.n2
        and 7
        jr nz,.n2
        ld a,1
        ld (hud_req),a
.n2:    ld a,(hl)
        or a
        jr nz,.n
        ld a,1
        ld (hud_req),a
.n:     inc hl
        djnz .l
        ld a,(pw_wide)
        or a
        ret nz
        ld a,(see_hw)
        cp HW_NORM
        ret z
        ld a,HW_NORM
        ld (see_hw),a
        ret

check_end:
        ld a,(endtimer)
        or a
        ret nz
        ld a,(actflags)
        and AF_BONUS
        ret nz
        ld a,(balloons_left)
        or a
        ret nz
        xor a
        ld (gameresult),a
        ld a,20
        ld (endtimer),a
        ret

; ---------------------------------------------------------------------
; drawing a frame: background updates, then the objects
; ---------------------------------------------------------------------
draw_frame:
        call rows_bg
        call draw_hoop
        call draw_monkey
        call draw_pies
        call draw_tokens
        call draw_freeb
        call draw_seesaw
        ld ix,clown0
        ld a,(pal+P_HAT)
        ld (tmpc),a
        ld a,(pal+P_BODY)
        ld (tmpy),a
        call draw_clown
        ld ix,clown1
        ld a,(pal+P_BODY)
        ld (tmpc),a
        ld a,(pal+P_HAT)
        ld (tmpy),a
        call draw_clown
        call parts_draw
        call popups_draw
        ld a,(demo)
        or a
        ret z
        ld a,(tickpar)              ; demo caption
        and 16
        ret z
        ld hl,txt_demo
        ld d,4
        ld e,10
        ld a,(pal+P_A1)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        jp put_text

; the plank: rows 19 (raised part) and 20 (low end), the pivot on row 20
draw_seesaw:
        call see_cells
        ld (tmpx),a                 ; centre
        ld a,b
        cp 5
        ld hl,PLANK9
        jr c,$+5
        ld hl,PLANK13
        ld a,(pal+P_PLANK)
        ld c,a
        ld a,(piestick)
        or a
        jr z,.col
        and 4
        ld c,WHITE
        jr z,.col
        ld c,YELLOW
.col:   ld a,c
        rlca
        rlca
        rlca
        rlca
        ld (tmpy),a                 ; plank attr
        ld a,(tmpx)                 ; leftmost cell
        sub b
        ld e,a
        ld a,b
        add a,a
        inc a
        ld b,a                      ; cells
        ld c,0                      ; index from the left
.l:     push bc
        push hl
        ld a,(flipanim)
        or a
        jr z,.tl
        ld a,c                      ; mid-flip: level at row 19, line 7
        ld d,19
        ld c,3Ch
        jr .put
.tl:    ld a,(tilt)
        or a
        ld a,c
        jr z,.ix
        ld a,b                      ; right end low: mirror
        sub c
        dec a
.ix:    add a,a
        call add_hl_a
        ld d,(hl)                   ; row
        inc hl
        ld c,(hl)                   ; glyph
.put:   ld a,(tmpy)
        ld b,a
        push de
        call put_at
        pop de
        pop hl
        pop bc
        inc e
        inc c
        djnz .l
        ; the pivot
        ld a,(tmpy)
        ld b,a
        ld a,(tmpx)
        ld e,a
        ld d,PIVOT_ROW
        ld c,43h
        call put_at
        ld a,(tmpx)
        dec a
        ld e,a
        ld c,4Eh
        call put_at
        ld a,(tmpx)
        inc a
        ld e,a
        ld c,4Dh
        jp put_at

; plank pieces (row, glyph) from the low (left) end: a line falling
; from row 20 line 0 to row 19 line 2
PLANK9:         db 20,70h, 19,3Ch, 19,3Ch, 19,7Ch, 19,38h, 19,78h, 19,34h, 19,74h, 19,74h
PLANK13:        db 20,70h, 19,3Ch, 19,3Ch, 19,7Ch, 19,7Ch, 19,38h, 19,38h, 19,78h, 19,78h, 19,34h, 19,34h, 19,74h, 19,74h

; clown IX: hat colour (tmpc), body colour (tmpy)
draw_clown:
        ld a,(ix+CS_STATE)
        or a
        ret z
        cp S_SEAT
        jr z,.seat
        cp S_TOWER
        jp z,.tower
        cp S_SPLAT
        jp z,.splat
        ; flying
        ld a,(ix+CS_X+1)
        rrca
        rrca
        and 3Fh
        ld e,a
        ld a,(ix+CS_Y+1)
        add a,4
        rrca
        rrca
        rrca
        and 1Fh
        ld d,a                      ; hat row
        ld a,(ix+CS_ANIM)
        rrca
        and 1
        add a,a
        add a,43h                   ; 43h or 45h: arms up / arms out
        ld (tmpx),a
        bit 2,(ix+CS_FL)            ; PERFECT: somersault
        jr z,.up
        ld a,(ix+CS_ANIM)
        and 2
        jr z,.up
        push de                     ; upside down: body above, hat below
        ld a,(tmpx)
        ld c,a
        ld a,(tmpy)
        call .body
        pop de
        inc d
        jp .hat
.up:    ld a,(pw_umb)               ; falling with the umbrella
        or a
        jr z,.nu
        ld a,(ix+CS_VY+1)
        bit 7,a
        jr nz,.nu
        push de
        dec d
        ld c,81h
        ld a,(tmpc)
        rlca
        rlca
        rlca
        rlca
        or 80h
        ld b,a
        call put_at
        pop de
.nu:    push de
        call .hat
        pop de
        inc d
        ld a,(tmpx)
        ld c,a
        ld a,(tmpy)
        jr .body
.seat:  call see_cells
        ld c,a
        ld a,(tilt)
        or a
        ld a,c
        jr nz,.sr
        sub b
        jr .sp
.sr:    add a,b
.sp:    ld e,a
        ld d,18
        push de
        call .hat
        pop de
        inc d
        ld c,G_BODY
        ld a,(ix+CS_T)              ; just landed: arms out
        or a
        jr z,$+4
        ld c,45h
        ld a,(tmpy)
        jr .body
.tower: ld a,(ix+CS_SIDE)
        or a
        ld e,1
        jr z,$+4
        ld e,38
        ld d,14
        push de
        call .hat
        pop de
        inc d
        ld a,(ix+CS_ANIM)
        and 8
        ld c,G_BODY
        jr z,$+4
        ld c,45h                    ; waving
        ld a,(tmpy)
        jr .body
.splat: ld a,(ix+CS_X+1)
        rrca
        rrca
        and 3Fh
        ld e,a
        ld d,19
        ld a,(ix+CS_ANIM)
        and 2
        ld a,YELLOW
        jr z,$+4
        ld a,WHITE
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld c,G_STAR
        push de
        call put_at
        pop de
        inc d
        ld c,43h
        ld a,(tmpy)
.body:  rlca
        rlca
        rlca
        rlca
        or 80h
        ld b,a
        jp put_at
.hat:   ld a,(tmpc)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld c,G_HAT
        jp put_at
