; =====================================================================
;  front.asm - title, attract mode, character select, VS, the arcade
;  ladder, continue, high scores, endings
;
;  Menu screens are built in BG (scr_base = BGM) and shown whole; the
;  compositor then draws fighters over them like over a stage.
; =====================================================================

NROSTER equ 8           ; selectable fighters (the boss is number 8)
BOSS    equ 8

; ---------------------------------------------------------------- helpers
; bg_clear: whole BG to blank chars, attr A
bg_clear:
        ld hl,BGM
        ld de,BGM+1
        ld bc,999
        ld (hl),0
        push af
        ldir
        pop af
        ld hl,BGM+800h
        ld de,BGM+801h
        ld bc,999
        ld (hl),a
        ldir
        ld hl,BGM
        ld (scr_base),hl
        ret

; bg_checker: every BG char a checker (the attrs give the two colours)
bg_checker:
        ld hl,BGM
        ld de,BGM+1
        ld bc,999
        ld (hl),0D0h
        ldir
        ret

; show_full: BG -> COMP, SHOWN and VRAM, all 25 rows
show_full:
        ld hl,VRAM
        ld (scr_base),hl
        ld hl,BGM
        ld de,COMP
        call .pl
        ld hl,BGM
        ld de,SHOWN
        call .pl
        ld hl,BGM
        ld de,VRAM
        call .pl
        jp objs_clear
.pl:    push hl
        push de
        ld bc,1000
        ldir
        pop de
        pop hl
        set 3,h
        set 3,d
        ld bc,1000
        ldir
        ret

; bg_banner: HL = banner record, C = row: centred 5x5 font text into BG
bg_banner:
        push bc
        call banner_make
        pop bc
        ld a,40
        sub (hl)
        srl a
        ld b,a
; bg_block: HL = cell block, B = col, C = row -> BG (opaque cells only)
bg_block:
        ld a,c
        push hl
        call row_addr           ; scr_base = BGM
        ld a,b
        add a,l
        ld e,a
        ld a,h
        adc a,0
        ld d,a
        pop hl
        ld c,(hl)               ; w
        inc hl
        ld b,(hl)               ; h
        inc hl
.r:     push bc
        push de
        ld b,c
.c:     ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        bit 3,c
        jr nz,.sk
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
.sk:    inc de
        djnz .c
        pop de
        ex de,hl
        ld bc,40
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret

