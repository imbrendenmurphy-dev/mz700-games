; ======================================================================
;  ROTOBALL - milestone 1: rotating maze test
;  Sharp MZ-700 (64K, PAL, stock character ROM), loads at 1200h
;
;  Left / right (or Z / X) rotate the maze around the ball; gravity always
;  points down the screen. The maze is drawn with the 16 dotted 2x2 block
;  characters F0h-FFh, so the 25x25 character view is a 50x50 block image.
; ======================================================================

    include "../build/gen_const.inc"

VRAM    = 0D000h
CRAM    = 0D800h
KBD_ROW = 0E000h        ; 8255 port A: keyboard row strobe
KBD_COL = 0E001h        ; 8255 port B: keyboard column data (active low)
PPI_C   = 0E002h        ; 8255 port C: bit7 = /VBLK (0 in vertical blanking)
CTR0    = 0E004h        ; 8253 counter 0: sound tone
CTR1    = 0E005h        ; 8253 counter 1: clocked by HSYNC, used to time frames
CTRL    = 0E007h        ; 8253 control word
SNDGATE = 0E008h        ; bit0 = sound on

LISTPTR = 0C380h        ; 5 words: start of delta list k (k = 0..4), page-local
LISTS   = 0C400h        ; 4 lists x 50 words

BALL_R  = 07Fh         ; ball half-size in map cells (8.8), just under 0.5
VMAX    = 112           ; speed cap (cells/frame, 8.8) keeps collisions honest
ROTSPD  = 4             ; angle units (of 256) per frame

HUD_X   = 28

    org 1200h

start:
    di
    ld sp,1200h
    call init_map
    call init_screen
    call init_hw
    ld hl,LISTPTR       ; list pointer table
    ld de,LISTS
    ld b,5
.lp:
    ld (hl),e
    inc l
    ld (hl),d
    inc l
    push hl
    ld hl,100
    add hl,de
    ex de,hl
    pop hl
    djnz .lp
    ld hl,START_X*256+80h
    ld (ballx),hl
    ld hl,(MAP_PAGE+START_Y)*256+80h
    ld (bally),hl

frame:
    call setup_render
    call render
    call wait_vblank
    call blit
    call colours
    call read_keys
    call rotate
    call physics
    call sound
    call timing
    call hud
    jp frame

; ----------------------------------------------------------------------
; map: 96 rows x 256 columns at 6000h-BFFFh, bit 7 = wall
init_map:
    ld hl,MAP_PAGE*256
    ld de,MAP_PAGE*256+1
    ld bc,MAP_ROWS*256-1
    ld (hl),81h
    ldir
    ld ix,MAZEBITS
    ld h,MAP_PAGE+MAZE_ROW0
    ld c,MAZE_H
.row:
    ld l,MAZE_COL0
    ld b,MAZE_W/8
.byte:
    ld a,(ix+0)
    inc ix
    push bc
    ld b,8
.bit:
    rla
    ld (hl),0
    jr nc,.open
    ld (hl),81h
.open:
    inc l
    djnz .bit
    pop bc
    djnz .byte
    inc h
    dec c
    jr nz,.row
    ret

; ----------------------------------------------------------------------
init_screen:
    ld hl,VRAM
    ld de,VRAM+1
    ld bc,999
    ld (hl),0
    ldir
    ld hl,CRAM
    ld de,CRAM+1
    ld bc,999
    ld (hl),70h
    ldir
    ; solid border columns either side of the view
    ld hl,VRAM
    ld de,40
    ld b,25
