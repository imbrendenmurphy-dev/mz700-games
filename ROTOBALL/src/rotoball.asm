; ======================================================================
;  ROTOBALL - Sharp MZ-700 (64K, PAL, stock European CG-ROM), loads at 1200h
;
;  You rotate the maze; gravity always pulls down the screen. Collect every
;  gem to open the exit, bounce on crawlers, avoid mines, use bombs (SPACE).
;  The maze is drawn with the dotted 2x2 block characters F0h-FFh, so the
;  25x25 character view is a 50x50 block image redrawn at every angle.
; ======================================================================

    include "../build/gen_const.inc"
    include "defs.inc"

    org 1200h

start:
    di
    ld sp,STACK
    call init_hw
    call init_lists
    call init_screen

new_game:
    ld sp,STACK
    xor a
    ld (level),a
    ld (score),a
    ld (score+1),a
    ld (score+2),a
    ld (bombs),a
    ld a,3
    ld (lives),a
    call start_level

frame:
    call setup_render
    call render
    call draw_overlay_chars
    call wait_vblank
    call blit
    call colours
    call overlay_colours
    call snd_tick
    call read_keys
    call game_logic
    call build_overlay
    call timing
    call hud
    ld hl,framecnt
    inc (hl)
    jp frame

    include "render.asm"
    include "game.asm"
    include "objects.asm"
    include "physics.asm"
    include "sound.asm"
    include "hud.asm"

; ----------------------------------------------------------------------
; data
    include "../build/gen_sfx.inc"
    include "../build/gen_levels.inc"
    include "vars.inc"
    include "../build/gen_tables.inc"
end_of_code:
    assert end_of_code < MAP_PAGE*256
