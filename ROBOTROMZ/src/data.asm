; =====================================================================
;  data.asm - tables and text
; =====================================================================

; ---- object types: glyph 0, glyph 1, attribute (bit 7 = ROM bank 2,
;      foreground, blue background), flags, score (BCD lo, hi), score/25
DEAD_SHOT equ F_DEADLY|F_SHOOT|F_SOLID
tinfo:
        db 30h,31h, 0A1h, DEAD_SHOT|F_COUNT,  00h,01h,  4,0   ; droid    100
        db 0B3h,0B3h,0E1h, DEAD_SHOT,         25h,00h,  1,0   ; pylon     25
        db 0F5h,0F6h,0C1h, F_DEADLY|F_PUSH|F_SOLID, 0,0, 0,0  ; crusher
        db 38h,39h, 0B1h, DEAD_SHOT|F_COUNT,  00h,05h, 20,0   ; mindbot  500
        db 34h,35h, 0D1h, DEAD_SHOT|F_COUNT|F_ANIM, 00h,01h, 4,0 ; mutant   100
        db 84h,3Eh, 0E1h, DEAD_SHOT|F_COUNT|F_ANIM, 00h,10h, 40,0 ; orb     1000
        db 1Dh,1Eh, 0E1h, DEAD_SHOT|F_COUNT,  50h,01h,  6,0   ; seeker   150
        db 0B1h,0B2h,0E1h, DEAD_SHOT|F_COUNT|F_ANIM, 00h,10h, 40,0 ; factory 1000
        db 1Bh,1Ch, 0F1h, DEAD_SHOT|F_COUNT,  00h,02h,  8,0   ; tank     200
        db 43h,45h, 0B1h, F_HUMAN|F_SOLID,    0,0,      0,0   ; mom
        db 44h,45h, 0D1h, F_HUMAN|F_SOLID,    0,0,      0,0   ; dad
        db 44h,43h, 0E1h, F_HUMAN|F_SOLID,    0,0,      0,0   ; kid
        db 81h,81h, 0F1h, 0,                  0,0,      0,0   ; skull
        db 0,0,     61h,  0,                  0,0,      0,0   ; pop-up
        db 0B3h,0EEh,0F1h, 0,                 0,0,      0,0   ; explosion
        db 0,0,     71h,  0,                  0,0,      0,0   ; (spare)

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
;             moms, dads, kids, droid step delay
spawn_types:
        db T_DROID, T_PYLON, T_CRUSH, T_BRAIN, T_ORB, T_FACT, T_MOM, T_DAD, T_KID
wavetab:
        db 15, 5, 0, 0, 0, 0, 1, 1, 1, 7      ; 1
        db 17, 8, 3, 0, 1, 0, 2, 1, 1, 6      ; 2
        db 22,10, 4, 0, 1, 0, 2, 2, 2, 6      ; 3
        db 18, 0,10, 0, 2, 0, 3, 2, 2, 6      ; 4  crusher wave
        db 14, 5, 3, 7, 0, 0, 3, 3, 3, 6      ; 5  mindbot wave
        db 29,10, 3, 0, 2, 0, 2, 2, 2, 5      ; 6
        db 10, 4, 3, 0, 0, 4, 2, 2, 2, 5      ; 7  tank wave
        db 28,12, 4, 0, 2, 0, 2, 1, 1, 5      ; 8
        db 24, 0,12, 0, 2, 0, 3, 3, 3, 5      ; 9  crusher wave
        db 14, 6, 3,10, 0, 0, 3, 3, 4, 5      ; 10 mindbot wave
        db 32,10, 4, 0, 3, 0, 1, 1, 1, 4      ; 11
        db 12, 4, 3, 0, 0, 5, 2, 2, 2, 4      ; 12 tank wave
        db 28,12, 5, 0, 3, 0, 1, 1, 1, 4      ; 13
        db 24, 0,14, 0, 2, 0, 3, 3, 3, 4      ; 14 crusher wave
        db 14, 7, 3,12, 0, 0, 3, 3, 4, 4      ; 15 mindbot wave
        db 32,10, 4, 0, 3, 0, 1, 1, 1, 3      ; 16
        db 14, 5, 3, 0, 0, 6, 2, 2, 2, 3      ; 17 tank wave
        db 30,11, 5, 0, 3, 0, 1, 1, 1, 3      ; 18
        db 24, 0,16, 0, 3, 0, 3, 3, 3, 3      ; 19 crusher wave
        db 16, 7, 3,14, 0, 0, 3, 3, 4, 3      ; 20 mindbot wave

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
