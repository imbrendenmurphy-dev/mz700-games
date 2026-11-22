; =====================================================================
;  ships.asm - the shipyard, fuel as a good, and skimming the sun
;
;  Hulls: each has a price, a hold, a fuel tank (jump range), a top
;  speed, seeker racks, armour (halves laser and seeker damage), shield
;  recharge and the rank you need to be sold one.  Every tank holds at
;  least 7.0 ly, the range the galaxy was built for.
;
;  Fuel is sold by the light year at a price and stock that differ from
;  system to system (cheap at industrial, high-tech stations, dear on
;  farm worlds and in lawless space, sometimes sold out).
;
;  The sun can be flown at: sun_d is our distance from it, falling as we
;  fly towards it.  Close in, the cabin heats up; with a fuel scoop
;  fitted the tank fills.  Too close for too long burns the shields,
;  then the energy banks.
; =====================================================================

NHULL           equ 4
; hull: dw price (tenths), db hold, tank (tenths ly), speed, seekers,
; armour, shield step, rank
HULLS:
        dw 6000
        db 20,70,32,3,0,2,0             ; KESTREL: the starter
        dw 11000
        db 12,120,44,2,0,2,1            ; SWIFT: courier, long range
        dw 18000
        db 60,90,24,2,1,2,2             ; GALLEON: freighter
        dw 25000
        db 15,80,38,4,1,4,3             ; WARHAWK: gunship
HULL_SIZE       equ 9
HULL_NAMES:     db "KESTREL",0,"SWIFT",0,"GALLEON",0,"WARHAWK",0

; HL -> hull A's entry
hull_ptr:
        ld l,a
        add a,a
        add a,a
        add a,a
        add a,l                         ; * 9
        ld l,a
        ld h,0
        ld de,HULLS
        add hl,de
        ret

; set the ship's figures from (hull)
apply_hull:
        ld a,(hull)
        call hull_ptr
        inc hl
        inc hl
        ld a,(hl)                       ; hold (+15 with the cargo pod)
        ld b,a
        ld a,(has_pod)
        or a
        ld a,b
        jr z,$+4
        add a,15
        ld (holdmax),a
        inc hl
        ld de,max_fuel
        ld bc,6                         ; tank, speed, seekers, armour,
        ldir                            ; shield step, (rank)
        ret

; ---------------------------------------------------------------------
; fuel: price per light year (tenths of a credit) and stock (ly)
; ---------------------------------------------------------------------
gen_fuel:
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_ECON
        ld b,(hl)                       ; economy 0 (farm) .. 7 (industry)
        ld h,high SYS_GOV
        ld c,(hl)
        ld a,7
        sub b
        ld e,a
        add a,a
        add a,a
        add a,e                         ; farm worlds dear: (7 - econ) * 5
        add a,15
        ld e,a
        ld a,c
        cp 2
        jr nc,.law
        ld a,e
        add a,15                        ; lawless or warlords: dearer
        ld e,a
.law:   call rand
        and 15
        add a,e
        ld (fuel_price),a
        ld a,(cur_sys)                  ; stock: more at high tech
        ld l,a
        ld h,high SYS_TECH
        ld a,(hl)
        add a,6
        ld e,a
        call rand
        and 7
        add a,e
        ld e,a
        ld a,c
        cp 2
        jr nc,.st
        call rand                       ; lawless: sold out one time in four
        and 3
        jr nz,.st
        ld e,0
.st:    ld a,e
        ld (fuel_stock),a
        ret

; buy up to a light year (to a full tank).  C if not (full, none, poor)
fuel_buy1:
        ld a,(fuel_stock)
        or a
        scf
        ret z
        ld a,(max_fuel)
        ld hl,fuel
        sub (hl)
        scf
        ret z
        cp 10
        jr c,$+4
        ld a,10
        ld (fb_amt),a                   ; tenths of a ly
        ld b,a                          ; cost = price * amount / 10
        ld a,(fuel_price)
        ld c,a
        ld hl,0
        ld d,0
        ld e,c
.m:     add hl,de
        djnz .m
        ld de,5
        add hl,de                       ; (rounded)
        ld de,10
        call div16u
        ex de,hl
        call cr_sub
        ret c
        ld a,(fb_amt)
        ld hl,fuel
        add a,(hl)
        ld (hl),a
        ld hl,fuel_stock
        dec (hl)
        or a
        ret

