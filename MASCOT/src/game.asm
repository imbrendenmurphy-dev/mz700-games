; =====================================================================
;  game.asm - game and level flow, room changes, HUD, pause
; =====================================================================

HUDAT           equ 70h             ; white on black
HUDROW          equ VRAM            ; row 0
DEMO_FRAMES     equ 2400            ; the attract demo runs ~48 s at most

; ---------------------------------------------------------------------
; game: a whole game from level 1 (or the demo)
; ---------------------------------------------------------------------
game:
        xor a
        ld (demo_abort),a
        ld (title_music),a
        ld a,(start_level)
        ld (level),a
        xor a
        ld (gems),a
        ld (secrets),a
        ld hl,score
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld a,3
        ld (lives),a
.lv:    call play_level
        or a
        ret nz                      ; game over, quit or end of demo
        ld a,(demo)
        or a
        ret nz
        ld a,(lv_boss)              ; a boss beaten: a prism comes back
        or a
        jr z,.next
        ld a,(lv_world)
        cp 3
        call c,prism_screen
.next:  ld a,(level)
        inc a
        ld (level),a
        cp NLEVELS
        jr c,.lv
        call ending                 ; finished the game
        ret

; ---------------------------------------------------------------------
; play_level: A = 0 cleared, 1 game over, 2 quit / demo over
; ---------------------------------------------------------------------
play_level:
        ld a,(level)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de                   ; *12
        ld de,LEVELTAB
        add hl,de
        ld a,(hl)
        ld (cp_room),a
        inc hl
        ld a,(hl)
        ld (cp_x),a
        inc hl
        ld a,(hl)
        ld (cp_y),a
        inc hl
        ld a,(hl)
        ld (lv_world),a
        inc hl
        ld a,(hl)
        ld (lv_ngems),a
        inc hl
        ld a,(hl)
        ld (lv_boss),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (lv_song),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (lv_name),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (lv_hint),de
        xor a
        ld (cp_dir),a
        ld (gems_level),a
        ld (secrets_level),a
        ld (level_done),a
        ld hl,taken
        ld de,taken+1
        ld bc,31
        ld (hl),0
        ldir
        ; colours Kiko owns in this world: W1 green, W2 +red, W3/W4 all
        ld a,(lv_world)
        ld hl,OWNTAB
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (howned),a
        ld a,1
        ld (hcol),a                 ; green
        ld hl,0
        ld (demo_t),hl
        ld a,(demo)
        or a
        call z,level_intro
.respawn:
        ld a,3
        ld (hearts),a
        call sfx_stop
        ld a,(cp_room)
        call load_room
        ld a,(cp_x)
        ld b,a
        ld a,(cp_y)
        ld c,a
        ld a,(cp_dir)
        call hero_place
        xor a
        ld (hdead),a
        ld (level_done),a
        ld (hinv),a
        ld (hswapf),a
        call refresh_chroma_quiet   ; colour reset to green on respawn
        call hud_full
        call show_hint
        xor a
        call wipe_in
        ld hl,(lv_song)
        call mus_play
        call fe_reset
.loop:  call frame_step
        ld a,(frame_result)
        or a
        jr z,.loop
        cp FR_EXIT
        jr z,.exit
        cp FR_DEAD
        jr z,.dead
        cp FR_WON
        jr z,.won
        ld a,2                      ; quit / demo over
        ret
.exit:  call room_change
        jr .loop
.dead:  ld a,(demo)
        or a
        ld a,2
        ret nz
        ld a,(lives)
        dec a
        ld (lives),a
        jr z,.over
        ld a,1
        ld (hcol),a
        jr .respawn
.over:  call game_over
        ld a,1
        ret
.won:   call level_clear
        xor a
        ret

OWNTAB: db 2, 3, 7, 7

FR_EXIT         equ 1
FR_DEAD         equ 2
FR_WON          equ 3
FR_QUIT         equ 4

; ---------------------------------------------------------------------
; one game frame; frame_result = 0 or an event
; ---------------------------------------------------------------------
frame_step:
        xor a
        ld (frame_result),a
        call wait_frame
        call flush
        call hud_update
        ld hl,hint_t
        ld a,(hl)
        or a
        jr z,.nohint
        dec (hl)
        call z,hud_divider
.nohint:
        ; input
        ld a,(demo)
        or a
        jr z,.human
        call anykey
        jr z,.nokey
        ld a,1
        ld (demo_abort),a
        jr .quit
.nokey: ld hl,(demo_t)
        inc hl
        ld (demo_t),hl
        ld de,DEMO_FRAMES
        or a
        sbc hl,de
        jr nc,.quit
        call pilot_keys
        jr .keys
.human: call read_keys
        ld b,a
        ld a,(key_quit)
        or a
        jr nz,.quit
        ld a,(key_pause)
        ld c,a
        ld a,(pause_prev)
        cpl
        and c
        ld a,c
        ld (pause_prev),a
        call nz,pause
        ld a,b
