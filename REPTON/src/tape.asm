; =====================================================================
;  tape.asm - save and load the whole game (state + every region) with
;  the monitor ROM's tape routines (1Z-013A: WRINF / WRDAT / RDINF /
;  RDDAT).  The file is an ordinary MZF data file "SKINK SAVE" of
;  SAVE_SIZE bytes from SAVEVARS, so it also works with a UniCMT.
; =====================================================================

SAVE_SIZE       equ WORLD_END-SAVEVARS

; fill the tape header at IBUFE
tape_header:
        ld hl,IBUFE
        ld de,IBUFE+1
        ld bc,127
        ld (hl),0
        ldir
        ld a,1                      ; attribute: object file
        ld (IBUFE),a
        ld hl,save_name
        ld de,IBUFE+1
        ld bc,17
        ldir
        ld hl,SAVE_SIZE
        ld (IBUFE+12h),hl
        ld hl,SAVEVARS
        ld (IBUFE+14h),hl
        ld hl,0
        ld (IBUFE+16h),hl
        ret

save_name:
        db "SKINK SAVE",0Dh,0Dh,0Dh,0Dh,0Dh,0Dh,0Dh

tape_screen:
        push hl
        call sfx_stop
        call mus_stop
        call out_off
        ld a,BLACK
        call cls
        pop hl
        ld c,0
        call heading
        ld hl,tape_lines
        jp print_lines

; tape_save: write the game to tape (status screen, S)
tape_save:
        call wait_release
        ld hl,txt_save_h
        call tape_screen
        ld hl,txt_rec_play
        ld c,8
        ld a,YELLOW*16
        call print_centre
        call tape_header
        call MON_WRINF
        jr c,tape_fail
        call MON_WRDAT
        jr c,tape_fail
        ld hl,txt_saved
tape_done:
        ld c,14
        ld a,GREEN*16
        call print_centre
        ld a,100
        call wait_fields
        ld a,1
        ld (hud_dirty),a
        xor a
        ret
tape_fail:
        ld hl,txt_tape_err
        ld c,14
        ld a,RED*16
        call print_centre
        ld a,100
        call wait_fields
        or 1
        ret

; tape_load: read a saved game.  Z if it worked.
tape_load:
        ld hl,txt_load_h
        call tape_screen
        ld hl,txt_play
        ld c,8
        ld a,YELLOW*16
        call print_centre
.again: call MON_RDINF
        jr c,tape_fail
        ; is it ours?
        ld hl,IBUFE+1
        ld de,save_name
        ld b,10
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.again                ; another file: keep looking
        inc hl
        inc de
        djnz .cmp
        ld hl,(IBUFE+12h)
        ld de,SAVE_SIZE
        or a
        sbc hl,de
        jr nz,tape_fail
        ld hl,SAVEVARS
        ld (IBUFE+14h),hl           ; load where it belongs
        call MON_RDDAT
        jr c,tape_fail
        ld hl,(save_magic)
        ld de,5348h
        or a
        sbc hl,de
        jr nz,tape_fail
        ld hl,txt_loaded
        jp tape_done
