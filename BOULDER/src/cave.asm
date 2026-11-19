; =====================================================================
;  cave.asm - cave loading and the physics scan
;
;  The cave is 40 x 22 cells, one byte each: bits 0-4 = element (E_*),
;  bit 7 = "already moved this tick".  The scan runs top to bottom, left
;  to right.  An object that moves right or down (into a cell the scan has
;  not reached yet) is written with bit 7 set, and the scan clears the bit
;  instead of processing that cell, so nothing moves twice per tick.
; =====================================================================

; ---------------------------------------------------------------------
; cave_load: unpack cave (cave_no) into CAVE, set up the cave variables
; ---------------------------------------------------------------------
cave_load:
        ld a,(cave_no)
        add a,a
        ld e,a
        ld d,0
        ld hl,CAVETAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (cave_hdr),hl
        push hl
        pop ix
        ld a,(ix+CH_NEED)
        ld (need),a
        ld a,(ix+CH_DVAL)
        ld (dval),a
        ld a,(ix+CH_XVAL)
        ld (xval),a
        ld a,(ix+CH_SPEED)
        ld (speed),a
        ld a,(ix+CH_MAGIC)
        ld (magic_time),a
        ld a,(ix+CH_AMOEBA)
        ld (amoeba_slow),a
        ld b,(ix+CH_TIME)           ; time: less on higher levels
        ld a,(level)
        or a
        jr z,.tset
        ld c,a
.tl:    ld a,b
        sub 15
        cp 60
        jr c,.tset
        ld b,a
        dec c
        jr nz,.tl
.tset:  ld a,b
        ld (ctime),a
        ld a,(level)                ; faster ticks on later levels
        cp 2
        jr c,.sp
        ld a,(speed)
        cp 5
        jr c,.sp
        dec a
        ld (speed),a
.sp:
        xor a
        ld (got),a
        ld (exit_open),a
        ld (magic_state),a
        ld (amoeba_conv),a
        ld (amoeba_fast),a
        ld (pl_dead),a
        ld (pl_exit),a
        ld (pl_frozen),a
        ld (pl_face),a
        ld (pl_moved),a
        ld (latch),a
        ld (pref),a
        ld (ai_keys),a
        ld (flash),a
        ld (end_time),a
        ld a,16
        ld (inbox_time),a
        ld a,(amoeba_slow)
        or a
        jr nz,.am
        inc a
        ld (amoeba_fast),a          ; no slow phase
.am:
        ; whole cave = steel, then unpack the 38 x 20 interior
        ld hl,CAVE
        ld de,CAVE+1
        ld bc,CAVESZ-1
        ld (hl),E_STEEL
        ldir
        ld de,CH_DATA
        add ix,de
        push ix
        pop hl
        ld de,CAVE+CAVEW+1
        ld c,CAVEH-2
.row:   ld b,(CAVEW-2)/2
.byte:  ld a,(hl)
        inc hl
        push af
        rrca
        rrca
        rrca
        rrca
        call .put
        pop af
        call .put
        djnz .byte
        inc de
        inc de
        dec c
        jr nz,.row
        ; find the inbox and the exit
        ld hl,CAVE
        ld bc,CAVESZ
.find:  ld a,(hl)
        cp E_INBOX
        jr nz,.f1
        ld (pl_addr),hl
.f1:    cp E_EXIT
        jr nz,.f2
        ld (exit_addr),hl
.f2:    inc hl
        dec bc
        ld a,b
        or c
        jr nz,.find
        ld a,1
        ld (hud_dirty),a
        ret

.put:   push hl
        and 0Fh
        ld hl,PACKMAP
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (de),a
        inc de
        pop hl
        ret

; ---------------------------------------------------------------------
; cave_scan: one tick of physics over rows 1..20
; ---------------------------------------------------------------------
cave_scan:
        ld hl,0
        ld (amoeba_cnt),hl
        xor a
        ld (amoeba_grow),a
        ld hl,CAVE+CAVEW
        ld a,CAVEH-2
        ld (scan_rows),a
