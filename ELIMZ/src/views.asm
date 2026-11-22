; =====================================================================
;  views.asm - front, rear, left and right views (keys 1-4) and the
;  function-key screens: F1 help, F2 galaxy chart, F3 nearby systems,
;  F4 system data
;
;  A view is drawn by turning every world vector into that camera for
;  the length of render (and back): ships, the planet, the sun and the
;  dust.  The physics, lasers, scanner and compass stay in the front
;  view.  Lasers fire only from the front view.
; =====================================================================

FK_F1           equ 80h                 ; keyboard row 9
FK_F2           equ 40h
FK_F3           equ 20h
FK_F4           equ 10h
LCX             equ 0B400h              ; nearby map: each system's dot
LCY             equ 0B500h              ; (LCX = FFh: off the map)

; A = the function keys newly pressed (FK_ bits)
fkeys_new:
        ld a,3                          ; I, O, P (as in Spectrum Elite)
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        ld c,0
        bit 7,a
        jr z,$+4
        set 6,c                         ; I: the galactic chart (F2)
        bit 1,a
        jr z,$+4
        set 5,c                         ; O: the local chart (F3)
        bit 0,a
        jr z,$+4
        set 4,c                         ; P: data on the system (F4)
        ld a,9
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        and 0F0h
        or c
        ld b,a
        ld a,(fk_prev)
        cpl
        and b
        ld c,a
        ld a,b
        ld (fk_prev),a
        ld a,c
        ret

; ---------------------------------------------------------------------
; in flight (not the demo): 1-4 choose the view, F1-F4 the screens
; ---------------------------------------------------------------------
flight_keys:
        ld a,(autoplay)
        or a
        ret nz
        ld a,5                          ; row 5: 1 (bit 7) .. 4 (bit 4)
        ld (KEYPA),a
        ld a,(KEYPB)
        cpl
        ld c,0FFh
        bit 7,a
        jr z,$+4
        ld c,0
        bit 6,a
        jr z,$+4
        ld c,1
        bit 5,a
        jr z,$+4
        ld c,2
        bit 4,a
        jr z,$+4
        ld c,3
        ld a,c
        cp 0FFh
        jr z,.fk
        ld hl,view
        cp (hl)
        jr z,.fk
        ld (hl),a
        add a,a
        ld e,a
        ld d,0
        ld hl,VIEW_NAMES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call message
.fk:    call fkeys_new
        or a
        ret z
        push af
        call sfx_stop
        pop af
        call fk_screen
        ; back to flight: the whole screen again
        ld a,WHITE<<4
        call cls
        call hud_frame
        jp wait_release

VIEW_NAMES:     dw txt_vfront,txt_vrear,txt_vleft,txt_vright
txt_vfront:     db "FRONT VIEW",0
txt_vrear:      db "REAR VIEW",0
txt_vleft:      db "LEFT VIEW",0
txt_vright:     db "RIGHT VIEW",0

; A = FK_ bits: open the first screen named
fk_screen:
        bit 7,a
        jp nz,help_screen
        bit 6,a
        jp nz,chart_screen
        bit 5,a
        jp nz,local_screen
        jp sysinfo_screen

; ---------------------------------------------------------------------
; view_xf: turn the world into view A's camera (1 rear, 2 left,
; 3 right); view_unxf turns it back
; ---------------------------------------------------------------------
view_unxf:
        ld a,(view)
        cp 2
        jr c,view_xf                    ; front and rear undo themselves
        xor 1                           ; left <-> right
view_xf:
        or a
        ret z
        ld (xf_m),a
        ld ix,objects
        ld b,MAXOBJ
.o:     push bc
        ld a,(ix+O_TYPE)
        or a
        jr z,.n
        push ix
        pop hl
        ld de,O_X
        add hl,de
        ld b,4                          ; position, side, roof, nose
.v:     push bc
        call xf1
        pop bc
        djnz .v
.n:     ld de,OBJSZ
        add ix,de
        pop bc
        djnz .o
        ld hl,planet
        call xf1
        ld hl,sunv
        call xf1
        ld hl,dust
        ld b,NDUST
