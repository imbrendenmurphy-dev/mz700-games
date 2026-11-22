; ---------------------------------------------------------------------------
; fx_tunnel.asm - textured tunnel in 40x50 half-block mode.
; TUNIDX: per cell two bytes (top pixel, bottom pixel), each
; angle/8 << 3 | depth & 7.  Rotation = add a multiple of 8
; (wraps for free), forward motion = pick one of 8 depth-shifted texture
; page pairs at TUNTEX (colour<<4, colour).  The middle of the tunnel is painted black afterwards.
; ---------------------------------------------------------------------------

tunnel_init:
        call gen_tuntex
        jp chunky_init

vortex_init:                    ; the same engine with a spiral texture
        call gen_vortex
        jp chunky_init

tunnel_frame:
        call wait_vbl
        call blit_attr
        ; rotation: sways back and forth
        ld a,(mtick)
        call sin_a
        sra a
        sra a
        ld b,a
        ld a,(mtick)
        srl a
        srl a
        add a,b
        add a,a
        add a,a
        add a,a                 ; *8
        ld b,a
        ; forward: texture page pair for depth (t/4) & 7
        ld a,(mtick)
        rrca
        and 0Eh                 ; 2 * ((t/4) & 7)
        add a,TUNTEX/256
        ld d,a
        ld hl,TUNIDX
        ld ix,ABUF
        ld a,25
.row:   ex af,af'
.n = 0
        DUP 40
        ld a,(hl)
        inc hl
        add a,b
        ld e,a
        ld a,(de)               ; top colour << 4
        ld c,a
        inc d
        ld a,(hl)
        inc hl
        add a,b
        ld e,a
        ld a,(de)               ; bottom colour
        dec d
        or c
        ld (ix+.n),a
.n = .n + 1
        EDUP
        ld a,b
        ld bc,40
        add ix,bc
        ld b,a
        ex af,af'
        dec a
        jp nz,.row
        ; the black hole in the middle
        ld hl,tun_hole
        xor a
.hole:  ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        bit 7,d
        ret nz
        ld (de),a
        jr .hole
