; ======================================================================
;  render.asm - rotating maze renderer, screen copy and colour cycling
; ======================================================================

init_lists:             ; LISTPTR[k] = LISTS + k*LIST_BYTES, k = 0..4 (and title's)
    ld hl,LISTPTR
    ld de,LISTS
    ld bc,LIST_BYTES
    call .tab
    ld hl,TLISTPTR
    ld de,TLISTS
    ld bc,TLIST_BYTES
.tab:
    ld a,5
.lp:
    ld (hl),e
    inc l
    ld (hl),d
    inc l
    ex de,hl
    add hl,bc
    ex de,hl
    dec a
    jr nz,.lp
    ret

wait_vblank:            ; wait for the start of the next vertical blank
.in:
    ld a,(PPI_C)
    rla
    jr nc,.in           ; already in blanking: wait for display
.out:
    ld a,(PPI_C)
    rla
    jr c,.out           ; wait for blanking to begin
    ret

; DE = signed 16-bit 128*sin(A*2pi/256)
getsin:
    ld l,a
    ld h,hi(SINL)
    ld e,(hl)
    inc h
    ld d,(hl)
    ret

neg_hl:
    xor a
    sub l
    ld l,a
    ld a,0
    sbc a,h
    ld h,a
    ret

; Work out per-block steps U (screen right) and V (screen down) in map space,
; and RT = the map point of the top row's rightmost block.
setup_render:
    ld a,(angle)
    call getsin
    ld (Uy),de
    ld a,(angle)
    add a,64
    call getsin
    ld (Ux),de
    ld (Vy),de          ; V = (-Uy, Ux)
    ld hl,(Uy)
    call neg_hl
    ld (Vx),hl
    add hl,hl
    ld (V2x),hl
    ld hl,(Vy)
    add hl,hl
    ld (V2y),hl
    ; RT = ball + 22.5 * (U - V), plus 1/4 cell so rows round to the nearest half
    ld hl,(Ux)
    ld de,(Vx)
    or a
    sbc hl,de
    call mulhalf
    ld de,(ballx)
    add hl,de
    ld de,64
    add hl,de
    ld (RTx),hl
    ld hl,(Uy)
    ld de,(Vy)
    or a
    sbc hl,de
    call mulhalf
    ld de,(bally)
    add hl,de
    ld de,64
    add hl,de
    ld (RTy),hl
    ; delta lists depend only on the angle
    ld a,(listang)
    ld b,a
    ld a,(angle)
    cp b
    ret z
    ld (listang),a
    ld hl,(Ux)
    call mul49
    ld (U49x),hl
    ld hl,(Uy)
    call mul49
    ld (U49y),hl
    ld hl,LISTPTR
    ld (lp_base),hl
    ld hl,lchain_end-(2*VIEW_CHARS-1)*LCHAIN_STEP
    ld (lchain),hl
    jp build_lists

    assert VIEW_CHARS == 23
mulhalf:                ; HL = 22.5 * HL (signed): half the view in blocks, less 1/2
    push hl
    add hl,hl           ; 2x
    ld d,h
    ld e,l
    add hl,hl           ; 4x
    ld b,h
    ld c,l
    add hl,hl
    add hl,hl           ; 16x
    add hl,bc           ; 20x
    add hl,de           ; 22x
    pop de
    sra d
    rr e
    add hl,de           ; 22.5x
    ret

mul49:                  ; HL = 45 * HL  (samples per row - 1)
    ld d,h
    ld e,l
    add hl,hl
    add hl,hl
    add hl,de           ; 5x
    ld d,h
    ld e,l
    add hl,hl
    add hl,hl
    add hl,hl           ; 40x
    add hl,de           ; 45x
    ret

; Build the four delta lists (one per half-cell phase of a row's start point).
; List k holds N pointer deltas: 0, then floor(s_i) - floor(s_(i-1)) for the
; samples s_i = f - i*U walking right to left across the row.
; In: (U49x/y) = (N-1)*U, (lp_base) = list pointer table, (lchain) = entry
; into the unrolled chain that does N-1 steps. Shared by game and title.
build_lists:
    ld (spsave),sp
    xor a
    ld (lclass),a
bl_cls:
    ld a,(lclass)       ; SP = end of list k (pushes fill it downwards)
    inc a
    add a,a
    ld hl,(lp_base)
    add a,l
    ld l,a
    ld a,(hl)
    inc l
    ld h,(hl)
    ld l,a
    ld sp,hl
    ld a,(lclass)       ; v = 4000h + fy - 49Uy  (biased so nothing wraps)
    and 2
    rrca
    rrca                ; 80h if fy = 1/2
    ld l,a
    ld h,40h
    ld de,(U49y)
    or a
    sbc hl,de
    ld bc,(Uy)
    exx
    ld a,(lclass)       ; u = 4000h + fx - 49Ux
    and 1
    rrca
    ld l,a
    ld h,40h
    ld de,(U49x)
    or a
    sbc hl,de
    ld bc,(Ux)
    ld ix,(lchain)
    jp (ix)
lchain_start:
    include "../build/gen_listentry.inc"
lchain_end:
LCHAIN_STEP = (lchain_end-lchain_start)/LCHAIN_MAX
    ld de,0
    push de
    ld a,(lclass)
    inc a
    ld (lclass),a
    cp 4
    jp nz,bl_cls
    ld sp,(spsave)
    ret

; ----------------------------------------------------------------------
; Rotozoom renderer. Each block row: HL = map pointer at the row's rightmost
; sample, SP = delta list; per sample pop/add/load/shift (40 T-states).
; Lower block row first, then upper, giving the F0h-FFh code in C.
; Every fourth character row it also runs a sound tick (no stack needed).
render:
    ld (spsave),sp
    ld a,VIEW_CHARS
    ld (rowcnt),a
    ld hl,CHARBUF+VIEW_CHARS-1
    ld (outptr),hl
.row:
    include "../build/gen_row_lower.inc"
    include "../build/gen_pass_lower.inc"
    include "../build/gen_row_upper.inc"
    include "../build/gen_pass_upper.inc"
    ld hl,(RTx)
    ld de,(V2x)
    add hl,de
    ld (RTx),hl
    ld hl,(RTy)
    ld de,(V2y)
    add hl,de
    ld (RTy),hl
    ld hl,(outptr)
    ld de,32
    add hl,de
    ld (outptr),hl
    ld a,(rowcnt)
    and 3
    jp nz,.notick
    ld sp,(spsave)      ; SP is free between rows: borrow the real stack
    call snd_tick
.notick:
    ld a,(rowcnt)
    dec a
    ld (rowcnt),a
    jp nz,.row
    ld sp,(spsave)
    ret

; objects and ball into the back buffer
draw_overlay_chars:
    ld hl,OVL
    ld b,(hl)
    inc hl
    ld a,b
    or a
    jr z,.ball
.lp:
    ld a,(hl)           ; row
    inc hl
    ld c,(hl)           ; col
    inc hl
    push hl
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    ld a,l
    or c
    ld l,a
    ld de,CHARBUF
    add hl,de
    pop de
    ld a,(de)           ; char
    ld (hl),a
    inc de
    inc de
    ex de,hl
    djnz .lp
.ball:
    ld a,(ballch)
    ld (CHARBUF+VIEW_C*32+VIEW_C),a
    ret

blit:
    include "../build/gen_blit.inc"
    ret

; ----------------------------------------------------------------------
; Colours: a quarter of the view rows per frame (the rainbow phase moves
; every 4 frames, so this reads as a wipe), border columns every frame.
colours:
    ld a,(framecnt)
    rra
    rra
    and 7
    ld (cphase),a
    ld a,(framecnt)
    and 3
    jr nz,.g1
    call colgrp0
    jr border
.g1:
    dec a
    jr nz,.g2
    call colgrp1
    jr border
.g2:
    dec a
    jr nz,.g3
    call colgrp2
    jr border
.g3:
    call colgrp3

border:                 ; rainbow marquee round the frame (white while flashing)
    ld a,(framecnt)
    cpl
    and 7
    ld l,a
    ld h,hi(STRIP2)
    ld a,(flash)
    or a
    jr z,.go
    dec a
    ld (flash),a
    set 7,l
.go:
    include "../build/gen_border.inc"
    ret

    include "../build/gen_colours.inc"

; A = row, C = col (view-relative) -> HL = colour RAM address
cram_addr:
    add a,a
    ld e,a
    ld d,0
    ld hl,ROW40
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld hl,CRAM+VIEW_Y*40+VIEW_X
    add hl,de
    ld e,c
    ld d,0
    add hl,de
    ret

; restore last frame's object cells to the rainbow, paint this frame's
overlay_colours:
    ld hl,OVLOLD
    ld b,(hl)
    inc hl
    ld a,b
    or a
    jr z,.new
.old:
    ld a,(hl)
    inc hl
    ld c,(hl)
    inc hl
    push hl
    push bc
    ld b,a
    ld a,(cphase)
    add a,b
    add a,c
    and 7
    ld e,a
    ld d,hi(STRIP)
    ld a,(de)
    push af
    ld a,b
    call cram_addr
    pop af
    ld (hl),a
    pop bc
    pop hl
    djnz .old
.new:
    ld hl,OVL
    ld de,OVLOLD
    ld a,(hl)
    ld (de),a
    inc hl
    inc de
    or a
    jr z,.ball
    ld b,a
.nl:                    ; HL -> (row, col, char, attr), DE -> OVLOLD slot
    ld a,(hl)           ; row
    inc hl
    ld c,(hl)           ; col
    inc hl
    inc hl              ; skip char
    push hl             ; -> attr
    ld (de),a
    inc de
    ex de,hl
    ld (hl),c
    inc hl
    ex de,hl
    push de
    push bc
    call cram_addr      ; A = row, C = col
    pop bc
    pop de
    ex (sp),hl          ; HL -> attr, stack = colour RAM address
    ld a,(hl)
    inc hl
    ex (sp),hl          ; HL = colour RAM address, stack -> next entry
    ld (hl),a
    pop hl
    djnz .nl
.ball:
    ld a,(ballat)
    ld (CRAM+(VIEW_Y+VIEW_C)*40+VIEW_X+VIEW_C),a
    ret
