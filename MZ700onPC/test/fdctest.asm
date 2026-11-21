; MZ700onPC floppy self-test: exercises the MB8876 through the MZ-1E05 ports on drive 1.
; Results at 3000h (00 = pass), then "FDC TEST DONE" on the screen:
;   3000 write+read-back of cyl 3 head 0 sector 5     3001 read address (6 bytes at 3010)
;   3002 format cyl 4 head 1 (write track)              3003 read back a formatted sector (all = 9)
;   3004 multi-sector read of sectors 1-3 then force interrupt
;   3005 interrupt-driven read (DF bit 0, IM 1, handler at 1038h)
;   3006 seek to cylinder 0 sets TRACK00 in the status
; Needs a formatted, writable disk:  mzemu -e "diskblank t.dsk; disk t.dsk; mzt fdctest.mzt; ..."
        org 1200h
RES     equ 3000h
BUF     equ 4000h
TRK     equ 5000h               ; write-track stream

start:  di
        ld a, 4                 ; PC2 = 0: no 8253 interrupts during the test
        ld (0E003h), a
        ld sp, 10F0h
        ld hl, RES
        ld b, 32
clr:    ld (hl), 0EEh
        inc hl
        djnz clr
        ld a, 84h               ; motor on, drive 1
        out (0DCh), a
rdy:    in a, (0D8h)
        cpl
        bit 7, a
        jr nz, rdy
        ld a, 0FFh ^ 08h        ; restore
        call cmd

; ---- 1: write cyl 3 head 0 sector 5 with 0..255, read it back
        ld a, 3
        call seek
        xor a
        out (0DDh), a
        ld a, 0FFh ^ 5
        out (0DAh), a
        ld a, 0FFh ^ 0A0h       ; write sector
        out (0D8h), a
        ld b, 0
        ld c, 0
wr1:    in a, (0D8h)
        bit 1, a
        jr nz, wr1
        ld a, c
        out (0DBh), a
        inc c
        djnz wr1
        call waitst
        ld hl, BUF
        ld a, 0FFh ^ 80h
        call readsec
        ld hl, BUF
        ld b, 0
        ld c, 0
cmp1:   ld a, (hl)
        cp c
        jr nz, bad1
        inc hl
        inc c
        djnz cmp1
        xor a
        jr r1
bad1:   ld a, 1
r1:     or e                    ; plus the status error bits
        ld (RES), a

; ---- 2: read address
        ld a, 0FFh ^ 0C0h
        out (0D8h), a
        ld hl, RES + 10h
        ld b, 6
ra:     in a, (0D8h)
        bit 1, a
        jr nz, ra
        in a, (0DBh)
        cpl                     ; ID bytes come off the disk as they are: undo the bus inversion
        ld (hl), a
        inc hl
        djnz ra
        call waitst
        ld a, (RES + 10h)       ; cylinder must be 3
        sub 3
        or e
        ld (RES + 1), a

; ---- 3: format cyl 4 head 1: 16 x 256, sector R filled with R
        ld a, 4
        call seek
        ld a, 1
        out (0DDh), a
        call buildtrk
        ld a, 0FFh ^ 0F0h       ; write track
        out (0D8h), a
        ld hl, TRK
wt:     in a, (0D8h)
        bit 0, a                ; raw 1 = not busy
        jr nz, wtend
        bit 1, a
        jr nz, wt
        ld a, (hl)
        cpl                     ; the stream goes to the disk as written: complement it on the bus
        out (0DBh), a
        inc hl
        jr wt
wtend:  in a, (0D8h)
        cpl
        and 44h                 ; write protect / lost data
        ld (RES + 2), a

; ---- 4: read sector 9 of the new track: 256 x 09h (stored complemented, so the CPU sees F6h... see below)
        ld a, 0FFh ^ 9
        out (0DAh), a
        ld hl, BUF
        ld a, 0FFh ^ 80h
        call readsec
        ld hl, BUF
        ld b, 0
cmp4:   ld a, (hl)
        cp 0F6h                 ; the format data was 09h on the disk = F6h to the CPU
        jr nz, bad4
        inc hl
        djnz cmp4
        ld a, e
        jr r4
bad4:   ld a, 1
r4:     ld (RES + 3), a

; ---- 5: multi-sector read from sector 1; stop with force interrupt after 3 sectors
        ld a, 0FFh ^ 1
        out (0DAh), a
        ld a, 0FFh ^ 90h
        out (0D8h), a
        ld hl, BUF
        ld de, 768
