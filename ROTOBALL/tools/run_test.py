"""run_test.py - runs build/ROTOBALL.MZF in the simulator with scripted keys.

    py tools/run_test.py [font.rom]

Saves screenshots to build/shots/ and prints timing and ball state.
"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from mzsim import MZ700, FIELD_T  # noqa: E402


def syms():
    s = {}
    for line in open(os.path.join(ROOT, 'build', 'rotoball.sym')):
        k, v = line.split()
        s[k] = int(v, 16)
    return s


def main():
    font = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('MZ700_FONT')
    m = MZ700(font)
    m.load_mzf(os.path.join(ROOT, 'build', 'ROTOBALL.MZF'))
    S = syms()
    shots = os.path.join(ROOT, 'build', 'shots')
    os.makedirs(shots, exist_ok=True)

    def w16(name):
        a = S[name]
        v = m.mem[a] | (m.mem[a + 1] << 8)
        return v - 65536 if v & 0x8000 else v

    def state(tag):
        frame_entries = m.frames
        print('%-10s field %5d  angle %3d  ball (%.2f, %.2f)  v (%+.3f, %+.3f)  fields/frame %d  lines %d' % (
            tag, m.field(), m.mem[S['angle']], (w16('ballx') & 0xFFFF) / 256,
            ((w16('bally') & 0xFFFF) / 256) - 0x60, w16('vx') / 256, w16('vy') / 256,
            m.mem[S['fields']], w16('lines') & 0xFFFF))

    # count frames by watching the main loop
    m.frames = 0
    frame_pc = S['frame']
    t0 = time.time()

    def run(nfields, keys=()):
        m.held = set(keys)
        end = m.cpu.t + nfields * FIELD_T
        c = m.cpu
        while c.t < end:
            if c.pc == frame_pc:
                m.frames += 1
            c.step()
            if c.pc < 0x1200 or c.pc >= 0x6000:
                print('PC escaped to %04X at t=%d' % (c.pc, c.t))
                sys.exit(1)

    run(30)
    state('start')
    m.screenshot(os.path.join(shots, '01_start.png'))
    run(60)
    state('settled')
    m.screenshot(os.path.join(shots, '02_settled.png'))
    f0 = m.frames
    run(48, ['right'])
    state('right x48')
    m.screenshot(os.path.join(shots, '03_rotated_right.png'))
    print('  frames in 48 fields while rotating: %d -> %.1f fps' % (m.frames - f0, (m.frames - f0) * 50 / 48))
    run(60)
    state('fall')
    m.screenshot(os.path.join(shots, '04_after_fall.png'))
    run(70, ['left'])
    state('left x70')
    m.screenshot(os.path.join(shots, '05_rotated_left.png'))
    run(80)
    state('end')
    m.screenshot(os.path.join(shots, '06_end.png'))
    print('sound events: %d   sim time %.1fs' % (len(m.sound_log), time.time() - t0))


if __name__ == '__main__':
    main()
