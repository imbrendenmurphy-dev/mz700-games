; =====================================================================
;  hud.asm - dashboard: gauges, radar, station compass, credits
; =====================================================================
BAR_COL         equ 3
FUEL_COL        equ 4
RIGHT_COL       equ 29
COMP_COL        equ 37
COMP_ROW        equ 22
SKR_COL         equ 33
DIV1            equ 11              ; the panel dividers
DIV2            equ 28
LINE_ATTR       equ BLUE<<4
TITLE_ATTR      equ CYAN<<4
SCOPE           equ BLUE            ; scanner and compass ground

; ---------------------------------------------------------------------
; the console: a bezel across row 19 with the panel titles set into it,
; dividers between the panels, LED meters, a blue scanner scope
; ---------------------------------------------------------------------
hud_frame:
        ld b,SEP_ROW
        ld c,6
        ld a,WHITE<<4
        call clear_rows
        xor a
        call hud_rule
        ld hl,VRAM+HUD_ROW*40+DIV1      ; dividers
        ld b,5
.d:     ld (hl),079h
        set 3,h
        ld (hl),LINE_ATTR
        res 3,h
        push hl
        ld de,DIV2-DIV1
        add hl,de
        ld (hl),079h
        set 3,h
        ld (hl),LINE_ATTR
        pop hl
        ld de,40
        add hl,de
        djnz .d
        ld b,MSG_ROW
        ld c,1
        ld a,BLUE<<4
        call clear_rows
        ld hl,hud_labels
.l:     ld a,(hl)
        cp 0FFh
        jr z,.lab
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push af
        call vaddr
        pop af
        ld c,a
        call print
        jr .l
.lab:   ld a,HUD_ROW                    ; the scanner scope
        ld c,RAD_H
.ra:    push af
        push bc
        call row_addr
        ld de,RAD_COL
        add hl,de
        ex de,hl
        ld b,RAD_W
        ld a,(GREEN<<4)|SCOPE
        call fill_attr
        pop bc
        pop af
        inc a
        dec c
        jr nz,.ra
        ld hl,VRAM+(COMP_ROW)*40+COMP_COL   ; the compass: a little scope
        ld c,3
.cr:    ld b,3
.cc:    ld (hl),0
        set 3,h
        ld (hl),(BLUE<<4)|SCOPE
        res 3,h
        inc hl
        djnz .cc
        ld de,40-3
        add hl,de
        dec c
        jr nz,.cr
        ld hl,VRAM+(COMP_ROW+1)*40+COMP_COL+1
        ld (hl),0BDh                    ; its centre cross
        ld hl,bar_last                  ; force the gauges to draw
        ld b,8
.f:     ld (hl),0FFh
        inc hl
        djnz .f
        xor a
        ld (comp_addr+1),a
        ld (flash_on),a
        inc a
        ld (cr_dirty),a
        ld a,(fuel)
        ld l,a
        ld h,0
        ld de,VRAM+(HUD_ROW+4)*40+FUEL_COL
        ld c,WHITE<<4
        call print_tenths
        ld hl,txt_ly
        jp print

; draw the bezel row; A = 0 its own colours, else every cell in attr A
hud_rule:
        ld hl,VRAM+SEP_ROW*40
        ld de,HUD_RULE
        ld b,40
.c:     push af
        ld a,(de)
        ld (hl),a
        pop af
        set 3,h
        or a
        jr nz,.put
        push hl
        ld hl,40
        add hl,de
        ld a,(hl)                       ; 0 line, 1 title
        pop hl
        or a
        ld a,LINE_ATTR
        jr z,$+4
        ld a,TITLE_ATTR
        ld (hl),a
        xor a
        jr .nx
.put:   ld (hl),a
.nx:    res 3,h
        inc hl
        inc de
        djnz .c
        ret

HUD_RULE:       ; row 19: the glyphs, then 0 = line / 1 = title per cell
        db 078h,05Eh,013h,019h,013h,014h,005h,00Dh,013h,01Eh,078h,05Fh,078h,078h,078h,078h,05Eh,013h,003h,001h,00Eh,00Eh,005h,012h,01Eh,078h,078h,078h,05Fh,078h,05Eh,013h,014h,001h,014h,015h,013h,01Eh,078h,078h
        db 0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0

hud_labels:
        db 0,HUD_ROW+0,CYAN<<4,"SPD",0
        db 0,HUD_ROW+1,CYAN<<4,"SHD",0
        db 0,HUD_ROW+2,CYAN<<4,"NRG",0
        db 0,HUD_ROW+3,CYAN<<4,"LSR",0
        db 0,HUD_ROW+4,CYAN<<4,"FUEL",0
        db RIGHT_COL,HUD_ROW+0,CYAN<<4,"CR",0
        db RIGHT_COL,HUD_ROW+1,CYAN<<4,"TMP",0
        db RIGHT_COL,HUD_ROW+2,CYAN<<4,"SKR",0
        db RIGHT_COL,HUD_ROW+3,CYAN<<4,"LEGAL",0
        db 0FFh

