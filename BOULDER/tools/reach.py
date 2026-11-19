"""reach.py - static reachability report for every cave."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caves  # noqa: E402

for c in caves.caves():
    gems, exit_ok, rocks, seen = c.reach()
    extra = []
    if c.count('MAGIC'):
        extra.append('magic, %d rocks in reach' % rocks)
    if c.count('AMOEBA'):
        extra.append('amoeba')
    flag = '' if exit_ok and gems >= c.need else '   <-- CHECK'
    print('%s %-17s need %2d, in reach %3d, exit %s %s%s' % (
        c.letter, c.name, c.need, gems, 'yes' if exit_ok else 'NO ', ', '.join(extra), flag))
