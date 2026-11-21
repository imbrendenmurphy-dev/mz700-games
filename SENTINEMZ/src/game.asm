; =====================================================================
;  game.asm - one island: input, cursor and picking, actions, the
;  Lantern's beam, wisps
; =====================================================================

R_LOST          equ 0
R_CLEAR         equ 1
R_QUIT          equ 2
R_NONE          equ 0FFh

; A = result: R_LOST, R_CLEAR or R_QUIT
play_island:
        call mus_stop
        call show_surveying
        call gen_island
        ld hl,(ptile)               ; face the Lantern
        call tile_xy
        ld a,(lantx)
        ld c,a
        ld a,c
        sub e
        add a,a
        add a,a
        ld (sdx),a
        ld a,(lanty)
        sub d
        add a,a
        add a,a
        ld (sdy),a
        call sector
        add a,a
        add a,a
        ld (heading),a
        ld a,1
        ld (pitch),a
        call rng
        and 7
        ld (beam),a
        or 8
        ld (beamcode),a
        ld a,(island)               ; beam period: 6 s, 0.25 s less per island, >= 3 s
        ld c,a
        ld hl,300+12
.bp:    ld de,-12
        add hl,de
        dec c
        jr nz,.bp
        ld de,-150
        add hl,de
        jr c,.bpok
        ld hl,0
.bpok:  ld de,150
        add hl,de
        ld (beam_period),hl
        ld (beam_t),hl
        ld hl,250
        ld (wisp_t),hl
        ld a,YELLOW
        ld (lamp_col),a
        ld a,20
        ld (ccx),a
        ld a,12
        ld (ccy),a
        xor a
        ld (cur_on),a
        ld (absorbed),a
        ld (built),a
        ld (moves),a
        ld (lit),a
        ld (warned),a
        ld (paused),a
        ld (msg_t),a
        ld (ai_state),a
        ld (ai_turns),a
        ld a,25
        ld (drain_t),a
        ld a,R_NONE
        ld (result),a
        ld hl,0
        ld (idle_t),hl
        ld a,BLACK
        call cls
        call hud_draw
        ld a,(autoplay)
        or a
        jr nz,.nomus
        ld a,(music_off)
        or a
        jr nz,.nomus
        ld hl,SONG_AMBIENT
        call mus_play
.nomus: ld hl,SFX_RISE
        ld a,1
        call sfx
        ld a,1
        ld (need_render),a
.loop:  ld a,(need_render)
        or a
        call nz,do_render
        call wait_field
        call update_beam
        call update_lit
        call update_wisps
        call hud_tick
        ld a,(autoplay)
        or a
        jr z,.human
        call ai_step
        call anykey                 ; any key ends the demo
        jr z,.dt
        ld a,R_QUIT
        ld (result),a
.dt:    ld hl,(demo_t)
        dec hl
        ld (demo_t),hl
        ld a,h
        or l
        jr nz,.chk
        ld a,R_QUIT
        ld (result),a
        jr .chk
.human: call handle_input
.chk:   ld a,(result)
        cp R_NONE
        jr z,.loop
        push af
        call mus_stop
        pop af
        ret

do_render:
        xor a
        ld (need_render),a
        call cursor_hide
        call player_pos
        call render                 ; ends with cursor_show
        call pick
        call cursor_show
        jp hud_target

; ---------------------------------------------------------------------
; cursor
; ---------------------------------------------------------------------
; DE = VRAM address of the cursor cell
cur_addr:
        ld a,(ccx)
        ld b,a
        ld a,(ccy)
        ld c,a
        jp vaddr

cursor_hide:
        ld a,(cur_on)
        or a
        ret z
        xor a
        ld (cur_on),a
        call cur_addr
        ld a,(cur_char)
        ld (de),a
        set 3,d
        ld a,(cur_attr)
        ld (de),a
        ret

cursor_show:
        ld a,(cur_on)
        or a
        ret nz
        ld a,(autoplay)             ; the demo shows the cursor too
        inc a
        ld (cur_on),a
        call cur_addr
        ld a,(de)
        ld (cur_char),a
        set 3,d
        ld a,(de)
        ld (cur_attr),a
        and 07h                     ; keep the cell's background
        ld c,a
        ld a,(tgt_ok)
        or a
        ld a,70h                    ; white: usable target
        jr nz,.w
        ld a,20h                    ; red: not
