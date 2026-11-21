; =====================================================================
;  screens.asm - title, story, guide, records, name entry and ending
; =====================================================================

LOGO_ROW        equ 1
SCROLL_ROW      equ 24
PARADE_ROW      equ 12

; ---------------------------------------------------------------------
; page helpers
; ---------------------------------------------------------------------
; page_wait: wait up to A half-seconds, calling (page_fx) every field.
; Returns Z on time-out, else NZ (SPACE / CR).
page_wait:
        ld (page_len),a
        ld b,a
        ld c,25
        call wait_release
.l:     push bc
        call wait_field
        ld hl,anim_fe
        inc (hl)
        ld hl,(page_fx)
        call jp_hl
        call read_keys
        pop bc
        ld a,(key_extra)
        and 1
        jr nz,.go
        ld a,(key_pause)
        or a
        jr nz,.go
        dec c
        jr nz,.l
        ld c,25
        djnz .l
        xor a
        ret
.go:    ld a,1
        or a
        ret

jp_hl:  jp (hl)

no_fx:  ret

; draw the current look of element A at VRAM address DE (2 x 2 cells)
fe_tile:
        push de
        ld e,a
        ld d,high CUR
        ld a,(de)
        pop de
        jp draw_tile

; CUR for the front end: animation phase from anim_fe, theme 0
fe_cur:
        ld a,(anim_fe)
        rrca
        rrca
        and 7
        ld (anim),a
        jp build_cur

; centred heading on a coloured bar: HL = text, C = row
heading:
        push bc
        push hl
        ld b,c
        ld c,1
        ld a,WHITE*16+BLUE
        call clear_rows
        pop hl
        pop bc
        ld a,WHITE*16+BLUE
        jp print_centre

; print lines: HL = list of (row, colour, text...0), ends with 0FFh;
; every line is centred
print_lines:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld c,a
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call print_centre_keep
        pop hl
.s:     ld a,(hl)                   ; skip the text
        inc hl
        or a
        jr nz,.s
        jr .l

print_centre_keep:
        jp print_centre

; ---------------------------------------------------------------------
; title screen
; ---------------------------------------------------------------------
title_screen:
        ld a,(mus_on)
        or a
        jr nz,.playing
        ld hl,SONG_TITLE
        call mus_play
.playing:
        ld a,BLACK
        call cls
        xor a
        ld (theme),a
        ld (pl_dead),a
        ld (done_flag),a
        ld a,1
        ld (pl_moved),a
        ld a,2
        ld (pl_face),a
        ; logo
        ld hl,LOGO
        ld de,VRAM+LOGO_ROW*40
        ld bc,LOGO_H*40
        ldir
        xor a
        ld (logo_phase),a
        call logo_colours
        ld hl,title_lines
        call print_lines
        call best_line
        ld hl,scroll_text
        ld (scroll_ptr),hl
        xor a
        ld (scroll_tick),a
        ld hl,title_fx
        ld (page_fx),hl
        ld a,40                     ; 20 seconds
        jp page_wait

title_fx:
        ld hl,logo_phase
        inc (hl)
        ld a,(hl)
        and 3
        call z,logo_colours
        call scroller
        call parade
        ; flash the start line
        ld a,(logo_phase)
        and 16
        ld a,WHITE*16
        jr z,$+4
        ld a,YELLOW*16
        ld de,VRAM+16*40
        ld b,40
        jp fill_attr

; the creatures of the deep, marching on the spot
parade:
        call fe_cur
        ld hl,parade_tab
        ld de,VRAM+PARADE_ROW*40+4
.l:     ld a,(hl)
        cp 0FFh
        ret z
        inc hl
        push hl
        push de
        call fe_tile
        pop de
        pop hl
        inc de
        inc de
        inc de
        jr .l

parade_tab:
        db E_PLAYER, E_GEM, E_ROCK, E_EGG, E_MONSTER, E_SPIRIT0, E_CAGE, E_PIECE
        db E_CROWN, E_KEY, E_TRANS, 0FFh

; logo rows: a warm gradient with a white glint sweeping down
logo_colours:
        ld a,(logo_phase)
        rrca
        rrca
        and 15
        ld c,a
        ld de,VRAM+LOGO_ROW*40
        ld hl,logo_grad
        ld b,0
.r:     ld a,b
        cp c
        ld a,(hl)
        jr nz,.nc
        ld a,WHITE*16
.nc:    push bc
        push hl
        ld b,40
        call fill_attr
        pop hl
        pop bc
        inc hl
        inc b
        ld a,b
        cp LOGO_H
        jr c,.r
        ret

