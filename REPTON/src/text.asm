; =====================================================================
;  text.asm - strings (ASCII, mapped to display codes by ATOD)
; =====================================================================

txt_piece:      db "A MOSAIC PIECE!",0
txt_crown:      db "A LOST CROWN!",0
txt_key:        db "THE SAFES SPRING OPEN",0
txt_blocked:    db "THE WAY IS BLOCKED",0
txt_opened:     db "OPENED: ",0
txt_sealed:     db "THE SUN GATE IS SEALED",0
txt_askquit:    db "GIVE UP THIS GAME? Y/N",0
txt_askreset:   db "RESTART THIS CAVERN? Y/N",0
txt_paused:     db "PAUSED - PRESS A KEY",0
txt_unknown:    db "? ? ?",0

; ---------------------------------------------------------------- title
title_lines:
        db 9,CYAN*16,"AND THE SUN MOSAIC",0
        db 15,WHITE*16,"PRESS SPACE TO PLAY",0
        db 21,MAGENTA*16,"ViBED by BPM  FOR THE SHARP MZ-700",0
        db 0FFh
txt_best:       db "BEST  ",0
txt_joy_off:    db "J  JOYSTICK OFF",0
txt_joy_on:     db "J  JOYSTICK ON ",0

scroll_text:
        db "                                        "
        db "DEEP BELOW THE SUNLIT HOLLOW LIES A REALM OF FOURTEEN CAVERNS ... "
        db "GATHER EVERY GEM, EVERY PIECE OF THE SHATTERED SUN MOSAIC, AND RID THE DARK OF EVERY "
        db "GLOOM BEAST ... THEN WALK THROUGH THE SUN GATE ... "
        db "CURSOR KEYS OR Q A O P TO MOVE ... SPACE FOR THE WORLD STATUS AND A HINT ... "
        db "R RESTARTS A CAVERN ... CR PAUSES ... BREAK GIVES UP ... J SWITCHES THE MZ-1X03 JOYSTICK ON OR OFF ... "
        db "ViBED by BPM ... ",0

; ---------------------------------------------------------------- story
txt_story_h:    db "THE TALE",0
story_lines:
        db 3,WHITE*16,"LONG AGO THE SUN MOSAIC LIT THE",0
        db 4,WHITE*16,"CAVERNS BENEATH THE SUNLIT HOLLOW.",0
        db 6,WHITE*16,"ONE DARK NIGHT IT SHATTERED INTO",0
        db 7,WHITE*16,"TWENTY-FOUR PIECES, AND THE GLOOM",0
        db 8,WHITE*16,"CREPT IN: EGGS OF HUNGRY BEASTS,",0
        db 9,WHITE*16,"RESTLESS SPIRITS AND CREEPING MOULD.",0
        db 11,YELLOW*16,"SKINK THE LIZARD MEANS TO PUT IT RIGHT.",0
        db 13,CYAN*16,"FIND EVERY GEM AND EVERY PIECE.",0
        db 14,CYAN*16,"CRUSH EVERY BEAST - EVEN THE UNHATCHED.",0
        db 15,CYAN*16,"THEN THE SUN GATE WILL OPEN.",0
        db 17,GREEN*16,"THE CAVERNS REMEMBER EVERYTHING YOU DO.",0
        db 0FFh

; ---------------------------------------------------------------- guide
txt_guide_h:    db "WHO IS WHO IN THE DEEP",0
guide_tab:
        db E_PLAYER : dw g_n0, g_d0
        db E_GEM : dw g_n1, g_d1
        db E_PIECE : dw g_n2, g_d2
        db E_CROWN : dw g_n3, g_d3
        db E_ROCK : dw g_n4, g_d4
        db E_EGG : dw g_n5, g_d5
        db E_MONSTER : dw g_n6, g_d6
        db E_SPIRIT0 : dw g_n7, g_d7
        db E_CAGE : dw g_n8, g_d8
        db E_SKULL : dw g_n9, g_d9
        db E_FUNGUS : dw g_n10, g_d10
        db E_KEY : dw g_n11, g_d11
        db E_SAFE : dw g_n12, g_d12
        db E_SWITCH : dw g_n13, g_d13
        db E_TRANS : dw g_n14, g_d14
        db E_GATE : dw g_n15, g_d15
g_n0:   db "SKINK",0
g_d0:   db "THAT IS YOU",0
g_n1:   db "GEM",0
g_d1:   db "TAKE THEM ALL",0
g_n2:   db "MOSAIC PIECE",0
g_d2:   db "24 TO FIND",0
g_n3:   db "CROWN",0
g_d3:   db "HIDDEN TREASURE",0
g_n4:   db "ROCK",0
g_d4:   db "FALLS AND ROLLS",0
g_n5:   db "EGG",0
g_d5:   db "DROP IT TO HATCH",0
g_n6:   db "GLOOM BEAST",0
g_d6:   db "CRUSH WITH ROCKS",0
g_n7:   db "SPIRIT",0
g_d7:   db "HUGS LEFT WALLS",0
g_n8:   db "CAGE",0
g_d8:   db "TRAPS A SPIRIT",0
g_n9:   db "SKULLS",0
g_d9:   db "DEADLY",0
g_n10:  db "MOULD",0
g_d10:  db "GROWS INTO SPACE",0
g_n11:  db "KEY",0
g_d11:  db "OPENS THE SAFES",0
g_n12:  db "SAFE",0
g_d12:  db "FULL OF GEMS",0
g_n13:  db "SWITCH",0
g_d13:  db "OPENS GATES",0
g_n14:  db "TRANSPORTER",0
g_d14:  db "TO FAR CAVERNS",0
g_n15:  db "SUN GATE",0
g_d15:  db "THE WAY HOME",0
guide_ctl:
        db 19,WHITE*16,"CURSOR KEYS OR Q A O P  MOVE AND DIG",0
        db 20,WHITE*16,"SPACE  WORLD STATUS AND HINTS",0
        db 21,WHITE*16,"R  RESTART THIS CAVERN   CR  PAUSE",0
        db 22,WHITE*16,"BREAK  GIVE UP    J (TITLE)  JOYSTICK",0
        db 0FFh

; ---------------------------------------------------------------- records
txt_rec_h:      db "THE GREATEST EXPLORERS",0
txt_rec_cols:   db "   NAME  DONE    TIME   DEATHS",0
txt_name_h:     db "A NEW RECORD - YOUR NAME?",0
txt_name_help:  db "UP DOWN LEFT RIGHT  -  SPACE WHEN DONE",0

; ---------------------------------------------------------------- status
txt_status_h:   db "THE WORLD BELOW",0
txt_status_cols: db "  CAVERN        GEM PC BST",0
txt_status_keys: db "PRESS ANY KEY TO PLAY ON",0
txt_alldone:    db " ALL IS GATHERED - GO TO THE SUN GATE! ",0
txt_gems:       db "GEMS   ",0
txt_pieces:     db "PIECES ",0
txt_mons:       db "BEASTS ",0
txt_crowns:     db "CROWNS ",0
txt_time:       db "TIME ",0
txt_deaths:     db "DEATHS ",0

; ---------------------------------------------------------------- ending
txt_end_h:      db "THE SUN RISES AGAIN",0
end_lines:
        db 13,YELLOW*16,"THE SUN MOSAIC IS WHOLE ONCE MORE",0
        db 14,WHITE*16,"AND LIGHT FILLS THE CAVERNS.",0
        db 15,GREEN*16,"WELL DONE, SKINK!",0
        db 22,MAGENTA*16,"ViBED by BPM",0
        db 0FFh
