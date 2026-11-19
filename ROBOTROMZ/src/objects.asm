; =====================================================================
;  objects.asm - robots, humans and effects: spawning, AI, drawing
; =====================================================================

; A = type -> HL = its tinfo entry (DE preserved)
tinfo_ptr:
        dec a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,tinfo
        add hl,de
        pop de
        ret

; IX = object, A = type: set the type and cache its flags and info pointer
set_type:
        ld (ix+OT),a
        ld (ix+ODIRTY),1
        push af
        add a,a
        ld hl,upd_tab-2
        add a,l
        ld l,a
        jr nc,.u
        inc h
.u:     ld a,(hl)
        ld (ix+OUPD),a
        inc hl
        ld a,(hl)
        ld (ix+OUPD+1),a
        pop af
        call tinfo_ptr
        ld (ix+OTI),l
        ld (ix+OTI+1),h
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (ix+OFL),a
        ret

; A = object id (index+1) -> IY = object (DE, HL clobbered)
id_to_iy:
        dec a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,OBJ
        add hl,de
        push hl
        pop iy
        ret

id_to_ix:                       ; same into IX (IY preserved)
        push iy
        call id_to_iy
        push iy
        pop ix
        pop iy
        ret

; ---------------------------------------------------------------------
; spawning

; A = type: put a new object somewhere sensible, materialising
spawn_obj:
        push af
        cp T_MOM
        jr nc,.hum
        call rand_pos_robot
        jr .p
.hum:   call rand_pos_any
.p:     pop af
        call new_obj
        ret c
        jp set_materialise

; B = row, C = column outside the box round the player
rand_pos_robot:
        ld e,7
        ld d,5
        jr rand_pos
rand_pos_any:
        ld e,2
        ld d,2
rand_pos:
.r:     ld a,XMAX-XMIN+1
        call rand_n
        add a,XMIN
        ld c,a
        ld a,YMAX-YMIN+1
        call rand_n
        add a,YMIN
        ld b,a
        ld a,(px+1)
        sub c
        call abs_a
        cp e
        ret nc
        ld a,(py+1)
        sub b
        call abs_a
        cp d
        ret nc
        jr .r

set_materialise:                ; appear line by line, top to bottom
        ld a,(ix+OY)
        sub YMIN
        ld b,a
        add a,a
        add a,b
        add a,10
        ld b,a
        call rand8
        and 7
        add a,b
        ld (ix+OST),a
        ret

; A = type, B = row, C = column -> IX = new object (carry if none free)
new_obj:
        push bc
        ld ix,OBJ
        ld de,OBJSZ
        ld b,MAXOBJ
        ld c,a
.f:     ld a,(ix+OT)
        or a
        jr z,.got
        add ix,de
        djnz .f
        pop bc
        scf
        ret
.got:   ld a,MAXOBJ+1           ; slot index + 1: raise objtop to cover it
        sub b
        ld hl,objtop
        cp (hl)
        jr c,.top
        ld (hl),a
.top:   push ix
        pop hl
        ld b,OBJSZ
.z:     ld (hl),0
        inc hl
        djnz .z
        ld a,c
        pop bc
        call set_type
        ld (ix+OX),c
        ld (ix+OY),b
        ld (ix+OXL),80h
        ld (ix+OYL),80h
        call rand8
        ld (ix+OAN),a
        call rand8
        and 31
        inc a
        ld (ix+OTM),a
        call rand8
        and 127
        add a,60
        ld (ix+OAUX2),a
        ld a,(ix+OT)
        cp T_DROID
        jr z,.droid
        cp T_PYLON
        jr z,.pylon
        cp T_ORB
        jr z,.orb
        cp T_FACT
        jr z,.fact
        cp T_CRUSH
        jr z,.head
        cp T_MOM
        jr nc,.head
.done:  or a
        ret
.droid: ld a,(droid_delay)
        call rand_n
        inc a
        ld (ix+OTM),a
        jr .done
.pylon: ld a,(wave)             ; colour changes from wave to wave
        and 3
        ld hl,pyloncols
        add a,l
        ld l,a
        jr nc,.c6
        inc h
