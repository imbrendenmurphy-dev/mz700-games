; =====================================================================
;  screens.asm - title / attract cycle, island screens, high scores,
;  and the game's text
; =====================================================================

FE_PAGES        equ 4               ; title, how to play, objects, high scores; then the demo

; returns when the player starts a game
front_end:
        xor a
        ld (autoplay),a
        ld (fe_page),a
        ld a,(start_island)
        or a
        jr nz,.si
        inc a
        ld (start_island),a
.si:    call fe_music
.page:  call fe_draw
        call fe_reset
.wait:  call wait_field
        call fe_keys
        bit B_FIRE,a
        jr nz,.go
        ld c,a
        ld a,(fe_page)
        or a
        jr nz,.nl
        bit B_LEFT,c
        call nz,fe_island_down
        bit B_RIGHT,c
        call nz,fe_island_up
.nl:    call getletter
        cp 'N'
        jr nz,.nm
        ld hl,lastletter
        cp (hl)
        jr z,.nm2
        ld (hl),a
        ld a,(music_off)
        xor 1
        ld (music_off),a
        call fe_music
        jr .nm2
.nm:    ld (lastletter),a
.nm2:   ld hl,(fe_t)
        dec hl
        ld (fe_t),hl
        ld a,h
        or l
        jr nz,.wait
        ld a,(fe_page)
        inc a
        ld (fe_page),a
        cp FE_PAGES
        jr c,.page
        call run_demo
        xor a
        ld (fe_page),a
        call fe_music
        jr .page
.go:    call wait_release
        call mus_stop
        ld hl,SONG_START
        ld a,(music_off)
        or a
        call z,mus_play
        ret

fe_music:
        call mus_stop
        ld a,(music_off)
        or a
        ret nz
        ld hl,SONG_TITLE
        jp mus_play

fe_island_down:
        ld a,(start_island)
        dec a
        ret z
        jr fe_island_set
fe_island_up:
        ld a,(best_island)
        ld c,a
        ld a,(start_island)
        cp c
        ret nc
        inc a
fe_island_set:
        ld (start_island),a
        ld hl,SFX_CURSOR
        ld a,1
        call sfx
        jp fe_island_line

fe_draw:
        ld a,(fe_page)
        or a
        jp z,title_page
        dec a
        jp z,howto_page
        dec a
        jp z,objects_page
        jp scores_page

; ---------------------------------------------------------------------
; title: a panorama, the big name, the start island
; ---------------------------------------------------------------------
title_page:
        ld hl,500
        ld (fe_t),hl
        ld a,BLACK
        call cls
        call panorama
        ; shadow then letters
        ld a,10h
        ld (tl_attr),a
        ld bc,1*256+9               ; B = row offset, C = col
        call big_title
        ld a,60h
        ld (tl_attr),a
        ld bc,0*256+8
        call big_title
        ld hl,TXT_SUB
        ld c,7
        ld a,50h
        call print_centre
        call fe_island_line
        ld hl,TXT_PRESS
        ld c,23
        ld a,70h
        call print_centre
        ld hl,TXT_CREDIT
        ld c,24
        ld a,10h
        jp print_centre

fe_island_line:
        ld bc,21*256+11
        call vaddr_bc
        ld hl,TXT_START
        ld c,70h
        call print
        ld a,(start_island)
        ld c,60h
        call print_dec2
        ld hl,TXT_START2
        ld c,70h
        jp print

; draw ZENITH from TITLEFONT, each dot a block; B = top row, C = left col
big_title:
        ld a,b
        add a,1
        ld (tl_row),a
        ld a,c
        ld (tl_col),a
        ld hl,TITLEFONT
        ld b,6
.ch:    push bc
        ld a,(tl_row)
        ld (tl_r),a
        ld b,5
.rw:    push bc
        ld a,(hl)
        inc hl
        push hl
        ld e,a
        ld a,(tl_col)
        ld b,a
        ld a,(tl_r)
        ld c,a
        push de
        call vaddr
        pop hl                      ; L = bits
        ld b,3
