; =====================================================================
;  data.asm - tables and text
; =====================================================================

; ---- object types: glyph 0, glyph 1, attribute (bit 7 = ROM bank 2,
;      foreground, blue background), flags, score (BCD lo, hi), score/25,
;      particles when destroyed
DEAD_SHOT equ F_DEADLY|F_SHOOT|F_SOLID
tinfo:
        db 30h,31h, 0A1h, DEAD_SHOT|F_COUNT,  00h,01h,  4,5   ; droid    100
        db 0B3h,0B3h,0E1h, DEAD_SHOT,         25h,00h,  1,3   ; pylon     25
        db 0F5h,0F6h,0C1h, F_DEADLY|F_PUSH|F_SOLID, 0,0, 0,0  ; crusher
        db 38h,39h, 0B1h, DEAD_SHOT|F_COUNT,  00h,05h, 20,8   ; mindbot  500
        db 34h,35h, 0D1h, DEAD_SHOT|F_COUNT|F_ANIM, 00h,01h, 4,5 ; mutant   100
        db 84h,3Eh, 0E1h, DEAD_SHOT|F_COUNT|F_ANIM, 00h,10h, 40,10 ; orb     1000
        db 1Dh,1Eh, 0E1h, DEAD_SHOT|F_COUNT,  50h,01h,  6,4   ; seeker   150
        db 0B1h,0B2h,0E1h, DEAD_SHOT|F_COUNT|F_ANIM, 00h,10h, 40,10 ; factory 1000
        db 1Bh,1Ch, 0F1h, DEAD_SHOT|F_COUNT,  00h,02h,  8,8   ; tank     200
        db 43h,45h, 0B1h, F_HUMAN|F_SOLID,    0,0,      0,0   ; mom
        db 44h,45h, 0D1h, F_HUMAN|F_SOLID,    0,0,      0,0   ; dad
        db 44h,43h, 0E1h, F_HUMAN|F_SOLID,    0,0,      0,0   ; kid
        db 81h,81h, 0F1h, 0,                  0,0,      0,0   ; skull
        db 0,0,     61h,  0,                  0,0,      0,0   ; pop-up
        db 0B3h,0EEh,0F1h, 0,                 0,0,      0,0   ; explosion
        db 0B5h,08Fh,0E1h, F_SOLID|F_ANIM,    0,0,      0,0   ; pickup

pyloncols:                      ; never red or green (droids, crushers)
        db 0F1h,0B1h,0E1h,0D1h
matglyph:
        db 0EFh,0EEh,0B3h,0EEh
cyctab:                         ; colour cycle for orbs and factories
        db 0A1h,0E1h,0F1h,0D1h,0C1h,0B1h,0D1h,0F1h
ebglyph:                        ; enemy bullets: char, attribute
        db 46h,61h              ; spark: yellow cross
        db 3Fh,0A1h             ; missile: red rocket (bank 2)
        db 47h,71h              ; shell: white ball

; ---- waves: droids, pylons, crushers, mindbots, orbs, factories,
;             moms, dads, kids, droid step delay, formation
; formation: bits 0-1 pylons (0 scattered, 1 ring, 2 corridors, 3 grid),
;            bit 2 droids start round the edges
NWAVES  equ 40
W_DELAY equ 9
W_FORM  equ 10
spawn_types:
        db T_DROID, T_PYLON, T_CRUSH, T_BRAIN, T_ORB, T_FACT, T_MOM, T_DAD, T_KID