; F when docked: fill the tank as far as credits and stock allow
fuel_fill:
        call fuel_buy1
        jr nc,fuel_fill
        ret

; the market's fuel row shows the tank in whole light years
fuel_sync:
        ld a,(fuel)
        ld l,a
        ld h,0
        ld de,10
        call div16u
        ld a,l
        ld (cargo+NGOODS),a
        ld a,(fuel_price)
        ld (price+2*NGOODS),a
        xor a
        ld (price+2*NGOODS+1),a
        ld a,(fuel_stock)
        ld (stock+NGOODS),a
        ret

; ---------------------------------------------------------------------
; the sun: flying at it brings it nearer; heat and the fuel scoop
; ---------------------------------------------------------------------
SUN_FAR         equ 12000
SUN_HOT         equ 1600                ; the cabin warms inside this
SUN_SCOOP       equ 1100                ; the scoop works inside this

sun_reset:
        ld hl,SUN_FAR
        ld (sun_d),hl
        xor a
        ld (temp),a
        ld (sun_msg),a
        ret

sun_step:
        ld a,(sunv+5)                   ; d -= speed * cos(nose, sun) / 16
        ld b,a
        ld a,(speed)
        ld c,a
        call mul8s
        ld b,4
.s:     sra h
        rr l
        djnz .s
        ex de,hl
        ld hl,(sun_d)
        or a
        sbc hl,de
        bit 7,h
        jr z,$+5
        ld hl,0
        ld de,SUN_FAR+1                 ; no further than it was
        call cmp_s
        jr c,$+5
        ld hl,SUN_FAR
        ld (sun_d),hl
        ld de,SUN_HOT
        or a
        sbc hl,de
        jp nc,.cool
        call neg_hl                     ; how far inside the hot zone:
        ld l,h                          ; / 256 + 1 -> 1..7, the heating
        inc l
        ld a,(frame)
        and 1
        jr nz,.scoop
        ld a,(temp)
        add a,l
        cp 65
        jr c,$+4
        ld a,64
        ld (temp),a
.scoop: ld a,(has_fscoop)               ; skimming: fuel
        or a
        jr z,.hot
        ld hl,(sun_d)
        ld de,SUN_SCOOP
        or a
        sbc hl,de
        jr nc,.hot
        ld a,(speed)
        or a
        jr z,.hot
        ld a,(max_fuel)
        ld hl,fuel
        cp (hl)
        jr z,.hot
        ld a,(frame)
        and 3
        jr nz,.hot
        inc (hl)
        ld a,(sun_msg)
        bit 0,a
        jr nz,.hot
        set 0,a
        ld (sun_msg),a
        ld hl,txt_scooping
        call message
.hot:   ld a,(temp)                     ; too hot: shields, then energy
        cp 40
        jr c,.ok
        ld a,(sun_msg)
        bit 1,a
        jr nz,.w
        set 1,a
        ld (sun_msg),a
        ld hl,txt_hot
        call message
.w:     ld a,(frame)
        and 15
        jr nz,.b
        ld hl,SFX_ALARM
        ld a,6
        call sfx
.b:     ld a,(temp)
        cp 52
        ret c
        ld hl,shield
        ld a,(hl)
        or a
        jr z,.en
        dec (hl)
        ret
.en:    ld a,(frame)
        and 1
        ret nz
        ld hl,energy
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret
.ok:    ld a,(sun_msg)
        and 1
        ld (sun_msg),a
        ret
.cool:  xor a
        ld (sun_msg),a
        ld a,(frame)                    ; out of the heat: cool down
        and 3
        ret nz
        ld hl,temp
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

txt_scooping:   db "FUEL SCOOPS ON",0
txt_hot:        db "CABIN TEMPERATURE CRITICAL",0

; ---------------------------------------------------------------------
; the shipyard (5 when docked): up/down a hull, RIGHT buys it with the
; old one traded in at 60%.  The hold must take your cargo.
; ---------------------------------------------------------------------
shipyard_screen:
        ld hl,txt_shipyard
        ld a,(cur_sys)
        call ui_title2
        ld de,txt_sdone
        ld b,1
        call ui_frame
        ld hl,txt_yhead
        ld bc,2*256+2
        ld a,UI_LABEL
        call print_at
        ld c,9
        ld hl,txt_s_ship
        call ui_rule
        ld hl,txt_yhelp
        ld c,20
        ld a,GREEN<<4
        call print_centre
        ld hl,txt_yhelp2
        ld c,21
        ld a,GREEN<<4
        call print_centre
        xor a
        ld (mkt_sel),a