.bt:    bit 2,l
        jr z,.sk
        ld a,43h
        ld (de),a
        set 3,d
        ld a,(tl_attr)
        ld (de),a
        res 3,d
.sk:    sla l
        inc de
        djnz .bt
        pop hl
        ld a,(tl_r)
        inc a
        ld (tl_r),a
        pop bc
        djnz .rw
        ld a,(tl_col)
        add a,4
        ld (tl_col),a
        pop bc
        djnz .ch
        ret

; mountains on rows 9..20: far range blue, near hills green, the Lantern
panorama:
        ld c,9
.r:     ld b,0
.c:     push bc
        call vaddr
        ld a,c
        add a,a
        sub 18                      ; top pixel row 0..23
        ld (pn_y),a
        call .colour
        rlca
        rlca
        rlca
        rlca
        ld (pn_top),a
        ld a,(pn_y)
        inc a
        ld (pn_y),a
        call .colour
        ld hl,pn_top
        or (hl)
        ld c,a
        ld a,7Ah
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        pop bc
        inc b
        ld a,b
        cp 40
        jr c,.c
        inc c
        ld a,c
        cp 21
        jr c,.r
        ld bc,10*256+27             ; the Lantern on the peak
        call vaddr_bc
        ld a,6Bh
        ld (de),a
        set 3,d
        ld a,60h
        ld (de),a
        ld b,9                      ; its beam
        ld hl,PANO_BEAM
.bm:    push bc
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld b,a
        call vaddr_bc
        ld a,0F9h
        ld (de),a
        set 3,d
        ld a,60h
        ld (de),a
        pop hl
        pop bc
        djnz .bm
        ret
; colour of pixel row pn_y in column B
.colour:
        push de
        call .col2
        pop de
        ret
.col2:  ld e,b
        ld d,0
        ld hl,PANO_N
        add hl,de
        ld a,(pn_y)
        cp (hl)
        ld a,GREEN
        ret nc
        ld hl,PANO_F
        add hl,de
        ld a,(pn_y)
        cp (hl)
        ld a,BLUE
        ret nc
        xor a
        ret

PANO_F: db 14,13,12,12,11,10,10,9,9,10,11,12,12,11,10,9,8,8,9,10
        db 10,9,8,7,6,5,4,3,4,5,6,7,8,9,10,11,11,12,13,13
PANO_N: db 18,18,17,17,17,16,16,17,18,19,20,20,19,19,18,18,19,20,21,21
        db 21,20,20,19,19,20,21,22,22,21,21,20,20,19,18,18,17,17,18,18
PANO_BEAM:
        db 26,10, 25,10, 24,10, 23,9, 22,9, 21,9, 20,9, 19,8, 18,8

; ---------------------------------------------------------------------
howto_page:
        ld hl,700
        ld (fe_t),hl
        ld a,BLACK
        call cls
        ld hl,HOWTO
        ld c,1
        jr text_page

objects_page:
        ld hl,600
        ld (fe_t),hl
        ld a,BLACK
        call cls
        ld hl,OBJTXT
        ld c,1
; lines of text (0-terminated each, FFh ends), from row C, centred
text_page:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        push bc
        push hl
        ld a,70h
        call print_centre
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        pop bc
        inc c
        jr .l

; ---------------------------------------------------------------------
; high scores: 8 x (name[3], island, score lo, hi)
; ---------------------------------------------------------------------
hiscore_init:
        ld hl,HS_DEFAULT
        ld de,HISCORES
        ld bc,8*6
        ldir
        ret

HS_DEFAULT:
        db "ZEN",4
        dw 2500
        db "MZ7",3
        dw 2000
        db "TOR",3
        dw 1600
        db "ASH",2
        dw 1200
        db "KEL",2
        dw 900
        db "ORA",1
        dw 600
        db "VIM",1
        dw 400
        db "LUX",1
        dw 200

