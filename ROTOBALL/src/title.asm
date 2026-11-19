; ======================================================================
;  title.asm - title screen, attract cycle, high-score entry
;
;  Assembled to run at 0000h: start-up switches the monitor ROM out
;  (OUT (E0h)) and copies this block into the RAM underneath.
; ======================================================================

PAGE_TIME = 75          ; frames per title page (~4.5 s)
TCX     = 8000h         ; map point the logo spins around
TCY     = 9080h

; A = first page to show (0 = instructions, 2 = high scores)
title:
    ld sp,STACK
    ld (tpage),a
    xor a
    ld (demo),a
    call mus_start
    call tbuild_map
    call tscreen
    call draw_page
    ld a,PAGE_TIME
    ld (ptimer),a
.loop:
    call tsetup
    call trender
    call wait_vblank
    call tblit
    call tcolours
    call tborder
    call snd_tick
    call read_keys
    ld a,(keyedge)
    and K_FIRE
    jp nz,start_game
    call scroller
    call page_tick
    ld hl,(tfc)
    inc hl
    ld (tfc),hl
    ld hl,framecnt
    inc (hl)
    jr .loop

start_game:
    call mus_stop
    xor a
    ld (demo),a
    jp new_game

start_demo:
    ld a,1
    ld (demo),a
    ld hl,DEMO_PATH
    ld (demo_wp),hl
    ld hl,DEMO_FRAMES
    ld (demo_t),hl
    jp new_game

; ----------------------------------------------------------------------
; map for the title: a lattice of dots with the ROTOBALL logo in the middle
tbuild_map:
    ld hl,MAP_PAGE*256
    ld de,MAP_PAGE*256+1
    ld bc,MAP_ROWS*256-1
    ld (hl),0
    ldir
    ld h,MAP_PAGE+3
.lr:
    ld l,3
    ld b,36
.lc:
    ld (hl),81h
    ld a,l
    add a,7
    ld l,a
    djnz .lc
    ld a,h
    add a,7
    ld h,a
    cp MAP_PAGE+MAP_ROWS
    jr c,.lr
    ld de,LOGO          ; logo, centred on (TCX, TCY)
    ld h,hi(TCY)-LOGO_H/2
    ld c,LOGO_H
.row:
    ld l,hi(TCX)-LOGO_W/2
    ld b,LOGO_WB
.byte:
    ld a,(de)
    inc de
    push bc
    ld b,8
.bit:
    rla
    jr nc,.o
    ld (hl),81h
    jr .n
.o:
    ld (hl),0
.n:
    inc l
    djnz .bit
    pop bc
    djnz .byte
    inc h
    dec c
    jr nz,.row
    ret

; static screen: clear, solid marquee rows, scroller row
tscreen:
    ld hl,VRAM
    ld de,VRAM+1
    ld bc,999
    ld (hl),0
    ldir
    ld hl,CRAM
    ld de,CRAM+1
    ld bc,999
    ld (hl),70h
    ldir
    ld hl,VRAM
    call .solid
    ld hl,VRAM+11*40
    call .solid
    ld hl,VRAM+24*40
    call .solid
    ld hl,scroll_text
    ld (scrollp),hl
    ret
.solid:
    ld b,40
.s:
    ld (hl),43h
    inc hl
    djnz .s
    ret

; ----------------------------------------------------------------------
; logo motion: gentle sway, a full spin every ~8 s, pulsing zoom
tsetup:
    ld a,(tfc)
    add a,a
    ld l,a
    ld h,hi(SIN8)
    ld a,(hl)
    sra a
    sra a
    sra a
    sra a
    ld b,a              ; sway +-8 (11 degrees)
    ld a,(tfc)
    and 127
    sub 96              ; last quarter of each 128-frame cycle: full turn
    jr c,.nospin
    add a,a
    add a,a
    add a,a
    add a,b
    ld b,a
