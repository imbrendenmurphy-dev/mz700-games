; =====================================================================
;  screens.asm - title, info pages, act cards, curtains, celebrations,
;  pause, game over and high-score entry
; =====================================================================
SRCBUF          equ 0C000h          ; a whole screen (chars, attrs +400h)
CARDSAVE        equ 0C800h          ; the arena under the act card (attrs +300h)
CARD_ROW        equ 4
CARD_ROWS       equ 9

jp_hl:  jp (hl)
no_fx:  ret

; ---------------------------------------------------------------------
; big dotted text (3x5 font in quarter-cell specks, 2 x 3 cells a char)
; ---------------------------------------------------------------------
; big_char: A = ASCII, D = top row, E = col, B = attr; uses (big_out)
big_char:
        push hl
        push de
        sub ' '
        jr nc,$+3
        xor a
        cp BIGFONT_N
        jr c,$+3
        xor a
        ld l,a
        ld h,0
        add hl,hl                   ; *2
        push hl
        add hl,hl                   ; *4
        pop de
        add hl,de                   ; *6
        ld de,BIGFONT
        add hl,de
        pop de
        push de
        ld c,3                      ; three cell rows of two
.r:     push bc
        ld c,(hl)
        inc hl
        call .cell
        inc e
        ld c,(hl)
        inc hl
        call .cell
        dec e
        inc d
        pop bc
        dec c
        jr nz,.r
        pop de
        pop hl
        ret
.cell:  ld a,c
        cp 0F0h
        jr nz,.put
        ld a,(big_solid)            ; blank: skip, or a space on panels
        or a
        ret z
        ld c,0
.put:   push hl
        push de
        push bc
        ld hl,(big_out)
        call jp_hl
        pop bc
        pop de
        pop hl
        ret

; big string: HL = ASCII, D = row, E = col, B = attr
big_str:
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        call big_char
        inc e
        inc e
        jr .l

; big string centred: HL, D, B
big_centre:
        push hl
        call strlen
        pop hl
        add a,a
        ld c,a
        ld a,41
        sub c
        srl a
        ld e,a
        jr big_str

; big string as objects (transparent), centred
big_obj:
        push hl
        ld hl,put_at
        ld (big_out),hl
        xor a
        ld (big_solid),a
        pop hl
        jr big_centre

; big string into the background (blank cells written), centred
big_bg:
        push hl
        ld hl,bg_put
        ld (big_out),hl
        ld a,1
        ld (big_solid),a
        pop hl
        jr big_centre

; ---------------------------------------------------------------------
; frame pacing for the front end
; ---------------------------------------------------------------------
fe_frame:
        call poll
        ld a,(turbo)
        or a
        call z,wait_frame
        call present
        ld hl,anim_fe
        inc (hl)
        ret

; page_wait: run (page_fx) for up to A frames (25 per second).  Returns
; Z on time-out, NZ when a key starts the game
page_wait:
        ld (page_len),a
        call wait_release
        ld a,(fieldcnt)
        ld (lastframe),a
.l:     call fe_frame
        ld hl,(page_fx)
        call jp_hl
        call anykey
        jr nz,.key
        ld hl,page_len
        dec (hl)
        jr nz,.l
        xor a
        ret
.key:   ld a,1
        or a
        ret

; info page frame: background A, candy stripes on rows 0 and 24
info_begin:
        call bg_fill
        ld hl,no_fx
        ld (page_fx),hl
        jp stripes_draw

stripes_draw:
        ld d,0
        call .row
        ld d,24
.row:   ld e,0
.l:     ld a,e
        ld hl,anim_fe
        add a,(hl)
        and 2
        ld a,RED*16+WHITE
        jr z,$+4
        ld a,WHITE*16+RED
        ld b,a
        ld c,4Eh
        call bg_touch_put
        inc e
        ld a,e
        cp 40
        jr c,.l
        ret

; the stripes chase on info pages
stripes_fx:
        ld a,(anim_fe)
        and 3
        ret nz
        jr stripes_draw