.w:     ld b,a
        ld a,c
        cp 7                        ; white ground: use black
        jr nz,.n
        ld b,0
.n:     ld a,c
        cp 2
        jr nz,.n2
        ld a,b
        cp 20h
        jr nz,.n2
        ld b,60h                    ; red on red: yellow
.n2:    ld a,b
        or c
        ld (de),a
        res 3,d
        ld a,6Ah                    ; '+'
        ld (de),a
        ret

; move the cursor by (B = dx, C = dy) cells; past an edge turns / tilts
cursor_move:
        push bc
        call cursor_hide
        pop bc
        ld a,(ccx)
        add a,b
        jp m,.left
        cp 40
        jr nc,.right
        ld (ccx),a
        ld a,(ccy)
        add a,c
        jp m,.up
        cp VIEW_ROWS
        jr nc,.down
        ld (ccy),a
        ld hl,SFX_CURSOR
        ld a,1
        call sfx
        call pick
        call cursor_show
        jp hud_target
.left:  ld a,-2
        jr .turn
.right: ld a,2
.turn:  ld b,a
        ld a,(heading)
        add a,b
        and 31
        ld (heading),a
        ld hl,SFX_TURN
        ld a,1
        call sfx
        jr .re
.up:    ld a,(pitch)
        or a
        jr z,.deny
        dec a
        ld (pitch),a
        ld a,VIEW_ROWS-3
        ld (ccy),a
        jr .re
.down:  ld a,(pitch)
        cp 2
        jr nc,.deny
        inc a
        ld (pitch),a
        ld a,2
        ld (ccy),a
.re:    ld a,1
        ld (need_render),a
        ret
.deny:  call cursor_show
        ret

; ---------------------------------------------------------------------
; pick: what is under the cursor -> tgt_t, tgt_kind, tgt_ok
; ---------------------------------------------------------------------
pick:
        xor a
        ld (tgt_kind),a
        ld (tgt_ok),a
        ld a,(ccx)
        add a,a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(ccy)
        add a,a
        or l
        ld l,a
        ld de,ZB
        add hl,de
        ld (pk_a),hl                ; top-left pixel
        ld a,(hl)                   ; any object pixel in the cell wins
        bit 7,a
        jr nz,.obj
        inc l
        ld a,(hl)
        bit 7,a
        jr nz,.obj
        ld de,64
        add hl,de
        ld a,(hl)
        bit 7,a
        jr nz,.obj
        dec l
        ld a,(hl)
        bit 7,a
        jr nz,.obj
        ld hl,(pk_a)                ; ground: bottom-left, bottom-right, top-left, top-right
        inc l
        ld a,(hl)
        ld b,0
        cp 7Eh
        jr c,.gnd
        ld de,64
        add hl,de
        ld a,(hl)
        ld b,1
        cp 7Eh
        jr c,.gnd
        dec l
        ld a,(hl)
        cp 7Eh
        jr c,.gnd
        ld hl,(pk_a)
        ld a,(hl)
        ld b,0
        cp 7Eh
        ret nc                      ; sea / sky
.gnd:   ld c,a
        ld a,(ccx)
        add a,a
        add a,b
        ld b,a
        ld a,c
        call recast_tile            ; A = step, B = column -> HL = tile
        ld (tgt_t),hl
        ld a,1
        jr .ok
.obj:   and 7Fh
        call ol_addr
        ld de,OL_T
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (tgt_t),hl
        ld a,2
.ok:    ld (tgt_kind),a
        ld hl,(tgt_t)
        call tf_addr
        ld a,(hl)
        and 80h
        ld (tgt_ok),a
        ret

; A = step index, B = pixel column -> HL = the tile that step hits
recast_tile:
        ld (rc_s),a
        push bc
        call load_dirs
        call player_pos
        pop bc
        ld hl,(d_x0)
        ld de,(d_y0)
        ld a,b
        or a
        jr z,.d1
.dl:    push bc
        ld bc,(d_dx)
        add hl,bc
        ex de,hl
        ld bc,(d_dy)
        add hl,bc
        ex de,hl
        pop bc
        djnz .dl
