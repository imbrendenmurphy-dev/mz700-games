; =====================================================================
;  C I R C U S   2   for the Sharp MZ-700 (64K, PAL, European CG-ROM)
;  A port of the VZ300 game: seesaw, clowns and balloons, nine acts,
;  bonus rounds, power-ups, monkey, ring of fire, attract mode.
;  Loads at 1200h from tape / UniCMT.                  ViBED by BPM 2026
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
; the play screen is composed in RAM: background chars/attrs, what is on
; the screen now (shadow), and an "object here" map.  All five arrays
; share the same low address bits (1K apart), so H selects the array.
BGC             equ 0A000h          ; background chars   (1000)
BGA             equ 0A400h          ; background attrs
SHC             equ 0A800h          ; shadow of VRAM chars
SHA             equ 0AC00h          ; shadow of VRAM attrs
OCC             equ 0B000h          ; object entry index per cell (0 = none)
NLO             equ 0B400h          ; this frame's object cells: address low,
NHI             equ 0B500h          ;   address high (BGC-based),
NCH             equ 0B600h          ;   char,
NAT             equ 0B700h          ;   attr (bit 3 set = own background)
OLO             equ 0B800h          ; last frame's object cells
OHI             equ 0B900h
ROWDIRTY        equ 0BA00h          ; 25 flags: recompose this row
DLO             equ 0BB00h          ; single background cells to recompose
DHI             equ 0BC00h
STACKTOP        equ 0CFF0h
VARBASE         equ (end_of_program+255) & 0FF00h
MAXENT          equ 250

FRAMEF          equ 2               ; fields per game update (25 per second)

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

; colours
BLACK           equ 0
BLUE            equ 1
RED             equ 2
MAGENTA         equ 3
GREEN           equ 4
CYAN            equ 5
YELLOW          equ 6
WHITE           equ 7
OWNBG           equ 08h             ; object attr flag: keep its own background

; ---------------------------------------------------------------- play-field geometry
; x positions are in units of 2 pixels (a cell is 4 units, the screen 160),
; y positions in pixels (a cell is 8).  Both are 8.8 fixed point.
CANOPY_ROW      equ 0
CEIL_Y          equ 8
BROW0           equ 2               ; balloon rows at char rows 2, 5, 8, 11
MONKEY_ROW      equ 13
ROPE_ROW        equ 14
TOWER_Y         equ 112             ; tower clowns stand on rows 14-15
LEDGE_ROW       equ 16
HOOP_ROW        equ 16
HOOP_CY         equ 132             ; the hoop line (clown centre y)
SEAT_Y          equ 144             ; seated clown: rows 18-19
PIVOT_ROW       equ 20              ; plank on rows 19-20, pivot on row 20
FLOOR_ROW       equ 21
LIGHTS_ROW      equ 22
HUD_ROW         equ 23
BAR_ROW         equ 24
XMIN            equ 6               ; clown centre limits (cells 1..38)
XMAX            equ 153

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
        ld a,(demo_act)             ; a demo of a different act each lap
        add a,2
        cp NACTS
        jr c,$+4
        sub NACTS
        ld (demo_act),a
        xor a
        ld (demo_key),a
        ld a,1
        call game_main
        ld a,(demo_key)
        or a
        jr nz,.play
        call howto_screen
        jr nz,.play
        call goodies_screen
        jr nz,.play
        call hiscore_screen
        jr nz,.play
        call preview_screen
        jr nz,.play
        jr attract
.play:  call mus_stop
        call wait_release
        xor a
        call game_main
        jr attract

init_once:
        ld hl,vars_start            ; clear the variables
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,1F3Ah
        ld (seed),hl
        ld a,1
        ld (difficulty),a
        ld a,NACTS-2
        ld (demo_act),a
        call init_hiscores
        jp shadow_reset

        include "sys.asm"
        include "sound.asm"
        include "render.asm"
        include "game.asm"
        include "objects.asm"
        include "hud.asm"
        include "pilot.asm"
        include "screens.asm"
        include "text.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_tables.inc"
        include "../build/gen_acts.inc"
        include "../build/gen_music.inc"
        include "../build/gen_art.inc"

end_of_program:
        ASSERT vars_end <= BGC

        SAVEBIN "../build/circus2.bin", start, end_of_program-start

        include "vars.asm"
