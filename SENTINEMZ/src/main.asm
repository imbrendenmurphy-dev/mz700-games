; =====================================================================
;  Z E N I T H   for the Sharp MZ-700 (64K, PAL, European CG-ROM)
;  An original landscape-climbing game: absorb, build, climb above the
;  Lantern and put its light out.
;
;  The view is ray-cast column by column into an 80 x 42 pixel buffer;
;  each character cell shows 2 x 2 pixels through the CG-ROM's half and
;  diagonal blocks.  Loads at 1200h from tape / UniCMT.
; =====================================================================
        DEVICE NOSLOT64K

; ---------------------------------------------------------------- hardware
VRAM            equ 0D000h
ARAM            equ 0D800h
KEYPA           equ 0E000h
KEYPB           equ 0E001h
KEYPC           equ 0E002h
CTR0            equ 0E004h
CTRL            equ 0E007h
SNDGATE         equ 0E008h

; ---------------------------------------------------------------- memory
PIX             equ 05800h          ; 80 columns x 64 (42 used): colour per pixel
ZB              equ PIX+1400h       ; same layout: depth (step index / 7E sea / 7F sky / 80+n object n)
FMAP            equ 08000h          ; 128 x 128 sub-cells: f << 2 | shade
OBJ             equ 0C000h          ; 32 x 32 tiles: bits 0-2 top object, 4-6 cairns
TILEF           equ 0C400h          ; 32 x 32 tiles: 0-2 sector from lantern, 3 lantern sees,
                                    ;   4 flat, 7 visible in the current view
VARBASE         equ 0C800h
STACKTOP        equ 0CFF0h
; generator scratch (inside PIX, before the first render)
GRID            equ PIX             ; 9 x 9 random grid
HRAW            equ PIX+100h        ; 33 x 33 smooth noise
CORN            equ PIX+600h        ; 33 x 33 levels
CORN2           equ PIX+0B00h       ; after the plateau filter

; ---------------------------------------------------------------- screen
VIEW_W          equ 80
VIEW_H          equ 42
VIEW_ROWS       equ 21
HUD_ROW         equ 21
NSTEP           equ 102
FRAMEF          equ 1
EYE             equ 6               ; eye above the ground (f units; 1 level = 4)
CAIRN_F         equ 4               ; a cairn is one level tall
LAMP_F          equ 15              ; lantern lamp above its tile

; colours
BLACK           equ 0
BLUE            equ 1
RED             equ 2
MAGENTA         equ 3
GREEN           equ 4
CYAN            equ 5
YELLOW          equ 6
WHITE           equ 7
SKY             equ BLACK
SEA             equ BLUE

; objects (low 3 bits of OBJ)
O_NONE          equ 0
O_SHARD         equ 1
O_SHELL         equ 2
O_LANTERN       equ 3
O_WISP          equ 4

; input bits (read_keys)
K_LEFT          equ 01h
K_RIGHT         equ 02h
K_UP            equ 04h
K_DOWN          equ 08h
K_FIRE          equ 10h
K_DIRS          equ 0Fh
B_LEFT          equ 0
B_RIGHT         equ 1
B_UP            equ 2
B_DOWN          equ 3
B_FIRE          equ 4

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
        ld hl,1
        ld (seed),hl
        call hiscore_init
        ld a,1
        ld (best_island),a
.attract:
        call front_end              ; returns when the player starts a game
        call new_game
.island:
        call play_island            ; A: 0 lost, 1 cleared, 2 quit
        or a
        jr z,.dead
        cp 2
        jr z,.attract
        call island_cleared
        jr .island
.dead:  call game_over
        jr .attract

new_game:
        ld a,(start_island)
        ld (island),a
        ld a,10
        ld (energy),a
        xor a
        ld (autoplay),a
        ld hl,0
        ld (score),hl
        ret

        include "sys.asm"
        include "sound.asm"
        include "math.asm"
        include "gen.asm"
        include "render.asm"
        include "game.asm"
        include "ai.asm"
        include "hud.asm"
        include "screens.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_tables.inc"
        include "../build/gen_sprites.inc"
        include "../build/gen_music.inc"

end_of_program:
        ASSERT end_of_program <= PIX

        SAVEBIN "../build/zenith.bin", start, end_of_program-start

        include "vars.asm"
