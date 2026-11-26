; =====================================================================
;  text.asm - LUMEN's words.  Messages: % creature, & item, # number,
;  ~ big number, @ the chosen spell.  Codes 1-7 in page text set colours.
; =====================================================================

; ---------------------------------------------------------------- front end
s_sub1:     db "A ROGUELIKE OF LIGHT AND SHADOW",0
s_sub2:     db "Carry the last lantern into the deep",0
s_keys1:    db "CURSORS/QAOP MOVE  1-6 SPELL  SPACE CAST",0
s_keys2:    db "H HEAL M MANA B BOMB T TELEPORT R MAP",0
s_keys3:    db "W WAIT   CR PAUSE   BREAK QUIT",0
s_start:    db "PRESS SPACE TO DESCEND",0
s_credit:   db "MZ-700 2026",0
s_bestiary: db "THE CREATURES OF THE DEEP",0
s_best2:    db "Some hide in the dark. Light finds them.",0
s_records:  db "THE LANTERN BEARERS",0
s_rechead:  db "NAME   SCORE  LV  ZONES",0
s_newrec:   db "YOUR NAME WILL BE REMEMBERED",0
s_typename: db "Type three letters, RETURN to end",0
s_score:    db "SCORE ",0
s_level:    db "LEVEL ",0
s_kills:    db "SLAIN ",0
s_turns:    db "TURNS ",0

; ---------------------------------------------------------------- folk (34 columns)
t_hermit1:
        db "Light! I had forgotten its colour.",0
        db "Take this prayer of healing:",0
        db "press 4 to choose it, SPACE to",0
        db "cast it. Two roads lead down from",0
        db "here - the grotto and the halls.",0
        db 0
t_hermit2:
        db "The plates in the crypt vault",0
        db "want weight upon them. Boulders",0
        db "will do. Push, don't pull!",0
        db 0
t_trader:
        db "Spores and coin, coin and spores.",0
        db "What will you have, bright one?",0
        db 0
t_sage1:
        db "Cold is only slow fire. Take",0
        db "FROST (key 2): it turns water",0
        db "into ice you can walk on, and",0
        db "lava into stone.",0
        db 0
t_sage2:
        db "The island vault lies across the",0
        db "deep pool. Freeze yourself a",0
        db "path to it.",0
        db 0
t_smith:
        db "Iron for gold. Fair trade, even",0
        db "down here in the dark.",0
        db 0
t_seer1:
        db "Rest. You are mended.",0
        db "On the ice you cannot stop until",0
        db "something stops you. Think first.",0
        db 0
t_seer2:
        db "Rest again. The Frost Sigil",0
        db "waits beyond the frozen hall.",0
        db 0
t_ghost1:
        db "Few come to read any more. Take",0
        db "BLINK (key 5) and step through.",0
        db "Every lever moves every gate.",0
        db "The sealed door wants all three",0
        db "sigils: Ember, Frost and Shadow.",0
        db 0
t_ghost2:
        db "Shades fear a strong light. A",0
        db "FLARE will show them - and burn",0
        db "them too.",0
        db 0
t_oracle1:
        db "You are mended, and you may call",0
        db "the LIGHTNING now (key 6).",0
        db "Turn the mirrors so the sun's",0
        db "beam strikes the eye of the gate.",0
        db 0
t_oracle2:
        db "He waits beyond the beam's gate.",0
        db "He drinks light: keep your",0
        db "lantern fed.",0
        db 0
t_shophelp:
        db "Keys 1-5 buy. SPACE to leave.",0

; ---------------------------------------------------------------- messages
msg_ambush:     db "The % wakes!",0
msg_mmiss:      db "The % misses.",0
msg_mhit:       db "The % hits you for #.",0
msg_poisoned:   db "You are poisoned!",0
msg_drain:      db "It drinks your lantern oil!",0
msg_kill:       db "The % dies.",0
msg_spores:     db "You breathe the spores!",0
msg_miss:       db "You miss the %.",0
msg_hit:        db "You hit the % for #.",0
msg_gold:       db "You find ~ gold.",0
msg_found:      db "You find: &.",0
msg_sigil:      db "The & is yours!",0
msg_learn:      db "You learn @!",0
msg_wield:      db "You wield the &.",0
msg_wear:       db "You wear the &.",0
msg_sell:       db "A worse &: you keep ~ gold.",0
msg_drink:      db "You feel better.",0
msg_mana:       db "Your magic returns.",0
msg_mapped:     db "The zone's plan fills your mind.",0
msg_tele:       db "Space folds around you.",0
msg_none:       db "You have none.",0
msg_unknown:    db "You do not know that spell.",0
msg_water:      db "The water is deep and cold.",0
msg_lava:       db "That would be the end of you.",0
msg_trap:       db "A spike trap!",0
msg_unlock:     db "The key turns.",0
msg_locked:     db "Locked. You need a key.",0
msg_sealed:     db "Three sigil sockets, waiting.",0
msg_sealopen:   db "The three sigils blaze: the seal opens!",0
msg_web:        db "You tear the web apart.",0
msg_fountain:   db "The fountain's water heals you.",0
msg_altar:      db "An old altar, cold and empty.",0
msg_setstone:   db "You set down the sun-stone. It blazes.",0
msg_takestone:  db "You lift the sun-stone: day in hand!",0
msg_pedestal:   db "An empty stand, shaped for a stone.",0
msg_ldoor:      db "Dark glass. Only still light opens it.",0
msg_dark:       db "Your lantern gutters. Find oil!",0
msg_lowoil:     db "Your lantern burns low.",0
msg_level:      db "You feel stronger!",0
msg_paused:     db "Paused - press a key.",0
msg_quit:       db "Abandon this descent? (Y/N)",0
msg_nomp:       db "Not enough magic.",0
msg_aim:        db "Which way? (SPACE: never mind)",0
msg_healed:     db "Warm light knits your wounds.",0
msg_bolthit:    db "A bolt strikes you!",0
msg_spellhit:   db "The spell hits the % for #.",0
msg_zapped:     db "Lightning strikes the % for #.",0
msg_blast:      db "The blast hits the % for #.",0
msg_gate:       db "Somewhere, a gate grinds open.",0
msg_brazier:    db "The brazier roars into flame.",0
msg_stuck:      db "It will not move.",0
msg_lever:      db "Clunk. Gates shift.",0
msg_beam:       db "The sun's beam strikes the eye!",0
msg_full:       db "You cannot carry more.",0
msg_poor:       db "You cannot afford it.",0
