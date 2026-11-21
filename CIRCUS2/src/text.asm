; =====================================================================
;  text.asm - strings (ASCII, mapped to display codes by ATOD)
; =====================================================================

; in play
txt_demo:       db "DEMO - PRESS ANY KEY",0
txt_act:        db "ACT ",0
txt_time:       db "TIME ",0
txt_bonus:      db "BONUS",0
txt_encore:     db " * ENCORE! * ",0
txt_boing:      db "BOING!",0
txt_ouch:       db "OUCH!",0
txt_bonk:       db "BONK!",0
txt_perfect:    db "PERFECT!",0
txt_streak:     db "STREAK ",0
txt_clang:      db "CLANG",0
txt_rowclear:   db "ROW CLEAR!",0
txt_extralife:  db "EXTRA LIFE!",0
txt_hot:        db "HOT!",0
txt_hoop:       db "HOOP!",0
txt_splat:      db "SPLAT!",0
txt_pied:       db "PIED!",0
txt_ook:        db "OOK OOK!",0
txt_wide:       db "WIDE!",0
txt_slow:       db "SLOW-MO",0
txt_net:        db "SAFETY NET",0
txt_x2:         db "DOUBLE!",0
txt_umb:        db "UMBRELLA",0
txt_fire:       db "FIREWORKS",0
txt_1up:        db "1UP!",0
txt_paused:     db "PAUSED",0
txt_pausehelp:  db "P PLAY  S SOUND  Q QUIT",0
txt_bravo:      db "BRAVO!",0
txt_timeup:     db "TIME UP!",0
txt_nomiss:     db "NO FALLS +5000",0
txt_popped:     db "POPPED ",0
txt_gameover:   db "GAME OVER",0
txt_gameover2:  db "THE CLOWNS NEED A NAP",0

; title messages
txt_press:      db "PRESS SPACE TO START",0
txt_hi:         db "HI ",0
txt_sound:      db "S  SOUND: ",0
txt_on:         db "ON",0
txt_off:        db "OFF",0
txt_diff:       db "D  LEVEL: ",0
txt_easy:       db "EASY",0
txt_normal:     db "NORMAL",0
txt_hard:       db "HARD",0
txt_joy:        db "J  JOYSTICK: ",0
txt_jstick:     db "STICK",0
txt_jpaddle:    db "PADDLE",0
txt_tkeys:      db "Z X MOVE   SPACE FLIP   P PAUSE",0
txt_credit:     db "VIBED BY BPM 2026",0
txt_machine:    db "FOR THE SHARP MZ-700",0

; ---------------------------------------------------------------- how to play (blue)
txt_howto:      db "HOW TO PLAY",0
howto_lines:
        db 7,WHITE*16+BLUE,"SLIDE THE SEESAW: Z / X OR CURSOR KEYS",0
        db 9,CYAN*16+BLUE,"SPACE, CR OR CURSOR UP FLIPS IT",0
        db 11,YELLOW*16+BLUE,"CATCH THE CLOWN ON THE HIGH END",0
        db 12,YELLOW*16+BLUE,"LAND ON THE TIP: SUPER JUMP!",0
        db 14,WHITE*16+BLUE,"HOLD LEFT OR RIGHT AS HE LANDS TO STEER",0
        db 16,GREEN*16+BLUE,"POP EVERY BALLOON TO WIN THE ACT",0
        db 18,CYAN*16+BLUE,"P PAUSE    S SOUND    Q QUIT",0
        db 0FFh
; a seesaw with a clown flying off it (row, col, char, attr)
howto_pic:
        db 20,15,70h,WHITE*16+BLUE
        db 19,16,3Ch,WHITE*16+BLUE
        db 19,17,7Ch,WHITE*16+BLUE
        db 19,18,38h,WHITE*16+BLUE
        db 19,19,78h,WHITE*16+BLUE
        db 19,20,34h,WHITE*16+BLUE
        db 19,21,74h,WHITE*16+BLUE
        db 20,17,4Eh,WHITE*16+BLUE
        db 20,18,43h,WHITE*16+BLUE
        db 20,19,4Dh,WHITE*16+BLUE
        db 18,15,41h,RED*16+BLUE
        db 19,15,44h,WHITE*16+BLUE+80h
        db 20,24,41h,RED*16+BLUE
        db 21,24,45h,WHITE*16+BLUE+80h
        db 21,26,47h,YELLOW*16+BLUE
        db 22,26,35h,CYAN*16+BLUE
        db 21,28,47h,RED*16+BLUE
        db 22,28,35h,CYAN*16+BLUE
        db 21,12,6Bh,YELLOW*16+BLUE
        db 0FFh

