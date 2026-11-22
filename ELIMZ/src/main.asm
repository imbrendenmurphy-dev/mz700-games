; =====================================================================
;  S T A R H A U L   for the Sharp MZ-700 (64K, PAL, European CG-ROM)
;  An original wireframe space-trading / combat game.  Prototype.
;  The 3D view is drawn in the CG-ROM's dotted quarter blocks (F0h-FFh):
;  40 x 18 cells = 80 x 36 dots.
;  Loads at 1200h from tape / UniCMT.
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
PIX             equ 0A000h          ; 18 cell rows x 64 (40 used): dot nibbles
SHD             equ 0A800h          ; same layout: what VRAM shows now
RBUF            equ 0B000h          ; radar: 5 rows x 16 cells
RSHD            equ 0B100h
STACKTOP        equ 0CFF0h
VARBASE         equ 0B600h          ; above the view and map pages

; ---------------------------------------------------------------- screen layout
VIEW_ROW        equ 1               ; view = rows 1..18
VIEW_VRAM       equ VRAM+VIEW_ROW*40
VW              equ 80
VH              equ 36
CX              equ 40
CY              equ 18
MSG_ROW         equ 0
SEP_ROW         equ 19
HUD_ROW         equ 20
RAD_COL         equ 12
RAD_W           equ 16              ; cells
RAD_H           equ 5

NEAR            equ 24              ; near clip plane (model units)
FRAMEF          equ 3               ; fields per game frame (16.7 fps target)

; colours
BLACK           equ 0
BLUE            equ 1
RED             equ 2
MAGENTA         equ 3
GREEN           equ 4
CYAN            equ 5
YELLOW          equ 6
WHITE           equ 7

; ---------------------------------------------------------------- objects
MAXOBJ          equ 8
OBJSZ           equ 32
O_TYPE          equ 0
O_FLAG          equ 1
O_X             equ 2               ; position (view space), signed words
O_Y             equ 4
O_Z             equ 6
O_SIDE          equ 8               ; orientation: side, roof, nose vectors,
O_ROOF          equ 14              ;   3 signed words each, unit 4000h
O_NOSE          equ 20
O_SPD           equ 26
O_HP            equ 27
O_TMR           equ 28
O_CD            equ 29              ; laser cooldown
O_EV            equ 30              ; evade timer
O_AIM           equ 31

T_NONE          equ 0
T_STATION       equ 1
T_DART          equ 2
T_MANTIS        equ 3
T_RAPTOR        equ 4
T_HAULER        equ 5
T_WARDEN        equ 6
T_ROCK          equ 7
T_SEEKER        equ 8
T_CANISTER      equ 9
T_DEBRIS        equ 10

; input bits (read_flight)
K_LEFT          equ 01h
K_RIGHT         equ 02h
K_UP            equ 04h
K_DOWN          equ 08h
K_FIRE          equ 10h
K_FAST          equ 20h
K_SLOW          equ 40h
K_BREAK         equ 80h
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
        call timer_init
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,5A3Ch
        ld (seed),hl
        call snd_init
.attract:
        call title_screen           ; NZ: start, Z: timed out
        jr nz,.play
        call demo
        jr nz,.attract
        call gallery
        jr nz,.attract
        call handbook
        jr .attract
.play:  call wait_release
        call new_game
        ld a,(load_req)             ; L on the title: load a pilot first
        or a
        jr z,.docked                ; a new pilot starts at the home station
        xor a
        ld (load_req),a
        call menu_load
        ld a,(tape_ok)
        or a
        jr z,.attract
        jr .docked
.launch:
        call flight                 ; A: 0 destroyed, 1 docked, 2 jumped
        or a
        jr z,.dead
        cp 2
        jr z,.jump
        call dock_fx                ; in through the station's tunnel
.docked:
        call docked_screen
        xor a
        ld (arrive),a
        jr .launch
.jump:  call hyper_jump
        ld a,1
        ld (arrive),a
        jr .launch
.dead:  call gameover_screen
        jr .attract

new_game:
        ld hl,kills
        ld (hl),0
        ld hl,1000                  ; 100.0 credits
        ld (credits),hl
        xor a
        ld (credits+2),a
        ld (arrive),a
        ld hl,cargo
        ld b,NGOODS
.c:     ld (hl),a
        inc hl
        djnz .c
        ld (legal),a
        ld (has_jammer),a
        ld (has_twin),a
        ld (has_pod),a
        ld (has_booster),a
        ld (has_scoop),a
        ld (has_autodock),a
        inc a
        ld (seekers),a
        ld a,HOLDMAX
        ld (holdmax),a
        ld a,MAXFUEL
        ld (fuel),a
        ld a,START_SYS
        ld (cur_sys),a
        ld (target_sys),a
        ret

        include "sys.asm"
        include "sound.asm"
        include "math.asm"
        include "draw.asm"
        include "world.asm"
        include "hud.asm"
        include "screens.asm"
        include "trade.asm"
        include "combat.asm"
        include "attract.asm"
        include "qol.asm"
        include "fx.asm"
        include "joy.asm"
        include "hidden.asm"
        include "views.asm"

; ---------------------------------------------------------------- data
        include "../build/gen_tables.inc"
        include "../build/gen_models.inc"
        include "../build/gen_music.inc"
        include "../build/gen_galaxy.inc"

end_of_program:
        ASSERT end_of_program <= PIX
        ASSERT vars_end <= STACKTOP-200h

        SAVEBIN "../build/starhaul.bin", start, end_of_program-start

        include "vars.asm"
