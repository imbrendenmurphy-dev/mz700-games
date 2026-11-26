; =====================================================================
;  npc.asm - the folk of the deep: talk, gifts, shops
;
;  Dialogue is drawn as overlay text over the view (dlg_draw), so the
;  torchlight keeps flickering behind it.  A text block is lines of
;  ASCII, each 0-terminated, ended by an empty line.
; =====================================================================
DLG_X           equ 2
DLG_Y           equ 2
DLG_W           equ 36

; talk to monster IX (type IY)
npc_talk:
        ld hl,SFX_TALK
        ld a,1
        call sfx
        ld a,(ix+MO_TYPE)
        cp M_TRADER
        jp z,shop_trader
        cp M_SMITH
        jp z,shop_smith
        bit 2,(ix+MO_FL)
        set 2,(ix+MO_FL)
        jr nz,.again
        ; the first meeting
        cp M_HERMIT
        jr nz,.n1
        ld a,SP_HEAL
        call learn
        ld hl,t_hermit1
        jr .say
.n1:    cp M_SAGE
        jr nz,.n2
        ld a,SP_FROST
        call learn
        ld hl,t_sage1
        jr .say
.n2:    cp M_GHOST
        jr nz,.n3
        ld a,SP_BLINK
        call learn
        ld hl,t_ghost1
        jr .say
.n3:    cp M_ORACLE
        jr nz,.n4
        ld a,SP_LIGHTNING
        call learn
        call restore
        ld hl,t_oracle1
        jr .say
.n4:    call restore                ; the seer
        ld hl,t_seer1
        jr .say
.again: cp M_HERMIT
        ld hl,t_hermit2
        jr z,.say
        cp M_SAGE
        ld hl,t_sage2
        jr z,.say
        cp M_GHOST
        ld hl,t_ghost2
        jr z,.say
        cp M_ORACLE
        jr nz,.s2
        call restore
        ld hl,t_oracle2
        jr .say
.s2:    call restore
        ld hl,t_seer2
.say:   call dialogue
        xor a                       ; talking takes no turn
        ret

; learn spell A (silently if known)
learn:
        ld (pk_qty),a
        call zbit
        ld hl,spells
        or (hl)
        ld (hl),a
        ld a,(pk_qty)
        ld (curspell),a
        ld hl,SFX_LEVEL
        ld a,3
        call sfx
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,P_MAGIC
        ld e,10
        call burst
        ld a,1
        ld (hud_dirty),a
        ret

; full health and magic
restore:
        ld a,(hpmax)
        ld (hp),a
        ld a,(mpmax)
        ld (mp),a
        xor a
        ld (poison),a
        ld a,1
        ld (hud_dirty),a
        ld hl,SFX_HEAL
        ld a,2
        jp sfx

; show text block HL (title: the speaker, IY) until a key
dialogue:
        ld (dlg_text),hl
        ld a,1
        ld (dlg_on),a
        ld (dlg_dirty),a
        ld a,(demo)
        or a
        jr nz,.demo
        call wait_release_play
.w:     call frame
        call anyhit
        jr z,.w
        call wait_release_play
        jr .x
.demo:  ld a,90
.dw:    push af
        call frame
        pop af
        dec a
        jr nz,.dw
.x:     xor a
        ld (dlg_on),a
        jp mark_all

; the box and its lines (from overlays)
dlg_draw:
        ; count lines
        ld hl,(dlg_text)
        ld e,0
.c:     ld a,(hl)
        or a
        jr z,.cn
.cs:    ld a,(hl)
        inc hl
        or a
        jr nz,.cs
        inc e
        jr .c
.cn:    ld a,e
        add a,4
        ld e,a
        ld d,DLG_W
        ld bc,DLG_X*256+DLG_Y
        ld a,BLUE*16+BLUE
        call ov_box
        ; the speaker
        ld l,(iy+MT_NAME)
        ld h,(iy+MT_NAME+1)
        ld bc,(DLG_X+2)*256+DLG_Y+1
        ld a,YELLOW*16+BLUE
        call ov_text
        ; the lines
        ld hl,(dlg_text)
        ld c,DLG_Y+2
.l:     ld a,(hl)
        or a
        ret z
        ld b,DLG_X+2
        push bc
        ld a,WHITE*16+BLUE
        call ov_text
        pop bc
        inc c
        jr .l

