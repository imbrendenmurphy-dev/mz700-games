; =====================================================================
;  screens.asm - title, story, controls, high scores, prisms, ending
; =====================================================================

RAINBOW:        db RED, YELLOW, GREEN, CYAN, BLUE, MAGENTA, RED, YELLOW

; fe_wait: run A fields of front end (calls fe_tick each field).
; Returns NZ if SPACE / Z was pressed (start), Z on timeout.
fe_wait:
        ld (fe_left),a
        call fe_reset
.l:     call wait_field
        ld hl,fe_clock
        inc (hl)
        ld hl,(fe_hook)
        ld a,h
        or l
        call nz,.hook
        call fe_keys
        and K_JUMP
        jr nz,.go
        ld hl,fe_left
        dec (hl)
        jr nz,.l
        xor a
        ret
.go:    ld hl,SFX_SELECT
        ld a,4
        call sfx
        or 1
        ret
.hook:  jp (hl)

; rainbow bar along row A
rainbow_row:
        call row_addr
        ld b,40
        ld c,0
.l:     ld a,c
        rrca
        rrca
        and 7
        push hl
        ld hl,RAINBOW
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        rlca
        rlca
        rlca
        rlca
        ld (hl),7Eh                 ; lower 3/8 bar
        set 3,h
        ld (hl),a
        res 3,h
        inc hl
        inc c
        djnz .l
        ret

; ---------------------------------------------------------------------
; title screen
; ---------------------------------------------------------------------
title_screen:
        xor a
        call cls
        xor a
        call rainbow_row
        ld a,24
        call rainbow_row
        ld hl,PIC_LOGO
        ld de,VRAM+40*2+8
        call draw_pic
        ld hl,txt_sub
        ld c,9
        ld a,70h
        call print_centre
        ld hl,PIC_BIGKIKO
        ld de,VRAM+40*12+2
        call draw_pic
        ld hl,PIC_PRISM
        ld de,VRAM+40*12+30
        call draw_pic
        ld hl,txt_hi
        ld de,VRAM+40*13+15
        ld c,50h
        call print
        ld hl,hiscores+2            ; best score
        ld b,3
        ld de,VRAM+40*14+16
        ld c,70h
        call print_bcd
        ld hl,txt_press
        ld c,17
        ld a,60h
        call print_centre
        ld hl,txt_credit
        ld c,21
        ld a,30h
        call print_centre
        ld hl,txt_year
        ld c,22
        ld a,10h
        call print_centre
        ld hl,SONG_TITLE
        ld a,(title_music)          ; restart the theme only after a game
        or a
        jr nz,.nomus
        call mus_play
        ld a,1
        ld (title_music),a
.nomus: ld hl,txt_scroll
        ld (scroll_ptr),hl
        ld hl,title_tick
        ld (fe_hook),hl
        ld a,250
        call fe_wait
        jr nz,.go
        ld a,250
        call fe_wait
.go:    push af
        ld hl,0
        ld (fe_hook),hl
        pop af
        ret

title_tick:
        call logo_roll
        jr title_more

; logo colours roll through the rainbow
logo_roll:
        ld a,(fe_clock)
        and 3
        ret nz
        ld a,(fe_clock)
        rrca
        rrca
        ld (tt_phase),a
        ld hl,ARAM+40*2+8
        ld c,6
.r:     ld b,LOGO_W
        push hl
.c:     ld a,(hl)
        and 0F0h                    ; only cells drawn in a colour
        jr z,.skip
        ld a,(tt_phase)             ; stripes rolling up the letters
        add a,c
        and 7
        push hl
        ld hl,RAINBOW
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        rlca
        rlca
        rlca
        rlca
        ld (hl),a
.skip:  inc hl
        djnz .c
        pop hl
        ld de,40
        add hl,de
        dec c
        jr nz,.r
        ret

title_more:
        ; Kiko blinks
        ld a,(fe_clock)
        and 127
        cp 6
        ld de,VRAM+40*13+2+6
        ld a,89h
        ld c,0F0h                   ; bank 1, white on black
        jr nc,.open
        ld a,43h
        ld c,40h