.c6:    ld a,(hl)
        ld (ix+OAUX),a
        jr .done
.orb:   ld (ix+OAUX),4          ; seekers to hatch
        jr .vel
.fact:  ld (ix+OAUX),3          ; tanks to build
.vel:   call rand_vel
        ld (ix+OVXL),l
        ld (ix+OVXH),h
        call rand_vel
        ld (ix+OVYL),l
        ld (ix+OVYH),h
        jr .done
.head:  call rand_dir
        ld (ix+ODX),d
        ld (ix+ODY),e
        jr .done

; HL = +-(18h..27h) cells/256 per tick
rand_vel:
        call rand8
        and 0Fh
        add a,18h
        ld l,a
        ld h,0
        call rand8
        rla
        ret nc
neg_hl:
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        ret

; D, E = random -1..1 each
rand_dir:
        ld a,3
        call rand_n
        dec a
        ld d,a
        ld a,3
        call rand_n
        dec a
        ld e,a
        ret

; A = type: hatch a child at IX's position (IX preserved)
spawn_child:
        push ix
        ld b,(ix+OY)
        ld c,(ix+OX)
        call new_obj
        jr c,.no
        ld (ix+OST),16
        ld hl,sfx_spawn
        ld a,2
        call play_sfx
.no:    pop ix
        ret

; ---------------------------------------------------------------------
; helpers
abs_a:  or a
        ret p
        neg
        ret

sgn:    or a
        ret z
        ld a,1
        ret p
        ld a,0FFh
        ret

player_bc:                      ; B = player column, C = row
        ld a,(px+1)
        ld b,a
        ld a,(py+1)
        ld c,a
        ret

toward_player:
        call player_bc
toward_bc:                      ; B = column, C = row -> D, E = step signs
        ld a,b
        sub (ix+OX)
        call sgn
        ld d,a
        ld a,c
        sub (ix+OY)
        call sgn
        ld e,a
        ret

; step IX by D, E cells inside the arena.  C bit 0/1 = x/y blocked.
obj_step:
        ld c,0
        ld a,(ix+OX)
        add a,d
        cp XMIN
        jr c,.bx
        cp XMAX+1
        jr nc,.bx
        ld (ix+OX),a
        jr .y
.bx:    set 0,c
.y:     ld a,(ix+OY)
        add a,e
        cp YMIN
        jr c,.by
        cp YMAX+1
        jr nc,.by
        ld (ix+OY),a
        jr .d
.by:    set 1,c
.d:     inc (ix+OAN)
        ld (ix+ODIRTY),1
        ret

; step along the heading, bouncing off the walls
step_heading:
        ld d,(ix+ODX)
        ld e,(ix+ODY)
        ld a,d
        or e
        jr nz,.go
        call rand_dir
        ld (ix+ODX),d
        ld (ix+ODY),e
.go:    call obj_step
        bit 0,c
        jr z,.b1
        ld a,(ix+ODX)
        neg
        ld (ix+ODX),a
.b1:    bit 1,c
        ret z
        ld a,(ix+ODY)
        neg
        ld (ix+ODY),a
        ret

; free movement by velocity, bouncing off the walls
move_free:                      ; (dirty only when it changes cell)
        ld l,(ix+OXL)
        ld h,(ix+OX)
        ld e,(ix+OVXL)
        ld d,(ix+OVXH)
        add hl,de
        ld a,h
        cp XMIN
        jr c,.bx
        cp XMAX+1
        jr nc,.bx
        ld (ix+OXL),l
        cp (ix+OX)
        jr z,.y
        ld (ix+OX),h
        ld (ix+ODIRTY),1
        jr .y
.bx:    ex de,hl
        call neg_hl
        ld (ix+OVXL),l
        ld (ix+OVXH),h
.y:     ld l,(ix+OYL)
        ld h,(ix+OY)
        ld e,(ix+OVYL)
        ld d,(ix+OVYH)
        add hl,de
        ld a,h
        cp YMIN
        jr c,.by
        cp YMAX+1
        jr nc,.by
        ld (ix+OYL),l
        cp (ix+OY)
        ret z
        ld (ix+OY),h
        ld (ix+ODIRTY),1
        ret
