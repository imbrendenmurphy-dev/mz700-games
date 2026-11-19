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
    out (0E0h),a        ; RAM instead of the monitor ROM at 0000h-0FFFh
    ld hl,reloc_src     ; title code lives there
    ld de,0
    ld bc,RELOC_LEN
    ldir
    call init_hw
    call init_lists
    xor a
    jp title

new_game:
    ld sp,STACK
    call init_screen
    ld a,(demo)
    or a
    jr z,.nd
    ld hl,txt_demo1     ; attract mode: replace the key help
    ld de,VRAM+21*40+HUD_X
    call print
    ld hl,txt_demo2
    ld de,VRAM+22*40+HUD_X
    call print
    ld hl,txt_demo3
    ld de,VRAM+23*40+HUD_X
    call print
.nd:
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
    ld a,(demo)
    or a
    jp z,frame
    ld hl,(demo_t)      ; attract mode runs for a limited time
    dec hl
    ld (demo_t),hl
    ld a,h
    or l
    jp nz,frame
    xor a
    jp title

    include "render.asm"
    include "game.asm"
    include "objects.asm"
    include "physics.asm"
    include "sound.asm"
    include "music.asm"
    include "hud.asm"

; ----------------------------------------------------------------------
; data
    include "../build/gen_sfx.inc"
    include "../build/gen_music.inc"
    include "../build/gen_levels.inc"
    include "../build/gen_demo.inc"
    include "../build/gen_logo.inc"
    include "titledata.asm"
    include "vars.inc"
    include "../build/gen_tables.inc"
end_of_code:
    assert end_of_code < MAP_PAGE*256

; ----------------------------------------------------------------------
; title code: stored here in the file, copied to 0000h at start-up
reloc_src:
    phase 0
reloc_start:
    include "title.asm"
reloc_end:
    dephase
RELOC_LEN = reloc_end-reloc_start
    assert RELOC_LEN <= 1000h
