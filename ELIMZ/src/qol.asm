; =====================================================================
;  qol.asm - pause, sound on/off, auto-dock, saving the pilot to tape,
;  hyperspace ambushes
; =====================================================================

; ---------------------------------------------------------------------
; extra keys (new presses): bit 0 P pause, 1 S sound, 2 D auto-dock
; ---------------------------------------------------------------------
extra_keys:
        bit 0,a
        push af
        call nz,do_pause
        pop af
        bit 1,a
        push af
        call nz,toggle_sound
        pop af
        bit 2,a
        ret z
        jp toggle_autodock

; NZ while CTRL is held
ctrlkey:
        ld a,8
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        and 40h
        ret

; frozen (CTRL, as CAPS SHIFT on the Spectrum): Q sound off, S sound on,
; CTRL or SPACE to go on
do_pause:
        ld hl,txt_paused
        call message
        call sfx_stop
        ld a,(snd_mute)
        ld (pz_mute),a
        ld a,1                          ; quiet while frozen
        ld (snd_mute),a
.r1:    call poll
        call ctrlkey
        jr nz,.r1
.w:     call poll
        ld a,2                          ; Q (bit 7), S (bit 5)
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        bit 7,a
        jr z,.nq
        ld a,1
        ld (pz_mute),a
        ld hl,txt_sndoff
        call message
.nq:    ld a,2
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        bit 5,a
        jr z,.ns
        xor a
        ld (pz_mute),a
        ld hl,txt_sndon
        call message
.ns:    call ctrlkey
        jr nz,.go
        ld a,6                          ; SPACE
        ld (KEYPA),a
        ld a,(KEYPB)
        bit 4,a
        jr nz,.w
.go:    call wait_release
        ld a,(pz_mute)
        ld (snd_mute),a
        ld hl,txt_resume
        jp message

toggle_sound:
        ld hl,snd_mute
        ld a,(hl)
        xor 1
        ld (hl),a
        ld hl,txt_sndon
        jr z,$+5
        ld hl,txt_sndoff
        push hl
        call sfx_stop
        pop hl
        jp message

txt_paused:     db "PAUSED: CTRL GOES ON  Q/S SOUND OFF/ON",0
txt_resume:     db "AS YOU WERE",0
txt_sndon:      db "SOUND ON",0
txt_sndoff:     db "SOUND OFF",0

; ---------------------------------------------------------------------
; auto-dock: the computer flies us in (with music)
; ---------------------------------------------------------------------
toggle_autodock:
        ld a,(autodock)
        or a
        jr nz,autodock_off
        ld a,(has_autodock)
        or a
        ld hl,txt_nodock
        jp z,message
        ld a,1
        ld (autodock),a
        ld hl,TRK_WALTZ
        call trk_play
        ld hl,txt_dockon
        jp message
autodock_off:
        xor a
        ld (autodock),a
        call mus_stop
        ld hl,txt_dockoff
        jp message

; called from controls while auto-dock is on: replaces (keys)
dock_pilot:
        ld a,(keys)                     ; touching the controls cancels it
        and K_DIRS+K_FAST+K_SLOW
        jr nz,autodock_off
        ld ix,objects
        ld c,0
        call steer
        jr nc,.set
        ld ix,objects                   ; close enough: the computer finishes
        call obj_dist
        ld de,900
        or a
        sbc hl,de
        jr nc,.far
        ld a,1
        ld (state),a
        xor a
        ld (autodock),a
        ret
.far:   ld de,900-3000
        add hl,de                       ; HL = dist - 3000
        ld a,(speed)
        ld b,28
        jr c,$+4
        ld b,12
        cp b
        jr z,.set
        jr nc,.slower
        set 5,c
        jr .set
.slower:
        set 6,c
.set:   ld a,c
        ld (keys),a
        ret

txt_nodock:     db "NO AUTO-DOCK FITTED",0
txt_dockon:     db "AUTO-DOCK ENGAGED",0
txt_dockoff:    db "AUTO-DOCK OFF",0

; ---------------------------------------------------------------------
; saving the pilot: a small block written with the monitor's tape
; routines (works with UniCMT as a normal tape file)
; ---------------------------------------------------------------------
TAPE_HDR        equ 10F0h
WRINF           equ 0021h
WRDAT           equ 0024h
RDINF           equ 0027h
RDDAT           equ 002Ah
SAVE_LEN        equ 2+3+1+2+10+10+1+1

; what goes into the save block: address, length
SAVE_MAP:
        dw credits
        db 3
        dw fuel
        db 1
        dw cur_sys
        db 2
        dw cargo
        db 10
        dw seekers
        db 10
        dw kills
        db 1
        dw hull
        db 1
        dw 0

pilot_name:     db "ARGOSY PILOT",0Dh
PILOT_NAME_LEN  equ $-pilot_name

; copy pilot vars <-> save_buf ; A = 0 pack, 1 unpack
pack_pilot:
        ld (pk_dir),a
        ld de,save_buf+2
        ld hl,SAVE_MAP
