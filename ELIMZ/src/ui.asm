; =====================================================================
;  ui.asm - the look of the info screens: a box-drawn bezel round the
;  screen with the title set into its top line and the key hints into
;  its bottom line, section rules with their own titles, and key caps
;  (white on blue) in front of each menu entry.  All in the CG-ROM's
;  centred box glyphs, in blue like the console's bezel.
; =====================================================================

UI_KEY          equ (WHITE<<4)+BLUE     ; a key cap
UI_LABEL        equ CYAN<<4
UI_VALUE        equ WHITE<<4

; ---------------------------------------------------------------------
; ui_frame: clear the screen and draw the bezel.  HL = title, DE =
; footer (0: none), B = the first row with side lines (1, or 20 on the
; map screens, whose rows 1-18 are the view)
; ---------------------------------------------------------------------
ui_frame:
        ld (ui_t),hl
        ld (ui_f),de
        ld a,b
        ld (ui_s),a
        ld a,WHITE<<4
        call cls
        ld bc,5C00h                     ; top: corner, line, corner
        ld e,5Dh
        call ui_hline
        ld bc,1C00h+24                  ; bottom
        ld e,1Dh
        call ui_hline
        ld a,(ui_s)
        call ui_sides
        ld hl,(ui_t)
        ld c,0
        ld a,YELLOW<<4
        call ui_inset
        ld hl,(ui_f)
        ld a,h
        or l
        ret z
        ld c,24
        ld a,GREEN<<4
        jp ui_inset

; row C: B at the left, a line, E at the right
ui_hline:
        push bc
        push de
        ld a,c
        call row_addr
        pop de
        pop bc
        ld (hl),b
        call .attr
        inc hl
        ld b,38
.l:     ld (hl),078h
        call .attr
        inc hl
        djnz .l
        ld (hl),e
.attr:  set 3,h
        ld (hl),LINE_ATTR
        res 3,h
        ret

; side lines from row A down to row 23
ui_sides:
        call row_addr
.l:     ld (hl),079h
        call ui_hline.attr
        push hl
        ld de,39
        add hl,de
        ld (hl),079h
        call ui_hline.attr
        pop hl
        ld de,40
        add hl,de
        ld a,h
        cp high (VRAM+24*40)
        jr c,.l
        ld a,l
        cp low (VRAM+24*40)
        jr c,.l
        ret

; a section rule on row C, its title HL (0: none) set in at the left
ui_rule:
        push hl
        ld b,1Eh
        ld e,5Eh
        call ui_hline
        pop hl
        ld a,h
        or l
        ret z
        ld b,2
        ld a,UI_LABEL
        jr ui_inset.at

; set text HL into the line on row C, centred, in attr A
ui_inset:
        push af
        push hl
        ld b,0                          ; its length
.n:     ld a,(hl)
        inc hl
        or a
        jr z,.e
        inc b
        jr .n
.e:     ld a,40-4
        sub b
        srl a
        ld b,a
        pop hl
        pop af
; at column B
.at:    push af
        push hl
        push bc
        call vaddr                      ; DE = the cell
        ex de,hl
        ld (hl),05Eh                    ; the line's end, a gap
        call ui_hline.attr
        inc hl
        ld (hl),0
        inc hl
        ex de,hl
        pop bc
        pop hl
        pop af
        ld c,a
        call print
        ex de,hl
        ld (hl),0                       ; a gap, the line again
        inc hl
        ld (hl),01Eh
        jp ui_hline.attr

; clear rows B .. B+C-1 inside the bezel (columns 1-38), attr A
clear_in:
        push af
        ld a,b
        call row_addr
        inc hl
        pop af
.r:     push bc
        push hl
        ld b,38
.c:     ld (hl),0
        set 3,h
        ld (hl),a
        res 3,h
        inc hl
        djnz .c
        pop hl
        ld de,40
        add hl,de
        pop bc
        dec c
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; ui_items: menu entries from HL until FFh: db column, row, "KEY", 0,
; "LABEL", 0.  The key is a cap (white on blue), the label cyan.
; ---------------------------------------------------------------------
ui_items:
.l:     ld a,(hl)
        cp 0FFh
        ret z
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call vaddr
        pop hl
        ld a,0                          ; the cap: a space, the key, a space
        ld c,UI_KEY
        call putc
        inc de
        call print
        xor a
        call putc
        inc de
        inc de
        ld c,UI_LABEL
        call print
        jr .l

; HL = "prefix" + the name of system A, in ui_buf
ui_title2:
        push af
        ld de,ui_buf
.c:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.c
        dec de
        pop af
        push de
        call sys_name
        pop de
.n:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.n
        ld hl,ui_buf
        ret
