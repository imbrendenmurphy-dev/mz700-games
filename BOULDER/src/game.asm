; =====================================================================
;  game.asm - game flow: caves, lives, ticks, clock, bonus
; =====================================================================

DEMO_TICKS      equ 800             ; long enough for every recorded solution

game:
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (level),a
        ld (demo_abort),a
        ld (quit),a
        ld hl,0
        ld (life_acc),hl
        ld a,3
        ld (lives),a
        ld a,(demo)
        or a
        ld a,(start_cave)
        jr z,.sc
        ld a,(demo_cave)            ; the demo visits a different cave each time
        inc a
        and DEMO_N-1
        ld (demo_cave),a
        ld e,a
        ld d,0
        ld hl,demo_caves
        add hl,de
        ld a,(hl)
.sc:    ld (cave_no),a
.cave:  call cave_intro
        ld a,(quit)
        or a
        jr nz,.end
        call cave_play
        ld a,(quit)
        or a
        jr nz,.end
        ld a,(demo)
        or a
        ret nz                      ; the demo plays one attempt
        ld a,(cave_result)
        or a
        jr z,.next
        call is_bonus               ; a bonus cave costs no life
        jr z,.lost
.next:
        ; cave done: next one
        ld a,(cave_no)
        inc a
        cp NCAVES
        jr c,.nc
        call ending                 ; out of the mountain at daybreak
        ld a,(level)
        cp 4
        jr nc,.nl
        inc a
        ld (level),a
.nl:    xor a
.nc:    ld (cave_no),a
        jr .cave
.lost:  ld hl,lives
        dec (hl)
        jr nz,.cave
.end:   ld a,(demo)
        or a
        ret nz
        ld a,(quit)
        or a
        ret nz
        jp game_over

; ---------------------------------------------------------------------
; cave_play: one attempt at the cave.  Sets cave_result 0 = done,
; 1 = life lost; quit set by BREAK or a key in the demo.
; ---------------------------------------------------------------------
cave_play:
        xor a
        call cls
        call cave_load
        call info_draw
        call hud_draw
        xor a
        call msg_show_none
        call reveal
        ld a,(fieldcnt)
        ld (tick_last),a
        ld (sec_last),a
        call demo_start
        xor a
        ld (demo_ticks),a
        ld (demo_ticks+1),a
        ld (timeout),a
        ld (pause_prev),a
        call fe_reset
.loop:  ld a,(turbo)                ; test harness: no waiting
        or a
        call z,wait_frame
        ld hl,anim
        inc (hl)
        call input_frame
        ld a,(demo)
        or a
        jr z,.human
        call anykey
        jr z,.keys
        ld a,1
        ld (demo_abort),a
        ld (quit),a
        jp sfx_stop
.human: ld a,(key_quit)
        or a
        jr z,.nq
        ld a,1
        ld (quit),a
        jp sfx_stop
.nq:    ld a,(key_pause)
        ld hl,pause_prev
        ld b,(hl)
        ld (hl),a
        or a
        jr z,.keys
        ld a,b
        or a
        call z,pause
.keys:
        ; tick?  (every frame in turbo)
        ld a,(turbo)
        or a
        jr z,.tq
        call game_tick
        jr .norend
.tq:    ld a,(fieldcnt)
        ld hl,tick_last
        sub (hl)
        ld hl,speed
        cp (hl)
        jr c,.notick
        cp 16
        jr c,.inc                   ; far behind (a pause): resync
        ld a,(fieldcnt)
        ld (tick_last),a
        jr .t
.inc:   ld a,(tick_last)
        add a,(hl)
        ld (tick_last),a
.t:     call game_tick
.notick:
.after: ld a,(flash)
        or a
        jr z,.nf
        dec a
        ld (flash),a
.nf:    call render
.norend:
        ld a,(hud_dirty)
        or a
        call nz,hud_draw
        ; how is it going?
        ld a,(pl_exit)
        or a
        jp nz,.won
        ld a,(pl_dead)
        ld b,a
        ld a,(timeout)
        or b
        jr z,.alive
        ld hl,end_time
        inc (hl)
        ld a,(hl)
        cp 1
        call z,.dmsg
        ld a,(end_time)
        cp 120
        jr nc,.lose
        cp 30
        jr c,.alive
        ld a,(demo)
        or a
        jr nz,.lose
        ld a,(keys)
        and K_FIRE
        jr nz,.lose