.nospin:
    ld a,b
    ld (angle),a
    ld a,(tfc)
    ld c,a
    add a,a
    add a,c
    ld l,a
    ld a,(hl)
    sra a
    sra a
    sra a
    sra a
    add a,238
    ld (tzoom),a        ; 230..246
    ld a,(angle)
    call getsin
    call zoom_de
    ld (Uy),hl
    ld a,(angle)
    add a,64
    call getsin
    call zoom_de
    ld (Ux),hl
    ld (Vy),hl
    ld hl,(Uy)
    call neg_hl
    ld (Vx),hl
    add hl,hl
    ld (V2x),hl
    ld hl,(Vy)
    add hl,hl
    ld (V2y),hl
    ; RT = centre + 39.5 U - 9.5 V (+1/4 cell for rounding)
    ld hl,(Ux)
    call mul395
    push hl
    ld hl,(Vx)
    call mul95
    ex de,hl
    pop hl
    or a
    sbc hl,de
    ld de,TCX+64
    add hl,de
    ld (RTx),hl
    ld hl,(Uy)
    call mul395
    push hl
    ld hl,(Vy)
    call mul95
    ex de,hl
    pop hl
    or a
    sbc hl,de
    ld de,TCY+64
    add hl,de
    ld (RTy),hl
    ld hl,(Ux)
    call mul79
    ld (U49x),hl
    ld hl,(Uy)
    call mul79
    ld (U49y),hl
    ld hl,TLISTPTR
    ld (lp_base),hl
    ld hl,lchain_end-LCHAIN_MAX*LCHAIN_STEP
    ld (lchain),hl
    jp build_lists

zoom_de:                ; HL = DE * (tzoom) / 128, DE = +-128 max
    ld a,d
    push af
    bit 7,d
    jr z,.p
    ex de,hl
    call neg_hl
    ex de,hl
.p:
    ld a,(tzoom)
    ld h,a
    ld l,0
    ld d,0
    ld b,8
.m:
    add hl,hl
    jr nc,.n
    add hl,de
.n:
    djnz .m
    add hl,hl
    ld l,h
    ld h,0
    pop af
    rla
    ret nc
    jp neg_hl

mul79:                  ; HL = 79 HL
    ld d,h
    ld e,l
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl           ; 16x
    ld b,h
    ld c,l
    add hl,hl
    add hl,hl           ; 64x
    add hl,bc           ; 80x
    or a
    sbc hl,de           ; 79x
    ret

mul395:                 ; HL = 39.5 HL
    ld d,h
    ld e,l
    add hl,hl
    add hl,hl
    add hl,hl           ; 8x
    ld b,h
    ld c,l
    add hl,hl
    add hl,hl           ; 32x
    add hl,bc           ; 40x
    sra d
    rr e
    or a
    sbc hl,de           ; 39.5x
    ret

mul95:                  ; HL = 9.5 HL
    ld d,h
    ld e,l
    add hl,hl
    add hl,hl
    add hl,hl           ; 8x
    add hl,de           ; 9x
    sra d
    rr e
    add hl,de           ; 9.5x
    ret

; ----------------------------------------------------------------------
; 40 x 10 character rotozoom of the logo band (same scheme as the game view)
trender:
    ld (spsave),sp
    ld a,T_H
    ld (rowcnt),a
    ld hl,TCHARBUF+T_W-1
    ld (outptr),hl
.row:
    include "../build/gen_trow_lower.inc"
    include "../build/gen_tpass_lower.inc"
    include "../build/gen_trow_upper.inc"
    include "../build/gen_tpass_upper.inc"
    ld hl,(RTx)
    ld de,(V2x)
    add hl,de
    ld (RTx),hl
    ld hl,(RTy)
    ld de,(V2y)
    add hl,de
    ld (RTy),hl
    ld hl,(outptr)
    ld de,64
    add hl,de
    ld (outptr),hl
    ld a,(rowcnt)
    and 1
    jp nz,.nt
    ld sp,(spsave)
    call snd_tick
.nt:
    ld a,(rowcnt)
    dec a
    ld (rowcnt),a
    jp nz,.row
    ld sp,(spsave)
    ret

tblit:
    ld hl,TCHARBUF
    ld de,VRAM+T_Y*40
    ld a,T_H
.l:
    push hl
    ld bc,40
    ldir
    pop hl
    ld bc,64
    add hl,bc
    dec a
    jr nz,.l
    ret

tcolours:               ; diagonal rainbow over the logo band
    ld a,(framecnt)
    rra
    and 7
    ld c,a
    ld de,CRAM+T_Y*40
    ld b,T_H
.l:
    ld a,c
    add a,b
    and 7
    ld l,a
    ld h,hi(STRIP)
    push bc
    ld bc,40
    ldir
    pop bc
    djnz .l
    ret

