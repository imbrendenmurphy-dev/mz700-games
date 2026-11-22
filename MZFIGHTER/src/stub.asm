; ---------------------------------------------------------------------------
; stub.asm - tape loader front end.  The file holds this stub, the packed
; high-RAM data and the packed program (tools/crunch.py format).
;  1. the unpacker goes to low RAM (under the switched-out monitor ROM)
;  2. the packed program moves to the top of RAM (ending at D000h)
;  3. the high data unpacks into the RAM under VRAM/IO (D000-FFFF)
;  4. the program unpacks in place to 1200h and starts
; ---------------------------------------------------------------------------
        DEVICE NOSLOT64K

PACK_TOP equ 0D000h
DEC_AT   equ 0C80h

        org 1200h
stub:   di
        out (0E0h),a            ; 0000-0FFF = RAM
        ld sp,0C80h
        ld hl,0D000h            ; "DECRUNCHING..." on black
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
        ld hl,dec_src
        ld de,DEC_AT
        ld bc,dec_len
        ldir
        ld hl,main_end-1
        ld de,PACK_TOP-1
        ld bc,main_end-main_pk
        lddr
        ; high data
        out (0E1h),a
        ld hl,high_pk
        ld de,0D000h
        call DEC_AT
        out (0E3h),a
        ; the program
        ld hl,PACK_TOP-(main_end-main_pk)
        ld de,1200h
        ld bc,1200h
        push bc                 ; unpack returns to the game
        jp DEC_AT

msg:    db 4,5,3,18,21,14,3,8,9,14,7,2Eh,2Eh,2Eh   ; DECRUNCHING...
msg_len equ $-msg

dec_src:
        DISP DEC_AT
; HL = packed data, DE = output
.lp:    ld a,(hl)
        inc hl
        cp 0FFh
        ret z
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

high_pk:
        INCBIN "../build/high.pak"
main_pk:
        INCBIN "../build/main.pak"
main_end:

        ASSERT main_end <= PACK_TOP
        SAVEBIN "../build/stub.bin", stub, main_end-stub
