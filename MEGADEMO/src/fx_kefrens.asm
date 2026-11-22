; ---------------------------------------------------------------------------
; fx_kefrens.asm - Kefrens bars: one bar per scan line, drawn into a line
; buffer that is never cleared, so the bars stack up into a curtain.
;
; The MZ-700 has no raster interrupt, but every VRAM access outside a line's
; free window waits for the next one.  So a loop that writes 3 attribute
; bytes per pass, and takes longer than the window, writes exactly once per
; scan line.  Characters in the bar window are 7Bh (left half filled): ink is
; the left 4 pixels, paper the right 4 - 52 colour columns of 4 pixels.
;
; A character row only exists in VRAM once, so each row's starting state is
; written in VBLANK ("prep"), and during the picture each line writes its bar
; into the current row.  Bars are simulated ahead into the other buffer set,
; a third of the rows per frame; the finished set is swapped in.
;
; Interrupts are off for this part: the two music ticks are called directly.
; ---------------------------------------------------------------------------

KR0     equ 9                   ; first raster row (line 72)
KROWS   equ 16                  ; to row 24
KLINES  equ KROWS*8
KWX     equ 7                   ; window: columns 7-32
KW      equ 26
KPARTS  equ 4                   ; frames per simulated set

KS      equ 0300h               ; line state, 26 bytes (page aligned)
KLIST_A equ 0400h               ; replay lists, 6 bytes per line (0400-09FF)
KLIST_B equ 0400h + KLINES*6
KPREP_A equ 0A00h               ; row starting states, 26 bytes per row
KPREP_B equ 1000h               ; (0A00-0B9F, 1000-119F)

kefrens_init:
        call kf_gen_prep
        di
        call cls_black
        ; the bar window: left-half characters on black
        ld hl,VCHR+KR0*40+KWX
        ld c,KROWS
.r:     ld b,KW
        push hl
.w:     ld (hl),7Bh
        inc hl
        djnz .w
        pop hl
        ld de,40
        add hl,de
        dec c
        jr nz,.r
        ; title: big RASTER in full blocks, caption under it
        call kf_title
        ld hl,kf_caption
        ld de,VCHR+8*40
        ld a,50h
        call print_at
        ; first set of bars, computed in full
        ld hl,KLIST_B
        ld (kf_lnext),hl
        ld hl,KPREP_B
        ld (kf_pnext),hl
        xor a
        ld (kf_t1),a
        ld (kf_t2),a
        ld (kf_tc),a
        call kf_sim_begin
        ld b,KPARTS
.s:     push bc
        call kf_sim_part
        pop bc
        djnz .s
        call kf_swap
        call kf_sim_begin
        ; counter 1 reads the same at line 200 of every frame (312 = 4*78);
        ; line 72 is 184 lines on = 28 counts
        call wait_vbl
        call kf_ctr1
        sub 28
        jr z,.t0
        jr nc,.t1
.t0:    add a,78
.t1:    ld (kf_target),a
        ret

; ---------------------------------------------------------------- frame
kefrens_frame:
.v:     ld a,(0E002h)                   ; the last frame ended at line 200:
        rla                             ; just wait for VBLANK to be on
        jr c,.v
        call kf_tick
        ; a finished set goes on screen
        ld a,(kf_part)
        cp KPARTS
        jr c,.nos
        call kf_swap
        call kf_sim_begin
.nos:   ; row starting states (VBLANK)
        ld (kf_ssp),sp
        ld sp,(kf_pcur)
        ld ix,.prepd
        jp kf_prep_code
.prepd: ld sp,(kf_ssp)
        ; a slice of the next set
        call kf_sim_part
        call kf_tick
        ; wait for the picture, then for counter 1 to reach line 72
.dp:    ld a,(0E002h)
        rla
        jr nc,.dp
        ld a,(kf_target)
        ld c,a
.cw:    call kf_ctr1
        cp c
        jr nz,.cw
        ; replay: one bar per scan line
        ld (kf_ssp),sp
        ld sp,(kf_lcur)
        ld iyl,KLINES
.l:     pop hl
        pop de
        pop bc
        ld (hl),e                       ; waits for this line's free window
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        ex (sp),hl                      ; padding: the next pass must miss
        ex (sp),hl                      ; this window
        dec iyl
        jp nz,.l
        ld sp,(kf_ssp)
        ret

; counter 1 (scan lines, 78..1) -> A
kf_ctr1:
        ld a,40h                        ; latch counter 1
        ld (0E007h),a
        ld a,(0E005h)
        ld b,a
        ld a,(0E005h)                   ; high byte (0)
        ld a,b
        ret

; one music tick by hand (interrupts are off)
kf_tick:
        ld hl,(mtick)
        inc hl
        ld (mtick),hl
        ld a,(mus_on)
        or a
        ret z
        jp mus_tick

kf_swap:
        ld hl,(kf_lnext)
        ld de,(kf_lcur)
        ld (kf_lcur),hl
        ld (kf_lnext),de
        ld hl,(kf_pnext)
        ld de,(kf_pcur)
        ld (kf_pcur),hl
        ld (kf_pnext),de
        ret

; ---------------------------------------------------------------- simulation
kf_sim_begin:
        ld hl,KS
        ld b,KW
        xor a
.c:     ld (hl),a
        inc l
        djnz .c
        ld a,(kf_t1)
        add a,5
        ld (kf_t1),a
        ld (kf_a1),a
        ld a,(kf_t2)
        sub 3
        ld (kf_t2),a
        ld (kf_a2),a
        ld hl,kf_tc
        inc (hl)
        ld hl,(kf_lnext)
        ld (kf_lp),hl
        ld hl,(kf_pnext)
        ld (kf_pp),hl
        xor a
        ld (kf_row),a
        ld (kf_part),a
        ret