.m:     ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,b
        or c
        ret z
        ld a,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c                          ; HL = variable
        ld c,a
        ld b,0
        ld a,(pk_dir)
        or a
        jr nz,.un
        ldir                            ; vars -> buffer
        jr .nx
.un:    ex de,hl                        ; buffer -> vars
        ldir
        ex de,hl
.nx:    pop hl
        jr .m

tape_header:
        ld hl,TAPE_HDR
        ld (hl),1                       ; a binary file
        inc hl
        ex de,hl
        ld hl,pilot_name
        ld bc,PILOT_NAME_LEN
        ldir
        ld hl,SAVE_LEN
        ld (TAPE_HDR+12h),hl
        ld hl,save_buf
        ld (TAPE_HDR+14h),hl
        ld hl,0
        ld (TAPE_HDR+16h),hl
        ret

; save_pilot / load_pilot: C on failure (BREAK, tape error, wrong file)
save_pilot:
        xor a
        call pack_pilot
        ld hl,"SH"
        ld (save_buf),hl
        call tape_header
        call WRINF
        jr c,.x
        call WRDAT
.x:     push af
        call tape_done
        pop af
        ret

load_pilot:
        call RDINF
        jr c,.bad
        ld hl,TAPE_HDR+1                ; is it ours?
        ld de,pilot_name
        ld b,PILOT_NAME_LEN
.c:     ld a,(de)
        cp (hl)
        jr nz,.wrong
        inc hl
        inc de
        djnz .c
        ld hl,save_buf
        ld (TAPE_HDR+14h),hl
        ld hl,SAVE_LEN
        ld (TAPE_HDR+12h),hl
        call RDDAT
        jr c,.bad
        ld hl,(save_buf)
        ld de,"SH"
        or a
        sbc hl,de
        jr nz,.wrong
        ld a,1
        call pack_pilot
        call apply_hull                 ; its ship's figures
        call tape_done
        or a
        ret
.wrong: scf
.bad:   push af
        call tape_done
        pop af
        scf
        ret

; after the monitor's tape code: our timer and sound back as they were
tape_done:
        call snd_fe
        call timer_init
        ld a,1
        ld (cr_dirty),a
        ret

; screens: "press record" style prompt on row C, then run HL
tape_screen:
        push hl
        ld a,WHITE<<4
        call cls
        pop hl
        push hl
        ld c,10
        ld a,YELLOW<<4
        call print_centre
        ld hl,txt_tapehint
        ld c,13
        ld a,CYAN<<4
        call print_centre
        pop hl
        ret

txt_saving:     db "SAVING PILOT - PRESS RECORD/PLAY",0
txt_loading:    db "LOADING PILOT - PRESS PLAY",0
txt_tapehint:   db "BREAK TO CANCEL",0
txt_tapeok:     db "DONE",0
txt_tapebad:    db "TAPE ERROR OR NOT A PILOT FILE",0

; docked menu: S save / L load.  Shows the result for a moment.
menu_save:
        ld hl,txt_saving
        call tape_screen
        call mus_stop
        call save_pilot
        jr tape_result
menu_load:
        ld hl,txt_loading
        call tape_screen
        call mus_stop
        call load_pilot
tape_result:
        ld a,0
        jr c,$+3
        inc a
        ld (tape_ok),a
        or a
        ld hl,SFX_SAVE
        ld a,5
        call nz,sfx
        ld hl,txt_tapeok
        ld a,(tape_ok)
        or a
        ld a,GREEN<<4
        jr nz,$+7
        ld hl,txt_tapebad
        ld a,RED<<4
        ld c,16
        call print_centre
        ld a,100
        jp wait_fields

; ---------------------------------------------------------------------
; hyperspace ambush: pirates waiting at the far end
; ---------------------------------------------------------------------
do_ambush:
        xor a
        ld (ambush),a
        ld b,2
.p:     push bc
        call find_free
        pop bc
        ret nc
        push bc
        push iy
        pop ix
        ld (ix+O_FLAG),0
        ld (ix+O_TMR),0
        ld (ix+O_EV),0
        ld (ix+O_CD),40
        ld (ix+O_AIM),0
        ld (ix+O_TYPE),T_DART
        ld (ix+O_SPD),14
        ld (ix+O_HP),2
        ld a,b
        dec a
        jr nz,.d
        ld (ix+O_TYPE),T_MANTIS
        ld (ix+O_SPD),11
        ld (ix+O_HP),4
        ld (ix+O_AIM),1
.d:     call ori_toward
        call rand                       ; somewhere ahead, close
        ld e,a
        call sext_e
        ex de,hl
        add hl,hl
        add hl,hl
        ld (ix+O_X),l
        ld (ix+O_X+1),h
        ld (ix+O_Y),100
        ld (ix+O_Y+1),0
        ld hl,1700
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        pop bc
        djnz .p
        ld hl,SFX_ALARM
        ld a,6
        call sfx
        ld hl,txt_ambush
        jp message

txt_ambush:     db "AMBUSH! PIRATES WERE WAITING",0