.by:    ex de,hl
        call neg_hl
        ld (ix+OVYL),l
        ld (ix+OVYH),h
        ret

; nearest human to IX -> B = column, C = row (carry if there are none)
target_human:
        ld iy,OBJ
        ld a,(objtop)
        ld b,a
        ld c,0FFh
        ld hl,0
.l:     ld a,(iy+OT)
        cp T_MOM
        jr c,.nx
        cp T_KID+1
        jr nc,.nx
        ld a,(iy+OX)
        sub (ix+OX)
        call abs_a
        ld e,a
        ld a,(iy+OY)
        sub (ix+OY)
        call abs_a
        add a,e
        cp c
        jr nc,.nx
        ld c,a
        ld h,(iy+OX)
        ld l,(iy+OY)
        ld a,(objtop)           ; remember its id: objtop - B + 1
        sub b
        inc a
        ld (tgtid),a
.nx:    ld de,OBJSZ
        add iy,de
        djnz .l
        ld a,c
        cp 0FFh
        scf
        ret z
        ld b,h
        ld c,l
        or a
        ret

; ---------------------------------------------------------------------
; droids get faster the longer a wave lasts
droid_speed:
        ld hl,(droid_tmr)
        dec hl
        ld (droid_tmr),hl
        ld a,h
        or l
        ret nz
        call reload_droid_tmr
        ld a,(ease+E_DMIN)
        ld b,a
        ld a,(droid_delay)
        sub 6
        jr c,.min
        cp b
        jr nc,.ok
.min:   ld a,b
.ok:    ld (droid_delay),a
        ret

reload_droid_tmr:
        ld a,(ease+E_DINT)
        ld l,a
        ld h,0
        add hl,hl
        ld (droid_tmr),hl
        ret

; ---------------------------------------------------------------------
; run every object's behaviour.  With ai_on = 0 only materialising and
; effect timers run.
update_objects:
        ld a,(objtop)
        or a
        ret z
        ld b,a
        ld ix,OBJ
.l:     push bc
        ld a,(ix+OT)
        or a
        jr z,.nx
        ld a,(ix+OST)
        or a
        jr z,.live
        dec (ix+OST)
        ld (ix+ODIRTY),1        ; the sparkle changes
        jr .nx
.live:  ld a,(ai_on)
        or a
        jr nz,.ai
        ld a,(ix+OT)
        cp T_SKULL
        jr c,.nx
.ai:    ld l,(ix+OUPD)
        ld h,(ix+OUPD+1)
        call jp_hl
.nx:    ld de,OBJSZ
        add ix,de
        pop bc
        djnz .l
        ret

upd_tab:
        dw upd_droid, upd_none, upd_crush, upd_brain
        dw upd_mutant, upd_orb, upd_seeker, upd_fact
        dw upd_tank, upd_human, upd_human, upd_human
        dw upd_timer, upd_timer, upd_timer, upd_none

upd_none:
        ret

upd_timer:                      ; skulls, pop-ups, explosions
        ld (ix+ODIRTY),1        ; explosions change as the timer runs
        dec (ix+OTM)
        ret nz
        ld (ix+OT),0
        ret

; Droid: marches straight at you, one cell per step
upd_droid:
        dec (ix+OTM)
        ret nz
        call rand8
        and 7
        ld b,a
        ld a,(droid_delay)
        sub b
        ld (ix+OTM),a
        call toward_player
        call rand8
        and 3
        jp nz,obj_step
        call rand8
        rra
        jr c,.nx
        ld d,0
        jp obj_step
.nx:    ld e,0
        jp obj_step

; Crusher: wanders, homes on humans now and then.  Can't be destroyed.
upd_crush:
        dec (ix+OTM)
        ret nz
        ld a,(ease+E_CRUSH)
        ld (ix+OTM),a
        call rand8
        and 3
        jp nz,step_heading
        call rand8
        rra
        jr c,.rnd
        call target_human
        jr nc,.t
        call player_bc
.t:     call toward_bc
        jr .set
.rnd:   call rand_dir
.set:   ld (ix+ODX),d
        ld (ix+ODY),e
        jp step_heading