.open:  call putc
        ; "PRESS SPACE" flashes
        ld a,(fe_clock)
        and 16
        ld a,60h
        jr z,$+4
        ld a,20h
        ld de,VRAM+40*17+10
        ld b,20
        call fill_attr
        ; scroller on row 23
        ld a,(fe_clock)
        and 7
        ret nz
        ld hl,VRAM+40*23+1
        ld de,VRAM+40*23
        ld bc,39
        ldir
        ld hl,(scroll_ptr)
        ld a,(hl)
        or a
        jr nz,.ch
        ld hl,txt_scroll
        ld a,(hl)
.ch:    inc hl
        ld (scroll_ptr),hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        ld de,VRAM+40*23+39
        ld c,70h
        call putc
        ld a,(fe_clock)             ; colour wave along the scroller
        rrca
        rrca
        rrca
        and 7
        ld hl,RAINBOW
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        ld de,VRAM+40*23+39
        set 3,d
        ld (de),a
        ret

txt_sub:        db "AND THE COLOUR THIEF",0
txt_hi:         db "HI-SCORE",0
txt_press:      db "PRESS SPACE TO PLAY",0
txt_credit:     db "V",89h,"BED BY BPM",0
txt_year:       db "SHARP MZ-700  2026",0
txt_scroll:
        db "                    THE GREY BARON HAS STOLEN THE PRISMS OF LIGHT ... "
        db "ONLY KIKO THE CHAMELEON CAN BRING THE COLOUR BACK!   "
        db "RUN, JUMP, STOMP AND TONGUE YOUR WAY THROUGH FOUR WORLDS ...   "
        db "CHANGE COLOUR TO WALK THROUGH WALLS AND STAND ON BLOCKS OF YOUR OWN COLOUR ...   "
        db "INKBLOTS CANNOT SEE YOU WHILE YOU WEAR THEIR COLOUR ...   "
        db "FIND THE HIDDEN STARS!   ",0

; ---------------------------------------------------------------------
; story
; ---------------------------------------------------------------------
story_page:
        xor a
        call cls
        xor a
        call rainbow_row
        ld a,24
        call rainbow_row
        ld hl,PIC_BARON
        ld de,VRAM+40*2+3
        call draw_pic
        ld hl,txt_st1
        ld de,VRAM+40*3+14
        ld c,70h
        call print
        ld hl,txt_st2
        ld de,VRAM+40*5+14
        ld c,70h
        call print
        ld hl,txt_st3
        ld de,VRAM+40*6+14
        ld c,70h
        call print
        ld hl,txt_st4
        ld de,VRAM+40*7+14
        ld c,70h
        call print
        ld hl,PIC_BIGKIKO
        ld de,VRAM+40*12+28
        call draw_pic
        ld b,2
        ld de,VRAM+40*12+2
        ld hl,txt_st5
.l:     push bc
        push de
        ld c,40h
        call print
        pop de
        ex de,hl
        ld bc,80
        add hl,bc
        ex de,hl
        pop bc
        djnz .l
        ld hl,txt_st7
        ld de,VRAM+40*17+2
        ld c,60h
        call print
        ld hl,txt_st8
        ld de,VRAM+40*18+2
        ld c,60h
        call print
        ld hl,txt_st9
        ld de,VRAM+40*20+2
        ld c,50h
        call print
        ld a,0
        ld hl,0
        ld (fe_hook),hl
        ld a,250
        call fe_wait
        ret nz
        ld a,100
        jp fe_wait

txt_st1:        db "THE GREY BARON",0
txt_st2:        db "HATES COLOUR. HE",0
txt_st3:        db "STOLE THE PRISMS",0
txt_st4:        db "OF LIGHT!",0
txt_st5:        db "THE WORLD IS FADING",0
                db "TO GREY ...",0
txt_st7:        db "BUT KIKO CAN BE",0
txt_st8:        db "ANY COLOUR HE LIKES!",0
txt_st9:        db "FIND THE PRISMS!",0

; ---------------------------------------------------------------------
; controls and items
; ---------------------------------------------------------------------
howto_page:
        xor a
        call cls
        xor a
        call rainbow_row
        ld a,24
        call rainbow_row
        ld hl,txt_how
        ld c,2
        ld a,60h
        call print_centre
        ld hl,HOWTO
