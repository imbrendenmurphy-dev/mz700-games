; ---------------------------------------------------------------------------
; stub.asm - tape loader front end: moves the packed demo to the top of RAM,
; unpacks it to 1200h (see tools/crunch.py) and starts it.
; ---------------------------------------------------------------------------
        DEVICE NOSLOT64K

PACK_TOP equ 0D000h             ; packed data ends here
DEC_AT   equ 0C80h              ; the unpacker runs from RAM under the ROM

        org 1200h
stub:   di
        out (0E0h),a            ; 0000-0FFF = RAM
        ld sp,0C80h
        ; screen: "DECRUNCHING..." on black
        ld hl,0D000h
        ld de,0D001h
        ld bc,999
        ld (hl),0
        ldir
        ld hl,0D800h
        ld de,0D801h
        ld bc,999
        ld (hl),70h
        ldir
        ld hl,msg
        ld de,0D000h+12*40+13
        ld bc,msg_len
        ldir
        ; unpacker to low RAM, packed data to the top
        ld hl,dec_src
        ld de,DEC_AT
        ld bc,dec_len
        ldir
        ld hl,packed_end-1
        ld de,PACK_TOP-1
        ld bc,packed_end-packed
        lddr
        jp DEC_AT

msg:    db 4,5,3,18,21,14,3,8,9,14,7,2Eh,2Eh,2Eh   ; DECRUNCHING...
msg_len equ $-msg

dec_src:
        DISP DEC_AT
        ld hl,PACK_TOP-(packed_end-packed)
        ld de,1200h
.lp:    ld a,(hl)
        inc hl
        cp 0FFh
        jp z,1200h
        bit 7,a
        jr nz,.match
        ld c,a
        ld b,0
        inc bc
        ldir
        jr .lp
.match: and 7Fh
        add a,3
        ld c,a
        ld b,0
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        push de
        ex de,hl
        or a
        sbc hl,de               ; output - offset
        pop de
        ldir
        pop hl
        inc hl
        jr .lp
        ENT
dec_len equ $-dec_src

packed:
        INCBIN "../build/megademo.pak"
packed_end:

        ASSERT packed_end <= PACK_TOP
        SAVEBIN "../build/stub.bin", stub, packed_end-stub
