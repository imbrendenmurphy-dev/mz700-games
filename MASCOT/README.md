# KIKO AND THE COLOUR THIEF

An original mascot platformer for the **Sharp MZ-700** (64K, PAL, stock
European character ROM, no PCG). ViBED by BPM.

The Grey Baron has stolen the Prisms of Light. Kiko is a little chameleon who
can be any colour he likes. Over four worlds he wins back the colours, then
takes on the Baron in his grey castle.

![Title](docs/title.png) ![Baron](docs/baron.png) ![Ending](docs/ending.png)

`docs/title_music.wav` is the title theme, recorded from the simulator's model
of the 8253 sound chip.

## Running it

- **Real MZ-700 / UniCMT:** load `release/KIKO.MZF` like a tape. It loads at
  1200h and starts by itself.
- **Emulator:** open `release/KIKO.MZT` (the same file).

## Controls

| Key | Action |
|---|---|
| Cursor keys or O / P | run |
| SPACE / Z | jump (hold to jump higher) |
| X / M | tongue: eat enemies, grab gems |
| C / N | change colour (from World 2) |
| UP / DOWN | climb vines |
| DOWN | duck: the tongue then skims the ground (on a plank: drop through) |
| CR | pause |
| BREAK | quit to the title |

### Joystick (optional)

A Sharp **MZ-1X03** joystick in port 1 can be used. Press **J** on the title
pages to open the joystick page, then press **J** again to turn the joystick
on (SPACE goes back). The setting lasts until you reset the machine. The keys
keep working alongside it.

| Joystick | Action |
|---|---|
| stick | run, climb, duck |
| fire 1 | jump (also starts the game from the title) |
| fire 2 | tongue |
| UP + fire 2 | change colour |

The joystick page also has a live test:
- The words LEFT / RIGHT / UP / DOWN / F1 / F2 light up for what the game sees.
- The raw readings are shown: the length of each stick pulse in scan lines,
  and the button lines during the picture.

If the stick doesn't behave, a photo of that page shows what the hardware is
doing.

## The game

- **4 worlds, 12 levels, 40 flip-screen rooms:** Sunny Meadows, Ember
  Caverns, Clockwork Clouds and the Grey Castle. Each world ends with a boss:
  Big Bumble, Magma Mole, Prism Phantom and Baron Greyscale.
- **The colour mechanic:** chroma blocks are solid only while Kiko wears their
  colour, and appear as dotted ghosts otherwise. You can switch in mid-air to
  land on a block or to slip through a wall. Inkblot enemies can't see Kiko
  while he wears their colour. The last two bosses can only be hurt in a
  matching colour. Kiko owns green in World 1, gains red in World 2 and blue
  from World 3 on.
- Other features:
  - Stomping and tongue attacks.
  - 3 hearts per life, extra lives from smileys and from every 100 gems.
  - Apples restore a heart.
  - A hidden star in 8 of the levels.
  - Springs, vines, one-way planks, crumbling bridges, moving platforms, lifts
    and lava/goo pits.
  - Level-clear tally with an all-gems bonus.
- **Physics:** acceleration and skidding, variable jump height, coyote time
  (6 frames) and a jump buffer (7 frames), with 1/256-cell fixed-point motion
  at 50 Hz.
- **Front end:**
  - Rainbow-cycling title screen with a scroller and title music.
  - Story, how-to-play and high-score pages.
  - An AI-driven attract demo that plays level 1-1.
  - Prism screens between worlds, game over, ending with colour flood.
  - High-score name entry.

## Building

Needs Python 3 and Pillow. sjasmplus is in `tools/`. The simulator needs the
MZ-700 character ROM as `rom/mz700fon.int`.

```
py build.py                 generate data, assemble, write build/ and release/
py build.py preview         also draw every room and level map to build/rooms/
py tools/reach.py           solver: every level finishable, every pickup reachable
py tools/test_boss.py       beat all four bosses in the simulator
py tools/test_flow.py       final boss -> tally -> ending -> high-score entry
py tools/test_joy.py        joystick page and play with the simulated MZ-1X03
py tools/perf.py 0 1500     frame drops under the conservative VRAM wait model
py tools/run.py N shots --keys "f:key+key,..."   scripted run with screenshots
py tools/wav.py 40 out.wav  record the title music
```