scores_page:
        ld hl,400
        ld (fe_t),hl
        ld a,BLACK
        call cls
        ld hl,TXT_HS
        ld c,3
        ld a,60h
        call print_centre
        ld hl,TXT_HSHEAD
        ld c,6
        ld a,50h
        call print_centre
        ld hl,HISCORES
        ld bc,1*256+8               ; B = rank, C = row
.e:     push bc
        push hl
        ld b,10
        call vaddr
        pop hl
        pop bc
        push bc
        push hl
        ld a,b
        add a,20h
        ld (de),a
        set 3,d
        ld a,60h
        ld (de),a
        res 3,d
        inc de
        inc de
        ld b,3                      ; name
.n:     ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,70h
        ld (de),a
        res 3,d
        inc de
        djnz .n
        inc de
        inc de
        inc de
        inc de
        ld a,(hl)                   ; island
        inc hl
        push hl
        ld c,50h
        call print_dec2
        pop hl
        inc de
        inc de
        inc de
        inc de
        ld a,(hl)                   ; score
        inc hl
        ld h,(hl)
        ld l,a
        ld c,70h
        call print_dec5
        pop hl
        ld de,6
        add hl,de
        pop bc
        inc c
        inc b
        ld a,b
        cp 9
        jr c,.e
        ret

; ---------------------------------------------------------------------
; the AI pilot plays one of the first four islands
; ---------------------------------------------------------------------
run_demo:
        call mus_stop
        ld a,1
        ld (autoplay),a
        ld a,(demo_n)
        inc a
        and 3
        ld (demo_n),a
        inc a
        ld (island),a
        ld a,20
        ld (energy),a
        ld hl,0
        ld (score),hl
        ld hl,50*75
        ld (demo_t),hl
        call play_island
        xor a
        ld (autoplay),a
        jp wait_release

; ---------------------------------------------------------------------
; island intro, cleared, game over
; ---------------------------------------------------------------------
; txtbuf = the island's name (two syllables)
island_name:
        ld a,(island)
        ld c,a
        add a,a
        add a,a
        add a,c                     ; *5
        add a,3
        and 15
        ld hl,SYLA
        call .syl
        ld de,txtbuf
        ldi
        ldi
        ldi
        push de
        ld a,(island)
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,c
        add a,c
        add a,c                     ; *11
        add a,7
        and 15
        ld hl,SYLB
        call .syl
        pop de
        ldi
        ldi
        ldi
        xor a
        ld (de),a
        ret
.syl:   ld c,a
        add a,a
        add a,c
        ld c,a
        ld b,0
        add hl,bc
        ret

SYLA:   db "KarVelOstUmbRinTalSorEkhNorAvaTirBelHolMirZanQel"
SYLB:   db "dunvermothaskmarlyngrimtosbreenfalgonrokwyndeltur"

show_surveying:
        ld a,BLACK
        call cls
        ld bc,8*256+15
        call vaddr_bc
        ld hl,TXT_ISLAND
        ld c,60h
        call print
        ld a,(island)
        ld c,70h
        call print_dec2
        call island_name
        ld hl,txtbuf
        ld c,10
        ld a,50h
        call print_centre
        ld hl,TXT_SURVEY
        ld c,14
        ld a,10h
        call print_centre
        ld a,(autoplay)
        or a
        ret z
        ld hl,TXT_DEMO
        ld c,17
        ld a,70h
        jp print_centre