tborder:                ; three marquee rows, the middle one running backwards
    ld a,(framecnt)
    and 7
    ld l,a
    ld h,hi(STRIP2)
    ld de,CRAM
    ld bc,40
    ldir
    ld a,(framecnt)
    cpl
    and 7
    ld l,a
    ld de,CRAM+11*40
    ld bc,40
    ldir
    ld a,(framecnt)
    and 7
    ld l,a
    ld de,CRAM+24*40
    ld bc,40
    ldir
    ret

; scroll message on row 23, one character every 2 frames
scroller:
    ld a,(framecnt)
    rra
    jr c,.col
    ld hl,VRAM+23*40+1
    ld de,VRAM+23*40
    ld bc,39
    ldir
    ld hl,(scrollp)
    ld a,(hl)
    cp 0FFh
    jr nz,.ok
    ld hl,scroll_text
    ld a,(hl)
.ok:
    inc hl
    ld (scrollp),hl
    ld (VRAM+23*40+39),a
.col:
    ld a,(framecnt)
    and 7
    ld l,a
    ld h,hi(STRIP)
    ld de,CRAM+23*40
    ld bc,40
    ldir
    ret

; ----------------------------------------------------------------------
page_tick:
    ld a,(framecnt)     ; flashing "PRESS SPACE" line
    and 8
    ld a,70h
    jr z,.f
    ld a,20h
.f:
    ld hl,CRAM+21*40
    ld b,40
.fl:
    ld (hl),a
    inc hl
    djnz .fl
    ld hl,ptimer
    dec (hl)
    ret nz
    ld (hl),PAGE_TIME
    ld a,(tpage)
    inc a
    cp 3
    jp nc,start_demo
    ld (tpage),a
    jp draw_page

draw_page:              ; clear rows 13-22, then the page's text records
    ld hl,VRAM+13*40
    ld de,VRAM+13*40+1
    ld bc,10*40-1
    ld (hl),0
    ldir
    ld hl,CRAM+13*40
    ld de,CRAM+13*40+1
    ld bc,10*40-1
    ld (hl),70h
    ldir
    ld a,(tpage)
    add a,a
    ld e,a
    ld d,0
    ld hl,PAGETAB
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl
    call draw_records
    ld a,(tpage)
    cp 2
    ret nz
    ; high-score table: rank, initials, score
    ld ix,HISCORES
    ld hl,VRAM+15*40+13
    ld c,21h            ; display code "1"
    ld b,5
.hs:
    push bc
    push hl
    ld (hl),c
    inc hl
    inc hl
    inc hl
    ld a,(ix+0)
    ld (hl),a
    inc hl
    ld a,(ix+1)
    ld (hl),a
    inc hl
    ld a,(ix+2)
    ld (hl),a
    inc hl
    inc hl
    inc hl
    ex de,hl
    ld a,(ix+5)
    call bcd2
    ld a,(ix+4)
    call bcd2
    ld a,(ix+3)
    call bcd2
    ld de,6
    add ix,de
    pop hl
    ld de,40
    add hl,de
    pop bc
    inc c
    djnz .hs
    ret

bcd2:                   ; A = BCD byte -> two digits at DE
    push af
    rrca
    rrca
    rrca
    rrca
    and 0Fh
    add a,20h
    ld (de),a
    inc de
    pop af
    and 0Fh
    add a,20h
    ld (de),a
    inc de
    ret

; records: row, col, attr, display codes..., FFh;  row FFh ends
draw_records:
    ld a,(hl)
    cp 0FFh
    ret z
    inc hl
    push hl
    ld e,a
    ld d,0
    ld h,d
    ld l,e
    add hl,hl
    add hl,hl
    add hl,de
    add hl,hl
    add hl,hl
    add hl,hl           ; row * 40
    ex de,hl
    pop hl
    ld a,(hl)           ; col
    inc hl
    add a,e
    ld e,a
    ld a,0
    adc a,d
    ld d,a
    ld c,(hl)           ; attr
    inc hl
.ch:
    ld a,(hl)
    inc hl
    cp 0FFh
    jr z,draw_records
    push hl
    ld hl,VRAM
    add hl,de
    ld (hl),a
    ld hl,CRAM
    add hl,de
    ld (hl),c
    pop hl
    inc de
    jr .ch