.bord:
    ld (hl),43h
    push hl
    push de
    ld de,VIEW_X+VIEW_CHARS
    add hl,de
    ld (hl),43h
    pop de
    pop hl
    add hl,de
    djnz .bord
    ; HUD text
    ld hl,txt_title
    ld de,VRAM+1*40+HUD_X+1
    call print
    ld hl,txt_sub
    ld de,VRAM+3*40+HUD_X
    call print
    ld hl,txt_fps
    ld de,VRAM+8*40+HUD_X
    call print
    ld hl,txt_ang
    ld de,VRAM+10*40+HUD_X
    call print
    ld hl,txt_lines
    ld de,VRAM+12*40+HUD_X
    call print
    ld hl,txt_keys1
    ld de,VRAM+20*40+HUD_X
    call print
    ld hl,txt_keys2
    ld de,VRAM+22*40+HUD_X
    call print
    ; title in yellow, keys in cyan
    ld hl,CRAM+1*40+HUD_X
    ld b,12
.tc:
    ld (hl),60h
    inc hl
    djnz .tc
    ld hl,CRAM+20*40+HUD_X
    ld b,12
.kc:
    ld (hl),50h
    inc hl
    djnz .kc
    ld hl,CRAM+22*40+HUD_X
    ld b,12
.kc2:
    ld (hl),50h
    inc hl
    djnz .kc2
    ret

print:                  ; HL = display-code string (FFh end), DE = VRAM
    ld a,(hl)
    cp 0FFh
    ret z
    ld (de),a
    inc hl
    inc de
    jr print

; ----------------------------------------------------------------------
init_hw:
    ld a,36h            ; counter 0: LSB/MSB, mode 3 (square wave)
    ld (CTRL),a
    ld a,74h            ; counter 1: LSB/MSB, mode 2, free-running /65536
    ld (CTRL),a
    xor a
    ld (CTR1),a
    ld (CTR1),a
    ld (SNDGATE),a
    ret

wait_vblank:            ; wait for the start of the next vertical blank
.in:
    ld a,(PPI_C)
    rla
    jr nc,.in           ; already in blanking: wait for display
.out:
    ld a,(PPI_C)
    rla
    jr c,.out           ; wait for blanking to begin
    ret

; ----------------------------------------------------------------------
; DE = signed 16-bit 128*sin(A*2pi/256)
getsin:
    ld l,a
    ld h,hi(SINL)
    ld e,(hl)
    inc h
    ld d,(hl)
    ret

neg_hl:
    xor a
    sub l
    ld l,a
    ld a,0
    sbc a,h
    ld h,a
    ret

; Work out per-block steps U (screen right) and V (screen down) in map space,
; and RT = the map point of the top row's rightmost block.
setup_render:
    ld a,(angle)
    call getsin
    ld (Uy),de
    ld a,(angle)
    add a,64
    call getsin
    ld (Ux),de
    ld (Vy),de          ; V = (-Uy, Ux)
    ld hl,(Uy)
    call neg_hl
    ld (Vx),hl
    add hl,hl
    ld (V2x),hl
    ld hl,(Vy)
    add hl,hl
    ld (V2y),hl
    ; RT = ball + 24.5 * (U - V)
    ld hl,(Ux)
    ld de,(Vx)
    or a
    sbc hl,de
    call mul245
    ld de,(ballx)
    add hl,de
    ld (RTx),hl
    ld hl,(Uy)
    ld de,(Vy)
    or a
    sbc hl,de
    call mul245
    ld de,(bally)
    add hl,de
    ld (RTy),hl
    ; delta lists depend only on the angle
    ld a,(listang)
    ld b,a
    ld a,(angle)
    cp b
    ret z
    ld (listang),a
    jp build_lists

mul49:                  ; HL = 49 * HL
    ld d,h
    ld e,l
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl           ; 16x
    push hl
    add hl,hl           ; 32x
    pop bc
    add hl,bc           ; 48x
    add hl,de           ; 49x
    ret

