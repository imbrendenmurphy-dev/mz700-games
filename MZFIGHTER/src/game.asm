; =====================================================================
;  game.asm - a match: rounds, banners, KOs, the frame loop
; =====================================================================

FRAME_TICKS equ 4       ; 100 Hz ticks per frame: 25 fps
BANNER_OBJ equ OBJ+6*OBJSZ

; match_play: PL1/PL2 P_ID and P_CPU set, stage in cur_stage.
; Returns A = 0 P1 won, 1 P2 won, 2 draw
match_play:
        ; dictionaries and palettes
        ld a,(PL1+P_ID)
        ld de,DICT1
        call load_dict
        ld a,(PL2+P_ID)
        ld de,DICT2
        call load_dict
        call set_palettes
        ld iy,PL1
        ld a,(PL1+P_ID)
        ld c,(iy+P_CPU)
        ld b,0
        call player_init
        ld (iy+P_CPU),c
        ld hl,(sc_carry)
        ld (iy+P_SC),l
        ld (iy+P_SC+1),h
        ld hl,0
        ld (sc_carry),hl
        ld hl,1250              ; attract demos last 50 seconds at most
        ld (att_frames),hl
        ld iy,PL2
        ld a,(PL2+P_ID)
        ld c,(iy+P_CPU)
        ld b,1
        call player_init
        ld (iy+P_CPU),c
        ld a,(cur_stage)
        call stage_load
        call objs_clear
        call hud_init
        ld a,1
        ld (round_no),a
        ld a,(cur_stage)
        add a,TUNE_STAGE0
        call mus_play
.round: call round_reset
        ld a,99
        ld (round_time),a
        xor a
        ld (time_frac),a
        ld (sp_t),a
        call hud_update
        ; ROUND n
        ld a,(round_no)
        ld hl,bn_round1
        cp 1
        jr z,.rb
        ld hl,bn_round2
        cp 2
        jr z,.rb
        ld hl,bn_final
.rb:    call banner_on
        ld a,SFX_ROUND
        call sfx_play
        ld b,45
        call idle_frames
        ld hl,bn_fight
        call banner_on
        ld a,SFX_FIGHT
        call sfx_play
        ld b,18
        call idle_frames
        call banner_off
        ld a,ST_STAND
        ld (PL1+P_ST),a
        ld (PL2+P_ST),a
        ; ------------------------------------------------ the fight
.loop:  call fight_frame
        ; timer
        ld a,(time_frac)
        inc a
        ld (time_frac),a
        cp 22
        jr c,.nt
        xor a
        ld (time_frac),a
        ld a,(round_time)
        or a
        jr z,.nt
        dec a
        ld (round_time),a
        jr z,.timeup
.nt:    ld a,(PL1+P_KO)
        ld b,a
        ld a,(PL2+P_KO)
        or b
        jr nz,.ko
        ld a,(quit_flag)
        or a
        jr nz,.quit
        jr .loop
.quit:  ld a,1
        ret
        ; ------------------------------------------------ KO
.ko:    ld hl,bn_ko
        call banner_on
        ld a,SFX_KO
        call sfx_play
        ; slow motion while the loser falls
        ld b,30
.slow:  push bc
        call fight_frame
        ld a,FRAME_TICKS
        call wait_ticks
        pop bc
        djnz .slow
        ld b,25
.fall:  push bc
        call fight_frame
        pop bc
        djnz .fall
        call banner_off
        ; who won?
        ld a,(PL1+P_KO)
        ld b,a
        ld a,(PL2+P_KO)
        and b
        jp nz,.drawr
        ld a,(PL2+P_KO)
        or a
        ld a,0
        jr nz,.won
        inc a
        jr .won
.timeup:
        ld hl,bn_time
        call banner_on
        ld b,40
        call idle_frames
        ld a,(PL1+P_HP)
        ld b,a
        ld a,(PL2+P_HP)
        cp b
        jr z,.drawr
        ld a,0
        jr c,.won
        inc a
.won:   ; A = round winner
        ld (rwin),a
        or a
        ld iy,PL1
        jr z,$+6
        ld iy,PL2
        inc (iy+P_WINS)
        ld a,ST_WIN
        call set_state
        ; time and vitality bonus
        ld e,(iy+P_HP)
        ld d,0
        ld l,(iy+P_SC)
        ld h,(iy+P_SC+1)
        add hl,de
        add hl,de
        ld a,(round_time)
        ld e,a
        add hl,de
        add hl,de
        ld (iy+P_SC),l
        ld (iy+P_SC+1),h
        call hud_stars
        call hud_update
        ld a,SFX_WIN
        call sfx_play
        ld (rwin_p),iy
        ld b,20
        call idle_frames
        ld iy,(rwin_p)
        ld a,(iy+P_DMGT)
        or a
        jr nz,.nperf
        ld hl,bn_perfect
        call banner_on
        ld de,500
        ld l,(iy+P_SC)
        ld h,(iy+P_SC+1)
        add hl,de
        ld (iy+P_SC),l
        ld (iy+P_SC+1),h
