import os
import sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import celart as ca  # noqa: E402

# candidate tiles: name -> token
T = {
    ' ': '000:W/B',
    'T': '07A:G/Y',     # grass top over dirt
    't': '1BB:G/B',
    '#': '0EF:R/Y',     # dirt
    '=': '07A:W/B',     # thin platform (top half)
    '-': '036:Y/B',     # thinner platform (top 2 rows)
    '^': '16D:W/B',     # spikes?
    '|': '1B6:G/B',     # vine
    'o': '044:C/B',     # gem
    'a': '19D:R/B',     # apple
    'S': '0E5:W/B',     # spring?
    '~': '0E4:W/B',     # water top
    'w': '0EF:B/C',     # water
    'r': '043:R/B',
    'R': '0FF:R/B',
    'g': '043:G/B',
    'G': '0FF:G/B',
    '*': '06B:Y/B',     # flower
    'f': '046:G/B',     # bush
    'q': '1BD:W/B',     # cloud parts
    'p': '13E:W/B',
    'd': '1BE:W/B',
    'B': '1B1:Y/R',     # block
    'b': '1B2:W/M',
    'x': '1B4:K/Y',
    'z': '177:Y/R',
    'y': '17F:W/R',
    '1': '0D4:G/B',
    '2': '0D5:G/B',
    '3': '1A1:G/B',
    '4': '1A5:G/B',
    '5': '1BC:G/B',
    '6': '1BB:G/B',
    '7': '175:G/B',
    '8': '0DF:G/B',
    '9': '16A:G/B',
}

ROOM = """

     qpq                     qppq
    pppppd                  pppppd

                  o o o
      o          =======        |
     ===                        |    a
                    ^^^         |  ----
  *  f   *   ff  TTTTTTTTT   *  |
TTTTTTTTTTTTTTTTT#########TTTTTTTTT   TT
##################################~~~##
##################################wwwww#
 r r r g g g R R G G  B B b b x x z z y y
 1 2 3 4 5 6 7 8 9 S  ^ ^ | |
"""

rows = [r.ljust(40)[:40] for r in ROOM.strip('\n').split('\n')]
im = Image.new('RGB', (320, len(rows) * 8))
pic = [[ca.tok(T.get(ch, '000:W/B')) for ch in r] for r in rows]
ca.draw(im, pic, 0, 0)
im = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
im.save(os.path.join(os.path.dirname(__file__), '..', 'build', 'proto_tiles.png'))
