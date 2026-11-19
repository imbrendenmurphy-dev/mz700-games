; ---------------------------------------------------------------- variables
ballx:    dw 0
bally:    dw 0
vx:       dw 0
vy:       dw 0
newp:     dw 0
angle:    db 0
keys:     db 0
prevkeys: db 0
keyedge:  db 0
framecnt: db 0
cphase:   db 0
flash:    db 0
seed:     dw 0ACE1h
lastctr:  dw 0
lines:    dw 0
fields:   db 0

state:    db 0
timer:    db 0
level:    db 0
lives:    db 0
score:    db 0,0,0      ; BCD, low byte first
gems:     db 0
bombs:    db 0
shield:   db 0
startx:   db 0
starty:   db 0
lv_wb:    db 0
lv_h:     db 0

sndptr:   dw 0
sndpri:   db 0

msgbuf:   ds 14,0FFh
msgdirty: db 0

ballch:   db 47h
ballat:   db 70h
cdx:      dw 0
cdy:      dw 0
t_dx:     db 0
t_dy:     db 0
t_col:    db 0
sin8v:    db 0
cos8v:    db 0
ovlcount: db 0

Ux:       dw 0
Uy:       dw 0
Vx:       dw 0
Vy:       dw 0
V2x:      dw 0
V2y:      dw 0
RTx:      dw 0
RTy:      dw 0
U49x:     dw 0
U49y:     dw 0
lclass:   db 0
listang:  db 0FFh
spsave:   dw 0
outptr:   dw 0
rowcnt:   db 0
