; =====================================================================
;  combat.asm - seeker missiles, the jammer, police and the law,
;  the equipment shop and pilot rank
; =====================================================================
SEEKER_COST     equ 300                 ; tenths
MAXSEEK         equ 3

; ---------------------------------------------------------------------
; find_free: IY = a free object slot (1..7), C set if one was found
; ---------------------------------------------------------------------
find_free:
        ld iy,objects+OBJSZ
        ld b,MAXOBJ-1
.f:     ld a,(iy+O_TYPE)
        or a
        scf
        ret z
        ld de,OBJSZ
        add iy,de
        djnz .f
        or a
        ret

; HL = address of object A (0..7)
obj_addr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,objects
        add hl,de
        ret

; A = slot index of IX
obj_index:
        push ix
        pop hl
        ld de,-objects
        add hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        ret

; ---------------------------------------------------------------------
; player: M fires a seeker at the ship nearest the sights
; ---------------------------------------------------------------------
fire_seeker:
        ld a,(seekers)
        or a
        ld hl,txt_noseek
        jp z,message
        ld hl,0
        ld (hit_obj),hl
        ld hl,7FFFh
        ld (hit_z),hl
        ld ix,objects+OBJSZ
        ld b,MAXOBJ-1
.o:     push bc
        ld a,(ix+O_TYPE)
        cp T_DART
        jr c,.n
        cp T_SEEKER
        jr nc,.n
        call obj_screen
        jr nc,.n
        ld hl,(psx)
        ld de,-CX
        add hl,de
        call abs_hl
        ld de,14
        or a
        sbc hl,de
        jr nc,.n
        ld hl,(psy)
        ld de,-CY
        add hl,de
        call abs_hl
        ld de,10
        or a
        sbc hl,de
        jr nc,.n
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        ld de,(hit_z)
        or a
        sbc hl,de
        jr nc,.n
        add hl,de
        ld (hit_z),hl
        ld (hit_obj),ix
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ld hl,(hit_obj)
        ld a,h
        or l
        ld hl,txt_nolock
        jp z,message
        call find_free
        ret nc
        ld ix,(hit_obj)
        call obj_index
        ld (iy+O_AIM),a
        push iy
        pop ix
        ld b,(ix+O_AIM)
        call seeker_init
        ld (ix+O_AIM),b
        call ori_forward
        ld hl,-24
        ld (ix+O_Y),l
        ld (ix+O_Y+1),h
        ld (ix+O_X),0
        ld (ix+O_X+1),0
        ld (ix+O_Z),40
        ld (ix+O_Z+1),0
        ld (ix+O_SPD),24
        ld hl,seekers
        dec (hl)
        ld hl,txt_away
        call message
        ld hl,SFX_ZAP
        ld a,6
        jp sfx

; seeker setup shared by both sides: IX = new seeker
seeker_init:
        ld (ix+O_TYPE),T_SEEKER
        ld (ix+O_HP),1
        ld (ix+O_TMR),0
        ld (ix+O_FLAG),0
        ld (ix+O_CD),0
        ld (ix+O_EV),0
        ret

; pirate in IX launches a seeker at the player
pirate_seeker:
        call find_free
        ret nc
        dec (ix+O_AIM)
        push ix
        pop hl
        inc hl
        inc hl                          ; position and orientation
        push iy
        pop de
        inc de
        inc de
        ld bc,24
        ldir
        push ix
        push iy
        pop ix
        call seeker_init
        ld (ix+O_AIM),0FFh              ; target: us
        ld (ix+O_SPD),20
        pop ix
        ld hl,txt_incoming
        call message
        ld hl,SFX_ALARM
        ld a,7
        jp sfx