; ---------------------------------------------------------------------
; title screen.  NZ = start a game
; ---------------------------------------------------------------------
title_screen:
        ld a,(mus_on)
        or a
        jr nz,.playing
        ld hl,SONG_TITLE
        call mus_play
.playing:
        call title_draw
        xor a
        ld (t_msg),a
        ld (t_msgt),a
        call title_msg
        ld hl,title_fx
        ld (page_fx),hl
        call wait_release
        ld a,(fieldcnt)
        ld (lastframe),a
        ld bc,500                   ; 20 seconds
.l:     push bc
        call fe_frame
        call title_fx
        call read_keys
        ld b,a
        ld a,(key_extra)
        and 86h                     ; S, D or J
        jr nz,.opt
        ld a,b
        or a
        jr nz,.go
        call anykey
        jr nz,.go
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.l
        xor a
        ret
.go:    pop bc
        ld a,1
        or a
        ret
.opt:   bit 1,a
        jr z,.d
        ld a,(snd_mute)             ; S: sound on / off
        xor 1
        ld (snd_mute),a
        ld a,2
        jr .show
.d:     bit 7,a
        jr z,.d2
        ld a,(joy_mode)             ; J: joystick off / stick / paddle
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (joy_mode),a
        call joy_reset
        ld a,4
        jr .show
.d2:    ld a,(difficulty)           ; D: easy / normal / hard
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (difficulty),a
        ld a,3
.show:  ld (t_msg),a
        call title_msg
        ld hl,SFX_CLICK
        ld a,3
        call sfx
.rel:   call fe_frame
        call title_fx
        call anykey
        jr nz,.rel
        pop bc
        ld bc,500
        jr .l+0

title_draw:
        ld hl,TITLE_ART
        call unpack_screen
        call all_dirty
        ld b,6
        ld hl,t_bal
.b:     push bc                     ; balloons start spread out
        push hl
        call new_tballoon
        ld b,14
        call rand_below
        add a,7
        pop hl
        ld (hl),a
        inc hl
        inc hl
        pop bc
        djnz .b
        ret

; HL = t_bal entry: a new balloon at the bottom of a side strip
new_tballoon:
        ld a,21
        ld (hl),a
        inc hl
        ld b,5
        call rand_below
        inc a
        ld c,a
        push hl
        call rand
        pop hl
        and 1
        ld a,c
        jr z,$+4
        add a,33
        ld (hl),a
        ret

title_fx:
        ld a,(anim_fe)
        ld c,a
        and 7
        call z,logo_colours
        ld a,c
        and 1
        call z,marquee
        call stars
        call wink
        call tballoons
        ld hl,t_msgt                ; next message every 3 seconds
        inc (hl)
        ld a,(hl)
        cp 75
        ret c
        ld (hl),0
        ld a,(t_msg)
        inc a
        cp NTMSG
        jr c,$+3
        xor a
        ld (t_msg),a
        jp title_msg

; logo letters cycle through the colours
logo_colours:
        ld hl,anim_fe
        ld a,(hl)
        rrca
        rrca
        rrca
        and 7
        ld (tmpc),a
        ld d,LOGO_ROW
.r:     ld e,0
.c:     call bg_addr
        ld a,(hl)
        or a
        jr z,.n
        push hl
        ld hl,LOGO_LETTER
        ld a,e
        call add_hl_a
        ld a,(hl)
        inc a
        jr nz,.lt
        pop hl                      ; a star, not the logo
        jr .n
.lt:    ld a,(tmpc)
        add a,(hl)
        and 7
        ld hl,LOGO_COLS
        call add_hl_a
        ld a,(hl)
        pop hl
        set 2,h
        ld b,a
        ld a,(hl)
        and 0Fh
        or b
        ld (hl),a
.n:     inc e
        ld a,e
        cp 40
        jr c,.c
        call row_dirty
        inc d
        ld a,d
        cp LOGO_ROW+LOGO_H
        jr c,.r
        ret

