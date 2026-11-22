; =====================================================================
;  text.asm - strings (ASCII; 01h-07h inside = colour change)
; =====================================================================

txt_credit:     db "MZ-700 VERSION  2026  VIBED BY BPM",0
txt_press:      db "PRESS SPACE TO START",0
txt_best:       db "HIGH SCORE ",0
txt_startcave:  db "START IN CAVE ",0
txt_joyoff:     db "J  JOYSTICK OFF",0
txt_joyon:      db "J  JOYSTICK ON ",0

scroll_text:
        db "                                        "
        db "UNDERMINED - A CAVE DIGGING GAME FOR THE MZ-700.    "
        db "DEEP UNDER THE MOUNTAIN LIE TWENTY-SIX CAVES IN SEVEN WINGS - THE SHALLOWS, THE FIREFLY DEEPS, "
        db "THE MAGIC HALLS, THE GREEN CAVERNS, THE CORE, THE CRYSTAL VAULTS AND THE HAUNTED DEEP... EACH WITH ITS OWN STONE.  "
        db "BETWEEN THE WINGS LIE SIX HIDDEN CHAMBERS FULL OF GEMS - A DASH THAT COSTS NO LIFE.  "
        db "THE CAVES ARE BIGGER THAN THE SCREEN - WANDER TO THE EDGE AND THE VIEW FOLLOWS YOU.  "
        db "DIG THROUGH THE EARTH, GATHER ENOUGH GEMS TO OPEN THE EXIT, AND GET OUT BEFORE THE CLOCK RUNS DOWN.    "
        db "BOULDERS FALL WHEN YOU DIG BENEATH THEM AND ROLL OFF ANYTHING ROUND.  "
        db "FIREFLIES EXPLODE AT A TOUCH - DROP A ROCK ON THEM.  "
        db "BUTTERFLIES BURST INTO NINE DIAMONDS.  "
        db "THE GREEN AMOEBA GROWS: TRAP IT AND IT TURNS TO GEMS, LET IT RUN WILD AND IT TURNS TO STONE.  "
        db "THE MAGIC WALL TURNS FALLING ROCKS INTO DIAMONDS - FOR A WHILE.  "
        db "DEEPER DOWN: CRACK GEODES WITH FALLING ROCKS, WATCH ROCKS SEEP THROUGH SLIME, FIND THE KEY THAT OPENS EVERY LOCK... "
        db "AND BEWARE THE SHADES, WHO FOLLOW YOUR TUNNELS. A FALLING ROCK SENDS THEM BACK AS GEMS.    "
        db "CURSOR KEYS OR Q A O P TO DIG.  HOLD SPACE TO GRAB WITHOUT MOVING.  "
        db "LEFT AND RIGHT ON THIS SCREEN CHOOSE THE STARTING CAVE.  "
        db "J SWITCHES ON AN MZ-1X03 JOYSTICK IN PORT 1 - EITHER BUTTON GRABS.  "
        db "CR PAUSES, BREAK GIVES UP.        ",0

txt_guide:      db "- W H A T   L I E S   B E L O W -",0
gt_diamond:     db "DIAMOND",0
gd_diamond:     db "GATHER TO OPEN EXIT",0
gt_boulder:     db "BOULDER",0
gd_boulder:     db "FALLS, ROLLS, PUSHES",0
gt_earth:       db "EARTH",0
gd_earth:       db "DIG THROUGH IT",0
gt_firefly:     db "FIREFLY",0
gd_firefly:     db "DEADLY - CRUSH IT",0
gt_butterfly:   db "BUTTERFLY",0
gd_butterfly:   db "CRUSH IT FOR GEMS",0
gt_amoeba:      db "AMOEBA",0
gd_amoeba:      db "TRAP IT FOR GEMS",0
gt_magic:       db "MAGIC WALL",0
gd_magic:       db "ROCKS IN, GEMS OUT",0
gt_exit:        db "EXIT",0
gd_exit:        db "FLASHES WHEN OPEN",0
gt_spout:       db "SPOUT",0
gd_spout:       db "RAINS GEMS - AND ROCKS",0

