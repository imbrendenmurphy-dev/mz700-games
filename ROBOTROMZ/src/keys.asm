; =====================================================================
;  keys.asm - keyboard matrix
;
;  Rows (E000h = F0h + row), columns active low on E001h:
;   row 0: bit0 CR            row 2: bit7 Q  bit5 S  bit1 W
;   row 3: bit7 I  bit6 J  bit5 K  bit4 L  bit3 M
;   row 4: bit7 A  bit4 D     row 6: bit4 SPACE
;   row 7: bit5 up  bit4 down  bit3 right  bit2 left
; =====================================================================

read_keys:
        ld hl,kbuf              ; keep last tick's scan for new presses
        ld de,kprev
        ld bc,10
        ldir
        ld hl,kbuf              ; scan all rows, 1 = pressed
        ld b,0F0h
.scan:  ld a,b
        ld (KROW),a
        nop
        nop
        ld a,(KCOL)
        cpl
        ld (hl),a
        inc hl
        inc b
        ld a,b
        cp 0FAh
        jr nz,.scan

        ld c,0                  ; movement: W A S D
        ld a,(kbuf+2)
        bit 1,a
        jr z,.m1
        set 0,c                 ; W up
.m1:    bit 5,a
        jr z,.m2
        set 1,c                 ; S down
.m2:    ld a,(kbuf+4)
        bit 7,a
        jr z,.m3
        set 2,c                 ; A left
.m3:    bit 4,a
        jr z,.m4
        set 3,c                 ; D right
.m4:    ld a,c
        call cancel_opp
        ld (mkeys),a

        ld c,0                  ; fire: I J K L or the cursor keys
        ld a,(kbuf+3)
        bit 7,a
        jr z,.f1
        set 0,c                 ; I up
.f1:    bit 5,a
        jr z,.f2
        set 1,c                 ; K down
.f2:    bit 6,a
        jr z,.f3
        set 2,c                 ; J left
.f3:    bit 4,a
        jr z,.f4
        set 3,c                 ; L right
.f4:    ld a,(kbuf+7)
        bit 5,a
        jr z,.f5
        set 0,c
.f5:    bit 4,a
        jr z,.f6
        set 1,c
.f6:    bit 2,a
        jr z,.f7
        set 2,c
.f7:    bit 3,a
        jr z,.f8
        set 3,c
.f8:    ld a,c
        call cancel_opp
        ld (fkeys),a

        ld c,0                  ; specials: bit0 SPACE, bit1 CR, bit2 Q, bit3 M
        ld a,(kbuf+6)
        bit 4,a
        jr z,.s1
        set 0,c
.s1:    ld a,(kbuf+0)
        bit 0,a
        jr z,.s2
        set 1,c
.s2:    ld a,(kbuf+2)
        bit 7,a
        jr z,.s3
        set 2,c
.s3:    ld a,(kbuf+3)
        bit 3,a
        jr z,.s4
        set 3,c
.s4:    ld a,(skeys)
        cpl
        and c
        ld (sedge),a            ; newly pressed
        ld a,c
        ld (skeys),a
        ret

; A = the letter key pressed this tick (ASCII), 8 for DEL, or 0
get_letter:
        ld a,(kbuf+7)           ; DEL: row 7 bit 6
        ld hl,kprev+7
        cpl
        or (hl)
        cpl
        bit 6,a
        ld a,8
        ret nz
        ld hl,kbuf+1
        ld de,kprev+1
        ld ix,lettab
        ld c,4
.r:     ld a,(de)               ; new presses in this row
        cpl
        and (hl)
        jr nz,.hit
        inc hl
        inc de
        push bc
        ld bc,8
        add ix,bc
        pop bc
        dec c
        jr nz,.r
        xor a
        ret
.hit:   ld b,a                  ; highest bit -> letter
.f:     sla b
        jr c,.got
        inc ix
        jr .f
.got:   ld a,(ix+0)
        ret

lettab: db "YZ",0,0,0,0,0,0     ; rows 1..4, bit 7 first
        db "QRSTUVWX"
        db "IJKLMNOP"
        db "ABCDEFGH"

; drop both of a pair of opposite directions
cancel_opp:
        ld b,a
        and 03h
        cp 03h
        jr nz,.h
        ld a,b
        and 0FCh
        ld b,a
.h:     ld a,b
        and 0Ch
        cp 0Ch
        ld a,b
        ret nz
        and 0F3h
        ret

KS_SPACE equ 01h
KS_CR    equ 02h
KS_Q     equ 04h
KS_M     equ 08h