.alive: ld a,(demo)
        or a
        jp z,.loop
        ld hl,(demo_ticks)
        ld de,DEMO_TICKS
        or a
        sbc hl,de
        jp c,.loop
.lose:  call cover
        ld a,1
        ld (cave_result),a
        ret
.dmsg:  ld a,(timeout)
        or a
        ret nz                      ; the clock already said so
        ld a,(demo)
        or a
        ret nz
        ld hl,txt_pressfire
        ld a,WHITE*16
        jp msg_show
.won:   ; time bonus
        ld hl,txt_cleared
        ld a,YELLOW*16
        call msg_show
        ld a,(demo)
        or a
        jr nz,.nob
        ld hl,SONG_CLEAR
        call mus_play
.bon:   ld a,(ctime)
        or a
        jr z,.bdone
        dec a
        ld (ctime),a
        ld a,(level)
        inc a
        call add_points
        call hud_draw
        call wait_field
        ld hl,anim
        inc (hl)
        call render
        ld a,(ctime)
        and 1
        jr nz,.bon
        ld hl,SFX_BONUS
        ld a,1
        call sfx
        jr .bon
.bdone: ld a,25
        call wait_fields
.nob:   call cover
        call mus_stop
        xor a
        ld (cave_result),a
        ret


msg_show_none:
        ld hl,0
        jp msg_show

; ---------------------------------------------------------------------
; game_tick: one physics step
; ---------------------------------------------------------------------
game_tick:
        call tick_input
tick_hook:                          ; (the test harness feeds tick_dir here)
        ld b,a
        ld a,(turbo)
        or a
        ld a,b
        jr z,.k
        ld a,(tick_dir)
.k:     ld (tick_keys),a
        ld a,(inbox_time)
        or a
        jr z,.ib
        dec a
        ld (inbox_time),a
.ib:    ld hl,(demo_ticks)
        inc hl
        ld (demo_ticks),hl
        call cave_scan
        ld hl,ticks
        inc (hl)
        jr nz,clock
        inc hl
        inc (hl)
                                    ; fall into the clock

; ---------------------------------------------------------------------
; clock: every tick; a cave second is tps ticks - time, magic wall, amoeba
; ---------------------------------------------------------------------
clock:
        ld a,(inbox_time)
        ld b,a
        ld a,(pl_frozen)
        or b
        ld b,a
        ld a,(pl_dead)
        or b
        ret nz                      ; stopped: hold the clock
        ld hl,sec_ctr
        dec (hl)
        ret nz
        ld a,(tps)
        ld (hl),a
        ld a,(magic_state)
        cp 1
        jr nz,.nm
        ld hl,magic_time
        dec (hl)
        jr nz,.nm
        ld a,2
        ld (magic_state),a
.nm:    ld a,(amoeba_slow)
        or a
        jr z,.na
        dec a
        ld (amoeba_slow),a
        jr nz,.na
        ld a,1
        ld (amoeba_fast),a
.na:    ld a,1
        ld (hud_dirty),a
        ld hl,ctime
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ld a,(hl)
        or a
        jr z,.out
        cp 10
        ret nc
        ld hl,SFX_TICK
        ld a,3
        jp sfx
.out:   ld a,1
        ld (pl_frozen),a
        ld (timeout),a
        ld hl,SFX_TIMEOUT
        ld a,6
        call sfx
        ld hl,txt_timeout
        ld a,RED*16
        jp msg_show

; ---------------------------------------------------------------------
; pause: CR again to go on, BREAK quits
; ---------------------------------------------------------------------
pause:
        call sfx_stop
        ld hl,txt_paused
        ld a,WHITE*16
        call msg_show
.rel:   call wait_field
        call read_keys
        ld a,(key_pause)
        or a
        jr nz,.rel
.w:     call wait_field
        call read_keys
        ld a,(key_quit)
        or a
        jr nz,.q
        ld a,(key_pause)
        or a
        jr z,.w
        ld a,1
        ld (pause_prev),a
        ld a,(fieldcnt)
        ld (tick_last),a
        ld (sec_last),a
        ld hl,0
        jp msg_show
.q:     ld a,1
        ld (key_quit),a
        ld hl,0
        jp msg_show

