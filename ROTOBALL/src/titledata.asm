; ======================================================================
;  titledata.asm - title pages, scroller, high-score table (main memory)
; ======================================================================

DEMO_FRAMES = 700       ; ~42 s of attract-mode play at most

PAGETAB:
    dw page0, page1, page2

; records: row, column, attribute, display codes..., FFh; FFh ends the page
page0:
    db 13,7,60h
    dsc "A ROTATING MAZE ADVENTURE"
    db 0FFh
    db 15,6,50h
    dsc "LEFT RIGHT  SPIN THE MAZE"
    db 0FFh
    db 16,6,50h
    dsc "Z X         SPIN TOO"
    db 0FFh
    db 17,6,50h
    dsc "SPACE       SET OFF A BOMB"
    db 0FFh
    db 19,4,40h
    dsc "GET EVERY GEM TO OPEN THE EXIT"
    db 0FFh
    db 21,10,70h
    dsc "PRESS SPACE TO PLAY"
    db 0FFh
    db 0FFh

page1:
    db 13,13,60h
    dsc "WHO IS WHO"
    db 0FFh
    db 14,8,50h
    db 44h
    db 0FFh
    db 14,11,70h
    dsc "GEM           50"
    db 0FFh
    db 15,8,0D0h
    db 88h
    db 0FFh
    db 15,11,70h
    dsc "EXIT        1000"
    db 0FFh
    db 16,8,0A0h
    db 1Eh
    db 0FFh
    db 16,11,70h
    dsc "MINE       AVOID"
    db 0FFh
    db 17,8,0B0h
    db 2Ch
    db 0FFh
    db 17,11,70h
    dsc "CRAWLER  STOMP IT"
    db 0FFh
    db 18,8,0F0h
    db 9Dh
    db 0FFh
    db 18,11,70h
    dsc "BOMB      SPACE"
    db 0FFh
    db 19,8,0D0h
    db 8Fh
    db 0FFh
    db 19,11,70h
    dsc "SHIELD"
    db 0FFh
    db 21,10,70h
    dsc "PRESS SPACE TO PLAY"
    db 0FFh
    db 0FFh

page2:
    db 13,10,60h
    dsc "TODAY'S TOP BALLERS"
    db 0FFh
    db 21,10,70h
    dsc "PRESS SPACE TO PLAY"
    db 0FFh
    db 0FFh

entry_text:
    db 3,13,60h
    dsc "WELL ROLLED!"
    db 0FFh
    db 7,13,70h
    dsc "SCORE"
    db 0FFh
    db 9,10,50h
    dsc "ENTER YOUR INITIALS"
    db 0FFh
    db 18,7,40h
    dsc "LEFT RIGHT  CHOOSE"
    db 0FFh
    db 19,7,40h
    dsc "SPACE       NEXT LETTER"
    db 0FFh
    db 0FFh

scroll_text:
    dsc "      WELCOME TO ROTOBALL ...  YOU CANNOT MOVE THE BALL - SO MOVE "
    dsc "THE WORLD!  SPIN THE MAZE, LET GRAVITY DO THE REST, SCOOP UP EVERY "
    dsc "GEM, BOUNCE ON THE CRAWLERS AND KEEP CLEAR OF THE MINES ...  "
    dsc "A REAL-TIME ROTATING MAZE ON A STOCK SHARP MZ-700, NO PCG, "
    dsc "PURE CHARACTER-SET MAGIC ...  HELLO TO EVERY MZ FAN OUT THERE ...  "
    db 0FFh

LETTERS:                ; initials alphabet: A-Z, full stop, space
    db 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,2Eh,0

HISCORES:               ; 3 initials (display codes) + 3-byte BCD score, low first
    dsc "MZ7"
    db 00h,50h,00h
    dsc "ROT"
    db 00h,40h,00h
    dsc "BAL"
    db 00h,30h,00h
    dsc "SPN"
    db 00h,20h,00h
    dsc "GEM"
    db 00h,10h,00h