; ---------------------------------------------------------------------
; ai_seeker: steer hard at the target, blow up on contact
; ---------------------------------------------------------------------
ai_seeker:
        inc (ix+O_TMR)
        ld a,(ix+O_TMR)
        cp 160
        jp nc,explode                   ; out of fuel
        ld a,(ix+O_AIM)
        cp 0FFh
        jr z,.us
        call obj_addr
        push hl
        pop iy
        ld a,(iy+O_TYPE)                ; target gone?
        cp T_DART
        jp c,explode
        cp T_SEEKER
        jp nc,explode
        ld l,(iy+O_X)                   ; tin = target - pos
        ld h,(iy+O_X+1)
        ld e,(ix+O_X)
        ld d,(ix+O_X+1)
        or a
        sbc hl,de
        ld (tin),hl
        ld l,(iy+O_Y)
        ld h,(iy+O_Y+1)
        ld e,(ix+O_Y)
        ld d,(ix+O_Y+1)
        or a
        sbc hl,de
        ld (tin+2),hl
        ld l,(iy+O_Z)
        ld h,(iy+O_Z+1)
        ld e,(ix+O_Z)
        ld d,(ix+O_Z+1)
        or a
        sbc hl,de
        ld (tin+4),hl
        jr .go
.us:    ld l,(ix+O_X)
        ld h,(ix+O_X+1)
        call neg_hl
        ld (tin),hl
        ld l,(ix+O_Y)
        ld h,(ix+O_Y+1)
        call neg_hl
        ld (tin+2),hl
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        call neg_hl
        ld (tin+4),hl
.go:    ld hl,tin                       ; close enough?
        call clamp_far.sum
        ld de,90
        or a
        sbc hl,de
        jr c,.hit
        ld hl,tin
        call vec_to_bytes
        push ix
        pop iy
        ld de,O_SIDE
        add iy,de
        call dot3
        ld (ai_ds),hl
        ld de,O_ROOF-O_SIDE
        add iy,de
        call dot3
        ld (ai_dr),hl
        ld de,O_NOSE-O_ROOF
        add iy,de
        call dot3
        ld (ai_dn),hl
        ld hl,(ai_ds)
        call abs_hl
        ld de,250
        or a
        sbc hl,de
        jr c,.nr
        ld a,(ai_ds+1)
        rla
        ld a,3
        jr c,.rl
        call roll_to_side
        jr .nr
.rl:    call roll_from_side
.nr:    ld hl,(ai_dn)
        bit 7,h
        ld a,3
        jp nz,pitch_up                  ; target behind: loop round
        ld hl,(ai_dr)
        bit 7,h
        jr nz,.dn
        ld de,150
        or a
        sbc hl,de
        ret c
        ld a,3
        jp pitch_up
.dn:    ld de,150
        add hl,de
        ret c
        ld a,3
        jp pitch_down
.hit:   ld a,(ix+O_AIM)
        cp 0FFh
        jr nz,.obj
        ld a,(energy)                   ; it got us
        sub 40
        jr nc,$+3
        xor a
        ld (energy),a
        xor a
        ld (shield),a
        ld a,6
        ld (hitflash),a
        jp explode
.obj:   push ix
        push iy
        pop ix
        ld a,(ix+O_TYPE)
        cp T_HAULER
        call c,award_kill               ; Dart or Mantis: bounty
        call explode
        pop ix
        jp explode

; a pirate (IX) destroyed by us: kill count and bounty
award_kill:
        ld hl,kills
        inc (hl)
        jr nz,$+3
        dec (hl)
        ld a,(ix+O_TYPE)                ; bounty by type
        sub T_DART
        add a,a
        ld e,a
        ld d,0
        ld hl,BOUNTY
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call cr_add
        ld hl,SFX_KILL
        ld a,5
        call sfx
        ld hl,txt_kill
        jp message

; ---------------------------------------------------------------------
; J: the jammer destroys every seeker in flight
; ---------------------------------------------------------------------
use_jammer:
        ld a,(has_jammer)
        or a
        ld hl,txt_nojam
        jp z,message
        ld a,(energy)
        cp 13
        ret c
        sub 12
        ld (energy),a
        ld ix,objects
        ld b,MAXOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        cp T_SEEKER
        call z,explode
        ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ld hl,SFX_JAM
        ld a,7
        call sfx
        ld hl,txt_jam
        jp message

; ---------------------------------------------------------------------
; the law
; ---------------------------------------------------------------------
; legal += A (saturating)
legal_add:
        ld hl,legal
        add a,(hl)
        jr nc,$+4
        ld a,0FFh
        ld (hl),a
        ret

; every police ship turns on us
police_angry:
        ld ix,objects
        ld b,MAXOBJ
.o:     ld a,(ix+O_TYPE)
        cp T_WARDEN
        jr nz,.n
        set 1,(ix+O_FLAG)