| Path | What |
|---|---|
| `src/render.asm` | overlay compositing and dirty-cell flush |
| `src/room.asm` | room decoding, pickups, chroma blocks, animated tiles, crumble/spring timers |
| `src/hero.asm` | Kiko: physics, vines, tongue, colour swap, damage |
| `src/objects.asm` | enemies, platforms, shots, goal |
| `src/boss.asm` | the four bosses |
| `src/pilot.asm` | the demo AI |
| `src/game.asm` | level flow, HUD, pause |
| `src/screens.asm` | front end |
| `src/joy.asm` | MZ-1X03 joystick reading and the joystick page |
| `src/sound.asm` | one-voice tracker (from OVERRIDE) |
| `tools/levels.py` | all level maps (ASCII) |
| `tools/tiles.py`, `sprites.py`, `screens.py`, `music.py` | tiles, sprite cell art, pictures, songs |

## How it works

- **Graphics** are made only from the CG-ROM's 512 glyphs, each with its own
  foreground and background colour. Sprites are composed by hand from glyphs
  and are recoloured through 256-byte attribute tables. That is how Kiko
  changes colour, and how hits flash white.
  - I tried an automatic "best glyph" converter for smooth sub-cell sprites.
    It produced mush, so sprites move in whole cells (8 px). The fixed-point
    physics and per-step run animation keep motion smooth in time.
- **Rendering:** each cell's overlay, shadow, attribute and VRAM addresses
  differ only in the high byte. Every frame, the cells sprites covered last
  frame are restored from the tile map and the sprites are drawn into the
  overlay. At VBLANK only the cells that differ from the shadow are written
  to VRAM. No flicker and no full redraws: under the conservative VRAM wait
  model (every access held to the 63-T line window), levels 1-1, 2-2 and the
  final boss each dropped only 1 frame (the room load) in 600–1500 frames.
- **Rooms** are tile-id maps (RLE). Python does the auto-tiling and stamps
  (clouds, trees). Each room averages ~180 bytes; the whole game binary is
  about 33 KB.

## Testing status

- The game has been played on a real MZ-700 (the title pages and World 1).
  Everything else was tested only in the Python Z80/MZ-700 simulator
  (`tools/mzsim.py`).
- What was tested in the simulator:
  - The attract loop and the demo pilot finishing 1-1.
  - All four bosses beaten (test harness).
  - Ending, high-score entry, room transitions and frame timing.
- `tools/reach.py` passes all 12 levels. It uses its own copy of the physics,
  ignores enemies, and treats moving platforms optimistically.
- What still needs doing:
  - Real hardware / emulator check, especially the real VBLANK polarity (it
    is measured at boot) and how the sound sounds.
  - Hand play-testing of difficulty, particularly the colour-switch jumps in
    Worlds 2–4 and the inkblots.
  - Further art polish (W3 ground texture, small-enemy sprites) is possible.
- **Joystick: not yet tried on a real MZ-1X03.**
  - No hardware documentation for the stick was available. The reading
    follows the two emulators that model it, the MiSTer SharpMZ core and
    MZRaku. Both put the stick and buttons on E008h bits 1-4.
  - Timing as modelled:
    - At the start of vertical blank each axis line goes low for a time set
      by the stick: about 0 lines held left/up, 16-19 centred, 32-37 held
      right/down.
    - While the picture is shown, the same lines carry the fire buttons.
  - The game samples each axis twice in the blanking (lines 4-10 and 21-26)
    and the buttons during the picture.
  - Safety: nothing counts until a line has given a normal reading, so an
    empty port or a stuck line does nothing.
  - `tools/test_joy.py` passes with both emulators' timings, and with an
    empty port and with stuck lines. The joystick costs no extra dropped
    frames in `perf.py`.
  - If the real stick differs (for example the pulses come at the other end
    of the blanking), the numbers on the joystick page will show it.
