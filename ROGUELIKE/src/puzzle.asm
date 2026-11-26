; =====================================================================
;  puzzle.asm - braziers, boulders and plates, levers, mirrors and the
;  sun beam, ice
;
;  Each kind of gate answers one mechanism in its zone:
;   GATEB  opens when no unlit brazier is left
;   GATEP  opens when every plate holds a boulder
;   GATEL / GATELO swap whenever a lever is pulled
;   GATEM  opens when the beam from the emitter reaches the target
; =====================================================================
NBEAM           equ 64

; replace every tile A in the map by tile E; NZ if any changed
swap_tiles:
        ld d,a
        ld hl,MAP
        ld c,0
.l:     ld a,(hl)
        and 3Fh
        cp d
        jr nz,.n
        ld a,e
        call set_tile
        inc c
.n:     inc hl
        ld a,h
        cp high SLIGHT
        jr c,.l
        ld a,c
        or a
        ret

; Z if tile A appears nowhere in the map
tile_absent:
        ld d,a
        ld hl,MAP
.l:     ld a,(hl)
        and 3Fh
        cp d
        ret z
        inc hl
        ld a,h
        cp high SLIGHT
        jr c,.l
        or 1
        ret

; open the gates of kind A, with a fanfare
open_gates:
        ld e,T_GATEOPEN
        call swap_tiles
        ret z
        ld hl,msg_gate
        call msg
        ld hl,SFX_GATE
        ld a,3
        call sfx
        ld a,1
        ld (need_fov),a
        ret

; ---------------------------------------------------------------------
; light the brazier at (B, C)
light_brazier:
        call map_addr
        ld a,T_BRAZON
        call set_tile
        push bc
        ld a,P_EMBER
        ld e,8
        call burst
        ld hl,SFX_BURN
        ld a,2
        call sfx
        ld hl,msg_brazier
        call msg
        call relight
        pop bc
        ; none left unlit?
        ld a,T_BRAZOFF
        call tile_absent
        jr z,.done
        ld a,T_GATEB
        call open_gates
.done:  or 1
        ret

; ---------------------------------------------------------------------
; push the boulder at (B, C) one cell on (act_dir); the player follows
push_boulder:
        ld (pb_from),bc
        ld a,(act_dir)
        call dir_step
        call occupied
        jp nz,.no
        call tile_at
        cp T_WATER
        jr z,.sink
        cp T_LAVA
        jr z,.melt
        cp T_PLATE
        jr z,.ok
        call tile_flags
        bit 1,a
        jp nz,.no
        bit 5,a
        jr z,.no
        call tile_at
        cp T_EXIT
        jr z,.no
.ok:    call tile_at
        cp T_PLATE
        ld a,T_BOULDER
        jr nz,$+4
        ld a,T_PLATEB
        call set_tile
        jr .moved
.sink:  ld a,T_FLOOR2               ; it fills the water
        call set_tile
        push bc
        ld a,P_DRIP
        ld e,8
        call burst
        ld hl,SFX_SPLASH
        ld a,2
        call sfx
        pop bc
        jr .moved
.melt:  ld a,T_OBSIDIAN
        call set_tile
        push bc
        ld a,P_EMBER
        ld e,8
        call burst
        pop bc
        call relight
.moved: ld bc,(pb_from)
        call tile_at
        cp T_PLATEB
        ld a,T_FLOOR
        jr nz,$+4
        ld a,T_PLATE
        call set_tile
        ld hl,SFX_PUSH
        ld a,1
        call sfx
        ; the player steps in
        ld bc,(pb_from)
        ld a,b
        ld (px),a
        ld a,c
        ld (py),a
        call set_pmap
        ld a,1
        ld (need_fov),a
        ; every plate covered?
        ld a,T_PLATE
        call tile_absent
        jr z,.x
        ld a,T_GATEP
        call open_gates
.x:     or 1
        ret
.no:    ld hl,msg_stuck
        call msg
        xor a
        ret

; ---------------------------------------------------------------------
pull_lever:
        ; swap shut and open lever gates (through a spare tile)
        ld a,T_GATEL
        ld e,T_GATEB+40             ; (temporary: an unused tile number)
        call swap_tiles
        ld a,T_GATELO
        ld e,T_GATEL
        call swap_tiles
        ld a,T_GATEB+40
        ld e,T_GATELO
        call swap_tiles
        ld hl,SFX_LEVER
        ld a,2
        call sfx
        ld hl,msg_lever
        call msg
        ld a,1
        ld (need_fov),a
        or 1
        ret

