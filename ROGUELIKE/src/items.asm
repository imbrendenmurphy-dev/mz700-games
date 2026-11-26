; =====================================================================
;  items.asm - things on the floor, picking up, potions and scrolls
;
;  ITEMS: 24 records of type, x, y, quantity for the current zone.
; =====================================================================
IT_G            equ 0
IT_A            equ 1
IT_KIND         equ 2
IT_VAL          equ 3
IT_PRICE        equ 4
IT_NAME         equ 5

; HL = type record of item A.  Keeps BC, DE.
itype:
        push de
        dec a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ITYPES
        add hl,de
        pop de
        ret

; item at (B, C)?  NZ, HL = its record.  Keeps BC, DE.
item_at:
        ld hl,ITEMS
        push de
        ld de,ITEMSZ
        ld a,NITEM
.f:     push af
        ld a,(hl)
        or a
        jr z,.n
        inc hl
        ld a,(hl)
        dec hl
        cp b
        jr nz,.n
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        cp c
        jr nz,.n
        pop af
        pop de
        or 1
        ret
.n:     add hl,de
        pop af
        dec a
        jr nz,.f
        pop de
        xor a
        ret

; add item D (quantity E) at (B, C).  Keeps BC, IX, IY.
add_item:
        ld hl,ITEMS
        ld a,NITEM
.f:     push af
        ld a,(hl)
        or a
        jr z,.put
        pop af
        inc hl
        inc hl
        inc hl
        inc hl
        dec a
        jr nz,.f
        ret
.put:   pop af
        ld (hl),d
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),e
        ret

; ---------------------------------------------------------------------
; the player steps onto an item: take it
pickup:
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call item_at
        ret z
        ld (pk_recp),hl
        ld a,(hl)
        ld (pk_type),a
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (pk_qty),a
        ld a,(pk_type)
        call itype
        ld (pk_it),hl
        inc hl
        inc hl
        ld a,(hl)                   ; kind
        inc hl
        ld e,(hl)                   ; value
        ld hl,pk_jump
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,e
        call jp_hl                  ; NZ = taken
        ret z
        ld hl,(pk_recp)
        ld (hl),0
        ret
jp_hl:  jp (hl)

pk_jump:
        dw pk_gold, pk_hpot, pk_mpot, pk_oil, pk_map, pk_tele, pk_bomb, pk_key, pk_sigil
        dw pk_book, pk_weapon, pk_armour

pk_gold:
        ld a,(pk_qty)
        ld e,a
        ld d,0
        ld hl,(gold)
        add hl,de
        ld (gold),hl
        ld (m_num),de
        ld hl,msg_gold
        call msg_num
        ld hl,SFX_GOLD
        ld a,1
        call sfx
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,P_GOLD
        ld e,4
        call burst
        jr pk_done
pk_hpot:
        ld hl,hpot
        jr pk_count
pk_mpot:
        ld hl,mpot
        jr pk_count
pk_map:
        ld hl,smap
        jr pk_count
pk_tele:
        ld hl,stele
        jr pk_count
pk_bomb:
        ld hl,bombs
pk_count:
        ld a,(hl)
        cp 9
        jr nc,pk_full
        inc (hl)
pk_found:
        ld hl,msg_found
        call msg_item
        ld hl,SFX_PICKUP
        ld a,1
        call sfx
pk_done:
        ld a,1
        ld (hud_dirty),a
        or a
        ret
pk_full:
        xor a
        ret
pk_oil:
        ld a,(oil)
        add a,60
        jr c,.m
        cp 200
        jr c,.s
.m:     ld a,200
.s:     ld (oil),a
        jr pk_found
pk_key:
        ld hl,keys
        inc (hl)
        jr pk_found
pk_sigil:
        ld hl,sigils
        or (hl)
        ld (hl),a
        ld hl,msg_sigil
        call msg_item
        ld hl,SFX_GATE
        ld a,3
        call sfx
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,P_MAGIC
        ld e,10
        call burst
        jr pk_done
pk_book:
        ld (pk_qty),a               ; the spell
        call zbit
        ld hl,spells
        or (hl)
        ld (hl),a
        ld a,(pk_qty)
        ld (curspell),a
        ld hl,msg_learn
        call msg_item
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
        jr pk_done
pk_weapon:
        ; better (more maximum damage)?
        ld e,a
        add a,a
        add a,a
        ld c,a
        ld b,0
        ld hl,WEAPONS+1
        add hl,bc
        ld b,(hl)                   ; its max
        ld a,(weapon)
        add a,a
        add a,a
        ld c,a
        push bc
        ld b,0
        ld hl,WEAPONS+1
        add hl,bc
        pop bc
        ld a,(hl)
        cp b
        jr nc,pk_sell
        ld a,e
        ld (weapon),a
        ld hl,msg_wield
        call msg_item
        ld hl,SFX_PICKUP
        ld a,1
        call sfx
        jp pk_done
pk_sell:
        ld hl,(pk_it)
        ld de,IT_PRICE
        add hl,de
        ld a,(hl)
        srl a
        add a,5
        ld e,a
        ld d,0
        ld hl,(gold)
        add hl,de
        ld (gold),hl
        ld (m_num),de
        ld hl,msg_sell
        call msg_item
        ld hl,SFX_GOLD
        ld a,1
        call sfx
        jp pk_done