.row:   ld b,CAVEW
.cell:  ld a,(hl)
        or a
        jr z,.next                  ; space
        jp m,.flag
        cp E_BOULDER
        jr c,.next                  ; dirt, walls, exits: nothing to do
        push bc
        ld (scan_ptr),hl
        add a,a
        ld e,a
        ld d,high JTAB
        ld a,(de)
        ld (.cs+1),a
        inc e
        ld a,(de)
        ld (.cs+2),a
.cs:    call 0
        ld hl,(scan_ptr)
        pop bc
.next:  inc hl
        djnz .cell
        call poll
        ld a,(scan_rows)
        dec a
        ld (scan_rows),a
        jr nz,.row
        ; amoeba bookkeeping
        ld a,(amoeba_conv)
        or a
        ret nz
        ld hl,(amoeba_cnt)
        ld a,h
        or l
        ret z
        ld de,-200
        add hl,de
        jr c,.toobig
        ld a,(amoeba_grow)
        or a
        ret nz
        ld a,2                      ; boxed in: becomes diamonds
        ld (amoeba_conv),a
        ld hl,SFX_AMOEBA
        ld a,3
        jp sfx
.toobig:
        ld a,1                      ; too big: turns to stone
        ld (amoeba_conv),a
        ld hl,SFX_AMOEBA
        ld a,3
        jp sfx
.flag:  and 7Fh
        ld (hl),a
        jr .next

; handlers: HL = cell, may change every register
; ---------------------------------------------------------------------
; boulder / diamond at rest
h_rest:
        ld a,(hl)
        ld c,a                      ; c = element
        ld de,CAVEW
        push hl
        add hl,de
        ld a,(hl)                   ; below
        pop hl
        or a
        jr nz,.notfall
        ; start falling: move down now
        ld (hl),0
        add hl,de
        ld a,c
        inc a                       ; E_BOULDERF / E_DIAMONDF
        or 80h
        ld (hl),a
        ret
.notfall:
        and 1Fh
        call is_round
        ret nz
        ld a,c
        inc a
        ld c,a                      ; rolls as a falling object
        jp try_roll

; falling boulder / diamond
h_fall:
        ld a,(hl)
        ld c,a
        ld de,CAVEW
        push hl
        add hl,de
        ld a,(hl)
        and 1Fh
        ex de,hl                    ; DE = below
        pop hl
        or a
        jr nz,.hit
        ld (hl),0                   ; keep falling
        ld a,c
        or 80h
        ld (de),a
        ret
.hit:   cp E_MAGIC
        jp z,.magic
        cp E_PLAYER
        jr z,.boom
        cp E_FIRE0
        jr c,.solid
        cp E_BUTT0
        jr c,.boom
        cp E_AMOEBA
        jr nc,.solid
        ex de,hl                    ; crushed a butterfly: diamonds
        ld b,E_DEX1
        jp explode
.boom:  ex de,hl
        ld b,E_EXP1
        jp explode
.solid: cp E_BOULDERF
        ret z                       ; resting on another falling object: wait
        cp E_DIAMONDF
        ret z
        call is_round
        jr nz,.land
        push hl
        push bc
        call try_roll
        pop bc
        pop hl
        ld a,(hl)
        cp c
        ret nz                      ; it rolled away
.land:  ld a,c
        dec a                       ; at rest
        ld (hl),a
        cp E_DIAMOND
        ld hl,SFX_LAND
        jr nz,.snd
        ld hl,SFX_CHIME
.snd:   ld a,1
        jp sfx
.magic: ld a,(magic_state)
        cp 2
        jr z,.land                  ; spent: just a wall
        or a
        jr nz,.active
        ld a,1                      ; wake the wall
        ld (magic_state),a
        ld a,1
        ld (hud_dirty),a
