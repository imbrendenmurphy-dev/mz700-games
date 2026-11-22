; =====================================================================
;  front.asm - the attract sequence, high scores, pause
;
;  Pages: the title (the logo over a live road, the computer driving),
;  the route map, how to play, the high scores, then a demo race with
;  the full HUD.  The title tune plays all through.  SPACE (or a
;  joystick button) starts a race from any of them.
; =====================================================================

PG_TITLE equ 0
PG_ROUTE equ 1
PG_HELP  equ 2
PG_HIGH  equ 3
PG_DEMO  equ 4
NPAGES   equ 5

; -> A = 0: start a race, 1: run the demo
front_end:
        xor a
        ld (demo),a
        ld (titlemode),a
        call sfx_stop
        ld a,(trk_on)           ; the tune, unless it is already on
        or a
        jr nz,.page
        ld hl,TRK_TITLE
        call play_tune
.page:  ld a,(page)
        cp PG_DEMO
        jr nz,.n1
        ld a,PG_HIGH            ; (the page after the demo)
        ld (page),a
        ld a,1
        ret
.n1:    cp PG_TITLE
        jr nz,.text
        ; the title runs as a race with no HUD
        ld a,2
        ret
.text:  call text_page
        or a
        ret z                   ; SPACE: a race
        call next_page
        jr .page

next_page:
        ld a,(page)
        inc a
        cp NPAGES
        jr c,.p
        xor a
.p:     ld (page),a
        ret

; a page of text: draw it, wait (about 8 s) -> A = 0 SPACE, 1 timed out
text_page:
        call cls
        call draw_logo
        ld a,(page)
        cp PG_ROUTE
        call z,draw_route
        ld a,(page)
        cp PG_HELP
        call z,draw_help
        ld a,(page)
        cp PG_HIGH
        call z,draw_scores
        ld hl,250
        ld (ptick),hl
.w:     ld a,2
        call wait_fields
        call read_keys
        call front_keys
        call logo_glint
        ld hl,framecnt
        inc (hl)
        ld a,(sedge)
        and KS_SPACE
        jr nz,.go
        ld hl,(ptick)
        dec hl
        ld (ptick),hl
        ld a,h
        or l
        jr nz,.w
        inc a
        ret
.go:    xor a
        ret

; M sound, J joystick (on any page)
front_keys:
        ld a,(sedge)
        and KS_M
        call nz,cycle_sound
        ld a,(sedge)
        and KS_J
        ret z
        ld a,(joyon)
        xor 1
        ld (joyon),a
        xor a
        ld (joycal),a
        ld hl,SFX_SELECT
        ld a,3
        jp sfx

; ---------------------------------------------------------------------
; the logo, rows 1-5 (LOGO: 5 rows x LOGOW cells of glyph, attribute)
draw_logo:
        ld hl,LOGO
        ld de,VRAM+40+(40-LOGOW)/2
        ld c,5
.r:     ld b,LOGOW
        push de
.c:     ld a,(hl)
        inc hl
        ld (de),a
        set 3,d
        ld a,(hl)
        inc hl
        ld (de),a
        res 3,d
        inc de
        djnz .c
        pop de
        ld a,e
        add a,40
        ld e,a
        jr nc,.n
        inc d
.n:     dec c
        jr nz,.r
        ret

; a white glint sweeping over the letters now and then
logo_glint:
        ld a,(framecnt)
        and 127
        cp LOGOW+8
        ret nc
        ; column A-8 back to its colours, column A white
        push af
        sub 8
        call c,.none
        call nc,.restore
        pop af
        cp LOGOW
        ret nc
        ld e,a
        ld d,0
        ld hl,CRAM+40+(40-LOGOW)/2
        add hl,de
        ld b,5
        ld de,40
.w:     ld a,(hl)
        and 0Fh
        or WHITE*16
        ld (hl),a
        add hl,de
        djnz .w
        ret
.none:  ret
.restore:
        ld e,a                  ; the logo's own colours for column A
        ld d,0
        ld hl,CRAM+40+(40-LOGOW)/2
        add hl,de
        push hl
        ld hl,LOGO+1
        add hl,de
        add hl,de
        pop de
        ld b,5
.rr:    ld a,(hl)
        ld (de),a
        push bc
        ld bc,LOGOW*2
        add hl,bc
        ex de,hl
        ld bc,40
        add hl,bc
        ex de,hl
        pop bc
        djnz .rr
        or a
        ret

