"""jrfix.py - assemble, and turn every out-of-range JR into a JP (repeat
until none are left).  Usage: py tools/jrfix.py"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
ASM = os.path.join(ROOT, 'tools', 'sjasmplus', 'sjasmplus.exe')

for it in range(20):
    r = subprocess.run([ASM, '--nologo', '--msg=war', 'main.asm'], cwd=SRC, capture_output=True, text=True)
    out = r.stdout + r.stderr
    hits = re.findall(r'^(\S+?)\((\d+)\): error: \[JR\] Target out of range', out, re.M)
    if not hits:
        break
    byfile = {}
    for f, ln in hits:
        byfile.setdefault(f, set()).add(int(ln))
    for f, lines in byfile.items():
        p = os.path.join(SRC, f)
        txt = open(p).read().split('\n')
        for ln in lines:
            s = txt[ln - 1]
            n = re.sub(r'\bjr\b', 'jp', s, count=1)
            assert n != s, (f, ln, s)
            txt[ln - 1] = n
            print('%s:%d  %s' % (f, ln, n.strip()))
        open(p, 'w').write('\n'.join(txt))
print(out if 'error' in out else 'ok')
