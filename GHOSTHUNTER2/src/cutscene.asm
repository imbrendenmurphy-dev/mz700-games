; =====================================================================
;  cutscene.asm - the two cheeky intermissions
;    1 "Who's hunting who?"  GRUMBLE chases the hero (BOO!), then the
;      hero turns round and chases him back (EEK!)
;    2 "The night shift"  ghosts tiptoe up to the sleeping hero (ZZZ)
;      until he wakes up (WOW!) and they flee
; =====================================================================
CUT_ROW         equ 14              ; sprites on rows 14-16, floor on 17

; A = 1 or 2
run_intermission:
        push af
        call mus_stop
        call wipe_out
        ld a,BLACK*16+BLACK
        call cls_bg
        ld b,0
.fl:    ld a,7Ah
        ld c,CUT_ROW+3
        ld e,GREEN*16+BLACK
        call bg_putc
        inc b
        ld a,b
        cp 40
        jr nz,.fl
        pop af
        push af
        cp 2
        ld hl,s_i1
        jr nz,$+5
        ld hl,s_i2
        ld c,5
        ld a,YELLOW*16+BLACK
        call bg_centre
        call wipe_in
        ld hl,SONG_INTER
        call mus_play
        xor a
        ld (cut_pt),a
        ld hl,0
        ld (attr_t),hl
        pop af
        cp 2
        jp z,inter2

; --- 1: WHO'S HUNTING WHO?
inter1:
.loop:  call ovl_clear
        call cut_anim
        ld hl,(attr_t)
        ld a,h
        or a
        jr nz,.p2
        ld a,l
        cp 200
        jr nc,.p2
        ; hero runs left, GRUMBLE right behind
        ld a,l
        call div5
        ld e,a
        ld a,38
        sub e
        ld b,a
        push bc
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,BH_L0
        ld c,CUT_ROW
        call draw_big
        pop bc
        ld a,b
        add a,6
        ld b,a
        ld a,(anim)
        add a,BG_RED0
        ld c,CUT_ROW
        call draw_big
        ld a,(attr_t)
        cp 70
        jr nz,.pop
        ld a,(attr_t)               ; BOO! over GRUMBLE
        call div5
        ld e,a
        ld a,44
        sub e
        ld b,a
        ld hl,sboo
        call cut_popup
        jr .pop
.p2:    ld hl,(attr_t)              ; giant hero chases GRUMBLE back
        ld de,200
        or a
        sbc hl,de
        ld a,l
        cp 190
        jr nc,.end
        srl a
        srl a
        sub 3
        ld b,a
        push bc
        ld a,(anim)
        add a,BG_BLUE0
        ld c,CUT_ROW
        call draw_big
        pop bc
        ld a,b
        sub 6
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,BH_R0
        ld c,CUT_ROW
        call draw_big
        ld hl,(attr_t)
        ld a,l
        sub 200
        cp 60
        jr nz,.pop
        srl a
        srl a
        sub 4
        ld b,a
        ld hl,seek
        call cut_popup
.pop:   call frame
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        jp .loop
.end:   jp cut_end

; --- 2: THE NIGHT SHIFT
inter2:
.loop:  call ovl_clear
        call cut_anim
        ld hl,(attr_t)
        ld a,h
        or a
        jp nz,.end
        ld a,l
        cp 250
        jp nc,.end
        cp 150
        jr nc,.awake
        ld b,6                      ; the hero sleeps, mouth shut
        ld c,CUT_ROW
        ld a,BH_R1
        call draw_big
        ld a,(attr_t)
        and 31
        jr nz,.nz
        ld b,7
        ld hl,szzz
        call cut_popup
.nz:    ld a,(attr_t)               ; four ghosts tiptoe in from the right
        call div5
        ld e,a
        ld a,42
        sub e
        ld b,a
        ld e,0
.g:     push bc
        push de
        ld a,e
        add a,a
        add a,BG_RED0
        ld e,a
        ld a,(attr_t)
        rrca
        rrca
        rrca
        rrca
        and 1
        add a,e
        ld c,CUT_ROW
        call draw_big
        pop de
        pop bc
        ld a,b
        add a,5
        ld b,a
        inc e
        ld a,e
        cp 4
        jr nz,.g
        jr .fr
.awake: jr nz,.na                   ; WOW! the hero wakes up
        ld b,6
        ld hl,swow
        call cut_popup
        ld hl,SFX_POWER
        ld a,4
        call sfx
.na:    ld a,(attr_t)               ; ghosts flee right, the hero follows
        sub 150
        ld e,a
        srl a
        add a,e
        srl a                       ; 0.75 per frame
        add a,10
        ld b,a
        push bc
        ld a,b
        sub 9
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,BH_R0
        ld c,CUT_ROW
        call draw_big
        pop bc
        ld e,4
.f:     push bc
        push de
        ld a,(anim)
        add a,BG_BLUE0
        ld c,CUT_ROW
        call draw_big
        pop de
        pop bc
        ld a,b
        add a,5
        ld b,a
        dec e
        jr nz,.f
.fr:    call frame
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        jp .loop
.end:   ld hl,s_i2b
        ld c,21
        ld a,CYAN*16+BLACK
        call print_centre
        ld b,90
.w:     push bc
        call ovl_clear
        call frame
        pop bc
        djnz .w
cut_end:
        call mus_stop
        ret

; leg animation and the pop-up text
cut_anim:
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        ld (anim),a
        ld a,(cut_pt)
        or a
        ret z
        dec a
        ld (cut_pt),a
        ld a,(cut_px)
        ld b,a
        ld c,CUT_ROW-2
        ld hl,(cut_ps)
        ld a,(framecount)
        and 4
        ld e,WHITE*16
        jr z,$+4
        ld e,YELLOW*16
        jp ovl_sc_text

; pop-up HL at column B for 40 frames
cut_popup:
        ld (cut_ps),hl
        ld a,b
        ld (cut_px),a
        ld a,40
        ld (cut_pt),a
        ret

; A / 5
div5:   ld e,0
.l:     sub 5
        jr c,.d
        inc e
        jr .l
.d:     ld a,e
        ret