wing_names:     dw wing_1,wing_2,wing_3,wing_4,wing_5,wing_6,wing_7,wing_b
wing_1:         db "WING I   THE SHALLOWS",0
wing_2:         db "WING II   FIREFLY DEEPS",0
wing_3:         db "WING III   MAGIC HALLS",0
wing_4:         db "WING IV   GREEN CAVERNS",0
wing_5:         db "WING V   THE CORE",0
wing_6:         db "WING VI   CRYSTAL VAULTS",0
wing_7:         db "WING VII   THE HAUNTED DEEP",0
wing_b:         db "A HIDDEN CHAMBER",0

guide_ctl:
        db 6,"CURSOR / Q A O P ",7,"MOVE AND DIG",0
        db 6,"SPACE + DIRECTION ",7,"GRAB, STAY PUT",0
        db 6,"CR ",7,"PAUSE   ",6,"BREAK ",7,"GIVE UP",0
        db 0FFh

txt_hiscores:   db "- D E E P E S T   D I G G E R S -",0
txt_hshead:     db "  NAME  SCORE       CAVE",0
txt_entername:  db "NEW HIGH SCORE - ENTER YOUR NAME",0
txt_enterhelp:  db "UP/DOWN LETTER   SPACE NEXT",0
txt_welldone:   db "WELL DUG!",0

hiscore_default:
        db "BPM", 00h,50h,02h, 8,0
        db "MZ7", 00h,00h,02h, 6,0
        db "DIG", 00h,50h,01h, 5,0
        db "GEM", 00h,00h,01h, 3,0
        db "ROK", 00h,50h,00h, 2,0
        db "AMB", 00h,30h,00h, 1,0
        db "FLY", 00h,20h,00h, 1,0
        db "MAG", 00h,10h,00h, 0,0

txt_gameover:   db "GAME  OVER",0
txt_finalscore: db "FINAL SCORE ",0

txt_time:       db "TIME",0
txt_cave:       db "CAVE ",0
txt_cave_big:   db "CAVE ",0
txt_guide2:     db "- D E E P E R   S T I L L -",0
gt_geode:       db "GEODE",0
gd_geode:       db "A FALLING ROCK OPENS IT",0
gt_slime:       db "SLIME",0
gd_slime:       db "ROCKS SEEP THROUGH",0
gt_key:         db "KEY",0
gd_key:         db "OPENS EVERY LOCK",0
gt_lock:        db "LOCK",0
gd_lock:        db "WAITS FOR THE KEY",0
gt_shade:       db "SHADE",0
gd_shade:       db "HUNTS YOU - CRUSH IT",0
guide2_ctl:
        db 6,"HIDDEN CHAMBERS ",7,"LIE BETWEEN THE WINGS:",0
        db 7,"A DASH FOR GEMS THAT ",6,"COSTS NO LIFE",0
        db 0FFh
txt_wings:      db "- T H E   S E V E N   W I N G S -",0
txt_wings_ft:   db "LEFT / RIGHT ON THE TITLE PICKS A WING",0
txt_story:
        db "DEEP UNDER THE MOUNTAIN LIE SEVEN",0
        db "WINGS OF CAVES, AND AT ITS HEART",0
        db "A TREASURE NO DIGGER HAS SEEN.",0
        db "MIND THE ROCKS. BEWARE THE SHADES.",0
        db 0FFh
txt_ending:
        db "THE HEART OF THE MOUNTAIN IS YOURS!",0
        db 0
        db "YOU CLIMB OUT INTO THE DAWN, BUT THE",0
        db "MOUNTAIN IS NOT DONE WITH YOU: ITS",0
        db "CAVES WAIT, DARKER AND FASTER.",0
        db 0FFh
txt_bonus_big:  db "BONUS ",0
txt_demo:       db "DEMO  -  PRESS ANY KEY",0
txt_collect:    db "COLLECT ",0
txt_diamonds:   db " DIAMONDS",0
txt_within:     db "WITHIN ",0
txt_seconds:    db " SECONDS",0
txt_lives:      db "LIVES ",0
txt_level:      db "   LEVEL ",0
txt_pressfire:  db "PRESS SPACE TO TRY AGAIN",0
txt_timeout:    db "OUT OF TIME!",0
txt_cleared:    db "CAVE CLEARED - TIME BONUS",0
txt_paused:     db "PAUSED - CR TO CONTINUE",0
