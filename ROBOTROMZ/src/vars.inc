; =====================================================================
;  vars.inc - variables (part of the loaded image, so they start at 0)
; =====================================================================
polx:       db 0
drops:      dw 0
slack:      dw 0
seed:       dw 0ACE1h
framecnt:   db 0

curlist:    dw 0        ; draw list being built this tick
curptr:     dw 0
prevlist:   dw 0        ; last tick's list
prevcnt:    db 0
bgcnt:      db 0
fcount:     db 0
objtop:     db 0        ; object slots in use are below this
humcnt:     db 0
curid:      db 0
humlist:    ds 16*4     ; humans to place after the robots: IX, id, -

kbuf:       ds 10
mkeys:      db 0
fkeys:      db 0
skeys:      db 0
sedge:      db 0

sndptr:     dw 0
sndleft:    db 0
sndmode:    db 0
snddiv:     dw 0
sndpri:     db 0
sndon:      db 1

state:      db 0
statetm:    db 0
ai_on:      db 0
wave:       db 1
waverow:    dw 0
lives:      db 3
score:      ds 3        ; BCD, low byte first
hiscore:    ds 3
extacc:     dw 0        ; points / 25 toward the next extra life
hudflag:    db 0
alive:      db 0
curflags:   db 0
rescues:    db 0
saved:      db 0
lost:       db 0
ease:       ds 8
droid_delay: db 0
droid_tmr:  dw 0

px:         dw 0        ; player position (8.8 cells)
py:         dw 0
pyflip:     db 0
firecd:     db 0

page:       db 0
pagetm:     dw 0
phase:      db 0
