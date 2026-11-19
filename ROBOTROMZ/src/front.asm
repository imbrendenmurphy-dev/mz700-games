; =====================================================================
;  front.asm - title page and "meet the robots" page, alternating
; =====================================================================

front_end:
        call snd_off
        xor a
        ld (page),a
.newpage:
        ld a,(page)
        or a
        call z,draw_title
        ld a,(page)
        or a
        call nz,draw_gallery
        ld hl,500
        ld (pagetm),hl
.loop:  call wait_vblank
        call flush
        call snd_tick
        call read_keys
        ld a,(sedge)
        and KS_SPACE
        ret nz
        ld a,(sedge)
        and KS_M
        jr z,.nm
        ld a,(sndon)
        xor 1
        ld (sndon),a
        call snd_off
        call show_sound
        ld hl,sfx_rescue
        ld a,1
        call play_sfx
.nm:    call animate_page
        ld hl,framecnt
        inc (hl)
        ld hl,(pagetm)
        dec hl
        ld (pagetm),hl
        ld a,h
        or l
        jr nz,.loop
        ld a,(page)
        xor 1
        ld (page),a
        jr .newpage

; text records: row, column (FFh = centred), attribute, string
print_recs:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        cp 0FFh
        jr z,.ctr
        push bc
        push hl
        ld c,a
        call calc_ofs
        ex de,hl
        pop hl
        pop bc
        call print_bg
        jr .l
.ctr:   call print_centre
        jr .l

page_frame:                     ; black page inside a checked border
        ld a,70h
        call clear_bg
        ld hl,BGCH
        ld de,BGCH+24*40
        ld b,40
.tb:    ld (hl),0D0h
        ld a,0D0h
        ld (de),a
        inc hl
        inc de
        djnz .tb
        ld hl,BGCH+40
        ld de,39
        ld b,23
.sd:    ld (hl),0D0h
        add hl,de
        ld (hl),0D0h
        inc hl
        djnz .sd
        ret

draw_title:
        call page_frame
        ld hl,logo              ; 4 rows x 35 block characters
        ld de,BGCH+2*40+2
        ld b,4
.lr:    push bc
        ld bc,35
        ldir
        ex de,hl
        ld bc,5
        add hl,bc
        ex de,hl
        pop bc
        djnz .lr
        ld hl,title_recs
        call print_recs
        ld hl,hiscore
        ld de,22*40+22
        ld c,50h
        call print_bcd6
        call show_sound
        jp refresh_all

show_sound:
        ld hl,s_snd_on
        ld a,(sndon)
        or a
        jr nz,.on
        ld hl,s_snd_off
.on:    ld de,17*40+18
        ld c,70h
        jp print_bg

draw_gallery:
        call page_frame
        ld hl,gallery_recs
        call print_recs
        call refresh_all
        ; fall through: draw the robots themselves
gallery_glyphs:
        ld hl,gallery
.l:     ld a,(hl)
        or a
        ret z
        push hl
        ld b,a                  ; row
        call tinfo_ptr_b        ; HL = tinfo for the type in the record
        ld d,(hl)
        ld a,(framecnt)
        and 16
        jr z,.g
        inc hl
        ld d,(hl)
        dec hl
.g:     inc hl
        inc hl
        ld a,(hl)
        and 0F0h                ; same colours on black
        ld e,a
        pop hl
        push hl
        inc hl
        ld c,(hl)               ; column
        push de
        call calc_ofs
        pop de
        call bg_put
        pop hl
        inc hl
        inc hl
        inc hl
        jr .l

tinfo_ptr_b:                    ; HL -> record (row, col, type): HL = tinfo
        inc hl
        inc hl
        ld a,(hl)
        jp tinfo_ptr

animate_page:
        ld a,(framecnt)
        and 7
        jr z,border_colours
        cp 4
        ret nz
        ld a,(page)
        or a
        jr nz,.gal
        ; title: logo colour bands roll across
        ld a,(framecnt)
        rrca
        rrca
        rrca
        ld (phase),a
        ld hl,2*40+2
        ld b,4
.r:     push bc
        push hl
        ld b,35
        ld c,0
