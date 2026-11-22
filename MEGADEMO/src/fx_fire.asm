; ---------------------------------------------------------------------------
; fx_fire.asm - "Doom" fire in half-block mode under a big FIRE title.
; Heat (0-31) climbs from a hot bottom row: each pixel takes the heat of the
; one below, maybe one less, maybe one column to the left.
; WORK: +0 palette colour<<4, +100h palette colour, +200h random bytes,
;       +400h heat, 40 x 32 (rows 0-29 shown as cell rows 10-24, row 30 = fuel)
; ---------------------------------------------------------------------------

FPT     equ WORK
FPB     equ WORK+100h
FRND    equ WORK+200h
FHEAT   equ WORK+400h
FROW0   equ 12                  ; first chunky row on screen

fire_init:
        call cls_black
        ; palettes from the 32-entry ramp
        ld hl,fire_ramp
        ld de,FPT
        ld b,32
.p:     ld a,(hl)
        inc hl
        inc d
        ld (de),a
        dec d
        rlca
        rlca
        rlca
        rlca
        ld (de),a
        inc e
        djnz .p
        ; random bytes
        ld hl,FRND
        ld b,0
.r:     push hl
        call rand
        pop hl
        ld (hl),a
        inc l
        djnz .r
        ; heat: cold, fuel row hot
        ld hl,FHEAT
        ld de,FHEAT+1
        ld bc,40*30-1
        ld (hl),0
        ldir
        ld hl,FHEAT+40*30
        ld de,FHEAT+40*30+1
        ld bc,79
        ld (hl),31
        ldir
        ; screen: half-block characters below the title, black
        ld hl,VCHR+FROW0*40
        ld bc,13*40
.c:     ld (hl),7Ah
        set 3,h
        ld (hl),0
        res 3,h
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.c
        ld hl,fire_word
        ld de,VCHR+2*40+9
        ld ix,fire_ink
        call big_word
        exx
        ld hl,FRND
        exx
        ret

fire_frame:
        call wait_vbl
        ld bc,FROW0*256+13
        call blit_attr_rows
        ; the fuel flickers: a few random cold spots
        ld b,6
.f:     call rand
        and 3Fh
        cp 40
        jr nc,.f1
        ld e,a
        ld d,0
        ld hl,FHEAT+40*30
        add hl,de
        ld a,(hl)
        xor 31-12               ; 31 <-> 12
        ld (hl),a
.f1:    djnz .f
        ; spread: row y takes from row y+1
        ld hl,FHEAT+40*5
        ld de,FHEAT+40*4
        ld a,26
.row:   ex af,af'
        ld b,40
.px:    ld a,(hl)
        inc hl
        or a
        jr z,.zero
        ld c,a
        exx
        ld a,(hl)
        inc l
        exx
        add a,a                 ; drift to the left?
        jr nc,.nd
        dec de
        rlca                    ; cool by 0-3 (random bits 5-6)
        rlca
        and 3
        neg
        add a,c
        jp p,$+4
        xor a
        ld (de),a
        inc de
        inc de
        djnz .px
        jr .rd
.nd:
        rlca                    ; cool by 0-3 (random bits 5-6)
        rlca
        and 3
        neg
        add a,c
        jp p,$+4
        xor a
        ld (de),a
        inc de
        djnz .px
        jr .rd
.zero:  ld (de),a
        inc de
        djnz .px
.rd:    ex af,af'
        dec a
        jr nz,.row
        ; render 13 cell rows (heat rows 4-29)
        ld hl,FHEAT+40*4
        ld bc,FHEAT+40*5
        ld d,FPT/256
        ld ix,ABUF+FROW0*40
        ld a,13
.cr:    push af
.n = 0
        DUP 40
        ld e,(hl)
        ld a,(de)
        ex af,af'
        ld a,(bc)
        ld e,a
        inc d
        ld a,(de)
        dec d
        ld e,a
        ex af,af'
        or e
        ld (ix+.n),a
        inc hl
        inc bc
.n = .n + 1
        EDUP
        push de
        ld de,40
        add hl,de
        add ix,de
        ex de,hl
        add hl,bc
        ld b,h
        ld c,l
        ex de,hl
        pop de
        pop af
        dec a
        jp nz,.cr
        ret

fire_ramp:  db 0,0,0,0,0,0,0,0, 2,2,2,2,2,2,2,2,2,2, 6,6,6,6,6,6,6,6, 7,7,7,7,7,7
fire_word:  db "FIRE", 0
fire_ink:   db 70h, 60h, 60h, 60h, 20h, 20h, 20h