; meter colours, one per cell (left to right)
COL_SPD:        db CYAN,CYAN,CYAN,CYAN,CYAN,CYAN,WHITE,WHITE
COL_SHD:        db RED,RED,YELLOW,YELLOW,GREEN,GREEN,GREEN,GREEN
COL_HEAT:       db GREEN,GREEN,GREEN,YELLOW,YELLOW,YELLOW,RED,RED

hud_update:
        call msg_tick
        ; gauges
        ld a,(speed)
        add a,a
        ld de,VRAM+(HUD_ROW+0)*40+BAR_COL
        ld hl,bar_last
        ld ix,COL_SPD
        call bar
        ld a,(shield)
        ld de,VRAM+(HUD_ROW+1)*40+BAR_COL
        ld hl,bar_last+1
        ld ix,COL_SHD
        call bar
        ld a,(energy)
        ld de,VRAM+(HUD_ROW+2)*40+BAR_COL
        ld hl,bar_last+2
        ld ix,COL_SHD
        call bar
        ld a,(heat)
        ld de,VRAM+(HUD_ROW+3)*40+BAR_COL
        ld hl,bar_last+3
        ld ix,COL_HEAT
        call bar
        ; credits / kills
        ld a,(cr_dirty)
        or a
        jr z,.nc
        xor a
        ld (cr_dirty),a
        ld de,VRAM+HUD_ROW*40+RIGHT_COL+2
        ld c,WHITE<<4
        call print_cr
.nc:    ld a,(temp)                     ; cabin temperature
        ld de,VRAM+(HUD_ROW+1)*40+RIGHT_COL+3
        ld hl,bar_last+6
        ld ix,COL_HEAT
        call bar
.nk:    ld a,(seekers)                  ; seekers: a row of missile icons
        ld hl,bar_last+7
        cp (hl)
        jr z,.ns
        ld (hl),a
        ld de,VRAM+(HUD_ROW+2)*40+SKR_COL
        ld b,3
.sk:    ld c,YELLOW<<4
        or a
        jr nz,$+4
        ld c,BLUE<<4
        push af
        ld a,050h                       ; an up arrow
        call putc
        inc de
        pop af
        or a
        jr z,$+3
        dec a
        djnz .sk
.ns:    call legal_level
        ld hl,bar_last+5
        cp (hl)
        jr z,.nl
        ld (hl),a
        ld c,GREEN<<4
        or a
        jr z,$+4
        ld c,RED<<4
        add a,a
        add a,a
        add a,a
        ld hl,LEGAL_NAMES
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld de,VRAM+(HUD_ROW+4)*40+RIGHT_COL
        call print
.nl:    call poll
        call radar
        call compass
        ; a hit flashes the bezel red
        ld hl,hitflash
        ld a,(hl)
        or a
        jr z,.nf
        dec (hl)
        ld a,(flash_on)
        or a
        ret nz
        inc a
        ld (flash_on),a
        ld a,RED<<4
        jp hud_rule
.nf:    ld a,(flash_on)
        or a
        ret z
        xor a
        ld (flash_on),a
        jp hud_rule

; bar: an LED meter of 8 cells, two dots each.  A = value 0..64,
; DE = VRAM, HL -> last value, IX = 8 colours.  Unlit dots show blue.
bar:
        cp (hl)
        ret z
        ld (hl),a
        srl a
        srl a                           ; 0..16 dots
        ld b,8
.c:     ld c,BLUE<<4
        push af
        cp 1
        ld a,0FFh                       ; both columns
        jr c,.put                       ; unlit
        jr nz,.lit
        ld a,0F5h                       ; the left column only
.lit:   push af
        ld a,(ix+0)
        add a,a
        add a,a
        add a,a
        add a,a
        ld c,a
        pop af
.put:   call putc
        inc de
        inc ix
        pop af
        sub 2
        jr nc,$+3
        xor a
        djnz .c
        ret

; credits (tenths) at DE: "nnnn.n"
print_credits:
        push bc
        push de
        ld de,numbuf
        call dec5
        pop de
        pop bc
        ld hl,numbuf
        ld b,4
.l:     ld a,(hl)
        inc hl
        call putc
        inc de
        djnz .l
        ld a,2Eh
        call putc
        inc de
        ld a,(hl)
        jp putc

; HL -> 5 display-code digits at (DE)
dec5:
        ld bc,-10000
        call .d
        ld bc,-1000
        call .d
        ld bc,-100
        call .d
        ld bc,-10
        call .d
        ld bc,-1
.d:     ld a,20h-1
.s:     inc a
        add hl,bc
        jr c,.s
        sbc hl,bc
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------------
; radar: top-down, 32 x 10 dots, x / 512, z / 1024
; ---------------------------------------------------------------------
RCOL            equ RBUF+80h            ; colour of each scanner cell
RCSH            equ RSHD+80h            ; what VRAM shows