; ---------------------------------------------------------------------
; the title: a race run by the computer under the logo
title_setup:
        call cls
        call road_chars
        call car_reset
        call draw_logo
        ld hl,txt_press
        ld b,7
        ld a,WHITE*16+BLACK
        call print_centre
        ld hl,txt_credit
        ld b,0
        ld a,CYAN*16+BLACK
        call print_centre
        ld a,1
        ld (titlemode),a
        ld (demo),a
        ld hl,170               ; about ten seconds
        ld (ptick),hl
        ret

; each frame of the title
title_frame:
        call logo_glint
        call front_keys
        ld a,(framecnt)         ; PRESS SPACE flashes
        and 8
        ld a,WHITE*16+BLACK
        jr z,.f
        ld a,RED*16+BLACK
.f:     ld hl,CRAM+7*40+10
        ld b,20
.c:     ld (hl),a
        inc hl
        djnz .c
        ld a,(sedge)
        and KS_SPACE
        jr z,.t
        xor a                   ; a race
        ld (titlego),a
        jr .end
.t:     ld hl,(ptick)
        dec hl
        ld (ptick),hl
        ld a,h
        or l
        ret nz
        ld a,1
        ld (titlego),a
        call next_page
.end:   ld a,1
        ld (gameend),a
        ret

txt_press:  db "PRESS SPACE TO RACE",0
txt_credit: db "VIBED BY BPM 2026",0

; ---------------------------------------------------------------------
; the route map: the pyramid of courses
draw_route:
        ld hl,txt_route
        ld b,7
        ld a,YELLOW*16+BLACK
        call print_centre
        ld hl,ROUTELINES        ; the branches
.ln:    ld a,(hl)
        cp 0FFh
        jr z,.names
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        push af
        call cell_ofs
        ld de,VRAM
        add hl,de
        ex de,hl
        pop af
        ld c,BLUE*16+BLACK
        call put_char
        pop hl
        jr .ln
.names: ld hl,ROUTEMAP
        xor a
.n:     ld (rt_n),a
        ld a,(hl)
        cp 0FFh
        jr z,.done
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(rt_n)             ; courses on your last route: yellow
        ld e,WHITE*16+BLACK
        call route_seen
        jr z,.col
        ld e,BLACK*16+YELLOW
.col:   ld a,e
        call print_at
        ld a,(rt_n)
        inc a
        jr .n
.done:  ld hl,txt_goal5
        ld b,23
        ld a,GREEN*16+BLACK
        call print_centre
        ld hl,txt_route2
        ld b,24
        ld a,CYAN*16+BLACK
        jp print_centre

; A = course: NZ if it was on the last route driven
route_seen:
        push hl
        ld hl,(routebits)
        or a
        jr z,.t
.s:     srl h
        rr l
        dec a
        jr nz,.s
.t:     bit 0,l
        pop hl
        ret

txt_route:  db "CHOOSE YOUR ROUTE",0
txt_route2: db "AT A FORK: LEFT EASIER, RIGHT HARDER",0
txt_goal5:  db "FIVE GOALS AWAIT AT THE END",0

; ---------------------------------------------------------------------
draw_help:
        ld hl,helptext
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        call print_at
        jr .l

helptext:
        db 7,13,YELLOW*16+BLACK,"HOW TO DRIVE",0
        db 9,2,WHITE*16+BLACK,"UP / W         ACCELERATE",0
        db 10,2,WHITE*16+BLACK,"DOWN / S       BRAKE",0
        db 11,2,WHITE*16+BLACK,"LEFT RIGHT A D STEER",0
        db 12,2,WHITE*16+BLACK,"SPACE / Z      BOOST",0
        db 13,2,WHITE*16+BLACK,"RETURN PAUSE   M SOUND  J STICK",0
        db 15,2,CYAN*16+BLACK,"REACH EACH CHECKPOINT IN TIME.",0
        db 16,2,CYAN*16+BLACK,"SKIM PAST CARS FOR CLOSE BONUSES -",0
        db 17,2,CYAN*16+BLACK,"CHAIN THEM FOR MORE. CLOSE CALLS",0
        db 18,2,CYAN*16+BLACK,"AND SLIPSTREAMS FILL YOUR BOOST.",0
        db 19,2,CYAN*16+BLACK,"MIND THE VERGES: GRASS SLOWS YOU,",0
        db 20,2,CYAN*16+BLACK,"AND TREES AND ROCKS STOP YOU DEAD.",0
        db 22,2,GREEN*16+BLACK,"AT A FORK, THE ROAD YOU TAKE",0
        db 23,2,GREEN*16+BLACK,"PICKS THE NEXT STAGE.",0
        db 0FFh

; ---------------------------------------------------------------------
; high scores: 8 x (score 3 BCD, initials 3, stage, goal)
init_hiscores:
        ld hl,hidefault
        ld de,HISC
        ld bc,64
        ldir
        ret