; ----------------------------------------------------------------------
; New high score: choose three letters with LEFT/RIGHT, SPACE to accept
hientry:
    ld sp,STACK
    call mus_start
    call tscreen
    ld hl,entry_text
    call draw_records
    ld de,VRAM+7*40+24
    ld a,(score+2)
    call bcd2
    ld a,(score+1)
    call bcd2
    ld a,(score)
    call bcd2
    xor a
    ld (epos),a
    ld (erep),a
    ld hl,initials
    ld (hl),1           ; "A"
    inc hl
    ld (hl),1
    inc hl
    ld (hl),1
.loop:
    call wait_vblank
    call snd_tick
    call snd_tick
    call read_keys
    ld hl,framecnt
    inc (hl)
    call tborder
    ; LEFT / RIGHT with auto-repeat
    ld a,(keys)
    and K_LEFT+K_RIGHT
    jr nz,.held
    xor a
    ld (erep),a
    jr .fire
.held:
    ld a,(erep)
    inc a
    ld (erep),a
    cp 1
    jr z,.step
    cp 14
    jr c,.fire
    and 3
    jr nz,.fire
.step:
    ld a,(epos)
    ld e,a
    ld d,0
    ld hl,initials
    add hl,de
    call letter_index
    ld a,(keys)
    and K_RIGHT
    ld a,b
    jr z,.dn
    inc a
    cp 28
    jr c,.set
    xor a
    jr .set
.dn:
    or a
    jr nz,.d1
    ld a,28
.d1:
    dec a
.set:
    ld e,a
    ld d,0
    push hl
    ld hl,LETTERS
    add hl,de
    ld a,(hl)
    pop hl
    ld (hl),a
    ld hl,sfx_clink
    ld a,1
    call play_sfx
.fire:
    ld a,(keyedge)
    and K_FIRE
    jr z,.draw
    ld hl,sfx_gem
    ld a,2
    call play_sfx
    ld a,(epos)
    inc a
    ld (epos),a
    cp 3
    jr nc,.done
.draw:
    ld hl,initials
    ld de,VRAM+14*40+17
    ld b,3
    ld c,0
.dl:
    ld a,(hl)
    ld (de),a
    push hl
    ld hl,CRAM-VRAM
    add hl,de
    ld a,(epos)
    cp c
    ld a,70h
    jr nz,.nc
    ld a,(framecnt)
    and 7
    push de
    ld e,a
    ld d,hi(STRIP)
    ld a,(de)
    pop de
.nc:
    ld (hl),a
    pop hl
    inc hl
    inc de
    inc de
    inc de
    inc c
    djnz .dl
    jp .loop
.done:
    call insert_hiscore
    ld a,2
    jp title

letter_index:           ; B = index in LETTERS of the letter at (HL)
    ld b,0
    push hl
    ld a,(hl)
    ld hl,LETTERS
.f:
    cp (hl)
    jr z,.x
    inc hl
    inc b
    ld c,a
    ld a,b
    cp 28
    ld a,c
    jr c,.f
    ld b,0
.x:
    pop hl
    ret

; is the score good enough for the table? carry if so
qualifies:
    ld hl,HISCORES+4*6+3
    jp bcd_gt

; carry if score > the 3-byte BCD score at HL (low byte first)
bcd_gt:
    inc hl
    inc hl
    ld de,score+2
    ld b,3
.l:
    ld a,(de)
    cp (hl)
    jr nz,.d
    dec de
    dec hl
    djnz .l
    or a
    ret
.d:
    ccf
    ret

insert_hiscore:
    ld ix,HISCORES
    ld b,0
.f:
    push ix
    pop hl
    inc hl
    inc hl
    inc hl
    push bc
    call bcd_gt
    pop bc
    jr c,.found
    ld de,6
    add ix,de
    inc b
    ld a,b
    cp 5
    jr nz,.f
    ret
.found:
    ld a,4              ; move entries b..3 down one place
    sub b
    jr z,.put
    ld c,a
    add a,a
    add a,c
    add a,a             ; (4-b) * 6 bytes
    ld c,a
    ld b,0
    ld hl,HISCORES+4*6-1
    ld de,HISCORES+5*6-1
    lddr
.put:
    ld hl,initials
    ld a,(hl)
    ld (ix+0),a
    inc hl
    ld a,(hl)
    ld (ix+1),a
    inc hl
    ld a,(hl)
    ld (ix+2),a
    ld a,(score)
    ld (ix+3),a
    ld a,(score+1)
    ld (ix+4),a
    ld a,(score+2)
    ld (ix+5),a
    ret