; Mindbot: hunts humans (turns them into mutants), fires homing missiles
upd_brain:
        dec (ix+OAUX2)
        jr nz,.mv
        call fire_reload
        add a,90
        ld (ix+OAUX2),a
        call count_missiles     ; at most 5 in the air
        cp 5
        jr nc,.mv
        ld a,2
        call fire_at_player
.mv:    dec (ix+OTM)
        ret nz
        ld a,(ease+E_BRAIN)
        ld (ix+OTM),a
        ld a,(humcnt)           ; no humans left: straight for the player
        or a
        jr z,.pl
        ld a,(ix+OAUX)          ; still after the same human?
        or a
        jr z,.scan
        call id_to_iy
        ld a,(iy+OT)
        cp T_MOM
        jr c,.scan
        cp T_KID+1
        jr nc,.scan
        ld b,(iy+OX)
        ld c,(iy+OY)
        jr .t
.scan:  call target_human
        jr c,.pl
        ld a,(tgtid)
        ld (ix+OAUX),a
        jr .t
.pl:    ld (ix+OAUX),0
        call player_bc
.t:     call toward_bc
        jp obj_step

; A = homing missiles in the air
count_missiles:
        push bc
        push de
        push hl
        ld hl,EBUL+BT
        ld de,EBSZ
        ld bc,MAXEB*256
.c:     ld a,(hl)
        cp 2
        jr nz,.n
        inc c
.n:     add hl,de
        djnz .c
        ld a,c
        pop hl
        pop de
        pop bc
        ret

; Mutant: fast and twitchy, straight for you
upd_mutant:
        dec (ix+OTM)
        ret nz
        ld a,(ease+E_MUT)
        ld (ix+OTM),a
        call toward_player
        call rand8
        and 3
        jp nz,obj_step
        call rand_dir
        jp obj_step

; Orb / factory: bounce around and hatch seekers / build tanks
upd_orb:
        ld a,T_SEEKER
        jr hatcher
upd_fact:
        ld a,T_TANK
hatcher:
        push af
        call move_free
        pop bc
        dec (ix+OAUX2)
        ret nz
        call rand8
        and 63
        add a,140
        ld (ix+OAUX2),a
        ld a,(ix+OAUX)
        or a
        ret z
        dec (ix+OAUX)
        ld a,b
        jp spawn_child

; Seeker: drifts after you and fires sparks
upd_seeker:
        dec (ix+OTM)
        jr nz,.mv
        ld (ix+OTM),4
        call toward_player
        push de
        ld l,(ix+OVXL)
        ld h,(ix+OVXH)
        ld a,d
        call steer
        ld (ix+OVXL),l
        ld (ix+OVXH),h
        pop de
        ld l,(ix+OVYL)
        ld h,(ix+OVYH)
        ld a,e
        call steer
        ld (ix+OVYL),l
        ld (ix+OVYH),h
.mv:    call move_free
        dec (ix+OAUX2)
        ret nz
        call fire_reload
        add a,60
        ld (ix+OAUX2),a
        ld a,1
        jp fire_at_player

; HL = velocity, A = sign: nudge by 6/256 toward it, clamp to +-30h
steer:
        or a
        ret z
        ld de,6
        jp p,.p
        ld de,-6
.p:     add hl,de
        bit 7,h
        jr nz,.neg
        ld a,h
        or a
        jr nz,.cp
        ld a,l
        cp 31h
        ret c
.cp:    ld hl,30h
        ret
.neg:   ld a,h
        inc a
        jr nz,.cn
        ld a,l
        cp 0D0h
        ret nc
.cn:    ld hl,-30h
        ret

; Tank: lumbers toward you, lobs shells that bounce off the walls
upd_tank:
        dec (ix+OAUX2)
        jr nz,.mv
        call fire_reload
        add a,100
        ld (ix+OAUX2),a
        ld a,3
        call fire_at_player
.mv:    dec (ix+OTM)
        ret nz
        ld a,(ease+E_TANK)
        ld (ix+OTM),a
        call toward_player
        jp obj_step

