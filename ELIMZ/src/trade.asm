; =====================================================================
;  trade.asm - credits, the galaxy, the docked menu, market, chart
; =====================================================================
NGOODS          equ 10
HOLDMAX         equ 20

; ---------------------------------------------------------------------
; credits: 24-bit, tenths of a credit
; ---------------------------------------------------------------------
; credits += DE
cr_add:
        ld hl,(credits)
        add hl,de
        ld (credits),hl
        ld a,(credits+2)
        adc a,0
        ld (credits+2),a
        ld a,1
        ld (cr_dirty),a
        ret

; credits -= DE ; C (and no change) if there is not enough
cr_sub:
        ld hl,(credits)
        or a
        sbc hl,de
        ld a,(credits+2)
        sbc a,0
        ret c
        ld (credits),hl
        ld (credits+2),a
        ld a,1
        ld (cr_dirty),a
        or a
        ret

; credits -> numbuf: 7 display-code digits
cr_digits:
        ld hl,credits
        ld de,cv
        ld bc,3
        ldir
        ld hl,POW10
        ld de,numbuf
        ld b,7
.d:     push bc
        ld c,20h
.s:     push hl
        ld a,(cv)
        sub (hl)
        ld (cvt),a
        inc hl
        ld a,(cv+1)
        sbc a,(hl)
        ld (cvt+1),a
        inc hl
        ld a,(cv+2)
        sbc a,(hl)
        pop hl
        jr c,.done
        ld (cv+2),a
        ld a,(cvt)
        ld (cv),a
        ld a,(cvt+1)
        ld (cv+1),a
        inc c
        jr .s
.done:  ld a,c
        ld (de),a
        inc de
        inc hl
        inc hl
        inc hl
        pop bc
        djnz .d
        ret

POW10:  db 40h,42h,0Fh          ; 1000000
        db 0A0h,86h,01h         ; 100000
        db 10h,27h,0            ; 10000
        db 0E8h,03h,0           ; 1000
        db 64h,0,0              ; 100
        db 0Ah,0,0              ; 10
        db 1,0,0                ; 1

; credits at DE (VRAM), attr C: "nnnnnn.n" (leading zeros blank)
print_cr:
        push bc
        push de
        call cr_digits
        pop de
        pop bc
        ld hl,numbuf
        ld b,5                          ; first five digits may be blank
.z:     ld a,(hl)
        cp 20h
        jr nz,.nz
        xor a
        call putc
        inc de
        inc hl
        djnz .z
        jr .rest
.nz:    ld a,(hl)
        call putc
        inc de
        inc hl
        djnz .nz
.rest:  ld a,(hl)
        inc hl
        call putc
        inc de
        ld a,2Eh
        call putc
        inc de
        ld a,(hl)
        call putc
        inc de
        ret

; HL = tenths (0..9999) at DE, attr C: "nnn.n" (leading zeros blank)
print_tenths:
        push bc
        push de
        ld de,numbuf
        call dec5
        pop de
        pop bc
        ld hl,numbuf+1
        ld b,2
.z:     ld a,(hl)
        cp 20h
        jr nz,.nz
        xor a
        call putc
        inc de
        inc hl
        djnz .z
        jr .rest
.nz:    ld a,(hl)
        call putc
        inc de
        inc hl
        djnz .nz
.rest:  ld a,(hl)
        inc hl
        call putc
        inc de
        ld a,2Eh
        call putc
        inc de
        ld a,(hl)
        call putc
        inc de
        ret

; ---------------------------------------------------------------------
; galaxy helpers
; ---------------------------------------------------------------------
; HL -> name of system A
sys_name:
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de                       ; x10
        ld de,SYS_NAME
        add hl,de
        pop de
        ret

