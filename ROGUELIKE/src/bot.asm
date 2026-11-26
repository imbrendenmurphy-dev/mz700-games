; =====================================================================
;  bot.asm - the attract-mode adventurer
;
;  It plays from a fixed seed: drinks when hurt, fights what is next to
;  it, throws firebolts down corridors, and otherwise walks the distance
;  map toward the nearest item or unexplored cell.  Any key ends it.
; =====================================================================
DEMO_TURNS      equ 220

demo_game:
        ld a,1
        ld (demo),a
        ld hl,(seed)
        push hl
        ld hl,5EEDh
        ld (seed),hl
        call game
        pop hl
        ld (seed),hl
        xor a
        ld (demo),a
        call snd_fe
        jp wait_release

; Z = nothing this frame; else act_code (and bot_dir for aimed things)
bot_action:
        call anykey
        jr z,.go
        ld a,1
        ld (quit),a
        or a
        ret
.go:    ld hl,(turns)
        ld de,DEMO_TURNS
        or a
        sbc hl,de
        jr c,.t
        ld a,1
        ld (quit),a
        or a
        ret
.t:     ld hl,bot_wait
        dec (hl)
        jr z,.act
        xor a
        ret
.act:   ld (hl),2
        ; hurt: drink
        ld a,(hpot)
        or a
        jr z,.nh
        ld a,(hpmax)
        srl a
        srl a
        ld b,a
        ld a,(hp)
        cp b
        jr nc,.nh
        ld a,ACT_HPOT
        jr .do
.nh:    ; a monster beside us, or in line for a firebolt
        call bot_target_mon
        jr z,.walk
        ld (bot_dir),a
        ld (act_dir),a
        ld a,(bot_dist)
        cp 2
        ld a,ACT_MOVE
        jr c,.do
        xor a
        ld (curspell),a
        ld a,(mp)
        cp 2
        jr c,.walk
        ld a,ACT_CAST
        jr .do
.walk:  call bot_path
        jr z,.rnd
        ld (act_dir),a
        ld a,ACT_MOVE
        jr .do
.rnd:   ld b,4
        call rand_below
        ld (act_dir),a
        ld a,ACT_MOVE
.do:    ld (act_code),a
        or a
        ret

; a hostile, visible, awake monster in a straight line within 6 with
; nothing solid between: A = direction toward it, bot_dist; NZ if found
bot_target_mon:
        ld ix,(monbase)
        ld b,NMON
.m:     push bc
        ld a,(ix+MO_TYPE)
        or a
        jr z,.n
        cp M_HERMIT
        jr nc,.n
        ld b,(ix+MO_X)
        ld c,(ix+MO_Y)
        call map_addr
        ld a,h
        or high VISM
        ld h,a
        ld a,(hl)
        or a
        jr z,.n
        ld a,(px)
        cp b
        jr z,.col
        ld a,(py)
        cp c
        jr nz,.n
        ; same row
        ld a,b
        ld hl,px
        sub (hl)
        ld e,3                      ; right
        jr nc,.r
        neg
        ld e,2
.r:     jr .chk
.col:   ld a,c
        ld hl,py
        sub (hl)
        ld e,1                      ; down
        jr nc,.chk
        neg
        ld e,0
.chk:   cp 7
        jr nc,.n
        ld (bot_dist),a
        ld d,a
        ; clear between?
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
.cl:    dec d
        jr z,.ok
        ld a,e
        call dir_step
        call tile_at
        call tile_flags
        and F_SOLID|F_OPAQUE
        jr nz,.n
        jr .cl
.ok:    pop bc
        ld a,e
        or 1
        ld a,e
        ret
.n:     ld de,MONSZ
        add ix,de
        pop bc
        djnz .m
        xor a
        ret

; the first step toward the nearest item or unexplored cell: A = dir,
; NZ if there is one
bot_path:
        ld a,0FFh
        ld (bot_best),a
        ld hl,MAP
