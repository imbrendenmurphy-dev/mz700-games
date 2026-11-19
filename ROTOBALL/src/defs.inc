; ---------------------------------------------------------------- hardware
VRAM    = 0D000h
CRAM    = 0D800h
KBD_ROW = 0E000h        ; 8255 port A: keyboard row strobe
KBD_COL = 0E001h        ; 8255 port B: keyboard column data (active low)
PPI_C   = 0E002h        ; 8255 port C: bit7 = /VBLK (0 in vertical blanking)
CTR0    = 0E004h        ; 8253 counter 0: sound tone
CTR1    = 0E005h        ; 8253 counter 1: clocked by HSYNC, used to time frames
CTRL    = 0E007h        ; 8253 control word
SNDGATE = 0E008h        ; bit0 = sound on

; ---------------------------------------------------------------- memory
STACK   = 1200h         ; stack grows down into the free monitor work area
LISTPTR = 0C380h        ; 5 words: start of delta list k (k = 0..4), page-local
TLISTPTR = 0C390h       ; the same for the title's 80-sample rows
LISTS   = 0C400h        ; 4 lists x 46 words
TLISTS  = 0CA00h        ; 4 lists x 80 words
OBJS    = 0C600h        ; MAXOBJ objects x 8 bytes
OVL     = 0C800h        ; overlay list: count, then (row, col, char, attr)
OVLOLD  = 0C900h        ; last frame's overlay cells: count, then (row, col)

; ---------------------------------------------------------------- objects
MAXOBJ  = 48
O_TYPE  = 0
O_XF    = 1             ; x = column . fraction  (8.8)
O_XC    = 2
O_YF    = 3             ; y = map page . fraction (8.8)
O_YP    = 4
O_SPD   = 5             ; crawler speed (signed, 1/256 cell per frame)
O_AXIS  = 6             ; crawler axis: 0 = x, 1 = y

T_GEM     = 1
T_EXIT    = 2
T_MINE    = 3
T_CRAWLER = 4
T_BOMB    = 5
T_SHIELD  = 6
T_EXITOPEN = 7

; ---------------------------------------------------------------- game
S_PLAY  = 0
S_DYING = 1
S_CLEAR = 2
S_OVER  = 3
S_READY = 4

K_LEFT  = 04h
K_RIGHT = 08h
K_FIRE  = 10h

BALL_R  = 07Fh          ; ball half-size in map cells (8.8), just under 0.5
VMAX    = 112           ; speed cap (cells/frame, 8.8) keeps collisions honest
ROTSPD  = 4             ; angle units (of 256) per frame
HIT_R   = 0E0h          ; ball/object overlap distance (8.8 cells)
SHIELD_TIME = 150       ; frames (~9 s)

HUD_X   = 26
