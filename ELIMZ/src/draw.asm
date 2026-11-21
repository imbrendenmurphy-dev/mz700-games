; =====================================================================
;  draw.asm - the dot view: plot, clipped lines, circles, present
;
;  PIX holds one nibble per cell (bit 0 top-left dot, 1 top-right,
;  2 bottom-left, 3 bottom-right), the same layout as glyphs F0h-FFh.
;  present() writes changed cells to VRAM and clears PIX.
; =====================================================================

; ---------------------------------------------------------------------
; plot: B = x (0..79), C = y (0..35).  Keeps BC, DE.  Clobbers A, HL.
; ---------------------------------------------------------------------
plot:
        ld h,high YLO
        ld l,c
        ld a,b
        srl a
        or (hl)
        inc h
        ld h,(hl)
        ld l,a
        ld a,b
        and 1
        inc a                       ; 1 = left dot, 2 = right dot
        bit 0,c
        jr z,.t
        add a,a
        add a,a
.t:     or (hl)
        ld (hl),a
        ret

; plot with a bounds check: HL = x, DE = y (signed words).  Keeps BC.
plot_clip:
        ld a,h
        or a
        ret nz
        ld a,l
        cp VW
        ret nc
        ld a,d
        or a
        ret nz
        ld a,e
        cp VH
        ret nc
        push bc
        ld b,l
        ld c,e
        call plot
        pop bc
        ret

; ---------------------------------------------------------------------
; present: copy changed cells of PIX to VRAM rows 1..18, clear PIX
; ---------------------------------------------------------------------
present:
        ld hl,PIX
        ld de,VIEW_VRAM
        ld c,18
.row:   ld b,40
        push hl
.cell:  ld a,(hl)
        ld (hl),0
        set 3,h
        cp (hl)
        jr nz,.chg
        res 3,h
        inc l
        inc de
        djnz .cell
        jr .next
.chg:   ld (hl),a
        res 3,h
        or 0F0h
        ld (de),a
        inc l
        inc de
        djnz .cell
.next:  call poll
        pop hl
        ld a,l
        add a,64
        ld l,a
        jr nc,$+3
        inc h
        dec c
        jr nz,.row
        ret

; force the next present() to rewrite every view cell
view_reset:
        ld hl,SHD
        ld de,SHD+1
        ld bc,18*64-1
        ld (hl),0FFh
        ldir
        ld hl,PIX
        ld de,PIX+1
        ld bc,18*64-1
        ld (hl),0
        ldir
        ld hl,RSHD
        ld de,RSHD+1
        ld bc,RAD_W*RAD_H-1
        ld (hl),0FFh
        ldir
        ret

; the sys.asm cls hook
shadow_reset    equ view_reset

; ---------------------------------------------------------------------
; line16: draw from (lx0,ly0) to (lx1,ly1), signed words, clipped to
; the 80 x 36 view (Cohen-Sutherland).
; ---------------------------------------------------------------------
line16:
        ld a,6
        ld (clipn),a
.loop:  ld hl,(lx0)
        ld de,(ly0)
        call outcode
        ld (oc0),a
        ld hl,(lx1)
        ld de,(ly1)
        call outcode
        ld (oc1),a
        ld b,a
        ld a,(oc0)
        or b
        jp z,line8                  ; both inside
        ld a,(oc0)
        and b
        ret nz                      ; both off the same side
        ld hl,clipn
        dec (hl)
        ret z
        ld a,(oc0)
        or a
        jr z,.e1
        ; clip endpoint 0 against endpoint 1
        ld hl,(lx0)
        ld (ex_),hl
        ld hl,(ly0)
        ld (ey_),hl
        ld hl,(lx1)
        ld (fx_),hl
        ld hl,(ly1)
        ld (fy_),hl
        call clip_end
        ld hl,(ex_)
        ld (lx0),hl
        ld hl,(ey_)
        ld (ly0),hl
        jr .loop
.e1:    ld hl,(lx1)
        ld (ex_),hl
        ld hl,(ly1)
        ld (ey_),hl
        ld hl,(lx0)
        ld (fx_),hl
        ld hl,(ly0)
        ld (fy_),hl
        ld a,(oc1)
        call clip_end
        ld hl,(ex_)
        ld (lx1),hl
        ld hl,(ey_)
        ld (ly1),hl
        jp .loop

; HL = x, DE = y -> A = outcode (1 left, 2 right, 4 above, 8 below)
outcode:
        ld c,0
        bit 7,h
        jr z,.a
        set 0,c
        jr .y
.a:     ld a,h
        or a
        jr nz,.r
        ld a,l
        cp VW
        jr c,.y
.r:     set 1,c
.y:     bit 7,d
        jr z,.b
        set 2,c
        jr .e
.b:     ld a,d
        or a
        jr nz,.bt
        ld a,e
        cp VH
        jr c,.e
.bt:    set 3,c
.e:     ld a,c
        ret

; move (ex_,ey_) along the line towards (fx_,fy_) onto the edge named
; by outcode A
clip_end:
        bit 2,a
        jr nz,.top
        bit 3,a
        jr nz,.bot
        bit 1,a
        jr nz,.right
        ; left: y = ey + (fy-ey)*(0-ex)/(fx-ex), x = 0
        ld hl,0
        jr .vert
