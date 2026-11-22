; ---------------------------------------------------------------------------
; fx_title.asm - the SHARP EDGES logo with copper bars behind it and a
; sine scroller underneath.
;
; Bars are drawn into a 144-line colour list (rows 0-17).  Each character row
; then becomes one glyph that splits the cell at the right scan line
; (70h 36h 7Ah 7Eh 3Eh 3Ch) in two colours, so the bars move a line at a time
; although the MZ-700 only has 8x8 text.
; logo_map: 18 rows x 40 chars (0 = empty, 43h full block, else a triangle).
; ---------------------------------------------------------------------------

LINES   equ 144
SCR_TOP equ 18

title_init:
        xor a
        ld (ti_spoke),a
        ld (ti_scroll),a
        ld (ti_sdelay),a
        ld hl,title_scroll
        ld (ti_text),hl
        ld hl,tr_lastg          ; every row's characters are rebuilt once
        ld b,SCR_TOP
.l:     ld (hl),0FFh
        inc hl
        djnz .l
        ld hl,VATR+SCR_TOP*40   ; scroller colours: fixed per column,
        ld c,7                  ; never blitted
.ar:    ld de,ti_rainbow
        ld b,40
.a:     ld a,(de)
        ld (hl),a
        inc hl
        inc de
        djnz .a
        dec c
        jr nz,.ar
        ret

title_frame:
        call wait_vbl
        ; ---- blit what was built last time (2 frames per update)
        ld bc,SCR_TOP
        call blit_attr_rows
        ; characters: only the rows whose split glyph changed, and the scroller
        ld hl,tr_dirty
        ld b,0
.d:     ld a,(hl)
        or a
        jr z,.nd
        ld (hl),0
        push hl
        push bc
        ld c,1
        call blit_char_rows
        pop bc
        pop hl
.nd:    inc hl
        inc b
        ld a,b
        cp SCR_TOP
        jr c,.d
        ld bc,SCR_TOP*256+7
        call blit_char_rows
        ld a,(ti_spoke)         ; third update: the logo is up, shout its name
        cp 3
        jr nc,.said
        inc a
        ld (ti_spoke),a
        cp 3
        call z,speak
.said:
        ; ---- time
        ld a,(mtick)
        ld (ti_t),a
        call ti_bars
        call ti_rows
        call ti_scroller
        ret

; ---------------------------------------------------------------- bars
ti_bars:
        ld hl,ti_lines          ; clear to black
        ld b,LINES
        xor a
.cl:    ld (hl),a
        inc hl
        djnz .cl
        ; two passes: bars behind (cos < 0) first, then in front
        xor a
        call .pass
        ld a,80h
.pass:  ld (.want+1),a
        ld ix,bar_defs
        ld b,5
.bar:   push bc
        ld a,(ti_t)
        add a,(ix+0)            ; phase
        ld c,a
        call cos_a
        and 80h
.want:  cp 0
        jr nz,.skip
        ld a,c
        call sin_a              ; -127..127
        sra a                   ; -63..63
        add a,LINES/2-6         ; 3..129
        ; y = A; draw the 12-line profile at y
        ld e,a
        ld d,0
        ld hl,ti_lines
        add hl,de
        ld e,(ix+1)
        ld d,(ix+2)             ; profile
        ld b,12
.pr:    ld a,(de)
        ld (hl),a
        inc hl
        inc de
        djnz .pr
.skip:  ld de,3
        add ix,de
        pop bc
        djnz .bar
        ret

bar_defs:                       ; phase, profile
        db 0
        dw prof_blue
        db 51
        dw prof_red
        db 102
        dw prof_green
        db 153
        dw prof_mag
        db 204
        dw prof_blue
prof_blue:  db 1,1,1,5,5,5,5,5,5,1,1,1
prof_red:   db 2,2,2,3,3,3,3,3,3,2,2,2
prof_green: db 4,4,4,5,5,5,5,5,5,4,4,4
prof_mag:   db 1,1,1,3,3,3,3,3,3,1,1,1

; ---------------------------------------------------------------- rows 0-17
; split table: k = leading lines in the top colour (1..7) -> glyph, swap
split_glyph:    db 0, 70h, 36h, 36h, 7Ah, 7Eh, 3Eh, 3Ch
split_swap:     db 0, 0,   0,   0,   0,   1,   1,   1

ti_rows:
        ld a,SCR_TOP-1          ; bottom row first (see the fill)
.row:   ld (tr_row),a
        ; lines of this row: ti_lines + row*8
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,ti_lines
        add hl,de
        ld b,(hl)               ; top colour
        push hl
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (tr_mid),a
        inc hl
        inc hl
        inc hl
        ld c,(hl)               ; bottom colour
        pop hl
        ld e,0                  ; k = lines in the top colour
.k:     ld a,(hl)
        cp b
        jr nz,.kd
        inc hl
        inc e
        ld a,e
        cp 8
        jr c,.k
.kd:    ld a,e
        cp 8
        jr c,.split
        ld a,b                  ; one colour
        rlca
        rlca
        rlca
        rlca
        or b
        ld c,a
        xor a
        jr .fill
.split: ld d,0
        ld hl,split_swap
        add hl,de
        ld a,(hl)
        or a
        jr z,.ns
        ld a,b
        ld b,c
        ld c,a
.ns:    ld a,b
        rlca
        rlca
        rlca
        rlca
        or c
        ld c,a                  ; attr
        ld hl,split_glyph
        add hl,de
        ld a,(hl)               ; glyph