hidefault:
        db 00h,50h,02h,"BPM",5,1
        db 00h,00h,02h,"RED",5,0
        db 00h,50h,01h,"MZ7",4,0
        db 00h,00h,01h,"ACE",4,0
        db 00h,50h,00h,"VRM",3,0
        db 00h,30h,00h,"TOP",2,0
        db 00h,20h,00h,"GTI",2,0
        db 00h,10h,00h,"CPU",1,0

draw_scores:
        ld hl,txt_high_h
        ld b,7
        ld a,YELLOW*16+BLACK
        call print_centre
        ld hl,txt_high_c
        ld b,9
        ld a,CYAN*16+BLACK
        call print_centre
        ld ix,HISC
        ld b,11
        ld c,0
.r:     push bc
        ld a,b
        ld (hs_row),a
        ld a,c
        ld (hs_rank),a
        ld a,(hinew)
        cp c
        ld a,WHITE*16+BLACK
        jr nz,.cc
        ld a,YELLOW*16+RED
.cc:    ld (hs_col),a
        ld a,(hs_row)
        ld b,a
        ld c,7
        call cell_ofs
        ld de,VRAM
        add hl,de
        ex de,hl
        ld a,(hs_col)
        ld c,a
        ld a,(hs_rank)
        inc a
        call put_digit
        inc de
        inc de
        inc de
        ld a,(ix+2)
        call put_bcd
        ld a,(ix+1)
        call put_bcd
        ld a,(ix+0)
        call put_bcd
        xor a
        call put_digit
        inc de
        inc de
        inc de
        ld b,3
        push ix
        pop hl
        inc hl
        inc hl
        inc hl
.nm:    ld a,(hl)
        inc hl
        call asc2dc
        call put_char
        djnz .nm
        inc de
        inc de
        inc de
        inc de
        ld a,(ix+6)
        call put_digit
        ld a,(ix+7)             ; reached a goal: a flag
        or a
        jr z,.ng
        inc de
        inc de
        ld a,(hs_col)
        ld c,a
        ld a,'*'
        call asc2dc
        call put_char
.ng:    ld de,8
        add ix,de
        pop bc
        inc b
        inc b
        inc c
        ld a,c
        cp 7
        jp c,.r
        ld hl,txt_high_f
        ld b,25-1
        ld a,GREEN*16+BLACK
        jp print_centre

txt_high_h: db "FASTEST DRIVERS",0
txt_high_c: db "    SCORE   NAME  STAGE",0
txt_high_f: db "* REACHED A GOAL",0

; after a race: into the table?
check_hiscore:
        ld a,0FFh
        ld (hinew),a
        ld ix,HISC
        ld c,0
.f:     ld a,(score+2)          ; score > entry?
        cp (ix+2)
        jr c,.n
        jr nz,.ins
        ld a,(score+1)
        cp (ix+1)
        jr c,.n
        jr nz,.ins
        ld a,(score)
        cp (ix+0)
        jr c,.n
        jr z,.n
        jr .ins
.n:     ld de,8
        add ix,de
        inc c
        ld a,c
        cp 8
        jr c,.f
        ret
.ins:   ld a,c
        ld (hinew),a
        ld a,7                  ; move the lower entries down
        sub c
        jr z,.put
        ld b,a
        ld hl,HISC+55
        ld de,HISC+63
.mv:    push bc
        ld bc,8
        lddr
        pop bc
        djnz .mv
.put:   ld hl,score
        push ix
        pop de
        ld bc,3
        ldir
        ld (ix+3),'.'
        ld (ix+4),'.'
        ld (ix+5),'.'
        ld a,(stage)
        ld (ix+6),a
        ld a,(goalhit)
        ld (ix+7),a
        jp enter_name

; IX = entry: type the initials
enter_name:
        ld (nameptr),ix
        call cls
        call draw_logo
        ld hl,txt_ename1
        ld b,9
        ld a,YELLOW*16+BLACK
        call print_centre
        ld hl,txt_ename2
        ld b,12
        ld a,WHITE*16+BLACK
        call print_centre
        ld hl,txt_ename3
        ld b,20
        ld a,CYAN*16+BLACK
        call print_centre
        ld hl,TRK_HIGH
        call play_tune
        xor a
        ld (nidx),a
.l:     ld a,2
        call wait_fields
        call read_keys
        call logo_glint
        ld hl,framecnt
        inc (hl)
        ; the three letters, the current one blinking
        ld b,0
.s:     push bc
        ld hl,(nameptr)
        ld a,b
        add a,3
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        call asc2dc
        ld e,a
        ld a,(nidx)
        cp b
        ld c,WHITE*16+BLACK
        jr nz,.sc
        ld a,(framecnt)
        and 4
        ld c,YELLOW*16+RED
        jr z,.sc
        ld c,RED*16+BLACK
