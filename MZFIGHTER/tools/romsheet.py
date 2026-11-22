import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import mzfont as F
from PIL import Image, ImageDraw
im = Image.new('RGB', (32*20+40, 16*20+20), (60,60,60))
d = ImageDraw.Draw(im)
for g in range(512):
    b = F.glyph_bits(g)
    cx = (g % 32) * 20 + 30; cy = (g // 32) * 20 + 10
    for y in range(8):
        for x in range(8):
            c = (255,255,255) if b[y][x] else (0,0,0)
            d.rectangle([cx+x*2, cy+y*2, cx+x*2+1, cy+y*2+1], fill=c)
for r in range(16):
    d.text((2, r*20+12), '%03X' % (r*32), fill=(255,255,0))
im = im.resize((im.width*2, im.height*2), Image.NEAREST)
im.save(sys.argv[1] if len(sys.argv) > 1 else 'romsheet.png')