.fill:  ; push-fill the row (downwards: an interrupt can only drop its return
        ; address on cells that are filled later)
        ld b,a                  ; glyph
        ld a,(tr_row)
        ld e,a
        ld d,0
        ld hl,tr_lastg
        add hl,de
        ld a,b
        cp (hl)
        ld (hl),a
        ld hl,tr_dirty
        add hl,de
        ld (hl),0
        jr z,.same
        ld (hl),1
.same:  push af                 ; Z = characters unchanged
        call .rowend
        ld de,ABUF-CBUF
        add hl,de
        ld (tr_sp),sp
        ld sp,hl
        ld h,c
        ld l,c
        DUP 20
        push hl
        EDUP
        ld sp,(tr_sp)
        pop af
        jr z,.attrs
        call .rowend
        ld (tr_sp),sp
        ld sp,hl
        ld h,b
        ld l,b
        DUP 20
        push hl
        EDUP
        ld sp,(tr_sp)
        ; logo characters for this row
        call .list
        ld b,(hl)
        inc hl
        ld a,b
        or a
        jr z,.attrs
.lch:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (de),a
        djnz .lch
.attrs: ; logo attributes: ink | paper on every logo cell of the row
        ld a,(tr_row)
        ld e,a
        ld d,0
        ld hl,logo_ink
        add hl,de
        ld a,(tr_mid)
        or (hl)
        ld c,a
        ld hl,logo_arowtab
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld b,(hl)
        inc hl
        ld a,b
        or a
        jr z,.done
.la:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,c
        ld (de),a
        djnz .la
        ; the shine: 3 white cells at x = (2t - row) mod 64
        ld a,c
        and 0Fh
        or 70h
        ld c,a
        ld a,(tr_row)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; row*40
        ld a,(ti_t)
        add a,a
        ld de,tr_row
        ex de,hl
        sub (hl)
        ex de,hl
        and 63
        ld e,a
        ld d,0
        add hl,de               ; row*40 + x
        ld b,3
.sh:    ld a,e
        cp 40
        jr nc,.sn
        push hl
        ld de,logo_map
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr z,.sn
        push hl
        ld de,ABUF
        add hl,de
        ld (hl),c
        pop hl
.sn:    inc hl
        ld a,e
        inc a
        and 63
        ld e,a
        jr nz,.sw
        ld de,-64               ; wrapped to x = 0
        add hl,de
        ld e,0
.sw:    djnz .sh
.done:  ld a,(tr_row)
        sub 1
        jp nc,.row
        ret
.rowend:
        ld a,(tr_row)           ; HL = CBUF + row*40 + 40
        ld l,a
        ld h,0
        add hl,hl
        ld de,ti_rowend
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret
.list:  ld a,(tr_row)           ; HL -> this row's logo list
        ld l,a
        ld h,0
        add hl,hl
        ld de,logo_rowtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

ti_rowend:
.r = 0
        DUP SCR_TOP
        dw CBUF + .r*40 + 40
.r = .r + 1
        EDUP

; ---------------------------------------------------------------- scroller
; rows 18-24: one letter per column at row 21 + 3 sin(...)
ti_scroller:
        ld (tr_sp),sp           ; clear the characters (push-fill)
        ld sp,CBUF+25*40
        ld hl,0
        DUP 140
        push hl
        EDUP
        ld sp,(tr_sp)
        ; advance the text every 2 updates
        ld hl,ti_sdelay
        inc (hl)
        bit 0,(hl)
        jr z,.noadv
        ld hl,(ti_text)
        inc hl
        ld a,(hl)
        cp 0FFh
        jr nz,.a1
        ld hl,title_scroll
.a1:    ld (ti_text),hl
.noadv: ; angle = t*6 + x*4; TI_SROW gives the CBUF offset of the row
        ld a,(ti_t)
        ld e,a
        add a,a
        add a,e
        add a,a
        ld c,a
        ld hl,(ti_text)
        ld de,CBUF+SCR_TOP*40
        ld b,40
.col:   ld a,(hl)
        inc hl
        cp 0FFh
        jr nz,.c1
        ld hl,title_scroll
        ld a,(hl)
        inc hl
.c1:    or a
        jr z,.nextc             ; space
        push hl
        push de
        ex af,af'
        ld l,c
        ld h,TI_SROW/256
        ld a,(hl)
        inc h
        ld h,(hl)
        ld l,a
        add hl,de
        ex af,af'
        ld (hl),a
        pop de
        pop hl
.nextc: inc de
        ld a,c
        add a,4
        ld c,a
        djnz .col
        ret

ti_rainbow: db 70h,70h,60h,60h,20h,20h,30h,30h,10h,10h,30h,30h,50h,50h,70h,70h
            db 70h,70h,50h,50h,40h,40h,60h,60h,70h,70h,60h,60h,20h,20h,30h,30h
            db 10h,10h,50h,50h,70h,70h,70h,70h

ti_t:      db 0
ti_spoke:  db 0
ti_scroll: db 0
ti_sdelay: db 0
ti_text:   dw 0
tr_sp:     dw 0
tr_white:  db 0
tr_row:    db 0
tr_mid:    db 0
tr_attr:   db 0
tr_glyph:  db 0
tr_ink:    db 0
tr_sh:     db 0
ti_lines:  ds LINES+16
tr_lastg:  ds SCR_TOP
tr_dirty:  ds SCR_TOP