.right: ld hl,VW-1
.vert:  push hl                     ; target x
        ld de,(ex_)
        or a
        sbc hl,de                   ; target - ex
        ex de,hl
        ld hl,(fx_)
        ld bc,(ex_)
        or a
        sbc hl,bc
        ld (md_c),hl                ; fx - ex
        ld hl,(fy_)
        ld bc,(ey_)
        or a
        sbc hl,bc
        ld b,h
        ld c,l                      ; fy - ey
        call muldiv
        ld de,(ey_)
        add hl,de
        ld (ey_),hl
        pop hl
        ld (ex_),hl
        ret
.top:   ld hl,0
        jr .horz
.bot:   ld hl,VH-1
.horz:  push hl                     ; target y
        ld de,(ey_)
        or a
        sbc hl,de
        ex de,hl                    ; DE = target - ey
        ld hl,(fy_)
        ld bc,(ey_)
        or a
        sbc hl,bc
        ld (md_c),hl                ; fy - ey
        ld hl,(fx_)
        ld bc,(ex_)
        or a
        sbc hl,bc
        ld b,h
        ld c,l                      ; fx - ex
        call muldiv
        ld de,(ex_)
        add hl,de
        ld (ex_),hl
        pop hl
        ld (ey_),hl
        ret

; ---------------------------------------------------------------------
; line8: Bresenham between the (in-range) low bytes of lx0,ly0,lx1,ly1
; ---------------------------------------------------------------------
line8:
        ld a,(lx0)
        ld b,a
        ld a,(ly0)
        ld c,a
        ld a,(lx1)
        sub b
        ld d,1
        jr nc,.dxp
        neg
        ld d,-1
.dxp:   ld (ldx),a
        ld a,d
        ld (lsx),a
        ld a,(ly1)
        sub c
        ld d,1
        jr nc,.dyp
        neg
        ld d,-1
.dyp:   ld (ldy),a
        ld a,d
        ld (lsy),a
        ld a,(ldx)
        ld e,a
        ld a,(ldy)
        cp e
        jr nc,.ymaj
        ; x major: count = dx+1, err = dx/2
        ld a,e
        inc a
        ld d,a
        srl e
.xl:    call plot
        dec d
        ret z
        ld a,(lsx)
        add a,b
        ld b,a
        ld a,(ldy)
        ld h,a
        ld a,e
        sub h
        ld e,a
        jp p,.xl
        ld a,(ldx)
        add a,e
        ld e,a
        ld a,(lsy)
        add a,c
        ld c,a
        jr .xl
.ymaj:  ld e,a                      ; E = dy
        inc a
        ld d,a
        srl e
.yl:    call plot
        dec d
        ret z
        ld a,(lsy)
        add a,c
        ld c,a
        ld a,(ldx)
        ld h,a
        ld a,e
        sub h
        ld e,a
        jp p,.yl
        ld a,(ldy)
        add a,e
        ld e,a
        ld a,(lsx)
        add a,b
        ld b,a
        jr .yl

; ---------------------------------------------------------------------
; circle: centre (ccx, ccy) signed words, radius A (1..127), clipped
; ---------------------------------------------------------------------
circle:
        ld (cr_x),a
        xor a
        ld (cr_y),a
        ld a,(cr_x)
        neg
        inc a
        ld l,a
        ld h,0FFh                   ; d = 1 - r
        ld (cr_d),hl
.l:     ld a,(cr_x)
        ld b,a
        ld a,(cr_y)
        ld c,a
        call .oct
        ld a,(cr_y)
        ld b,a
        ld a,(cr_x)
        ld c,a
        call .oct
        ld a,(cr_y)                 ; y++
        inc a
        ld (cr_y),a
        ld hl,(cr_d)
        bit 7,h
        jr nz,.dneg
        ld a,(cr_x)                 ; d += 2(y - x) + 1, x--
        dec a
        ld (cr_x),a
        ld a,(cr_y)
        ld c,a
        ld a,(cr_x)
        ld e,a
        ld d,0
        ld b,0
        or a
        push hl
        ld h,b
        ld l,c
        sbc hl,de
        add hl,hl
        inc hl
        pop de
        add hl,de
        ld (cr_d),hl
        jr .t
.dneg:  ld a,(cr_y)                 ; d += 2y + 1
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        inc hl
        add hl,de
        ld (cr_d),hl
.t:     ld a,(cr_x)
        ld b,a
        ld a,(cr_y)
        cp b
        jr c,.l
        jr z,.l
        ret
; four points (cx +- B, cy +- C)
.oct:   ld e,b
        ld d,0
        ld hl,(ccx)
        add hl,de
        ld (cpx1),hl
        ld hl,(ccx)
        or a
        sbc hl,de
        ld (cpx2),hl
        ld e,c
        ld hl,(ccy)
        add hl,de
        ld (cpy1),hl
        ld hl,(ccy)
        or a
        sbc hl,de
        ld (cpy2),hl
        ld hl,(cpx1)
        ld de,(cpy1)
        call plot_clip
        ld hl,(cpx2)
        ld de,(cpy1)
        call plot_clip
        ld hl,(cpx1)
        ld de,(cpy2)
        call plot_clip
        ld hl,(cpx2)
        ld de,(cpy2)
        jp plot_clip