; A = random 0..63 + the easing stage's extra fire delay
fire_reload:
        call rand8
        and 63
        ld b,a
        ld a,(ease+E_FIRE)
        add a,b
        ret

; Humans wander about
upd_human:
        dec (ix+OTM)
        ret nz
        call rand8
        and 7
        add a,14
        ld (ix+OTM),a
        call rand8
        and 7
        jr nz,.keep
        call rand_dir
        ld (ix+ODX),d
        ld (ix+ODY),e
.keep:  jp step_heading

; ---------------------------------------------------------------------
; IX = robot hit by a shot: score it and turn it into an explosion
kill_obj:
        ld a,(ix+OT)
        call tinfo_ptr
        push hl
        inc hl
        inc hl
        ld a,(hl)
        or 80h                  ; the explosion glyphs are in bank 2
        ld b,a
        ld a,(ix+OT)
        cp T_PYLON
        jr nz,.c
        ld b,(ix+OAUX)
.c:     ld (ix+OAUX),b
        pop hl
        ld de,4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        ld b,(hl)               ; debris count
        dec hl
        ld a,b
        ld (bcnt),a
        ld a,(hl)
        call add_score
        ld a,(bcnt)
        ld e,a
        ld b,(ix+OY)            ; debris in the robot's colour
        ld c,(ix+OX)
        ld a,(ix+OAUX)
        ld d,0
        call burst
        ld a,T_EXPL
        call set_type
        ld (ix+OTM),12
        ld (ix+OST),0
        ld hl,sfx_boom
        ld a,3
        jp play_sfx

; ---------------------------------------------------------------------
; draw every object on the object layer (robots first, then humans so robots
; that catch them can squash or convert them) and count robots still to kill.
; Objects that haven't moved or changed cost almost nothing (see obj_draw).
place_objects:
        xor a
        ld (alive),a
        ld (humcnt),a
        ld a,(objtop)
        or a
        ret z
        ld b,a                  ; B = slots left, C = id
        ld ix,OBJ
        ld c,1
        ; fast path: a robot that hasn't changed and is still showing
.l:     ld a,(ix+OT)
        or a
        jr z,.gone
        cp T_POP
        jr z,.pop
        ld a,(ix+OFL)
        bit 2,a                 ; F_COUNT
        jr z,.nc
        ld hl,alive
        inc (hl)
.nc:    and F_HUMAN|F_ANIM
        jr nz,.spec
        or (ix+ODIRTY)          ; (A = 0 here; not drawn => dirty)
        jr nz,.full
        ld l,(ix+OLOFS)         ; uncovered since?
        ld a,(ix+OLOFS+1)
        add a,high REDRAW
        ld h,a
        ld a,(hl)
        or a
        jr nz,.full
.nx:    ld de,OBJSZ
        add ix,de
        inc c
        djnz .l
        jp .humans
.spec:  and F_HUMAN             ; humans: later
        jr nz,.hum
        ld a,(framecnt)         ; F_ANIM: colours change every 4th tick
        and 3
        jr z,.full
        ld a,(ix+ODIRTY)
        or a
        jr nz,.full
        ld l,(ix+OLOFS)
        ld a,(ix+OLOFS+1)
        add a,high REDRAW
        ld h,a
        ld a,(hl)
        or a
        jr nz,.full
        jr .nx
.full:  push bc
        ld a,c
        ld (curid),a
        ld (ix+ODIRTY),0
        ld l,(ix+OTI)
        ld h,(ix+OTI+1)
        call obj_look
        call obj_ofs
        call obj_draw
        pop bc
        jr .nx
.gone:  ld a,(ix+ODRAWN)        ; freed since last tick and still drawn?
        or a
        jr z,.nx
        push bc
        ld a,c
        ld (curid),a
        call obj_erase
        pop bc
        jr .nx
.pop:   push bc                 ; a rescued human: now a transient pop-up
        ld a,c
        ld (curid),a
        call obj_erase
        call place_pop
        pop bc
        jr .nx
.hum:   ld hl,humcnt
        ld a,(hl)
        cp 16
        jp nc,.nx
        inc (hl)
        add a,a
        add a,a
        ld hl,humlist
        add a,l
        ld l,a
        jr nc,.h1
        inc h
