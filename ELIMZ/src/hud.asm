; =====================================================================
;  hud.asm - dashboard: gauges, radar, station compass, credits
; =====================================================================
BAR_COL         equ 4
RIGHT_COL       equ 29
COMP_COL        equ 35
COMP_ROW        equ 22

hud_frame:
        ld b,SEP_ROW                    ; blue rule under the view
        ld c,1
        ld a,BLUE<<4
        call clear_rows
        ld hl,VRAM+SEP_ROW*40
        ld b,40
.r:     ld (hl),07Ah                    ; upper half block
        inc hl
        djnz .r
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
.lab:   ; radar area: green dots
        ld a,HUD_ROW
        ld c,RAD_H
.ra:    push af
        push bc
        call row_addr
        ld de,RAD_COL
        add hl,de
        ex de,hl
        ld b,RAD_W
        ld a,GREEN<<4
        call fill_attr
        pop bc
        pop af
        inc a
        dec c
        jr nz,.ra
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
        ld de,VRAM+(HUD_ROW+4)*40+BAR_COL
        ld c,WHITE<<4
        call print_tenths
        ld hl,txt_ly
        jp print

hud_labels:
        db 0,HUD_ROW+0,CYAN<<4,"SPD",0
        db 0,HUD_ROW+1,CYAN<<4,"SHD",0
        db 0,HUD_ROW+2,CYAN<<4,"NRG",0
        db 0,HUD_ROW+3,CYAN<<4,"LSR",0
        db 0,HUD_ROW+4,CYAN<<4,"FUEL",0
        db RIGHT_COL,HUD_ROW+0,CYAN<<4,"CR",0
        db RIGHT_COL,HUD_ROW+1,CYAN<<4,"KILLS",0
        db RIGHT_COL,HUD_ROW+3,CYAN<<4,"STN",0
        db RIGHT_COL,HUD_ROW+2,CYAN<<4,"SKR",0
        db 0FFh

hud_update:
        call msg_tick
        ; gauges
        ld a,(speed)
        add a,a
        ld c,GREEN<<4
        ld de,VRAM+(HUD_ROW+0)*40+BAR_COL
        ld hl,bar_last
        call bar
        ld a,(shield)
        ld c,CYAN<<4
        ld de,VRAM+(HUD_ROW+1)*40+BAR_COL
        ld hl,bar_last+1
        call bar
        ld a,(energy)
        ld c,YELLOW<<4
        cp 20
        jr nc,$+4
        ld c,RED<<4
        ld de,VRAM+(HUD_ROW+2)*40+BAR_COL
        ld hl,bar_last+2
        call bar
        ld a,(heat)
        ld c,RED<<4
        ld de,VRAM+(HUD_ROW+3)*40+BAR_COL
        ld hl,bar_last+3
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
.nc:    ld a,(kills)
        ld hl,bar_last+6
        cp (hl)
        jr z,.nk
        ld (hl),a
        ld de,VRAM+(HUD_ROW+1)*40+RIGHT_COL+6
        ld c,WHITE<<4
        call print_dec3
.nk:    ld a,(seekers)
        ld hl,bar_last+7
        cp (hl)
        jr z,.ns
        ld (hl),a
        add a,20h
        ld de,VRAM+(HUD_ROW+2)*40+RIGHT_COL+4
        ld c,WHITE<<4
        call putc
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
        ; hit flash on the rule under the view
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
        jr .rule
.nf:    ld a,(flash_on)
        or a
        ret z
        xor a
        ld (flash_on),a
        ld a,BLUE<<4
.rule:  ld de,VRAM+SEP_ROW*40
        ld b,40
        jp fill_attr

; bar: A = value 0..64, C = attr, DE = VRAM, HL -> last value
bar:
        cp (hl)
        ret z
        ld (hl),a
        ld b,8
.c:     push af
        sub 8
        jr nc,.full
        add a,8
        cp 4
        ld a,0
        jr c,.put
        ld a,07Bh                       ; left half block
        jr .put
.full:  ld a,043h
.put:   call putc
        inc de
        pop af
        sub 8
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
radar:
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
.same:  dec h
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
        ld (hl),0                       ; clear the old dot
.draw:  ld (comp_addr),de
        ld a,(dbz)
        rla
        ld c,GREEN<<4
        jr nc,$+4
        ld c,RED<<4
        ld a,043h
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
