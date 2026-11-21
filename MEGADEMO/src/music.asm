; ---------------------------------------------------------------------------
; music.asm - interrupt-driven 8253 player
;
; Counter 1 counts scan lines (mode 2, N=78), counter 2 counts those
; (mode 0, N=2) and raises INT every 156 lines = 100 Hz.  The handler re-arms
; counter 2, advances the tick clock and plays one byte of the song:
;   0 = speaker off, 1..111 = note (period table), 80h+k = noise burst k.
; Song data (build/gen_music.inc): mus_order = bar numbers (FFh = loop),
; mus_bars = 16 row pointers per bar, each row = 12 tick bytes.
; ---------------------------------------------------------------------------

irq:    ld (irq_sp),sp          ; own stack: only the return address
        ld sp,0C40h             ; lands on the interrupted SP
        push af
        push hl
        ld hl,0E006h
        ld (hl),2               ; re-arm counter 2 (OUT2 low, INT released)
        ld (hl),0
        ld hl,(mtick)
        inc hl
        ld (mtick),hl
        ld a,(mus_on)
        or a
        call nz,mus_tick
        pop hl
        pop af
        ld sp,(irq_sp)
        ei
        reti
irq_sp: dw 0

mus_start:                      ; A = bar in the order list to start from
        di
        ld l,a
        ld h,0
        ld de,mus_order
        add hl,de
        ld (mus_optr),hl
        call mus_newbar
        ld a,1
        ld (mus_on),a
        ei
        ret

mus_stop:
        xor a
        ld (mus_on),a
        ld (0E008h),a           ; gate off
        ld (mus_last),a
        ret

; next bar from the order list
mus_newbar:
        ld hl,(mus_optr)
        ld a,(hl)
        cp 0FFh
        jr nz,.ok
        ld hl,mus_order+MUS_LOOP
        ld a,(hl)
.ok:    push de
        push hl
        ld de,mus_order
        or a
        sbc hl,de
        ld (mus_pos),hl
        pop hl
        pop de
        inc hl
        ld (mus_optr),hl
        ; bar pointer = mus_bars + A*32
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,mus_bars
        add hl,de
        ld (mus_rowp),hl
        ld a,16
        ld (mus_rows),a
        ; fall through: fetch first row
mus_newrow:
        ld hl,(mus_rowp)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (mus_rowp),hl
        ld (mus_tp),de
        ld a,12
        ld (mus_tl),a
        ret

mus_tick:
        push bc
        push de
        ld hl,(mus_tp)
        ld a,(hl)
        inc hl
        ld (mus_tp),hl
        ld (mus_val),a
        ld hl,mus_tl
        dec (hl)
        jr nz,.play
        ld hl,mus_rows
        dec (hl)
        jr nz,.row
        call mus_newbar
        jr .play
.row:   call mus_newrow
.play:  ld a,(mus_val)
        or a
        jr z,.off
        jp m,.noise
        ld hl,mus_last
        cp (hl)
        jr z,.done              ; same note: leave the counter running
        ld (hl),a
        ld l,a
        ld h,0
        add hl,hl
        ld de,mus_periods
        add hl,de
        ld a,(hl)
        ld (0E004h),a
        inc hl
        ld a,(hl)
        ld (0E004h),a
        ld a,1
        ld (0E008h),a
.done:  pop de
        pop bc
        ret
.off:   ld (0E008h),a
        ld (mus_last),a
        jr .done
.noise: and 7Fh
        add a,a
        add a,a
        add a,a                 ; 8 bytes per drum
        ld l,a
        ld h,0
        ld de,mus_drums
        add hl,de
        ld b,(hl)               ; writes
        inc hl
        ld e,(hl)               ; mask
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)               ; base lo
        inc hl
        ld a,(hl)               ; base hi
        inc hl
        ld (.bh+1),a
        ld a,(hl)               ; keep?
        ld (mus_keep),a
        ld a,1
        ld (0E008h),a
        ld hl,(mus_seed)
.nl:    ; 16-bit xorshift
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld a,l
        and e
        add a,c
        ld (0E004h),a
        ld a,h
        and d
.bh:    adc a,0
        ld (0E004h),a
        djnz .nl
        ld (mus_seed),hl
        xor a
        ld (mus_last),a
        ld a,(mus_keep)
        or a
        jr nz,.done
        ld (0E008h),a
        jr .done

mus_on:    db 0
mus_val:   db 0
mus_last:  db 0
mus_keep:  db 0
mus_tl:    db 0
mus_rows:  db 0
mus_tp:    dw 0
mus_rowp:  dw 0
mus_optr:  dw 0
mus_bar:   dw 0
mus_pos:   dw 0
mus_seed:  dw 0ACE1h
mtick:     dw 0