; ---------------------------------------------------------------------
turn_mirror:
        call map_addr
        ld a,(mv_tile)
        cp T_MIRRORA
        ld a,T_MIRRORB
        jr z,$+4
        ld a,T_MIRRORA
        call set_tile
        ld hl,SFX_LEVER
        ld a,1
        call sfx
        call beam_trace
        call relight
        or 1
        ret

; trace the beam from the emitter (it shines right).  beam: the cells it
; crosses (map addresses), beam_n of them.  Opens GATEM on the target.
beam_trace:
        xor a
        ld (beam_n),a
        ld a,T_EMITTER
        call find_tile
        ret nz
        ld de,1                     ; moving right
        ld b,NBEAM
.s:     add hl,de
        ld a,(hl)
        and 3Fh
        cp T_MIRRORA
        jr z,.ma
        cp T_MIRRORB
        jr z,.mb
        cp T_TARGET
        jr z,.hit
        cp T_TARGETON
        ret z
        ; the beam passes over anything that is not solid
        push hl
        ld l,a
        ld h,high TFLAGS
        ld a,(hl)
        pop hl
        and F_SOLID|F_OPAQUE
        ret nz
        push hl
        push de
        ld a,(beam_n)
        ld e,a
        inc a
        ld (beam_n),a
        ld d,0
        ex de,hl
        add hl,hl
        ld bc,beam
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        pop de
        pop hl
        ld a,(beam_n)
        cp NBEAM
        ret nc
        jr .s
.ma:    ; '/': right -> up, up -> right, left -> down, down -> left
        call beam_neg_swap
        jr .s
.mb:    ; '\': right -> down, down -> right, left -> up, up -> left
        call beam_swap
        jr .s
.hit:   ld a,T_TARGETON
        call set_tile
        push hl
        call map_xy
        ld a,P_GOLD
        ld e,12
        call burst
        pop hl
        ld a,T_GATEM
        call open_gates
        ld hl,msg_beam
        call msg
        ret

; direction (DE = +-1 or +-64) through a '\' mirror: +1 <-> +64, -1 <-> -64
beam_swap:
        ld a,e
        cp 1
        jr z,.p64
        cp 64
        jr z,.p1
        cp 0FFh
        jr z,.m64
        ld de,-1
        ret
.p64:   ld de,64
        ret
.p1:    ld de,1
        ret
.m64:   ld de,-64
        ret
; through a '/' mirror: +1 <-> -64, -1 <-> +64
beam_neg_swap:
        ld a,e
        cp 1
        jr z,.m64
        cp 64
        jr z,.m1
        cp 0FFh
        jr z,.p64
        ld de,1
        ret
.m64:   ld de,-64
        ret
.m1:    ld de,-1
        ret
.p64:   ld de,64
        ret

; HL = the first cell holding tile A; NZ if there is none
find_tile:
        ld d,a
        ld hl,MAP
.l:     ld a,(hl)
        and 3Fh
        cp d
        ret z
        inc hl
        ld a,h
        cp high SLIGHT
        jr c,.l
        or 1
        ret

; the beam lights its cells (called at the end of relight)
beam_relight:
        ld a,(beam_n)
        or a
        ret z
        ld b,a
        ld hl,beam
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        push bc
        ex de,hl
        ld a,3+(6<<4)               ; S 3, SUN
        call cast_light
        pop bc
        pop hl
        djnz .l
        ret

; the beam's glyphs over the view
beam_draw:
        ld a,(beam_n)
        or a
        ret z
        ld b,a
        ld hl,beam
.l:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        call map_xy
        call view_index
        jr z,.n
        ld a,(hl)
        bit 3,a
        jr z,.n
        ld a,(framecnt)
        and 2
        ld a,0F6h
        jr z,$+4
        ld a,0F9h
        ld (ov_g),a
        ld a,YELLOW*16
        call ov_put
.n:     pop hl
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; ice: keep sliding in act_dir while the next cell is free
ice_slide:
.l:     ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call tile_at
        cp T_ICE
        ret nz
        ld a,(act_dir)
        call dir_step
        call tile_at
        call tile_flags
        bit 1,a
        ret nz
        call mon_at
        ret nz
        ld a,b
        ld (px),a
        ld a,c
        ld (py),a
        call set_pmap
        call pickup
        call set_view
        call fov
        call anim_frame
        jr .l
