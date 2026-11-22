; =====================================================================
;  vars.asm - variables (part of the loaded image, so they start at 0)
; =====================================================================
; ---- system
polx:       db 0
duectr:     dw 0
drops:      dw 0
turbo:      db 0        ; tests: no waiting for the frame
kbuf:       ds 10
kprev:      ds 10
keys:       db 0        ; K_ bits this tick
skeys:      db 0        ; KS_ keys held
sedge:      db 0        ; KS_ keys newly pressed
joyfire:    db 0
joyon:      db 0
joys1:      db 0FFh
joycal:     db 0
joycx:      db 0
joycy:      db 0
joymv:      db 0
synced:     db 0
seed:       dw 0ACE1h
framecnt:   db 0
startpage:  db 0        ; tests: the first attract page
godmode:    db 0        ; tests: can't be hit
trainer:    db 0
skipto:     db 0        ; tests: start the stage 2 x this far in
skipw:      dw 0

; ---- screen
curlist:    dw 0
curptr:     dw 0
prevlist:   dw 0
prevend:    dw 0
bgptr:      dw 0
fullflush:  db 0
sprown:     db 0
sprcnt:     db 0
sprflash:   db 0
scntop:     db 0
rdrow:      db 0
starw:      db 30

; ---- sound (snd_init clears snd_vars .. snd_vars_end)
snd_vars:
trk_ptr:    dw 0
trk_start:  dw 0
trk_rep:    db 0
trk_cur:    db 0
trk_on:     db 0
hslot0:     ds HS_SIZE
hslot1:     ds HS_SIZE
snd_clk:    dw 0
snd_ph:     db 0
hw_par:     db 0
noise_on:   db 0
nz_seed:    db 0
cur_div:    dw 0
snd_vars_end:
soundopt:   db 0        ; 0 music + effects, 1 effects, 2 off
curtune:    dw 0

; ---- game
gstate:     db 0
gameend:    db 0
quitflag:   db 0
demo:       db 0
demoquit:   db 0
demotm:     dw 0
stage:      db 1
startstage: db 0
loop:       db 0
diff:       db 0
bspd:       db 48h
firegap:    db 90
score:      ds 3
hiscore:    ds 3
nextext:    dw 0
lives:      db 3
bombs:      db 3
power:      db 1
weapon:     db 0        ; 0 vulcan, 1 laser
options:    db 0
speed:      db 0
shield:     db 0
medal:      db 0        ; next medal's value step (0..6)
nomiss:     db 0
dist:       dw 0
evptr:      dw 0
scrollon:   db 0
scrollcnt:  db 0
scrollper:  db 4
scrolled:   db 0
overtm:     dw 0
cleartm:    db 0
bon1:       dw 0
bon2:       dw 0
bon3:       dw 0
numbuf:     ds 8
hudscore:   db 0
hudhi:      db 0
hudlives:   db 0
hudbomb:    db 0
hudpow:     db 0
hudmed:     db 0
hudstage:   db 0
hudboss:    db 0
hudsnd:     db 0

; ---- player
px:         dw 0
py:         dw 0
trailp:     db 0
firecd:     db 0
bombtm:     db 0
bombr:      db 0
bombdy:     db 0
invuln:     db 0
deadtm:     db 0
shstep:     db 0

; ---- enemies
sptype:     db 0
curid:      db 0
nfan:       db 0
ringrot:    db 0
nbdir:      db 0
spidx:      db 0

; ---- boss
bossact:    db 0        ; 0 none, 1 flying in, 2 fighting, 3 exploding
bossid:     db 0
bspr:       dw 0
bw:         db 0
bh:         db 0
bhp:        dw 0
bhpmax:     dw 0
bhp8:       dw 0
bpts:       dw 0
bscr:       dw 0
bscr0:      dw 0
bscr2:      dw 0
bmove:      db 0
bx:         dw 0
bxc:        db 0
by:         dw 0
btm:        db 0
bphase:     db 0
brep:       db 0
bflash:     db 0
bwait:      db 0
bspiral:    db 0
bdeath:     db 0

; ---- effects
captm:      db 0
cap1:       dw 0
cap2:       dw 0
capcol:     db 0
capat:      db 0
capmode:    db 0
capcol0:    db 0

; ---- front end
page:       db 0
ptick:      dw 0
pagelen:    dw 0
typed:      db 0
typep:      dw 0
typer:      db 0
typec:      db 0
lw:         db 0
logophase:  db 0
lcol:       db 0
ldiag:      db 0
lrowp:      dw 0
lshine:     db 0
twk:        db 0
rankbuf:    db 0
hinew:      db 0FFh
nidx:       db 0
nameptr:    dw 0

; ---- demo pilot
dkeys:      db 0
dmap:       ds DMW*DMH
dtx:        db 0
dbest:      dw 0
dbk:        db 0
dmk:        db 0
