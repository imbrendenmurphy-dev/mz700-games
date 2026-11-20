; =====================================================================
;  GHOST HUNTER 2 - "The Boo-quel"  for the Sharp MZ-700
;  (64K, PAL, European CG-ROM, no PCG).  Loads at 1200h from tape or
;  UniCMT.  Port of the VZ300 game.               ViBED by BPM 2026
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

; ---------------------------------------------------------------- memory
BGCH            equ 09000h          ; background chars  (VRAM addr with bit 14 clear)
BGAT            equ 09800h          ; background attrs
GRID            equ 0A000h          ; maze codes, 21 rows of 64 bytes
CLS             equ 0A600h          ; cell class per grid char
LOOK            equ 0AC00h          ; wall glyph per grid char
STACKTOP        equ 0CFF0h
VARBASE         equ (end_of_program+255) & 0FF00h

OVMAX           equ 56              ; overlay cells per frame
DIRTYMAX        equ 40

FRAMEF          equ 1               ; fields per game frame (50 fps)

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
ALT             equ 80h             ; attribute bit: second character set

; grid codes
C_EMPTY         equ 0
C_PELLET        equ 1
C_ENERG         equ 2
C_WALL          equ 3
C_DOOR          equ 4
C_HOUSE         equ 5
C_TELE          equ 6
C_TUNNEL        equ 7
CL_INNER        equ 8               ; class of wall interiors

; grid geometry
GW              equ 41
GH              equ 21
DOORX           equ 20
EXITY           equ 6
HOUSEY          equ 10
STARTX          equ 20
STARTY          equ 14

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
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,1234h
        ld (seed),hl
        ld hl,hitab_init
        ld de,HITAB
        ld bc,30
        ldir
        ld hl,HITAB
        ld de,hiscore
        ld bc,3
        ldir
        call ovl_init
        jp attract

hitab_init:
        db 01h,00h,00h,"BPM"
        db 00h,80h,00h,"DUB"
        db 00h,60h,00h,"MAC"
        db 00h,40h,00h,"MZ7"
        db 00h,20h,00h,"BOO"

        include "sys.asm"
        include "sound.asm"
        include "render.asm"
        include "maze.asm"
        include "actors.asm"
        include "game.asm"
        include "pilot.asm"
        include "screens.asm"
        include "cutscene.asm"
        include "text.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_tables.inc"
        include "../build/gen_mazes.inc"
        include "../build/gen_music.inc"
        include "../build/gen_art.inc"

end_of_program:
        ASSERT end_of_program <= VARBASE

        SAVEBIN "../build/ghost2.bin", start, end_of_program-start

        include "vars.asm"
        ASSERT vars_end <= BGCH