.c:     push bc
        ld a,c
        srl a
        srl a
        ld b,a
        ld a,(phase)
        sub b
        and 7
        ld de,logocols
        add a,e
        ld e,a
        jr nc,.n1
        inc d
.n1:    ld a,(de)
        ld e,a
        call recolour
        inc hl
        pop bc
        inc c
        djnz .c
        pop hl
        ld de,40
        add hl,de
        pop bc
        djnz .r
        ; "PRESS SPACE" blinks
        ld a,(framecnt)
        and 32
        ld e,60h
        jr z,.p
        ld e,00h
.p:     ld hl,20*40+10
        ld b,20
.pl:    call recolour
        inc hl
        djnz .pl
        ret
.gal:   ld a,(framecnt)
        and 15
        cp 4
        ret nz
        jp gallery_glyphs

; the border's colours flow round diagonally
border_colours:
        ld a,(framecnt)
        rrca
        rrca
        rrca
        ld (phase),a
        ld hl,0
        ld c,0
        ld b,40
.t:     call border_cell
        inc hl
        inc c
        djnz .t
        ld hl,24*40
        ld c,24
        ld b,40
.bt:    call border_cell
        inc hl
        inc c
        djnz .bt
        ld hl,40
        ld c,1
        ld b,23
.s:     call border_cell
        push hl
        push bc
        ld de,39
        add hl,de
        ld a,c
        add a,39
        ld c,a
        call border_cell
        pop bc
        pop hl
        ld de,40
        add hl,de
        inc c
        djnz .s
        ret

; colour border cell HL by C (= row + column) and the phase
border_cell:
        push bc
        push hl
        ld a,(phase)
        sub c
        and 7
        ld hl,bordcols
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld e,(hl)
        pop hl
        call recolour
        pop bc
        ret

; give BG cell HL attribute E, keeping its character
recolour:
        push hl
        push bc
        ld bc,BGCH
        add hl,bc
        ld d,(hl)
        pop bc
        pop hl
        jp bg_put

bordcols:
        db 20h,60h,40h,50h,10h,30h,70h,60h
logocols:
        db 20h,20h,60h,60h,70h,50h,30h,30h

; ---------------------------------------------------------------------
title_recs:
        db 7,0FFh,60h
        db "- 2085 -",0
        db 9,0FFh,50h
        db "SHARP MZ-700 VERSION",0
        db 10,0FFh,70h
        db "VIBED BY BPM 2026",0
        db 13,6,70h
        db "MOVE        W A S D",0
        db 14,6,70h
        db "FIRE        I J K L",0
        db 15,6,70h
        db "            OR CURSOR KEYS",0
        db 16,6,70h
        db "PAUSE       RETURN",0
        db 17,6,70h
        db "SOUND (M)",0
        db 20,10,60h
        db "PRESS SPACE TO START",0
        db 22,13,50h
        db "HI SCORE",0
        db 0FFh

gallery_recs:
        db 2,0FFh,60h
        db "- THE ROBOTS -",0
        db 5,9,70h
        db "DROID          100",0
        db 7,9,70h
        db "PYLON           25",0
        db 9,9,70h
        db "CRUSHER        ---",0
        db 11,9,70h
        db "MINDBOT        500",0
        db 13,9,70h
        db "MUTANT         100",0
        db 15,9,70h
        db "ORB           1000",0
        db 17,9,70h
        db "SEEKER         150",0
        db 19,9,70h
        db "FACTORY       1000",0
        db 21,9,70h
        db "TANK           200",0
        db 5,30,70h
        db "SAVE",0
        db 7,30,70h
        db "THEM!",0
        db 23,0FFh,50h
        db "SHOOT THEIR SHOTS FOR 25",0
        db 0FFh

gallery:                        ; row, column, type (row 0 ends)
        db 5,6,T_DROID
        db 7,6,T_PYLON
        db 9,6,T_CRUSH
        db 11,6,T_BRAIN
        db 13,6,T_MUTANT
        db 15,6,T_ORB
        db 17,6,T_SEEKER
        db 19,6,T_FACT
        db 21,6,T_TANK
        db 9,30,T_MOM
        db 9,32,T_DAD
        db 9,34,T_KID
        db 0

s_snd_on:   db "ON ",0
s_snd_off:  db "OFF",0

        include "../build/gen_logo.inc"
