import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import celart as ca  # noqa: E402

V = [
"""
.      4E:G    189:W/K   1BF:G
165:G  146:G   147:G     .
""",
"""
.      4E:G    189:W/K   1BF:G
165:G  43:G    7B:G      .
.      146:G   .         .
""",
"""
.      4E:G    189:W/K   1BF:G
165:G  1A1:G   14B:G     .
""",
"""
.      1A5:G   189:W/K   1BF:G
165:G  43:G    43:G      .
.      147:G   147:G     .
""",
"""
.      4E:G    189:W/G   1BF:G
165:G  43:G    43:G      .
.      146:G   148:G     .
""",
"""
1BD:G  1A5:G   189:W/K   1BF:G
165:G  43:G    43:G      56:G
.      147:G   147:G     .
""",
]
pics = [ca.parse(v) for v in V]
for sky in (1, 0, 5):
    ca.sheet(pics, sky=sky, cols=6).save(os.path.join(os.path.dirname(__file__), '..', 'build', 'hero_%d.png' % sky))
