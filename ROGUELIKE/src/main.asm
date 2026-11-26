; =====================================================================
;  LUMEN - a roguelike of light and shadow for the Sharp MZ-700
;          (64K, PAL, European CG-ROM, no PCG).  Loads at 1200h.
;
;  Memory (the monitor ROM at 0000h is switched out for RAM at start):
;   0000-07FF  MAP      the current zone, 64 x 32 cells
;                       (bit 7 opaque, bit 6 seen, bits 0-5 tile)
;   0800-0FFF  SLIGHT   static light per cell (level | hue << 4)
;   1000-11FF  stack
;   1200-7FFF  program and data
;   8000-97FF  view buffers, 800 cells each, in 1K slots (render.asm)
;   9800-9FFF  VISM     what the player sees, per map cell (dist + 1)
;   A000-A7FF  DMAP     distance from the player (monster paths, bot)
;   A800-AFFF  the zone's monsters and items, variables, tile looks
;   B000-BFFF  zones 0 and 1 while away
;   C000-C8FF  every zone's creatures and items while away
;   D000-FFFF  (banked RAM behind VRAM and I/O) zones 2-7 while away
; =====================================================================
        DEVICE NOSLOT64K

; ---------------------------------------------------------------- hardware
VRAM            equ 0D000h
ARAM            equ 0D800h
KEYPA           equ 0E000h
KEYPB           equ 0E001h
KEYPC           equ 0E002h
CTR0            equ 0E004h
CTR1            equ 0E005h
CTRL            equ 0E007h
SNDGATE         equ 0E008h

; ---------------------------------------------------------------- geometry
MAPW            equ 64
MAPH            equ 32
VIEWW           equ 40
VIEWH           equ 20
NZONES          equ 8

; ---------------------------------------------------------------- memory
MAP             equ 0000h
SLIGHT          equ 0800h
STACKTOP        equ 1200h
LVL             equ 8000h           ; light at each view cell (level | hue<<4)
OVA             equ 8400h           ; overlay attr (0 = none)
OVG             equ 8800h           ; overlay glyph
SCH             equ 8C00h           ; what the screen shows: chars
SAT             equ 9000h           ;                        attrs
QRING           equ 9400h           ; BFS queue (1K ring)
SCH2VRAM        equ (high SCH) ^ (high VRAM)
ARAM2LVL        equ (high ARAM) ^ (high LVL)
PARTS           equ 8320h           ; particles live in a gap: 28 x 8
NPART           equ 28
VISM            equ 9800h
DMAP            equ 0A000h
MONS            equ 0A800h          ; the current zone's 24 monsters x 8
NMON            equ 24
MONSZ           equ 8
ITEMS           equ 0A8C0h          ; the current zone's 24 items x 4
NITEM           equ 24
ITEMSZ          equ 4
VARBASE         equ 0A920h          ; variables up to TLP
TLP             equ 0AF00h          ; tile look page (built per zone)
ZSTORE          equ 0B000h          ; zones 0-1 here, 2-7 in banked RAM:
ZSTORE_HI       equ 0D000h          ; D000-FFFF (behind VRAM and I/O)
ESTORE          equ 0C000h          ; each zone's monsters and items
ESIZE           equ NMON*MONSZ+NITEM*ITEMSZ
HIDATA          equ 0C900h          ; prefabs and front-end text (see hi_load)

; light
TORCH_HUE       equ 0               ; WARM

FRAMEF          equ 2               ; fields per frame (minimum)

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

; key codes: row*8 + bit
KC_CR           equ 0*8+0
KC_Y            equ 1*8+7
KC_Z            equ 1*8+6
KC_X            equ 2*8+0
KC_W            equ 2*8+1
KC_V            equ 2*8+2
KC_U            equ 2*8+3
KC_T            equ 2*8+4
KC_S            equ 2*8+5
KC_R            equ 2*8+6
KC_Q            equ 2*8+7
KC_P            equ 3*8+0
KC_O            equ 3*8+1
KC_N            equ 3*8+2
KC_M            equ 3*8+3
KC_L            equ 3*8+4
KC_K            equ 3*8+5
KC_J            equ 3*8+6
KC_I            equ 3*8+7
KC_H            equ 4*8+0
KC_G            equ 4*8+1
KC_F            equ 4*8+2
KC_E            equ 4*8+3
KC_D            equ 4*8+4
KC_C            equ 4*8+5
KC_B            equ 4*8+6
KC_A            equ 4*8+7
KC_8            equ 5*8+0
KC_7            equ 5*8+1
KC_6            equ 5*8+2
KC_5            equ 5*8+3
KC_4            equ 5*8+4
KC_3            equ 5*8+5
KC_2            equ 5*8+6
KC_1            equ 5*8+7
KC_DOT          equ 6*8+0
KC_SPACE        equ 6*8+4
KC_LEFT         equ 7*8+2
KC_RIGHT        equ 7*8+3
KC_DOWN         equ 7*8+4
KC_UP           equ 7*8+5
KC_BREAK        equ 8*8+7

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
        out (0E0h),a                ; 0000-0FFF: RAM instead of the monitor
        ld hl,hi_load               ; the high data to its place
        ld de,HIDATA
        ld bc,hi_end-hi_start
        ldir
        im 1
        xor a
        ld (SNDGATE),a
        ld a,36h
        ld (CTRL),a
        call detect_vblank
        call timer_init
        call init_once
attract:
        call title_screen           ; NZ = start a game
        jr nz,.play
        call story_page
        jr nz,.play
        call bestiary_page
        jr nz,.play
        call records_page
        jr nz,.play
        call demo_game
        jr attract
.play:  xor a
        ld (demo),a
        call game
        jr attract

init_once:
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,0ACE1h
        ld (seed),hl
        call snd_init
        call records_init
        ret

        include "sys.asm"
        include "sound.asm"
        include "fov.asm"
        include "render.asm"
        include "ovl.asm"
        include "particles.asm"
        include "gen.asm"
        include "zone.asm"
        include "game.asm"
        include "monsters.asm"
        include "magic.asm"
        include "items.asm"
        include "puzzle.asm"
        include "npc.asm"
        include "hud.asm"
        include "bot.asm"
        include "screens.asm"
        include "text.asm"
        include "text_hi.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_data.inc"
        include "../build/gen_music.inc"

end_of_code:
        ASSERT end_of_code <= LVL

; data only needed now and then: loaded after the program, copied to
; HIDATA (C900) at start, before the view buffers come into use
hi_load:
        DISP HIDATA
hi_start:
        include "../build/gen_prefabs.inc"
        include "../build/gen_logo.inc"
hi_end:
        ENT
hi_load_end:
        ASSERT hi_end <= 0D000h
        org VARBASE
        include "vars.asm"
        ASSERT vars_end <= TLP
        ASSERT PARTS+NPART*8 <= OVA
        ASSERT ESTORE+NZONES*ESIZE <= 0D000h

        SAVEBIN "../build/lumen.bin", start, hi_load_end-start