.sc:    ld a,b
        add a,a
        add a,17
        ld l,a
        ld h,0
        push de
        ld de,VRAM+15*40
        add hl,de
        ex de,hl
        pop hl
        ld a,l
        call put_char
        pop bc
        inc b
        ld a,b
        cp 3
        jr c,.s
        call get_letter
        or a
        jr z,.k
        cp 8
        jr z,.del
        ld e,a
        ld a,(nidx)
        cp 3
        jr nc,.l
        push af
        add a,3
        ld c,a
        ld b,0
        ld hl,(nameptr)
        add hl,bc
        ld (hl),e
        pop af
        inc a
        ld (nidx),a
        ld hl,SFX_SELECT
        ld a,3
        call sfx
        jp .l
.del:   ld a,(nidx)
        or a
        jp z,.l
        dec a
        ld (nidx),a
        add a,3
        ld c,a
        ld b,0
        ld hl,(nameptr)
        add hl,bc
        ld (hl),'.'
        jp .l
.k:     ld a,(sedge)
        and KS_CR
        jp z,.l
        ld a,(nidx)
        or a
        jp z,.l
        ld a,PG_HIGH
        ld (page),a
        ret
txt_ename1: db "A NEW FAST TIME!",0
txt_ename2: db "TYPE YOUR INITIALS",0
txt_ename3: db "RETURN WHEN DONE",0

; ---------------------------------------------------------------------
; RETURN in a race: pause (Q quits, RETURN goes on)
pause_check:
        ld a,(demo)
        or a
        ret nz
        ld a,(sedge)
        and KS_CR
        ret z
        call out_off
        ld a,1
        ld (paused),a
        ld hl,txt_paused
        ld a,WHITE*16+BLUE
        ld (msgcol),a
        xor a
        call hud_message
        ld a,255
        ld (msgtime),a
        call msg_update
.w:     ld a,2
        call wait_fields
        call read_keys
        call front_keys
        ld a,(sedge)
        and KS_Q
        jr nz,.q
        ld a,(sedge)
        and KS_CR
        jr z,.w
        xor a
        ld (paused),a
        ld a,1
        ld (msgtime),a
        ret
.q:     xor a
        ld (paused),a
        ld a,1
        ld (gameend),a
        ld (quitflag),a
        ret

txt_paused: db "PAUSED  Q QUITS",0

; ---------------------------------------------------------------------
; the end of the route: a page for the goal you reached
goal_page:
        call cls
        call draw_logo
        ld hl,txt_gp1
        ld b,9
        ld a,YELLOW*16+BLACK
        call print_centre
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
        ld b,12
        ld a,WHITE*16+RED
        call print_centre
        ld a,(node)
        sub 10
        add a,a
        ld e,a
        ld d,0
        ld hl,goaltxt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,15
        ld a,CYAN*16+BLACK
        call print_centre
        ld hl,txt_gp2
        ld b,19
        ld a,GREEN*16+BLACK
        call print_centre
        ld de,VRAM+21*40+16     ; the score
        ld c,WHITE*16+BLACK
        ld a,(score+2)
        call put_bcd
        ld a,(score+1)
        call put_bcd
        ld a,(score)
        call put_bcd
        xor a
        call put_digit
        ld b,0                  ; about six seconds
.w:     push bc
        ld a,2
        call wait_fields
        call logo_glint
        ld hl,framecnt
        inc (hl)
        ; fireworks: sparkles in the sky above the text
        call rand8
        and 7
        add a,1
        ld c,a
        call rand8
        and 31
        add a,4
        ld e,a
        ld d,0
        ld hl,CRAM+6*40
        ld a,(framecnt)
        and 1
        jr z,.fw
        ld hl,CRAM+24*40
.fw:    add hl,de
        ld a,c
        rlca
        rlca
        rlca
        rlca
        ld (hl),a
        res 3,h
        ld (hl),6Bh             ; a star
        pop bc
        djnz .w
        ret

txt_gp1:  db "CONGRATULATIONS!  YOU REACHED",0
txt_gp2:  db "YOUR SCORE",0
goaltxt:  dw gt0,gt1,gt2,gt3,gt4
gt0:      db "TEA ON THE GREEN. A GENTLE FINISH.",0
gt1:      db "ICE-BLUE WATER AND THIN AIR.",0
gt2:      db "THE SUN SETS OVER A MILE OF ROCK.",0
gt3:      db "THE CITY LIGHTS ARE ALL FOR YOU.",0
gt4:      db "DAWN BREAKS. THE ROAD IS YOURS.",0