.d1:    call sra_hl                 ; x: >> 3, 4, 5
        call sra_hl
        call sra_hl
        ld (rcx_c),hl
        call sra_hl
        ld (rcx_b),hl
        call sra_hl
        ld (rcx_a),hl
        ex de,hl
        call sra_hl
        call sra_hl
        call sra_hl
        ld (rcy_c),hl
        call sra_hl
        ld (rcy_b),hl
        call sra_hl
        ld (rcy_a),hl
        ld hl,(ppx)                 ; z = 1
        ld de,(rcx_b)
        add hl,de
        ld (rpx),hl
        ld hl,(ppy)
        ld de,(rcy_b)
        add hl,de
        ld (rpy),hl
        ld a,(rc_s)
        or a
        jr z,.done
        ld b,a
        ld c,1
.st:    ld a,c
        cp 31
        ld hl,rcx_a
        jr c,.add
        cp 63
        ld hl,rcx_b
        jr c,.add
        ld hl,rcx_c
.add:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl                      ; rcy_* follow 6 bytes later
        push hl
        ld hl,(rpx)
        add hl,de
        ld (rpx),hl
        pop hl
        ld de,4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(rpy)
        add hl,de
        ld (rpy),hl
        inc c
        djnz .st
.done:  ld a,(rpx+1)
        rrca
        rrca
        and 1Fh
        ld e,a
        ld a,(rpy+1)
        rrca
        rrca
        and 1Fh
        ld d,a
        jp tile_of

; ---------------------------------------------------------------------
; input
; ---------------------------------------------------------------------
; A = newly pressed or repeating K_ bits (repeat: 8 fields, then every 2)
game_keys:
        call read_keys
        ld c,a
        ld a,(fe_prev)
        cpl
        and c
        ld b,a
        ld a,c
        ld (fe_prev),a
        ld a,b
        or a
        jr z,.rep
        ld a,8
        ld (fe_rep),a
        ld a,b
        ret
.rep:   ld a,c
        and K_DIRS
        ret z
        ld hl,fe_rep
        dec (hl)
        jr z,.go
        xor a
        ret
.go:    ld (hl),2
        ld a,c
        and K_DIRS
        ret

; A = ASCII letter held (rows 1-4) or 0
getletter:
        push bc
        push de
        push hl
        ld hl,KEYPA
        ld de,gk_tab
        ld c,1
.r:     ld (hl),c
        inc l
        ld a,(hl)
        dec l
        ld b,8
.b:     rla
        jr nc,.hit
        inc de
        djnz .b
        inc c
        ld a,c
        cp 5
        jr c,.r
        xor a
        jr .x
.hit:   ld a,(de)
.x:     pop hl
        pop de
        pop bc
        ret

handle_input:
        call game_keys
        ld c,a
        or a
        jr z,.letters
        ld hl,0
        ld (idle_t),hl
        bit B_FIRE,c
        jp nz,act_absorb
        ld b,0
        ld e,0
        bit B_LEFT,c
        jr z,$+3
        dec b
        bit B_RIGHT,c
        jr z,$+3
        inc b
        bit B_UP,c
        jr z,$+3
        dec e
        bit B_DOWN,c
        jr z,$+3
        inc e
        ld c,e
        jp cursor_move
.letters:
        ld a,(key_extra)            ; BREAK: quit
        bit 4,a
        jp nz,ask_quit
        call getletter
        ld hl,lastletter
        cp (hl)
        ld (hl),a
        ret z                       ; held, not new
        or a
        ret z
        ld hl,0
        ld (idle_t),hl
        cp 'A'
        jp z,act_absorb
        cp 'B'
        jp z,act_cairn
        cp 'S'
        jp z,act_shell
        cp 'T'
        jp z,act_move
        cp 'U'
        jp z,act_uturn
        cp 'Z'
        jp z,act_left
        cp 'X'
        jp z,act_right
        cp 'M'
        jp z,show_map
        cp 'N'
        jp z,toggle_music
        cp 'P'
        jp z,do_pause
        cp 'Q'
        jp z,ask_quit
        cp 'H'
        jp z,show_help_line
        ret

act_left:
        ld a,-4
        jr act_turn
act_right:
        ld a,4
        jr act_turn
act_uturn:
        ld a,16
act_turn:
        ld b,a
        ld a,(heading)
        add a,b
        and 31
        ld (heading),a
        ld hl,SFX_TURN
        ld a,1
        call sfx
        ld a,1
        ld (need_render),a
        ret

