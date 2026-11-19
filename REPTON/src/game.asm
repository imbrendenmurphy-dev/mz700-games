; =====================================================================
;  game.asm - game flow: new game, the play loop, regions, transporters,
;  switches, death and region reset
; =====================================================================

; ---------------------------------------------------------------------
; game: a new game (A = 1) or a game loaded from tape (A = 2)
; ---------------------------------------------------------------------
game:
        cp 2
        jr nz,.new
        call tape_load
        ret nz
        call resume_world
        jr .go
.new:   call new_world
.go:    xor a
        ld (demo),a
        ld hl,0
        ld (replay_ptr),hl
        call mus_stop
        call play
        ld a,(won)
        or a
        jp nz,ending
        call sfx_stop
        call record_entry
        ld hl,SONG_TITLE
        jp mus_play

; demo_game: the attract-mode demo replays the start of the solution
demo_game:
        call new_world
        ld a,1
        ld (demo),a
        ld hl,DEMO_DATA
        ld (replay_ptr),hl
        xor a
        ld (replay_cnt),a
        ld (replay_done),a
        call play
        xor a
        ld (demo),a
        ld hl,0
        ld (replay_ptr),hl
        ret

; new_world: every region from the packed maps, the player at the start
new_world:
        call unpack_all
        ld hl,save_start
        ld de,save_start+1
        ld bc,save_end-save_start-1
        ld (hl),0
        ldir
        ld hl,5348h                 ; "SH"
        ld (save_magic),hl
        xor a
        ld (won),a
        ld a,START_REGION
        ld de,START_POS
        jp enter_region

; resume_world: the world and state came from tape; the player is in it
resume_world:
        xor a
        ld (won),a
        ld a,(region)
        call set_region
        ld de,(pl_pos)
        ld hl,(rbase)
        add hl,de
        ld (pl_addr),hl
        call take_snapshot
        jp recount

; set_region: A = region -> region, rbase, theme
set_region:
        ld (region),a
        push af
        call region_addr
        ld (rbase),hl
        pop af
        call region_hdr
        ld a,(hl)
        ld (theme),a
        ret

; enter_region: A = region, DE = position.  Puts the player there, takes
; the snapshot that death returns to.
enter_region:
        push de
        call set_region
        pop de
        ld (pl_pos),de
        ld (entry_pos),de
        ld hl,(rbase)
        add hl,de
        ld (pl_addr),hl
        ld (hl),E_PLAYER
        ; visited bit
        ld a,(region)
        ld c,a
        srl a
        srl a
        srl a
        ld e,a
        ld d,0
        ld hl,visited
        add hl,de
        ld a,c
        and 7
        ld b,a
        inc b
        ld a,80h
.bit:   rlca
        djnz .bit
        or (hl)
        ld (hl),a
        call take_snapshot
        call recount
        xor a
        ld (pl_dead),a
        ld (pl_moved),a
        ld a,3
        ld (pl_face),a
        jp camera

take_snapshot:
        ld hl,(rbase)
        ld de,SNAP
        ld bc,RSZ
        ldir
        ret

; ---------------------------------------------------------------------
; play: the main loop.  Returns when the game is won, quit, or (in the
; demo) when the replay ends or a key is pressed.
; ---------------------------------------------------------------------
play:
        xor a
        ld (quit),a
        ld (frame_ctr),a
        ld (msg_time),a
        ld (latch),a
        call show_view
        call fe_reset
.loop:
        ld a,(turbo)
        or a
        call z,wait_frame
        ld hl,anim
        inc (hl)
        call input_frame
        ld a,(demo)
        or a
        jr z,.human
        call anykey
        jr z,.tick
        ld a,1
        ld (demo_abort),a
        jp sfx_stop
.human: call extra_keys
        ld a,(quit)
        or a
        jp nz,sfx_stop
.tick:  ld a,(turbo)
        or a
        jr nz,.t
        ld hl,frame_ctr
        inc (hl)
        ld a,(hl)
        cp TICKF
        jr c,.notick
        ld (hl),0
.t:     call game_tick
        ld a,(won)
        or a
        ret nz
        ld a,(demo)
        or a
        jr z,.notick
        ld a,(replay_done)
        or a
        ret nz
.notick:
        call clock
        call msg_tick
        call render
        ld a,(hud_dirty)
        or a
        call nz,hud_draw
        jr .loop

; full redraw of the play screen with a reveal
show_view:
        ld a,BLACK*16+BLACK
        call cls
        call camera
        call hud_draw
        jp reveal_view

; play time: a second every 50 fields
clock:
        ld a,(demo)
        or a
        ret nz
        ld hl,sec_frames
        inc (hl)
        ld a,(hl)
        cp 50/FRAMEF
        ret c
        ld (hl),0
        ld hl,ptime+2
        inc (hl)
        ld a,(hl)
        cp 60
        ret c
        ld (hl),0
        dec hl
        inc (hl)
        ld a,(hl)
        cp 60
        ret c
        ld (hl),0
        dec hl
        inc (hl)
        ret

; ---------------------------------------------------------------------
; game_tick: input, the physics scan, then whatever the player set off
; ---------------------------------------------------------------------
game_tick:
        xor a
        ld (pl_moved),a
        ld (pl_gate),a
        ld hl,0
        ld (pl_trans),hl
        ld (pl_switch),hl
        call tick_input
tick_hook:                          ; (the test harness feeds tick_dir here)
        call region_scan
        ld a,(pl_dead)
        or a
        jp nz,death
        ld hl,(pl_trans)
        ld a,h
        or l
        call nz,do_transport
        ld hl,(pl_switch)
        ld a,h
        or l
        call nz,do_switch
        ld a,(pl_gate)
        or a
        call nz,do_gate
        jp camera