.keys:  ld (hkeys),a
        ; world
        call objects_update
        call plat_carry
        call hero_update
        call objects_interact
        call tt_tick
        ld hl,anim_clock
        inc (hl)
        ld a,(hl)
        and 7
        call z,anim_tick
        ; compose
        call restore_old
        call objects_draw
        call hero_draw
        ; events
        ld a,(pending_exit)
        or a
        ld b,FR_EXIT
        jr nz,.ev
        ld a,(hdead)
        or a
        ld b,FR_DEAD
        jr nz,.ev
        ld a,(level_done)
        or a
        ret z
        ld b,FR_WON
.ev:    ld a,b
        ld (frame_result),a
        ret
.quit:  ld a,FR_QUIT
        ld (frame_result),a
        ret

; ---------------------------------------------------------------------
; room change through an edge (pending_exit 1 L, 2 R, 3 U, 4 D)
; ---------------------------------------------------------------------
room_change:
        ld a,(pending_exit)
        dec a
        ld e,a
        ld d,0
        ld hl,room_exits
        add hl,de
        ld a,(hl)
        push af
        ld a,e
        ld (rc_dir),a
        or a
        jr nz,.r
        ld a,ROOMW-2                ; left: arrive on the right
        ld (kx),a
        jr .load
.r:     cp 1
        jr nz,.u
        xor a
        ld (kx),a
        jr .load
.u:     cp 2
        jr nz,.d
        ld a,ROOMH-1
        ld (ky),a
        jr .load
.d:     ld a,2
        ld (ky),a
.load:  pop af
        call load_room
        xor a
        ld (pending_exit),a
        ld (htngst),a
        ld (htngl),a
        ld a,0FFh
        ld (hplat),a
        ; checkpoint on horizontal entries only
        ld a,(kx)
        ld b,a
        ld a,(rc_dir)
        cp 2
        jr nc,.nocp
        ld a,(room)
        ld (cp_room),a
        ld a,b
        ld (cp_x),a
        ld a,(ky)
        ld (cp_y),a
        ld a,(hdir)
        ld (cp_dir),a
.nocp:  ld a,(hgnd)                 ; ground under the new spot?
        or a
        call nz,hero_ground_probe
        ld a,(rc_dir)
        or a                        ; left exit: wipe right to left
        ld a,0
        jr nz,.w
        inc a
.w:     jp wipe_in

; ---------------------------------------------------------------------
; HUD (screen rows 0-1)
; ---------------------------------------------------------------------
hud_full:
        ld b,0
        ld c,2
        ld a,HUDAT
        call clear_rows
        ld hl,txt_score
        ld de,HUDROW+13
        ld c,60h
        call print
        ld de,HUDROW+4              ; gem icon
        ld a,44h
        ld c,50h
        call putc
        ld de,HUDROW+28             ; Kiko's eye
        ld a,89h
        ld c,0F4h                   ; bank 1, white on green
        call putc
        ld de,HUDROW+29
        ld a,18h                    ; 'x'
        ld c,70h
        call putc
        ; level code
        ld a,(level)
        add a,a
        ld e,a
        ld d,0
        ld hl,LVCODES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,HUDROW+35
        ld c,50h
        call print
        ld a,1
        ld (hud_dirty),a
        call hud_divider
        jr hud_update