toggle_music:
        ld a,(music_off)
        xor 1
        ld (music_off),a
        jr z,.on
        call mus_stop
        ld hl,MSG_MUSOFF
        jp hud_msg
.on:    ld hl,SONG_AMBIENT
        call mus_play
        ld hl,MSG_MUSON
        jp hud_msg

do_pause:
        ld hl,MSG_PAUSED
        call hud_msg_now
        call mus_stop
        call wait_release
.w:     call poll
        call anykey
        jr z,.w
        call wait_release
        xor a
        ld (lastletter),a
        ld a,(music_off)
        or a
        jr nz,.m
        ld hl,SONG_AMBIENT
        call mus_play
.m:     ld hl,MSG_EMPTY
        jp hud_msg_now

ask_quit:
        ld hl,MSG_QUIT
        call hud_msg_now
        call wait_release
.w:     call poll
        call getletter
        cp 'Y'
        jr z,.y
        cp 'N'
        jr z,.n
        call read_keys
        bit B_FIRE,a
        jr z,.w
.n:     call wait_release
        xor a
        ld (lastletter),a
        ld hl,MSG_EMPTY
        jp hud_msg_now
.y:     ld a,R_QUIT
        ld (result),a
        ret

show_help_line:
        ld hl,MSG_HELP
        jp hud_msg

; ---------------------------------------------------------------------
; actions on the target (tgt_t / tgt_ok); each one reports in the HUD
; ---------------------------------------------------------------------
; Z if the target is a visible tile that is not the player's own
tgt_check:
        ld a,(tgt_kind)
        or a
        jr z,.no
        ld a,(tgt_ok)
        or a
        jr z,.unseen
        ld hl,(tgt_t)
        ld de,(ptile)
        or a
        sbc hl,de
        jr z,.own
        xor a
        ret
.no:    ld hl,MSG_NOTGT
        jr .deny
.unseen:
        ld hl,MSG_UNSEEN
        jr .deny
.own:   ld hl,MSG_OWN
.deny:  call hud_msg
        call deny_sfx
        or 1
        ret

deny_sfx:
        ld hl,SFX_DENY
        ld a,2
        jp sfx

act_absorb:
        call tgt_check
        ret nz
        ld hl,(tgt_t)
        call obj_addr
        ld a,(hl)
        or a
        jr nz,.some
        ld hl,MSG_NOTHING
        call hud_msg
        jp deny_sfx
.some:  ld b,a
        and 7
        jr z,.cairn
        cp O_LANTERN
        jp z,lantern_out
        ld c,1                      ; shard
        cp O_SHARD
        jr z,.top
        ld c,3                      ; shell
        cp O_SHELL
        jr z,.top
        ld c,2                      ; wisp
        ld a,(nwisps)
        dec a
        ld (nwisps),a
.top:   ld a,b
        and 0F0h
        ld (hl),a
        jr .gain
.cairn: ld a,b
        sub 10h
        ld (hl),a
        ld c,2
.gain:  ld a,c
        call add_energy
        ld hl,absorbed
        inc (hl)
        call fx_target_sparkle
        ld hl,SFX_ABSORB
        ld a,2
        call sfx
        ld hl,MSG_ABSORBED
        call hud_msg
        ld a,1
        ld (need_render),a
        ret

; A = energy gained (also scores 10 per unit)
add_energy:
        ld c,a
        ld a,(energy)
        add a,c
        cp 100
        jr c,$+4
        ld a,99
        ld (energy),a
        ld a,c
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b                     ; * 10
        ld e,a
        ld d,0
        ld hl,(score)
        add hl,de
        ld (score),hl
        call hud_info
        jp hud_energy

; Z if the target tile can take something new on top
build_check:
        call tgt_check
        ret nz
        ld hl,(tgt_t)
        call tf_addr
        bit 4,(hl)
        jr nz,.flat
        ld hl,MSG_SLOPE
        jr .no
.flat:  ld hl,(tgt_t)
        call obj_addr
        ld a,(hl)
        and 7
        jr z,.free
        ld hl,MSG_OCCUPIED
.no:    call hud_msg
        call deny_sfx
        or 1
        ret
.free:  ld a,(hl)
        cp 70h
        jr c,.ok
        ld hl,MSG_TALL
        jr .no