; HL = distance in tenths of a light year between systems A and B
sys_dist:
        ld c,a
        ld h,high SYS_GX
        ld l,c
        ld a,(hl)
        ld l,b
        sub (hl)
        jr nc,$+4
        neg
        ld d,a                          ; dx
        ld h,high SYS_GY
        ld l,c
        ld a,(hl)
        ld l,b
        sub (hl)
        jr nc,$+4
        neg                             ; A = dy
        cp d
        jr nc,.m
        ld e,a
        ld a,d
        ld d,e                          ; A = max, D = min
.m:     srl d
        ld l,a
        ld h,0
        ld e,d
        ld d,0
        add hl,de
        add hl,hl
        add hl,hl                       ; 1 unit = 0.4 ly
        ret

; distance from the current system to the target (HL, tenths)
target_dist:
        ld a,(target_sys)
        ld b,a
        ld a,(cur_sys)
        jp sys_dist

; ---------------------------------------------------------------------
; gen_market: prices and stock for the current system
; ---------------------------------------------------------------------
gen_market:
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_ECON
        ld a,(hl)
        sub 3
        ld (mk_e3),a                    ; -3..4
        xor a
        ld (mk_i),a
.g:     ld a,(mk_i)                     ; price = base + slope*e3 + noise
        add a,a
        ld l,a
        ld h,0
        ld de,GOOD_BASE
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (mk_base),de
        ld hl,GOOD_SLOPE
        call mk_get
        ld b,a
        ld a,(mk_e3)
        ld c,a
        call mul8s
        ld de,(mk_base)
        add hl,de
        ld (mk_p),hl
        ld hl,(mk_base)                 ; noise: (0..15 - 8) * base/64
        add hl,hl
        add hl,hl
        ld c,h
        call rand
        and 15
        sub 8
        ld b,a
        call mul8s
        ld de,(mk_p)
        add hl,de
        bit 7,h
        jr nz,.lo
        ld a,h
        or a
        jr nz,.okp
        ld a,l
        cp 10
        jr nc,.okp
.lo:    ld hl,10
.okp:   ex de,hl
        ld a,(mk_i)
        add a,a
        ld l,a
        ld h,0
        ld bc,price
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,GOOD_QS                   ; stock = qbase + qslope*e3 + 0..7
        call mk_get
        ld b,a
        ld a,(mk_e3)
        ld c,a
        call mul8s
        ld a,l
        ld (mk_q),a
        ld hl,GOOD_QB
        call mk_get
        ld hl,mk_q
        add a,(hl)
        ld (hl),a
        call rand
        and 7
        ld hl,mk_q
        add a,(hl)
        bit 7,a
        jr z,$+3
        xor a
        cp 61
        jr c,$+4
        ld a,60
        ld hl,stock
        push af
        call mk_ptr
        pop af
        ld (hl),a
        ld hl,mk_i
        inc (hl)
        ld a,(hl)
        cp NGOODS
        jp c,.g
        jp gen_fuel

; HL = HL + mk_i ; mk_get: A = (HL + mk_i)
mk_ptr:
        ld a,(mk_i)
        add a,l
        ld l,a
        ret nc
        inc h
        ret
mk_get:
        call mk_ptr
        ld a,(hl)
        ret

; units of cargo carried -> A
hold_used:
        ld hl,cargo
        ld b,NGOODS
        xor a
.l:     add a,(hl)
        inc hl
        djnz .l
        ret

; ---------------------------------------------------------------------
; goods (original list): name, base price (tenths), price change per
; economy step (farm 0 .. heavy industry 7), stock base and change,
; contraband flag
; ---------------------------------------------------------------------
GOOD_NAMES:
        db "GRAIN      ",0
        db "ORE        ",0
        db "TEXTILES   ",0
        db "SPIRITS    ",0
        db "MEDICINE   ",0
        db "MACHINERY  ",0
        db "ELECTRONICS",0
        db "ARTWORK    ",0
        db "STIMS      ",0
        db "ARMS       ",0
        db "FUEL LY    ",0
GOOD_BASE:
        dw 60,90,110,200,320,450,700,900,280,600