; ---------------------------------------------------------------- goodies (magenta)
txt_goodies:    db "GOODIES",0
goodies_lines:
        db 21,CYAN*16+BLACK,"CATCH GOODIES ON THE PLANK, OR GRAB",0
        db 22,CYAN*16+BLACK,"THEM IN MID-AIR",0
        db 0FFh
TOKB            equ BLACK*16+YELLOW+80h
goodies_icons:
        db 7,2,17h,TOKB
        db 9,2,13h,TOKB
        db 11,2,0Eh,TOKB
        db 13,2,22h,TOKB
        db 15,2,15h,TOKB
        db 17,2,06h,TOKB
        db 19,2,21h,TOKB
        db 7,22,8Fh,YELLOW*16+BLACK+80h
        db 9,22,9Dh,RED*16+BLACK+80h
        db 11,22,84h,WHITE*16+BLACK+80h
        db 13,22,3Eh,YELLOW*16+BLACK+80h
        db 15,22,49h,YELLOW*16+BLACK+80h
        db 17,21,68h,RED*16+BLACK
        db 17,23,69h,RED*16+BLACK
        db 0FFh
goodies_text:
        db 7,4,WHITE*16+BLACK,"WIDE SEESAW",0
        db 9,4,WHITE*16+BLACK,"SLOW MOTION",0
        db 11,4,WHITE*16+BLACK,"SAFETY NET",0
        db 13,4,WHITE*16+BLACK,"DOUBLE POINTS",0
        db 15,4,WHITE*16+BLACK,"UMBRELLA",0
        db 17,4,WHITE*16+BLACK,"FIREWORKS",0
        db 19,4,WHITE*16+BLACK,"EXTRA LIFE",0
        db 7,25,YELLOW*16+BLACK,"GIFT: A GOODY",0
        db 9,25,YELLOW*16+BLACK,"BOMB: KABOOM",0
        db 11,25,YELLOW*16+BLACK,"STEEL: 2 HITS",0
        db 13,25,YELLOW*16+BLACK,"GOLD: 500",0
        db 15,25,YELLOW*16+BLACK,"MONKEY: 250",0
        db 17,25,YELLOW*16+BLACK,"HOOP: 300",0
        db 0FFh

; ---------------------------------------------------------------- top clowns (black)
txt_topclowns:  db "TOP CLOWNS",0

; ---------------------------------------------------------------- coming up (green)
txt_comingup:   db "COMING UP",0
preview_lines:
        db 20,YELLOW*16+BLUE,"AND THEN... THE GRAND FINALE!",0
        db 0FFh
preview_icons:
        db 10,9,49h,YELLOW*16+BLUE+80h
        db 16,9,3Eh,YELLOW*16+BLUE+80h
        db 0FFh
preview_text:
        db 7,13,WHITE*16+BLUE,"RING OF FIRE",0
        db 10,13,WHITE*16+BLUE,"MONKEY BUSINESS",0
        db 13,13,WHITE*16+BLUE,"BOMBS AWAY!",0
        db 16,13,WHITE*16+BLUE,"BONUS ROUNDS",0
        db 0FFh

; ---------------------------------------------------------------- name entry (blue)
txt_newhigh:    db "HIGH SCORE!",0
entry_lines:
        db 7,WHITE*16+BLUE,"ENTER YOUR NAME",0
        db 9,CYAN*16+BLUE,"TYPE THREE LETTERS, CR WHEN DONE",0
        db 18,CYAN*16+BLUE,"OR CURSOR UP/DOWN AND SPACE",0
        db 0FFh
