; ---------------------------------------------------------------------------
; fx_roto.asm - rotozoomer in 40x50 half-block mode.
; Texture: 16 pages from ROTEX, each a 16-texel row repeated 16 times, texel
; byte = colour * 11h.  u (8.8) walks along a page, v (8.8) picks the page.
; Chunky pixels are twice as wide as tall, so rows step half as far.
; Per pixel: main E/L = u frac/int, B.C = du;  alt E/D = v frac/int, B'.C' = dv
; ---------------------------------------------------------------------------

RZ_ROW0 equ 2                   ; letterbox: cell rows 2-22
RZ_ROWS equ 21

roto_init:
        call chunky_init
        ld hl,rz_cap1
        ld de,VCHR+0*40
        ld a,50h
        call print_at
        ld hl,rz_cap2
        ld de,VCHR+24*40
        ld a,50h
        jp print_at

; u in HL (8.8), du in DE; v in HL', dv in DE'.  Texel page from v, low
; byte from u, read through BC.
        MACRO RZ_STEP pages
        add hl,de
        ld c,h
        exx
        add hl,de
        ld a,h
        exx
        and 15
        add a,pages
        ld b,a
        ld a,(bc)
        ENDM

rz_setup:                       ; registers for a row
        ld hl,(rz_v)
        ld de,(rz_dv)
        exx
        ld hl,(rz_u)
        ld de,(rz_du)
        ret

rz_next:                        ; row start += row step
        ld hl,(rz_u)
        ld de,(rz_rdu)
        add hl,de
        ld (rz_u),hl
        ld hl,(rz_v)
        ld de,(rz_rdv)
        add hl,de
        ld (rz_v),hl
        ret

roto_frame:
        call wait_vbl
        ld bc,RZ_ROW0*256+RZ_ROWS
        call blit_attr_rows
        ; angle = t/2
        ld hl,(mtick)
        srl h
        rr l
        ld a,l
        ld (rz_ang),a
        ; zoom (texels per pixel * 64)
        ld a,(mtick)
        ld e,a
        srl a
        add a,e
        call sin_a
        sra a
        sra a
        sra a                   ; -16..15
        add a,36                ; 20..51: 0.3-0.8 texels per pixel
        ld (rz_zoom),a
        ; du = cos * zoom, dv = sin * zoom  (8.8)
        ld e,a
        ld a,(rz_ang)
        call cos_a
        call muls16
        call rz_fix
        ld (rz_du),hl
        ld a,(rz_zoom)
        ld e,a
        ld a,(rz_ang)
        call sin_a
        call muls16
        call rz_fix
        ld (rz_dv),hl
        ; row step (-dv/2, du/2)
        ld hl,(rz_dv)
        call neg_hl
        sra h
        rr l
        ld (rz_rdu),hl
        ld hl,(rz_du)
        sra h
        rr l
        ld (rz_rdv),hl
        ; centre drifts
        ld hl,(mtick)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; t*32: ~12 texels/s
        ld (rz_u),hl
        ld (rz_v),hl
        ; start = centre - 20*du - 21*rowstep
        ld de,(rz_du)
        ld hl,(rz_u)
        ld b,20
        call rz_subn
        ld de,(rz_rdu)
        ld b,RZ_ROWS
        call rz_subn
        ld (rz_u),hl
        ld de,(rz_dv)
        ld hl,(rz_v)
        ld b,20
        call rz_subn
        ld de,(rz_rdv)
        ld b,RZ_ROWS
        call rz_subn
        ld (rz_v),hl
        ld ix,ABUF+RZ_ROW0*40
        ld a,RZ_ROWS
.row:   ld (rz_cnt),a
        call rz_setup
.n = 0
        DUP 40
        RZ_STEP ROTEX/256
        ld (ix+.n),a
.n = .n + 1
        EDUP
        call rz_next
        call rz_setup
.n = 0
        DUP 40
        RZ_STEP ROTEXB/256
        or (ix+.n)
        ld (ix+.n),a
.n = .n + 1
        EDUP
        call rz_next
        ld de,40
        add ix,de
        ld a,(rz_cnt)
        dec a
        jp nz,.row
        ret

rz_subn:                        ; HL -= DE * B
        or a
        sbc hl,de
        djnz rz_subn
        ret

; HL (cos*zoom, up to 127*127) -> 8.8 texels: /32
rz_fix: ld b,5
.l:     sra h
        rr l
        djnz .l
        ret

neg_hl: xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

rz_ang:  db 0
rz_zoom: db 0
rz_du:   dw 0
rz_dv:   dw 0
rz_rdu:  dw 0
rz_rdv:  dw 0
rz_u:    dw 0
rz_v:    dw 0
rz_cnt:  db 0
