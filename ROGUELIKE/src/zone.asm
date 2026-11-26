; =====================================================================
;  zone.asm - moving between zones; the zone's tile looks
;
;  The current zone lives at MAP (and its items in ITEMS); the others
;  are kept in ZSTORE (2K each) and the item stores in the gaps between
;  the view buffers.  A zone is generated the first time it is entered.
; =====================================================================

;  zones 2-7 are kept in the RAM behind VRAM and I/O (D000-FFFF), paged
;  in with OUT (E1h) just for the copy and out again with OUT (E3h).

; HL = zone A's map store; carry if it is in banked RAM
zmap_addr:
        cp 2
        jr nc,.hi
        add a,a
        add a,a
        add a,a
        add a,high ZSTORE
        ld h,a
        ld l,0
        or a
        ret
.hi:    sub 2
        add a,a
        add a,a
        add a,a
        add a,high ZSTORE_HI
        ld h,a
        ld l,0
        scf
        ret

; HL = zone A's creature and item store
zent_addr:
        ld hl,ESTORE
        or a
        ret z
        ld de,ESIZE
.m:     add hl,de
        dec a
        jr nz,.m
        ret

save_zone:
        ld a,(zone)
        call zmap_addr
        ex de,hl
        ld hl,MAP
        ld bc,2048
        jr nc,.lo
        out (0E1h),a                ; RAM at D000-FFFF
.lo:    ldir
        out (0E3h),a                ; VRAM and I/O back
        ld a,(zone)
        call zent_addr
        ex de,hl
        ld hl,MONS
        ld bc,ESIZE
        ldir
        ret

load_zone:
        ld a,(zone)
        call zmap_addr
        ld de,MAP
        ld bc,2048
        jr nc,.lo
        out (0E1h),a
.lo:    ldir
        out (0E3h),a
        ld a,(zone)
        call zent_addr
        ld de,MONS
        ld bc,ESIZE
        ldir
        ret

; build the tile look page for the zone's theme
build_tlp:
        ld hl,TILEDEF
        ld de,TLP
        ld bc,256
        ldir
        call zone_def
        ld a,(ix+ZD_THEME)
        ld l,a
        add a,a
        add a,a
        add a,l
        add a,a                     ; *10
        ld e,a
        ld d,0
        ld hl,THEMES
        add hl,de
        ; wall (tiles 0 and 1)
        ld a,(hl)
        ld (TLP+T_WALL),a
        ld (TLP+64+T_WALL),a
        ld (TLP+T_ROCK),a
        ld (TLP+64+T_ROCK),a
        inc hl
        ld a,(hl)
        ld (TLP+128+T_WALL),a
        ld (TLP+128+T_ROCK),a
        inc hl
        ld a,(hl)
        ld (TLP+192+T_WALL),a
        ld (TLP+192+T_ROCK),a
        inc hl
        ; floor
        ld a,(hl)
        ld (TLP+T_FLOOR),a
        ld (TLP+T_TRAP),a
        inc hl
        ld a,(hl)
        ld (TLP+64+T_FLOOR),a
        ld (TLP+64+T_TRAP),a
        inc hl
        ld a,(hl)
        ld (TLP+128+T_FLOOR),a
        ld (TLP+128+T_TRAP),a
        inc hl
        ld a,(hl)
        ld (TLP+192+T_FLOOR),a
        ld (TLP+192+T_TRAP),a
        inc hl
        ; floor 2
        ld a,(hl)
        ld (TLP+T_FLOOR2),a
        ld (TLP+64+T_FLOOR2),a
        inc hl
        ld a,(hl)
        ld (TLP+128+T_FLOOR2),a
        inc hl
        ld a,(hl)
        ld (TLP+192+T_FLOOR2),a
        ret

; ---------------------------------------------------------------------
; go to zone A (from the current one, or a new game when newgame is set)
enter_zone:
        ld (zone_new),a
        xor a
        ld (bot_zturns),a
        ld a,(zone_new)
        ld a,(zone_live)
        or a
        call nz,save_zone
        ld a,(zone)
        ld (zone_from),a
        ld a,(zone_new)
        ld (zone),a
        call set_monbase
        call clear_effects
        ; generated before?
        ld a,(zone)
        call zbit
        ld hl,zgen
        and (hl)
        jr nz,.old
        ld a,(zone)
        call zbit
        or (hl)
        ld (hl),a
        ld hl,ITEMS
        ld b,NITEM*ITEMSZ
.ci:    ld (hl),0
        inc hl
        djnz .ci
        call mon_clear
        call gen_zone
        jr .lit
.old:   call load_zone
.lit:   ld a,1
        ld (zone_live),a
        call build_tlp
        call beam_trace
        call relight
        ; the player arrives beside the exit back to where they came from
        ld a,(newgame)
        or a
        jr nz,.placed
        ld a,(zone)
        call exits_addr
        ld a,(zone_from)
        ld d,a
        ld e,3
.f:     ld a,(hl)
        cp 0FFh
        jr z,.fn
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        cp d
        jr z,.found
.fn:    inc hl
        inc hl
        inc hl
        dec e
        jr nz,.f
        ld a,(zone)                 ; no way back: by the first exit
        call exits_addr
.found: ld b,(hl)
        inc hl
        ld c,(hl)
        call arrive_near
.placed:
        ld a,(zone)
        call zbit
        ld hl,zvisit
        or (hl)
        ld (hl),a
        jp set_pmap

; A = 1 << A
zbit:
        push bc
        ld b,a
        inc b
        xor a
        scf
.s:     rla
        djnz .s
        pop bc
        ret

; put the player on a free cell next to (B, C), or on it
arrive_near:
        ld e,0
.d:     push bc
        ld a,e
        call dir_step
        call tile_at
        call tile_flags
        bit 1,a
        jr nz,.no
        call occupied
        jr nz,.no
        ld a,b
        ld (px),a
        ld a,c
        ld (py),a
        pop bc
        ret
.no:    pop bc
        inc e
        ld a,e
        cp 4
        jr c,.d
        ld a,b
        ld (px),a
        ld a,c
        ld (py),a
        ret

; pmap = map address of the player
set_pmap:
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call map_addr
        ld (pmap),hl
        ret

; the start of a new game: a random room of the crypt
place_start:
.t:     call rand_room
        call room_cell
        jr nz,.t
        ld a,b
        ld (px),a
        ld a,c
        ld (py),a
        ret
