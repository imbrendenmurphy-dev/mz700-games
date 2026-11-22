; =====================================================================
;  defs.inc - NOVA STORM: hardware, memory map, structures, constants
; =====================================================================

; ---------------------------------------------------------------- hardware
VRAM    equ 0D000h
CRAM    equ 0D800h
KROW    equ 0E000h      ; 8255 port A: keyboard row strobe (F0h + row)
KCOL    equ 0E001h      ; 8255 port B: keyboard columns, active low
PPIC    equ 0E002h      ; 8255 port C: bit 7 = /VBLK
CTR0    equ 0E004h      ; 8253 counter 0: sound tone
CTR1    equ 0E005h      ; 8253 counter 1: counts scan lines (pacing)
CTRL    equ 0E007h      ; 8253 control word
SNDGATE equ 0E008h      ; bit 0 = sound on

; ---------------------------------------------------------------- memory
; Screen-shaped buffers are 1000 bytes in the VRAM layout (row*40+col);
; char and attribute halves sit 400h apart ("set 2,h" hops between them).
BGCH    equ 8800h       ; background: stars + scenery + HUD
BGAT    equ 8C00h
WCH     equ 9000h       ; work screen: background + this tick's sprites
WAT     equ 9400h
SCH     equ 9800h       ; shadow: what VRAM holds now
SAT     equ 9C00h
OCC     equ 0A000h      ; who is in each cell: 0, enemy 1..24, 80h boss
LISTA   equ 0A400h      ; draw lists (cell offsets, 512 words each)
LISTB   equ 0A800h
BGDL    equ 0AC00h      ; background cells changed (512 words, to AFFF)
SCNC    equ 8000h       ; scenery ring: 32 rows x 32 bytes, chars
SCNA    equ 8400h       ; and attributes
SCNOCC  equ 0BF00h      ; cells used per scenery ring row (32)
ROWDIRTY equ 0BF20h     ; screen rows to compare in full at the flush (25)
ENEMY   equ 0B000h      ; MAXEN enemies x 32 bytes
EBUL    equ 0B400h      ; MAXEB enemy bullets x 8 bytes
SHOTS   equ 0B600h      ; MAXSH player shots x 8 bytes (to B7FF)
ITEMS   equ 0BE00h      ; MAXIT capsules/medals x 16 bytes
FXL     equ 0B800h      ; MAXFX explosions/popups x 8 bytes
STARS   equ 0B900h      ; NSTARS x 4 bytes
SPAWN   equ 0BA00h      ; MAXSP wave spawners x 16 bytes
PIECEL  equ 0BB00h      ; MAXPC scenery pieces entering x 8 bytes
HISC    equ 0BC00h      ; high scores: 8 x 8 bytes
TRAIL   equ 0BD00h      ; player trail for the options: 32 x 2 bytes
STACK   equ 1200h

; ---------------------------------------------------------------- playfield
PFW     equ 30          ; columns 0..29 are the playfield
PFH     equ 25
HUDX    equ 31          ; HUD panel columns 31..39 (30 is the divider)

; ---------------------------------------------------------------- enemies
MAXEN   equ 24
ENSZ    equ 32
ET      equ 0           ; type (0 = free)
EXL     equ 1           ; x: column . fraction (signed column)
EX      equ 2
EYL     equ 3           ; y: row . fraction (signed row)
EY      equ 4
EVXL    equ 5           ; velocity 8.8, cells per tick
EVXH    equ 6
EVYL    equ 7
EVYH    equ 8
EHP     equ 9
ETM     equ 10          ; general timer
EFT     equ 11          ; fire timer
EAN     equ 12          ; animation counter
EFL     equ 13          ; hit flash ticks
EST     equ 14          ; state
EPAR    equ 15          ; per-type parameter (phase, ...)
EPAR2   equ 16
EW      equ 17          ; width in cells
EH      equ 18
ESP0    equ 19          ; sprite frame 0 (word)
ESP1    equ 21          ; sprite frame 1 (word)
EPTS    equ 23          ; points (BCD word, low first: x10)
EDROP   equ 25          ; capsule kind dropped (0 none)
EWAVE   equ 26          ; spawner it came from + 1 (formation bonus)
EFLG    equ 27          ; flags
EX0     equ 28          ; anchor column (sine movers)
EAUX    equ 29
ECOLL   equ 30          ; collided with the player this tick