.active:
        ld (hl),0                   ; the object vanishes into the wall...
        ex de,hl
        ld de,CAVEW
        add hl,de
        ld a,(hl)                   ; ...and comes out below, if there is room
        or a
        jr nz,.gone
        ld a,c
        xor E_BOULDERF ^ E_DIAMONDF ; boulder <-> diamond
        or 80h
        ld (hl),a
.gone:  ld hl,SFX_MAGIC
        ld a,1
        jp sfx

; Z if element A is rounded (things roll off it)
is_round:
        cp E_BOULDER
        ret z
        cp E_DIAMOND
        ret z
        cp E_BRICK
        ret z
        cp E_EXPWALL
        ret

; roll the object at HL left or right if both the side and the cell
; below the side are empty.  C = element (falling code) to move.
try_roll:
        dec hl
        ld a,(hl)
        or a
        jr nz,.right
        ld de,CAVEW
        push hl
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.right
        ld (hl),c                   ; left: already scanned, no flag
        inc hl
        ld (hl),0
        ret
.right: inc hl
        inc hl
        ld a,(hl)
        or a
        ret nz
        ld de,CAVEW
        push hl
        add hl,de
        ld a,(hl)
        pop hl
        or a
        ret nz
        ld a,c
        or 80h
        ld (hl),a
        dec hl
        ld (hl),0
        ret

; ---------------------------------------------------------------------
; firefly (left-hand wall follower) and butterfly (right-hand)
h_fly:
        ld a,(hl)
        ld c,a
        ; touching the player or the amoeba: explode
        ld de,DIROFF
        ld b,4
.chk:   push hl
        ld a,(de)
        inc de
        add a,l
        ld l,a
        ld a,(de)
        inc de
        adc a,h
        ld h,a
        ld a,(hl)
        pop hl
        and 1Fh
        cp E_PLAYER
        jr z,.boom
        cp E_AMOEBA
        jr z,.boom
        djnz .chk
        ld a,c
        cp E_BUTT0
        jr nc,.butt
        sub E_FIRE0
        ld b,a                      ; dir
        dec a                       ; firefly: try turning left first
        and 3
        call .try
        ret z
        ld a,b                      ; then straight on
        call .try
        ret z
        ld a,b                      ; else turn right on the spot
        inc a
        and 3
        add a,E_FIRE0
        ld (hl),a
        ret
.butt:  sub E_BUTT0
        ld b,a
        inc a                       ; butterfly: try turning right first
        and 3
        add a,4                     ; mark "butterfly" in bit 2 for .try
        call .try
        ret z
        ld a,b
        add a,4
        call .try
        ret z
        ld a,b
        dec a
        and 3
        add a,E_BUTT0
        ld (hl),a
        ret
.boom:  ld a,c
        cp E_BUTT0
        ld b,E_EXP1
        jr c,.b1
        ld b,E_DEX1
.b1:    jp explode

; A = dir (+4 for butterfly). Moves the creature at HL if that cell is
; empty (Z) else NZ.  Keeps B, C, HL.
.try:   push bc
        ld c,a
        and 3
        add a,a
        add a,low DIROFF
        ld e,a
        ld d,high DIROFF            ; DIROFF does not cross a page
        ld a,(de)
        inc e
        push hl                     ; the cell
        add a,l
        ld l,a
        ld a,(de)
        adc a,h
        ld h,a                      ; HL = target
        ld a,(hl)
        or a
        jr nz,.no
        ld a,c
        and 3
        bit 2,c
        jr z,.ff
        add a,E_BUTT0-E_FIRE0
.ff:    add a,E_FIRE0
        bit 1,c                     ; dirs 2 (right) and 3 (down) are ahead in the scan
        jr z,.nf
        or 80h
.nf:    ld (hl),a
        pop hl
        ld (hl),0
        pop bc
        xor a
        ret
.no:    pop hl
        pop bc
        or 1
        ret

; ---------------------------------------------------------------------
; amoeba
h_amoeba:
        ld de,(amoeba_cnt)
        inc de
        ld (amoeba_cnt),de
        ld a,(amoeba_conv)
        or a
        jr z,.live
        dec a
        ld a,E_BOULDER
        jr z,.cv
        ld a,E_DIAMOND
