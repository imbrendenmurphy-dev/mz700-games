"""stageprev.py - every stage as MZ cells, in one sheet"""
import sys
from PIL import Image
import stage, stages_art
import mzfont as F
ims = []
for name, fn, layers in stages_art.STAGE_LIST:
    cl = [stage.cell_bytes(c) for c in stage.to_cells(fn(0))]
    chars = [0] * 120 + [c for c, a in cl]
    attrs = [0x11] * 120 + [a for c, a in cl]
    ims.append(F.render_cells(chars, attrs, scale=1))
out = Image.new('RGB', (960, 600))
for i, im in enumerate(ims):
    out.paste(im, ((i % 3) * 320, (i // 3) * 200))
out.save(sys.argv[1] if len(sys.argv) > 1 else '../build/stages.png')