.nperf: ld b,50
        call idle_frames
        call banner_off
        ld iy,(rwin_p)
        ld a,(iy+P_WINS)
        cp 2
        jr nc,.matchover
        jr .next
.drawr: ld hl,bn_draw
        call banner_on
        ld b,60
        call idle_frames
        call banner_off
        ld a,(PL1+P_WINS)
        inc a
        ld (PL1+P_WINS),a
        ld a,(PL2+P_WINS)
        inc a
        ld (PL2+P_WINS),a
        call hud_stars
        ld a,(PL1+P_WINS)
        cp 2
        jr c,.next
        ld a,(PL2+P_WINS)
        cp 2
        jr c,.next
        ld a,2
        ret
.next:  ld a,(round_no)
        inc a
        ld (round_no),a
        ; the next round: fighters back to their marks
        jp .round
.matchover:
        ld a,(rwin)
        ret

; one frame of fighting (no timer)
fight_frame:
        ld a,(PL1+P_ST)
        cp ST_INTRO
        jr z,.noin
        call read_inputs
.noin:  ld iy,PL1
        ld ix,PL2
        call update_player
        ld iy,PL2
        ld ix,PL1
        call update_player
        ld iy,PL1
        call move_proj
        ld iy,PL2
        call move_proj
        ; hits (only while both still fight)
        ld iy,PL1
        ld ix,PL2
        call check_hits
        ld iy,PL2
        ld ix,PL1
        call check_hits
        call push_apart
        call set_objs
        call set_spark
        call stage_tick
        call render
        call hud_update
        jp frame_wait

; idle_frames: B frames with everyone in their current state (intro, win)
idle_frames:
.l:     push bc
        ld iy,PL1
        ld ix,PL2
        call update_player
        ld iy,PL2
        ld ix,PL1
        call update_player
        call set_objs
        call set_spark
        call stage_tick
        call render
        call hud_update
        call frame_wait
        pop bc
        djnz .l
        ret

; frame_wait: hold the 25 fps pace
frame_wait:
        ld a,(frame_tick)
        ld b,a
        ld a,(joy_mode)         ; frames that sample the sticks end at the
        or a                    ; VBLANK edge instead
        ld c,FRAME_TICKS
        jr z,.w
        ld a,(joy_alt)
        or a
        jr nz,.w
        dec c
.w:     ld a,(mtick)
        sub b
        cp c
        jr nc,.go
        halt
        jr .w
.go:    cp FRAME_TICKS*3
        ld a,(mtick)
        jr nc,.late             ; far behind: don't try to catch up
        ld a,b
        add a,FRAME_TICKS
.late:  ld (frame_tick),a
        ld a,(joy_mode)
        or a
        call nz,joy_frame
        ; attract mode: any key or the time limit ends the demo
        ld a,(attract)
        or a
        jr z,.play
        ld hl,(att_frames)
        dec hl
        ld (att_frames),hl
        ld a,h
        or l
        jr z,.aq
        call anyhit
        ret z
.aq:    ld a,1
        ld (quit_flag),a
        ret
.play:  ; BREAK pauses / quits
        ld a,KC_BREAK
        call key_hit
        ret z
        call kb_clear
        jp pause

pause:  ld a,1
        ld (paused),a
.p:     halt
        ld a,KC_BREAK
        call key_hit
        jr nz,.q
        call anyhit
        jr z,.p
        call kb_clear
        xor a
        ld (paused),a
        ld a,(mtick)
        ld (frame_tick),a
        ret
.q:     call kb_clear
        ld a,1
        ld (quit_flag),a
        xor a
        ld (paused),a
        ret

; banner_on: HL = banner record, centred, top row 8
banner_on:
        call banner_make
        ld ix,BANNER_OBJ
        ld (ix+O_TYPE),2
        ld (ix+O_PTR),l
        ld (ix+O_PTR+1),h
        ld a,40
        sub (hl)
        srl a
        ld (ix+O_COL),a
        ld (ix+O_ROW),8
        ret
banner_off:
        ld ix,BANNER_OBJ
        ld (ix+O_TYPE),0
        ret

; set_palettes: P2 in a mirror match gets the alternate colours
set_palettes:
        ld hl,XLATI
        ld de,XLAT1
        ld bc,256
        ldir
        ld hl,XLATI
        ld de,XLAT2
        ld bc,256
        ldir
        ld a,(PL1+P_ID)
        ld b,a
        ld a,(PL2+P_ID)
        cp b
        ret nz
        ; alternate: the fighter's colour swap list (pairs old,new; 0FFh ends)
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
        ld l,a                  ; info
        ld de,FI_ALT
        add hl,de
        ld de,alt_map
        ld bc,8
        ldir
        ; XLAT2[a] = fg/bg through alt_map
        ld hl,XLAT2
