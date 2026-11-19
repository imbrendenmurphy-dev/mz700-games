; =====================================================================
;  defs.inc - hardware, memory map, object layout, constants
; =====================================================================

; ---------------------------------------------------------------- hardware
VRAM    equ 0D000h
CRAM    equ 0D800h
KROW    equ 0E000h      ; 8255 port A: keyboard row strobe (F0h + row)
KCOL    equ 0E001h      ; 8255 port B: keyboard columns, active low
PPIC    equ 0E002h      ; 8255 port C: bit 7 = /VBLK
CTR0    equ 0E004h      ; 8253 counter 0: sound tone
CTRL    equ 0E007h      ; 8253 control word
SNDGATE equ 0E008h      ; bit 0 = sound on

; ---------------------------------------------------------------- memory
; Every screen-shaped buffer is 1000 bytes in the VRAM layout (row*40+col).
; Char and attribute halves sit 400h apart so "set 2,h" hops between them.
OLCH    equ 8000h       ; object layer: BG + sticky sprites
OLAT    equ 8400h
REDRAW  equ 8800h       ; 1 = cell uncovered, objects there must redraw
OBJ     equ 9000h       ; MAXOBJ objects x 32 bytes
DLIST   equ 0A800h      ; object-layer cells changed this tick, 252 words
LISTA   equ 0A000h      ; draw list (cell offsets), 252 words max, 512-aligned
LISTB   equ 0A200h      ; the other draw list
BGDL    equ 0A400h      ; background cells changed this tick, 250 words max
EBUL    equ 0A600h      ; MAXEB enemy bullets x 8 bytes
SHOTS   equ 0A680h      ; MAXSH player shots x 4 bytes
PART    equ 8C00h       ; MAXPART particles x 16 bytes
HISC    equ 0A6C0h      ; high-score table: 8 x 8 bytes
BGCH    equ 0B000h      ; background: arena, frame, HUD, captions
BGAT    equ 0B400h
WCH     equ 0B800h      ; work screen: background + this tick's sprites
WAT     equ 0BC00h
SCH     equ 0C000h      ; shadow: what VRAM holds now
SAT     equ 0C400h
OCC     equ 0C800h      ; owner of each object-layer cell: 0 or object index+1
BOCC    equ 0CC00h      ; enemy bullets: 0 or 80h+bullet (cleared every tick)
STACK   equ 1200h       ; stack grows down into the monitor work area

; ---------------------------------------------------------------- objects
MAXOBJ  equ 80
OBJSZ   equ 32
OT      equ 0           ; type (0 = free slot)
OXL     equ 1           ; x = column . fraction (8.8)
OX      equ 2
OYL     equ 3           ; y = row . fraction (8.8)
OY      equ 4
OVXL    equ 5           ; velocity (8.8, cells per tick) for free movers
OVXH    equ 6
OVYL    equ 7
OVYH    equ 8
OTM     equ 9           ; step countdown / life timer
OAN     equ 10          ; animation counter
OST     equ 11          ; materialise countdown (0 = live)
OAUX    equ 12          ; per-type: colour, heading, spawn count, ...
OAUX2   equ 13          ; per-type: fire timer, target, ...
ODX     equ 14          ; heading dx (-1..1)
ODY     equ 15          ; heading dy (-1..1)
OFL     equ 16          ; type flags (copied by set_type)
OTI     equ 17          ; type info pointer (word, copied by set_type)
OLOFS   equ 19          ; where it was last drawn on the object layer (word)
OLC     equ 21          ; and how it looked
OLA     equ 22
ODRAWN  equ 23          ; 1 = drawn on the object layer
ODIRTY  equ 24          ; 1 = moved or changed look since last drawn
OUPD    equ 25          ; behaviour routine (word, copied by set_type)

T_DROID   equ 1
T_PYLON   equ 2
T_CRUSH   equ 3
T_BRAIN   equ 4         ; mindbot
T_MUTANT  equ 5
T_ORB     equ 6
T_SEEKER  equ 7
T_FACT    equ 8
T_TANK    equ 9
T_MOM     equ 10
T_DAD     equ 11
T_KID     equ 12
T_SKULL   equ 13
T_POP     equ 14
T_EXPL    equ 15
T_PICK    equ 16
NTYPES    equ 16

F_DEADLY  equ 01h       ; touching it kills the player
F_SHOOT   equ 02h       ; player shots destroy it
F_COUNT   equ 04h       ; must be destroyed to clear the wave
F_HUMAN   equ 08h
F_PUSH    equ 10h       ; shots knock it back (crusher)
F_SOLID   equ 20h       ; collides (player, shots, humans)
F_ANIM    equ 40h       ; look changes by itself (colour cycling): redraw always

; enemy bullets (8 bytes)
MAXEB   equ 16
EBSZ    equ 8
BT      equ 0           ; 0 free, 1 spark, 2 missile, 3 shell
BXL     equ 1
BX      equ 2
BYL     equ 3
BY      equ 4
BVX     equ 5           ; signed, 1/256 cell per tick
BVY     equ 6
BLIFE   equ 7

; particles (8 bytes)
MAXPART equ 32
PSZ     equ 16
P_LIFE  equ 0           ; 0 = free
P_XL    equ 1
P_X     equ 2
P_YL    equ 3
P_Y     equ 4
P_VX    equ 5           ; signed, 1/256 cell per tick
P_VY    equ 6
P_AT    equ 7           ; attribute; bit 3 = gravity
P_DOFS  equ 8           ; where it is drawn in W (word)
P_DRAWN equ 10          ; 1 = drawn there
P_DCH   equ 11          ; as this char
P_DAT   equ 12          ; and attribute
GRAV    equ 08h

; player shots (4 bytes)
MAXSH   equ 12
SDIR    equ 0           ; 0 free, else direction 1..8 (index into tables)
SX      equ 1
SY      equ 2
SAGE    equ 3

; ---------------------------------------------------------------- arena
XMIN    equ 1           ; playfield columns 1..38, rows 2..23
XMAX    equ 38
YMIN    equ 2
YMAX    equ 23
CX      equ 19          ; player start cell
CY      equ 12
A_ARENA equ 71h         ; empty arena: white on blue

; key bits (both sticks)
K_UP    equ 01h
K_DOWN  equ 02h
K_LEFT  equ 04h
K_RIGHT equ 08h

; game states
S_INTRO equ 0
S_PLAY  equ 1
S_DYING equ 2
S_CLEAR equ 3
S_OVER  equ 4

PSPDX   equ 48h         ; player speed, cells per tick (8.8)
PSPDY   equ 3Ch
FIRE_RATE equ 4         ; ticks between shots

; power-ups
PU_3WAY   equ 0         ; pickup kinds (OAUX of a T_PICK)
PU_SHIELD equ 1
T3WAY     equ 500       ; ticks of triple shot (10 s)
TSHIELD   equ 300       ; ticks of shield (6 s)
PICKLIFE  equ 400       ; a pickup lasts 8 s

; attract pages
PG_TITLE  equ 0
PG_STORY  equ 1
PG_ROBOTS equ 2
PG_HOWTO  equ 3
PG_DEMO   equ 4
PG_HEROES equ 5
NPAGES    equ 6