.d:     push bc
        call xf1
        pop bc
        djnz .d
        ret

; HL -> (x, y, z) words: turn them for view (xf_m); HL -> the next
xf1:    push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (xf_x),de
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (xf_z),de
        ld a,(xf_m)
        cp 1
        jr nz,.lr
        ld hl,(xf_x)                    ; rear: x = -x, z = -z
        call neg_hl
        ld (xf_x),hl
        ld hl,(xf_z)
        call neg_hl
        ld (xf_z),hl
        jr .st
.lr:    ld hl,(xf_x)
        ld de,(xf_z)
        cp 2
        jr nz,.rt
        ld (xf_x),de                    ; left: x = z, z = -x
        call neg_hl
        ld (xf_z),hl
        jr .st
.rt:    ld (xf_z),hl                    ; right: x = -z, z = x
        ex de,hl
        call neg_hl
        ld (xf_x),hl
.st:    pop hl
        ld de,(xf_x)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc hl
        inc hl
        ld de,(xf_z)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ret

; ---------------------------------------------------------------------
; F1: help - every key, as key caps.  The attract sequence shows it
; too (handbook: until a key or a while; NZ on a key).
; ---------------------------------------------------------------------
handbook:
        ld a,1
        jr help_show
help_screen:
        xor a
help_show:
        ld (hp_timed),a
        ld hl,txt_help
        ld de,txt_anykey
        ld b,1
        call ui_frame
        ld hl,HELP_RULES
.r:     ld a,(hl)
        cp 0FFh
        jr z,.it
        ld c,a
        inc hl
        push hl
        call ui_rule
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        jr .r
.it:    inc hl
        call ui_items
        call wait_release
        ld bc,450                       ; (the attract sequence: 9 s)
.k:     push bc
        call wait_field
        call anykey
        pop bc
        jr nz,.key
        ld a,(hp_timed)
        or a
        jr z,.k
        dec bc
        ld a,b
        or c
        jr nz,.k
        ret                             ; Z: timed out
.key:   call wait_release
        or 1
        ret

txt_help:       db "PILOT'S HELP",0
HELP_RULES:     db 1,"FLIGHT",0, 8,"VIEWS AND CHARTS",0, 13,"DOCKED",0
                db 18,"PAUSED (CTRL)",0, 21,"JOYSTICK",0, 0FFh
HELP_ITEMS:
        db 3,2,"N M",0,"ROLL",0,        21,2,"S X",0,"DIVE CLIMB",0
        db 3,3,"SPC",0,"FASTER",0,      21,3,"SHF",0,"SLOWER",0
        db 3,4,"A",0,"LASERS",0,        21,4,"F",0,"SEEKER",0
        db 3,5,"E",0,"ECM",0,           21,5,"C",0,"DOCK COMPUTER",0
        db 3,6,"H",0,"HYPERSPACE",0,    21,6,"CTRL",0,"PAUSE",0
        db 3,7,"J",0,"JUMP DRIVE",0
        db 3,9,"1",0,"FRONT",0,         12,9,"2",0,"REAR",0
        db 21,9,"3",0,"LEFT",0,         30,9,"4",0,"RIGHT",0
        db 3,10,"I",0,"GALAXY",0,       21,10,"O",0,"LOCAL CHART",0
        db 3,11,"P",0,"SYSTEM DATA",0,  21,11,"F1",0,"HELP",0
        db 3,14,"1",0,"LAUNCH",0,       21,14,"2 3",0,"BUY SELL",0
        db 3,15,"4",0,"EQUIP",0,        21,15,"F",0,"REFUEL",0
        db 3,16,"S",0,"SAVE",0,         21,16,"L",0,"LOAD",0
        db 3,17,"5",0,"SHIPYARD",0
        db 3,19,"Q",0,"SOUND OFF",0,    21,19,"S",0,"SOUND ON",0
        db 3,22,"J",0,"ON THE TITLE: ON OFF",0
        db 0FFh