.n:     ld de,OBJSZ
        add ix,de
        djnz .o
        ret

; set IX up as a police Warden (hostile if we are wanted)
warden_init:
        ld (ix+O_TYPE),T_WARDEN
        ld (ix+O_SPD),13
        ld (ix+O_HP),4
        ld (ix+O_AIM),0
        ld (ix+O_FLAG),0
        ld a,(legal)
        cp 32
        ret c
        set 1,(ix+O_FLAG)
        ret

; launch: customs scan for contraband, police if we are wanted
customs:
        ld a,(cargo+8)
        ld hl,cargo+9
        add a,(hl)
        jr z,.clean
        add a,a
        add a,a
        call legal_add
        ld hl,txt_scan
        call message
.clean: ld a,(legal)
        cp 32
        ret c
        call find_free
        ret nc
        push iy
        pop ix
        call warden_init
        call ori_forward                ; out of the port behind us
        ld (ix+O_Z),(-900)&255
        ld (ix+O_Z+1),((-900)>>8)&255
        ld (ix+O_Y),40
        ld (ix+O_Y+1),0
        ld hl,txt_police
        jp message

; A = 0 clean, 1 suspect, 2 wanted
legal_level:
        ld a,(legal)
        cp 8
        ld a,0
        ret c
        ld a,(legal)
        cp 32
        ld a,1
        ret c
        inc a
        ret

BOUNTY: dw 150,250,600                 ; Dart, Mantis, Raptor (tenths)

LEGAL_NAMES:
        db "CLEAN  ",0
        db "SUSPECT",0
        db "WANTED ",0

; A = rank 0..6 from kills
rank_of:
        ld a,(kills)
        ld hl,RANK_KILLS
        ld b,0
.l:     cp (hl)
        jr c,.x
        inc hl
        inc b
        jr .l
.x:     ld a,b
        dec a
        ret

RANK_KILLS:
        db 0,3,8,20,45,90,170,255
RANK_NAMES:
        db "CADET",0
        db "PILOT",0
        db "GUNNER",0
        db "VETERAN",0
        db "ACE",0
        db "HOTSHOT",0
        db "LEGEND",0

txt_noseek:     db "NO SEEKERS LEFT",0
txt_nolock:     db "NO TARGET IN THE SIGHTS",0
txt_away:       db "SEEKER AWAY",0
txt_incoming:   db "INCOMING SEEKER! J TO JAM",0
txt_nojam:      db "NO JAMMER FITTED",0
txt_jam:        db "JAMMER PULSE",0
txt_scan:       db "CUSTOMS SCAN: CONTRABAND LOGGED",0
txt_police:     db "WANTED! POLICE LAUNCHED",0
txt_copshot:    db "YOU FIRED ON THE POLICE!",0

; ---------------------------------------------------------------------
; equipment shop (from the docked menu)
; ---------------------------------------------------------------------
NEQUIP          equ 7

equip_screen:
        ld a,WHITE<<4
        call cls
        ld b,0
        ld c,1
        ld a,YELLOW<<4+BLUE
        call clear_rows
        ld hl,txt_equip
        ld c,0
        ld a,YELLOW<<4+BLUE
        call print_centre
        ld hl,txt_ehead
        ld bc,1*256+2
        ld a,CYAN<<4
        call print_at
        ld hl,txt_ehelp
        ld c,21
        ld a,GREEN<<4
        call print_centre
        xor a
        ld (mkt_sel),a
.redraw:
        ld b,0
.all:   push bc
        call eq_row
        pop bc
        inc b
        ld a,b
        cp NEQUIP
        jr c,.all
        ld b,14
        ld c,1
        ld a,WHITE<<4
        call clear_rows
        ld hl,txt_credits2
        ld bc,1*256+14
        ld a,CYAN<<4
        call print_at
        ld c,WHITE<<4
        call print_cr
        call wait_release
        call fe_reset
.loop:  call wait_field
        call fe_keys
        ld c,a
        bit 4,c
        jp nz,wait_release
        ld a,(mkt_sel)
        bit 2,c
        jr z,.nu
        or a
        jr z,.loop
        dec a
        ld (mkt_sel),a
        jr .redraw