.x:     ld a,l
        rrca
        rrca
        rrca
        rrca
        and 7
        ld e,a
        ld d,0
        push hl
        ld hl,alt_map
        add hl,de
        ld b,(hl)               ; new fg
        pop hl
        ld a,l
        and 7
        ld e,a
        push hl
        ld hl,alt_map
        add hl,de
        ld c,(hl)               ; new bg
        pop hl
        ld a,l
        and 88h
        or c
        ld c,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or c
        ld (hl),a
        inc l
        jr nz,.x
        ret

alt_map: ds 8
round_no: db 0
round_time: db 0
time_frac: db 0
rwin:   db 0
rwin_p: dw 0
frame_tick: db 0
quit_flag: db 0
paused: db 0
cur_stage: db 0
att_frames: dw 0

; ---------------------------------------------------------------- banners
; banner_make: HL = banner record (db scheme, "TEXT", 0) -> a cell block
; at BANNER_BUF in the 5x5 font: each font pixel is half a cell wide.
BANNER_BUF equ 0B400h

banner_make:
        ld a,(hl)
        inc hl
        ld (bm_txt),hl
        ld e,a
        add a,a
        add a,a
        add a,e                 ; *5
        ld e,a
        ld d,0
        push hl
        ld hl,bn_schemes
        add hl,de
        ld (bm_sch),hl
        pop hl
        ; width in half cells
        ld c,0
.w:     ld a,(hl)
        or a
        jr z,.wd
        call font_ptr
        push hl
        ld hl,5
        add hl,de
        ld a,(hl)
        pop hl
        add a,c
        inc a
        ld c,a
        inc hl
        jr .w
.wd:    ld a,c                  ; (one gap too many: rounds up)
        srl a
        ld (bm_w),a
        ld hl,BANNER_BUF
        ld (hl),a
        inc hl
        ld (hl),5
        inc hl
        ld (bm_out),hl
        xor a
        ld (bm_row),a
.row:   ld hl,(bm_sch)
        ld a,(bm_row)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (bm_attr),a
        xor a
        ld (bm_pend),a
        ld a,(bm_w)
        ld (bm_left),a
        ld hl,(bm_txt)
.ch:    ld a,(hl)
        or a
        jr z,.rowend
        push hl
        call font_ptr           ; DE = glyph
        ld a,(bm_row)
        ld l,a
        ld h,0
        add hl,de
        ld c,(hl)               ; row bits
        ex de,hl
        ld de,5
        add hl,de
        ld b,(hl)               ; width
.bit:   sla c
        push bc
        call bm_emit
        pop bc
        djnz .bit
        or a                    ; gap
        call bm_emit
        pop hl
        inc hl
        jr .ch
.rowend:
        ; pad the row out to w cells
.pad:   ld a,(bm_left)
        or a
        jr z,.nrow
        or a
        call bm_emit
        jr .pad
.nrow:  ld a,(bm_row)
        inc a
        ld (bm_row),a
        cp 5
        jr c,.row
        ld hl,BANNER_BUF
        ret

; emit one half-cell pixel (carry = set).  Keeps BC, HL.
bm_emit:
        ld a,0
        rla
        ld e,a                  ; E = pixel
        ld a,(bm_left)
        or a
        ret z                   ; row full
        ld a,(bm_pend)
        or a
        jr nz,.second
        ld a,e
        or 2                    ; bit 1 = pending, bit 0 = the first pixel
        ld (bm_pend),a
        ret
.second:
        rrca                    ; first pixel -> carry
        ld a,e
        rla                     ; bit 1 = first, bit 0 = second
        and 3
        push hl
        ld hl,(bm_out)
        jr z,.empty
        ld e,43h
        cp 3
        jr z,.put
        ld e,3Bh                ; right half (bit 1 = second pixel)
        cp 2
        jr z,.put
        ld e,7Bh                ; left half
.put:   ld (hl),e
        inc hl
        ld a,(bm_attr)
        ld (hl),a
        jr .nx
.empty: ld (hl),0
        inc hl
        ld (hl),0               ; black backing
.nx:    inc hl
        ld (bm_out),hl
        pop hl
        xor a
        ld (bm_pend),a
        ld a,(bm_left)
        dec a
        ld (bm_left),a
        ret

; A = ASCII -> DE = its 6 font bytes
font_ptr:
        push hl
        sub 20h
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        add hl,hl               ; *6
        ld de,font5_tab
        add hl,de
        ex de,hl
        pop hl
        ret

bm_txt: dw 0
bm_sch: dw 0
bm_out: dw 0
bm_w:   db 0
bm_row: db 0
bm_attr: db 0
bm_pend: db 0
bm_left: db 0