logo_grad:
        db YELLOW*16,YELLOW*16,GREEN*16,GREEN*16,GREEN*16,CYAN*16,BLUE*16,BLUE*16

; text scroller on the bottom row
scroller:
        ld hl,scroll_tick
        inc (hl)
        ld a,(hl)
        and 3                       ; one character every 4 fields
        ret nz
        ld hl,VRAM+SCROLL_ROW*40+1
        ld de,VRAM+SCROLL_ROW*40
        ld bc,39
        ldir
        ld hl,(scroll_ptr)
        ld a,(hl)
        or a
        jr nz,.ok
        ld hl,scroll_text
        ld a,(hl)
.ok:    inc hl
        ld (scroll_ptr),hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        ld (VRAM+SCROLL_ROW*40+39),a
        ld de,VRAM+SCROLL_ROW*40
        ld b,40
        ld a,GREEN*16
        jp fill_attr

; "BEST: NAM  100%  0:12:34" on row 18
best_line:
        ld hl,txt_best
        ld b,10
        ld c,18
        ld a,CYAN*16
        call print_at
        ld hl,RECORDS
        jp record_print

; ---------------------------------------------------------------------
; story page
; ---------------------------------------------------------------------
story_page:
        ld a,BLACK
        call cls
        ld hl,txt_story_h
        ld c,0
        call heading
        ld hl,story_lines
        call print_lines
        ld hl,story_fx
        ld (page_fx),hl
        ld a,24
        jp page_wait

story_fx:
        call fe_cur
        ld a,E_PLAYER
        ld de,VRAM+20*40+19
        call fe_tile
        ld a,E_GATE
        ld de,VRAM+20*40+25
        call fe_tile
        ld a,E_PIECE
        ld de,VRAM+20*40+13
        jp fe_tile

; ---------------------------------------------------------------------
; guide page: what lives in the caverns (two columns of tiles)
; ---------------------------------------------------------------------
guide_page:
        ld a,BLACK
        call cls
        ld hl,txt_guide_h
        ld c,0
        call heading
        ld hl,guide_tab
        ld de,VRAM+2*40+1
        ld b,16
.e:     push bc
        inc hl                      ; skip the element
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        push de
        inc de
        inc de
        inc de
        ld c,YELLOW*16
        call print
        pop de
        pop hl
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        push de
        ld a,e
        add a,40+3
        ld e,a
        jr nc,$+3
        inc d
        ld c,CYAN*16
        call print
        pop de
        pop hl
        inc hl
        call guide_next
        pop bc
        djnz .e
        ld hl,guide_ctl
        call print_lines
        ld hl,guide_fx
        ld (page_fx),hl
        ld a,30
        jp page_wait

; DE = next guide slot (8 rows of 2 lines per column)
guide_next:
        push hl
        ld hl,80
        add hl,de
        ex de,hl
        ld hl,VRAM+18*40+1
        or a
        sbc hl,de
        jr nz,.ok
        ld de,VRAM+2*40+21          ; second column
.ok:    pop hl
        ret

guide_fx:
        call fe_cur
        ld hl,guide_tab
        ld de,VRAM+2*40+1
        ld b,16
.e:     push bc
        ld a,(hl)
        push hl
        push de
        call fe_tile
        pop de
        pop hl
        ld bc,5
        add hl,bc
        call guide_next
        pop bc
        djnz .e
        ret

; ---------------------------------------------------------------------
; records page
; ---------------------------------------------------------------------
records_page:
        ld a,BLACK
        call cls
        ld hl,txt_rec_h
        ld c,0
        call heading
        ld hl,txt_rec_cols
        ld b,6
        ld c,3
        ld a,CYAN*16
        call print_at
        ld hl,RECORDS
        ld c,5
        ld b,8
.r:     push bc
        push hl
        ld a,c
        sub 4
        srl a
        inc a
        add a,20h
        push af
        ld b,6
        call vaddr
        pop af
        ld c,WHITE*16
        call putc
        inc de
        inc de
        inc de
        pop hl
        push hl
        call record_print
        pop hl
        ld bc,8
        add hl,bc
        pop bc
        inc c
        inc c
        djnz .r
        ld hl,no_fx
        ld (page_fx),hl
        ld a,16
        jp page_wait

; print record HL at DE: name, percent, time, deaths
record_print:
        ld b,3
        ld c,YELLOW*16