; chasing bulbs along the tent's valance
marquee:
        ld a,(anim_fe)
        rrca
        and 7Fh
        ld (tmpc),a
        ld e,MARQ_C0
.l:     ld a,e
        srl a
        ld hl,tmpc
        add a,(hl)
        and 3
        ld b,WHITE*16+MARQ_BG
        jr z,.p
        and 1
        ld b,RED*16+MARQ_BG
        jr z,.p
        ld b,YELLOW*16+MARQ_BG
.p:     ld c,G_BALLOON
        ld d,MARQ_ROW
        call bg_touch_put
        inc e
        inc e
        ld a,e
        cp MARQ_C1+1
        jr c,.l
        ret

; twinkling stars
stars:
        call rand
        and 7
        ret nz
        ld b,NSTARS
        call rand_below
        add a,a
        ld hl,STARS
        call add_hl_a
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld b,3
        call rand_below
        ld hl,star_glyphs
        call add_hl_a
        ld c,(hl)
        ld b,WHITE*16+BLUE
        ld a,c
        cp 2Eh
        jr nz,$+4
        ld b,YELLOW*16+BLUE
        jp bg_touch_put
star_glyphs:    db 6Bh,2Eh,0

; the clown in the tent door winks now and then
wink:
        ld a,(anim_fe)
        and 63
        cp 2
        ld c,0CEh
        jr nc,$+4
        ld c,0CFh
        ld d,FACE_ROW
        ld e,FACE_COL
        ld b,YELLOW*16+BLACK
        jp bg_touch_put

; balloons floating up beside the tent (objects)
tballoons:
        ld c,0
.l:     ld a,c
        add a,a
        ld hl,t_bal
        call add_hl_a               ; HL = (row, col)
        push bc
        ld a,(anim_fe)
        add a,c
        and 7
        jr nz,.nm
        dec (hl)                    ; up a row
        ld a,(hl)
        cp 7
        jr nc,.nm
        push hl
        call new_tballoon
        pop hl
.nm:    ld d,(hl)
        inc hl
        ld e,(hl)
        pop bc
        push bc
        ld a,c
        ld hl,tbal_cols
        call add_hl_a
        ld b,(hl)
        ld c,G_BALLOON
        push de
        call put_at
        pop de
        inc d
        ld b,WHITE*16
        ld c,G_STRING
        call put_at
        pop bc
        inc c
        ld a,c
        cp 6
        jr c,.l
        ret
tbal_cols:      db RED*16,YELLOW*16,CYAN*16,MAGENTA*16,GREEN*16,WHITE*16

; bottom line message A
title_msg:
        ld b,BLACK
        ld c,0
        ld d,TMSG_ROW
        ld e,0
        ld a,40
        call bg_fill_run
        ld a,(t_msg)
        or a
        jr nz,.n0
        ld hl,txt_press
        jp .pr
.n0:    dec a
        jr nz,.n1
        ld hl,txt_hi                ; HI 015000 BPM
        ld de,strbuf
        call strcpy
        ld hl,hiscores+3
        call bcd6_append
        ld a,' '
        ld (de),a
        inc de
        ld hl,hiscores
        ld bc,3
        ldir
        xor a
        ld (de),a
        ld hl,strbuf
        jr .pr
.n1:    dec a
        jr nz,.n2
        ld hl,txt_sound
        ld de,strbuf
        call strcpy
        ld a,(snd_mute)
        or a
        ld hl,txt_on
        jr z,$+5
        ld hl,txt_off
        call strcpy
        ld hl,strbuf
        jr .pr
.n2:    dec a
        jr nz,.n3
        ld hl,txt_diff
        ld de,strbuf
        call strcpy
        ld a,(difficulty)
        add a,a
        ld hl,difftxt
        call add_hl_a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call strcpy
        ld hl,strbuf
        jr .pr
.n3:    dec a
        jr nz,.n4
        ld hl,txt_joy
        ld de,strbuf
        call strcpy
        ld a,(joy_mode)
        add a,a
        ld hl,joytxt
        call add_hl_a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call strcpy
        ld hl,strbuf
        jr .pr
