; =====================================================================
;  attract.asm - the attract sequence: AI demo pilot, ship gallery,
;  pilot's handbook
; =====================================================================
DEMO_FRAMES     equ 900                 ; about a minute of demo flight

; ---------------------------------------------------------------------
; demo: a fresh pilot in a lawless system, flown by the AI.
; NZ if a key cut it short.
; ---------------------------------------------------------------------
demo:
        call new_game
        ld a,DEMO_SYS
        ld (cur_sys),a
        ld (target_sys),a
        ld a,3
        ld (seekers),a
        ld a,1
        ld (autoplay),a
        ld (arrive),a
        ld (has_twin),a
        ld (has_jammer),a
        ld hl,DEMO_FRAMES
        ld (demo_t),hl
        call wait_release
        call flight
        push af
        xor a
        ld (autoplay),a
        ld (demo_keys),a
        call sfx_stop
        pop af
        cp 3
        jr z,.key
        xor a
        ret
.key:   call wait_release
        or 1
        ret

; ---------------------------------------------------------------------
; pilot: choose the demo's keys for this frame
; ---------------------------------------------------------------------
pilot:
        ld c,0
        xor a
        ld (mkey),a
        ; an incoming seeker close by: jam it
        ld ix,objects+OBJSZ
        ld b,MAXOBJ-1
.sk:    push bc
        ld a,(ix+O_TYPE)
        cp T_SEEKER
        jr nz,.nsk
        ld a,(ix+O_AIM)
        inc a
        jr nz,.nsk
        call obj_dist
        ld de,1200
        or a
        sbc hl,de
        jr nc,.nsk
        ld a,40h
        ld (mkey),a
.nsk:   ld de,OBJSZ
        add ix,de
        pop bc
        djnz .sk
        ; target: the nearest pirate, hostile Warden or asteroid
        ld hl,7FFFh
        ld (pl_best),hl
        ld hl,0
        ld (pl_obj),hl
        ld ix,objects+OBJSZ
        ld b,MAXOBJ-1
.o:     push bc
        ld a,(ix+O_TYPE)
        cp T_DART
        jr c,.n
        cp T_SEEKER
        jr nc,.n
        cp T_HAULER
        jr z,.n
        cp T_WARDEN
        jr nz,.cand
        bit 1,(ix+O_FLAG)
        jr z,.n
.cand:  call obj_dist
        ld de,(pl_best)
        or a
        sbc hl,de
        jr nc,.n
        add hl,de
        ld (pl_best),hl
        ld (pl_obj),ix
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ld hl,(pl_obj)
        ld a,h
        or l
        jr nz,.hunt
        ld a,(speed)                    ; nothing to hunt: cruise
        cp 16
        jr nc,.k
        set 5,c
.k:     ld a,c
        ld (demo_keys),a
        ret
.hunt:  push hl
        pop ix
        call steer
        jr nc,.k                        ; behind us: just turn
        ; speed: close in, then hold off
        ld hl,(pl_z)
        ld de,-1400
        add hl,de
        jr nc,.slow
        ld a,(speed)
        cp 22
        jr nc,.fire
        set 5,c
        jr .fire
.slow:  ld hl,(pl_z)
        ld de,-500
        add hl,de
        jr c,.fire
        ld a,(speed)
        cp 7
        jr c,.fire
        set 6,c
.fire:  call lined_up
        jr nc,.k
        set 4,c
        ld a,(ix+O_TYPE)                ; a warlord: send a seeker too
        cp T_RAPTOR
        jr nz,.k
        ld a,(mkey)
        or 08h
        ld (mkey),a
        jr .k