GOOD_SLOPE:
        db 7,6,5,9,-11,-17,-26,12,10,-13
GOOD_QB:
        db 24,20,18,12,8,8,6,3,4,4
GOOD_QS:
        db -4,-3,-3,-2,2,2,2,0,0,1
GOOD_ILL:
        db 0,0,0,0,0,0,0,0,1,1,0

; ---------------------------------------------------------------------
; docked: the station menu
; ---------------------------------------------------------------------
docked_screen:
        call gen_market
        ld hl,SFX_DOCK
        ld a,9
        call sfx
        ld a,(trk_on)                   ; the waltz (on, if it plays already)
        or a
        ld hl,TRK_WALTZ
        call z,trk_play
.menu:  call wait_release
        ld hl,txt_dockedat              ; the bezel: "DOCKED AT name"
        ld a,(cur_sys)
        call ui_title2
        ld de,txt_dfoot
        ld b,1
        call ui_frame
        ld c,6
        ld hl,txt_s_cmdr
        call ui_rule
        ld c,12
        ld hl,txt_s_target
        call ui_rule
        ld c,15
        ld hl,txt_s_station
        call ui_rule
        ; system facts
        ld hl,txt_econ
        ld bc,2*256+2
        ld a,CYAN<<4
        call print_at
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_ECON
        ld a,(hl)
        ld hl,ECON_NAMES
        call nth_str
        ld c,WHITE<<4
        call print
        ld hl,txt_gov
        ld bc,2*256+3
        ld a,CYAN<<4
        call print_at
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_GOV
        ld a,(hl)
        ld hl,GOV_NAMES
        call nth_str
        ld c,WHITE<<4
        call print
        ld hl,txt_tech
        ld bc,2*256+4
        ld a,CYAN<<4
        call print_at
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_TECH
        ld a,(hl)
        ld c,WHITE<<4
        call print_dec3
        ; status
        ld hl,txt_credits2
        ld bc,2*256+7
        ld a,CYAN<<4
        call print_at
        ld c,WHITE<<4
        call print_cr
        ld hl,txt_fuel
        ld bc,2*256+8
        ld a,CYAN<<4
        call print_at
        ld a,(fuel)
        ld l,a
        ld h,0
        ld c,WHITE<<4
        call print_tenths
        ld hl,txt_ly
        ld c,WHITE<<4
        call print
        ld hl,txt_hold
        ld bc,2*256+9
        ld a,CYAN<<4
        call print_at
        call hold_used
        ld c,WHITE<<4
        call print_dec3
        ld hl,txt_of20
        call print
        ld a,(holdmax)
        call print_dec3
        ld hl,txt_kills2
        ld bc,2*256+10
        ld a,CYAN<<4
        call print_at
        ld a,(kills)
        ld c,WHITE<<4
        call print_dec3
        inc de
        inc de
        call rank_of
        ld hl,RANK_NAMES
        call nth_str
        ld c,YELLOW<<4
        call print
        ld hl,txt_legal
        ld bc,24*256+7
        ld a,CYAN<<4
        call print_at
        call legal_level
        ld c,a
        add a,a
        add a,a
        add a,a
        ld hl,LEGAL_NAMES
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,c
        ld c,GREEN<<4
        or a
        jr z,$+4
        ld c,RED<<4
        call print
        ld hl,txt_ship
        ld bc,24*256+9
        ld a,CYAN<<4
        call print_at
        ld a,(hull)
        ld hl,HULL_NAMES
        call nth_str
        ld c,YELLOW<<4
        call print
        ld hl,txt_seekers
        ld bc,24*256+8
        ld a,CYAN<<4
        call print_at
        ld a,(seekers)
        ld c,WHITE<<4
        call print_dec3
        ; target
        ld hl,txt_none
        ld bc,2*256+13
        ld a,CYAN<<4
        call print_at
        ld a,(target_sys)
        call sys_name
        ld c,WHITE<<4
        call print
        inc de
        push de
        call target_dist
        pop de
        ld c,WHITE<<4
        call print_tenths
        ld hl,txt_ly
        call print
        ld hl,menu_text                 ; the services, as key caps
        call ui_items
