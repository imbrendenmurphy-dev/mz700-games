"""test_demo.py - watches the attract cycle: title pages, then the autopilot demo.

    py tools/test_demo.py [font.rom]
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from mzsim import MZ700, FIELD_T  # noqa: E402

S = {}
for line in open(os.path.join(ROOT, 'build', 'rotoball.sym')):
    k, v = line.split()
    S[k] = int(v, 16)
m = MZ700(sys.argv[1] if len(sys.argv) > 1 else None)
m.load_mzf(os.path.join(ROOT, 'build', 'ROTOBALL.MZF'))
shots = os.path.join(ROOT, 'build', 'shots')
c = m.cpu


def rb(n): return m.mem[S[n]]


# title frame rate: count passes through the title loop's trender call
frames, t_end = 0, c.t + 120 * FIELD_T
while c.t < t_end:
    if c.pc == S['trender']:
        frames += 1
    c.step()
print('title: %d frames in 120 fields -> %.1f fps' % (frames, frames * 50 / 120))
m.screenshot(os.path.join(shots, 'm3_02_title_page.png'))

# wait for the demo
for _ in range(400):
    if rb('demo'):
        break
    m.run_fields(3)
print('demo started:', bool(rb('demo')))
m.run_fields(30)        # let the level load
last = None
for i in range(800):
    m.run_fields(3)
    if not rb('demo'):
        print('demo ended after %d frames' % i)
        break
    wp = ((m.mem[S['demo_wp']] | m.mem[S['demo_wp'] + 1] << 8) - S['DEMO_PATH']) // 2
    now = (rb('gems'), rb('state'), wp)
    if now != last:
        print('  frame %3d: gems %d state %d waypoint %d' % ((i,) + now))
        last = now
    if i in (60, 150, 300):
        m.screenshot(os.path.join(shots, 'm3_03_demo_%03d.png' % i))
