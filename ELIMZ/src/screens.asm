; =====================================================================
;  screens.asm - title (the ARGOSY logo, spinning ships, the waltz),
;  game over
; =====================================================================

title_screen:
        ld a,WHITE<<4
        call cls
        call logo_draw                  ; the logo, straight into VRAM
        ld b,VIEW_ROW+6                 ; ships in cyan
        ld c,12
        ld a,CYAN<<4
        call clear_rows
        ld hl,title_text
.t:     ld a,(hl)
        cp 0FFh
        jr z,.go
        inc hl
        ld c,a
        ld a,(hl)
        inc hl
        push hl
        call print_centre
        pop hl
.s:     ld a,(hl)                       ; skip to the next entry
        inc hl
        or a
        jr nz,.s
        jr .t
.go:    ld c,SEP_ROW                    ; the panel's bezel
        ld hl,0
        call ui_rule
        ld a,SEP_ROW+1
        call ui_sides
        ld bc,1C00h+24
        ld e,1Dh
        call ui_hline
        ld hl,txt_tfoot
        ld c,24
        ld a,GREEN<<4
        call ui_inset
        call snd_fl                     ; the waltz on the tracker: it needs
        ld a,(trk_on)                   ; no CPU, so the ship spins every frame
        or a                            ; (it plays on through the attract
        ld hl,TRK_WALTZ                 ; screens)
        call z,trk_play
        ld hl,objects
        ld de,objects+1
        ld bc,MAXOBJ*OBJSZ-1
        ld (hl),0
        ldir
        ld a,T_DART
        ld (title_ship),a
        call fe_reset
        ld a,1
        ld (state),a                    ; no crosshair
        xor a
        ld (title_ang),a
        ld hl,tstars                    ; stars at random places
        ld b,2*NTSTARS
.st:    push hl
        call rand
        pop hl
        ld (hl),a
        inc hl
        djnz .st
        call .newship
        ld hl,330                       ; then the attract sequence
        ld (att_t),hl
.loop:  call wait_frame
        call .spin
        call shimmer
        ld hl,title_t
        dec (hl)
        call z,.next
        call getkey                     ; L: load a saved pilot
        cp 'L'
        jr nz,.nl
        ld a,1
        ld (load_req),a
        jr .start
.nl:    cp 'J'                          ; J: joystick on / off
        jr nz,.nj
        call joy_toggle
        ld c,SEP_ROW+4
        ld a,GREEN<<4
        call print_centre
        call wait_release
        ld hl,330                       ; a fresh wait before the demo
        ld (att_t),hl
.nj:    call read_flight
        and K_FIRE+K_FAST               ; SPACE, A or the joystick's fire
        jr nz,.start
        ld hl,(att_t)
        dec hl
        ld (att_t),hl
        ld a,h
        or l
        jr nz,.loop
        xor a                           ; Z: time for the demo
        ret
.start: call mus_stop
        call snd_fe
        or 1
        ret
.next:  ld a,(title_ship)
        inc a
        cp T_SEEKER
        jr c,$+4
        ld a,T_STATION
        ld (title_ship),a
.newship:
        ld ix,objects
        ld a,(title_ship)
        ld (ix+O_TYPE),a
        ld hl,-40                       ; (below the logo)
        ld (ix+O_Y),l
        ld (ix+O_Y+1),h
        ld hl,150
        ld a,(title_ship)
        cp T_STATION
        jr nz,$+5
        ld hl,330
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        ld a,128                        ; two turns each
        ld (title_t),a
        ret

; one step of the spin: the stars drift by (near ones faster), then
; the next of 64 orientations, in the ship's own colour, under the logo
.spin:  ld a,WHITE
        call set_col
        ld hl,tstars
        ld b,NTSTARS
.sl:    ld a,(hl)                       ; x (0..255: 80 dots + off screen)
        sub 1
        bit 0,b
        jr z,$+4
        sub 1                           ; every other star is nearer
        ld (hl),a
        inc hl
        cp 80
        jr nc,.sn
        push bc
        push hl
        ld b,a
        ld a,(hl)                       ; y: dot rows 12..35
        and 1Fh
        cp 24
        jr c,$+4
        sub 12
        add a,12
        ld c,a
        call plot
        pop hl
        pop bc
.sn:    inc hl
        djnz .sl
        ld a,(title_ang)
        inc a
        and 63
        ld (title_ang),a
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de                       ; * 9
        ld de,SPIN
        add hl,de
        ld de,objects+O_SIDE            ; bytes -> words (high bytes)
        ld b,9
.sp:    xor a
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        djnz .sp
        ld a,(title_ship)
        ld hl,TYPE_COL-1
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        call set_col
        ld ix,objects
        call draw_obj
        jp present

; the logo's glint: a slanted white streak sweeps across the yellow
; letters, two columns a call, then a rest (26 calls in 64 sweep)
shimmer:
        ld hl,frame
        inc (hl)
        ld a,(hl)
        and 63
        cp 26
        ret nc
        add a,a
        sub 4
        ld c,a                          ; the streak's column on the top row
        ld hl,ARAM+VIEW_ROW*40
        ld b,5
.row:   ld a,c
        sub 2
        ld e,YELLOW<<4                  ; behind it: back to yellow
        call .cell
        call .cell
        ld e,WHITE<<4                   ; the streak, two cells wide
        call .cell
        call .cell
        ld de,40
        add hl,de
        dec c                           ; leaning: one column left a row
        djnz .row
        ret
; colour column A of the row at HL with E, if on the screen; A + 1
.cell:  cp 40
        jr nc,.n
        push hl
        push af
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),e
        pop af
        pop hl
.n:     inc a
        ret

; the logo (build.py: LOGO) into VRAM rows 1..5, from column 2, yellow
logo_draw:
        ld b,VIEW_ROW
        ld c,5
        ld a,YELLOW<<4
        call clear_rows
        ld hl,SHD                       ; present leaves these rows alone
        ld de,SHD+1
        ld bc,5*64-1
        ld (hl),0
        ldir
        ld hl,LOGO
        ld de,VRAM+VIEW_ROW*40+2
        ld c,5
.r:     ld b,36
.l:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .l
        ex de,hl
        ld a,c
        ld bc,4
        add hl,bc
        ld c,a
        ex de,hl
        dec c
        jr nz,.r
        ret

title_text:
        db SEP_ROW+1,WHITE<<4,"ORIGINAL SPACE TRADING FOR THE MZ-700",0
        db SEP_ROW+2,CYAN<<4,"N/M ROLL  S/X DIVE  A FIRE  F1 HELP",0
        db SEP_ROW+3,CYAN<<4,"SPACE/SHIFT SPEED   1-4 VIEWS",0
        db SEP_ROW+4,BLUE<<4,"MUSIC: J. STRAUSS II - BLUE DANUBE",0
        db 0FFh
txt_tfoot:      db "SPACE START  L LOAD  J JOYSTICK",0

; ---------------------------------------------------------------------
gameover_screen:
        ld hl,TRK_OVER
        call trk_play
        ld hl,txt_over
        ld de,0
        ld b,1
        call ui_frame
        ld hl,txt_over
        ld c,8
        ld a,RED<<4
        call print_centre
        ld bc,13*256+12
        ld a,WHITE<<4
        ld hl,txt_kills
        call print_at
        ld de,VRAM+12*40+22
        ld c,WHITE<<4
        ld a,(kills)
        call print_dec3
        ld b,200
.w:     push bc
        call wait_field
        pop bc
        djnz .w
        call mus_stop
        jp wait_release

txt_kills:      db "KILLS",0
txt_over:       db "G A M E   O V E R",0