.ok:    xor a
        ret

; C = cost: Z and energy taken if affordable
spend:
        ld a,(energy)
        sub c
        jr c,.poor
        ld (energy),a
        call hud_energy
        xor a
        ret
.poor:  ld hl,MSG_POOR
        call hud_msg
        call deny_sfx
        or 1
        ret

act_cairn:
        call build_check
        ret nz
        ld c,2
        call spend
        ret nz
        ld hl,(tgt_t)
        call obj_addr
        ld a,(hl)
        add a,10h
        ld (hl),a
        ld hl,built
        inc (hl)
        ld hl,SFX_BUILD
        ld a,2
        call sfx
        ld hl,MSG_BUILT
        call hud_msg
        ld a,1
        ld (need_render),a
        ret

act_shell:
        call build_check
        ret nz
        ld c,3
        call spend
        ret nz
        ld hl,(tgt_t)
        call obj_addr
        ld a,(hl)
        or O_SHELL
        ld (hl),a
        ld hl,built
        inc (hl)
        ld hl,SFX_SHELL
        ld a,2
        call sfx
        ld hl,MSG_SHELLED
        call hud_msg
        ld a,1
        ld (need_render),a
        ret

act_move:
        call tgt_check
        ret nz
        ld hl,(tgt_t)
        call obj_addr
        ld a,(hl)
        and 7
        cp O_SHELL
        jr z,.go
        ld hl,MSG_NOSHELL
        call hud_msg
        jp deny_sfx
.go:    ld a,(hl)                   ; the shell becomes us
        and 0F0h
        ld (hl),a
        ld hl,(ptile)               ; and we leave a shell behind
        call obj_addr
        ld a,(hl)
        or O_SHELL
        ld (hl),a
        ld hl,(tgt_t)
        ld (ptile),hl
        ld hl,moves
        inc (hl)
        ld hl,SFX_MOVE
        ld a,3
        call sfx
        call fx_wipe
        xor a
        ld (warned),a
        ld a,25
        ld (drain_t),a
        ld hl,MSG_MOVED
        call hud_msg
        ld a,12
        ld (ccy),a
        ld a,20
        ld (ccx),a
        ld a,1
        ld (need_render),a
        ret

; the Lantern's tile is in view: put its light out
lantern_out:
        ld (hl),0
        call fx_target_sparkle
        ld hl,SFX_BOOM
        ld a,3
        call sfx
        call fx_flash
        ld a,6
        call add_energy
        ld hl,500
        ld de,(score)
        add hl,de
        ld (score),hl
        ld a,R_CLEAR
        ld (result),a
        ret

; ---------------------------------------------------------------------
; the Lantern
; ---------------------------------------------------------------------
update_beam:
        ld hl,(beam_t)
        dec hl
        ld (beam_t),hl
        ld a,h
        or l
        ret nz
        ld hl,(beam_period)
        ld (beam_t),hl
        ld a,(beam)
        ld c,a
        inc a
        and 7
        ld (beam),a
        ld b,a
        xor a
        ld (warned),a
        ld hl,SFX_SWEEP
        ld a,1
        call sfx
        call hud_compass
        ld a,c                      ; redraw if either sector shows in the view
        or 88h
        ld c,a
        ld a,b
        or 88h
        ld b,a
        ld hl,TILEF
        ld de,1024
.s:     ld a,(hl)
        and 8Fh
        cp c
        jr z,.re
        cp b
        jr z,.re
        inc hl
        dec de
        ld a,d
        or e
        jr nz,.s
        ld a,(beam)
        or 8
        ld (beamcode),a
        ret
.re:    ld a,1
        ld (need_render),a
        ret

update_lit:
        ld hl,(ptile)
        call tf_addr
        ld a,(hl)
        and 0Fh
        ld c,a
        ld a,(beam)
        or 8
        cp c
        jr z,.lit
        ; next sector coming?
        inc a
        and 7
        or 8
        cp c
        jr nz,.dark
        ld a,(warned)
        or a
        jr nz,.dark
        inc a
        ld (warned),a
        ld hl,SFX_WARN
        ld a,2
        call sfx
        ld hl,MSG_APPROACH
        call hud_msg