pk_armour:
        ld e,a
        add a,a
        ld c,a
        ld b,0
        ld hl,ARMOURS
        add hl,bc
        ld a,(hl)                   ; its defence
        inc hl
        add a,(hl)                  ; (counting magic as worth having)
        ld b,a
        ld a,(armour)
        add a,a
        ld c,a
        push bc
        ld b,0
        ld hl,ARMOURS
        add hl,bc
        pop bc
        ld a,(hl)
        inc hl
        add a,(hl)
        cp b
        jr nc,pk_sell
        ld a,e
        ld (armour),a
        call calc_stats
        ld hl,msg_wear
        call msg_item
        ld hl,SFX_PICKUP
        ld a,1
        call sfx
        jp pk_done

; defence and MP maximum from the armour
calc_stats:
        ld a,(armour)
        add a,a
        ld e,a
        ld d,0
        ld hl,ARMOURS
        add hl,de
        ld a,(hl)
        ld (pdef),a
        inc hl
        ld b,(hl)
        ld a,(plevel)
        add a,a
        add a,6                     ; 8 + 2 per level
        add a,b
        ld (mpmax),a
        ld b,a
        ld a,(mp)
        cp b
        ret c
        ld a,b
        ld (mp),a
        ret

; ---------------------------------------------------------------------
; using things (each takes a turn when it works: NZ)
use_hpot:
        ld a,(hpot)
        or a
        jp z,deny_none
        dec a
        ld (hpot),a
        ld a,(hpmax)
        srl a
        add a,4
        call heal_by
        xor a
        ld (poison),a
        ld hl,msg_drink
        call msg
        ld hl,SFX_DRINK
        ld a,2
        call sfx
        jp use_done

use_mpot:
        ld a,(mpot)
        or a
        jp z,deny_none
        dec a
        ld (mpot),a
        ld a,(mp)
        add a,10
        ld b,a
        ld a,(mpmax)
        cp b
        jr c,$+3
        ld a,b
        ld (mp),a
        ld hl,msg_mana
        call msg
        ld hl,SFX_DRINK
        ld a,2
        call sfx
        ld a,P_MAGIC
        jr use_fx

use_map:
        ld a,(smap)
        or a
        jp z,deny_none
        dec a
        ld (smap),a
        ld hl,MAP                   ; every wall, floor and door is known
.l:     ld a,(hl)
        and 3Fh
        cp T_ROCK
        jr z,.n
        set 6,(hl)
.n:     inc hl
        ld a,h
        cp high SLIGHT
        jr c,.l
        ld hl,msg_mapped
        call msg
        ld hl,SFX_FLARE
        ld a,2
        call sfx
        jr use_done

use_tele:
        ld a,(stele)
        or a
        jp z,deny_none
        dec a
        ld (stele),a
.t:     ld b,62
        call rand_below
        inc a
        ld b,a
        push bc
        ld b,30
        call rand_below
        pop bc
        inc a
        ld c,a
        call tile_at
        cp T_FLOOR
        jr nz,.t
        call occupied
        jr nz,.t
        call teleport_to
        ld hl,msg_tele
        call msg
        jr use_done

heal_fx:
        ld a,P_HEAL
use_fx: ld e,8
        push af
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        pop af
        call burst
use_done:
        ld a,1
        ld (hud_dirty),a
        or a
        ret

deny_none:
        ld hl,msg_none
        call msg
deny:   ld hl,SFX_DENY
        ld a,1
        call sfx
        xor a
        ret

; heal A hit points (to the maximum)
heal_by:
        ld b,a
        ld a,(hp)
        add a,b
        jr c,.m
        ld b,a
        ld a,(hpmax)
        cp b
        jr c,.m
        ld a,b
        ld (hp),a
        jr heal_fx
.m:     ld a,(hpmax)
        ld (hp),a
        jr heal_fx

; move the player to (B, C) with a swirl at both ends
teleport_to:
        push bc
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,P_MAGIC
        ld e,8
        call burst
        pop bc
        ld a,b
        ld (px),a
        ld a,c
        ld (py),a
        ld a,P_MAGIC
        ld e,8
        call burst
        call set_pmap
        ld hl,SFX_BLINK
        ld a,2
        call sfx
        ld a,1
        ld (need_fov),a
        ret

; open a chest (bumped at B, C): its treasure falls at the player's feet
open_chest:
        call map_addr
        ld a,T_CHESTO
        call set_tile
        push bc
        ld a,P_GOLD
        ld e,6
        call burst
        ld hl,SFX_CHEST
        ld a,2
        call sfx
        pop bc
        ; a mimic?  (handled by the monster: it sits on the floor instead)
        call zone_def
        ld b,5
        call rand_below
        cp 4
        jr c,.loot
        ld d,I_HPOTION
        jr .give
.loot:  ld e,a
        ld d,0
        add ix,de
        ld d,(ix+ZD_LOOT)
.give:  call gold_qty
        ld a,e
        add a,e
        ld e,a                      ; chests hold twice the gold
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call add_item
        call pickup
        ld a,1
        ret