.n4:    dec a
        ld hl,txt_tkeys
        jr z,.pr
        dec a
        ld hl,txt_credit
        jr z,.pr
        ld hl,txt_machine
.pr:    ld d,TMSG_ROW
        ld b,YELLOW*16
        jp bg_centre
NTMSG           equ 8
difftxt:        dw txt_easy,txt_normal,txt_hard
joytxt:         dw txt_off,txt_jstick,txt_jpaddle

; append 6 BCD digits from HL (3 bytes) at DE
bcd6_append:
        ld b,3
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .l
        xor a
        ld (de),a
        ret

; unpack an RLE screen into the background: (count, char, attr)... 0
unpack_screen:
        ld de,BGC
.l:     ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
.r:     push af
        ld a,c
        ld (de),a
        pop af
        set 2,d
        ld (de),a
        res 2,d
        inc de
        djnz .r
        jr .l

; ---------------------------------------------------------------------
; info pages
; ---------------------------------------------------------------------
howto_screen:
        ld a,BLUE
        call info_begin
        ld hl,txt_howto
        ld d,2
        ld b,YELLOW*16+BLUE
        call big_bg
        ld hl,howto_lines
        call print_lines
        call demo_seesaw
        ld hl,stripes_fx
        ld (page_fx),hl
        ld a,200
        jp page_wait

goodies_screen:
        ld a,BLACK
        call info_begin
        ld hl,txt_goodies
        ld d,2
        ld b,YELLOW*16+BLACK
        call big_bg
        ld hl,goodies_lines
        call print_lines
        ld hl,goodies_icons
        call put_icons
        ld hl,goodies_text
        call print_at_list
        ld hl,stripes_fx
        ld (page_fx),hl
        ld a,200
        jp page_wait

hiscore_screen:
        ld a,BLACK
        call info_begin
        ld hl,txt_topclowns
        ld d,2
        ld b,YELLOW*16+BLACK
        call big_bg
        call hs_table
        ld hl,stripes_fx
        ld (page_fx),hl
        ld a,200
        jp page_wait

preview_screen:
        ld a,BLUE
        call info_begin
        ld hl,txt_comingup
        ld d,2
        ld b,YELLOW*16+BLUE
        call big_bg
        ld hl,preview_lines
        call print_lines
        ld hl,preview_icons
        call put_icons
        ld hl,preview_text
        call print_at_list
        ld hl,preview_fx
        ld (page_fx),hl
        ld a,200
        jp page_wait

preview_fx:
        call stripes_fx
        ld a,(anim_fe)              ; the hoop flickers
        and 2
        ld b,RED*16+BLUE
        jr z,$+4
        ld b,YELLOW*16+BLUE
        ld d,7
        ld e,8
        ld c,68h
        call bg_touch_put
        ld e,10
        ld c,69h
        call bg_touch_put
        ld a,(anim_fe)              ; the bomb's fuse
        and 4
        ld b,BLACK*16+80h+BLUE
        jr z,$+4
        ld b,RED*16+80h+BLUE
        ld d,13
        ld e,9
        ld c,9Dh
        jp bg_touch_put

; lines: (row, attr, text..0)..., 0FFh
print_lines:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld d,a
        inc hl
        ld b,(hl)
        inc hl
        push hl
        call bg_centre
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        jr .l

; texts: (row, col, attr, text..0)..., 0FFh
print_at_list:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        ld b,(hl)
        inc hl
        call bg_print
        jr .l

; icons: (row, col, char, attr)..., 0FFh
put_icons:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        call bg_put
        jr .l

; a still life of the seesaw for the how-to page
demo_seesaw:
        ld hl,howto_pic
        jr put_icons

; the high-score table on rows 8..16
hs_table:
        ld hl,hiscores
        ld d,8
        ld c,0
