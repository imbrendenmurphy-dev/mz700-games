; =====================================================================
;  player.asm - controls and the player's move each tick
; =====================================================================

; ---------------------------------------------------------------------
; input_frame: read the keys once per frame and remember taps, so a
; quick press between two ticks still moves the player
; ---------------------------------------------------------------------
input_frame:
        call read_keys
        ld c,a
        ld a,(keys)
        cpl
        and c                       ; newly pressed
        and K_DIRS
        jr z,.nonew
        ld (pref),a                 ; the newest direction wins
        ld b,a
        ld a,(latch)
        or b
        ld (latch),a
.nonew: ld a,c
        ld (keys),a
        ret

; tick_input: tick_dir = the direction for this tick (0 none, 1 left,
; 2 up, 3 right, 4 down), from the replay stream or the keyboard
tick_input:
        ld hl,(replay_ptr)
        ld a,h
        or l
        jr z,.human
        ld a,(replay_cnt)
        or a
        jr nz,.same
        ld a,(hl)                   ; byte = dir << 5 | (count - 1); 0FFh = end
        cp 0FFh
        jr z,.end
        inc hl
        ld (replay_ptr),hl
        ld b,a
        and 1Fh
        inc a
        ld (replay_cnt),a
        ld a,b
        rlca
        rlca
        rlca
        and 7
        ld (replay_dir),a
.same:  ld hl,replay_cnt
        dec (hl)
        ld a,(replay_dir)
        ld (tick_dir),a
        ret
.end:   xor a
        ld (tick_dir),a
        ld a,1
        ld (replay_done),a
        ret
.human: ld a,(keys)
        and K_DIRS
        jr nz,.held
        ld a,(latch)                ; nothing held: use a tap
.held:  ld b,a
        xor a
        ld (latch),a
        ld a,b
        or a
        jr z,.out
        ld a,(pref)                 ; prefer the most recently pressed
        and b
        jr nz,.one
        ld a,b
.one:   ld b,a                      ; keep only the lowest set bit
        neg
        and b
        ; K_ bit -> direction number
        ld b,2
        cp K_UP
        jr z,.d
        ld b,4
        cp K_DOWN
        jr z,.d
        ld b,1
        cp K_LEFT
        jr z,.d
        ld b,3
.d:     ld a,b
.out:   ld (tick_dir),a
        ret

; ---------------------------------------------------------------------
; h_player: the player's move.  HL = cell.
; ---------------------------------------------------------------------
h_player:
        ld (pl_addr),hl
        call cell_pos
        ld (pl_pos),de
        ld a,(tick_dir)
        or a
        ret z
        dec a
        ld b,a                      ; B = direction 0-3
        ld (pl_face),a
        ld a,1
        ld (pl_moved),a
        ld a,b
        call dir_off
        ld (pl_off),de
        push hl
        add hl,de
        ex de,hl                    ; DE = target
        pop hl                      ; HL = player
        ld a,(de)
        and 3Fh
        ld c,a                      ; C = target element
        or low PCLASS
        push de
        ld e,a
        ld d,high PCLASS
        ld a,(de)
        pop de
        add a,a
        push hl
        ld l,a
        ld h,0
        push de
        ld de,.jt
        add hl,de
        pop de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex (sp),hl                  ; jump with HL = player cell
        ret
.jt:    dw pl_block, pl_move, pl_gem, pl_piece, pl_crown, pl_key, pl_push
        dw pl_trans_hit, pl_switch_hit, pl_gate_hit, kill_player

pl_block:
        ret

; move the player from HL to DE (B = direction)
pl_move:
        ld a,c
        or a
        jr z,pl_go
        push bc
        push de
        push hl
        ld hl,SFX_DIG
        xor a
        call sfx
        pop hl
        pop de
        pop bc
pl_go:  ld (hl),0
        ex de,hl
        ld (pl_addr),hl
        ld a,E_PLAYER
        bit 1,b
        jr z,$+4
        or 80h
        ld (hl),a
        call cell_pos
        ld (pl_pos),de
        ret

pl_gem:
        push bc
        push de
        push hl
        ld a,1
        call count_gone
        ld de,0010h
        call add_score
        ld hl,SFX_GEM
        ld a,2
        call sfx
        pop hl
        pop de
        pop bc
        jp pl_go

pl_piece:
        push bc
        push de
        push hl
        ld a,2
        call count_gone
        ld de,0250h
        call add_score
        ld hl,SFX_PIECE
        ld a,6
        call sfx
        ld hl,txt_piece
        call msg_set
        pop hl
        pop de
        pop bc
        jp pl_go

pl_crown:
        push bc
        push de
        push hl
        ld a,3
        call count_gone
        ld de,0500h
        call add_score
        ld hl,SFX_CROWN
        ld a,6
        call sfx
        ld hl,txt_crown
        call msg_set
        pop hl
        pop de
        pop bc
        jp pl_go

; a key: every safe in this region turns into a gem
pl_key:
        push bc
        push de
        push hl
        ld hl,(rbase)
        ld bc,RSZ
.l:     ld a,(hl)
        and 3Fh
        cp E_SAFE
        jr nz,.n
        ld (hl),E_GEM
.n:     inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ld hl,SFX_KEY
        ld a,6
        call sfx
        ld hl,txt_key
        call msg_set
        pop hl
        pop de
        pop bc
        jp pl_go

; push a rock or an egg sideways into space
pl_push:
        bit 0,b
        ret nz                      ; not up or down
        push hl
        ld hl,(pl_off)
        add hl,de                   ; beyond
        ld a,(hl)
        or a
        jr nz,.no
        ld a,c
        bit 1,b
        jr z,$+4
        or 80h
        ld (hl),a
        push bc
        push de
        ld hl,SFX_PUSH
        ld a,1
        call sfx
        pop de
        pop bc
        pop hl
        jp pl_go
.no:    pop hl
        ret

pl_trans_hit:
        ld (pl_trans),de
        ret

pl_switch_hit:
        ld (pl_switch),de
        ret

pl_gate_hit:
        ld a,1
        ld (pl_gate),a
        ret
