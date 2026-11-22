"""run.py - run an mzemu script with symbol addresses filled in.

    py tools/run.py SCRIPT     (in the script, {name} or {name+1} becomes $hex)
"""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
EMU = os.path.join(ROOT, '..', 'MZ700onPC', 'mzemu.exe')
sym = {m.group(1): int(m.group(2), 16) for m in
       re.finditer(r'^(\w+): EQU 0x([0-9A-F]+)', open(os.path.join(ROOT, 'build', 'novastrm.sym')).read(), re.M)}


def sub(m):
    name, off = m.group(1), int(m.group(2) or 0)
    return '$%04X' % (sym[name] + off)


src = open(sys.argv[1]).read()
out = re.sub(r'\{(\w+)(?:\+(\d+))?\}', sub, src)
tmp = os.path.join(ROOT, 'build', '_run.txt')
open(tmp, 'w').write(out)
r = subprocess.run([EMU, tmp], cwd=ROOT, capture_output=True, text=True)
print('\n'.join(l for l in (r.stdout + r.stderr).split('\n') if not l.startswith('loaded')))
sys.exit(r.returncode)
