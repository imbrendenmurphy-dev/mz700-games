; =====================================================================
;  screens.asm - title (spinning ships + waltz), docked, game over
; =====================================================================

title_screen:
        ld a,WHITE<<4
        call cls
        ld b,VIEW_ROW                   ; title letters in yellow
        ld c,5
        ld a,YELLOW<<4
        call clear_rows
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
.go:    ld hl,SONG_WALTZ
        call mus_play
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
        call .newship
        ld hl,330                       ; then the attract sequence
        ld (att_t),hl
        ; Each frame is nearly all music: the mixer only plays while we
        ; wait, so the ship is drawn once (every five bars) and the logo
        ; just shimmers.
.loop:  call wait_frame
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
        and K_FIRE
        jr nz,.start
        ld hl,(att_t)
        dec hl
        ld (att_t),hl
        ld a,h
        or l
        jr nz,.loop
        call mus_stop
        xor a                           ; Z: time for the demo
        ret
.start: call mus_stop
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
        call ori_forward
        ld b,4                          ; a three-quarter view
.r:     push bc
        ld a,3
        call roll_to_side
        ld a,3
        call pitch_up
        pop bc
        djnz .r
        ld hl,-40
        ld (ix+O_Y),l
        ld (ix+O_Y+1),h
        ld hl,200
        ld a,(title_ship)
        cp T_STATION
        jr nz,$+5
        ld hl,300
        ld (ix+O_Z),l
        ld (ix+O_Z+1),h
        ld a,CYAN
        call set_col
        call draw_obj
        call stamp_title
        call present
        ld a,70                         ; five bars of the waltz
        ld (title_t),a
        ret

; the logo's rows take turns to light up white
shimmer:
        ld hl,frame
        inc (hl)
        ld a,(hl)
        and 1
        ret nz
        ld a,(hl)
        rrca
        and 7
        ld c,a                          ; the lit row (0..7: 5..7 = none)
        ld hl,ARAM+VIEW_ROW*40
        ld b,0
.row:   ld a,b
        cp c
        ld a,YELLOW<<4
        jr nz,$+4
        ld a,WHITE<<4
        push bc
        ld b,40
.c:     ld (hl),a
        inc hl
        djnz .c
        pop bc
        inc b
        ld a,b
        cp 5
        jr c,.row
        ret

title_text:
        db SEP_ROW+1,WHITE<<4,"AN ORIGINAL SPACE TRADER FOR THE MZ-700",0
        db SEP_ROW+2,CYAN<<4,"CURSORS PITCH/ROLL  SPACE FIRE",0
        db SEP_ROW+3,CYAN<<4,"A/Z SPEED  H HYPERSPACE  DOCK: FLY IN",0
        db SEP_ROW+4,GREEN<<4,"SPACE LAUNCH  L LOAD PILOT  J JOYSTICK",0
        db SEP_ROW+5,BLUE<<4,"MUSIC: J. STRAUSS II - BLUE DANUBE",0
        db 0FFh

; big dotted STARHAUL in PIX cell rows 0..4 (each font dot = a full cell)
stamp_title:
        ld a,1                          ; rows 0..4 are in use
        ld (PIX+63),a
        ld (PIX+63+64),a
        ld (PIX+63+128),a
        ld (PIX+63+192),a
        ld (PIX+63+256),a
        ld hl,TITLEFONT
        ld de,PIX+4                     ; column 4
        ld b,8
.ch:    push bc
        push de
        ld b,5
.row:   push bc
        ld a,(hl)
        inc hl
        push de
        ld b,3
.bit:   bit 2,a
        jr z,.z
        ex de,hl
        ld (hl),0Fh+(YELLOW<<4)
        ex de,hl
.z:     inc de
        add a,a
        djnz .bit
        pop de
        ex de,hl
        ld bc,64
        add hl,bc
        ex de,hl
        pop bc
        djnz .row
        pop de
        ld a,e
        add a,4
        ld e,a
        pop bc
        djnz .ch
        ret

; ---------------------------------------------------------------------
gameover_screen:
        ld hl,SONG_OVER
        call mus_play
        ld a,WHITE<<4
        call cls
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