; show_fighter: A = fighter, B = slot (0/1), C = column, D = facing, E = frame
; (loads the dictionary of the slot's player)
show_fighter:
        push de
        push bc
        ld (sf_id),a
        ld de,DICT1
        ld a,b
        or a
        jr z,$+5
        ld de,DICT2
        ld a,(sf_id)
        call load_dict
        pop bc
        pop de
        ld a,b
        ld ix,OBJ
        or a
        jr z,$+6
        ld ix,OBJ+OBJSZ
        ld (ix+O_TYPE),1
        ld (ix+O_COL),c
        ld a,(sf_row)
        ld (ix+O_ROW),a
        ld (ix+O_FLAGS),d
        ld a,b
        or a
        ld a,high DICT1
        jr z,$+4
        ld a,high DICT2
        ld (ix+O_DICT),a
        ld (ix+O_XLAT),high XLATI
        ld a,(sf_id)
; set_frame: IX = object, A = fighter, E = frame
set_frame:
        add a,a
        ld l,a
        ld h,0
        ld bc,ftr_tab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; frame table
        ld d,0
        add hl,de
        add hl,de
        ld a,(hl)
        ld (ix+O_PTR),a
        inc hl
        ld a,(hl)
        ld (ix+O_PTR+1),a
        ret
sf_id:  db 0
sf_row: db GROUND

; menu_frame: one frame of a menu screen; NZ if a key was pressed
menu_frame:
        call render
        call frame_wait
        jp anyhit

; ---------------------------------------------------------------- title
title:
        xor a
        ld (two_players),a
        ld (attract),a
        ld a,TUNE_TITLE
        call mus_play
.again: call title_screen
        ; wait for a choice; 8 seconds idle -> attract
        ld b,200
.w:     push bc
        call menu_frame
        pop bc
        jr nz,.key
        ; the joystick: up/down choose, a button starts
        ld a,(joy_in1)
        ld c,a
        ld a,(tj_prev)
        cpl
        and c
        ld e,a
        ld a,c
        ld (tj_prev),a
        ld a,e
        and (1<<IN_P)+(1<<IN_K)
        jr nz,.go
        ld a,e
        and (1<<IN_U)+(1<<IN_D)
        jr nz,.tog
        ld a,b
        and 15
        jr nz,.nb
        push bc
        call title_blink
        pop bc
.nb:    djnz .w
        call attract_loop
        jr title
.key:   ld a,KC_J
        call key_hit
        jr z,.nj
        call kb_clear
        call joy_toggle
        call title_menu
        ld a,SFX_SELECT
        call sfx_play
        ld b,200
        jr .w
.nj:    ld a,KC_UP
        call key_hit
        jr nz,.tog
        ld a,KC_DOWN
        call key_hit
        jr nz,.tog
        ld a,KC_SPACE
        call key_hit
        jr nz,.go
        ld a,KC_CR
        call key_hit
        jr nz,.go
        call kb_clear
        jr .w
.tog:   call kb_clear
        ld a,(two_players)
        xor 1
        ld (two_players),a
        call title_menu
        ld a,SFX_MOVE
        call sfx_play
        ld b,200
        jp .w
.go:    call kb_clear
        ld a,SFX_SELECT
        call sfx_play
        ld a,(two_players)
        or a
        jp nz,versus_mode
        jp arcade

title_screen:
        ld a,(BLUE*16)+BLUE
        call bg_clear
        ; stripes of colour behind the logo
        ld a,BLACK*16+BLACK
        ld b,1
        ld c,13
        call clear_rows
        ld hl,bn_logo1
        ld c,2
        call bg_banner
        ld hl,bn_logo2
        ld c,8
        call bg_banner
        ld hl,s_tag
        ld c,14
        ld a,(CYAN*16)+BLACK
        call print_centre
        ld hl,s_credit
        ld c,24
        ld a,(WHITE*16)+BLUE
        call print_centre
        call show_full
        call title_menu
        ; two fighters
        ld a,(title_pair)
        and 7
        ld b,0
        ld c,4
        ld d,0
        ld e,FR_WIN
        call show_fighter
        ld a,(title_pair)
        add a,3
        and 7
        ld b,1
        ld c,36
        ld d,1
        ld e,FR_WIN
        call show_fighter
        ld a,(title_pair)
        inc a
        ld (title_pair),a
        ret

title_menu:
        ld hl,s_1p
        ld bc,(16*256)+18
        ld a,(two_players)
        or a
        ld a,(YELLOW*16)+BLUE
        jr z,$+4
        ld a,(WHITE*16)+BLUE
        call print_at_vram
        ld hl,s_2p
        ld bc,(16*256)+20
        ld a,(two_players)
        or a
        ld a,(WHITE*16)+BLUE
        jr z,$+4
        ld a,(YELLOW*16)+BLUE
        call print_at_vram
        ; the joystick option
        ld a,(joy_mode)
        add a,a
        ld l,a
        ld h,0
        ld de,joy_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld bc,(10*256)+16
        ld a,(CYAN*16)+BLUE
        jp print_at_vram
joy_names: dw s_joy0, s_joy1, s_joy2
tj_prev: db 0

title_blink:
        ld a,(blink)
        xor 1
        ld (blink),a
        ld hl,s_push
        ld c,22
        ld a,(blink)
        or a
        ld a,(WHITE*16)+BLUE
        jr z,$+4
        ld a,(BLUE*16)+BLUE
        push hl
        ld hl,VRAM
        ld (scr_base),hl
        pop hl
        jp print_centre

; print in VRAM (and SHOWN, so the compositor stays in step) - menu rows
; are outside any sprite, so printing to VRAM alone is fine
print_at_vram:
        push hl
        ld hl,VRAM
        ld (scr_base),hl
        pop hl
        jp print_at

; ---------------------------------------------------------------- attract
attract_loop:
        ld a,1
        ld (attract),a
        call roster_screen
        jr nz,.out
        ; a demo fight between two random fighters
        ld b,NROSTER
        call rand_below
        ld (PL1+P_ID),a
        ld c,a
.r2:    ld b,NROSTER+1
        call rand_below
        cp c
        jr z,.r2
        ld (PL2+P_ID),a
        ld (cur_stage),a
        ld a,1
        ld (PL1+P_CPU),a
        ld (PL2+P_CPU),a
        ld a,4
        ld (ai_level),a
        xor a
        ld (quit_flag),a
        call match_play
        call hiscore_screen
.out:   xor a
        ld (attract),a
        call mus_stop
        call kb_clear
        ret

; the fighters, one by one: name, country, a pose.  NZ if a key was hit.
roster_screen:
        ld a,(BLACK*16)+BLACK
        call bg_clear
        ld hl,bn_world
        ld c,1
        call bg_banner
        call show_full
        xor a
        ld (rs_i),a
.f:     ld a,(rs_i)
        ld b,0
        ld c,11
        ld d,0
        ld e,FR_STANCE
        call show_fighter
        ; name and country at the right
        ld de,VRAM+12*40+22
        ld b,16
        xor a
        ld c,a
        call fill_cells
        ld de,VRAM+14*40+22
        ld b,16
        xor a
        ld c,a
        call fill_cells
        ld a,(rs_i)
        call info_ptr
        push hl
        ld de,FI_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld bc,(24*256)+12
        ld a,(YELLOW*16)+BLACK
        call print_at_vram
        pop hl
        ld de,FI_LAND
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld bc,(24*256)+14
        ld a,(CYAN*16)+BLACK
        call print_at_vram
        ld b,50
.w:     push bc
        call menu_frame
        pop bc
        ret nz
        ld a,b
        cp 30
        jr nz,.nw
        push bc
        ld ix,OBJ
        ld a,(rs_i)
        ld e,FR_WIN
        call set_frame
        pop bc
.nw:    djnz .w
        ld a,(rs_i)
        inc a
        ld (rs_i),a
        cp NROSTER+1
        jr c,.f
        xor a
        ret

print_centre_v:
        push hl
        ld hl,VRAM
        ld (scr_base),hl
        pop hl
        jp print_centre

; HL = info record of fighter A
info_ptr:
        add a,a
        ld l,a
        ld h,0
        ld de,ftr_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,6
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; ---------------------------------------------------------------- select
; select_screen: returns sel1 (and sel2 in two-player mode)
select_screen:
        ld a,TUNE_SELECT
        call mus_play
        ld a,(BLUE*16)+BLACK
        call bg_clear
        call bg_checker
        ld a,(BLACK*16)+BLACK
        ld b,18
        ld c,7
        call clear_rows
        ld hl,s_select
        ld c,1
        ld a,(WHITE*16)+BLACK
        call print_centre
        ; the cards: 2 rows of 4, rows 19-20 and 22-23
        xor a
.cd:    push af
        call card_draw
        pop af
        inc a
        cp NROSTER
        jr c,.cd
        call show_full
        ld a,17
        ld (sf_row),a
        ld a,(sel1)
        ld b,0
        ld c,9
        ld d,0
        ld e,FR_STANCE
        call show_fighter
        ld a,(two_players)
        or a
        jr z,.one
        ld a,(sel2)
        ld b,1
        ld c,31
        ld d,1
        ld e,FR_STANCE
        call show_fighter
.one:   call cards_mark
        ld a,250
        ld (sel_time),a
.loop:  call render
        call frame_wait
        ; timeout picks the current one
        ld a,(sel_time)
        dec a
        ld (sel_time),a
        jr z,.done
        call kb_clear_keep
        ; P1 moves with cursor keys or WASD, picks with Z/SPACE/V
        ld hl,keys_p1
        ld a,(two_players)
        or a
        jr z,$+5
        ld hl,keys_p1b
        call keys_read
        ld hl,joy_in1
        or (hl)
        ld c,a
        ld a,(sel1_done)
        or a
        jr nz,.p2
        ld hl,sel1
        ld b,0
        call sel_move
        jr nz,.loop
.p2:    ld a,(two_players)
        or a
        jr z,.chk
        ld a,(sel2_done)
        or a
        jr nz,.chk
        ld hl,keys_p2
        call keys_read
        ld hl,joy_in2
        or (hl)
        ld c,a
        ld hl,sel2
        ld b,1
        call sel_move
.chk:   ld a,(sel1_done)
        or a
        jr z,.loop
        ld a,(two_players)
        or a
        jr z,.done
        ld a,(sel2_done)
        or a
        jr z,.loop
.done:  ld b,25
.d:     push bc
        call render
        call frame_wait
        pop bc
        djnz .d
        ld a,GROUND
        ld (sf_row),a
        xor a
        ld (sel1_done),a
        ld (sel2_done),a
        ret

; sel_move: HL = selection var, B = slot, C = input bits (held; acted on
; when newly pressed).  NZ if the screen changed.
sel_move:
        ld a,b
        or a
        ld a,(sel_prev1)
        jr z,$+5
        ld a,(sel_prev2)
        cpl
        and c
        ld e,a                  ; newly pressed
        ld a,b
        or a
        ld a,c
        jr nz,.s2
        ld (sel_prev1),a
        jr .s
.s2:    ld (sel_prev2),a
.s:     ld a,e
        or a
        ret z
        ld a,(hl)
        bit IN_L,e
        jr z,.nl
        dec a
        and 7
.nl:    bit IN_R,e
        jr z,.nr
        inc a
        and 7
.nr:    bit IN_U,e
        jr nz,.ud
        bit IN_D,e
        jr z,.nud
.ud:    xor 4
.nud:   cp (hl)
        jr z,.pick
        ld (hl),a
        push bc
        push de
        push hl
        call cards_mark
        pop hl
        pop de
        pop bc
        ld a,(hl)
        ld c,9
        ld d,0
        bit 0,b
        jr z,$+6
        ld c,31
        ld d,1
        ld e,FR_STANCE
        push hl
        call show_fighter
        pop hl
        ld a,SFX_MOVE
        call sfx_play
        or 1
        ret
.pick:  ld a,e
        and (1<<IN_P)+(1<<IN_K)
        ret z
        ld a,b
        or a
        ld hl,sel1_done
        jr z,$+5
        ld hl,sel2_done
        ld (hl),1
        ; victory pose for the pick
        ld ix,OBJ
        or a
        jr z,$+6
        ld ix,OBJ+OBJSZ
        ld a,b
        or a
        ld a,(sel1)
        jr z,$+5
        ld a,(sel2)
        ld e,FR_WIN
        call set_frame
        ld a,SFX_SELECT
        call sfx_play
        or 1
        ret

; card_draw: A = fighter -> its card in VRAM, colour by selection
card_draw:
        ld (cd_i),a
        ld c,(BLUE*16)+BLACK
        ld hl,sel1
        cp (hl)
        jr nz,.n1
        ld c,(WHITE*16)+RED
.n1:    ld hl,two_players
        bit 0,(hl)
        jr z,.n2
        ld hl,sel2
        cp (hl)
        jr nz,.n2
        ld c,(WHITE*16)+BLUE
        ld hl,sel1
        cp (hl)
        jr nz,.n2
        ld c,(WHITE*16)+MAGENTA
.n2:    ld a,c
        ld (cd_attr),a
        ; position: col (i & 3) * 10, row 19 + (i >> 2) * 3
        ld a,(cd_i)
        and 3
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        ld b,a                  ; col
        ld a,(cd_i)
        and 4
        rrca
        rrca
        ld c,a
        add a,a
        add a,c
        add a,19
        ld c,a                  ; row
        push bc
        ld hl,VRAM
        ld (scr_base),hl
        ld a,c
        call row_addr
        ld a,b
        add a,l
        ld e,a
        ld a,h
        adc a,0
        ld d,a
        push de
        ld b,10
        ld a,(cd_attr)
        ld c,a
        xor a
        call fill_cells
        pop de
        ld hl,40
        add hl,de
        ex de,hl
        ld b,10
        ld a,(cd_attr)
        ld c,a
        xor a
        call fill_cells
        pop bc
        inc b
        ld a,(cd_i)
        call info_ptr
        push hl
        push bc
        ld de,FI_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(cd_attr)
        call print_at
        pop bc
        pop hl
        inc c
        ld de,FI_LAND
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(cd_attr)
        and 0Fh
        or YELLOW*16
        jp print_at

cards_mark:
        xor a
.c:     push af
        call card_draw
        pop af
        inc a
        cp NROSTER
        jr c,.c
        ret

; keep keyacc clean between menu frames (we read held keys)
kb_clear_keep:
        jp kb_clear

; ---------------------------------------------------------------- VS
vs_screen:
        ld a,(BLUE*16)+BLACK
        call bg_clear
        call bg_checker
        ld hl,BGM+800h
        ld b,25
.h:     push bc
        ld d,h
        ld e,l
        inc de
        ld (hl),(RED*16)+BLACK
        ld bc,19
        ldir
        ld bc,21
        add hl,bc
        pop bc
        djnz .h
        ld hl,bn_vs
        ld c,9
        call bg_banner
        call show_full
        ld a,(PL1+P_ID)
        ld b,0
        ld c,8
        ld d,0
        ld e,FR_STANCE
        call show_fighter
        ld a,(PL2+P_ID)
        ld b,1
        ld c,32
        ld d,1
        ld e,FR_STANCE
        call show_fighter
        ; names under them
        ld a,(PL1+P_ID)
        call info_ptr
        ld de,FI_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld bc,(2*256)+24
        ld a,(YELLOW*16)+BLACK
        call print_at_vram
        ld a,(PL2+P_ID)
        call info_ptr
        ld de,FI_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call str_len
        ld a,38
        sub b
        ld b,a
        ld c,24
        ld a,(YELLOW*16)+BLACK
        call print_at_vram
        ld a,SFX_FIGHT
        call sfx_play
        ld b,60
.w:     push bc
        call render
        call frame_wait
        pop bc
        djnz .w
        ret

; ---------------------------------------------------------------- arcade
arcade:
        call select_screen
        ld a,(sel1)
        ld (PL1+P_ID),a
        xor a
        ld (match_no),a
        ld (PL1+P_CPU),a
        ld hl,0
        ld (score1),hl
.next:  ; opponent: the fighters after ours in order, then the boss
        ld a,(match_no)
        cp NROSTER-1
        ld a,BOSS
        jr nc,.opp
        ld a,(match_no)
        ld b,a
        ld a,(sel1)
        add a,b
        inc a
        and 7
.opp:   ld (PL2+P_ID),a
        ld (cur_stage),a
        ld a,1
        ld (PL2+P_CPU),a
        ld a,(match_no)
        cp 7
        jr c,$+4
        ld a,6
        ld (ai_level),a
        call vs_screen
.fight: xor a
        ld (quit_flag),a
        ld (PL1+P_WINS),a
        ld (PL2+P_WINS),a
        ld hl,(score1)
        ld (sc_carry),hl
        call match_play
        push af
        ld a,(quit_flag)
        or a
        jr z,.nq
        pop af
        jp title
.nq:    pop af
        or a
        jr nz,.lost
        ; won: keep the score, next opponent
        ld hl,(PL1+P_SC)
        ld (score1),hl
        ld a,TUNE_WIN
        call jingle
        ld a,(match_no)
        inc a
        ld (match_no),a
        cp NROSTER
        jr c,.next
        call ending
        jp game_over
.lost:  ld a,TUNE_LOSE
        call jingle
        call continue_screen
        jr z,.over
        ld hl,0
        ld (score1),hl
        call vs_screen
        jr .fight
.over:  ld hl,(PL1+P_SC)
        ld (score1),hl
game_over:
        call hiscore_enter
        jp title

; jingle: A = tune, played once, waits for it
jingle:
        ld b,a
        ld a,1
        ld (mus_noloop),a
        ld a,b
        call mus_play
        ld b,80
.w:     push bc
        call frame_wait
        pop bc
        ld a,(mus_on)
        or a
        jr z,.e
        djnz .w
.e:     xor a
        ld (mus_noloop),a
        jp mus_stop

; continue_screen: Z = no
continue_screen:
        ld a,(BLACK*16)+BLACK
        call bg_clear
        ld hl,bn_cont
        ld c,6
        call bg_banner
        call show_full
        ld a,(PL1+P_ID)
        ld b,0
        ld c,20
        ld d,0
        ld e,FR_DOWN
        call show_fighter
        call kb_clear
        ld a,9
.n:     ld (cd_i),a
        add a,20h
        ld hl,VRAM+14*40+19
        ld (hl),a
        ld hl,ARAM+14*40+19
        ld (hl),80h+(YELLOW*16)+BLACK
        ld b,22
.w:     push bc
        call menu_frame
        pop bc
        jr nz,.key
        djnz .w
        ld a,(cd_i)
        or a
        ret z
        dec a
        jr .n
.key:   call kb_clear
        or 1
        ret

; ---------------------------------------------------------------- 2 players
versus_mode:
        call select_screen
        ld a,(sel1)
        ld (PL1+P_ID),a
        ld a,(sel2)
        ld (PL2+P_ID),a
        ld (cur_stage),a
        xor a
        ld (PL1+P_CPU),a
        ld (PL2+P_CPU),a
        ld (quit_flag),a
        call vs_screen
        call match_play
        ld a,(quit_flag)
        or a
        jp nz,title
        ld a,TUNE_WIN
        call jingle
        jr versus_mode

; ---------------------------------------------------------------- endings
ending:
        ld a,TUNE_ENDING
        call mus_play
        ld a,(BLUE*16)+BLUE
        call bg_clear
        ld hl,bn_champ
        ld c,1
        call bg_banner
        call show_full
        ld a,(PL1+P_ID)
        ld b,0
        ld c,8
        ld d,0
        ld e,FR_WIN
        call show_fighter
        ; the fighter's ending text
        ld a,(PL1+P_ID)
        add a,a
        ld l,a
        ld h,0
        ld de,end_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld bc,(16*256)+9
        ld a,(WHITE*16)+BLUE
        call print_at_vram
        ld hl,s_thanks
        ld c,24
        ld a,(YELLOW*16)+BLUE
        call print_centre_v
        ld b,0
.w:     push bc
        call menu_frame
        pop bc
        jr nz,.k
        djnz .w
.k:     jp kb_clear

; ---------------------------------------------------------------- high scores
; table: 5 entries x (score word, 3 letters, fighter)
hiscore_screen:
        ld a,(BLACK*16)+BLACK
        call bg_clear
        ld hl,bn_best
        ld c,2
        call bg_banner
        call show_full
        ld ix,hi_table
        ld c,10
        ld b,5
.l:     push bc
        ld hl,VRAM
        ld (scr_base),hl
        ; rank, initials, score, fighter
        ld a,c
        call row_addr
        ld de,9
        add hl,de
        ex de,hl
        ld a,(ix+2)
        ld c,(YELLOW*16)+BLACK
        call .ch
        ld a,(ix+3)
        call .ch
        ld a,(ix+4)
        call .ch
        inc de
        inc de
        ld l,(ix+0)
        ld h,(ix+1)
        ld b,5
        ld c,(WHITE*16)+BLACK
        call print_num
        ld a,20h
        call putc
        inc de
        inc de
        push de
        ld a,(ix+5)
        call info_ptr
        ld de,FI_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ld c,(CYAN*16)+BLACK
        call print
        ld de,6
        add ix,de
        pop bc
        inc c
        inc c
        djnz .l
        ld b,120
.w:     push bc
        call menu_frame
        pop bc
        ret nz
        djnz .w
        xor a
        ret
.ch:    push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        jp putc_inc
putc_inc:
        call putc
        inc de
        ret

; hiscore_enter: if score1 makes the table, take initials
hiscore_enter:
        ld ix,hi_table
        ld b,5
.f:     ld l,(ix+0)
        ld h,(ix+1)
        ld de,(score1)
        or a
        sbc hl,de
        jr c,.ins
        ld de,6
        add ix,de
        djnz .f
        ret
.ins:   ; shift the rest down
        push ix
        pop hl                  ; HL = slot
        ld (he_slot),hl
        ld de,hi_table+4*6
        ex de,hl
        or a
        sbc hl,de               ; bytes below the slot (in the last 4 entries)
        jr c,.put
        jr z,.put
        ld b,h
        ld c,l
        ld hl,hi_table+4*6-1
        ld de,hi_table+5*6-1
        lddr
.put:   ld ix,(he_slot)
        ld hl,(score1)
        ld (ix+0),l
        ld (ix+1),h
        ld a,(PL1+P_ID)
        ld (ix+5),a
        ld (ix+2),'A'
        ld (ix+3),'A'
        ld (ix+4),'A'
        ; enter initials on a black screen
        ld a,(BLACK*16)+BLACK
        call bg_clear
        ld hl,bn_best
        ld c,2
        call bg_banner
        call show_full
        ld hl,s_enter
        ld c,10
        ld a,(WHITE*16)+BLACK
        call print_centre_v
        ld ix,(he_slot)         ; (show_full used IX)
        ld c,0                  ; letter index
.l:     push bc
        ; draw the three letters
        ld hl,VRAM+14*40+18
        ld b,3
        push ix
.d:     ld a,(ix+2)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (hl),a
        set 3,h
        ld (hl),(YELLOW*16)+BLACK
        res 3,h
        inc hl
        inc ix
        djnz .d
        pop ix
        pop bc
        ; wait for a key
.k:     push bc
        call frame_wait
        call anyhit
        pop bc
        jr z,.k
        push ix
        pop hl
        ld e,c
        ld d,0
        add hl,de
        inc hl
        inc hl                  ; HL = the letter
        ld a,KC_UP
        call key_hit
        jr z,.nu
        inc (hl)
        ld a,(hl)
        cp 'Z'+1
        jr c,.nx
        ld (hl),'A'
.nu:    ld a,KC_DOWN
        call key_hit
        jr z,.nd
        dec (hl)
        ld a,(hl)
        cp 'A'
        jr nc,.nx
        ld (hl),'Z'
.nd:    ld a,KC_SPACE
        call key_hit
        jr nz,.adv
        ld a,KC_Z
        call key_hit
        jr nz,.adv
        ld a,KC_RIGHT
        call key_hit
        jr z,.nx
.adv:   inc c
        ld a,SFX_MOVE
        call sfx_play
.nx:    call kb_clear
        ld a,c
        cp 3
        jr c,.l
        ret

; ---------------------------------------------------------------- data
attract: db 0
blink:  db 0
title_pair: db 0
rs_i:   db 0
sel1:   db 0
sel2:   db 1
sel1_done: db 0
sel2_done: db 0
sel_prev1: db 0
sel_prev2: db 0
sel_time: db 0
cd_i:   db 0
cd_attr: db 0
match_no: db 0
score1: dw 0
sc_carry: dw 0
he_slot: dw 0
hi_table:
        dw 3000
        db "BPM",0
        dw 2500
        db "MZ7",1
        dw 2000
        db "SHP",2
        dw 1500
        db "KEN",3
        dw 1000
        db "ACE",4