.l:     push bc
        push hl
        ld de,strbuf                ; "1ST  BPM  015000"
        ld a,c
        add a,a
        add a,a
        push hl
        ld hl,rank_txt
        call add_hl_a
        ld bc,4
        ldir
        pop hl
        ld a,' '
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld bc,3
        ldir
        ld a,' '
        ld (de),a
        inc de
        ld (de),a
        inc de
        call bcd6_append
        pop hl
        pop bc
        push bc
        push hl
        ld a,c
        ld hl,rank_cols
        call add_hl_a
        ld b,(hl)
        ld a,c
        add a,a
        add a,8
        ld d,a
        ld a,(hs_new)               ; the new entry flashes yellow on white
        dec a
        cp c
        jr nz,.nn
        ld b,BLACK*16+YELLOW
.nn:    ld hl,strbuf
        call bg_centre
        pop hl
        ld de,6
        add hl,de
        pop bc
        inc c
        ld a,c
        cp 5
        jr c,.l
        ret
rank_txt:       db "1ST 2ND 3RD 4TH 5TH "
rank_cols:      db YELLOW*16,WHITE*16,CYAN*16,GREEN*16,MAGENTA*16

init_hiscores:
        ld hl,hs_default
        ld de,hiscores
        ld bc,30
        ldir
        ret
hs_default:
        db "BPM",01h,50h,00h
        db "VZ!",01h,00h,00h
        db "DSE",00h,75h,00h
        db "BOZ",00h,50h,00h
        db "MOE",00h,25h,00h

; ---------------------------------------------------------------------
; act card and curtains
; ---------------------------------------------------------------------
; returns Z normally, NZ if a key aborted the demo
act_intro:
        call mus_stop
        ; keep the arena under the card
        ld hl,BGC+CARD_ROW*40
        ld de,CARDSAVE
        ld bc,CARD_ROWS*40
        ldir
        ld hl,BGA+CARD_ROW*40
        ld de,CARDSAVE+300h
        ld bc,CARD_ROWS*40
        ldir
        call draw_card
        ; the revealed picture
        ld hl,BGC
        ld de,SRCBUF
        ld bc,1000
        ldir
        ld hl,BGA
        ld de,SRCBUF+400h
        ld bc,1000
        ldir
        ; curtains across rows 0..22
        ld c,0
.cc:    push bc
        ld a,c
        call curtain_col
        pop bc
        inc c
        ld a,c
        cp 40
        jr c,.cc
        ld a,(fieldcnt)
        ld (lastframe),a
        call fe_frame
        call curtain_open
        ld a,(demo)
        or a
        jr nz,.demo
        ld hl,SONG_ACT
        call mus_play
.jw:    call fe_frame
        call draw_scene
        ld a,(mus_on)
        or a
        jr nz,.jw
        ld a,10
        call .hold
        jr .done
.demo:  ld a,40
        call .hold
        call anykey
        jr z,.done
        ld a,1
        ld (demo_key),a
        or a
        ret
.done:  ; take the card away
        ld hl,CARDSAVE
        ld de,BGC+CARD_ROW*40
        ld bc,CARD_ROWS*40
        ldir
        ld hl,CARDSAVE+300h
        ld de,BGA+CARD_ROW*40
        ld bc,CARD_ROWS*40
        ldir
        ld d,CARD_ROW
        ld b,CARD_ROWS
.rd:    call row_dirty
        inc d
        djnz .rd
        xor a
        ret
.hold:  push af
        call fe_frame
        call draw_scene
        pop af
        dec a
        jr nz,.hold
        ret

; the seesaw and the clowns, waiting for the show to start
draw_scene:
        call draw_seesaw
        ld a,(pal+P_HAT)
        ld (tmpc),a
        ld a,(pal+P_BODY)
        ld (tmpy),a
        ld ix,clown0
        call draw_clown
        ld a,(pal+P_BODY)
        ld (tmpc),a
        ld a,(pal+P_HAT)
        ld (tmpy),a
        ld ix,clown1
        jp draw_clown

draw_card:
        ld d,CARD_ROW               ; black panel with a dotted frame
