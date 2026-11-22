; =====================================================================
;  stage.asm - stage backgrounds: unpack into BG, animate
;
;  stage_tab: per stage dw packed picture, dw animation script.
;  The picture is rows 3-24: 880 chars then 880 attrs (crunch packed).
;  Animation: a list of "layers"; each layer cycles through phases on
;  its own period.  A phase is a list of cell runs written into BG:
;      dw BG offset (0-999), db n, then n x (char, attr)     ... dw FFFFh
;  Layer record: db period (frames), db phase count, dw phase pointers...
;  The script: db layer count, then dw layer pointers.
; =====================================================================

STAGE_CELLS equ 880

; stage_load: A = stage number
stage_load:
        ld l,a
        add a,a
        add a,l
        add a,a                 ; *6
        ld l,a
        ld h,0
        ld de,stage_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld (st_anim),hl
        pop hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (st_blob),hl
        ex de,hl
        ld de,WORK              ; (COMP and SHOWN are rebuilt by show_all)
        call unpack
        ld hl,WORK
        ld de,BGM+ROW_MIN*40
        ld bc,STAGE_CELLS
        ldir
        ld de,BGM+800h+ROW_MIN*40
        ld bc,STAGE_CELLS
        ldir
        ld bc,(st_blob)
        ld a,b
        or c
        jr z,.noan
        ld de,ANIM_BUF
        ldir
.noan:  ; animation timers
        ld hl,st_timers
        ld b,16
.z:     ld (hl),0
        inc hl
        djnz .z
        ld hl,0FFFFh
        ld (anim_list),hl
        ld hl,anim_list
        ld (anim_ptr),hl
        jp show_all

; stage_tick: advance every layer; due ones write their next phase
stage_tick:
        ld hl,(st_anim)
        ld a,h
        or l
        ret z
        ld b,(hl)               ; layers
        inc hl
        ld ix,st_timers
.l:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl                ; HL = layer
        inc (ix+0)
        ld a,(ix+0)
        cp (hl)                 ; period
        jr c,.skip
        ld (ix+0),0
        inc hl
        ld a,(ix+1)
        inc a
        cp (hl)                 ; phases
        jr c,$+3
        xor a
        ld (ix+1),a
        inc hl
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call apply_phase
.skip:  pop hl
        inc ix
        inc ix
        pop bc
        djnz .l
        ret

; apply_phase: HL = run list
apply_phase:
.r:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        inc a
        ret z
        ld b,(hl)
        inc hl
.c:     push bc
        push de
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ex de,hl
        call anim_set
        pop hl
        pop de
        inc de
        pop bc
        djnz .c
        jr .r

; unpack: HL = crunch stream, DE = output
unpack:
.lp:    ld a,(hl)
        inc hl
        cp 0FFh
        ret z
        bit 7,a
        jr nz,.match
        ld c,a
        ld b,0
        inc bc
        ldir
        jr .lp
.match: and 7Fh
        add a,3
        ld c,a
        ld b,0
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        push de
        ex de,hl
        or a
        sbc hl,de
        pop de
        ldir
        pop hl
        inc hl
        jr .lp

st_anim: dw 0
st_blob: dw 0
st_timers: ds 16