; ---------------------------------------------------------------------
; F3: the systems near us, zoomed in (a galaxy unit is a dot), names on
; those within reach, the fuel circle; cursors choose the jump target
; ---------------------------------------------------------------------
local_screen:
        ld hl,txt_local
        call ui_mapframe
        ld a,(cur_sys)                  ; every system's place on this map
        ld l,a
        ld h,high SYS_GX
        ld a,(hl)
        ld (lc_gx),a
        ld h,high SYS_GY
        ld a,(hl)
        ld (lc_gy),a
        ld b,0
.bl:    ld l,b
        ld h,high SYS_GX
        ld a,(lc_gx)
        ld c,a
        ld a,(hl)
        sub c
        jr c,.nx
        cp VW/2
        jr nc,.off
        jr .okx
.nx:    cp 256-VW/2+1
        jr c,.off
.okx:   add a,VW/2
        ld d,a
        ld h,high SYS_GY
        ld a,(lc_gy)
        ld c,a
        ld a,(hl)
        sub c
        jr c,.ny
        cp VH/2
        jr nc,.off
        jr .oky
.ny:    cp 256-VH/2+1
        jr c,.off
.oky:   add a,VH/2
        ld h,high LCY
        ld (hl),a
        ld h,high LCX
        ld (hl),d
        jr .bn
.off:   ld h,high LCX
        ld (hl),0FFh
.bn:    inc b
        jr nz,.bl
        ld a,(target_sys)               ; the cursor on the target, if shown
        ld l,a
        ld h,high LCX
        ld a,(hl)
        cp 0FFh
        jr nz,.tc
        ld a,VW/2
        ld (ch_x),a
        ld a,VH/2
        ld (ch_y),a
        jr .ti
.tc:    ld (ch_x),a
        ld h,high LCY
        ld a,(hl)
        ld (ch_y),a
.ti:    call chart_info
        call wait_release
        call fe_reset
.loop:  call wait_frame
        ld hl,LCX                       ; every star on the map, in its colour
.st:    ld a,(hl)
        cp 0FFh
        jr z,.sn
        ld b,a
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
        call plot
        pop hl
.sn:    inc l
        jr nz,.st
        ld hl,VW/2                      ; the fuel circle (a unit is 0.4 ly)
        ld (ccx),hl
        ld hl,VH/2
        ld (ccy),hl
        ld a,GREEN
        call set_col
        ld a,(fuel)
        srl a
        srl a
        cp 2
        jr nc,$+4
        ld a,2
        call circle
        ld a,YELLOW
        call set_col
        ld a,(ch_x)
        ld b,a
        ld a,(ch_y)
        ld c,a
        call chart_screen.cross
        call present
        call lc_names
        call fe_keys
        ld c,a
        bit 4,c
        jp nz,wait_release
        ld a,c
        and K_DIRS
        jr z,.loop
        call .step                      ; two dots a step: a unit is a dot
        call .step
        call lc_nearest
        cp 0FFh
        jp z,.loop
        ld hl,target_sys
        cp (hl)
        jp z,.loop
        ld (hl),a
        call chart_info
        jp .loop
.step:  ld hl,ch_x
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
        ret

; names beside the systems in jump range (after present, into VRAM)
lc_names:
        ld b,0
.l:     push bc
        ld l,b
        ld h,high LCX
        ld a,(hl)
        cp 0FFh
        jr z,.n
        ld a,(cur_sys)                  ; in range?
        push bc
        call sys_dist
        pop bc
        ld a,(fuel)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        jr z,.in
        jr nc,.n
.in:    ld l,b
        ld h,high LCX
        ld a,(hl)
        srl a
        inc a                           ; the cell after the dot
        cp 40-5
        jr nc,.n                        ; no room for it
        ld d,a
        ld h,high LCY
        ld a,(hl)
        srl a
        add a,VIEW_ROW
        ld c,a
        ld a,b
        call sys_name
        ex de,hl                        ; DE -> name
        ld b,h                          ; B = column
        push de
        call vaddr                      ; DE = VRAM
        pop hl
        ld b,5                          ; the first five letters