EF_GROUND equ 01h       ; moves with the scenery
EF_BIG    equ 02h       ; a big explosion

; enemy types
T_DART  equ 1
T_WASP  equ 2
T_CRAB  equ 3
T_BUG   equ 4
T_SKULL equ 5
T_EYE   equ 6
T_MINE  equ 7
T_FISH  equ 8
T_UFO   equ 9
T_GUN   equ 10
T_ROCK  equ 11
T_ROCKS equ 12
T_TUR   equ 13
T_HEAVY equ 14
NTYPES  equ 14

; ---------------------------------------------------------------- bullets
MAXEB   equ 48
EBSZ    equ 8
BT      equ 0           ; 0 free, 1 small, 2 big
BXL     equ 1
BX      equ 2
BYL     equ 3
BY      equ 4
BVX     equ 5           ; signed, 1/256 cell per tick
BVY     equ 6
BAN     equ 7

; player shots
MAXSH   equ 40
SHSZ    equ 8
ST      equ 0           ; 0 free, 1 vulcan, 2 laser
SXL     equ 1
SX      equ 2
SY      equ 3
SVX     equ 4           ; signed, 1/256 cell per tick
SDY     equ 5           ; rows per tick

; items (capsules, medals)
MAXIT   equ 8
ITSZ    equ 16
IK      equ 0           ; kind: 0 free, else IK_x
IXL     equ 1
IX_     equ 2
IYL     equ 3
IY      equ 4
IVX     equ 5
ITM     equ 6           ; age
IK_P    equ 1           ; power
IK_V    equ 2           ; vulcan
IK_L    equ 3           ; laser
IK_O    equ 4           ; option
IK_S    equ 5           ; speed
IK_B    equ 6           ; bomb
IK_H    equ 7           ; shield
IK_1UP  equ 8
IK_MED  equ 9           ; medal

; effects (explosions, score pop-ups)
MAXFX   equ 32
FXSZ    equ 8
FK      equ 0           ; 0 free, 1 explosion, 2 spark, 3 text pop-up
FX_     equ 1
FY      equ 2
FT      equ 3           ; age
FL      equ 4           ; life
FA      equ 5           ; attribute / text pointer low
FB      equ 6           ; text pointer high
FVY     equ 7

; stars
NSTARS  equ 30

; wave spawners
MAXSP   equ 6
SPSZ    equ 16
SPT     equ 0           ; enemy type (0 free)
SPN     equ 1           ; left to spawn
SPI     equ 2           ; interval
SPC     equ 3           ; countdown
SPX     equ 4           ; x
SPDX    equ 5           ; x change per spawn (signed)
SPP     equ 6           ; parameter
SPDR    equ 7           ; drop on the last one / formation bonus kind
SPALIVE equ 8           ; spawned and still alive
SPKILL  equ 9           ; killed by the player
SPTOT   equ 10          ; total in the wave
SPLX    equ 11          ; where the last one died
SPLY    equ 12

; scenery pieces entering the top
MAXPC   equ 8
PCSZ    equ 8
PCP     equ 0           ; pointer to the next row (word, 0 = free)
PCX     equ 2           ; column
PCW     equ 3           ; width
PCR     equ 4           ; rows left

; ---------------------------------------------------------------- keys
K_UP    equ 01h
K_DOWN  equ 02h
K_LEFT  equ 04h
K_RIGHT equ 08h
K_FIRE  equ 10h
K_BOMB  equ 20h

KS_SPACE equ 01h        ; edge keys (sedge/skeys)
KS_CR    equ 02h
KS_Q     equ 04h
KS_M     equ 08h
KS_B     equ 10h
KS_J     equ 20h

; game states
G_PLAY  equ 0
G_DEAD  equ 1
G_CLEAR equ 2
G_OVER  equ 3

; attract pages
PG_TITLE equ 0
PG_STORY equ 1
PG_FOES  equ 2
PG_ITEMS equ 3
PG_DEMO  equ 4
PG_HIGH  equ 5
NPAGES   equ 6

; colours
BLACK   equ 0
BLUE    equ 1
RED     equ 2
MAGENTA equ 3
GREEN   equ 4
CYAN    equ 5
YELLOW  equ 6
WHITE   equ 7
