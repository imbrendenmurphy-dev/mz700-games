; =====================================================================
;  hud.asm - the status rows (20-24), messages, overlay text
;
;  row 20  keys, the zone's name, the sigils
;  row 21  HP and MP bars, level
;  row 22  lantern oil, gold, potions / bombs / scrolls
;  row 23  the spells (1-6), the chosen spell, the weapon
;  row 24  messages (queued, each shown for a moment, then dimmed)
; =====================================================================
HUDROW          equ 20
HUD_ATTR        equ (WHITE<<4)+BLACK
HUD_LBL         equ (CYAN<<4)+BLACK

hud_frame:
        ld b,HUDROW
        ld c,5
        ld a,HUD_ATTR
        call clear_rows
        ; the separator line
        ld a,HUDROW
        call row_addr
        ex de,hl
        ld b,40
        ld a,034h
        ld c,BLUE<<4
        call fill_cells
        ; labels
        ld bc,0*256+HUDROW+1
        ld a,HUD_LBL
        ld hl,s_hp
        call print_at
        ld bc,18*256+HUDROW+1
        ld a,HUD_LBL
        ld hl,s_mp
        call print_at
        ld bc,33*256+HUDROW+1
        ld a,HUD_LBL
        ld hl,s_lv
        call print_at
        ld bc,0*256+HUDROW+2
        ld a,HUD_LBL
        ld hl,s_oil
        call print_at
        ld bc,13*256+HUDROW+2
        ld a,YELLOW*16
        ld hl,s_gold
        call print_at
        call msg_reset
        ret

s_hp:   db "HP",0
s_mp:   db "MP",0
s_lv:   db "LV",0
s_oil:  db "OIL",0
s_gold: db "$",0

; all the values
hud_draw:
        xor a
        ld (hud_dirty),a
        ; row 20: keys, zone name, sigils
        ld a,HUDROW
        call row_addr
        ex de,hl
        push de
        ld b,40
        ld a,034h
        ld c,BLUE<<4
        call fill_cells
        pop de
        ld a,(keys)
        or a
        jr z,.nk
        ld a,0FEh                   ; key glyph (bank 1)
        ld c,80h+(YELLOW<<4)
        call putc
        inc de
        ld a,(keys)
        add a,20h
        ld c,YELLOW<<4
        call putc
.nk:    call zone_def
        ld l,(ix+ZD_NAME)
        ld h,(ix+ZD_NAME+1)
        push hl
        call str_len
        ld a,40
        sub b
        srl a
        dec a
        ld b,a
        ld c,HUDROW
        call vaddr
        xor a
        ld c,0
        call putc
        inc de
        pop hl
        ld c,YELLOW*16
        call print
        xor a
        ld c,0
        call putc
        ; sigils at the right
        ld de,VRAM+HUDROW*40+36
        ld a,(sigils)
        ld b,3
        ld hl,sig_cols
.sg:    push af
        rrca
        ld (sg_bits),a
        ld a,083h
        ld c,(hl)
        jr c,.sgo
        ld a,0F1h
        ld c,BLUE<<4
.sgo:   call putc
        inc de
        inc hl
        pop af
        ld a,(sg_bits)
        djnz .sg
        ; row 21: HP
        ld de,VRAM+(HUDROW+1)*40+3
        ld a,(hp)
        ld l,a
        ld h,0
        ld b,3
        ld c,HUD_ATTR
        call print_num
        ld a,2Dh                    ; /
        call putc
        inc de
        ld a,(hpmax)
        ld l,a
        ld h,0
        ld b,3
        call print_num_left
        ld de,VRAM+(HUDROW+1)*40+11
        ld a,(hp)
        ld h,a
        ld a,(hpmax)
        ld l,a
        ld b,6
        call hp_colour
        call bar
        ; MP
        ld de,VRAM+(HUDROW+1)*40+21
        ld a,(mp)
        ld l,a
        ld h,0
        ld b,2
        ld c,HUD_ATTR
        call print_num
        ld a,2Dh
        call putc
        inc de
        ld a,(mpmax)
        ld l,a
        ld h,0
        ld b,2
        call print_num_left
        ld de,VRAM+(HUDROW+1)*40+27
        ld a,(mp)
        ld h,a
        ld a,(mpmax)
        ld l,a
        ld b,5
        ld c,MAGENTA<<4
        call bar
        ld de,VRAM+(HUDROW+1)*40+36
        ld a,(plevel)
        ld l,a
        ld h,0
        ld b,2
        ld c,HUD_ATTR
        call print_num
        ; row 22: oil
        ld de,VRAM+(HUDROW+2)*40+4
        ld a,(oil)
        ld l,a
        ld h,0
        ld b,3
        ld c,HUD_ATTR
        ld a,(oil)
        cp 21
        jr nc,$+4
        ld c,RED<<4
        call print_num
        ld de,VRAM+(HUDROW+2)*40+8
        ld a,(oil)
        ld h,a
        ld l,200
        ld b,4
        ld c,YELLOW<<4
        call bar
        ld de,VRAM+(HUDROW+2)*40+14
        ld hl,(gold)
        ld b,5
        ld c,YELLOW<<4
        call print_num_left
        ; counts: H M B T R
        ld de,VRAM+(HUDROW+2)*40+21
        ld hl,cnt_tab
        ld b,5
