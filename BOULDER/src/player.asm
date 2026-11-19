; =====================================================================
;  player.asm - controls, the player's move each tick, scoring
; =====================================================================

; ---------------------------------------------------------------------
; input_frame: read the keys once per frame and remember taps, so a
; quick press between two ticks still moves the player
; ---------------------------------------------------------------------
input_frame:
        call read_keys
        ld c,a
        ld a,(keys)
        ld (keys_prev),a
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

; tick_input: A = the K_ bits that drive this tick (one direction at most)
tick_input:
        ld a,(demo)
        or a
        jr z,.human
        ld a,(ai_keys)
        ret
.human: ld a,(keys)
        ld c,a
        and K_DIRS
        jr nz,.held
        ld a,(latch)                ; nothing held: use a tap
.held:  ld b,a                      ; B = candidate directions
        xor a
        ld (latch),a
        ld a,b
        or a
        jr z,.out
        ld a,(pref)                 ; prefer the most recently pressed
        and b
        jr nz,.one
        ld a,b
.one:   ; keep only the lowest set bit
        ld b,a
        neg
        and b
.out:   ld b,a
        ld a,c
        and K_FIRE
        or b
        ret

; ---------------------------------------------------------------------
; h_player: the player's move.  HL = cell.
; ---------------------------------------------------------------------
h_player:
        ld (pl_addr),hl
        ld a,(pl_frozen)
        or a
        ret nz
        ld a,(tick_keys)
        ld c,a                      ; C = keys
        and K_DIRS
        jr nz,.go
        xor a
        ld (pl_moved),a
        ret
.go:    ld b,0                      ; dir 0 = left 1 = up 2 = right 3 = down
        rrca                        ; K_UP
        jr nc,$+4
        ld b,1
        rrca                        ; K_DOWN
        jr nc,$+4
        ld b,3
        rrca                        ; K_LEFT
        jr nc,$+4
        ld b,0
        rrca                        ; K_RIGHT
        jr nc,$+4
        ld b,2
        ld a,b
        ld (pl_dir),a
        cp 0
        jr z,.fl
        cp 2
        jr nz,.nf
        ld a,2
.fl:    inc a                       ; face 1 = left, 3 = right
        ld (pl_face),a
.nf:    ld a,1
        ld (pl_moved),a
        ld a,b
        add a,a
        add a,low DIROFF
        ld e,a
        ld d,high DIROFF
        ld a,(de)
        ld (pl_off),a
        inc e
        ld a,(de)
        ld (pl_off+1),a
        ld de,(pl_off)
        push hl
        add hl,de
        ex de,hl                    ; DE = target
        pop hl                      ; HL = player
        ld a,(de)
        and 1Fh
        cp E_DIRT+1
        jr c,.dig
        cp E_DIAMOND
        jr z,.gem
        cp E_DIAMONDF
        jr z,.gem
        cp E_EXITO
        jr z,.exit
        cp E_BOULDER
        ret nz
        ; push a boulder sideways (1 in 4 tries)
        bit 4,c
        ret nz                      ; not while snapping
        ld a,b
        and 1
        ret nz                      ; only left / right
        push hl
        ex de,hl
        ld de,(pl_off)
        add hl,de                   ; beyond the boulder
        ld a,(hl)
        or a
        jr nz,.nopush
        push hl
        call rand
        pop hl
        and 3
        jr nz,.nopush
        ld a,E_BOULDER
        bit 1,b
        jr z,$+4
        or 80h
        ld (hl),a
        ld de,(pl_off)
        or a
        sbc hl,de
        ex de,hl                    ; DE = old boulder cell
        pop hl
        push de
        ld hl,SFX_PUSH
        ld a,1
        call sfx
        pop de
        ld hl,(pl_addr)
        jr .move
.nopush:
        pop hl
        ret
.gem:   push bc
        push de
        push hl
        call got_diamond
        pop hl
        pop de
        pop bc
        jr .take
.dig:   or a
        jr z,.take
        push bc
        push de
        push hl
        ld hl,SFX_DIG
        xor a
        call sfx
        pop hl
        pop de
        pop bc
.take:  bit 4,c                     ; snapping: clear it without moving
        jr z,.move
        xor a
        ld (de),a
        ret
.move:  ld (hl),0
        ex de,hl
        ld (pl_addr),hl
        ld a,E_PLAYER
        bit 1,b
        jr z,$+4
        or 80h
        ld (hl),a
        ret
.exit:  bit 4,c
        ret nz
        ld (hl),0
        ld (pl_addr),de
        ld a,1
        ld (pl_exit),a
        ld (pl_frozen),a
        ret

; ---------------------------------------------------------------------
; got_diamond: count it, score it, open the exit when enough are in
; ---------------------------------------------------------------------
got_diamond:
        ld a,(exit_open)
        or a
        ld a,(dval)
        jr z,$+5
        ld a,(xval)
        call add_points
        ld hl,got
        ld a,(hl)
        cp 99
        jr nc,.c
        inc (hl)
.c:     ld a,1
        ld (hud_dirty),a
        ld a,(exit_open)
        or a
        jr nz,.snd
        ld a,(need)
        cp (hl)
        jr nz,.snd
        call open_exit
        ret
.snd:   ld hl,SFX_COLLECT
        ld a,2
        jp sfx

; add_points: A = points (binary, 0-255); BCD score and the extra life count
add_points:
        push af
        ld e,a
        ld d,0
        ld hl,(life_acc)
        add hl,de
        ld de,-500
        add hl,de
        jr c,.life
        ld de,500
        add hl,de
        jr .nolife
.life:  ld a,(lives)
        cp 9
        jr nc,.nolife
        inc a
        ld (lives),a
        push hl
        ld hl,SFX_LIFE
        ld a,6
        call sfx
        pop hl
.nolife:
        ld (life_acc),hl
        pop af
        call bin2bcd                ; A -> DE = BCD
        jp add_score

; A (0-255) -> DE = BCD (D = hundreds)
bin2bcd:
        ld d,0
.h:     cp 100
        jr c,.t
        sub 100
        inc d
        jr .h
.t:     ld e,0
.t2:    cp 10
        jr c,.u
        sub 10
        inc e
        jr .t2
.u:     ld b,a
        ld a,e
        rlca
        rlca
        rlca
        rlca
        or b
        ld e,a
        ret
