; ---------------------------------------------------------------------------
; fx_dots.asm - 64 morphing 3D dots in 80x50 (dotted quarter blocks F0h-FFh:
; bit 0 top left, 1 top right, 2 bottom left, 3 bottom right).
; Only the cells that change are written to VRAM.
; ---------------------------------------------------------------------------

NDOTS   equ 64
TROT    equ 0100h           ; rotation tables 0100-02FF

dots_init:
        call gen_proj
        call cls_black
        ld hl,DOTM
        xor a
        call fill_buf
        ld hl,DOTA
        xor a
        call fill_buf
        ; start from a flat disc so the first shape grows out of it
        ld hl,DOTSHP+NDOTS*3*(NSHAPES-1)
        ld de,dot_cur
        ld bc,NDOTS*3
        ldir
        xor a
        ld (dt_shape),a
        ld (dt_nold),a
        dec a
        ld (dt_lastshape),a
        ld hl,dots_title
        ld de,VCHR+1*40+11
        ld a,50h
        call print_at
        ret

dots_frame:
        call wait_vbl
        ; shape: a new one every 2 bars
        ld a,(mus_pos)
        sub BAR_DOTS
        srl a
.mod:   cp NSHAPES-1
        jr c,.m1
        sub NSHAPES-1
        jr .mod
.m1:    ld (dt_shape),a
        ld hl,dt_lastshape
        cp (hl)
        call nz,dt_newshape
        call dt_morph
        call dt_angles
        call dt_erase
        call dt_project
        call dt_present
        ret

dt_newshape:
        ld (hl),a
        ; print the name: 20 chars per name
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *20
        ld de,dots_names
        add hl,de
        ld de,VCHR+23*40+10
        ld a,70h
        jp print_at

; cur += (target - cur) / 8, at least one step
dt_morph:
        ld a,(dt_shape)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *192
        ld de,DOTSHP
        add hl,de
        ld de,dot_cur
        ld b,NDOTS*3
.l:     ld a,(hl)
        ex de,hl
        sub (hl)                ; diff = target - cur
        jr z,.n
        ld c,a
        sra a
        sra a
        sra a
        jr nz,.s
        ld a,c                  ; small: step by one
        or a
        ld a,1
        jp p,.s
        ld a,-1
.s:     add a,(hl)
        ld (hl),a
.n:     ex de,hl
        inc hl
        inc de
        djnz .l
        ret

dt_angles:
        ld a,(mtick)
        ld (dt_ay),a
        ld a,(mtick)
        add a,a
        call sin_a
        sra a
        sra a
        ld (dt_ax),a
        ld a,(dt_ay)
        call cos_a
        ld hl,TROT              ; cos y
        call dt_mktab
        ld a,(dt_ay)
        call sin_a
        ld hl,TROT+80h          ; sin y
        call dt_mktab
        ld a,(dt_ax)
        call cos_a
        ld hl,TROT+100h         ; cos x
        call dt_mktab
        ld a,(dt_ax)
        call sin_a
        ld hl,TROT+180h         ; sin x
        ; fall through

; table at HL (128 bytes): T[v & 7Fh] = v * A / 128 for v = -64..63
dt_mktab:
        ld b,h
        ld c,l
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        add hl,hl
        ex de,hl                ; DE = 2 * sine
        ld hl,0
        DUP 64
        ld a,h
        ld (bc),a
        inc c
        add hl,de
        EDUP
        ld a,c
        add a,63
        ld c,a
        ld hl,0
        DUP 64
        or a
        sbc hl,de
        ld a,h
        ld (bc),a
        dec c
        EDUP
        ret

; clear last frame's cells in the mask buffer (they stay in the old list
; so present() rewrites them)
dt_erase:
        ld a,(dt_nold)
        or a
        ret z
        ld b,a
        ld hl,dt_old
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,DOTM
        add hl,de
        ld (hl),0
        ld hl,DOTA
        add hl,de
        ld (hl),0
        pop hl
        djnz .l
        ret

dt_project:
        ld ix,dot_cur
        ld hl,dt_new
        ld (dt_np),hl
        xor a
        ld (dt_nnew),a
        ld b,NDOTS
