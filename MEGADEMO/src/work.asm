; ---------------------------------------------------------------------------
; work.asm - the shared 8 KB work area (B000-CFFF) and the high RAM.
;
; Big tables are not stored in the program: each part builds them in WORK
; when it starts, or copies them down from the 12 KB of RAM under VRAM/IO
; (D000-FFFF, switched in with OUT (E1h), back with OUT (E3h)).
; ---------------------------------------------------------------------------

WORK    equ 0B000h

PALS    equ WORK                ; plasma: 4 palettes x 2 pages
ROTEX   equ WORK                ; rotozoomer: 16 pages colour<<4, 16 pages colour
ROTEXB  equ WORK+4096
TUNTEX  equ WORK                ; tunnel: 8 page pairs
TUNIDX  equ WORK+4096           ; tunnel: 2000 bytes of angle/depth
PROJT   equ WORK                ; dots: 16 x 128 perspective
DOTSHP  equ WORK+2048           ; dots: the shapes

; HL = source in high RAM, DE = destination, BC = length.  Copies 256 bytes
; at a time with interrupts off (VRAM and the 8253 are switched out).
hicopy: ld a,b
        or c
        ret z
        push bc
        ld a,b
        or a
        ld bc,256
        jr nz,.n
        pop bc
        push bc
        ld b,0
.n:     di
        out (0E1h),a
        push bc
        ldir
        pop bc
        out (0E3h),a
        ei
        ex (sp),hl              ; HL = remaining
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        jr hicopy

; ---------------------------------------------------------------- plasma
; pal_bands: per palette (colour, width) pairs adding up to 256
gen_pals:
        ld hl,pal_bands
        ld de,PALS
        ld b,4
.p:     push bc
        push de
.band:  ld a,(hl)               ; colour
        inc hl
        ld c,(hl)               ; width (0 = 256)
        inc hl
        ld b,a
.w:     ld a,b
        rlca
        rlca
        rlca
        rlca
        ld (de),a               ; top: colour << 4
        inc d
        ld a,b
        ld (de),a               ; bottom: colour
        dec d
        inc e
        dec c
        jr nz,.w
        ld a,e
        or a
        jr nz,.band
        pop de
        inc d
        inc d
        pop bc
        djnz .p
        ret

; ---------------------------------------------------------------- rotozoomer
; rz_tile: 16x16 colours -> 16 pages each holding a row 16 times, twice
gen_rotex:
        ld hl,rz_tile
        ld de,ROTEXB
.row:   ld c,16
.rep:   push hl
        ld b,16
.px:    ld a,(hl)
        inc hl
        ld (de),a
        inc e
        djnz .px
        pop hl
        dec c
        jr nz,.rep
        ld bc,16
        add hl,bc
        inc d
        ld a,d
        cp ROTEXB/256+16
        jr c,.row
        ld hl,ROTEXB            ; top pages: colour << 4
        ld de,ROTEX
        ld bc,4096
.sh:    ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        ld (de),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.sh
        ret

; ---------------------------------------------------------------- tunnel
; page p: tex[v] = T0[(v & F8h) | ((v + p) & 7)], as colour<<4 then colour
gen_vortex:
        ld hl,tun_t1
        jr gen_tt
gen_tuntex:
        ld hl,tun_t0
gen_tt: ld (gt_src),hl
        ld de,TUNTEX
        ld c,0                  ; p
.page:  ld b,0                  ; v
.v:     ld a,b
        add a,c
        and 7
        ld l,a
        ld a,b
        and 0F8h
        or l
        ld l,a
        ld h,0
        push de
        ld de,(gt_src)
        add hl,de
        pop de
        ld a,(hl)
        inc d
        ld (de),a
        dec d
        rlca
        rlca
        rlca
        rlca
        ld (de),a
        inc e
        inc b
        jr nz,.v
        inc d
        inc d
        inc c
        ld a,c
        cp 8
        jr c,.page
        ld hl,hi_tunidx
        ld de,TUNIDX
        ld bc,2000
        jp hicopy

; ---------------------------------------------------------------- dots
gen_proj:
        ld hl,PROJT
        ld de,proj_f
        ld b,16
.r:     push bc
        push de
        push hl
        ld a,(de)
        call dt_mktab
        pop hl
        ld de,128
        add hl,de
        pop de
        inc de
        pop bc
        djnz .r
        ld hl,hi_shapes
        ld de,DOTSHP
        ld bc,NDOTS*3*NSHAPES
        jp hicopy

gt_src: dw 0