wavetab:
        db 15, 5, 0, 0, 0, 0, 1, 1, 1, 7, 0   ; 1
        db 17, 8, 3, 0, 1, 0, 2, 1, 1, 6, 0   ; 2
        db 22,10, 4, 0, 1, 0, 2, 2, 2, 6, 0   ; 3
        db 18, 0,10, 0, 2, 0, 3, 2, 2, 6, 0   ; 4  crusher wave
        db 14, 5, 3, 7, 0, 0, 3, 3, 3, 6, 0   ; 5  mindbot wave
        db 29,10, 3, 0, 2, 0, 2, 2, 2, 5, 0   ; 6
        db 10, 4, 3, 0, 0, 4, 2, 2, 2, 5, 0   ; 7  tank wave
        db 28,12, 4, 0, 2, 0, 2, 1, 1, 5, 1   ; 8  pylon ring
        db 24, 0,12, 0, 2, 0, 3, 3, 3, 5, 0   ; 9  crusher wave
        db 14, 6, 3,10, 0, 0, 3, 3, 4, 5, 0   ; 10 mindbot wave
        db 32,10, 4, 0, 3, 0, 1, 1, 1, 4, 4   ; 11 droids all round
        db 12, 4, 3, 0, 0, 5, 2, 2, 2, 4, 0   ; 12 tank wave
        db 28,12, 5, 0, 3, 0, 1, 1, 1, 4, 2   ; 13 corridors
        db 24, 0,14, 0, 2, 0, 3, 3, 3, 4, 0   ; 14 crusher wave
        db 14, 7, 3,12, 0, 0, 3, 3, 4, 4, 0   ; 15 mindbot wave
        db 32,12, 4, 0, 3, 0, 1, 1, 1, 3, 3   ; 16 grid
        db 14, 5, 3, 0, 0, 6, 2, 2, 2, 3, 0   ; 17 tank wave
        db 30,11, 5, 0, 3, 0, 1, 1, 1, 3, 0   ; 18
        db 24, 0,16, 0, 3, 0, 3, 3, 3, 3, 0   ; 19 crusher wave
        db 16, 7, 3,14, 0, 0, 3, 3, 4, 3, 0   ; 20 mindbot wave
        ; ---- the second twenty
        db 30,14, 0, 0, 0, 0, 2, 2, 2, 3, 1   ; 21 ring
        db 20, 0, 8, 6, 0, 0, 3, 3, 3, 3, 0   ; 22 mindbots + crushers
        db 24, 8, 3, 0, 2, 3, 2, 2, 2, 3, 2   ; 23 corridors, tanks
        db 40, 0, 0, 0, 0, 0, 2, 2, 2, 3, 4   ; 24 droids all round
        db 10,16, 4, 8, 0, 0, 3, 3, 4, 3, 3   ; 25 grid, mindbots
        db 26,10, 6, 0, 3, 0, 2, 2, 2, 3, 1   ; 26 ring, orbs
        db 12, 6, 3, 0, 0, 7, 2, 2, 2, 3, 0   ; 27 tank wave
        db 28,12, 0, 0, 2, 0, 2, 2, 2, 2, 6   ; 28 corridors, droids all round
        db 20, 0,16, 0, 2, 0, 3, 3, 3, 2, 0   ; 29 crusher wave
        db 12, 8, 4,12, 2, 2, 3, 3, 4, 2, 3   ; 30 grid, everything
        db 36,12, 4, 0, 0, 0, 2, 2, 2, 2, 5   ; 31 ring, droids all round
        db 16, 6, 3, 0, 0, 8, 2, 2, 2, 2, 2   ; 32 corridors, tanks
        db 24, 8, 3, 4, 2, 0, 2, 2, 2, 2, 0   ; 33
        db 26, 0,18, 0, 0, 0, 3, 3, 3, 2, 4   ; 34 crushers, droids all round
        db 14,10, 3,16, 0, 0, 3, 3, 4, 2, 1   ; 35 ring, mindbots
        db 40,16, 0, 0, 0, 0, 1, 1, 1, 2, 3   ; 36 grid, droid swarm
        db 14, 6, 3, 0, 2, 4, 2, 2, 2, 2, 0   ; 37 orbs and tanks
        db 28,10, 5, 0, 2, 0, 2, 2, 2, 2, 6   ; 38 corridors, droids all round
        db 24, 0,20, 0, 3, 0, 3, 3, 3, 2, 0   ; 39 crusher wave
        db 14, 8, 3, 8, 1, 2, 3, 3, 3, 2, 1   ; 40 the last stand