.pt:    push bc
        push bc                 ; balances the pop at .clip
        ld a,(ix+0)
        and 7Fh
        ld e,a                  ; x
        ld a,(ix+2)
        and 7Fh
        ld d,a                  ; z
        ld h,TROT/256           ; cos y at +0, sin y at +80h
        ld l,e
        ld a,(hl)
        ld l,d
        set 7,l
        add a,(hl)
        ld (dt_x1),a            ; x1 = x cy + z sy
        ld l,d
        ld a,(hl)
        ld l,e
        set 7,l
        sub (hl)
        and 7Fh
        ld d,a                  ; z1 = z cy - x sy
        ld a,(ix+1)
        and 7Fh
        ld e,a                  ; y
        inc h                   ; cos x at +0, sin x at +80h
        ld l,e
        ld a,(hl)
        ld l,d
        set 7,l
        sub (hl)
        ld (dt_y2),a            ; y2 = y cx - z1 sx
        ld l,e
        set 7,l
        ld a,(hl)
        ld l,d
        res 7,l
        add a,(hl)
        ld (dt_z2),a            ; z2 = y sx + z1 cx
        ; perspective: PROJT row (z2+64)/8, 128 bytes per row
        add a,64
        and 7Fh
        ld c,a
        rrca
        rrca
        rrca
        rrca
        and 7
        add a,PROJT/256
        ld h,a
        ld a,c
        and 8
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(dt_x1)
        and 7Fh
        or c
        ld l,a
        ld a,(hl)
        add a,40
        cp 80
        jr nc,.clip
        ld (dt_px),a
        ld a,(dt_y2)
        and 7Fh
        or c
        ld l,a
        ld a,(hl)
        add a,25
        cp 46                   ; rows 2-22 only: keep the captions
        jr nc,.clip
        cp 4
        jr c,.clip
        ; cell = (py>>1)*40 + (px>>1), bit = (py&1)*2 + (px&1)
        ld c,a                  ; py
        srl a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *40
        ld a,(dt_px)
        ld b,a
        srl a
        ld e,a
        ld d,0
        add hl,de
        ex de,hl                ; DE = cell offset
        ld a,c
        and 1
        add a,a
        ld c,a
        ld a,b
        and 1
        or c                    ; 0..3
        ld b,a
        ld a,1
        inc b
.sh:    dec b
        jr z,.sh2
        add a,a
        jr .sh
.sh2:   ld hl,DOTM
        add hl,de
        or (hl)
        ld (hl),a
        ; colour by depth: nearer = brighter
        ld a,(dt_z2)
        add a,64
        and 7Fh
        rrca
        rrca
        rrca
        rrca
        and 7
        ld c,a
        ld b,0
        ld hl,dot_depthcol
        add hl,bc
        ld a,(hl)
        ld hl,DOTA
        add hl,de
        cp (hl)
        jr c,.nc
        ld (hl),a
.nc:    ; remember the cell
        ld hl,(dt_np)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (dt_np),hl
        ld hl,dt_nnew
        inc (hl)
.clip:  pop de
        ld de,3
        add ix,de
        pop bc
        dec b
        jp nz,.pt
        ret

; write old + new cells to VRAM, then new becomes old
dt_present:
        ld a,(dt_nold)
        ld hl,dt_old
        call .list
        ld a,(dt_nnew)
        ld hl,dt_new
        call .list
        ld hl,dt_new
        ld de,dt_old
        ld bc,NDOTS*2
        ldir
        ld a,(dt_nnew)
        ld (dt_nold),a
        ret
.list:  or a
        ret z
        ld b,a
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,DOTM
        add hl,de
        ld a,(hl)
        or a
        jr z,.e
        or 0F0h
.e:     ld hl,VCHR
        add hl,de
        ld (hl),a
        ld hl,DOTA
        add hl,de
        ld a,(hl)
        ld hl,VATR
        add hl,de
        ld (hl),a
        pop hl
        djnz .l
        ret

dot_depthcol: db 70h, 70h, 70h, 50h, 50h, 10h, 10h, 10h

dt_shape:     db 0
dt_lastshape: db 0
dt_ax: db 0
dt_ay: db 0
dt_sx: db 0
dt_cx: db 0
dt_sy: db 0
dt_cy: db 0
dt_x1: db 0
dt_z1: db 0
dt_y2: db 0
dt_z2: db 0
dt_px: db 0
dt_nold: db 0
dt_nnew: db 0
dt_np:  dw 0
dt_old: ds NDOTS*2
dt_new: ds NDOTS*2
dot_cur: ds NDOTS*3