.l:     ld a,(hl)
        inc hl
        cp 0FFh
        jr z,.items
        ld c,a                      ; row
        ld a,(hl)
        inc hl
        ld b,a                      ; column
        ld a,(hl)
        inc hl
        push af
        call vaddr
        pop af
        ld c,a
        call print
        jr .l
.items: ld hl,ITEMS
.i:     ld a,(hl)
        cp 0FFh
        jr z,.wait
        inc hl
        ld c,a
        ld a,(hl)
        inc hl
        ld b,a
        call vaddr
        ld a,(hl)                   ; char
        inc hl
        ld c,(hl)                   ; attr
        inc hl
        call putc
        jr .i
.wait:  ld hl,0
        ld (fe_hook),hl
        ld a,250
        call fe_wait
        ret nz
        ld a,150
        jp fe_wait

txt_how:        db "HOW TO PLAY",0
HOWTO:
        db 5,4,70h,  "CURSORS / O P ....... RUN",0
        db 6,4,70h,  "SPACE / Z ........... JUMP",0
        db 7,4,50h,  "  (HOLD TO JUMP HIGHER)",0
        db 8,4,70h,  "X / M ............... TONGUE",0
        db 9,4,70h,  "C / N ....... CHANGE COLOUR",0
        db 10,4,70h, "UP / DOWN ..... CLIMB VINES",0
        db 11,4,50h, "  DOWN: DUCK  (ON A PLANK: DROP)",0
        db 12,4,70h, "CR PAUSE        BREAK QUIT",0
        db 15,8,60h, "GEM ...... 10 POINTS",0
        db 16,8,60h, "APPLE .... ONE HEART",0
        db 17,8,60h, "SMILE .... EXTRA LIFE",0
        db 18,8,60h, "STAR ..... SECRET!",0
        db 20,4,40h, "STOMP OR EAT THE BADDIES!",0
        db 21,4,40h, "100 GEMS GIVE AN EXTRA LIFE",0
        db 0FFh
ITEMS:  db 15,5,44h,50h, 16,5,9Dh,0A0h, 17,5,0CEh,40h, 18,5,0B3h,0E0h
        db 0FFh

; ---------------------------------------------------------------------
; high scores: 8 x (3 BCD bytes, low first; 3 letters)
; ---------------------------------------------------------------------
HS_N            equ 8
HS_SZ           equ 6

hiscore_init:
        ld hl,HS_DEFAULT
        ld de,hiscores
        ld bc,HS_N*HS_SZ
        ldir
        ret

HS_DEFAULT:
        db 00h,00h,02h,"KIK"
        db 00h,50h,01h,"BPM"
        db 00h,00h,01h,"MZ7"
        db 00h,75h,00h,"ZAP"
        db 00h,50h,00h,"INK"
        db 00h,30h,00h,"BAR"
        db 00h,20h,00h,"GEM"
        db 00h,10h,00h,"FLY"

hiscore_page:
        xor a
        call cls
        xor a
        call rainbow_row
        ld a,24
        call rainbow_row
        ld hl,txt_best
        ld c,3
        ld a,60h
        call print_centre
        call hs_table
        ld hl,0
        ld (fe_hook),hl
        ld a,250
        jp fe_wait

; rank at column 12, score at 16, name at 25; entry i on row 6 + 2i
hs_table:
        ld hl,hiscores
        ld c,6                      ; row
        ld a,1                      ; rank
.l:     push af
        ld b,12
        push bc
        call vaddr                  ; DE = screen address (HL kept)
        pop bc
        pop af
        push af
        push bc
        add a,20h
        ld c,70h
        call putc
        inc de
        inc de
        inc de
        inc de
        push hl
        inc hl
        inc hl                      ; most significant byte
        ld b,3
        ld c,70h
        call print_bcd
        pop hl
        inc de
        inc de
        inc de
        push hl
        inc hl
        inc hl
        inc hl
        ld b,3
.n:     ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,60h
        call putc
        inc de
        djnz .n
        pop hl
        ld bc,HS_SZ
        add hl,bc
        pop bc
        inc c
        inc c
        pop af
        inc a
        cp HS_N+1
        jr c,.l
        ret

txt_best:       db "BEST CHAMELEONS",0