.c:     ld a,(hl)
        or a
        jr z,.n
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,WHITE<<4
        ld (de),a
        res 3,d
        inc hl
        inc de
        djnz .c
.n:     pop bc
        inc b
        jr nz,.l
        ret

; A = the shown system nearest the cursor (FFh: none within 12 dots)
lc_nearest:
        ld a,0FFh
        ld (nr_best),a
        ld a,13
        ld (lc_bd),a
        ld b,0
.l:     ld l,b
        ld h,high LCX
        ld a,(hl)
        cp 0FFh
        jr z,.n
        ld hl,ch_x
        sub (hl)
        jr nc,$+4
        neg
        ld c,a
        ld l,b
        ld h,high LCY
        ld a,(hl)
        ld hl,ch_y
        sub (hl)
        jr nc,$+4
        neg
        add a,c
        jr c,.n
        ld hl,lc_bd
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld a,b
        ld (nr_best),a
.n:     inc b
        jr nz,.l
        ld a,(nr_best)
        ret

txt_local:      db "NEARBY SYSTEMS",0

; ---------------------------------------------------------------------
; F4: this system - its planet and sun, and the facts
; ---------------------------------------------------------------------
sysinfo_screen:
        ld hl,txt_sysdata               ; the bezel; the picture above
        ld a,(cur_sys)
        call ui_title2
        ld de,txt_anykey
        ld b,20
        call ui_frame
        ld c,19
        ld hl,txt_s_facts
        call ui_rule
        ; the picture: the planet near, lit by its sun from its side
        ld hl,planet                    ; (kept, and put back after)
        ld de,si_save
        ld bc,6
        ldir
        ld hl,sunv
        ld bc,6
        ldir
        ld hl,SI_PLANET
        ld de,planet
        ld bc,6
        ldir
        ld a,(cur_sys)
        and 3
        ld e,a
        add a,a
        add a,e
        add a,a
        ld e,a
        ld d,0
        ld hl,SUN0
        add hl,de
        ld de,sunv
        ld bc,6
        ldir
        call planet_prep
        call span_clear
        call sun_draw
        call planet_draw
        xor a
        ld (pl_on),a
        call present
        ld hl,si_save
        ld de,planet
        ld bc,6
        ldir
        ld de,sunv
        ld bc,6
        ldir
        ; the facts
        ld hl,txt_econ
        ld bc,2*256+20
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
        ld bc,2*256+21
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
        ld hl,txt_techs
        ld bc,29*256+20
        ld a,CYAN<<4
        call print_at
        ld a,(cur_sys)
        ld l,a
        ld h,high SYS_TECH
        ld a,(hl)
        ld c,WHITE<<4
        call print_dec3
        ld hl,txt_star
        ld bc,2*256+22
        ld a,CYAN<<4
        call print_at
        ld a,(sun_col)
        ld hl,STAR_NAMES
        call nth_str
        ld c,WHITE<<4
        call print
        ld hl,txt_world
        ld bc,2*256+23
        ld a,CYAN<<4
        call print_at
        ld a,(pl_col)
        ld hl,WORLD_NAMES
        call nth_str
        ld c,WHITE<<4
        call print
        call wait_release
.k:     call wait_field
        call anykey
        jr z,.k
        jp wait_release

SI_PLANET:      dw 3600,-2400,12000     ; near, below and right of centre
txt_sysdata:    db "SYSTEM DATA - ",0
txt_s_facts:    db "THE SYSTEM",0
txt_star:       db "STAR        ",0
txt_world:      db "WORLD       ",0
txt_anykey:     db "ANY KEY TO GO ON",0
txt_techs:      db "TECH ",0
; by colour number (0..7)
STAR_NAMES:     db "-",0,"-",0,"RED DWARF",0,"-",0,"-",0,"BLUE GIANT",0
                db "YELLOW DWARF",0,"WHITE STAR",0
WORLD_NAMES:    db "-",0,"-",0,"VOLCANIC WORLD",0,"GAS GIANT",0,"JUNGLE WORLD",0
                db "OCEAN WORLD",0,"DESERT WORLD",0,"ICE WORLD",0
