"""perf.py [none|all|display] [act] [fields] - frame rate in play, with the VRAM wait model.

Starts a game on the given act (1-9) with the pilot steering and reports
updates per second (target 25), late frames and CPU time lost to VRAM waits."""
import sys
sys.path.insert(0, 'tools')
from run import Game, S  # noqa: E402

mode = sys.argv[1] if len(sys.argv) > 1 else 'all'
act = int(sys.argv[2]) if len(sys.argv) > 2 else 1
fields = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
g = Game(None if mode == 'none' else mode)
g.run(60)
g.m.held = {'space'}
g.m.run_until_pc(S['wait_release'], max_t=70886 * 50)
g.m.held = set()
g.m.run_until_pc(S['act_setup'], max_t=70886 * 200)
g.wb('act', act - 1)
g.wb('autoplay', 1)
g.m.run_until_pc(S['play_act'], max_t=70886 * 2000)
t0 = g.rb('tickpar')
d0 = g.rb('drops')
w0 = g.m.waits
g.run(fields)
n = (g.rb('tickpar') - t0) & 0xFF
print('%s act %d: ~%d updates in %d fields, %d late frames, %.1f%% CPU in VRAM waits, score %02X%02X%02X' % (
    mode, g.rb('act') + 1, n, fields, (g.rb('drops') - d0) & 0xFF,
    100.0 * (g.m.waits - w0) / (fields * 70886), g.rb('score'), g.rb('score', 1), g.rb('score', 2)))
g.shot('perf')
