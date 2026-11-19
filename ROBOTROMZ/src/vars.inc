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
tgtid:      db 0        ; target_human's pick
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
dlptr:      dw DLIST    ; dirty list of object-layer cells
dlfull:     db 0
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

kprev:      ds 10       ; last tick's keyboard scan
bat:        db 0        ; burst: attribute, speed, direction step, direction
bspd:       db 0
bstep:      db 0
bdir:       db 0
bcnt:       db 0
pnext:      db 0
demo:       db 0        ; 1 = the computer is playing
demotm:     dw 0
demoidx:    db 0
td:         ds 3        ; demo AI: nearest threat, target, human (dist, dx, dy)
sd:         ds 3
hd:         ds 3
dmk:        db 0        ; demo keys held between thinks
dfk:        db 0
wdx:        db 0
wdy:        db 0
form:       db 0        ; wave formation
fk:         db 0
fn:         db 0
hinew:      db 0FFh     ; rank of the newest high score (FFh none)
nameptr:    dw 0
nidx:       db 0
ndone:      db 0
ptick:      dw 0        ; ticks on this attract page
pagelen:    dw 0
gwhen:      dw 0
gk:         db 0
gshown:     ds 10
storyp:     dw 0
storyc:     dw 0
storyl:     dw 0
chase:      db 0
page:       db 0
pagetm:     dw 0
phase:      db 0
