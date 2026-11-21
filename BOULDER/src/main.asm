; =====================================================================
;  ROCKFALL  -  a cave digging game for the Sharp MZ-700 (64K, PAL,
;               European CG-ROM, no PCG).  Loads at 1200h from tape /
;               UniCMT.                                    ViBED by BPM
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
JOYPORT         equ 0E008h          ; read: bits 1-2 = joystick 1 X / Y pulses

; ---------------------------------------------------------------- memory
CAVEW           equ 64              ; map row stride: caves are up to 64 x 32
CAVEH           equ 32
CAVESZ          equ CAVEW*CAVEH     ; 2048 cells
CAVE            equ 0B800h          ; the map (2K aligned: x = low 6 bits)
VIEWW           equ 40              ; the window on screen rows 2-23
VIEWH           equ 22
VIEWSZ          equ VIEWW*VIEWH
SHADOW          equ 0C050h          ; display index on screen; VRAM address = SHADOW + 1000h
QUEUE           equ CAVE            ; (end of the variables)
STACKTOP        equ 0CFF0h
VARBASE         equ (end_of_program+255) & 0FF00h

FRAMEF          equ 2               ; fields per display frame (25 fps)

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
        call guide_page
        jr nz,.play
        call hiscore_page
        jr nz,.play
        ld a,1
        ld (demo),a
        call game
        xor a
        ld (demo),a
        ld a,(demo_abort)           ; a key pressed during the demo:
        or a                        ; back to the title
        call nz,wait_release
        jr attract
.play:
        xor a
        ld (demo),a
        call game
        call hiscore_entry
        jr attract

init_once:
        ld hl,vars_start            ; clear the variables
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,1234h
        ld (seed),hl
        call hiscore_init
        ret

        include "sys.asm"
        include "sound.asm"
        include "cave.asm"
        include "player.asm"
        include "render.asm"
        include "game.asm"
        include "screens.asm"
        include "text.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_tables.inc"
        include "../build/gen_looks.inc"
        include "../build/gen_caves.inc"
        include "../build/gen_music.inc"
        include "../build/gen_logo.inc"

end_of_program:
        ASSERT end_of_program <= VARBASE

        SAVEBIN "../build/rockfall.bin", start, end_of_program-start

        include "vars.asm"