.r:     ld e,4
.c:     ld c,0
        ld b,BLACK
        ld a,d
        cp CARD_ROW
        jr z,.edge
        cp CARD_ROW+CARD_ROWS-1
        jr z,.edge
        ld a,e
        cp 4
        jr z,.edge
        cp 35
        jr nz,.put
.edge:  ld a,(pal+P_A1)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld c,G_BALLOON
        ld a,d
        add a,e
        and 1
        jr z,.put
        ld c,0
.put:   call bg_put
        inc e
        ld a,e
        cp 36
        jr c,.c
        inc d
        ld a,d
        cp CARD_ROW+CARD_ROWS
        jr c,.r
        ; "ACT n" or "BONUS"
        ld a,(actflags)
        and AF_BONUS
        jr nz,.bonus
        ld hl,txt_act
        ld de,strbuf
        call strcpy
        ld a,(encore)
        ld b,a
        ld a,(act)
        inc a
        inc b
        jr .ae
.al:    add a,NACTS
.ae:    djnz .al
        call num_append
        ld hl,strbuf
        jr .big
.bonus: ld hl,txt_bonus
.big:   ld d,CARD_ROW+1
        ld b,YELLOW*16+BLACK
        call big_bg
        call act_ptr
        ld de,14
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld d,CARD_ROW+5
        ld b,WHITE*16+BLACK
        call bg_centre
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld d,CARD_ROW+7
        ld b,CYAN*16+BLACK
        call bg_centre
        ld a,(encore)
        or a
        ret z
        ld hl,txt_encore
        ld d,CARD_ROW
        ld b,MAGENTA*16+BLACK
        jp bg_centre

; curtain column A (rows 0..22) into the background
curtain_col:
        ld e,a
        ld d,0
.l:     ld a,e
        and 1
        ld c,75h                    ; folds
        jr z,$+4
        ld c,31h
        ld b,MAGENTA*16+RED
        ld a,d
        cp 22
        jr nz,$+6
        ld c,0F3h                   ; a fringe
        ld b,YELLOW*16+RED
        call bg_touch_put
        inc d
        ld a,d
        cp 23
        jr c,.l
        ret

curtain_open:
        ld c,19
.l:     push bc
        ld a,c
        call reveal_col
        pop bc
        push bc
        ld a,39
        sub c
        call reveal_col
        call fe_frame
        pop bc
        dec c
        jp p,.l
        ret

; copy column A, rows 0..22, from SRCBUF into the background
reveal_col:
        ld e,a
        ld d,0
.l:     push de
        call bg_addr
        push hl
        ld bc,SRCBUF-BGC
        add hl,bc
        ld c,(hl)
        set 2,h
        ld b,(hl)
        pop hl
        pop de
        call bg_touch_put
        inc d
        ld a,d
        cp 23
        jr c,.l
        ret

curtain_close:
        ld c,0
.l:     push bc
        ld a,c
        call curtain_col
        pop bc
        push bc
        ld a,39
        sub c
        call curtain_col
        call fe_frame
        pop bc
        inc c
        ld a,c
        cp 20
        jr c,.l
        ret

; ---------------------------------------------------------------------
; celebrations
; ---------------------------------------------------------------------
act_clear:
        ld hl,SONG_CLEAR
        call mus_play
        ld a,(actflags)
        and AF_BONUS
        jr nz,.bon
        ld a,(misses_act)
        or a
        jr nz,.cel
        ld de,5000h
        call add_pts
        ld a,1
        ld (nomiss),a
        jr .cel
.bon:   ld a,(bonus_pops)           ; 30 or more: a bonus for the round
        cp 30
        jr c,.cel
        ld de,3000h
        call add_pts
.cel:   call hud_draw
        ld a,75
        ld (cel_t),a
.lp:    call fe_frame
        ld a,(cel_t)
        and 7
        jr nz,.nc
        ld b,110
        call rand_below
        add a,25
        ld b,a
        ld b,a
        push bc
        ld b,60
        call rand_below
        add a,30
        pop bc
        ld c,a
        ld a,8
        ld e,10
        call confetti