; after a game: enter the table?
hiscore_entry:
        ld a,(demo)
        or a
        ret nz
        ; find the first entry our score beats
        ld ix,hiscores
        ld b,HS_N
.f:     ld a,(score+2)
        cp (ix+2)
        jr c,.n
        jr nz,.here
        ld a,(score+1)
        cp (ix+1)
        jr c,.n
        jr nz,.here
        ld a,(score)
        cp (ix+0)
        jr z,.n
        jr nc,.here
.n:     ld de,HS_SZ
        add ix,de
        djnz .f
        ret
.here:  ; shift the rest down (from the end backwards)
        push ix
        ld hl,hiscores+HS_N*HS_SZ-1
        ld de,hiscores+HS_N*HS_SZ-1-HS_SZ
        ld a,b
        dec a
        jr z,.noshift
        ld c,a
        ld b,0
        ; count = (b-1) * 6
        ld h,b
        ld l,c
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld b,h
        ld c,l
        ld hl,hiscores+HS_N*HS_SZ-1-HS_SZ
        ld de,hiscores+HS_N*HS_SZ-1
        lddr
.noshift:
        pop ix
        ld a,(score)
        ld (ix+0),a
        ld a,(score+1)
        ld (ix+1),a
        ld a,(score+2)
        ld (ix+2),a
        ld (ix+3),'A'
        ld (ix+4),'A'
        ld (ix+5),'A'
        ; name entry screen
        xor a
        call cls
        xor a
        call rainbow_row
        ld a,24
        call rainbow_row
        ld hl,txt_newhs
        ld c,3
        ld a,60h
        call print_centre
        ld hl,txt_name
        ld c,5
        ld a,50h
        call print_centre
        ld hl,txt_keys
        ld c,22
        ld a,30h
        call print_centre
        xor a
        ld (hs_pos),a
.edit:  call hs_table
        ; cursor under the letter being edited
        push ix
        pop hl
        ld de,hiscores
        or a
        sbc hl,de
        ld a,l                      ; entry*6
        ld b,0
.dv:    sub HS_SZ
        jr c,.dd
        inc b
        jr .dv
.dd:    ld a,b
        add a,a
        add a,7                     ; row under the entry
        ld c,a
        ld b,25
        push bc
        call vaddr
        ld b,3
.cl:    xor a
        push bc
        ld c,70h
        call putc
        pop bc
        inc de
        djnz .cl
        pop bc
        ld a,(hs_pos)
        add a,25
        ld b,a
        call vaddr
        ld a,0C3h                   ; up arrow
        ld c,60h
        call putc
        call fe_reset
.k:     call wait_field
        call fe_keys
        jr z,.k
        ld c,a
        ld a,(hs_pos)
        add a,3
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de                   ; HL = the letter
        bit 0,c                     ; UP
        jr z,.nu
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,$+4
        ld a,'A'
        ld (hl),a
        jp .edit
.nu:    bit 1,c                     ; DOWN
        jr z,.nd
        ld a,(hl)
        dec a
        cp 'A'
        jr nc,$+4
        ld a,'Z'
        ld (hl),a
        jp .edit
.nd:    bit 2,c                     ; LEFT
        jr z,.nl
        ld a,(hs_pos)
        or a
        jp z,.edit
        dec a
        ld (hs_pos),a
        jp .edit
.nl:    ld a,c
        and K_RIGHT|K_JUMP
        jp z,.edit
        ld hl,SFX_SELECT
        ld a,4
        call sfx
        ld a,(hs_pos)
        inc a
        ld (hs_pos),a
        cp 3
        jp c,.edit
        call hs_table
        ld a,100
        jp wait_fields

txt_newhs:      db "A NEW HIGH SCORE!",0
txt_name:       db "ENTER YOUR NAME",0
txt_keys:       db "UP/DOWN LETTER   SPACE NEXT",0