.keys:  call wait_field                 ; the mixer plays while we wait
        call fkeys_new                  ; F1 help, F2 chart, F3 nearby, F4 data
        or a
        jr z,.nofk
        call fk_screen
        jp .menu
.nofk:  call digit_key                   ; Spectrum Elite: 1 launch, 2 buy,
        cp 1                            ; 3 sell, 4 equip
        jr z,.launch
        cp 4
        jr z,.equip
        cp 5
        jr z,.yard
        or a
        jr nz,.market
        call getkey
        cp 'M'
        jr z,.market
        cp 'K'                          ; K: market prices
        jr z,.market
        cp 'C'
        jr z,.chart
        cp 'F'
        jr z,.refuel
        cp 'E'
        jr z,.equip
        cp 'S'
        jr z,.save
        cp 'L'
        jr z,.load
        call read_flight
        and K_FIRE+K_FAST               ; SPACE launches too
        jr z,.keys
.launch:
        call mus_stop
        jp wait_release
.market:
        call market_screen
        jp .menu
.chart: call chart_screen
        jp .menu
.equip: call equip_screen
        jp .menu
.yard:  call shipyard_screen
        jp .menu
.save:  call menu_save
        jp .menu
.load:  call menu_load
        call gen_market
        jp .menu
.refuel:
        ld a,(fuel)                     ; fill up at the local price
        push af
        call fuel_fill
        pop bc
        ld a,(fuel)
        cp b
        jr z,.poor                      ; none bought
        ld hl,SFX_BUY
        ld a,3
        call sfx
        jp .menu
.poor:  ld hl,SFX_OUCH
        ld a,3
        call sfx
        jp .menu

menu_text:
        db 3,16,"1",0,"LAUNCH",0
        db 3,17,"2",0,"BUY CARGO",0
        db 3,18,"3",0,"SELL CARGO",0
        db 3,19,"4",0,"EQUIP SHIP",0
        db 3,20,"F",0,"REFUEL",0
        db 3,21,"5",0,"SHIPYARD",0
        db 21,16,"I",0,"GALACTIC CHART",0
        db 21,17,"O",0,"LOCAL CHART",0
        db 21,18,"P",0,"DATA ON SYSTEM",0
        db 21,19,"S",0,"SAVE",0
        db 30,19,"L",0,"LOAD",0
        db 21,20,"F1",0,"HELP",0
        db 0FFh
txt_dfoot:      db "1 LAUNCH   F1 HELP",0
txt_none:       db 0
txt_ship:       db "SHIP    ",0
txt_s_cmdr:     db "COMMANDER",0
txt_s_target:   db "JUMP TARGET",0
txt_s_station:  db "STATION SERVICES",0

; A = 1..4 for the number key held (0: none)
digit_key:
        ld a,5
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        and 0F8h                        ; 1..5
        ret z
        ld b,0
.l:     inc b
        rla
        jr nc,.l
        ld a,b
        ret

; HL = the A'th 0-terminated string of a list
nth_str:
        or a
        ret z
        ld b,a
.l:     ld a,(hl)
        inc hl
        or a
        jr nz,.l
        djnz .l
        ret

txt_dockedat:   db "DOCKED AT ",0
txt_econ:       db "ECONOMY     ",0
txt_gov:        db "GOVERNMENT  ",0
txt_tech:       db "TECH LEVEL  ",0
txt_credits2:   db "CREDITS     ",0
txt_fuel:       db "FUEL        ",0
txt_ly:         db " LY",0
txt_hold:       db "CARGO HOLD  ",0
txt_of20:       db " / ",0
txt_kills2:     db "KILLS       ",0
txt_target:     db "SYSTEM      ",0
txt_legal:      db "STATUS  ",0
txt_seekers:    db "SEEKERS ",0

