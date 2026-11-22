; =====================================================================
;  WORLD CLASH - a one-on-one fighting game for the Sharp MZ-700
;  (64K, PAL, European CG-ROM, no PCG).  Loads at 1200h.
;
;  Memory (the monitor ROM at 0000h is switched out for RAM at start):
;   0000-00FF  RST/INT vectors (0038h -> irq)
;   0100-03FF  P1 cell dictionary: chars, attrs, mirrored chars
;   0400-06FF  P2 cell dictionary
;   0700-07FF  XLAT1  P1 attribute translation (palette, flashes)
;   0800-08FF  XLAT2  P2
;   0900-09FF  XLATW  all white (hit flash)
;   0A00-0AFF  XLATI  identity
;   0B00-0BFF  ATOD   ASCII -> display code
;   0C00-0C3F  ROWTAB COMP address of each row
;   0C40-0CFF  anim_list
;   0D00-0DFF  OBJ    8 objects x 32
;   0E00-0FFF  scratch, IRQ
;   1000-11FF  stack
;   1200-AFFF  program
;   B000-BFFF  BG     the stage (chars B000, attrs B800)
;   C000-CFFF  COMP   composite (chars C000, attrs C800) interleaved with
;              SHOWN  the copy of VRAM (chars C400, attrs CC00)
;   D000-FFFF  high RAM behind VRAM/IO: fighter frames
; =====================================================================
        DEVICE NOSLOT64K

VRAM            equ 0D000h
ARAM            equ 0D800h
KEYPA           equ 0E000h
KEYPB           equ 0E001h
KEYPC           equ 0E002h
KEYCTL          equ 0E003h
CTR0            equ 0E004h
CTR1            equ 0E005h
CTR2            equ 0E006h
CTRL            equ 0E007h
SNDGATE         equ 0E008h

DICT1           equ 0100h
DICT2           equ 0400h
XLAT1           equ 0700h
XLAT2           equ 0800h
XLATW           equ 0900h
XLATI           equ 0A00h
ATOD            equ 0B00h
ROWTAB          equ 0C00h
anim_list       equ 0C40h
ANIM_MAX        equ 90
OBJ             equ 0D00h
NOBJ            equ 8
STACKTOP        equ 1200h
BGM             equ 0B000h
COMP            equ 0C000h
WORK            equ 0C000h          ; stage unpacking (before show_all)
SHOWN           equ 0C400h

; colours
BLACK           equ 0
BLUE            equ 1
RED             equ 2
MAGENTA         equ 3
GREEN           equ 4
CYAN            equ 5
YELLOW          equ 6
WHITE           equ 7

; key codes: row*8 + bit
KC_CR           equ 0*8+0
KC_SPACE        equ 6*8+4
KC_BREAK        equ 8*8+7
KC_Z            equ 1*8+6
KC_J            equ 3*8+6
KC_X            equ 2*8+0
KC_UP           equ 7*8+5
KC_DOWN         equ 7*8+4
KC_LEFT         equ 7*8+2
KC_RIGHT        equ 7*8+3

        org 1200h
start:  di
        ld sp,STACKTOP
        out (0E0h),a                    ; 0000-0FFF = RAM
        ld a,0C3h
        ld (38h),a
        ld hl,irq
        ld (39h),hl
        im 1
        call init_tables
        ld a,36h                        ; counter 0: square wave
        ld (CTRL),a
        xor a
        ld (SNDGATE),a
        ld hl,CTRL
        ld (hl),74h                     ; counter 1: rate generator, 78 lines
        ld (hl),0B0h                    ; counter 2: one-shot, 2 counts -> 100 Hz
        ld a,78
        ld (CTR1),a
        xor a
        ld (CTR1),a
        ld a,2
        ld (CTR2),a
        xor a
        ld (CTR2),a
        ld a,5                          ; INTMSK on (PC2)
        ld (KEYCTL),a
        ei
        jp title

; ---------------------------------------------------------------- tables
init_tables:
        ; ATOD
        ld hl,ATOD
        ld b,0
.z:     ld (hl),0
        inc l
        djnz .z
        ld hl,atod_src
        ld de,ATOD+20h
        ld bc,96
        ldir
        ; ROWTAB: COMP + row*40
        ld hl,COMP
        ld ix,ROWTAB
        ld b,25
        ld de,40
.r:     ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        add hl,de
        djnz .r
        ; identity and white translation pages
        ld hl,XLATI
.i:     ld (hl),l
        inc l
        jr nz,.i
        ld hl,XLATW
.w:     ld a,l
        and 88h                         ; keep bank and transparency
        or 70h                          ; white ink
        bit 3,a
        jr nz,.wt
        or 7                            ; opaque: white paper too
.wt:    ld (hl),a
        inc l
        jr nz,.w
        ld hl,XLATI
        ld de,XLAT1
        ld bc,256
        ldir
        ld hl,XLATI
        ld de,XLAT2
        ld bc,256
        ldir
        ld hl,0FFFFh
        ld (anim_list),hl
        call objs_clear
        ret

; ---------------------------------------------------------------- fighters
; load_dict: A = fighter number, DE = dict base page address (DICT1/DICT2)
; expands the fighter's cell dictionary into chars, attrs, mirrored chars
load_dict:
        push de
        add a,a
        ld l,a
        ld h,0
        ld bc,ftr_tab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                          ; HL = fighter record
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                          ; HL = dict: n, chars, attrs
        pop de
        ld c,(hl)                       ; n
        inc hl
        inc e                           ; entries from 1
        push de
        push bc
        ld b,0
        ldir                            ; chars
        pop bc
        pop de
        push de
        inc d
        push bc
        ld b,0
        ldir                            ; attrs
        pop bc
        pop de
        ; mirrored chars: look each glyph up in the mirror pairs
        ld b,c
.m:     push bc
        ld a,(de)                       ; char
        ld c,a
        inc d
        ld a,(de)                       ; attr: bit 7 = bank
        dec d
        rlca
        and 1
        ld b,a                          ; BC = glyph number
        ld hl,mir_pairs
.s:     inc hl                          ; the glyph's high byte
        ld a,(hl)
        cp 0FFh
        jr z,.nf                        ; not listed: mirrors to itself
        cp b
        jr nz,.nx
        dec hl
        ld a,(hl)
        inc hl
        cp c
        jr z,.f
.nx:    inc hl
        inc hl
        inc hl
        jr .s
.f:     inc hl
        ld c,(hl)
.nf:    ld a,c
        inc d
        inc d
        ld (de),a
        dec d
        dec d
        inc e
        pop bc
        djnz .m
        ret

        include "sys.asm"
        include "sound.asm"
        include "render.asm"
        include "render2.asm"
        include "fight.asm"
        include "ai.asm"
        include "game.asm"
        include "hud.asm"
        include "stage.asm"
        include "front.asm"
        include "joy.asm"
        include "../build/gen_text.inc"
        include "../build/gen_art.inc"
        include "../build/gen_stage.inc"
        include "../build/gen_music.inc"
        include "../build/gen_gfx.inc"

code_end:
        ASSERT code_end <= 0B000h
        DISPLAY "code end: ", /H, code_end

        SAVEBIN "../build/MAIN.BIN", start, code_end - start

; ---------------------------------------------------------------------
; high RAM (behind VRAM and I/O, OUT E1h in / E3h out)
; ---------------------------------------------------------------------
        org 0D000h
hi_start:
        include "../build/gen_hi.inc"
hi_end:
        ASSERT hi_end <= 0FFF0h
        DISPLAY "high data end: ", /H, hi_end
        SAVEBIN "../build/HIGH.BIN", hi_start, hi_end - hi_start