.nc:    call parts_update
        call popups_update
        ld hl,tickpar
        inc (hl)
        call draw_frame
        ld hl,txt_bravo
        ld a,(actflags)
        and AF_BONUS
        jr z,$+5
        ld hl,txt_timeup
        ld d,6
        ld a,(cel_t)
        and 4
        ld b,YELLOW*16
        jr z,$+4
        ld b,WHITE*16
        call big_obj
        ld a,(actflags)
        and AF_BONUS
        jr nz,.cb
        ld a,(nomiss)
        or a
        jr z,.cn
        ld hl,txt_nomiss
        jr .cap
.cb:    ld hl,txt_popped
        ld de,strbuf
        call strcpy
        ld a,(bonus_pops)
        call num_append
        ld hl,strbuf
.cap:   push hl
        call strlen
        pop hl
        ld c,a
        ld a,40
        sub c
        srl a
        ld e,a
        ld d,10
        ld b,WHITE*16
        call put_text
.cn:    ld hl,cel_t
        dec (hl)
        jp nz,.lp
        xor a
        ld (nomiss),a
        call sfx_stop
        ld hl,popups                ; tidy away the leftovers
        ld de,popups+1
        ld bc,NPOPS*PU_SIZE-1
        ld (hl),0
        ldir
        ld hl,parts
        ld de,parts+1
        ld bc,NPARTS*PT_SIZE-1
        ld (hl),0
        ldir
        call draw_frame
        call fe_frame
        jp curtain_close

game_over:
        ld hl,SONG_OVER
        call mus_play
        ld a,100
        ld (cel_t),a
.lp:    call fe_frame
        call parts_update
        call popups_update
        ld hl,tickpar
        inc (hl)
        call draw_frame
        ld hl,txt_gameover
        ld d,6
        ld b,WHITE*16
        call big_obj
        ld hl,txt_gameover2
        ld d,10
        ld e,9
        ld b,YELLOW*16
        call put_text
        ld a,(cel_t)
        cp 60
        jr nc,.nk
        call anykey
        jr nz,.x
.nk:    ld hl,cel_t
        dec (hl)
        jr nz,.lp
.x:     call mus_stop
        jp wait_release

; ---------------------------------------------------------------------
; pause: P or BREAK resumes, S sound, Q quits
; ---------------------------------------------------------------------
pause_game:
        call sfx_stop
        call wait_release
.w:     call fe_frame
        call draw_frame
        ld hl,txt_paused
        ld d,6
        ld b,WHITE*16
        call big_obj
        ld hl,txt_pausehelp
        ld d,10
        ld e,8
        ld b,YELLOW*16
        call put_text
        call read_keys
        ld a,(key_extra)
        bit 1,a
        jr z,.ns
        ld a,(snd_mute)
        xor 1
        ld (snd_mute),a
        call wait_release
        jr .w
.ns:    bit 3,a
        jr z,.nq
        ld a,2
        ld (gameresult),a
        jp wait_release
.nq:    and 11h
        jr z,.w
        call wait_release
        ld a,(fieldcnt)
        ld (lastframe),a
        ret

; ---------------------------------------------------------------------
; high scores
; ---------------------------------------------------------------------
hiscore_check:
        xor a
        ld (hs_new),a
        ld hl,hiscores+3            ; find the rank
        ld c,0
.f:     push hl
        ld de,score
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.lower
        jr nz,.higher
        inc hl
        inc de
        djnz .cmp
.lower: pop hl                      ; equal or lower: next
        ld de,6
        add hl,de
        inc c
        ld a,c
        cp 5
        jr c,.f
        ret
.higher:
        pop hl
        ld a,c
        ld (hs_rank),a
        ld a,4                      ; shift the lower entries down
        sub c
        jr z,.ins
        ld b,a
        ld hl,hiscores+4*6-1
        ld de,hiscores+5*6-1
.sh:    push bc
        ld bc,6
        lddr
        pop bc
        djnz .sh