.s:     ld a,h
        or high DMAP
        ld d,a
        ld e,l
        ld a,(de)
        ld c,a                      ; its distance
        or a
        jr z,.n
        cp 0FFh
        jr z,.n
        bit 6,(hl)
        jr z,.unseen
        ld a,(hl)
        and 3Fh
        cp T_EXIT
        jr nz,.n
        ; exits once the zone is known: new zones first
        ld e,c
        push hl
        call map_xy
        call exit_dest
        call zbit
        ld hl,zvisit
        and (hl)
        pop hl
        ld a,e
        jr z,.new
        add a,120
        jr .ex2
.new:   add a,25
.ex2:   jr nc,$+4
        ld a,254
        ld c,a
        jr .cand
.unseen:                            ; after a long while, exploring loses its pull
        ld a,(bot_zturns)
        cp 70
        jr c,.cand
        ld a,c
        add a,60
        jr nc,$+4
        ld a,254
        ld c,a
.cand:  ld a,(bot_best)
        cp c
        jr c,.n
        jr z,.n
        ld a,c
        ld (bot_best),a
        ld (bot_cell),hl
.n:     inc hl
        ld a,l
        or a
        call z,poll
        ld a,h
        cp high SLIGHT
        jr c,.s
        ; items are worth a detour
        ld ix,ITEMS
        ld b,NITEM
.it:    push bc
        ld a,(ix+0)
        or a
        jr z,.in
        ld b,(ix+1)
        ld c,(ix+2)
        call map_addr
        ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        sub 6
        jr nc,$+3
        xor a
        ld c,a
        ld a,(bot_best)
        cp c
        jr c,.in
        jr z,.in
        ld a,c
        ld (bot_best),a
        ld a,h
        and 07h
        ld h,a
        ld (bot_cell),hl
.in:    ld de,ITEMSZ
        add ix,de
        pop bc
        djnz .it
        ld a,(bot_best)
        cp 0FFh
        ret z
        ; walk back from the target to the cell next to the player
        ld hl,(bot_cell)
.b:     ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        ld c,a
        ld a,h
        and 07h
        ld h,a
        ld a,c
        cp 2
        jr c,.found
        dec c                       ; a neighbour one nearer
        ld de,1
        call .nb
        jr z,.b
        ld de,-1
        call .nb
        jr z,.b
        ld de,64
        call .nb
        jr z,.b
        ld de,-64
        call .nb
        jr z,.b
        xor a
        ret
.nb:    push hl
        add hl,de
        ld a,h
        or high DMAP
        ld h,a
        ld a,(hl)
        push af
        ld a,h
        and 07h
        ld h,a
        pop af
        cp c
        jr z,.yes
        pop hl
        or 1
        ret
.yes:   pop af
        xor a
        ret
.found: ; HL = the cell to step to: which way is it?
        call map_xy
        ld a,(px)
        cp b
        jr z,.v
        ld a,2
        jr nc,.ok
        inc a
        jr .ok
.v:     ld a,(py)
        cp c
        ld a,0
        jr nc,.ok
        inc a
.ok:    ld (bot_dir),a
        ; not into a resident
        call bot_step_ok
        ld a,(bot_dir)
        ret

; A = the zone the exit at (B, C) leads to (FF if none).  Keeps BC, DE.
exit_dest:
        push hl
        push de
        ld a,(zone)
        call exits_addr
        ld e,3
.f:     ld a,(hl)
        cp b
        jr nz,.n
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr nz,.n
        inc hl
        inc hl
        ld a,(hl)
        jr .x
.n:     inc hl
        inc hl
        inc hl
        dec e
        jr nz,.f
        ld a,0FFh
.x:     pop de
        pop hl
        ret

; NZ if stepping bot_dir from the player does not bump a resident
bot_step_ok:
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        ld a,(bot_dir)
        call dir_step
        call mon_at
        jr z,.ok
        ld a,(ix+MO_TYPE)
        cp M_HERMIT
        jr c,.ok
        xor a
        ret
.ok:    or 1
        ret
