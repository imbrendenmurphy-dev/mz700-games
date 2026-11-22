"""jrfix.py - build, and turn every out-of-range JR the assembler reports into JP."""
import re, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for it in range(10):
    r = subprocess.run([sys.executable, 'build.py'] + sys.argv[1:], cwd=ROOT, capture_output=True, text=True)
    errs = re.findall(r'(\w+\.asm)\((\d+)\): error: \[JR\] Target out of range', r.stdout + r.stderr)
    if not errs:
        print(r.stdout + r.stderr)
        break
    for fn, ln in set(errs):
        p = os.path.join(ROOT, 'src', fn)
        lines = open(p).read().split('\n')
        i = int(ln) - 1
        lines[i] = re.sub(r'\bjr\b', 'jp', lines[i])
        open(p, 'w', newline='\n').write('\n'.join(lines))
        print('fixed', fn, ln)
