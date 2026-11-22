; ---------------------------------------------------------------------------
; fx_crash.asm - the fake crash: memory-dump garbage and noise, then a
; blinking "meditation" box.  (The greetings that follow start with
; "JUST KIDDING!")
; ---------------------------------------------------------------------------

crash_init:
        xor a
        ld (cr_n),a
        ret

crash_frame:
        call wait_vbl
        ld hl,cr_n
        ld a,(hl)
        inc (hl)
        cp 50
        jr nc,.box
        ; garbage: 60 random cells a frame
        ld b,60
.g:     call rand
        ld a,h
        and 3
        ld h,a
        ld de,1000
        or a
        sbc hl,de
        jr nc,.g
        add hl,de
        ld de,VCHR
        add hl,de
        push hl
        call rand
        pop hl
        ld (hl),a
        set 3,h
        and 77h
        ld (hl),a
        djnz .g
        ret
.box:   jr nz,.blink
        ; once: black screen and the box text
        call cls_black
        ld hl,cr_l1
        ld de,VCHR+10*40+3
        ld a,20h
        call print_at
        ld hl,cr_l2
        ld de,VCHR+12*40+3
        ld a,20h
        call print_at
.blink: ; the border blinks red
        ld a,(cr_n)
        and 32
        ld c,22h
        jr z,.on
        ld c,0
.on:    ld hl,VATR+8*40+1
        ld b,38
.t:     ld (hl),c
        push hl
        ld de,6*40
        add hl,de
        ld (hl),c
        pop hl
        inc hl
        djnz .t
        ld hl,VATR+8*40+1
        ld b,7
.s:     ld (hl),c
        push hl
        ld de,37
        add hl,de
        ld (hl),c
        pop hl
        ld de,40
        add hl,de
        djnz .s
        ; border cells are full blocks
        ld hl,VCHR+8*40+1
        ld b,38
.tc:    ld (hl),43h
        push hl
        ld de,6*40
        add hl,de
        ld (hl),43h
        pop hl
        inc hl
        djnz .tc
        ld hl,VCHR+8*40+1
        ld b,7
.sc:    ld (hl),43h
        push hl
        ld de,37
        add hl,de
        ld (hl),43h
        pop hl
        ld de,40
        add hl,de
        djnz .sc
        ret

cr_n:   db 0