; simulate the rows of the next slice
kf_sim_part:
        ld a,(kf_part)
        cp KPARTS
        ret nc
        inc a
        ld (kf_part),a
        ld e,a
        ld d,0
        ld hl,kf_slice-1
        add hl,de
        ld a,(hl)                       ; row to stop at
        ld (kf_stop),a
.row:   ld a,(kf_row)
        ld hl,kf_stop
        cp (hl)
        ret nc
        call kf_sim_row
        ld hl,kf_row
        inc (hl)
        jr .row

kf_slice: db 4, 8, 12, 16

kf_sim_row:
        ; starting state of this row -> prep
        ld hl,KS
        ld de,(kf_pp)
        ld bc,KW
        ldir
        ld (kf_pp),de
        ; bar colours for this row: SMC into the apply code
        ld a,(kf_tc)                    ; one colour for all bars, a new
        rrca                            ; one every 8 sets
        rrca
        rrca
        and 3
        ld l,a
        add a,a
        add a,a
        add a,l                         ; *5
        ld e,a
        ld d,0
        ld hl,kf_pals
        add hl,de
        ld a,(hl)
        ld (.e0+1),a
        inc hl
        ld a,(hl)
        ld (.e1+1),a
        inc hl
        ld a,(hl)
        ld (.o0+1),a
        inc hl
        ld a,(hl)
        ld (.o1+1),a
        inc hl
        ld a,(hl)
        ld (.o2+1),a
        ; VRAM row address of the window
        ld a,(kf_row)
        add a,a
        ld e,a
        ld d,0
        ld hl,kf_rowv
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (kf_rv),hl
        ld b,8
.line:  push bc
        ; position: two sines, 0..46 half columns
        ld a,(kf_a1)
        add a,2
        ld (kf_a1),a
        ld l,a
        ld h,KPOS/256
        ld c,(hl)
        ld a,(kf_a2)
        inc a
        ld (kf_a2),a
        ld l,a
        inc h
        ld a,(hl)
        add a,c
        ; apply the bar to the line state
        ld h,KS/256
        srl a
        ld l,a
        ld (kf_k),a
        jr c,.odd
.e0:    ld (hl),0
        inc l
.e1:    ld (hl),0
        jr .emit
.odd:   ld a,(hl)
        and 0F0h
.o0:    or 0
        ld (hl),a
        inc l
.o1:    ld (hl),0
        inc l
        ld a,(hl)
        and 0Fh
.o2:    or 0
        ld (hl),a
.emit:  ; list entry: VRAM address, 3 bytes, pad
        ld a,(kf_k)
        ld c,a
        ld b,0
        ld hl,(kf_rv)
        add hl,bc
        ex de,hl
        ld hl,(kf_lp)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld b,KS/256
        ld a,(bc)
        ld (hl),a
        inc hl
        inc c
        ld a,(bc)
        ld (hl),a
        inc hl
        inc c
        ld a,(bc)
        ld (hl),a
        inc hl
        inc hl
        ld (kf_lp),hl
        pop bc
        djnz .line
        ret

; palettes: even (c0c1, c2c3), odd (c0, c1c2, c3<<4)
kf_pals:
        db 15h, 75h, 01h, 57h, 50h      ; blue  cyan  white cyan
        db 26h, 76h, 02h, 67h, 60h      ; red   yellow white yellow
        db 33h, 73h, 03h, 37h, 30h      ; magenta magenta white magenta
        db 46h, 76h, 04h, 67h, 60h      ; green yellow white yellow

kf_rowv:
.r = 0
        DUP KROWS
        dw VATR + (KR0+.r)*40 + KWX
.r = .r + 1
        EDUP

; prep: pop 13 words per row into the window (SP = prep buffer).  The
; unrolled code is generated into WORK at init: pop hl / ld (nn),hl ...
kf_prep_code equ WORK

kf_gen_prep:
        ld de,kf_prep_code
        ld hl,VATR + KR0*40 + KWX
        ld c,KROWS
.r:     ld b,KW/2
        push hl
.w:     ld a,0E1h               ; pop hl
        ld (de),a
        inc de
        ld a,22h                ; ld (nn),hl
        ld (de),a
        inc de
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        inc hl
        inc hl
        djnz .w
        pop hl
        push de
        ld de,40
        add hl,de
        pop de
        dec c
        jr nz,.r
        ld a,0DDh               ; jp (ix)
        ld (de),a
        inc de
        ld a,0E9h
        ld (de),a
        ret

; the RASTER title (big font, full blocks)
kf_title:
        ld hl,kf_word
        ld de,VCHR+1*40+2
        ld ix,kf_tink
        jp big_word

kf_word:    db "RASTER", 0
kf_tink:    db 20h, 20h, 60h, 60h, 70h, 50h, 10h

kf_lcur:   dw KLIST_A
kf_lnext:  dw KLIST_B
kf_pcur:   dw KPREP_A
kf_pnext:  dw KPREP_B
kf_lp:     dw 0
kf_pp:     dw 0
kf_rv:     dw 0
kf_ssp:    dw 0
kf_t1:     db 0
kf_t2:     db 0
kf_tc:     db 0
kf_a1:     db 0
kf_a2:     db 0
kf_k:      db 0
kf_row:    db 0
kf_stop:   db 0
kf_part:   db 0
kf_target: db 0
