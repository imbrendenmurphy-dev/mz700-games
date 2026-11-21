; =====================================================================
;  KIKO AND THE COLOUR THIEF
;  a mascot platformer for the Sharp MZ-700 (64K, PAL, European CG-ROM,
;  no PCG).  Loads at 1200h from tape / UniCMT.          ViBED by BPM
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
; The playfield is screen rows 2-24 (40 x 23 cells).  Every per-cell
; buffer uses the same low address bits as VRAM row 2 (xx50h), so a cell's
; addresses in the different buffers differ only in the high byte:
;   OVC  C050h  overlay chars  (what should be on screen)
;   SHC  C450h  shadow chars   (what is on screen)      OVC + 0400h  set 2,h
;   OVA  C850h  overlay attrs                           OVC + 0800h  set 3,h
;   SHA  CC50h  shadow attrs                            OVA + 0400h  set 2,h
;   VRAM D050h / D850h                                  OV? + 1000h  set 4,h
;   ROOMT B050h tile ids                                OVC - 1000h
ROOMT           equ 0B050h
LISTA           equ 0B400h          ; cell lists, 256 entries each
LISTB           equ 0B600h
LISTEND         equ 0B800h
STACKTOP        equ 0C000h          ; stack grows down from here (B800-BFFF)
OVC             equ 0C050h
SHC             equ 0C450h
OVA             equ 0C850h
SHA             equ 0CC50h
PLAYV           equ 0D050h          ; VRAM of playfield cell 0
ROOMW           equ 40
ROOMH           equ 23
NCELLS          equ ROOMW*ROOMH
VARBASE         equ (end_of_program+255) & 0FF00h

FRAMEF          equ 1               ; fields per game frame (50 fps)
REMAP_ID        equ (high REMAP)+4  ; recolour table that changes nothing

; input bits
K_UP            equ 01h
K_DOWN          equ 02h
K_LEFT          equ 04h
K_RIGHT         equ 08h
K_JUMP          equ 10h
K_TONGUE        equ 20h
K_SWAP          equ 40h
K_PAUSE         equ 80h
K_GAME          equ 7Fh
K_DIRS          equ 0Fh
K_ACTS          equ 70h

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
        call clear_vars
        call detect_vblank
        call init_once
attract:
        ld a,1
        ld (fe_jok),a               ; J opens the joystick page
        call title_screen           ; NZ = start a game
        jr nz,.play
        call story_page
        jr nz,.play
        call howto_page
        jr nz,.play
        call hiscore_page
        jr nz,.play
        xor a
        ld (fe_jok),a
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
        ld (fe_jok),a
        ld a,(fe_joy)
        or a
        jr nz,.joy
        ld (demo),a
        call game
        call hiscore_entry
        jr attract
.joy:   xor a
        ld (fe_joy),a
        call joy_screen
        jr attract

clear_vars:
        ld hl,VARBASE
        ld de,VARBASE+1
        ld bc,vars_end-VARBASE-1
        ld (hl),0
        ldir
        ret

init_once:
        ld hl,0ACE1h
        ld (seed),hl
        call hiscore_init
        ret

        include "sys.asm"
        include "joy.asm"
        include "sound.asm"
        include "render.asm"
        include "room.asm"
        include "hero.asm"
        include "objects.asm"
        include "boss.asm"
        include "pilot.asm"
        include "game.asm"
        include "screens.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_tables.inc"
        include "../build/gen_tiles.inc"
        include "../build/gen_remap.inc"
        include "../build/gen_sprites.inc"
        include "../build/gen_music.inc"
        include "../build/gen_screens.inc"
        include "../build/gen_rooms.inc"

end_of_program:
        ASSERT end_of_program <= VARBASE
        ASSERT vars_end <= ROOMT

        SAVEBIN "../build/kiko.bin", start, end_of_program-start

        include "vars.asm"
