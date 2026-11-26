; =====================================================================
;  msg.asm - bars, the message queue and overlay text (part of hud.asm)
; =====================================================================

; a bar of B cells at DE: H out of L, colour C (half-cell steps)
bar:
        push de
        push bc
        ld a,l
        or a
        jr nz,$+3
        inc a
        ld (bar_max),a
        ld e,h
        ld d,0
        ld hl,0
        ld a,b
        add a,a
        ld b,a
.m:     add hl,de
        djnz .m
        ld a,(bar_max)
        ld e,a
        ld d,0
        ld b,0
.d:     or a
        sbc hl,de
        jr c,.dq
        inc b
        jr .d
.dq:    ld a,b
        ld (bar_q),a
        pop bc
        pop de
.c:     ld a,(bar_q)
        cp 2
        jr c,.half
        sub 2
        ld (bar_q),a
        ld a,43h
        call putc
        jr .nx
.half:  or a
        jr z,.empty
        xor a
        ld (bar_q),a
        ld a,0D0h
        call putc
        jr .nx
.empty: push bc
        ld c,BLUE<<4
        ld a,43h
        call putc
        pop bc
.nx:    inc de
        djnz .c
        ret

; ---------------------------------------------------------------------
; messages.  msg: HL = template (ASCII).  % monster name (IY), & item
; name (pk_it), # m_dmg, ~ m_num, @ the chosen spell.  Queued 4 deep;
; each shows at least MSG_MIN frames when others wait.
MSG_MIN         equ 14
MSG_DIM         equ 90
msg_mon:
msg_mon_iy:
msg_mon_num:
msg_mon_iy_num:
msg_item:
msg_num:
msg:
        push bc
        push de
        push hl
        push ix
        ld a,(mq_tail)
        call mq_slot
        ex de,hl                    ; DE = slot
        pop ix
        pop hl
        push hl
        push ix
        ld b,40
.l:     ld a,(hl)
        inc hl
        or a
        jr z,.pad
        cp '%'
        jr z,.mon
        cp '&'
        jr z,.item
        cp '#'
        jp z,.num8
        cp '~'
        jp z,.num16
        cp '@'
        jr z,.spell
        call .put
        jr .l
.pad:   ld a,b
        or a
        jr z,.done
        xor a
        ld (de),a
        inc de
        djnz .pad
.done:  ld a,(mq_tail)
        inc a
        and 3
        ld hl,mq_head
        cp (hl)
        jr nz,.ok
        ld a,(hl)                   ; full: drop the oldest
        inc a
        and 3
        ld (hl),a
        ld a,(mq_tail)
        inc a
        and 3
.ok:    ld (mq_tail),a
        pop ix
        pop hl
        pop de
        pop bc
        ret
.put:   push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        inc b
        dec b
        ret z
        ld (de),a
        inc de
        dec b
        ret
.mon:   push hl
        ld l,(iy+MT_NAME)
        ld h,(iy+MT_NAME+1)
        call .str
        pop hl
        jr .l
.item:  push hl
        push de
        ld hl,(pk_it)
        ld de,IT_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        call .str
        pop hl
        jr .l
.spell: push hl
        push de
        ld a,(curspell)
        ld l,a
        add a,a
        add a,l
        inc a
        ld l,a
        ld h,0
        ld de,SPELLS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        call .str
        pop hl
        jp .l
.num8:  push hl
        ld a,(m_dmg)
        ld l,a
        ld h,0
        call .num
        pop hl
        jp .l
.num16: push hl
        ld hl,(m_num)
        call .num
        pop hl
        jp .l
.str:   ld a,(hl)
        inc hl
        or a
        ret z
        call .put
        jr .str
.num:   push de
        push bc
        ld ix,numbuf
        ld de,10000
        call .dg
        ld de,1000
        call .dg
        ld de,100
        call .dg
        ld de,10
        call .dg
        ld (ix+0),l
        pop bc
        pop de
        ld hl,numbuf
        ld c,4
.z:     ld a,(hl)
        or a
        jr nz,.nd
        inc hl
        dec c
        jr nz,.z
.nd:    inc c
.np:    ld a,(hl)
        inc hl
        add a,'0'
        call .put
        dec c
        jr nz,.np
        ret
