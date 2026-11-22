; =====================================================================
;  REDLINE - a road racer for the Sharp MZ-700
;  64K MZ-700 (PAL, stock European CG-ROM, no PCG).  Loads and runs at 1200h.
;
;  A pseudo-3D road built from half-block characters (a 40 x 32 colour
;  picture in the attributes), hills and bends, roadside scenery and
;  traffic, five stages on a branching route against the clock.
;
;  ViBED by BPM 2026.
; =====================================================================
        DEVICE NOSLOT64K

        include "defs.inc"

        org 1200h

start:
        di
        ld sp,STACK
        call init_hw
        call detect_vblank
        call snd_init
        call make_tables
        call sq_init
        call edt_init
        ld a,r
        ld (seed),a
        call init_hiscores

attract:
        ld sp,STACK
        xor a
        ld (inrace),a
        ld (gameend),a
        ld (quitflag),a
        ld (demoquit),a
        call front_end          ; A = 0 a race, 1 the demo, 2 the title
        cp 2
        jp z,title_start
        ld (demo),a
        or a
        jp nz,demo_start
race:   xor a
        ld (demo),a
        ld (titlemode),a
        ld (goalhit),a
        ld hl,0
        ld (routebits),hl
        call mus_stop
        ld a,1
        ld (inrace),a
        ld (eng_on),a
        call race_screen
        call new_race
        call race_music
        jr main_loop
demo_start:
        ld hl,45*50/3           ; 45 seconds or so
        ld (demotm),hl
        xor a
        ld (eng_on),a
        call race_screen
        call rand_course
        ld a,WHITE*16+MAGENTA
        ld (msgcol),a
        ld hl,txt_demo
        xor a
        call hud_message
        ld a,255
        ld (msgtime),a
        jr main_loop
title_start:
        xor a
        ld (eng_on),a
        ld a,1
        ld (demo),a
        call rand_course
        call title_setup
        ld a,GS_RACE            ; (no countdown)
        ld (gstate),a
        ld hl,1100
        ld (speed),hl

main_loop:
        call wait_frame
        ; --- at the blank: the screen
        call road_blit
        call car_chars
        ld a,(titlemode)
        or a
        jr nz,.tf
        call sky_update
        call hud_update
        jr .k
.tf:    call title_frame
.k:     ; --- input, then the world for each field that passed
        call read_keys
        call pause_check
        call demo_ctl
        call demo_timer
        ld a,(dt)
        ld b,a
.f:     push bc
        call game_field
        call countdown
        call field_misc
        pop bc
        djnz .f
        call traffic
        ld a,(gameend)
        or a
        jr nz,.end
        ; --- the next picture
        call road_draw
        call spr_draw
        call car_draw
        call engine
        ld hl,framecnt
        inc (hl)
        jr main_loop
.end:   call sfx_stop
        call out_off
        xor a
        ld (inrace),a
        ld (gameend),a
        ld a,(titlemode)
        or a
        jr z,.nt
        xor a
        ld (titlemode),a
        ld (demo),a
        ld a,(titlego)          ; SPACE on the title: race
        or a
        jp z,race
        jp attract
.nt:    ld a,(demo)
        or a
        jr z,.over
        xor a
        ld (demo),a
        ld a,(demoquit)
        or a
        jp nz,race
        jp attract
.over:  ld a,(quitflag)
        or a
        jr nz,.q
        ld a,(goalhit)
        or a
        call nz,goal_page
        call mus_stop
        call check_hiscore
        ld a,PG_HIGH
        ld (page),a
.q:     call mus_stop
        ld hl,TRK_TITLE
        call play_tune
        jp attract

txt_demo: db "DEMO - SPACE TO RACE",0

; the demo and the title: a random course, already moving
rand_course:
        call new_race
        ld a,15
        call rand_n
        call load_stage
        ld a,GS_RACE
        ld (gstate),a
        ld hl,900
        ld (speed),hl
        ld a,10
        ld (spawnt),a
        ret

; the demo ends by itself after a while
demo_timer:
        ld a,(demo)
        or a
        ret z
        ld a,(titlemode)
        or a
        ret nz
        ld hl,(demotm)
        dec hl
        ld (demotm),hl
        ld a,h
        or l
        ret nz
        ld a,1
        ld (gameend),a
        ret

; the playing screen
race_screen:
        call cls
        call road_chars
        call car_reset
        call hud_init
        xor a
        ld (msgtime),a
        ret

; things that tick every field
field_misc:
        ld a,(shake)
        or a
        jr z,.s
        dec a
        ld (shake),a
.s:     ld a,(combot)
        or a
        jr z,.c
        dec a
        ld (combot),a
        jr nz,.c
        ld (combo),a            ; (A = 0) the combo runs out
.c:     ; the sky slides on the bends: skyx -= curve * speed hi * 4
        call cur_seg
        ld de,TRK_CURV
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld c,a
        ld a,(speed+1)
        or a
        ret z
        ld l,a
        ld a,c
        bit 7,a
        jr z,.p
        neg
.p:     ld e,a
        call mul8               ; HL = |curve| * speed hi
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(skyx)
        bit 7,c
        jr nz,.n
        or a
        sbc hl,de
        ld (skyx),hl
        ret
.n:     add hl,de
        ld (skyx),hl
        ret

; clear the screen to black
cls:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,1000-1
        ld (hl),0
        ldir
        ld hl,CRAM
        ld de,CRAM+1
        ld bc,1000-1
        ld (hl),70h
        ldir
        ret

        include "sys.asm"
        include "tables.asm"
        include "road.asm"
        include "sprite.asm"
        include "car.asm"
        include "sky.asm"
        include "hud.asm"
        include "track.asm"
        include "stage.asm"
        include "game.asm"
        include "front.asm"
        include "demo.asm"
        include "sound.asm"
        include "joy.asm"
        include "../build/gen_tab.inc"
        include "../build/gen_blit.inc"
        include "../build/gen_spr.inc"
        include "../build/gen_track.inc"

        include "vars.asm"
end_of_program:
        assert end_of_program <= 0A000h

        SAVEBIN "../build/redline.bin", start, end_of_program-start