; ---------------------------------------------------------------------
; cave_intro: the cave's title card
; ---------------------------------------------------------------------
cave_intro:
        call cave_load              ; for the header values
        ld a,BLUE                   ; dark blue background
        call cls
        ld b,4
        ld c,17
        ld a,BLUE
        call clear_rows
        ; which wing of the mountain (its theme), or a bonus cave
        ld hl,(cave_hdr)
        ld de,CH_THEME
        add hl,de
        ld a,(hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,wing_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,1
        ld a,CYAN*16+BLUE
        call print_centre
        ; big "CAVE X" in the bold second-bank letters
        ld de,VRAM+6*40+17
        call is_bonus
        ld hl,txt_cave_big
        jr z,.cb
        ld de,VRAM+6*40+16
        ld hl,txt_bonus_big
.cb:    ld c,YELLOW*16+BLUE+80h
        call print
        ld a,(cave_no)
        call letter_of
        ld c,WHITE*16+BLUE+80h
        call putc
        ; name and hint
        ld hl,(cave_hdr)
        ld de,CH_NAME
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld c,9
        ld a,WHITE*16+BLUE
        call print_centre
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld c,11
        ld a,CYAN*16+BLUE
        call print_centre
        ; collect / time
        ld de,VRAM+14*40+10
        ld hl,txt_collect
        ld c,WHITE*16+BLUE
        call print
        ld a,(need)
        ld c,YELLOW*16+BLUE
        call print_dec2
        ld hl,txt_diamonds
        ld c,WHITE*16+BLUE
        call print
        ld de,VRAM+16*40+10
        ld hl,txt_within
        call print
        ld a,(ctime)
        ld c,YELLOW*16+BLUE
        call print_dec3
        ld hl,txt_seconds
        ld c,WHITE*16+BLUE
        call print
        ; lives / level
        ld de,VRAM+19*40+12
        ld hl,txt_lives
        ld c,GREEN*16+BLUE
        call print
        ld a,(lives)
        add a,20h
        call putc
        inc de
        ld hl,txt_level
        call print
        ld a,(level)
        add a,21h
        call putc
        ; a row of diamonds top and bottom
        ld de,VRAM+3*40+4
        ld b,32
        ld c,CYAN*16+BLUE
.d1:    ld a,44h
        call putc
        inc de
        djnz .d1
        ld de,VRAM+21*40+4
        ld b,32
.d2:    ld a,44h
        call putc
        inc de
        djnz .d2
        ld a,(demo)
        or a
        jr z,.nd
        ld hl,txt_demo
        ld c,23
        ld a,MAGENTA*16+BLUE
        call print_centre
.nd:    ld hl,(cave_hdr)            ; the wing's own jingle
        ld de,CH_THEME
        add hl,de
        ld a,(hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,WINGSONGS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call mus_play
        call fe_reset
        ld b,125                    ; 2.5 s or a key
.w:     push bc
        call wait_field
        call read_keys
        ld c,a
        ld a,(demo)
        or a
        jr z,.hu
        call anykey
        jr z,.nx
        ld a,1
        ld (demo_abort),a
        ld (quit),a
        pop bc
        jp mus_stop
.hu:    ld a,(key_quit)
        or a
        jr z,.nb
        ld a,1
        ld (quit),a
        pop bc
        jp mus_stop
.nb:    ld a,(fe_prev)
        cpl
        and c
        and K_FIRE
        ld a,c
        ld (fe_prev),a
        jr z,.nx
        pop bc
        jr .go
.nx:    pop bc
        djnz .w
.go:    jp mus_stop

; ---------------------------------------------------------------------
; game over
; ---------------------------------------------------------------------
game_over:
        call sfx_stop
        ld a,BLACK
        call cls
        ld hl,txt_gameover
        ld c,10
        ld a,RED*16+80h
        call print_centre
        ld de,VRAM+13*40+12
        ld hl,txt_finalscore
        ld c,WHITE*16
        call print
        ld hl,score+2
        ld b,3
        ld c,YELLOW*16
        call print_bcd
        ld hl,SONG_GAMEOVER
        call mus_play
        ld b,200
.w:     push bc
        call wait_field
        call mus_playing
        pop bc
        or a
        jr z,.d
        djnz .w
.d:     ld a,50
        call wait_fields
        jp mus_stop