; C set if IX is in the sights: z < 2600, |x|, |y| < z/12 or so
lined_up:
        ld hl,(pl_z)
        ld de,-2600
        add hl,de
        ccf
        ret nc
        ld hl,(pl_thr)
        ld de,-4
        add hl,de
        ld d,h
        ld e,l
        srl h
        rr l
        srl h
        rr l
        add hl,de
        ex de,hl
        ld hl,(pl_x)
        call abs_hl
        or a
        sbc hl,de
        ret nc
        ld hl,(pl_y)
        call abs_hl
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------------
; steer: add roll / pitch key bits to C that turn us towards IX.
; NC if it is behind us (then we just loop round).  Sets pl_x, pl_y,
; pl_z, pl_thr.
; ---------------------------------------------------------------------
steer:
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        ld (pl_z),hl
        ld e,(ix+O_X)
        ld d,(ix+O_X+1)
        ld (pl_x),de
        ld e,(ix+O_Y)
        ld d,(ix+O_Y+1)
        ld (pl_y),de
        bit 7,h
        jr z,.ahead
        set 3,c                         ; behind us: climb round
        ld a,(pl_x+1)
        rla
        jr c,$+6
        set 1,c
        or a
        ret
        set 0,c
        or a
        ret
.ahead: ld b,4                          ; thr = z/16 + 4
.t:     srl h
        rr l
        djnz .t
        ld de,4
        add hl,de
        ld (pl_thr),hl
        ld hl,(pl_x)                    ; roll it above / below the sights
        call abs_hl
        ld de,(pl_thr)
        or a
        sbc hl,de
        jr c,.noroll
        ld a,(pl_x+1)
        ld b,(ix+O_Y+1)
        xor b
        rla
        jr c,.rl
        set 1,c
        jr .noroll
.rl:    set 0,c
.noroll:
        ld hl,(pl_y)                    ; then pitch onto it
        ld de,(pl_thr)
        bit 7,h
        jr nz,.below
        or a
        sbc hl,de
        jr c,.np
        set 3,c
        jr .np
.below: add hl,de
        jr c,.np
        set 2,c
.np:    scf
        ret

; ---------------------------------------------------------------------
; gallery: the ships of the spacelanes, one by one.  NZ on a key.
; ---------------------------------------------------------------------
gallery:
        call snd_fl                     ; the waltz plays on
        ld a,WHITE<<4
        call cls
        ld b,0
        ld c,1
        ld a,YELLOW<<4+BLUE
        call clear_rows
        ld hl,txt_gallery
        ld c,0
        ld a,YELLOW<<4+BLUE
        call print_centre
        ld a,1
        ld (state),a
        ld hl,GALLERY
.ship:  ld a,(hl)
        or a
        ret z
        ld (gal_ptr),hl
        ld b,SEP_ROW+1
        ld c,4
        ld a,WHITE<<4
        push hl
        call clear_rows
        pop hl
        ld a,(hl)                       ; type
        inc hl
        ld ix,objects
        push hl
        push af
        ld hl,objects
        ld de,objects+1
        ld bc,MAXOBJ*OBJSZ-1
        ld (hl),0
        ldir
        pop af
        ld (ix+O_TYPE),a
        ld e,a
        ld d,0
        ld hl,TYPE_COL-1
        add hl,de
        ld a,(hl)
        ld (gal_col),a
        call ori_forward
        pop hl
        ld a,(hl)                       ; distance / 2
        inc hl
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        ex de,hl
        ld c,SEP_ROW+1                  ; name, then two lines of notes
        ld a,YELLOW<<4
        call .line
        ld c,SEP_ROW+3
        ld a,CYAN<<4
        call .line
        ld c,SEP_ROW+4
        ld a,CYAN<<4
        call .line
        ld (gal_ptr),hl
        ld a,90
        ld (gal_t),a
.spin:  call wait_frame
        ld ix,objects
        ld a,5
        call roll_to_side
        ld a,6
        call pitch_up
        ld a,(gal_col)
        call set_col
        call draw_obj
        call present
        call anykey
        jr nz,.key
        ld hl,gal_t
        dec (hl)
        jr nz,.spin
        ld hl,(gal_ptr)
        jp .ship
.key:   call wait_release
        or 1
        ret
; print the string at HL centred on row C, attr A; HL -> next string
.line:  push hl
        push af
        push bc
        call print_centre
        pop bc
        pop af
        pop hl