.dark:  ld a,(lit)
        or a
        ld a,0
        ld (lit),a
        call nz,hud_compass
        ld a,25
        ld (drain_t),a
        ret
.lit:   ld a,(lit)
        or a
        jr nz,.on
        inc a
        ld (lit),a
        ld hl,MSG_SEEN
        call hud_msg
        call hud_compass
.on:    ld hl,drain_t
        dec (hl)
        ret nz
        ld (hl),40
        ld a,(energy)
        or a
        jr z,.dead
        dec a
        ld (energy),a
        call hud_energy
        call fx_drain
        ld hl,SFX_DRAIN
        ld a,2
        jp sfx
.dead:  ld a,R_LOST
        ld (result),a
        ret

; ---------------------------------------------------------------------
; wisps: every few seconds one drifts a tile towards the player; next to
; the player it steals a unit of energy and darts away
; ---------------------------------------------------------------------
update_wisps:
        ld a,(nwisps)
        or a
        ret z
        ld hl,(wisp_t)
        dec hl
        ld (wisp_t),hl
        ld a,h
        or l
        ret nz
        ld hl,200
        ld (wisp_t),hl
        ; pick the k-th wisp
        call rng
        and 3
        ld b,a
        ld a,(nwisps)
        ld c,a
.mod:   ld a,b
        cp c
        jr c,.k
        sub c
        ld b,a
        jr .mod
.k:     ld hl,OBJ
.f:     ld a,(hl)
        and 7
        cp O_WISP
        jr nz,.nf
        ld a,b
        or a
        jr z,.got
        dec b
.nf:    inc hl
        ld a,h
        cp high OBJ+4
        jr c,.f
        ret
.got:   ld de,-OBJ
        add hl,de
        ld (wsrc),hl
        call tile_xy
        ; step towards the player (random wobble)
        push de
        ld hl,(ptile)
        call tile_xy
        ld a,e
        ld (wpx),a
        ld a,d
        ld (wpy),a
        pop de
        call rng
        and 3
        jr nz,.toward
        call rng                    ; 1 in 4: random sideways step
        and 1
        add a,a
        dec a
        add a,e
        ld e,a
        jr .try
.toward:
        ld a,(wpx)
        cp e
        jr z,.ty
        jr c,.xm
        inc e
        jr .ty
.xm:    dec e
.ty:    ld a,(wpy)
        cp d
        jr z,.try
        jr c,.ym
        inc d
        jr .try
.ym:    dec d
.try:   ld a,e
        cp 32
        ret nc
        ld a,d
        cp 32
        ret nc
        call tile_of
        call tile_flat_level
        or a
        ret z
        ld de,(ptile)
        or a
        sbc hl,de
        add hl,de
        jr nz,.free
        ld hl,(wsrc)
        ld (wdst),hl
        jr .steal
.free:  push hl
        call obj_addr
        ld a,(hl)
        and 7
        pop hl
        ret nz
        call wisp_move
        ; next to the player?
        ld hl,(wdst)
        call tile_xy
        ld a,(wpx)
        sub e
        call absa
        cp 2
        ret nc
        ld a,(wpy)
        sub d
        call absa
        cp 2
        ret nc
.steal: ld a,(energy)
        or a
        jr z,.away
        dec a
        ld (energy),a
        call hud_energy
.away:  ld hl,SFX_DRAIN
        ld a,2
        call sfx
        ld hl,MSG_WISP
        call hud_msg
        call fx_drain
        ld hl,(wdst)                ; dart away
        call obj_addr
        ld a,(hl)
        and 0F0h
        ld (hl),a
        ld hl,(wsrc)
        call obj_addr
        ld a,(hl)
        and 0F0h
        ld (hl),a
        ld a,O_WISP
        call place_random
        ld a,1
        ld (need_render),a
        ret

; move the wisp from wsrc to tile HL
wisp_move:
        ld (wdst),hl
        call obj_addr
        ld a,(hl)
        or O_WISP
        ld (hl),a
        ld hl,(wsrc)
        call obj_addr
        ld a,(hl)
        and 0F0h
        ld (hl),a
        ld hl,(wsrc)                ; redraw only if seen
        call tf_addr
        bit 7,(hl)
        jr nz,.re
        ld hl,(wdst)
        call tf_addr
        bit 7,(hl)
        ret z
.re:    ld a,1
        ld (need_render),a
        ret
