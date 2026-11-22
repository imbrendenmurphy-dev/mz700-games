; =====================================================================
;  defs.inc - REDLINE: hardware, memory map, constants
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
PK       equ 0A000h     ; road attributes: 16 rows x 64 (40 used)
SPRL     equ 0A400h     ; sprites to draw: 64 x 8 bytes (to A5FF)
CARS     equ 0A600h     ; traffic: 8 x 32 bytes
HISC     equ 0A700h     ; high scores: 8 x 8 bytes
SKYSH    equ 0A800h     ; sky shadow: 280 characters (to A917)
SKYBUF   equ 0AA00h     ; sky patterns, each row twice: 7 x 128 (to AD7F)
TRK_CURV equ 0B000h     ; per segment: curve (signed)
TRK_HGT  equ 0B400h     ; per segment: height (signed)
TRK_OBJ  equ 0B800h     ; per segment: roadside object (0 = none)
TRK_OX   equ 0BC00h     ; per segment: object's side position (x 4, signed)
TRK_SPL  equ 0C000h     ; per segment: fork split (0 = one road)
MAXSEG   equ 960
EDT      equ 0C800h     ; edge cells: EDT[f][o] = (o + 4 + f) >> 3, 8 pages
SQL      equ 0C400h     ; squares/4: low bytes (512), high bytes at +200h        ; segments in a stage, at most (+ 64 of padding)
STACK    equ 1200h

; ---------------------------------------------------------------- screen
ROADROW  equ 9          ; first character row of the road picture
NCR      equ 16         ; character rows of road
NSR      equ 32         ; sub-rows (two per character row)
SKYROW   equ 2          ; sky rows 2..8
HALF     equ 7Ah        ; upper-half block: fg = top sub-row, bg = bottom

; ---------------------------------------------------------------- world
SEGL     equ 16         ; z units per segment
CAMH     equ 33         ; camera height
ROADW    equ 160        ; road half width (world units)
NSAMP    equ 40         ; segments looked ahead

; sprite record (SPRL + i*8)
SP_IMG   equ 0          ; image (word, 0 = end)
SP_X     equ 2          ; centre, 1/8 cells (word)
SP_Y     equ 4          ; bottom sub-row + 1
SP_CLIP  equ 5

; traffic record (CARS + i*32)
MAXCARS  equ 8
CARSZ    equ 32
C_ON     equ 0          ; 0 free, else type
C_ZF     equ 1          ; z (fraction, low, high) - absolute track units
C_Z      equ 2
C_X      equ 4          ; lateral position (word, world units)
C_V      equ 6          ; speed (8.8 units per field)
C_TX     equ 8          ; lane target x (word)
C_PASS   equ 10         ; 1 = was ahead of the player
C_LC     equ 11         ; lane change timer
C_COL    equ 12         ; body colour
C_NEXT   equ 13         ; next car on the same segment (+1)
C_RZ     equ 14         ; z ahead of the camera (word)
C_HIT    equ 16         ; fields before it can be hit again

; ---------------------------------------------------------------- keys
K_UP    equ 01h
K_DOWN  equ 02h
K_LEFT  equ 04h
K_RIGHT equ 08h
K_FIRE  equ 10h         ; boost
K_ALT   equ 20h

KS_SPACE equ 01h
KS_CR    equ 02h
KS_Q     equ 04h
KS_M     equ 08h
KS_B     equ 10h
KS_J     equ 20h

; colours
BLACK   equ 0
BLUE    equ 1
RED     equ 2
MAGENTA equ 3
GREEN   equ 4
CYAN    equ 5
YELLOW  equ 6
WHITE   equ 7

; game states
GS_START equ 0
GS_RACE  equ 1
GS_CRASH equ 2
GS_OVER  equ 3
GS_GOAL  equ 4

BOOSTMAX equ 160