island_cleared:
        call mus_stop
        ld a,(music_off)
        or a
        ld hl,SONG_CLEAR
        call z,mus_play
        ld a,BLACK
        call cls
        ld bc,5*256+11
        call vaddr_bc
        ld hl,TXT_ISLAND
        ld c,60h
        call print
        ld a,(island)
        ld c,60h
        call print_dec2
        ld hl,TXT_CLEARED
        ld c,60h
        call print
        ld hl,TXT_DARK
        ld c,7
        ld a,50h
        call print_centre
        ld hl,TXT_ABS
        ld c,10
        ld a,(absorbed)
        call .stat
        ld hl,TXT_BUILT
        ld c,11
        ld a,(built)
        call .stat
        ld hl,TXT_MOVES
        ld c,12
        ld a,(moves)
        call .stat
        ld a,(energy)               ; bonus: energy * 10
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        push hl
        ld de,(score)
        add hl,de
        ld (score),hl
        ld bc,14*256+11
        call vaddr_bc
        ld hl,TXT_BONUS
        ld c,70h
        call print
        pop hl
        ld c,60h
        call print_dec5
        ld bc,16*256+11
        call vaddr_bc
        ld hl,TXT_SCORE
        ld c,70h
        call print
        ld hl,(score)
        ld c,60h
        call print_dec5
        ld a,(island)
        cp 99
        jr nc,.top
        inc a
        ld (island),a
.top:   ld c,a
        ld a,(best_island)
        cp c
        jr nc,.nb
        ld a,c
        ld (best_island),a
.nb:    ld bc,19*256+13
        call vaddr_bc
        ld hl,TXT_NEXT
        ld c,50h
        call print
        ld a,(island)
        ld c,70h
        call print_dec2
        ld a,(energy)               ; a fresh island tops energy up to 10
        cp 10
        jr nc,.en
        ld a,10
        ld (energy),a
.en:    ld a,50
        call wait_fields
        call wait_release
        ld hl,300
.w:     push hl
        call wait_field
        call anykey
        pop hl
        jr nz,.x
        dec hl
        ld a,h
        or l
        jr nz,.w
.x:     jp wait_release
; label HL, row C, value A
.stat:  push af
        push hl
        ld b,12
        call vaddr
        pop hl
        push bc
        ld c,70h
        call print
        pop bc
        ld b,26
        call vaddr
        pop af
        ld c,60h
        jp print_dec2

game_over:
        call mus_stop
        ld a,(music_off)
        or a
        ld hl,SONG_OVER
        call z,mus_play
        ld a,BLACK
        call cls
        ld hl,TXT_TAKEN
        ld c,6
        ld a,20h
        call print_centre
        ld bc,9*256+8
        call vaddr_bc
        ld hl,TXT_ISLAND
        ld c,70h
        call print
        ld a,(island)
        ld c,60h
        call print_dec2
        inc de
        inc de
        inc de
        ld hl,TXT_SCORE
        ld c,70h
        call print
        ld hl,(score)
        ld c,60h
        call print_dec5
        call hs_insert
        ld a,100
        call wait_fields
        call wait_release
        ld hl,400
.w:     push hl
        call wait_field
        call anykey
        pop hl
        jr nz,.x
        dec hl
        ld a,h
        or l
        jr nz,.w
.x:     call wait_release
        ld a,3                      ; show the table next
        ld (fe_page),a
        ret

; insert (score, island) into the table if it qualifies, asking for a name
hs_insert:
        ld hl,HISCORES+4
        ld b,0
.f:     ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        push hl
        ld hl,(score)
        or a
        sbc hl,de
        pop hl
        jr z,.nx
        jr nc,.at                   ; beats entry B
.nx:    ld de,6
        add hl,de
        inc b
        ld a,b
        cp 8
        jr c,.f
        ret
.at:    ld a,b
        ld (hs_pos),a
        ld a,7                      ; shift entries B..6 down one
        sub b
        jr z,.ins
        ld c,a
        ld hl,0
        ld de,6
.m6:    add hl,de
        dec c
        jr nz,.m6
        ld b,h
        ld c,l
        ld hl,HISCORES+7*6-1
        ld de,HISCORES+8*6-1
        lddr
.ins:   ld hl,TXT_NEWHS
        ld c,13
        ld a,50h
        call print_centre
        ld hl,TXT_TYPE
        ld c,15
        ld a,70h
        call print_centre
        ld a,'A'
        ld (hs_name),a
        ld (hs_name+1),a
        ld (hs_name+2),a
        call wait_release
        xor a
        ld (lastletter),a
        ld b,0                      ; letter index
.k:     push bc
        call .show
        pop bc