; ---------------------------------------------------------------------
; a prism won back (after the boss of worlds 1-3)
; ---------------------------------------------------------------------
prism_screen:
        xor a
        call cls
        ld hl,PIC_PRISM
        ld de,VRAM+40*3+16
        call draw_pic
        ld hl,txt_prism
        ld c,13
        ld a,70h
        call print_centre
        ld a,(lv_world)
        add a,a
        ld e,a
        ld d,0
        ld hl,PRISM_TXT
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,16
        ld a,60h
        call print_centre
        ld hl,txt_onward
        ld c,19
        ld a,50h
        call print_centre
        ld hl,SONG_PRISM
        call mus_play
        ; the prism sparkles
        ld b,200
.l:     push bc
        call wait_field
        ld a,b
        and 7
        jr nz,.n
        ld a,b
        rrca
        rrca
        rrca
        and 7
        ld hl,RAINBOW
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        ld de,VRAM+40*3+16+3
        call .tip
        ld de,VRAM+40*10+16+3
        call .tip
.n:     pop bc
        djnz .l
        ret
.tip:   set 3,d
        ld (de),a
        inc de
        ld (de),a
        ret

txt_prism:      db "YOU WON BACK A PRISM OF LIGHT!",0
txt_onward:     db "ONWARD, KIKO!",0
PRISM_TXT:      dw txt_pr1, txt_pr2, txt_pr3, txt_pr3
txt_pr1:        db "NOW KIKO CAN TURN RED!",0
txt_pr2:        db "NOW KIKO CAN TURN BLUE!",0
txt_pr3:        db "ONLY THE BARON IS LEFT ...",0

; ---------------------------------------------------------------------
; the ending: colour floods back into the world
; ---------------------------------------------------------------------
ending:
        xor a
        call cls
        ld hl,SONG_ENDING
        call mus_play
        ; grey to colour: sweep rainbow bands down the screen
        ld c,0
.fl:    push bc
        call wait_field
        call wait_field
        pop bc
        push bc
        ld a,c
        cp 25
        jr nc,.fd
        call row_addr
        ld a,c
        and 7
        ld de,RAINBOW
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld a,(de)
        ld b,40
.fc:    ld (hl),0
        set 3,h
        ld (hl),a                   ; background colour
        res 3,h
        inc hl
        djnz .fc
        ld hl,SFX_BLIP
        xor a
        call sfx
.fd:    pop bc
        inc c
        ld a,c
        cp 26
        jr c,.fl
        ld a,50
        call wait_fields
        ; then the pictures and the thanks on black
        xor a
        call cls
        xor a
        call rainbow_row
        ld a,24
        call rainbow_row
        ld hl,PIC_LOGO
        ld de,VRAM+40*2+8
        call draw_pic
        ld hl,PIC_BIGKIKO
        ld de,VRAM+40*10+3
        call draw_pic
        ld hl,PIC_PRISM
        ld de,VRAM+40*10+29
        call draw_pic
        ld hl,txt_end1
        ld de,VRAM+40*10+14
        ld c,70h
        call print
        ld hl,txt_end2
        ld de,VRAM+40*11+14
        ld c,70h
        call print
        ld hl,txt_end3
        ld de,VRAM+40*13+14
        ld c,60h
        call print
        ld hl,txt_end4
        ld de,VRAM+40*14+14
        ld c,60h
        call print
        ld hl,txt_score
        ld de,VRAM+40*16+14
        ld c,50h
        call print
        inc de
        ld hl,score+2
        ld b,3
        ld c,70h
        call print_bcd
        ld hl,txt_stars
        ld de,VRAM+40*17+14
        ld c,50h
        call print
        inc de
        ld a,(secrets)
        ld c,70h
        call print_dec2
        ld hl,txt_of8
        ld c,50h
        call print
        ld hl,txt_credit
        ld c,20
        ld a,30h
        call print_centre
        ld hl,txt_theend
        ld c,22
        ld a,70h
        call print_centre
        ld hl,ending_tick
        ld (fe_hook),hl
        ld a,250
        call fe_wait
        ld a,250
        call fe_wait
        ld hl,0
        ld (fe_hook),hl
        xor a
        ld (title_music),a
        ret

ending_tick:
        jp logo_roll

txt_end1:       db "THE COLOURS",0
txt_end2:       db "ARE BACK!",0
txt_end3:       db "THANK YOU FOR",0
txt_end4:       db "PLAYING!",0
txt_stars:      db "STARS",0
txt_of8:        db " OF 8",0
txt_theend:     db "THE END",0
