; ======================================================================
;  hud.asm - screen frame, status panel, messages, frame timer
; ======================================================================

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
    ld hl,VRAM          ; solid frame round the view
    ld b,VIEW_CHARS+2
.top:
    ld (hl),43h
    inc hl
    djnz .top
    ld hl,VRAM+(VIEW_Y+VIEW_CHARS)*40
    ld b,VIEW_CHARS+2
.bot:
    ld (hl),43h
    inc hl
    djnz .bot
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
    ld hl,hud_text      ; (row, col, string) records, row FFh ends
.txt:
    ld a,(hl)
    cp 0FFh
    jr z,.cols
    inc hl
    push hl
    add a,a
    ld e,a
    ld d,0
    ld hl,ROW40
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld hl,VRAM+HUD_X
    add hl,de
    ex de,hl
    pop hl
    ld a,(hl)
    inc hl
    add a,e
    ld e,a
    ld a,0
    adc a,d
    ld d,a
    call print
    jr .txt
.cols:
    ld hl,CRAM+1*40+HUD_X       ; title: yellow
    ld a,60h
    call colour12
    ld hl,CRAM+21*40+HUD_X      ; key help: cyan
    ld a,50h
    call colour12
    ld hl,CRAM+22*40+HUD_X
    ld a,50h
    call colour12
    ld hl,CRAM+23*40+HUD_X
    ld a,50h
    jp colour12

colour12:               ; 14 cells (HUD width) at HL = A
    ld b,14
.c:
    ld (hl),a
    inc hl
    djnz .c
    ret

print:                  ; HL = display-code string (FFh end), DE = VRAM; HL ends past FFh
    ld a,(hl)
    inc hl
    cp 0FFh
    ret z
    ld (de),a
    inc de
    jr print

print_dec2:             ; A (0-99) as two digits at DE
    ld c,0
.l:
    cp 10
    jr c,.d
    sub 10
    inc c
    jr .l
.d:
    ld b,a
    ld a,c
    add a,20h
    ld (de),a
    inc de
    ld a,b
    add a,20h
    ld (de),a
    inc de
    ret

print_score:            ; 6 BCD digits at DE
    ld hl,score+2
    ld b,3
.l:
    ld a,(hl)
    rrca
    rrca
    rrca
    rrca
    and 0Fh
    add a,20h
    ld (de),a
    inc de
    ld a,(hl)
    and 0Fh
    add a,20h
    ld (de),a
    inc de
    dec hl
    djnz .l
    ret

set_msg:                ; copy message (FFh end, max 12 chars) to msgbuf
    ld de,msgbuf
.l:
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    cp 0FFh
    jr nz,.l
    ld a,1
    ld (msgdirty),a
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

hud:                    ; numbers are redrawn round-robin, a quarter per frame
    ld a,(framecnt)
    and 3
    jr z,.h0
    dec a
    jr z,.h1
    dec a
    jr z,.h2
    ld a,(shield)
    rrca
    rrca
    rrca
    and 1Fh
    ld de,VRAM+14*40+HUD_X+7
    call print_dec2
    jr .fps
.h0:
    ld de,VRAM+4*40+HUD_X+3
    call print_score
    jr .msg
.h1:
    ld a,(level)
    inc a
    ld de,VRAM+6*40+HUD_X+7
    call print_dec2
    ld a,(lives)
    ld de,VRAM+8*40+HUD_X+7
    call print_dec2
    jr .msg
.h2:
    ld a,(gems)
    ld de,VRAM+10*40+HUD_X+7
    call print_dec2
    ld a,(bombs)
    ld de,VRAM+12*40+HUD_X+7
    call print_dec2
    jr .msg
.fps:                   ; frames per second
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
    ld de,VRAM+19*40+HUD_X+7
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    ld a,(hl)
    ld (de),a
.msg:                   ; message line, redrawn when changed, rainbow every frame
    ld a,(msgdirty)
    or a
    jr z,.mcol
    xor a
    ld (msgdirty),a
    ld hl,VRAM+17*40+HUD_X
    ld b,14
.clr:
    ld (hl),0
    inc hl
    djnz .clr
    ld hl,msgbuf
    ld de,VRAM+17*40+HUD_X
    call print
.mcol:
    ld hl,CRAM+17*40+HUD_X
    ld a,(framecnt)
    ld c,a
    ld b,14
.mc:
    ld a,b
    add a,c
    and 7
    ld e,a
    ld d,hi(STRIP)
    ld a,(de)
    ld (hl),a
    inc hl
    djnz .mc
    ret

; frames-per-second for 0..7 fields per frame (display codes)
fps_tab:
    dsc "--50251612100807"

hud_text:               ; row, column offset, text
    db 1,1
    dsc "ROTOBALL"
    db 0FFh
    db 3,0
    dsc "SCORE"
    db 0FFh
    db 6,0
    dsc "LEVEL"
    db 0FFh
    db 8,0
    dsc "LIVES"
    db 0FFh
    db 10,0
    dsc "GEMS"
    db 0FFh
    db 12,0
    dsc "BOMBS"
    db 0FFh
    db 14,0
    dsc "SHIELD"
    db 0FFh
    db 19,0
    dsc "FPS"
    db 0FFh
    db 21,0
    dsc "LEFT RIGHT"
    db 0FFh
    db 22,0
    dsc "SPIN MAZE"
    db 0FFh
    db 23,0
    dsc "SPACE BOMB"
    db 0FFh
    db 0FFh

txt_demo1:  dsc "  DEMO  PLAY  "
            db 0FFh
txt_demo2:  dsc "              "
            db 0FFh
txt_demo3:  dsc " PRESS  SPACE "
            db 0FFh
txt_level:  dsc "LEVEL 00"
            db 0FFh
txt_go:     dsc "GO!"
            db 0FFh
txt_ready:  dsc "READY"
            db 0FFh
txt_splat:  dsc "SPLAT!"
            db 0FFh
txt_over:   dsc "GAME OVER"
            db 0FFh
txt_exit:   dsc "EXIT OPEN!"
            db 0FFh
txt_stomp:  dsc "SQUASHED!"
            db 0FFh
txt_bomb:   dsc "GOT A BOMB"
            db 0FFh
txt_shield: dsc "SHIELD ON"
            db 0FFh
txt_clear:  dsc "CLEARED!"
            db 0FFh
txt_boom:   dsc "KABOOM!"
            db 0FFh