mr:     in a, (0D8h)
        bit 1, a
        jr nz, mr
        in a, (0DBh)
        ld (hl), a
        inc hl
        dec de
        ld a, d
        or e
        jr nz, mr
        ld a, 0FFh ^ 0D0h       ; force interrupt
        out (0D8h), a
        call waitst
        ld a, (BUF + 100h)      ; sector 2 = F6h ^ 9 ^ 2 ... check first bytes of sectors 1, 2, 3
        cp 0FDh                 ; ~02h
        jr nz, bad5
        ld a, (BUF + 200h)
        cp 0FCh                 ; ~03h
        jr nz, bad5
        ld a, (BUF)
        cp 0FEh                 ; ~01h
        jr nz, bad5
        in a, (0DAh)
        cpl
        sub 3                   ; sector register stopped at 3
        jr r5
bad5:   ld a, 1
r5:     ld (RES + 4), a

; ---- 6: interrupt-driven read of sector 7 (DF bit 0: INT while DRQ)
        ld a, 0C3h
        ld (1038h), a
        ld hl, isr
        ld (1039h), hl
        exx                     ; HL' = buffer, C' = data port, B' = count
        ld hl, BUF
        ld bc, 00DBh
        exx
        im 1
        ld a, 0FFh ^ 7
        out (0DAh), a
        ld a, 1
        out (0DFh), a
        ld a, 0FFh ^ 80h
        out (0D8h), a
        ei
iw:     in a, (0D8h)
        rrca
        jr nc, iw               ; until not busy
        di
        xor a
        out (0DFh), a
        exx
        push hl
        exx
        pop hl
        ld de, BUF + 256
        or a
        sbc hl, de              ; 256 bytes by interrupt
        ld a, l
        or h
        jr nz, bad6
        ld a, (BUF + 0FFh)
        cp 0F8h                 ; ~07h
        jr nz, bad6
        xor a
        jr r6
bad6:   ld a, 1
r6:     ld (RES + 5), a

; ---- 7: seek to 0 -> TRACK00
        xor a
        call seek
        in a, (0D8h)
        cpl
        and 4
        xor 4
        ld (RES + 6), a

        xor a
        out (0DCh), a
        ld hl, msg
        ld de, 0D000h
        ld bc, 13
        ldir
done:   jr done

isr:    exx                     ; ~70 T with the monitor's JP 1038h: inside the 113 T byte time
        ini
        exx
        ei
        ret

; ---- helpers
cmd:    out (0D8h), a
waitst: in a, (0D8h)
        rrca
        jr nc, waitst
        in a, (0D8h)
        cpl
        and 9Ch
        ld e, a
        ret

seek:   cpl
        out (0DBh), a
        ld a, 0FFh ^ 18h
        jr cmd

readsec:                        ; A = command, HL = buffer, 256 bytes; E = error bits
        out (0D8h), a
        ld b, 0
rs:     in a, (0D8h)
        bit 1, a
        jr z, rsg
        bit 0, a
        jr z, rs
        jr rse
rsg:    in a, (0DBh)
        ld (hl), a
        inc hl
        djnz rs
rse:    jr waitst

buildtrk:
        ld hl, TRK
        ld a, 4Eh
        ld b, 80
        call fill
        xor a
        ld b, 12
        call fill
        ld a, 0F6h
        ld b, 3
        call fill
        ld (hl), 0FCh
        inc hl
        ld a, 4Eh
        ld b, 50
        call fill
        ld c, 1
bsec:   xor a
        ld b, 12
        call fill
        ld a, 0F5h
        ld b, 3
        call fill
        ld (hl), 0FEh
        inc hl
        ld (hl), 4
        inc hl
        ld (hl), 1
        inc hl
        ld (hl), c
        inc hl
        ld (hl), 1
        inc hl
        ld (hl), 0F7h
        inc hl
        ld a, 4Eh
        ld b, 22
        call fill
        xor a
        ld b, 12
        call fill
        ld a, 0F5h
        ld b, 3
        call fill
        ld (hl), 0FBh
        inc hl
        ld a, c
        ld b, 0
        call fill               ; 256 bytes of R
        ld (hl), 0F7h
        inc hl
        ld a, 4Eh
        ld b, 54
        call fill
        inc c
        ld a, c
        cp 17
        jr nz, bsec
        ld a, 4Eh               ; tail gap
        ld b, 0
        call fill
        ld b, 0
        call fill
        ld b, 0
        call fill
        ret
fill:   ld (hl), a
        inc hl
        djnz fill
        ret

msg:    db 6, 4, 3, 0, 20, 5, 19, 20, 0, 4, 15, 14, 5      ; FDC TEST DONE (display codes)