.n:     ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        call putc
        inc hl
        inc de
        djnz .n
        inc de
        inc de
        ld a,(hl)                   ; percent
        inc hl
        ld c,WHITE*16
        push hl
        call print_dec3
        pop hl
        ld a,65h                    ; %
        call putc
        inc de
        inc de
        inc de
        ld a,(hl)                   ; hours
        inc hl
        push hl
        add a,20h
        call putc
        inc de
        ld a,4Fh                    ; :
        call putc
        inc de
        pop hl
        ld a,(hl)
        inc hl
        push hl
        call print_dec2
        ld a,4Fh
        call putc
        inc de
        pop hl
        ld a,(hl)
        inc hl
        push hl
        call print_dec2
        pop hl
        inc de
        inc de
        ld a,(hl)                   ; deaths
        ld c,RED*16
        jp print_dec3

records_init:
        ld hl,records_default
        ld de,RECORDS
        ld bc,8*8
        ldir
        ret

records_default:
        db "BPM",60,1,30,0,9
        db "SKN",50,1,20,0,12
        db "VIB",40,1,0,0,7
        db "MZ7",30,0,50,0,5
        db "ROC",25,0,40,0,4
        db "GEM",20,0,30,0,3
        db "EGG",15,0,20,0,2
        db "SUN",10,0,10,0,1

; ---------------------------------------------------------------------
; record_entry: after a game, if the result belongs in the table, ask
; for a name and insert it
; ---------------------------------------------------------------------
record_entry:
        call percent_done
        ld (rec_pct),a
        ; find the slot: higher percent first, then the faster time
        ld hl,RECORDS
        ld b,0
.f:     push hl
        call rec_better
        pop hl
        jr c,.found
        ld de,8
        add hl,de
        inc b
        ld a,b
        cp 8
        jr c,.f
        ret                         ; not good enough
.found: ld (rec_ptr),hl
        ; move the rest down
        ld a,7
        sub b
        jr z,.nomove
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,RECORDS+7*8-1
        ld de,RECORDS+8*8-1
        lddr
.nomove:
        call name_entry
        ld hl,(rec_ptr)
        ld de,PBUF
        ex de,hl
        ld bc,3
        ldir
        ld a,(rec_pct)
        ld (de),a
        inc de
        ld hl,ptime
        ld bc,3
        ldir
        ld hl,(deaths)
        ld a,h
        or a
        ld a,l
        jr z,$+4
        ld a,255
        ld (de),a
        ret

; carry if the new result (rec_pct, ptime) beats record HL
rec_better:
        inc hl
        inc hl
        inc hl
        ld a,(rec_pct)
        cp (hl)
        jr z,.t
        ccf                         ; higher percent: carry
        ret
.t:     inc hl
        ld de,ptime
        ld c,3
.c:     ld a,(de)
        cp (hl)
        ret nz                      ; carry if faster
        inc hl
        inc de
        dec c
        jr nz,.c
        or a
        ret

; A = percent of the world done (gems, pieces, monsters)
percent_done:
        ld a,(won)
        or a
        ld a,100
        ret nz
        ld hl,(gems_left)
        ld a,(pieces_left)
        ld e,a
        ld d,0
        add hl,de
        ld a,(mons_left)
        ld e,a
        add hl,de                   ; left
        ex de,hl
        ld hl,TOTAL_GEMS+TOTAL_PIECES+TOTAL_MONS
        or a
        sbc hl,de                   ; done
        ld b,h
        ld c,l
        ld hl,0
        ld a,100
.m:     add hl,bc
        dec a
        jr nz,.m                    ; done * 100
        ld de,TOTAL_GEMS+TOTAL_PIECES+TOTAL_MONS
        ld a,0FFh
.d:     inc a
        or a
        sbc hl,de
        jr nc,.d
        cp 100
        ret c
        ld a,99                     ; 100 only for a finished game
        ret

; name_entry: three letters into PBUF
name_entry:
        ld a,BLACK
        call cls
        ld hl,txt_name_h
        ld c,6
        call heading
        ld hl,txt_name_help
        ld c,16
        ld a,CYAN*16
        call print_centre
        ld hl,PBUF
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        xor a
        ld (rec_i),a
        call fe_reset
.l:     call wait_field
        ; draw the letters
        ld hl,PBUF
        ld de,VRAM+11*40+18
        ld b,0
.d:     ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,WHITE*16
        push af
        ld a,(rec_i)
        cp b
        jr nz,.nc
        ld c,YELLOW*16+RED
.nc:    pop af
        call putc
        inc hl
        inc de
        inc b
        ld a,b
        cp 3
        jr c,.d
        call fe_keys
        ld b,a
        ld a,(key_extra)
        and 1
        jr nz,.done
        ld a,(key_pause)
        or a
        jr nz,.done
        ld hl,PBUF
        ld a,(rec_i)
        ld e,a
        ld d,0
        add hl,de
        bit B_UP,b
        jr z,.nu
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,$+4
        ld a,'A'
        ld (hl),a
