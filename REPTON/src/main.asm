; =====================================================================
;  SKINK  -  an underground exploration and puzzle adventure for the
;            Sharp MZ-700 (64K, PAL, European CG-ROM, no PCG).
;            Loads at 1200h from tape / UniCMT.            ViBED by BPM
; =====================================================================
        DEVICE NOSLOT64K

; ---------------------------------------------------------------- hardware
VRAM            equ 0D000h
ARAM            equ 0D800h
KEYPA           equ 0E000h          ; 8255 port A: keyboard row select
KEYPB           equ 0E001h          ; 8255 port B: keyboard columns (active low)
KEYPC           equ 0E002h          ; 8255 port C: bit 7 = /VBLK
CTR0            equ 0E004h          ; 8253 counter 0 (sound)
CTRL            equ 0E007h          ; 8253 control
SNDGATE         equ 0E008h          ; sound gate

; ---------------------------------------------------------------- world geometry
RW              equ 32              ; region width (cells / tiles)
RH              equ 24              ; region height
RSZ             equ RW*RH           ; 768 bytes per region
VIEWW           equ 20              ; tiles on screen
VIEWH           equ 12
VIEWTOP         equ 1               ; first screen row of the view

; ---------------------------------------------------------------- memory
SAVEVARS        equ 8E00h           ; game state (256 bytes) ...
WORLD           equ 8F00h           ; ... followed by every region
WORLD_END       equ WORLD+NREG*RSZ
SNAP            equ 0C600h          ; the current region as it was on entry
SHADOW          equ 0C900h          ; look index of every tile on screen (20 x 12)
CUR             equ 0CA00h          ; this frame's look index per element (64)
RCOUNT          equ 0CA40h          ; per region: gems, pieces, crowns, monsters
STACKTOP        equ 0CFF0h
VARBASE         equ (end_of_program+255) & 0FF00h

FRAMEF          equ 2               ; fields per display frame (25 fps)
TICKF           equ 3               ; frames per game tick (8.3 ticks per second)

; input bits
K_UP            equ 01h
K_DOWN          equ 02h
K_LEFT          equ 04h
K_RIGHT         equ 08h
K_FIRE          equ 10h
K_DIRS          equ 0Fh
B_UP            equ 0
B_DOWN          equ 1
B_LEFT          equ 2
B_RIGHT         equ 3
B_FIRE          equ 4

; colours
BLACK           equ 0
BLUE            equ 1
RED             equ 2
MAGENTA         equ 3
GREEN           equ 4
CYAN            equ 5
YELLOW          equ 6
WHITE           equ 7

        org 1200h
start:
        di
        ld sp,STACKTOP
        im 1
        xor a
        ld (SNDGATE),a
        ld a,36h                    ; counter 0: LSB/MSB, mode 3 square wave
        ld (CTRL),a
        call detect_vblank
        call init_once
attract:
        call title_screen           ; NZ = start a game
        jr nz,.play
        call story_page
        jr nz,.play
        call guide_page
        jr nz,.play
        call records_page
        jr nz,.play
        call demo_game
        ld a,(demo_abort)           ; a key pressed during the demo:
        or a                        ; back to the title
        call nz,wait_release
        jr attract
.play:  call game
        jr attract

init_once:
        ld hl,vars_start            ; clear the variables
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,1234h
        ld (seed),hl
        call records_init
        ret

        include "sys.asm"
        include "sound.asm"
        include "world.asm"
        include "physics.asm"
        include "player.asm"
        include "render.asm"
        include "game.asm"
        include "status.asm"
        include "screens.asm"
        include "text.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_tables.inc"
        include "../build/gen_looks.inc"
        include "../build/gen_world.inc"
        include "../build/gen_music.inc"
        include "../build/gen_logo.inc"
        include "../build/gen_demo.inc"

end_of_program:
        ASSERT WORLD_END <= SNAP
        ASSERT vars_end <= SAVEVARS

        SAVEBIN "../build/skink.bin", start, end_of_program-start

        include "vars.asm"
