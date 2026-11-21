; ===========================================================================
;  SHARP EDGES - a megademo for the Sharp MZ-700
;  by SPRITELESS, 2026
;
;  Memory:  0000-0FFF RAM (the monitor ROM is switched out)
;             0038      jp irq
;             0400-07E7 ABUF  attribute back buffer (1000)
;             0800-0BE7 CBUF  character back buffer (1000)
;             0C00-0FFF stack
;           1200-       code + data
;           D000-D3E7 characters, D800-DBE7 attributes
;           attribute = bit 7 char bank, bits 6-4 ink, bits 2-0 paper
;  Colours: 0 black 1 blue 2 red 3 magenta 4 green 5 cyan 6 yellow 7 white
; ===========================================================================
        DEVICE NOSLOT64K

ABUF    equ 0400h
CBUF    equ 0800h
VCHR    equ 0D000h
VATR    equ 0D800h

        org 1200h
start:  di
        ld sp,1000h
        out (0E0h),a            ; 0000-0FFF = RAM
        ld a,0C3h
        ld (38h),a
        ld hl,irq
        ld (39h),hl
        im 1
        ld a,36h                ; counter 0: square wave
        ld (0E007h),a
        xor a
        ld (0E008h),a
        call wait_vbl
        ld hl,0E007h
        ld (hl),74h             ; counter 1: rate generator, 78 lines
        ld (hl),0B0h            ; counter 2: one-shot, 2 counts -> 100 Hz
        ld a,78
        ld (0E005h),a
        xor a
        ld (0E005h),a
        ld a,2
        ld (0E006h),a
        xor a
        ld (0E006h),a
        ld a,5                  ; INTMSK on (PC2)
        ld (0E003h),a
        ei

demo_loop:
        call cls_black
        xor a
        call mus_start
        ld hl,script
.part:  ld (script_ptr),hl
        ld de,script
        or a
        sbc hl,de
        call nz,flash           ; every part but the first starts on a flash
        ld hl,(script_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call jp_hl              ; init
.frame: ld hl,(script_ptr)
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call jp_hl              ; one frame
        ld hl,(script_ptr)
        ld de,4
        add hl,de
        ld a,(mus_pos)
        cp (hl)
        jr nz,.frame
        ld a,2                  ; a part may have run with interrupts off:
        ld (0E006h),a           ; re-arm counter 2 (drops a stale tick)
        xor a
        ld (0E006h),a
        ei
        inc hl
        ld a,(hl)
        inc hl
        or a
        jr z,.part
        jr demo_loop

jp_hl:  jp (hl)

; white flash between parts: all attributes 77h for a few frames
flash:  call wait_vbl
        ld hl,VATR
        ld bc,1000
.l:     ld (hl),77h
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        call wait_vbl
        jp wait_vbl

;            init         frame        until bar, more (0 = next part)
script: dw intro_init,  intro_frame
        db BAR_TITLE, 0
        dw title_init,  title_frame
        db BAR_PLASMA, 0
        dw plasma_init, plasma_frame
        db BAR_ROTO, 0
        dw roto_init,   roto_frame
        db BAR_TUNNEL, 0
        dw tunnel_init, tunnel_frame
        db BAR_KEFRENS, 0
        dw kefrens_init, kefrens_frame
        db BAR_DOTS, 0
        dw dots_init,   dots_frame
        db BAR_GREETS, 0
        dw greets_init, greets_frame
        db BAR_END, 0
        dw end_init,    end_frame
        db 0, 1

script_ptr: dw 0

        include "sys.asm"
        include "music.asm"
        include "fx_intro.asm"
        include "fx_title.asm"
        include "fx_plasma.asm"
        include "fx_roto.asm"
        include "fx_tunnel.asm"
        include "fx_kefrens.asm"
        include "fx_dots.asm"
        include "fx_greets.asm"
        include "fx_end.asm"

        include "../build/gen_data.inc"

end_of_code:
        display "code+data end: ", /h, end_of_code
        ASSERT end_of_code < 0D000h

        SAVEBIN "../build/megademo.bin", start, end_of_code - start