; ---------------------------------------------------------------------
; market
; ---------------------------------------------------------------------
market_screen:
        ld hl,txt_market
        ld a,(cur_sys)
        call ui_title2
        ld de,txt_sdone
        ld b,1
        call ui_frame
        ld hl,txt_mhead
        ld bc,2*256+2
        ld a,UI_LABEL
        call print_at
        ld c,15
        ld hl,txt_s_ship
        call ui_rule
        ld hl,txt_mhelp
        ld c,20
        ld a,GREEN<<4
        call print_centre
        ld hl,txt_mhelp2
        ld c,21
        ld a,GREEN<<4
        call print_centre
        xor a
        ld (mkt_sel),a
        call fuel_sync
        ld b,0
.all:   push bc
        call mkt_row
        pop bc
        inc b
        ld a,b
        cp NGOODS+1                     ; the goods and fuel
        jr c,.all
        call mkt_footer
        call wait_release
        call fe_reset
.loop:  call wait_field
        call fe_keys
        ld c,a
        bit 4,c
        jp nz,wait_release
        ld a,(mkt_sel)
        ld b,a
        bit 2,c                         ; up
        jr z,.nu
        or a
        jr z,.nu
        dec a
        jr .mv
.nu:    bit 3,c
        jr z,.nd
        cp NGOODS
        jr nc,.nd
        inc a
.mv:    ld (mkt_sel),a
        push af
        call mkt_row                    ; old row (B)
        pop af
        ld b,a
        call mkt_row
        jr .loop
.nd:    bit 1,c
        jr nz,.buy
        bit 0,c
        jr nz,.sell
        jr .loop
.buy:   ld a,(mkt_sel)
        cp NGOODS
        jr nz,.good
        call fuel_buy1                  ; fuel: a light year
        jr c,.no
        call fuel_sync
        jr .done
.good:  call stock_ptr
        ld a,(hl)
        or a
        jr z,.no
        call hold_used
        ld hl,holdmax
        cp (hl)
        jr nc,.no
        call price_de
        call cr_sub
        jr c,.no
        call stock_ptr
        dec (hl)
        call cargo_ptr
        inc (hl)
        jr .done
.sell:  ld a,(mkt_sel)
        cp NGOODS
        jr z,.no                        ; no selling fuel
        call cargo_ptr
        ld a,(hl)
        or a
        jr z,.no
        dec (hl)
        call stock_ptr
        inc (hl)
        call price_de
        call cr_add
.done:  ld hl,SFX_BUY
        ld a,3
        call sfx
        ld a,(mkt_sel)
        ld b,a
        call mkt_row
        call mkt_footer
        jp .loop
.no:    ld hl,SFX_OUCH
        ld a,3
        call sfx
        jp .loop

stock_ptr:
        ld hl,stock
        jr sel_ptr
cargo_ptr:
        ld hl,cargo
sel_ptr:
        ld a,(mkt_sel)
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; DE = price of the selected good
price_de:
        ld a,(mkt_sel)
        add a,a
        ld l,a
        ld h,0
        ld de,price
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

; draw market row B
mkt_row:
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
        push bc
        ld a,b                          ; name
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de                       ; x12
        ld de,GOOD_NAMES
        add hl,de
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
        push bc
        ld hl,GOOD_ILL
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr z,.leg
        ld a,(mk_row)
        ld c,a
        ld b,13
        call vaddr
        ld a,(mk_attr)
        and 0Fh
        or RED<<4
        ld c,a
        ld a,6Bh                        ; '*'
        call putc