; ---------------------------------------------------------------------
; transporters
; ---------------------------------------------------------------------
do_transport:
        call find_trans
        ret nz
        ld a,(ix+3)
        call region_addr
        ld e,(ix+4)
        ld d,(ix+5)
        add hl,de
        ld a,(hl)
        and 3Fh
        cp E_EARTH+1
        jr c,.ok
        ld hl,txt_blocked
        call msg_set
        ld hl,SFX_BUMP
        ld a,3
        jp sfx
.ok:    push ix
        ld hl,(pl_addr)
        ld (hl),E_SPACE
        ld hl,SFX_TRANS
        ld a,7
        call sfx
        call render
        call cover_view
        pop ix
        ld a,(ix+3)
        ld e,(ix+4)
        ld d,(ix+5)
        call enter_region
        call show_view
        ld hl,SONG_ENTER
        jp mus_play

; ---------------------------------------------------------------------
; switches: open the barriers they are wired to (maybe far away)
; ---------------------------------------------------------------------
do_switch:
        call find_switch
        ret nz
        ld hl,(sw_flags)            ; flag bit B
        ld de,1
        inc b
        jr .s1
.s0:    sla e
        rl d
.s1:    djnz .s0
        ld a,l
        or e
        ld l,a
        ld a,h
        or d
        ld h,a
        ld (sw_flags),hl
        ld hl,(pl_switch)
        ld (hl),E_SWITCHON
        push ix
        call clear_rect
        pop ix
        ; "GATES OPEN IN <region>"
        ld hl,PBUF
        ld de,txt_opened
        call strcpy
        push hl
        ld a,(ix+3)
        call region_hdr
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        call strcpy
        ld (hl),0
        ld hl,PBUF
        call msg_set
        ld hl,SFX_SWITCH
        ld a,6
        jp sfx

; HL = dest, DE = source (0-terminated): copies without the 0, HL = end
strcpy:
        ld a,(de)
        or a
        ret z
        ld (hl),a
        inc hl
        inc de
        jr strcpy

do_gate:
        ld a,(done_flag)
        or a
        jr z,.shut
        ld a,1
        ld (won),a
        ret
.shut:  ld hl,txt_sealed
        call msg_set
        ld hl,SFX_BUMP
        ld a,3
        jp sfx

; ---------------------------------------------------------------------
; death: the region goes back to how it was when the player came in
; ---------------------------------------------------------------------
death:
        ld hl,(deaths)
        inc hl
        ld (deaths),hl
        ld hl,SFX_DEATH
        ld a,9
        call sfx
        ld b,30
.anim:  push bc
        ld a,(turbo)
        or a
        call z,wait_frame
        ld hl,anim
        inc (hl)
        call render
        pop bc
        djnz .anim
        ld a,(turbo)
        or a
        call z,cover_view
        call restore_region
        xor a
        ld (pl_dead),a
        ld a,(turbo)
        or a
        ret nz
        jp show_view

restore_region:
        ld hl,SNAP
        ld de,(rbase)
        ld bc,RSZ
        ldir
        ld a,(region)
        call fixup
        ld de,(entry_pos)
        ld (pl_pos),de
        ld hl,(rbase)
        add hl,de
        ld (pl_addr),hl
        ld a,3
        ld (pl_face),a
        call recount
        jp camera

; reset_region: the region as it was at the start of the game
reset_region:
        ld a,(region)
        call unpack_region
        ld a,(region)
        call fixup
        ld de,(entry_pos)
        ld (pl_pos),de
        ld hl,(rbase)
        add hl,de
        ld (pl_addr),hl
        ld (hl),E_PLAYER
        call take_snapshot
        call recount
        jp camera

; ---------------------------------------------------------------------
; keys during play: SPACE status, R reset, CR pause, BREAK quit
; ---------------------------------------------------------------------
extra_keys:
        ld a,(key_extra)
        ld b,a
        ld a,(xprev)
        cpl
        and b                       ; newly pressed
        ld c,a
        ld a,b
        ld (xprev),a
        ld a,(key_quit)
        or a
        jr z,.nq
        ld hl,txt_askquit
        call ask_yes
        ret nz
        ld a,1
        ld (quit),a
        ret
.nq:    ld a,(key_pause)
        or a
        jr z,.np
        call pause
        ret
.np:    bit 0,c
        jr z,.ns
        call status_screen
        jp show_view
.ns:    bit 1,c
        ret z
        ld hl,txt_askreset
        call ask_yes
        ret nz
        call cover_view
        call reset_region
        jp show_view

; ask_yes: HL = question on the HUD row; Z if Y was pressed
ask_yes:
        push hl
        call sfx_stop
        ld b,HUDROW
        ld c,1
        ld a,RED*16+BLACK
        call clear_rows
        pop hl
        ld c,HUDROW
        ld a,WHITE*16+RED
        call print_centre
        call wait_release
.w:     call wait_field
        call anykey
        jr z,.w
        call read_keys
        ld a,(key_extra)
        bit 4,a                     ; Y
        jr nz,.yes
        call wait_release
        ld a,1
        ld (hud_dirty),a
        or a
        ret
.yes:   call wait_release
        ld a,1
        ld (hud_dirty),a
        xor a
        ret

pause:
        call wait_release
        ld b,HUDROW
        ld c,1
        ld a,BLUE*16+BLACK
        call clear_rows
        ld hl,txt_paused
        ld c,HUDROW
        ld a,WHITE*16+BLUE
        call print_centre
.w:     call wait_field
        call anykey
        jr z,.w
        call wait_release
        ld a,1
        ld (hud_dirty),a
        ret