radar:
        ld a,(WHITE<<4)|SCOPE
        ld (rp_col),a
        ld bc,16*256+5                  ; us
        call rplot
        ld b,15
        call rplot
        ld ix,objects
        ld b,MAXOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_DEBRIS
        jr z,.n
        ld a,(ix+O_X+1)                 ; px = 16 + x/512
        sra a
        add a,16
        ld b,a
        ld a,(ix+O_Z+1)                 ; py = 5 - z/1024
        sra a
        sra a
        neg
        add a,5
        ld c,a
        push hl
        ld a,(ix+O_TYPE)                ; the blip takes the ship's colour
        ld hl,TYPE_COL-1
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        add a,a
        add a,a
        add a,a
        add a,a
        or SCOPE
        ld (rp_col),a
        ld a,(ix+O_TYPE)
        cp T_STATION
        jr nz,.chk
        ld a,b                          ; the station sticks to the edge
        bit 7,a
        jr z,$+3
        xor a
        cp 32
        jr c,$+4
        ld a,31
        ld b,a
        ld a,c
        bit 7,a
        jr z,$+3
        xor a
        cp 10
        jr c,$+4
        ld a,9
        ld c,a
        ld a,(frame)                    ; and blinks
        and 4
        jr z,.n
.chk:   ld a,b
        cp 32
        jr nc,.n
        ld a,c
        cp 10
        jr nc,.n
        call rplot
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ; present the radar
        ld hl,RBUF
        ld de,VRAM+HUD_ROW*40+RAD_COL
        ld c,RAD_H
.row:   ld b,RAD_W
.cell:  ld a,(hl)
        ld (hl),0
        inc h
        cp (hl)
        jr z,.same
        ld (hl),a
        or 0F0h
        ld (de),a
.same:  and 0Fh                         ; a blip: its colour
        jr z,.nocol
        ld a,l
        add a,80h
        ld l,a
        ld a,(hl)                       ; the shown colour (RCSH)
        dec h
        cp (hl)                         ; this frame's (RCOL)
        jr z,.cdone
        ld a,(hl)
        inc h
        ld (hl),a
        set 3,d
        ld (de),a
        res 3,d
        dec h
.cdone: inc h
        ld a,l
        sub 80h
        ld l,a
.nocol: dec h
        inc l
        inc de
        djnz .cell
        push hl
        ex de,hl
        ld de,40-RAD_W
        add hl,de
        ex de,hl
        pop hl
        dec c
        jr nz,.row
        ret

; B = x 0..31, C = y 0..9
rplot:
        push bc
        ld a,c
        srl a
        add a,a
        add a,a
        add a,a
        add a,a                         ; row * 16
        ld l,a
        ld a,b
        srl a
        add a,l
        ld l,a
        ld h,high RBUF
        ld a,b
        and 1
        inc a
        bit 0,c
        jr z,.t
        add a,a
        add a,a
.t:     or (hl)
        ld (hl),a
        set 7,l
        ld a,(rp_col)
        ld (hl),a
        pop bc
        ret

; ---------------------------------------------------------------------
; compass: where the station lies (3 x 3 cells, green ahead / red behind)
; ---------------------------------------------------------------------
compass:
        ld hl,objects+O_X
        call vec_to_bytes
        ; m/2 = max(|x|,|y|,|z|)/2
        ld a,(dbx)
        call .abs
        ld b,a
        ld a,(dby)
        call .abs
        cp b
        jr c,$+3
        ld b,a
        ld a,(dbz)
        call .abs
        cp b
        jr c,$+3
        ld b,a
        srl b                           ; B = m/2
        ld a,(dbx)
        call .tri                       ; -1, 0, 1
        add a,COMP_COL+1
        ld e,a
        ld a,(dby)
        call .tri
        neg
        add a,COMP_ROW+1
        push de
        call row_addr
        pop de
        ld d,0
        add hl,de
        ex de,hl                        ; DE = new cell
        ld hl,(comp_addr)
        ld a,h
        or a
        jr z,.draw
        or a
        sbc hl,de
        jr z,.draw
        add hl,de
        push de
        ld de,VRAM+(COMP_ROW+1)*40+COMP_COL+1
        or a
        sbc hl,de                       ; Z: it was the centre
        add hl,de
        pop de
        ld a,0
        jr nz,$+4
        ld a,0BDh                       ; put the cross back
        ld (hl),a
        set 3,h
        ld (hl),(BLUE<<4)|SCOPE
.draw:  ld (comp_addr),de
        ld a,(dbz)
        rla
        ld c,(GREEN<<4)|SCOPE
        jr nc,$+4
        ld c,(RED<<4)|SCOPE
        ld a,0FFh
        jp putc
.abs:   or a
        ret p
        neg
        ret
; A = signed byte -> -1 / 0 / 1 against B
.tri:   or a
        jp m,.neg
        cp b
        ld a,0
        ret c
        ret z
        inc a
        ret
.neg:   neg
        cp b
        ld a,0
        ret c
        ret z
        dec a
        ret