.leg:   pop bc
        push bc
        ld a,b                          ; price
        add a,a
        ld l,a
        ld h,0
        ld de,price
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,(mk_row)
        ld c,a
        ld b,16
        call vaddr
        pop hl
        ld a,(mk_attr)
        ld c,a
        call print_tenths
        pop bc
        push bc
        ld hl,stock                     ; stock
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        push af
        ld a,(mk_row)
        ld c,a
        ld b,25
        call vaddr
        pop af
        ld hl,mk_attr
        ld c,(hl)
        call print_dec3
        pop bc
        push bc
        ld hl,cargo                     ; held
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        push af
        ld a,(mk_row)
        ld c,a
        ld b,33
        call vaddr
        pop af
        ld hl,mk_attr
        ld c,(hl)
        call print_dec3
        pop bc
        ret

mkt_footer:
        ld b,16
        ld c,2
        ld a,WHITE<<4
        call clear_in
        ld hl,txt_credits2
        ld bc,2*256+16
        ld a,CYAN<<4
        call print_at
        ld c,WHITE<<4
        call print_cr
        ld hl,txt_hold
        ld bc,2*256+17
        ld a,CYAN<<4
        call print_at
        call hold_used
        ld c,WHITE<<4
        call print_dec3
        ld hl,txt_of20
        call print
        ld a,(holdmax)
        jp print_dec3

txt_market:     db "MARKET - ",0
txt_mhead:      db "GOODS          PRICE    STOCK   HOLD",0
txt_mhelp:      db "UP/DOWN CHOOSE  RIGHT BUY  LEFT SELL",0
txt_mhelp2:     db "* CONTRABAND",0
txt_sdone:      db "SPACE DONE",0
txt_s_ship:     db "YOUR SHIP",0

; ---------------------------------------------------------------------
; galaxy chart: pick a jump target
; ---------------------------------------------------------------------
chart_screen:
        ld hl,txt_chart
        call ui_mapframe
        ld a,(target_sys)
        ld l,a
        ld h,high SYS_CX
        ld a,(hl)
        ld (ch_x),a
        ld h,high SYS_CY
        ld a,(hl)
        ld (ch_y),a
        call chart_info
        call wait_release
        call fe_reset
.loop:  call wait_frame
        ld hl,SYS_CX                    ; every star, in its own colour
.st:    ld b,(hl)
        inc h
        ld c,(hl)
        dec h
        push hl
        ld h,high SYS_LOOK
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 7
        call set_col
        pop hl
        push hl
        call plot
        pop hl
        inc l
        jr nz,.st
        ld a,(cur_sys)                  ; fuel range around us
        ld l,a
        ld h,high SYS_CX
        ld e,(hl)
        ld d,0
        ld (ccx),de
        ld h,high SYS_CY
        ld e,(hl)
        ld (ccy),de
        ld a,(fuel)                     ; r = fuel * 5 / 64
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld b,6
.r6:    srl h
        rr l
        djnz .r6
        ld a,l
        cp 2
        jr nc,$+4
        ld a,2
        push af
        ld a,GREEN
        call set_col
        pop af
        call circle
        ld a,YELLOW
        call set_col
        ld a,(ch_x)                     ; cursor
        ld b,a
        ld a,(ch_y)
        ld c,a
        call .cross
        call present
        call fe_keys
        ld c,a
        bit 4,c
        jp nz,wait_release
        ld a,c
        and K_DIRS
        jr z,.loop
        ld hl,ch_x
        bit 0,c
        jr z,$+7
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        bit 1,c
        jr z,$+8
        ld a,(hl)
        cp VW-1
        jr nc,$+3
        inc (hl)
        ld hl,ch_y
        bit 2,c
        jr z,$+7
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        bit 3,c
        jr z,$+8
        ld a,(hl)
        cp VH-1
        jr nc,$+3
        inc (hl)
        call nearest
        ld hl,target_sys
        cp (hl)
        jp z,.loop
        ld (hl),a
        call chart_info
        jp .loop
; cursor cross at B, C (clipped)
.cross: ld l,b
        ld h,0
        ld e,c
        ld d,0
        push hl
        push de
        dec hl
        dec hl
        call plot_clip
        pop de
        pop hl
        push hl
        push de
        inc hl
        inc hl
        call plot_clip
        pop de
        pop hl
        push hl
        push de
        dec de
        dec de
        call plot_clip
        pop de
        pop hl
        inc de
        inc de
        jp plot_clip