.skip:  ld a,(hl)
        inc hl
        or a
        jr nz,.skip
        ret

; type, distance/2, name, two lines of notes
GALLERY:
        db T_DART,110
        db "DART",0,"LIGHT PIRATE INTERCEPTOR",0,"FAST, FRAGILE.  BOUNTY 15 CR",0
        db T_MANTIS,115
        db "MANTIS",0,"PIRATE GUNSHIP",0,"CARRIES A SEEKER.  BOUNTY 25 CR",0
        db T_RAPTOR,150
        db "RAPTOR",0,"PIRATE WARLORD",0,"LAWLESS SPACE ONLY.  BOUNTY 60 CR",0
        db T_HAULER,140
        db "HAULER",0,"BULK TRADER",0,"HARMLESS - LEAVE IT ALONE",0
        db T_WARDEN,110
        db "WARDEN",0,"SYSTEM POLICE",0,"FIRE ON ONE AND THEY ALL HUNT YOU",0
        db T_ROCK,110
        db "ASTEROID",0,"DRIFTING ROCK",0,"SHOOT IT, SCOOP THE ORE",0
        db T_STATION,200
        db "ORBITAL HUB",0,"STATION",0,"FLY INTO THE SLOT TO DOCK",0
        db 0

txt_gallery:    db "SHIPS OF THE SPACELANES",0

; ---------------------------------------------------------------------
; handbook: controls and tips.  NZ on a key.
; ---------------------------------------------------------------------
handbook:
        call snd_fl
        ld a,WHITE<<4
        call cls
        ld b,0
        ld c,1
        ld a,YELLOW<<4+BLUE
        call clear_rows
        ld hl,HANDBOOK
.l:     ld a,(hl)
        cp 0FFh
        jr z,.wait
        ld c,a
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call print_centre
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        jr .l
.wait:  ld b,0
.w:     push bc
        call wait_field
        call anykey
        pop bc
        jr nz,.key
        djnz .w
        ld b,150
.w2:    push bc
        call wait_field
        call anykey
        pop bc
        jr nz,.key
        djnz .w2
        xor a
        ret
.key:   call wait_release
        or 1
        ret

HANDBOOK:
        db 0,YELLOW<<4+BLUE,"PILOT'S HANDBOOK",0
        db 2,CYAN<<4,"CURSORS   ROLL AND PITCH",0
        db 3,CYAN<<4,"A / Z     FASTER / SLOWER",0
        db 4,CYAN<<4,"SPACE     LASERS (MIND THE HEAT)",0
        db 5,CYAN<<4,"M         SEEKER AT THE TARGET",0
        db 6,CYAN<<4,"J         JAMMER PULSE",0
        db 7,CYAN<<4,"H         HYPERSPACE TO THE TARGET",0
        db 8,CYAN<<4,"D         AUTO-DOCK (IF FITTED)",0
        db 9,CYAN<<4,"P / S     PAUSE / SOUND ON-OFF",0
        db 11,WHITE<<4,"BUY LOW ON FARMWORLDS, SELL HIGH",0
        db 12,WHITE<<4,"TO INDUSTRY - AND THE REVERSE.",0
        db 13,WHITE<<4,"PIRATES PAY BOUNTIES.  TRADERS",0
        db 14,WHITE<<4,"AND POLICE DO NOT - SHOOT THEM",0
        db 15,WHITE<<4,"AND THE LAW WILL HUNT YOU.",0
        db 17,GREEN<<4,"DOCK: LINE UP WITH THE SLOT AND",0
        db 18,GREEN<<4,"FLY STRAIGHT IN, NOT TOO FAST.",0
        db 20,MAGENTA<<4,"RANKS: CADET PILOT GUNNER VETERAN",0
        db 21,MAGENTA<<4,"ACE HOTSHOT LEGEND",0
        db 23,GREEN<<4,"PRESS SPACE TO LAUNCH",0
        db 0FFh