.redraw:
        ld b,22                         ; (no old message)
        ld c,1
        ld a,WHITE<<4
        call clear_in
        ld b,0
.all:   push bc
        call yd_row
        pop bc
        inc b
        ld a,b
        cp NHULL
        jr c,.all
        ld b,10
        ld c,3
        ld a,WHITE<<4
        call clear_in
        ld hl,txt_credits2
        ld bc,2*256+10
        ld a,UI_LABEL
        call print_at
        ld c,WHITE<<4
        call print_cr
        ld hl,txt_tradein
        ld bc,2*256+11
        ld a,UI_LABEL
        call print_at
        push de
        call trade_in
        pop de
        ld c,WHITE<<4
        call print_cr10
        ld hl,txt_flying
        ld bc,2*256+12
        ld a,UI_LABEL
        call print_at
        ld a,(hull)
        ld hl,HULL_NAMES
        call nth_str
        ld c,YELLOW<<4
        call print
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
        cp NHULL-1
        jr nc,.loop
        inc a
        ld (mkt_sel),a
        jp .redraw
.nd:    bit 1,c
        jr z,.loop
        call yd_buy
        jp .redraw

; HL = what the ship we fly fetches (60% of its price)
trade_in:
        ld a,(hull)
        call hull_ptr
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                        ; price * 0.6 = (price/5)*3
        ld de,5
        call div16u
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ret

; buy hull (mkt_sel)
yd_buy:
        ld a,(mkt_sel)
        ld hl,hull
        cp (hl)
        jr z,.no                        ; already ours
        call hull_ptr
        ld (yd_p),hl
        call rank_of                    ; the rank it needs
        ld hl,(yd_p)
        ld de,8
        add hl,de
        cp (hl)
        ld de,txt_norank
        jr c,.msg
        call hold_used                  ; its hold must take our cargo
        ld c,a
        ld hl,(yd_p)
        inc hl
        inc hl
        ld a,(has_pod)
        or a
        ld a,(hl)
        jr z,$+4
        add a,15
        cp c
        ld de,txt_nohold
        jr c,.msg
        ld hl,(yd_p)
        ld e,(hl)                       ; cost = price - trade-in
        inc hl
        ld d,(hl)
        push de
        call trade_in
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ex de,hl
        jr nc,.pay
        ld de,0                         ; (a cheaper ship: no refund)
.pay:   call cr_sub
        ld de,txt_poor
        jr c,.msg
        ld a,(mkt_sel)
        ld (hull),a
        call apply_hull
        ld a,(max_fuel)                 ; the new tank comes full
        ld (fuel),a
        ld a,(seek_max)
        ld hl,seekers
        cp (hl)
        jr nc,$+3
        ld (hl),a
        ld hl,SFX_BUY
        ld a,3
        jp sfx
.msg:   ex de,hl
        ld c,22
        ld a,RED<<4
        call print_centre
.no:    ld hl,SFX_OUCH
        ld a,3
        jp sfx

; draw hull row B
yd_row:
        ld a,b
        add a,4
        ld (mk_row),a
        ld a,(mkt_sel)
        cp b
        ld a,WHITE<<4
        jr nz,$+4
        ld a,(WHITE<<4)+BLUE
        ld (mk_attr),a
        push bc
        ld a,(mk_row)
        ld b,a
        ld c,1
        ld a,(mk_attr)
        call clear_in
        pop bc
        ld a,b
        push bc
        ld hl,HULL_NAMES
        call nth_str
        push hl
        ld a,(mk_row)
        ld c,a
        ld b,2
        call vaddr
        pop hl
        ld a,(mk_attr)
        ld c,a
        call print
        pop bc
        ld a,b
        push bc
        call hull_ptr
        ld (yd_p),hl
        ld e,(hl)                       ; price (whole credits)
        inc hl
        ld d,(hl)
        push de
        ld a,(mk_row)
        ld c,a
        ld b,9
        call vaddr
        pop hl
        ld a,(mk_attr)
        ld c,a
        call print_cr10
        ld b,17                         ; hold, range, speed, racks
        ld e,2
        call .num
        ld b,22
        ld e,3
        call .tenth
        ld b,28
        ld e,4
        call .num
        ld b,33
        ld e,5
        call .num1
        pop bc
        ret