.nu:    bit 3,c
        jr z,.nd
        cp NEQUIP-1
        jr nc,.loop
        inc a
        ld (mkt_sel),a
        jr .redraw
.nd:    bit 1,c
        jr z,.loop
        call eq_buy
        jr .redraw

; can item A be bought here?  NZ if not (tech or already fitted)
eq_status:
        ld e,a
        ld d,0
        ld hl,EQ_TECH
        add hl,de
        ld b,(hl)
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_TECH
        ld a,(hl)
        cp b
        ld a,1                          ; 1 = not sold here
        jr c,.nz
        ld a,e
        or a
        jr nz,.flag
        ld a,(seekers)                  ; seekers: up to 3
        cp MAXSEEK
        ld a,2
        jr nc,.nz
        xor a
        ret
.flag:  ld hl,has_jammer-1              ; items 1..4: has_* flags
        add hl,de
        ld a,(hl)
        or a
        ld a,2                          ; 2 = fitted
        jr nz,.nz
        xor a
        ret
.nz:    or a
        ret

eq_buy:
        ld a,(mkt_sel)
        call eq_status
        jr nz,.no
        ld a,(mkt_sel)
        add a,a
        ld e,a
        ld d,0
        ld hl,EQ_COST
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call cr_sub
        jr c,.no
        ld a,(mkt_sel)
        or a
        jr nz,.f
        ld hl,seekers
        inc (hl)
        jr .ok
.f:     ld e,a
        ld d,0
        ld hl,has_jammer-1
        add hl,de
        ld (hl),1
        cp 3                            ; cargo pod: a bigger hold
        jr nz,.ok
        ld a,HOLDMAX+15
        ld (holdmax),a
.ok:    ld hl,SFX_BUY
        ld a,3
        jp sfx
.no:    ld hl,SFX_OUCH
        ld a,3
        jp sfx

; draw equipment row B
eq_row:
        ld a,b
        add a,4
        ld (mk_row),a
        ld a,(mkt_sel)
        cp b
        ld a,WHITE<<4
        jr nz,$+4
        ld a,WHITE<<4+BLUE
        ld (mk_attr),a
        push bc
        ld a,(mk_row)
        ld b,a
        ld c,1
        ld a,(mk_attr)
        call clear_rows
        pop bc
        push bc
        ld a,b
        ld hl,EQ_NAMES
        call nth_str
        push hl
        ld a,(mk_row)
        ld c,a
        ld b,1
        call vaddr
        pop hl
        ld a,(mk_attr)
        ld c,a
        call print
        pop bc
        push bc
        ld a,b                          ; price
        add a,a
        ld l,a
        ld h,0
        ld de,EQ_COST
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,(mk_row)
        ld c,a
        ld b,19
        call vaddr
        pop hl
        ld a,(mk_attr)
        ld c,a
        call print_tenths
        pop bc
        push bc
        ld a,b
        call eq_status
        ld hl,txt_eqok
        or a
        jr z,.p
        ld hl,txt_eqtech
        dec a
        jr z,.p
        ld hl,txt_eqhave
.p:     push hl
        ld a,(mk_row)
        ld c,a
        ld b,28
        call vaddr
        pop hl
        ld a,(mk_attr)
        ld c,a
        call print
        pop bc
        ld a,b
        or a
        ret nz
        ld a,(mk_row)                   ; seekers carried
        ld c,a
        ld b,37
        call vaddr
        ld a,(seekers)
        add a,20h
        ld hl,mk_attr
        ld c,(hl)
        jp putc

EQ_NAMES:
        db "SEEKER MISSILE",0
        db "JAMMER",0
        db "TWIN LASER",0
        db "CARGO POD +15",0
        db "SHIELD BOOSTER",0
        db "CARGO SCOOP",0
        db "AUTO-DOCK",0
EQ_COST:
        dw SEEKER_COST,600,1500,800,1200,900,2500
EQ_TECH:
        db 2,4,7,3,9,3,6

txt_equip:      db "EQUIPMENT",0
txt_ehead:      db "ITEM              PRICE    STATUS",0
txt_ehelp:      db "UP/DOWN CHOOSE  RIGHT BUY  SPACE DONE",0
txt_eqok:       db "FOR SALE",0
txt_eqtech:     db "NOT HERE",0
txt_eqhave:     db "FITTED",0