; Build the four delta lists (one per half-cell phase of a row's start point).
; List k holds 50 pointer deltas: 0, then floor(s_i) - floor(s_(i-1)) for the
; samples s_i = f - i*U walking right to left across the row.
build_lists:
    ld hl,(Ux)
    call mul49
    ld (U49x),hl
    ld hl,(Uy)
    call mul49
    ld (U49y),hl
    ld (spsave),sp
    xor a
    ld (lclass),a
.cls:
    ld a,(lclass)       ; SP = end of list k (pushes fill it downwards)
    inc a
    add a,a
    add a,lo(LISTPTR)
    ld l,a
    ld h,hi(LISTPTR)
    ld a,(hl)
    inc l
    ld h,(hl)
    ld l,a
    ld sp,hl
    ld a,(lclass)       ; v = 4000h + fy - 49Uy  (biased so nothing wraps)
    and 2
    rrca
    rrca                ; 80h if fy = 1/2
    ld l,a
    ld h,40h
    ld de,(U49y)
    or a
    sbc hl,de
    ld bc,(Uy)
    exx
    ld a,(lclass)       ; u = 4000h + fx - 49Ux
    and 1
    rrca
    ld l,a
    ld h,40h
    ld de,(U49x)
    or a
    sbc hl,de
    ld bc,(Ux)
    include "../build/gen_listentry.inc"
    ld de,0
    push de
    ld a,(lclass)
    inc a
    ld (lclass),a
    cp 4
    jp nz,.cls
    ld sp,(spsave)
    ret

mul245:                 ; HL = 24.5 * HL (signed)
    push hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld d,h
    ld e,l
    add hl,hl
    add hl,de
    pop de
    sra d
    rr e
    add hl,de
    ret

; ----------------------------------------------------------------------
; Rotozoom renderer. Each block row: HL = map pointer at the row's rightmost
; sample, SP = delta list; per sample pop/add/load/shift (40 T-states).
; Lower block row first, then upper, giving the F0h-FFh code in C.
render:
    ld (spsave),sp
    ld a,VIEW_CHARS
    ld (rowcnt),a
    ld hl,CHARBUF+VIEW_CHARS-1
    ld (outptr),hl
.row:
    include "../build/gen_row_lower.inc"
    include "../build/gen_pass_lower.inc"
    include "../build/gen_row_upper.inc"
    include "../build/gen_pass_upper.inc"
    ld hl,(RTx)
    ld de,(V2x)
    add hl,de
    ld (RTx),hl
    ld hl,(RTy)
    ld de,(V2y)
    add hl,de
    ld (RTy),hl
    ld hl,(outptr)
    ld de,32
    add hl,de
    ld (outptr),hl
    ld a,(rowcnt)
    dec a
    ld (rowcnt),a
    jp nz,.row
    ld sp,(spsave)
    ; ball in the centre character
    ld a,47h
    ld (CHARBUF+12*32+12),a
    ret

blit:
    include "../build/gen_blit.inc"
    ret

colours:
    ld a,(phase)
    inc a
    ld (phase),a
    rra
    rra
    and 7
    ld (cphase),a
    include "../build/gen_colours.inc"
    ld a,70h            ; ball: white on black
    ld (CRAM+12*40+VIEW_X+12),a
    ret

; ----------------------------------------------------------------------
read_keys:
    ld a,0F7h           ; row 7: cursor keys
    ld (KBD_ROW),a
    nop
    ld a,(KBD_COL)
    cpl
    and 0Ch             ; bit2 = left, bit3 = right
    ld c,a
    ld a,0F1h           ; row 1: Z = bit6
    ld (KBD_ROW),a
    nop
    ld a,(KBD_COL)
    bit 6,a
    jr nz,.noz
    set 2,c
.noz:
    ld a,0F2h           ; row 2: X = bit0
    ld (KBD_ROW),a
    nop
    ld a,(KBD_COL)
    bit 0,a
    jr nz,.nox
    set 3,c
.nox:
    ld a,c
    ld (keys),a
    ret

rotate:
    ld a,(keys)
    ld c,a
    ld a,(angle)
    bit 2,c
    jr z,.nl
    sub ROTSPD
.nl:
    bit 3,c
    jr z,.nr
    add a,ROTSPD
.nr:
    ld (angle),a
    ret

; ----------------------------------------------------------------------
; Physics in map space. Gravity = screen-down = (-sin, cos) * 1/32 cell/frame^2.
physics:
    ld a,(angle)
    call getsin         ; DE = 128 sin
    call sra4_de
    ld hl,(vx)
    or a
    sbc hl,de           ; vx -= sin/16
    call friction
    call clamp
    ld (vx),hl
    ld a,(angle)
    add a,64
    call getsin         ; DE = 128 cos
    call sra4_de
    ld hl,(vy)
    add hl,de
    call friction
    call clamp
    ld (vy),hl
    call move_x
    jp move_y

sra4_de:
    sra d
    rr e
    sra d
    rr e
    sra d
    rr e
    sra d
    rr e
    ret

friction:               ; HL -= HL/64
    push hl
    ld d,h
    ld e,l
    ld b,6
.f:
    sra d
    rr e
    djnz .f
    pop hl
    or a
    sbc hl,de
    ret

clamp:                  ; clamp HL to +-VMAX
    bit 7,h
    jr nz,.neg
    ld de,VMAX
    or a
    push hl
    sbc hl,de
    pop hl
    ret c
    ld hl,VMAX
    ret
.neg:
    ld de,-VMAX
    or a
    push hl
    sbc hl,de
    pop hl
    ret nc
    ld hl,-VMAX
    ret

; is map cell (B = column, C = row page) a wall? NZ if so
wall_at:
    ld h,c
    ld l,b
    bit 7,(hl)
    ret

move_x:
    ld de,(vx)
    ld a,d
    or e
    ret z
    ld hl,(ballx)
    add hl,de
    ld (newp),hl
    bit 7,d
    jr nz,.left
    ld de,BALL_R
    add hl,de
    jr .edge
.left:
    ld de,-BALL_R
    add hl,de
.edge:
    ld b,h              ; column of the leading edge
    ld hl,(bally)
    ld de,-BALL_R
    add hl,de
    ld c,h
    call wall_at
    jr nz,.hit
    ld hl,(bally)
    ld de,BALL_R
    add hl,de
    ld c,h
    call wall_at
    jr nz,.hit
    ld hl,(newp)
    ld (ballx),hl
    ret
.hit:
    ld hl,(vx)
    call bounce
    ld (vx),hl
    ret

move_y:
    ld de,(vy)
    ld a,d
    or e
    ret z
    ld hl,(bally)
    add hl,de
    ld (newp),hl
    bit 7,d
    jr nz,.up
    ld de,BALL_R
    add hl,de
    jr .edge
.up:
    ld de,-BALL_R
    add hl,de
.edge:
    ld c,h              ; row page of the leading edge
    ld hl,(ballx)
    ld de,-BALL_R
    add hl,de
    ld b,h
    call wall_at
    jr nz,.hit
    ld hl,(ballx)
    ld de,BALL_R
    add hl,de
    ld b,h
    call wall_at
    jr nz,.hit
    ld hl,(newp)
    ld (bally),hl
    ret
.hit:
    ld hl,(vy)
    call bounce
    ld (vy),hl
    ret

; HL = velocity that hit a wall -> HL = -HL/2, with a clink if it was fast
bounce:
    push hl
    bit 7,h
    jr z,.pos
    call neg_hl
.pos:
    ld de,20
    or a
    sbc hl,de
    jr c,.quiet
    ld a,l              ; harder hits clink lower and longer
    srl a
    srl a
    srl a
    add a,3
    ld (sfxt),a
    ld hl,180
    ld (sfxdiv),hl
.quiet:
    pop hl
    sra h
    rr l
    jp neg_hl

; ----------------------------------------------------------------------
; Sound: one 8253 square-wave voice. Clink = rising sweep; spinning = gritty hiss.
sound:
    ld a,(sfxt)
    or a
    jr z,.nosfx
    dec a
    ld (sfxt),a
    ld hl,(sfxdiv)
    ld de,37
    add hl,de
    ld (sfxdiv),hl
    jr .play
.nosfx:
    ld a,(keys)
    and 0Ch
    jr z,.off
    call rand           ; hiss: random divisor 1024-2047 (540-1080 Hz) each frame
    ld a,h
    and 3
    or 4
    ld h,a
.play:
    ld a,l
    ld (CTR0),a
    ld a,h
    ld (CTR0),a
    ld a,1
    ld (SNDGATE),a
    ret
.off:
    xor a
    ld (SNDGATE),a
    ret

rand:                   ; HL = xorshift16
    ld hl,(seed)
    ld a,h
    rra
    ld a,l
    rra
    xor h
    ld h,a
    ld a,l
    rra
    ld a,h
    rra
    xor l
    ld l,a
    xor h
    ld h,a
    ld (seed),hl
    ret

; ----------------------------------------------------------------------
; Frame timing from 8253 counter 1 (counts scan lines, 312 per field)
timing:
    ld a,40h            ; latch counter 1
    ld (CTRL),a
    ld a,(CTR1)
    ld e,a
    ld a,(CTR1)
    ld d,a
    ld hl,(lastctr)
    ld (lastctr),de
    or a
    sbc hl,de           ; lines elapsed (counter counts down)
    ld (lines),hl
    ld de,156           ; round to whole fields
    add hl,de
    ld de,312
    ld b,0
.div:
    or a
    sbc hl,de
    jr c,.done
    inc b
    jr .div
.done:
    ld a,b
    ld (fields),a
    ret

hud:
    ld a,(fields)
    cp 7
    jr c,.ok
    ld a,7
.ok:
    add a,a
    ld e,a
    ld d,0
    ld hl,fps_tab
    add hl,de
    ld de,VRAM+8*40+HUD_X+5
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
    ld a,(angle)
    ld de,VRAM+10*40+HUD_X+6
    call hex2
    ld a,(lines+1)
    ld de,VRAM+12*40+HUD_X+6
    call hex2
    ld a,(lines)
    jp hex2

hex2:                   ; A -> two hex digits at DE
    push af
    rra
    rra
    rra
    rra
    call .dig
    pop af
.dig:
    and 0Fh
    cp 10
    jr c,.num
    sub 9               ; A-F -> display codes 01h-06h
    jr .put
.num:
    add a,20h
.put:
    ld (de),a
    inc de
    ret

; frames-per-second for 0..7 fields per frame (display codes)
fps_tab:
    dsc "--50251612100807"

txt_title:  dsc "ROTOBALL"
            db 0FFh
txt_sub:    dsc "SPIN TEST 1"
            db 0FFh
txt_fps:    dsc "FPS"
            db 0FFh
txt_ang:    dsc "ANGLE"
            db 0FFh
txt_lines:  dsc "LINES"
            db 0FFh
txt_keys1:  dsc "LEFT RIGHT"
            db 0FFh
txt_keys2:  dsc "OR  Z  X"
            db 0FFh

; ----------------------------------------------------------------------
; variables
ballx:   dw 0
bally:   dw 0
vx:      dw 0
vy:      dw 0
newp:    dw 0
angle:   db 0
keys:    db 0
phase:   db 0
cphase:  db 0
sfxt:    db 0
sfxdiv:  dw 0
seed:    dw 0ACE1h
lastctr: dw 0
lines:   dw 0
fields:  db 0
Ux:      dw 0
Uy:      dw 0
Vx:      dw 0
Vy:      dw 0
V2x:     dw 0
V2y:     dw 0
RTx:     dw 0
RTy:     dw 0
U49x:    dw 0
U49y:    dw 0
lclass:  db 0
listang: db 0FFh
spsave:  dw 0
outptr:  dw 0
rowcnt:  db 0

    include "../build/gen_maze.inc"
    include "../build/gen_tables.inc"
end_of_code:
    assert end_of_code < MAP_PAGE*256
