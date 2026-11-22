; =====================================================================
;  hud.asm - rows 0-2: scores, health bars, timer, names, round stars
;
;  Row 0: 1P score . . . . . . . . . . . . . . . . 2P score
;  Row 1: [P1 health, cols 1-17]  timer 18-21  [P2 health, cols 22-38]
;  Row 2: P1 name, stars           timer        stars, P2 name
;  The health left sits next to the timer (as damage eats in from the
;  outside).  2 pixels a step: HP 0-136 = 17 cells x 8.
; =====================================================================

HUD_BG  equ (BLUE*16)+BLUE
BAR_A   equ (YELLOW*16)+RED

hud_init:
        ld b,0
        ld c,3
        ld a,HUD_BG
        call clear_rows
        ; timer box
        ld de,VRAM+40+18
        ld b,4
        ld a,0
        ld c,(RED*16)+RED
        call fill_cells
        ld de,VRAM+80+18
        ld b,4
        ld a,0
        ld c,(RED*16)+RED
        call fill_cells
        ld hl,s_time
        ld de,VRAM+80+18
        ld c,(YELLOW*16)+RED
        call print
        ld hl,s_ko
        ld de,VRAM+40*0+19
        ld c,(WHITE*16)+RED
        call print
        ld a,0FFh
        ld (hud_hp1),a
        ld (hud_hp2),a
        ld (hud_time),a
        ld hl,0FFFFh
        ld (hud_sc1),hl
        ld (hud_sc2),hl
        call hud_names
        jp hud_update

; names and round stars
hud_names:
        ld iy,PL1
        call name_ptr
        ld de,VRAM+80+1
        ld c,(WHITE*16)+BLUE
        call print
        ld iy,PL2
        call name_ptr
        call str_len
        ld a,39
        sub b
        ld e,a
        ld d,0
        push hl
        ld hl,VRAM+80
        add hl,de
        ex de,hl
        pop hl
        ld c,(WHITE*16)+BLUE
        call print
hud_stars:
        ; P1 stars at cols 12,13; P2 at 26,27
        ld a,(PL1+P_WINS)
        ld de,VRAM+80+14
        call .st
        ld a,(PL2+P_WINS)
        ld de,VRAM+80+24
.st:    ld b,2
        ld c,a
.s:     ld a,c
        or a
        ld a,47h                ; a ball per round won
        ld l,(YELLOW*16)+BLUE
        jr nz,.on
        ld a,0
        ld l,HUD_BG
.on:    ld (de),a
        set 3,d
        ld a,l
        ld (de),a
        res 3,d
        inc de
        ld a,c
        or a
        jr z,$+3
        dec c
        djnz .s
        ret

; HL = name string of player IY
name_ptr:
        ld l,(iy+P_INFO)
        ld h,(iy+P_INFO+1)
        ld de,FI_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

hud_update:
        ; health bars
        ld a,(PL1+P_HP)
        ld hl,hud_hp1
        cp (hl)
        jr z,.h2
        ld (hl),a
        call bar1
.h2:    ld a,(PL2+P_HP)
        ld hl,hud_hp2
        cp (hl)
        jr z,.t
        ld (hl),a
        call bar2
.t:     ld a,(round_time)
        ld hl,hud_time
        cp (hl)
        jr z,.sc
        ld (hl),a
        call draw_time
.sc:    ld hl,(PL1+P_SC)
        ld de,(hud_sc1)
        or a
        sbc hl,de
        jr z,.sc2
        add hl,de
        ld (hud_sc1),hl
        ld de,VRAM+1
        call draw_score
.sc2:   ld hl,(PL2+P_SC)
        ld de,(hud_sc2)
        or a
        sbc hl,de
        ret z
        add hl,de
        ld (hud_sc2),hl
        ld de,VRAM+32
        jp draw_score

; score (HL = score / 10) as 6 digits with a trailing 0, at DE
draw_score:
        ld c,(YELLOW*16)+BLUE
        ld b,5
        call print_num
        ld a,20h
        jp putc

; P1 bar: cols 1-17, health right-aligned (next to the timer)
bar1:
        ld c,a                  ; hp
        ld de,VRAM+40+17        ; rightmost cell, going left
        ld b,17
.c:     ld a,c
        cp 8
        jr c,.part
        sub 8
        ld c,a
        ld a,43h
        ld l,BAR_A
        jr .put
.part:  srl a                   ; 2px steps
        add a,a
        push de
        ld e,a
        ld d,0
        ld hl,bar_r
        add hl,de
        pop de
        ld a,(hl)
        inc hl
        ld l,(hl)
        ld c,0
.put:   ld (de),a
        set 3,d
        ld a,l
        ld (de),a
        res 3,d
        dec de
        djnz .c
        ret
; yellow on the right: 0, 2, 4, 6 px
bar_r:  db 0,(RED*16)+RED, 3Fh,BAR_A, 3Bh,BAR_A, 37h,(RED*16)+YELLOW

; P2 bar: cols 22-38, health left-aligned
bar2:
        ld c,a
        ld de,VRAM+40+22
        ld b,17
.c:     ld a,c
        cp 8
        jr c,.part
        sub 8
        ld c,a
        ld a,43h
        ld l,BAR_A
        jr .put
.part:  srl a                   ; 2px steps
        add a,a
        push de
        ld e,a
        ld d,0
        ld hl,bar_l
        add hl,de
        pop de
        ld a,(hl)
        inc hl
        ld l,(hl)
        ld c,0
.put:   ld (de),a
        set 3,d
        ld a,l
        ld (de),a
        res 3,d
        inc de
        djnz .c
        ret
; yellow on the left: 0, 2, 4, 6 px
bar_l:  db 0,(RED*16)+RED, 37h,BAR_A, 7Bh,BAR_A, 3Fh,(RED*16)+YELLOW

; the timer: two bold ROM digits in a red box, cols 18-21, rows 1-2
draw_time:
        ld b,0
.d:     sub 10
        jr c,.u
        inc b
        jr .d
.u:     add a,10+20h
        ld c,a
        ld a,b
        add a,20h
        ld hl,VRAM+40+19
        ld (hl),a
        inc hl
        ld (hl),c
        ld hl,ARAM+40+19
        ld a,80h+(WHITE*16)+RED ; bank 1: the bold digits
        ld (hl),a
        inc hl
        ld (hl),a
        ret

hud_hp1: db 0
hud_hp2: db 0
hud_time: db 0
hud_sc1: dw 0
hud_sc2: dw 0
