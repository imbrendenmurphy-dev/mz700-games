; screens.asm - front end (stub)
title_screen:
        ld a,BLUE*16
        call cls
.w:     call wait_field
        call read_keys
        ld a,(key_extra)
        bit 0,a
        jr z,.w
        call wait_release
        ld a,1
        or a
        ret
story_page:
guide_page:
records_page:
        xor a
        ret
records_init:
        ret
ending:
        ret
