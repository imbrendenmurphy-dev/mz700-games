# ZENITH (Sharp MZ-700)

An original landscape-climbing game for the 64K European MZ-700. Each island has a
Lantern on its highest ground, and its beam sweeps round in eight sectors. While
the beam lights your tile you lose energy. You can only act on tiles whose surface
you can see:

- **absorb** shards, cairns, shells and wisps for energy
- **build** cairns and set a shell on top
- **move** into the shell to climb higher

Absorb the Lantern from above to clear the island.

This is a game in the genre of 1980s landscape-climbing games. Its name, rules
detail, art, islands, music and code are all new; nothing is taken from any
existing game.

`release/ZENITH.MZT` is for emulators. `release/ZENITH.MZF` is the same file for
UniCMT and real hardware. It loads at 1200h and runs at 1200h.

## Keys

| Key | Action |
| --- | --- |
| Cursor keys | aim; pushing past an edge turns the view or tilts it up and down |
| A or SPACE | absorb |
| B | build a cairn (2 energy) |
| S | place a shell (3 energy) |
| T | move into a shell |
| U | turn about |
| Z / X | turn 45 degrees |
| M | island map |
| P | pause |
| N | music on / off |
| Q or BREAK | quit |

On the title page, LEFT and RIGHT choose the start island (up to the best island
reached).

## What is in it

- **Island generator.** A deterministic 9 x 9 noise grid becomes a 33 x 33 corner
  grid, then levels, then a plateau filter, then a 128 x 128 sub-cell height map.
  The Lantern's line of sight to every tile is surveyed once per island. Island N
  is always the same island. A generated island takes about 4.4 s, behind a
  "surveying" screen.
- **Renderer.** Each of 80 pixel columns casts a ray in 102 depth steps. The ray
  uses quarter-square multiplication and draws front to back into an 80 x 42 pixel
  buffer with depth. Objects are billboard sprites, tested against that depth.
  Each character cell shows 2 x 2 pixels through the CG-ROM's half-block and
  diagonal-block characters (7A 7B 5B 6C). A view takes 0.9-1.4 s, including VRAM
  wait states.
- **Look.** Black sky, sea striped blue and black, green plateaus with a marker on
  each tile, cyan and blue slopes. The Lantern's beam paints yellow across the
  tiles it can see.
- **Gameplay extras.**
  - Wisps from island 3 drift towards you and steal energy.
  - The beam speeds up and the Lantern's pedestal grows on later islands.
  - A warning sounds when the beam is one sector away.
  - The HUD shows a compass, a description of the cursor's target, an energy bar,
    the score and messages.
  - The island map shows the beam and every object.
  - Pause, quit with confirmation, and a music toggle.
- **Front end.**
  - Original title tune "Summit", plus a quiet in-game bass line and jingles.
  - Title page with a panorama, a how-to-play page, an object guide, and a
    high-score table with initials entry.
  - An AI demo pilot plays islands 1-4 and clears islands 1 and 3 on its own.
- **Effects.** Absorb sparkle, a dissolve when you move into a shell, a flash when
  the Lantern goes out, a red energy row when you are drained, and 12 sound
  effects.

## Building and testing

```
py build.py                     # -> build/ and release/ ZENITH.MZT / .MZF
py tools/test_gen.py 1 2 3 7    # Z80 generator == Python model, byte for byte
py tools/test_view.py 1 19 3    # render views, report timings
py tools/demo_test.py 3 3700    # AI pilot plays island 3, logs every action
py tools/run.py 800 799 --keys "10:space,16:-"
```

- `tools/model.py` is the Python reference for the generator and the renderer.
- `tools/mzsim.py` and `tools/z80.py` are the shared MZ-700 simulator.
- The CG-ROM image goes in `rom/mz700fon.int` (gitignored).

## Memory map

| Range | Contents |
| --- | --- |
| 1200-5561 | code and data (about 670 bytes free below 5800h) |
| 5800-6BFF | pixel buffer (column-major, 64 per column) |
| 6C00-7FFF | depth buffer |
| 8000-BFFF | sub-cell height map |
| C000-C3FF | tile objects |
| C400-C7FF | tile flags |
| C800-CCFF | variables |
| CD00-CFFF | stack |

## Status

This is a prototype and has not been tested on real hardware. Next candidates:

- a faster survey and render
- more variety between islands
- saving high scores to tape