.kw:    push bc
        call wait_field
        call getletter
        pop bc
        ld hl,lastletter
        cp (hl)
        ld (hl),a
        jr z,.kc
        or a
        jr z,.kc
        ld e,b
        ld d,0
        ld hl,hs_name
        add hl,de
        ld (hl),a
        inc b
        ld a,b
        cp 3
        jr c,.k
        jr .done
.kc:    push bc
        call read_keys
        pop bc
        bit B_FIRE,a
        jr z,.kw
.done:  call .show
        ld a,(hs_pos)               ; write the entry
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        add hl,hl                   ; * 6
        ld de,HISCORES
        add hl,de
        ex de,hl
        ld hl,hs_name
        ldi
        ldi
        ldi
        ld a,(island)
        ld (de),a
        inc de
        ld hl,(score)
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,SFX_SHELL
        ld a,2
        jp sfx
.show:  ld bc,17*256+18
        call vaddr_bc
        ld hl,hs_name
        ld b,3
.sl:    ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,60h
        ld (de),a
        res 3,d
        inc de
        djnz .sl
        ret

; ---------------------------------------------------------------------
; text
; ---------------------------------------------------------------------
TXT_SUB:        db "AN ISLAND OF LIGHT AND STONE",0
TXT_PRESS:      db "PRESS SPACE TO PLAY",0
TXT_CREDIT:     db "AN ORIGINAL GAME FOR THE SHARP MZ-700",0
TXT_START:      db "< START ISLAND ",0
TXT_START2:     db " >",0
TXT_HS:         db "THE HIGHEST CLIMBERS",0
TXT_HSHEAD:     db "    NAME  ISLAND   SCORE",0
TXT_SURVEY:     db "SURVEYING THE LAND...",0
TXT_DEMO:       db "DEMONSTRATION - PRESS ANY KEY",0
TXT_CLEARED:    db " CLEARED",0
TXT_DARK:       db "THE LANTERN IS DARK",0
TXT_ABS:        db "ABSORBED",0
TXT_BUILT:      db "BUILT",0
TXT_MOVES:      db "MOVES",0
TXT_BONUS:      db "ENERGY BONUS ",0
TXT_NEXT:       db "NEXT: ISLAND ",0
TXT_TAKEN:      db "THE LIGHT HAS TAKEN YOU",0
TXT_NEWHS:      db "A NEW HIGH SCORE!",0
TXT_TYPE:       db "TYPE YOUR INITIALS",0
TXT_ENERGY:     db "ENERGY ",0
TXT_ISLAND:     db "ISLAND ",0
TXT_SCORE:      db "SCORE ",0
TXT_KEYS:       db "H HELP  M MAP",0
TXT_DEMOKEYS:   db 3,"DEMO - ANY KEY",0
TXT_MAP:        db "THE ISLAND FROM ABOVE",0
TXT_MAPKEY:     db 7,"YOU ",6,"BEAM ",3,"SHARD ",2,"LANTERN ",7,"SHELL",0
TXT_MAPKEY2:    db 2,"RED: CAIRNS   ",5,"ANY KEY RETURNS",0

TT_NONE:        db 1,"NOTHING THERE",0
TT_UNSEEN:      db 2,"CANNOT SEE THAT TILE'S SURFACE",0
TT_OWN:         db 5,"YOUR OWN TILE",0
TT_SHARD:       db 3,"SHARD",7,"  A: ABSORB +1",0
TT_SHELL:       db 7,"SHELL  T: MOVE IN  A: +3",0
TT_LANTERN:     db 6,"THE LANTERN!",7,"  A: PUT IT OUT",0
TT_WISP:        db 3,"WISP",7,"  A: ABSORB +2",0
TT_CAIRN:       db 2,"CAIRN",7,"  A: +2  B: +1  S: SHELL",0
TT_FLAT:        db 4,"GROUND",7,"  B: CAIRN 2  S: SHELL 3",0
TT_SLOPE:       db 5,"SLOPE",7,"  NOTHING STANDS HERE",0