.ct:    push bc
        ld a,(hl)
        inc hl
        ld c,(hl)                   ; colour
        inc hl
        push hl
        call putc
        inc de
        pop hl
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)                   ; the count
        add a,20h
        ld c,HUD_ATTR
        call putc
        inc de
        xor a
        call putc
        inc de
        pop hl
        inc hl
        inc hl
        pop bc
        djnz .ct
        ; row 23: spells
        ld de,VRAM+(HUDROW+3)*40
        ld b,0
.sp:    push bc
        ld a,b
        call zbit
        pop bc
        push bc
        ld hl,spells
        and (hl)
        ld c,BLUE<<4
        jr z,.spc
        ld hl,spell_cols
        ld a,l
        add a,b
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)
        ld a,(curspell)
        cp b
        jr nz,.spc
        ld a,c                      ; the chosen one: inverse
        rrca
        rrca
        rrca
        rrca
        and 07h
        ld c,a
.spc:   ld a,b
        add a,21h
        call putc
        inc de
        pop bc
        inc b
        ld a,b
        cp NSPELLS
        jr c,.sp
        xor a
        call putc
        inc de
        ld a,(curspell)
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        push de
        ld de,SPELLS
        add hl,de
        pop de
        ld a,(hl)                   ; MP cost
        ld (sp_cost),a
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,HUD_ATTR
        push de
        call print
        xor a
        call putc
        inc de
        ld a,(sp_cost)
        ld l,a
        ld h,0
        ld b,1
        ld c,MAGENTA<<4
        call print_num
        ld hl,s_mpcost
        call print
        ; blank to the weapon
        pop hl                      ; start of the name
        ld a,l
        add a,17
        ld l,a
        jr nc,$+3
        inc h
.bl:    ld a,e
        cp l
        jr z,.wn
        xor a
        call putc
        inc de
        jr .bl
.wn:    ; the weapon, right-aligned in 40 - 23 - 17 ...
        ld de,VRAM+(HUDROW+3)*40+28
        ld b,12
        xor a
        ld c,0
        call fill_cells
        ld a,(weapon)
        add a,I_DAGGER
        call itype
        ld de,IT_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call str_len
        ld a,40
        sub b
        ld b,a
        ld c,HUDROW+3
        call vaddr
        ld c,WHITE*16
        jp print

s_mpcost: db "MP",0
sig_cols: db RED*16+80h, CYAN*16+80h, MAGENTA*16+80h
spell_cols:
        db YELLOW<<4, CYAN<<4, WHITE<<4, GREEN<<4, MAGENTA<<4, WHITE<<4
cnt_tab:
        db 08h,RED<<4
        dw hpot
        db 0Dh,MAGENTA<<4
        dw mpot
        db 02h,RED<<4
        dw bombs
        db 14h,CYAN<<4
        dw stele
        db 12h,WHITE<<4
        dw smap

; print HL left-aligned in a field of B (blank padded): DE, attr C
print_num_left:
        push bc
        ld a,b
        ld (pnl_w),a
        push de
        ld b,1
        call print_num
        pop hl
        ; chars printed = E - L
        ld a,e
        sub l
        ld b,a
        ld a,(pnl_w)
        sub b
        pop bc
        ret z
        ret c
        ld b,a
.p:     xor a
        call putc
        inc de
        djnz .p
        ret

; C = the colour for an HP bar of H out of L
hp_colour:
        ld c,GREEN<<4
        ld a,l
        srl a
        cp h
        ret c
        ld c,YELLOW<<4
        srl a
        cp h
        ret c
        ld c,RED<<4
        ret

        include "msg.asm"
