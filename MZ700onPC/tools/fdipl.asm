; MZ700onPC built-in floppy IPL - an original stand-in for the MZ-1E05 interface ROM (F000-FFFF).
; Used when roms\mz1e05.rom is not present. Type F at the 1Z-013A monitor (it jumps to F000 when the byte there
; is 00) or use Boot disk in the emulator. Boots a Sharp IPL disk from drive 1:
;   record 0 = 03 "IPLPRO" name(13, 0Dh-terminated) ... 14h size, 16h load, 18h exec, 1Eh first record
; Record r: logical track r/16, sector r%16+1; logical track t = cylinder t/2, head (t&1)^1.
; The MB8876 has an inverted data bus: command, status, track and sector values are complemented (CPL) on the
; way in and out; sector data is not, because MZ disks hold every byte complemented.
; Assemble: sjasmplus --raw=fdipl.bin fdipl.asm   (tools\mkipl.ps1 turns it into src\FdIpl.cs)

LETNL   equ 0006h
MSG     equ 0015h
GETKY   equ 001Bh
BUF     equ 0CF00h          ; one record
NAMEB   equ 0CEE0h          ; name copy + 0Dh
REC     equ 0CEF0h          ; next record
DEST    equ 0CEF2h          ; next load address
LEFT    equ 0CEF4h          ; bytes still to load
TRIES   equ 0CEF6h

        org 0F000h
        nop                 ; the monitor's F command needs 00 here
        jr start
        db "MZ700onPC IPL 1.0", 0

start:  call LETNL
        ld de, m_boot
        call MSG
        ld a, 84h           ; motor on, latch drive 0
        out (0DCh), a
        ld hl, 0            ; wait up to ~3 s for READY
        ld b, 4
rdy:    in a, (0D8h)
        cpl
        bit 7, a
        jr z, ready
        dec hl
        ld a, h
        or l
        jr nz, rdy
        djnz rdy
        ld de, m_nodisk
        jp fail

ready:  ld a, 0FFh ^ 08h  ; RESTORE, head load, 6 ms steps
        out (0D8h), a
        call wait

        ld hl, 0
        ld (REC), hl
        ld de, BUF
        call rdrec
        jp c, ioerr
        ld hl, BUF + 1      ; "IPLPRO"?
        ld de, sig
        ld b, 6
chk:    ld a, (de)
        cp (hl)
        jp nz, notboot
        inc hl
        inc de
        djnz chk

        ld hl, BUF + 7      ; print the name
        ld de, NAMEB
        ld bc, 13
        ldir
        ld a, 0Dh
        ld (de), a
        call LETNL
        ld de, m_load
        call MSG
        ld de, NAMEB
        call MSG

        ld hl, (BUF + 14h)
        ld (LEFT), hl
        ld hl, (BUF + 16h)
        ld (DEST), hl
        ld a, h             ; loading below 1000h (CP/M and other MZ-800 style
        cp 10h              ; systems): put RAM at 0000 first, as the MZ-800
        jr nc, hiload       ; IPL does - the monitor is not needed after this
        out (0E0h), a
hiload: ld hl, (BUF + 1Eh)
        ld (REC), hl
        ld hl, (BUF + 18h)  ; keep exec on the stack
        push hl

next:   ld hl, (LEFT)
        ld a, h
        or l
        jr z, go
        ld de, (DEST)
        ld a, h             ; a whole record left: read straight into place
        or a
        jr z, part
        call rdrec
        jr c, ioerr2
        ld hl, (DEST)
        inc h
        ld (DEST), hl
        ld hl, (LEFT)
        dec h
        ld (LEFT), hl
        jr adv
part:   ld de, BUF          ; the last part-record: via the buffer
        call rdrec
        jr c, ioerr2
        ld hl, BUF
        ld de, (DEST)
        ld bc, (LEFT)
        ldir
        ld hl, 0
        ld (LEFT), hl
adv:    ld hl, (REC)
        inc hl
        ld (REC), hl
        jr next

go:     xor a               ; motor off and run
        out (0DCh), a
        ret                 ; to exec

ioerr2: pop hl
ioerr:  ld de, m_err
        jr fail
notboot:
        ld de, m_notboot
fail:   push de
        xor a
        out (0DCh), a
        call LETNL
        pop de
        call MSG
        call LETNL
        ld de, m_key
        call MSG
key:    call GETKY
        or a
        jr z, key
        rst 0

; ---- read record (REC) into DE; carry set on error (three tries)
rdrec:  ld a, 3
        ld (TRIES), a
rtry:   push de
        ld hl, (REC)
        ld a, l             ; sector = r%16 + 1
        and 0Fh
        inc a
        cpl
        out (0DAh), a
        add hl, hl          ; H:L<<4 -> logical track in H (records < 4096)
        add hl, hl
        add hl, hl
        add hl, hl
        ld a, h
        and 1
        xor 1
        out (0DDh), a       ; head
        ld a, h
        srl a               ; cylinder
        cpl
        out (0DBh), a
        ld a, 0FFh ^ 18h  ; SEEK, head load, 6 ms
        out (0D8h), a
        call wait
        ld a, 0FFh ^ 80h  ; READ SECTOR
        out (0D8h), a
        ld b, 0
rbyte:  in a, (0D8h)
        bit 1, a            ; raw bit 1 = 0: DRQ
        jr z, got
        bit 0, a            ; raw bit 0 = 1: not busy any more
        jr z, rbyte
        jr rend
got:    in a, (0DBh)        ; data needs no CPL: the disk holds it complemented
        ld (de), a
        inc de
        djnz rbyte
        call wait
rend:   pop de
        in a, (0D8h)
        cpl
        and 9Ch             ; not ready, RNF, CRC, lost data
        ret z               ; (carry is clear)
        ld a, (TRIES)
        dec a
        ld (TRIES), a
        jr z, rbad
        push de
        ld a, 0FFh ^ 08h  ; restore and try again
        out (0D8h), a
        call wait
        pop de
        jr rtry
rbad:   scf
        ret

wait:   in a, (0D8h)        ; until BUSY drops (raw bit 0 = 1)
        rrca
        jr nc, wait
        ret

sig:    db "IPLPRO"
m_boot: db "IPL IS LOOKING FOR A PROGRAM", 0Dh
m_load: db "IPL IS LOADING ", 0Dh
m_nodisk: db "NO DISK IN DRIVE 1", 0Dh
m_err:  db "DISK READ ERROR", 0Dh
m_notboot: db "NOT A BOOT DISK (NO IPLPRO)", 0Dh
m_key:  db "PRESS A KEY", 0Dh
