; =====================================================================
;  NOVA STORM - a vertically scrolling shoot-'em-up for the Sharp MZ-700
;  64K MZ-700 (PAL, stock European CG-ROM, no PCG).  Loads and runs at 1200h.
;
;  Five sectors of the Storm Fleet, each with its warlord at the end.
;  Every sprite is built from the ROM's own characters.  The game runs
;  at 25 ticks a second: each tick builds a work screen in RAM (stars,
;  scrolling scenery, sprites) and at the next vertical blank writes only
;  the cells that changed.
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
        ld a,r
        ld (seed),a
        call init_hiscores
        call reset_lists
        ld a,40
        ld (starw),a
        call stars_init
        ld a,(startpage)
        ld (page),a

attract:
        ld sp,STACK
        xor a
        ld (demo),a
        ld (gameend),a
        ld (quitflag),a
        ld (demoquit),a
        call front_end          ; A = 0: a game, 1: the demo
        or a
        jr z,.game
        ; the demo: the computer plays a stage, silently
        ld a,1
        ld (demo),a
        call mus_stop
        call sfx_stop
        ld hl,1500              ; a minute at most
        ld (demotm),hl
        ld a,(framecnt)         ; a different stage each time (1-3)
        and 3
        cp 3
        jr c,.ds
        xor a
.ds:    inc a
        ld (startstage),a
.game:  ld a,PFW
        ld (starw),a
        call stars_init
        call new_game
        xor a
        ld (startstage),a

main_loop:
        call wait_tick
        call joy_sample1
        call flush
        call joy_sample2
        call read_keys
        call demo_ctl
        call check_keys
        ld a,(gameend)
        or a
        jr nz,.end
        call game_tick
        ld hl,framecnt
        inc (hl)
        jr main_loop

.end:   call mus_stop
        call sfx_stop
        ld a,40
        ld (starw),a
        call stars_init
        ld a,(demo)
        or a
        jr z,.over
        xor a
        ld (demo),a
        ld a,(demoquit)         ; SPACE in the demo: start a game
        or a
        jr z,.dnext
        xor a
        ld (page),a
        jr .newg
.dnext: call next_page          ; on to the high scores
        jp attract
.newg:  xor a
        ld (gameend),a
        ld (demoquit),a
        jp attract.game
.over:  ld a,(quitflag)
        or a
        jr nz,.title
        call check_hiscore
        ld a,PG_HIGH
        ld (page),a
        jp attract
.title: xor a
        ld (page),a
        jp attract

        include "sys.asm"
        include "screen.asm"
        include "scroll.asm"
        include "sound.asm"
        include "game.asm"
        include "player.asm"
        include "enemy.asm"
        include "boss.asm"
        include "fx.asm"
        include "demo.asm"
        include "front.asm"
        include "joy.asm"
        include "../build/gen_art.inc"
        include "../build/gen_logo.inc"
        include "../build/gen_stage.inc"

        include "vars.asm"
end_of_program:
        assert end_of_program <= SCNC

        SAVEBIN "../build/novastrm.bin", start, end_of_program-start