.nu:    bit B_DOWN,b
        jr z,.nd
        ld a,(hl)
        dec a
        cp 'A'
        jr nc,$+4
        ld a,'Z'
        ld (hl),a
.nd:    bit B_RIGHT,b
        jr z,.nr
        ld a,(rec_i)
        cp 2
        jr nc,.nr
        inc a
        ld (rec_i),a
.nr:    bit B_LEFT,b
        jr z,.l
        ld a,(rec_i)
        or a
        jr z,.l
        dec a
        ld (rec_i),a
        jr .l
.done:  ld hl,SFX_GEM
        ld a,2
        call sfx
        jp wait_release

; ---------------------------------------------------------------------
; ending: the mosaic whole again
; ---------------------------------------------------------------------
ending:
        ld hl,SONG_WIN
        call mus_play
        ld a,BLACK
        call cls
        ld hl,txt_end_h
        ld c,0
        call heading
        ld a,TOTAL_PIECES
        ld de,VRAM+3*40+14
        call mosaic_draw
        ld hl,end_lines
        call print_lines
        ; stats
        ld hl,txt_time
        ld b,9
        ld c,17
        ld a,CYAN*16
        call print_at
        call print_time
        ld hl,txt_deaths
        ld b,9
        ld c,18
        ld a,CYAN*16
        call print_at
        ld hl,(deaths)
        ld c,WHITE*16
        call print_dec3w
        ld hl,txt_crowns
        ld b,9
        ld c,19
        ld a,CYAN*16
        call print_at
        ld a,(crowns_left)
        ld b,a
        ld a,TOTAL_CROWNS
        sub b
        ld c,YELLOW*16
        call print_dec2
        ld a,2Dh
        call putc
        inc de
        ld a,TOTAL_CROWNS
        call print_dec2
        ld hl,ending_fx
        ld (page_fx),hl
        ld a,120
        call page_wait
        call record_entry
        ld hl,SONG_TITLE
        jp mus_play

ending_fx:
        ld a,(anim_fe)
        and 7
        ret nz
        ; twinkle the rays
        ld hl,VRAM+3*40+14+800h
        ld b,8
.r:     push bc
        push hl
        ld b,12
.c:     ld a,(hl)
        and 0F0h
        cp YELLOW*16
        jr nz,.n
        ld a,(hl)
        and 0Fh
        cp BLUE
        jr nz,.n
        ld a,(anim_fe)
        and 8
        ld a,YELLOW*16+BLUE
        jr z,$+4
        ld a,WHITE*16+BLUE
        ld (hl),a
.n:     inc hl
        djnz .c
        pop hl
        ld de,40
        add hl,de
        pop bc
        djnz .r
        ret

; draw the first A pieces of the mosaic with its top-left at DE
; (the rest as dim placeholders)
mosaic_draw:
        ld (mos_n),a
        ld (mos_base),de
        ld ix,MOS_POS
        ld hl,MOS_CH
        ld b,0
.p:     push bc
        ld e,(ix+0)
        ld d,(ix+1)
        inc ix
        inc ix
        push hl
        ld hl,(mos_base)
        add hl,de
        ex de,hl                    ; DE = screen cell
        pop hl
        ld a,(mos_n)
        cp b
        jr z,.dim
        jr c,.dim
        call .cell
        call .cell
        call .down
        call .cell
        call .cell
        jr .nx
.dim:   inc hl
        inc hl
        inc hl
        inc hl
        ld c,BLUE*16
        ld a,0D0h
        call putc
        inc de
        ld a,0D0h
        call putc
        call .down2
        ld a,0D0h
        call putc
        inc de
        ld a,0D0h
        call putc
.nx:    pop bc
        inc b
        ld a,b
        cp 24
        jr c,.p
        ret
.cell:  ld a,(hl)
        push hl
        ld bc,96
        add hl,bc
        ld c,(hl)
        pop hl
        inc hl
        call putc
        inc de
        ret
.down:  ld a,e
        add a,38
        ld e,a
        ret nc
        inc d
        ret
.down2: ld a,e
        add a,39
        ld e,a
        ret nc
        inc d
        ret

; print play time h:mm:ss at DE
print_time:
        ld a,(ptime)
        add a,20h
        ld c,WHITE*16
        call putc
        inc de
        ld a,4Fh
        call putc
        inc de
        ld a,(ptime+1)
        call print_dec2
        ld a,4Fh
        call putc
        inc de
        ld a,(ptime+2)
        jp print_dec2