MSG_EMPTY:      db 0
MSG_MUSOFF:     db "MUSIC OFF",0
MSG_MUSON:      db "MUSIC ON",0
MSG_PAUSED:     db 6,"PAUSED - PRESS A KEY",0
MSG_QUIT:       db 6,"QUIT THIS GAME? Y/N",0
MSG_HELP:       db "KEYS ARE LISTED ON THE TITLE PAGES",0
MSG_NOTGT:      db 2,"POINT AT A TILE FIRST",0
MSG_UNSEEN:     db 2,"YOU MUST SEE ITS SURFACE",0
MSG_OWN:        db 2,"YOU STAND THERE",0
MSG_NOTHING:    db 2,"NOTHING TO ABSORB",0
MSG_ABSORBED:   db 5,"ABSORBED",0
MSG_SLOPE:      db 2,"ONLY ON FLAT GROUND",0
MSG_OCCUPIED:   db 2,"SOMETHING IS ALREADY THERE",0
MSG_TALL:       db 2,"THE CAIRN IS AS TALL AS IT GETS",0
MSG_POOR:       db 2,"NOT ENOUGH ENERGY",0
MSG_BUILT:      db 6,"A CAIRN RISES",0
MSG_SHELLED:    db 7,"A NEW SHELL WAITS",0
MSG_NOSHELL:    db 2,"MOVE ONLY INTO A SHELL",0
MSG_MOVED:      db 5,"YOU WAKE IN THE NEW SHELL",0
MSG_APPROACH:   db 6,"THE BEAM IS COMING ROUND",0
MSG_SEEN:       db 2,"THE LANTERN SEES YOU!",0
MSG_WISP:       db 3,"A WISP STEALS YOUR ENERGY",0

HOWTO:
        db 6,"HOW TO PLAY",0
        db 0
        db "YOU ARE A SPIRIT IN A SHELL OF STONE.",0
        db "ON EACH ISLAND THE LANTERN WATCHES",0
        db "FROM THE HIGHEST GROUND. ITS BEAM",0
        db "SWEEPS ROUND, AND WHILE IT LIGHTS",0
        db "YOUR TILE YOU LOSE ENERGY.",0
        db 0
        db "YOU CAN ONLY TOUCH TILES WHOSE",0
        db "SURFACE YOU CAN SEE. TO CLIMB, BUILD",0
        db "CAIRNS, SET A SHELL ON TOP, MOVE IN.",0
        db "LOOK DOWN ON THE LANTERN'S TILE AND",0
        db "ABSORB IT TO PUT ITS LIGHT OUT.",0
        db 0
        db 5,"CURSOR KEYS AIM - PAST AN EDGE TURNS",0
        db 5,"A OR SPACE ABSORB  B CAIRN  S SHELL",0
        db 5,"T MOVE  U ABOUT-TURN  Z X TURN",0
        db 5,"M MAP  P PAUSE  N MUSIC  Q QUIT",0
        db 0FFh

OBJTXT:
        db 6,"ON THE ISLANDS",0
        db 0
        db 3,"SHARD     ",7,"ABSORB FOR 1 ENERGY",0
        db 2,"CAIRN     ",7,"BUILD 2, ABSORB 2",0
        db 7,"SHELL     ",7,"BUILD 3, ABSORB 3",0
        db 3,"WISP      ",7,"ABSORB 2, STEALS 1",0
        db 6,"LANTERN   ",7,"ABSORB TO CLEAR",0
        db 0
        db "FROM ISLAND 3 WISPS DRIFT TOWARDS",0
        db "YOU. THE BEAM TURNS FASTER AND THE",0
        db "LANTERN STANDS TALLER ON EACH ISLAND.",0
        db 0
        db "THE COMPASS SHOWS THE BEAM IN YELLOW",0
        db "AND YOUR SECTOR AS O.",0
        db 0
        db "A WHITE CURSOR MEANS YOU CAN ACT.",0
        db 0FFh