.ins:   ld a,(hs_rank)
        ld b,a
        add a,a
        add a,b
        add a,a
        ld hl,hiscores
        call add_hl_a
        ld (hs_ptr),hl
        ld (hl),'A'
        inc hl
        ld (hl),' '
        inc hl
        ld (hl),' '
        inc hl
        ex de,hl
        ld hl,score
        ld bc,3
        ldir
        ld hl,SONG_HISCORE
        call mus_play
        call name_entry
        ld a,(hs_rank)
        inc a
        ld (hs_new),a
        call hiscore_screen
        xor a
        ld (hs_new),a
        ret

name_entry:
        ld a,BLUE
        call info_begin
        ld hl,txt_newhigh
        ld d,2
        ld b,YELLOW*16+BLUE
        call big_bg
        ld hl,entry_lines
        call print_lines
        xor a
        ld (hs_pos),a
        call wait_release
        xor a
        ld (hs_prevkey),a
        ld bc,25*60                 ; a minute at most
.l:     push bc
        call fe_frame
        call stripes_fx
        call name_show
        call getkey
        ld hl,hs_prevkey
        cp (hl)
        ld (hl),a
        jr z,.held
        or a
        jr z,.held
        cp 13
        jr z,.done
        cp 8
        jr z,.back
        call hs_setchar             ; a letter: type it and move on
        call hs_next
        jr nz,.done
        jr .tick
.back:  ld a,(hs_pos)
        or a
        jr z,.tick
        call hs_getchar             ; clear this one, step back
        ld a,' '
        call hs_setchar
        ld hl,hs_pos
        dec (hl)
        jr .tick
.held:  call fe_keys                ; cursor up / down picks, SPACE moves on
        bit B_UP,a
        jr z,.nu
        call hs_getchar
        call hs_letter
        inc a
        cp 'Z'+1
        jr c,$+4
        ld a,'A'
        call hs_setchar
.nu:    bit B_DOWN,a
        jr z,.nd
        call hs_getchar
        call hs_letter
        dec a
        cp 'A'
        jr nc,$+4
        ld a,'Z'
        call hs_setchar
.nd:    bit B_FIRE,a
        jr z,.tick
        call hs_next
        jr nz,.done
.tick:  pop bc
        dec bc
        ld a,b
        or c
        jr nz,.l
        jr .fin
.done:  pop bc
.fin:   call name_show
        call fe_frame
        ld hl,SFX_POWER
        ld a,3
        call sfx
        ld a,25
.w:     push af
        call fe_frame
        pop af
        dec a
        jr nz,.w
        jp wait_release

; space -> 'A' when picking with the cursor keys
hs_letter:
        cp 'A'
        ret nc
        ld a,'A'
        ret

hs_getchar:
        ld hl,(hs_ptr)
        ld a,(hs_pos)
        call add_hl_a
        ld a,(hl)
        ret

hs_setchar:
        push af
        call hs_getchar
        pop af
        ld (hl),a
        ret

; next letter; NZ when the name is complete
hs_next:
        ld a,(hs_pos)
        inc a
        cp 3
        jr nc,.end
        ld (hs_pos),a
        call hs_getchar
        cp ' '
        jr nz,.z
        ld a,'A'
        call hs_setchar
.z:     xor a
        ret
.end:   ld a,1
        or a
        ret

; the name in big letters, the current letter flashing
name_show:
        ld hl,(hs_ptr)
        ld d,12
        ld e,14
        ld c,0
.l:     push bc
        push hl
        ld a,(hs_pos)
        cp c
        ld b,WHITE*16+BLUE
        jr nz,.nf
        ld a,(anim_fe)
        and 4
        jr z,.nf
        ld b,YELLOW*16+BLUE
.nf:    ld hl,bg_touch_put
        ld (big_out),hl
        ld a,1
        ld (big_solid),a
        pop hl
        ld a,(hl)
        inc hl
        push hl
        call big_char
        pop hl
        pop bc
        ld a,e
        add a,4
        ld e,a
        inc c
        ld a,c
        cp 3
        jr c,.l
        ret
