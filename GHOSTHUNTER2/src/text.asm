; =====================================================================
;  text.asm - strings (ASCII; 01h-07h inside = colour change)
; =====================================================================
s_ready:        db "READY!",0
s_timeup:       db "TIME UP!",0
s_gameover:     db "GAME OVER",0
s_paused:       db "PAUSED",0
s_super:        db "HUNTER!",0
s_power:        db "POWER",0
s_freeze:       db "FREEZE",0
s_speed:        db "SPEED",0
s_decoy:        db "DECOY",0
s_x2:           db "DOUBLE",0
s_shield:       db "SHIELD",0
s_buffet:       db "BUFFET",0
s_panic:        db "PANIC!",0
s_demo:         db "DEMO",0
s_bonus:        db "* BONUS ROUND *",0
s_bb1:          db "GHOST BUFFET!",0
s_bb2:          db "EAT ALL YOU CAN",0
s_pb1:          db "PELLET PANIC!",0
s_pb2:          db "CLEAR IT IN 25 SECONDS",0

s_tag:          db "- THE BOO-QUEL -",0
s_hiscore:      db "HI-SCORE ",0
tm0:            db "PRESS SPACE TO HUNT!",0
tm1:            db "ORIGINAL BY DUBOIS & MCNAMARA",0
tm2:            db "MZ-700 VERSION VIBED BY BPM 2026",0
tm3:            db "HAPPY HAUNTING!",0

s_meet:         db "M E E T   T H E   G H O S T S",0
s_meet_b:       db "THEY ALL TURN BLUE AFTER A POWER PILL",0
mg0:            db "GRUMBLE",0,"CHASES YOU. ALWAYS CROSS.",0
mg1:            db "SNEAKY",0,"CUTS YOU OFF UP AHEAD.",0
mg2:            db "DIZZY",0,"WANDERS ABOUT... MOSTLY.",0
mg3:            db "PEEKABOO",0,"NOW YOU SEE HIM, NOW...",0

s_pow:          db "P O W E R   U P !",0
pw0:            db "POWER PILL: EAT THE GHOSTS",0
pw1:            db "SPEED: ZOOM, LEAVE A TRAIL",0
pw2:            db "FREEZE: GHOSTS ON ICE",0
pw3:            db "DECOY: A DUMMY TO CHASE",0
pw4:            db "DOUBLE: TWICE THE POINTS",0
pw5:            db "SHIELD: SHRUG OFF ONE HIT",0
pw6:            db "EAT ALL 4: HUNTER MODE!",0
ctl1:           db "CURSOR KEYS OR Q A O P TO MOVE",0
ctl2:           db "CR PAUSE   S SOUND   BREAK QUIT",0
ctl3:           db "SPACE OR CR TO START",0

s_hof:          db "H A L L   O F   F A M E",0
s_play:         db "PRESS SPACE TO PLAY",0
ranks:          db "1ST",0,"2ND",0,"3RD",0,"4TH",0,"5TH",0
s_nhs:          db "NEW HI-SCORE!",0
s_ent:          db "ENTER YOUR INITIALS",0
s_enthelp:      db "UP/DOWN LETTER  SPACE NEXT  CR DONE",0

s_i1:           db "WHO'S HUNTING WHO?",0
s_i2:           db "THE NIGHT SHIFT",0
s_i2b:          db "GHOSTS... SO JUMPY!",0