; ---- easing in.  Per stage (all in 50 Hz ticks): added droid delay (x6),
; fastest droid step, droid speed-up interval / 2, crusher step, mindbot
; step, mutant step, tank step, extra fire delay
E_DADD  equ 0
E_DMIN  equ 1
E_DINT  equ 2
E_CRUSH equ 3
E_BRAIN equ 4
E_MUT   equ 5
E_TANK  equ 6
E_FIRE  equ 7
ease_tab:
        db 0, 12, 100, 18, 12, 4, 24,  0     ; 0: wave 11 on
        db 1, 18, 133, 24, 16, 6, 30, 20     ; 1: waves 6-10
        db 2, 18, 143, 24, 18, 7, 34, 40     ; 2: waves 3-5
        db 2, 36, 250, 30, 22, 8, 40, 60     ; 3: waves 1-2

; ---- directions 1 U, 2 UR, 3 R, 4 DR, 5 D, 6 DL, 7 L, 8 UL (0 none)
; key bits 0 up, 1 down, 2 left, 3 right -> direction
dirtab: db 0,1,5,0, 7,8,6,7, 3,2,4,3, 0,1,5,0
sdxtab: db 0, 0,1,1,1, 0,-1,-1,-1
sdytab: db 0,-1,-1,0,1, 1,1,0,-1
shotch: db 0, 79h,76h,78h,77h, 79h,76h,78h,77h

; enemy bullet velocities (1/256 cell per tick) for directions 0 U .. 7 UL
BVDIR   MACRO s, d
        db 0,(-s)&255, d,(-d)&255, s,0, d,d, 0,s, (-d)&255,d, (-s)&255,0, (-d)&255,(-d)&255
        ENDM
bvtab:
        BVDIR 72, 51            ; spark
        BVDIR 46, 33            ; missile
        BVDIR 84, 60            ; shell

; ---------------------------------------------------------------------
s_w:        db "W",0
s_hi:       db "HI",0
s_wave:     db "WAVE ",0
s_cleared:  db " CLEAR",0
s_bonus:    db "FULL FAMILY BONUS 5000",0
s_gameover: db "GAME OVER",0
s_paused:   db "- PAUSED -",0
s_blank9:   db "          ",0
s_sub_first: db "SAVE THE LAST HUMAN FAMILY!",0
s_sub_crush: db "CRUSHERS! THEY CAN'T BE STOPPED",0
s_sub_brain: db "MINDBOTS ARE HUNTING HUMANS",0
s_sub_tank:  db "TANK FACTORIES INBOUND",0
s_sub_orb:   db "WATCH OUT FOR THE ORBS",0
s_sub_droid: db "THE DROIDS ARE COMING",0
s_sub_edge:  db "THEY'RE ALL AROUND YOU!",0
s_sub_ring:  db "ELECTRIC FENCE",0
s_sub_lines: db "CORRIDORS OF DOOM",0
s_sub_grid:  db "MINEFIELD",0
s_sub_last:  db "THE LAST STAND",0
s_demo:      db "DEMO",0
s_t:         db "T",0
s_shield:    db "SHIELD ",0
s_3way:      db "3-WAY  ",0
s_blank7:    db "       ",0
s_saved:     db "HUMANS SAVED: ",0
s_bigwave:   db "WAVE "
s_bigclear:  db "CLEAR!",0
s_biggame:   db "GAME OVER",0

; ---- default high scores: score (BCD, low byte first), initials, wave, -
hisc_init:
        db 00h,00h,05h, "BPM", 15, 0
        db 00h,00h,04h, "MZ7", 12, 0
        db 00h,00h,03h, "SHP", 10, 0
        db 00h,50h,02h, "ZAP",  8, 0
        db 00h,00h,02h, "BOT",  6, 0
        db 00h,50h,01h, "MOM",  5, 0
        db 00h,00h,01h, "DAD",  3, 0
        db 00h,50h,00h, "KID",  2, 0

        include "../build/gen_bigfont.inc"