.h1:    push ix
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        jp .nx

.humans:
        ; humans
        ld a,(humcnt)
        or a
        ret z
        ld b,a
        ld hl,humlist
.h:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        inc hl
        push hl
        ld (curid),a
        push de
        pop ix
        ld l,(ix+OTI)
        ld h,(ix+OTI+1)
        call obj_look
        call obj_ofs
        ld a,(ix+OST)
        or a
        jr nz,.draw
        push de
        push hl
        call occ_at             ; who is showing in the cell we're going to?
        or a
        jr z,.free
        ld b,a
        ld a,(curid)
        cp b
        jr z,.free
        ld a,b
        call id_to_iy
        ld a,(iy+OST)
        or a
        jr nz,.free
        ld a,(iy+OFL)
        and F_SOLID
        jr z,.free
        ld a,(iy+OT)
        cp T_CRUSH
        jr z,.squash
        cp T_BRAIN
        jr z,.mutate
        pop hl                  ; another robot is there: stay hidden
        pop de
        call obj_erase
        jr .hn
.free:  pop hl
        pop de
.draw:  call obj_draw
        jr .hn
.squash:
        pop hl
        pop de
        ld a,T_SKULL
        call set_type
        ld (ix+OTM),100
        ld hl,sfx_human
        jr .lose
.mutate:
        pop hl
        pop de
        ld a,T_MUTANT
        call set_type
        ld a,(ease+E_MUT)
        ld (ix+OTM),a
        ld hl,sfx_mutate
.lose:  ld a,4
        call play_sfx
        ld hl,lost
        inc (hl)
        ld b,(ix+OY)            ; a puff of red
        ld c,(ix+OX)
        ld a,0A1h
        ld de,0106h
        call burst
.hn:    pop hl
        pop bc
        dec b
        jp nz,.h
        ret

; HL = cell offset of IX (DE preserved)
obj_ofs:
        ld b,(ix+OY)
        ld c,(ix+OX)
        jp calc_ofs

; IX, HL = tinfo entry -> D = char, E = attribute
obj_look:
        ld a,(ix+OST)
        or a
        jr nz,.mat
        ld a,(ix+OT)
        cp T_EXPL
        jr z,.expl
        ld d,(hl)
        bit 0,(ix+OAN)
        jr z,.g
        inc hl
        ld d,(hl)
        dec hl
.g:     inc hl
        inc hl
        ld e,(hl)
        cp T_PYLON
        jr z,.aux
        cp T_ORB
        jr z,.cyc
        cp T_FACT
        jr z,.cyc
        cp T_MUTANT
        ret nz
        ld a,(framecnt)         ; mutants flicker cyan / white
        and 4
        ret z
        ld a,e
        xor 20h
        ld e,a
        ret
.aux:   ld e,(ix+OAUX)
        ret
.cyc:   ld a,(framecnt)
        rrca
        rrca
        and 7
        ld hl,cyctab
        add a,l
        ld l,a
        jr nc,.c1
        inc h
.c1:    ld e,(hl)
        ret
.expl:  ld e,(ix+OAUX)
        ld a,(ix+OTM)
        ld d,0B3h
        cp 9
        ret nc
        ld d,0EEh
        cp 5
        ret nc
        ld d,0EFh
        ret
.mat:   inc hl                  ; sparkle in the object's colour
        inc hl
        ld e,(hl)
        set 7,e
        ld a,(ix+OST)
        rrca
        and 3
        ld hl,matglyph
        add a,l
        ld l,a
        jr nc,.m1
        inc h
.m1:    ld d,(hl)
        ret

; rescue score pop-up: "1000".."5000" for a second
place_pop:
        ld a,(ix+OX)
        cp XMAX-3
        jr c,.ok
        ld a,XMAX-3
        ld (ix+OX),a
.ok:    call obj_ofs
        ld a,(ix+OAUX)
        add a,21h
        ld d,a
        ld e,61h
        ld b,4
.l:     push bc
        push hl
        call put_cell
        pop hl
        pop bc
        inc hl
        ld d,20h
        djnz .l
        ret
