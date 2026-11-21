; ---------------------------------------------------------------------------
; fx_intro.asm - typewriter intro, then a colour glitch into the title
; intro_text: dw vram offset, db attr, chars..., FFh;  dw FFFFh = end
; ---------------------------------------------------------------------------

intro_init:
        call cls_black
        ld hl,intro_text
        ld (it_line),hl
        call it_newline
        xor a
        ld (it_delay),a
        ld (it_done),a
        ld (it_glitch),a
        ret

it_newline:                     ; HL -> line header
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp 0FFh
        jr z,.end
        ld a,(hl)
        inc hl
        ld (it_attr),a
        ld (it_ptr),hl
        ld hl,VCHR
        add hl,de
        ld (it_vram),hl
        ret
.end:   ld a,1
        ld (it_done),a
        ret

intro_frame:
        call wait_vbl
        ld a,(mus_pos)
        cp BAR_TITLE-1
        jp nc,intro_glitch
        ld a,(it_done)
        or a
        jr nz,.cursor
        ld hl,it_delay
        inc (hl)
        ld a,(hl)
        cp 2
        jr c,.cursor
        ld (hl),0
        ; type one character
        ld hl,(it_ptr)
        ld a,(hl)
        cp 0FFh
        jr z,.eol
        inc hl
        ld (it_ptr),hl
        ld hl,(it_vram)
        ld (hl),a
        set 3,h
        ld a,(it_attr)
        ld (hl),a
        res 3,h
        inc hl
        ld (it_vram),hl
        jr .cursor
.eol:   ; remove the cursor, next line
        ld hl,(it_vram)
        ld (hl),0
        ld hl,(it_ptr)
        inc hl
        call it_newline
.cursor:
        ld a,(it_done)
        or a
        ret nz
        ld hl,(it_vram)
        ld a,(fcount)
        and 16
        ld a,43h                ; block cursor, blinking
        jr z,.c1
        xor a
.c1:    ld (hl),a
        set 3,h
        ld (hl),50h             ; cyan
        ret

; last bar: blocks of colour rain over the text, getting denser
intro_glitch:
        ld a,(fcount)
        and 3
        ld b,a
        ld a,(it_glitch)
        add a,2
        jr nc,.g0
        ld a,0FFh
.g0:    ld (it_glitch),a
        srl a
        srl a
        add a,4
        ld b,a
.gl:    call rand
        ld a,h
        and 3
        ld h,a
        ld de,1000
        or a
        sbc hl,de
        jr nc,.gl               ; off screen: try again
        add hl,de
        ld de,VCHR
        add hl,de
        call rand_glitch_cell
        djnz .gl
        ret

rand_glitch_cell:               ; HL = VRAM char address
        push hl
        call rand
        pop hl
        and 7
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,glitch_chars
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        pop hl
        ld (hl),a
        set 3,h
        ld (hl),e
        ret

glitch_chars:                   ; char, attr
        db 43h,10h, 43h,30h, 7Ah,15h, 3Ah,31h, 0EFh,13h, 43h,50h, 00h,70h, 0F9h,61h

it_line:  dw 0
it_ptr:   dw 0
it_vram:  dw 0
it_attr:  db 0
it_delay: db 0
it_done:  db 0
it_glitch: db 0