; divider row: a thin green bar (and the boss's energy)
hud_divider:
        ld de,HUDROW+40
        ld b,40
.dv:    ld a,36h
        ld c,40h
        call putc
        inc de
        djnz .dv
        ld a,(boss_on)
        or a
        ret z
        jp boss_hud

; the level's hint on the divider row for a few seconds
show_hint:
        ld a,(demo)
        or a
        ret nz
        ld hl,(lv_hint)
        ld a,(hl)
        or a
        ret z
        ld c,1
        ld a,60h
        call print_centre
        ld a,250
        ld (hint_t),a
        ret
hud_update:
        ld a,(hud_dirty)
        or a
        ret z
        xor a
        ld (hud_dirty),a
        ; hearts
        ld de,HUDROW
        ld b,3
        ld a,(hearts)
        ld c,a
.h:     ld a,c
        or a
        jr z,.empty
        dec c
        ld a,49h                    ; bank-1 heart
        push bc
        ld c,0A0h                   ; bank 1, red
        call putc
        pop bc
        jr .hn
.empty: ld a,53h                    ; outline heart
        push bc
        ld c,10h
        call putc
        pop bc
.hn:    inc de
        djnz .h
        ; gems
        ld hl,gems
        ld b,1
        ld de,HUDROW+5
        ld c,50h
        call print_bcd
        ; colours: owned = dot, current = block, missing = dim dot
        ld de,HUDROW+9
        ld b,0
.c:     ld a,b
        ld hl,CIDX
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        ld c,a                      ; fg = that colour
        ld a,(howned)
        push bc
        inc b
.sh:    rrca
        djnz .sh
        pop bc
        jr nc,.miss
        ld a,(hcol)
        cp b
        ld a,47h                    ; dot
        jr nz,.p2
        ld a,43h                    ; block
        jr .p2
.miss:  ld a,2Eh                    ; '.'
        ld c,10h
.p2:    call putc
        inc de
        inc b
        ld a,b
        cp 3
        jr c,.c
        ; score
        ld hl,score+2
        ld b,3
        ld de,HUDROW+19
        ld c,70h
        call print_bcd
        ; lives
        ld a,(lives)
        add a,20h
        ld de,HUDROW+30
        ld c,70h
        jp putc

txt_score:      db "SCORE",0

; ---------------------------------------------------------------------
; pause: CR again to go on
; ---------------------------------------------------------------------
pause:
        push bc
        ld a,1
        ld (snd_mute),a
        call out_off
        ld de,HUDROW+40+16
        ld hl,txt_paused
        ld c,61h
        call print
.w1:    call poll
        call read_keys
        ld a,(key_pause)
        or a
        jr nz,.w1
.w2:    call poll
        call read_keys
        ld a,(key_pause)
        or a
        jr z,.w2
.w3:    call poll
        call read_keys
        ld a,(key_pause)
        or a
        jr nz,.w3
        xor a
        ld (snd_mute),a
        ld (pause_prev),a
        ld de,HUDROW+40+16          ; restore the divider
        ld b,8
.r:     ld a,36h
        ld c,40h
        call putc
        inc de
        djnz .r
        call wait_frame             ; don't count the pause as a late frame
        ld a,(fieldcnt)
        ld (lastframe),a
        pop bc
        ret

txt_paused:     db " PAUSED ",0

; ---------------------------------------------------------------------
; level start / clear / game over
; ---------------------------------------------------------------------
level_intro:
        xor a
        call cls
        ld hl,txt_world
        ld de,VRAM+40*9+14
        ld c,70h
        call print
        ld a,(level)
        add a,a
        ld e,a
        ld d,0
        ld hl,LVCODES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,60h
        call print
        ld hl,(lv_name)
        ld c,13
        ld a,50h
        call print_centre
        ld hl,FR_K_STAND_R
        ld de,VRAM+40*16+19
        call draw_frame_vram
        ld hl,SONG_START
        call mus_play
        ld a,110
        call wait_fields
        ret

txt_world:      db "WORLD ",0

level_clear:
        ld a,HS_WIN
        ld (hstate),a
        xor a
        ld (htimer),a
        ld (htngl),a
        ld (htngst),a
        ld hl,SONG_CLEAR
        call mus_play
        ld b,120
.f:     push bc
        call wait_frame
        call flush
        call hero_update
        call restore_old
        call objects_draw
        call hero_draw
        pop bc
        djnz .f
        ; tally: 100 points a gem
        xor a
        call cls
        ld hl,txt_clear
        ld c,6
        ld a,60h
        call print_centre
        ld hl,txt_gems
        ld de,VRAM+40*10+12
        ld c,50h
        call print
        ld a,(gems_level)
        ld c,70h
        call print_dec3
        ld hl,txt_of
        ld c,50h
        call print
        ld a,(lv_ngems)
        ld c,70h
        call print_dec3
        ld hl,txt_secret
        ld de,VRAM+40*12+12
        ld c,50h
        call print
        ld a,(secrets_level)
        ld c,70h
        or a
        ld hl,txt_none
        jr z,.ps
        ld hl,txt_found
        ld a,(secrets)
        inc a
        ld (secrets),a
.ps:    call print
        ; bonus count-up
        ld a,(gems_level)
        or a
        jr z,.perf
        ld b,a
.bon:   push bc
        ld de,0100h
        call add_score
        call hud_score_line
        ld hl,SFX_BLIP
        xor a
        call sfx
        ld a,2
        call wait_fields
        pop bc
        djnz .bon
.perf:  ld a,(gems_level)           ; every gem: +5000
        ld hl,lv_ngems
        cp (hl)
        jr nz,.wait
        or a
        jr z,.wait
        ld hl,txt_perfect
        ld c,16
        ld a,30h
        call print_centre
        ld de,5000h
        call add_score
        call hud_score_line
        ld hl,SFX_ONEUP
        ld a,4
        call sfx
.wait:  ld a,120
        jp wait_fields

; score on row 19 of a front-end screen
hud_score_line:
        ld hl,txt_score
        ld de,VRAM+40*19+14
        ld c,70h
        call print
        inc de
        ld hl,score+2
        ld b,3
        ld c,60h
        jp print_bcd

txt_clear:      db "LEVEL CLEAR!",0
txt_gems:       db "GEMS    ",0
txt_of:         db " OF ",0
txt_secret:     db "STAR    ",0
txt_none:       db "NOT FOUND",0
txt_found:      db "FOUND!",0
txt_perfect:    db "ALL GEMS! BONUS 5000",0

; draw a sprite frame straight to VRAM (front end): HL = frame, DE = VRAM
; of the frame's top-left cell.  Transparent cells keep the screen colour.
draw_frame_vram:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        inc hl
        inc hl
        jp draw_pic_wh

game_over:
        xor a
        call cls
        ld hl,txt_gameover
        ld c,10
        ld a,20h
        call print_centre
        call hud_score_line
        ld hl,SONG_GAMEOVER
        call mus_play
        ld a,200
        jp wait_fields

txt_gameover:   db "GAME OVER",0
