; =====================================================================
;  ROBOGEDDON 2085 - Sharp MZ-700 version
;  64K MZ-700 (PAL, stock European CG-ROM, no PCG). Loads and runs at 1200h.
;
;  A twin-stick arena shooter, played on the keyboard: W A S D to move,
;  I J K L (or the cursor keys) to fire in 8 directions.
;  Every sprite is one character cell drawn with the ROM's own graphics.
;  Each tick (50 Hz) the game builds a work screen (background + sprites)
;  in RAM and, in vertical blank, writes only the cells that changed.
;
;  ViBED by BPM 2026.  Based on Robogeddon 2085 for the VZ200/VZ300.
; =====================================================================
        DEVICE NOSLOT64K

        include "defs.inc"

        org 1200h

start:
        di
        ld sp,STACK
        call init_hw
        call detect_vblank
        ld a,r                  ; a little entropy for the generator
        ld (seed),a
        ld hl,LISTA
        ld (curlist),hl
        ld (curptr),hl
        ld hl,LISTB
        ld (prevlist),hl
        ld a,1
        ld (sndon),a
        call init_hiscores

; ---------------------------------------------------------------------
; attract sequence -> game (or demo) -> attract ...
title:
        xor a
        ld (page),a
attract:
        ld sp,STACK
        xor a
        ld (demo),a
        call front_end          ; A = 0: start a game, 1: run the demo
        or a
        jp nz,run_demo
        call new_game

main_loop:
        call wait_vblank
        call flush
        call snd_tick
        call read_keys
        call demo_ctl
        call check_pause
        call game_tick
        ld hl,framecnt
        inc (hl)
        jr main_loop

jp_hl:  jp (hl)

        include "screen.asm"
        include "keys.asm"
        include "sound.asm"
        include "game.asm"
        include "objects.asm"
        include "player.asm"
        include "particles.asm"
        include "demo.asm"
        include "fx.asm"
        include "front.asm"
        include "data.asm"

        include "vars.inc"
end_of_program:
        assert end_of_program <= OLCH

        SAVEBIN "../build/robogedn.bin", start, end_of_program-start