.cv:    ld (hl),a
        ret
.live:  ld a,(amoeba_grow)          ; still room to grow somewhere?
        or a
        jr nz,.grow
        ld de,DIROFF
        ld b,4
.chk:   push hl
        ld a,(de)
        inc de
        add a,l
        ld l,a
        ld a,(de)
        inc de
        adc a,h
        ld h,a
        ld a,(hl)
        pop hl
        cp E_DIRT+1
        jr nc,.n
        ld a,1
        ld (amoeba_grow),a
        jr .grow
.n:     djnz .chk
.grow:  push hl
        call rand
        pop hl
        ld b,a
        ld a,(amoeba_fast)
        or a
        ld a,6                      ; chance per tick out of 256
        jr z,$+4
        ld a,48
        cp b
        ret c
        ret z
        ld a,(seed+1)
        and 3
        ld e,a
        add a,a
        add a,low DIROFF
        ld c,a
        ld b,high DIROFF
        ld a,(bc)
        inc c
        push hl
        add a,l
        ld l,a
        ld a,(bc)
        adc a,h
        ld h,a
        ld a,(hl)
        cp E_DIRT+1
        jr nc,.nogrow
        ld a,E_AMOEBA
        bit 1,e
        jr z,$+4
        or 80h
        ld (hl),a
.nogrow:
        pop hl
        ret

; ---------------------------------------------------------------------
; expanding wall: grows sideways into empty space
h_expwall:
        dec hl
        ld a,(hl)
        or a
        jr nz,.r
        ld (hl),E_EXPWALL
.r:     inc hl
        inc hl
        ld a,(hl)
        or a
        ret nz
        ld (hl),E_EXPWALL+80h
        ret

; explosion stages
h_exp:
        ld a,(hl)
        cp E_EXP4
        jr z,.done
        inc a
        ld (hl),a
        ret
.done:  ld (hl),E_SPACE
        ret

h_dex:
        ld a,(hl)
        cp E_DEX4
        jr z,.done
        inc a
        ld (hl),a
        ret
.done:  ld (hl),E_DIAMOND
        ret

; inbox: becomes the player when the countdown ends
h_inbox:
        ld a,(inbox_time)
        or a
        ret nz
        ld (hl),E_PLAYER
        ld (pl_addr),hl
        ld hl,SFX_BORN
        ld a,2
        jp sfx

h_none:
        ret

; ---------------------------------------------------------------------
; explode: HL = centre, B = first stage (E_EXP1 or E_DEX1).  Fills the
; 3 x 3 block except indestructible cells.
; ---------------------------------------------------------------------
explode:
        push hl
        ld hl,SFX_BOOM
        ld a,4
        call sfx
        pop hl
        ld de,-CAVEW-1
        add hl,de
        ld c,3
.r:     push bc
        ld c,3
.c:     ld a,(hl)
        and 1Fh
        cp E_STEEL
        jr z,.skip
        cp E_EXIT
        jr z,.skip
        cp E_EXITO
        jr z,.skip
        cp E_INBOX
        jr z,.skip
        cp E_PLAYER
        jr nz,.np
        ld a,1
        ld (pl_dead),a
.np:    push hl
        ld de,(scan_ptr)
        or a
        sbc hl,de
        pop hl
        ld a,b
        jr c,.st
        jr z,.st
        or 80h                      ; not reached by the scan yet
.st:    ld (hl),a
.skip:  inc hl
        dec c
        jr nz,.c
        ld de,CAVEW-3
        add hl,de
        pop bc
        dec c
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; open_exit: called when enough diamonds are collected
; ---------------------------------------------------------------------
open_exit:
        ld a,1
        ld (exit_open),a
        ld (hud_dirty),a
        ld a,6
        ld (flash),a
        ld hl,(exit_addr)
        ld (hl),E_EXITO
        ld hl,SFX_EXIT
        ld a,5
        jp sfx