; A = the system nearest the chart cursor
nearest:
        ld a,0FFh
        ld (nr_best),a
        ld b,0
.l:     ld h,high SYS_CX
        ld l,b
        ld a,(ch_x)
        sub (hl)
        jr nc,$+4
        neg
        ld d,a
        ld h,high SYS_CY
        ld a,(ch_y)
        sub (hl)
        jr nc,$+4
        neg
        cp d                            ; A = max + min/2
        jr nc,.m
        ld e,a
        ld a,d
        ld d,e
.m:     srl d
        add a,d
        jr c,.n
        ld hl,nr_best
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld a,b
        ld (nr_sys),a
.n:     inc b
        jr nz,.l
        ld a,(nr_sys)
        ret

chart_info:
        ld b,20
        ld c,4
        ld a,WHITE<<4
        call clear_in
        ld hl,txt_target
        ld bc,2*256+20
        ld a,CYAN<<4
        call print_at
        ld a,(target_sys)
        call sys_name
        ld c,WHITE<<4
        call print
        ld hl,txt_dist
        ld bc,2*256+21
        ld a,CYAN<<4
        call print_at
        push de
        call target_dist
        pop de
        ld c,WHITE<<4
        call print_tenths
        ld hl,txt_ly
        call print
        inc de
        inc de
        ld a,(target_sys)
        ld b,a
        ld a,(cur_sys)
        cp b
        ld hl,txt_here
        ld c,YELLOW<<4
        jr z,.p
        push de
        call target_dist
        pop de
        ld a,(fuel)
        ld c,a
        ld b,0
        or a
        sbc hl,bc
        ld hl,txt_inrange
        ld c,GREEN<<4
        jr c,.p
        jr z,.p
        ld hl,txt_outrange
        ld c,RED<<4
.p:     call print
        ld hl,txt_econ
        ld bc,2*256+22
        ld a,CYAN<<4
        call print_at
        ld a,(target_sys)
        ld l,a
        ld h,high SYS_ECON
        ld a,(hl)
        ld hl,ECON_NAMES
        call nth_str
        ld c,WHITE<<4
        call print
        ld hl,txt_gov
        ld bc,2*256+23
        ld a,CYAN<<4
        call print_at
        ld a,(target_sys)
        ld l,a
        ld h,high SYS_GOV
        ld a,(hl)
        ld hl,GOV_NAMES
        call nth_str
        ld c,WHITE<<4
        call print
        ret

txt_chart:      db "GALAXY CHART",0
txt_dist:       db "DISTANCE    ",0
txt_here:       db "YOU ARE HERE",0
txt_inrange:    db "IN RANGE",0
txt_outrange:   db "OUT OF RANGE",0
txt_chelp:      db "CURSORS MOVE   SPACE DONE",0

; the bezel for the map screens (the view is the map): title HL
ui_mapframe:
        ld de,txt_chelp
        ld b,20
        call ui_frame
        ld c,19
        ld hl,txt_s_target
        jp ui_rule

; ---------------------------------------------------------------------
; hyperspace jump effect
; ---------------------------------------------------------------------
hyper_jump:
        call target_dist
        ld a,(fuel)
        sub l
        jr nc,$+3
        xor a
        ld (fuel),a
        ld a,(target_sys)
        ld (cur_sys),a
        ld hl,legal                     ; the law forgets, slowly
        srl (hl)
        call rand                       ; one jump in six: an ambush
        cp 43
        ld a,0
        adc a,a
        ld (ambush),a
        ld hl,SFX_JUMP
        ld a,9
        call sfx
        ld hl,HYPER_PAL                 ; rings rush inwards
        ld bc,36*256+0FFh
        jp tunnel_fx