.dg:    xor a
.s:     or a
        sbc hl,de
        jr c,.u
        inc a
        jr .s
.u:     add hl,de
        ld (ix+0),a
        inc ix
        ret

; HL = message slot A.  Keeps DE.
mq_slot:
        and 3
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,mqueue
        add hl,de
        pop de
        ret

msg_reset:
        xor a
        ld (mq_head),a
        ld (mq_tail),a
        ld a,MSG_MIN
        ld (mq_age),a
        ret

; clear the message line now
msg_clear:
        call msg_reset
        ld b,HUDROW+4
        ld c,1
        ld a,HUD_ATTR
        jp clear_rows

; each frame: show the next message, dim old ones
msg_tick:
        ld a,(mq_age)
        cp 255
        jr z,.a
        inc a
        ld (mq_age),a
.a:     ld a,(mq_head)
        ld hl,mq_tail
        cp (hl)
        jr z,.idle
        ld a,(mq_age)
        cp MSG_MIN
        ret c
        ld a,(mq_head)
        call mq_slot
        ld de,VRAM+(HUDROW+4)*40
        ld bc,40
        ldir
        ld de,ARAM+(HUDROW+4)*40
        ld b,40
        ld a,HUD_ATTR
        call fill_attr
        ld a,(mq_head)
        inc a
        and 3
        ld (mq_head),a
        xor a
        ld (mq_age),a
        ret
.idle:  ld a,(mq_age)
        cp MSG_DIM
        ret nz
        ld de,ARAM+(HUDROW+4)*40
        ld b,40
        ld a,BLUE<<4
        jp fill_attr

; ---------------------------------------------------------------------
; overlay text over the view (stamped each frame while wanted):
; HL = ASCII, B = column, C = row, A = attr.  B ends after the text.
ov_text:
        ld (ot_attr),a
.l:     ld a,(hl)
        inc hl
        or a
        ret z
        cp 8
        jr c,.col
        push hl
        push bc
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        ld (ov_g),a
        ld a,c
        call mul40
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld de,OVA
        add hl,de
        ld a,(ot_attr)
        ld (hl),a
        ld a,h
        xor 0Ch
        ld h,a
        ld a,(ov_g)
        ld (hl),a
        pop bc
        ld a,b
        ld (ov_vx),a
        ld a,c
        ld (ov_vy),a
        call mark_ov
        pop hl
        inc b
        jr .l
.col:   rlca
        rlca
        rlca
        rlca
        ld e,a
        ld a,(ot_attr)
        and 8Fh
        or e
        ld (ot_attr),a
        jr .l

; a centred line of overlay text on view row C
ov_centre:
        push af
        call str_len
        ld a,40
        sub b
        srl a
        ld b,a
        pop af
        jr ov_text

; a box of overlay blanks: B, C = top-left, D x E, attr A
ov_box:
        ld (ot_attr),a
        push bc
        push de
        ld a,b
        add a,d
        dec a
        ld d,a
        ld a,c
        add a,e
        dec a
        ld e,a
        call mark_box
        pop de
        pop bc
.r:     push bc
        push de
.c:     push bc
        push de
        ld a,c
        call mul40
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld de,OVA
        add hl,de
        ld a,(ot_attr)
        ld (hl),a
        ld a,h
        xor 0Ch
        ld h,a
        ld (hl),0
        pop de
        pop bc
        inc b
        dec d
        jr nz,.c
        pop de
        pop bc
        inc c
        dec e
        jr nz,.r
        ret

; the zone's name over the view for a while, with its call
zone_banner:
        ld a,70
        ld (banner_t),a
        ld hl,TRK_ZONE
        jp trk_play

; stamped from overlays each frame
banner_draw:
        ld a,(banner_t)
        or a
        ret z
        dec a
        ld (banner_t),a
        jp z,mark_all
        call zone_def
        ld l,(ix+ZD_NAME)
        ld h,(ix+ZD_NAME+1)
        push hl
        call str_len
        ld a,b
        add a,4
        ld d,a
        ld a,40
        sub d
        srl a
        ld b,a
        ld c,3
        ld e,3
        ld a,BLUE*16+BLUE
        call ov_box
        pop hl
        ld c,4
        ld a,YELLOW*16+BLUE
        jp ov_centre