; byte E of the entry as a number at column B
.num:   push bc
        call .get
        pop bc
        push af
        call .at
        pop af
        ld hl,mk_attr
        ld c,(hl)
        jp print_dec3
.num1:  call .get
        add a,20h                       ; a digit
        push af
        call .at
        pop af
        ld hl,mk_attr
        ld c,(hl)
        jp putc
.tenth: push bc
        call .get
        pop bc
        push af
        call .at
        pop af
        ld l,a
        ld h,0
        ld a,(mk_attr)
        ld c,a
        jp print_tenths
.get:   ld hl,(yd_p)
        ld d,0
        add hl,de
        ld a,(hl)
        ret
.at:    ld a,(mk_row)
        ld c,a
        jp vaddr

; HL = tenths of a credit: print the whole credits, 5 places, at DE
print_cr10:
        push bc
        push de
        ld de,10
        call div16u
        ld de,numbuf
        call dec5
        pop de
        pop bc
        ld hl,numbuf
        ld b,4                          ; leading zeros blank
.z:     ld a,(hl)
        cp 20h
        jr nz,.d
        xor a
        call putc
        inc de
        inc hl
        djnz .z
.d:     inc b
.p:     ld a,(hl)
        call putc
        inc de
        inc hl
        djnz .p
        ret

txt_shipyard:   db "SHIPYARD - ",0
txt_yhead:      db "HULL   PRICE   HOLD RANGE SPD RACKS",0
txt_yhelp:      db "UP/DOWN CHOOSE   RIGHT BUY",0
txt_yhelp2:     db "BETTER HULLS NEED A HIGHER RANK",0
txt_tradein:    db "TRADE-IN    ",0
txt_flying:     db "FLYING      ",0
txt_norank:     db "YOUR RANK IS TOO LOW",0
txt_nohold:     db "SELL CARGO FIRST - IT WON'T FIT",0
txt_poor:       db "NOT ENOUGH CREDITS",0

; ---------------------------------------------------------------------
; J: the jump drive, as the Spectrum's Torus drive.  While J is held
; and nothing is near (no ship or station within reach, the planet not
; close), everything rushes past: the world moves JSTEP units a frame
; towards us.  Anything near: MASS LOCKED.
; ---------------------------------------------------------------------
JSTEP           equ 800
LOCK_SHIP       equ 7000                ; |x|+|y|+|z| inside which ships lock it
LOCK_PLANET     equ 16000

jump_step:
        call mass_lock
        jr nc,.go
        ld a,(jk_note)                  ; say so once a press
        or a
        ret nz
        inc a
        ld (jk_note),a
        ld hl,txt_locked
        jp message
.go:    ld hl,(planet+4)                ; the planet and every ship nearer
        ld de,-JSTEP
        add hl,de
        ld (planet+4),hl
        ld ix,objects
        ld b,MAXOBJ
.o:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        ld l,(ix+O_Z)
        ld h,(ix+O_Z+1)
        add hl,de
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
.n:     push de
        ld de,OBJSZ
        add ix,de
        pop de
        djnz .o
        ld a,(sunv+5)                   ; and the sun, as we head for it
        or a
        ret m
        ld l,a                          ; JSTEP * cos / 64 = cos * 12.5
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de                       ; * 12
        ex de,hl
        ld hl,(sun_d)
        or a
        sbc hl,de
        jr nc,$+5
        ld hl,0
        ld (sun_d),hl
        ret

; C if something is near enough to lock the jump drive
mass_lock:
        ld hl,planet
        call clamp_far.sum
        ld de,LOCK_PLANET
        or a
        sbc hl,de
        ret c
        ld ix,objects
        ld b,MAXOBJ
.o:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        cp T_DEBRIS
        jr z,.n
        push bc
        push ix
        pop hl
        ld de,O_X
        add hl,de
        call clamp_far.sum
        pop bc
        ld de,LOCK_SHIP
        or a
        sbc hl,de
        ret c
.n:     ld de,OBJSZ
        add ix,de
        djnz .o
        or a
        ret

txt_locked:     db "MASS LOCKED",0