; ---------------------------------------------------------------------
; shops: up to 5 wares of (item, price); keys 1-5 buy, SPACE leaves
shop_trader:
        ld hl,wares_trader
        ld de,t_trader
        jr shop
shop_smith:
        ld hl,wares_smith
        ld de,t_smith
shop:
        ld (shop_wares),hl
        ld (shop_greet),de
        ld a,(demo)
        or a
        jr z,.s
        ex de,hl
        call dialogue
        xor a
        ret
.s:     call build_shop_text
        ld hl,shop_buf
        ld (dlg_text),hl
        ld a,1
        ld (dlg_on),a
        ld (dlg_dirty),a
        call wait_release_play
.w:     call frame
        call scan_keys
        ld a,KC_SPACE
        call key_hit
        jr nz,.x
        ld a,KC_BREAK
        call key_hit
        jr nz,.x
        ld b,0
        ld hl,spell_keys
.k:     ld a,(hl)
        call key_hit
        jr nz,.buy
        inc hl
        inc b
        ld a,b
        cp 5
        jr c,.k
        jr .w
.buy:   call kb_clear
        call buy_ware
        call build_shop_text
        ld a,1
        ld (dlg_dirty),a
        jr .w
.x:     xor a
        ld (dlg_on),a
        call mark_all
        call wait_release_play
        xor a
        ret

; buy ware B
buy_ware:
        ld a,b
        add a,a
        ld e,a
        ld d,0
        ld hl,(shop_wares)
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld (bw_item),a
        inc hl
        ld e,(hl)
        ld d,0
        ld (bw_price),de
        ld hl,(gold)
        or a
        sbc hl,de
        jr c,.poor
        ld (gold),hl
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,(bw_item)
        ld d,a
        ld e,1
        call add_item
        call pickup
        ; refused (full)?  then a refund
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call item_at
        jr z,.ok
        ld (hl),0
        ld hl,(gold)
        ld de,(bw_price)
        add hl,de
        ld (gold),hl
        ld hl,msg_full
        call msg
        jp deny
.ok:    ld hl,SFX_GOLD
        ld a,2
        call sfx
        ld a,1
        ld (hud_dirty),a
        ret
.poor:  ld hl,msg_poor
        call msg
        jp deny

; shop_buf: the greeting, then "n  NAME ... price" lines, then help
build_shop_text:
        ld de,shop_buf
        ld hl,(shop_greet)
.g:     ld a,(hl)                   ; copy the greeting's lines
        or a
        jr z,.gd
.gl:    ld a,(hl)
        ldi
        or a
        jr nz,.gl
        jr .g
.gd:    ld a,' '                    ; a blank line
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld hl,(shop_wares)
        ld c,'1'
.w:     ld a,(hl)
        or a
        jr z,.wd
        push hl
        push bc
        ld a,c
        ld (de),a
        inc de
        ld a,' '
        ld (de),a
        inc de
        ld a,(hl)
        inc hl
        ld b,(hl)                   ; price
        push bc
        call itype
        push de
        ld de,IT_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ld b,20
.n:     ld a,(hl)
        or a
        jr z,.np
        ld (de),a
        inc hl
        inc de
        dec b
        jr .n
.np:    ld a,'.'
        ld (de),a
        inc de
        djnz .np
        pop bc
        ld a,b                      ; price, 3 digits
        ld l,a
        ld h,0
        ld b,'0'-1
.h:     inc b
        push de
        ld de,100
        or a
        sbc hl,de
        pop de
        jr nc,.h
        push de
        ld de,100
        add hl,de
        pop de
        ld a,b
        ld (de),a
        inc de
        ld a,l
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,b
        ld (de),a
        inc de
        pop af
        ld (de),a
        inc de
        ld a,' '
        ld (de),a
        inc de
        ld a,'$'
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        pop bc
        pop hl
        inc hl
        inc hl
        inc c
        jr .w
.wd:    ld hl,t_shophelp
.c2:    ld a,(hl)
        ldi
        or a
        jr nz,.c2
        xor a
        ld (de),a
        ret

wares_trader:
        db I_HPOTION,20, I_MPOTION,20, I_OIL,12, I_BOMB,25, I_TELESCROLL,25, 0
wares_smith:
        db I_SWORD,30, I_SPEAR,70, I_WARHAMMER,110, I_SCALE,50, I_CHAIN,80, 0
