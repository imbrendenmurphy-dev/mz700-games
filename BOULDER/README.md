# UNDERMINED

A cave-digging game for the **Sharp MZ-700** (64K, PAL, stock European
character ROM, no PCG), loaded from tape or a UniCMT USB cassette emulator.

Deep under the mountain lie twenty-six caves in seven wings, each wing in
its own stone and colours, with a hidden bonus chamber between each wing
and the next. Most caves are bigger than the screen: the view stays still
until you near its edge, then glides after you.

Dig through the earth, gather enough diamonds to open the exit, and get out
before the clock runs down:
- Boulders fall when you dig beneath them and roll off anything round.
- Fireflies explode at a touch, and butterflies burst into diamonds.
- The amoeba grows, the magic wall turns falling rocks into gems, and
  spouts in the ceiling rain jewels.
- Deeper down, a falling rock cracks a geode open into a gem, rocks seep
  through slime, a key opens every lock in its cave, and shades, ghosts
  that hunt you through your own tunnels, wait to be crushed.

![Title](docs/title.png) ![Cave B](docs/cave.png)
![Cave card](docs/intro.png) ![Guide](docs/guide.png)

`docs/title_music.wav` is the title music as recorded from the simulator's
sound chip.

## Running it

- **Real MZ-700 / UniCMT:** copy `release/UNDERMINED.MZF` to the USB stick and
  load it like a tape (`L` from the monitor). It loads at 1200h and starts by
  itself.
- **Emulator:** open `release/UNDERMINED.MZT` (the same file with the extension
  MZ700WIN expects).

## Controls

| Key | Action |
|---|---|
| Cursor keys or Q / A / O / P | move and dig |
| SPACE + direction | grab earth or a diamond next to you without moving |
| LEFT / RIGHT on the title | choose the starting wing (cave A, E, I, M, Q, U or X) |
| J on the title | switch the MZ-1X03 joystick on or off |
| CR | pause |
| BREAK | give up |

## Joystick

Press **J** on the title to switch on a Sharp **MZ-1X03** joystick in port 1
(the left connector); it stays on until you press J again. The stick moves
and digs, and either button grabs (button + direction) or starts a game.
The keyboard still works alongside it.

The MZ-1X03 is analog: at the start of each vertical blank, each axis line
on E008h (bit 1 = X, bit 2 = Y) goes low for a time set by the stick, and a
held button keeps its line low (SW1 on the X line, SW2 on the Y line). The
game reads it the way Sharp's own routine does, but needs only two looks
per frame: a line already high 10 scan lines into the blank is the low end
(left / up), and one still low 22 lines in is the high end (right / down),
so there is a wide dead zone around the centre. A held button takes over
its axis, so hold SW2 to grab left or right and SW1 to grab up or down. The
two looks cost a little time each frame (the busiest cave runs about 2%
slower with the joystick on), so it is off until you ask for it.

Emulators that fake the joystick as four on/off switches on E008h (MAME
does this) won't work with it; it is written for the real hardware, and
tested on a model of it in the simulator (`tools/test_joy.py`).

## The caves

Like Cryptfall, the caves are planned in wings. Each wing teaches one idea,
varies it, shows it off in a **picture cave**, and ends in a **jewel shower**: a
collect-em-up where spouts in the ceiling rain gems, with more falling
hazards in each later wing. The first two caves are already dangerous: a careless digger dies within seconds, and the second try goes better. Each cave's card names its wing and gives a
one-line hint. The caves grow through the first wing, from 48 x 24 to 64 x 32 (one screen is 40 x 22); the showers are one screen tall and scroll only sideways, so the spouts stay in sight.

| Wing | Teach | Vary | Picture | Shower |
|---|---|---|---|---|
| I The Shallows | A First Light: gems hang under rock columns; take them from the side | B Rolling Stones: gem heaps under rock, and pillars that roll into your shaft | C The Mountain | D Jewel Shower: gems only, falling through a giant gem of pegs |
| II Firefly Deeps | E Lanterns: drop a rock on a firefly to blast its vault | F Butterfly Pens: drop rocks through the roof slots | G The Moth: butterflies in its wings | H Sparkfall: gems and rocks, fireflies in the floor |
| III Magic Halls | I The Magic Wall | J Alchemy Shafts: open the shafts from the gallery | K Hourglass: snap the plug and the stone sand runs through the magic neck | L Rock Rain: a stone storm turned to gems by a magic floor |
| IV Green Caverns | M The Amoeba: gather before it spreads | N Creeping Walls | O The Tree: fruit in the crown, amoeba at the roots | P Ruby Rain: catch the rain before the amoeba |
| V The Core | Q Gauntlet: firefly tunnels | R Twin Vaults: feed the magic roofs | S Treasure Storm: under a crown of pegs | T The Core: everything you have learned |

The last two wings have three caves each, and bring in four new things:

| Wing | Teach | Vary | Finale |
|---|---|---|---|
| VI Crystal Vaults | U Geodes: geodes hang under rock columns; free the rock and it cracks one open | V Seeping Halls: rocks seep through slime floors onto the geodes and butterflies below | W The Crystal Vault: a giant locked crystal; the key waits under slime far away |
| VII The Haunted Deep | X Shades: lure each shade out of its crypt under a rock, snap the plug and run | Y Catacombs: shades walk the old passages between locked tombs | Z Heart of the Mountain: a locked heart of gems and geodes; the key lies far below, and its keepers wait in crypts |

**Hidden chambers.** Between one wing and the next lies a one-screen bonus
cave with a short clock, in gold. Dying or running out of time there costs
no life; the game just goes on to the next wing.

| | Bonus cave | |
|---|---|---|
| 1 | Crystal Rain | spouts rain only gems |
| 2 | Butterfly Garden | drop a rock into every pen |
| 3 | The Alchemist's Vat | feed rocks to a magic floor |
| 4 | The Honeycomb | gems in brick cells; mind the ones above you |
| 5 | Geode Field | a first taste of geodes |
| 6 | The Treasure Vault | one key opens every vault |

Clear cave Z and you climb out of the mountain at daybreak; then the caves
start again at the next level, with less time and faster physics.

**Every cave is proven completable.** A solving bot plays each cave on an
exact Python model of the rules. It plans paths, tries them in a copy of the
world, and keeps a move only if it survives. It also times rock drops onto
creatures: it waits beside an earth plug and snaps it away at the moment
that frees the most gems. Each winning run is stored in
`tools/solutions.py`, and each cave's clock is set from it (twice the bot's
time plus 40 s; a bonus cave gets a third over the bot's time plus 10 s). `build.py` refuses to build if any solution stops winning.
`tools/verify.py` plays every solution on the real Z80 program in the
simulator and compares the whole cave with the model after every tick.

## Playing

- The top line shows the diamonds needed, the value of each diamond, the
  diamonds you have, the time, your score, lives, and the cave and level.
- When you have enough diamonds the empty space flashes and the exit opens.
  Diamonds collected after that are worth more.
- Boulders and diamonds at rest do not hurt you. A **falling** one does.
  Push a boulder sideways by walking into it for two moves running.
- **Fireflies** (yellow boxes) kill you if they touch you. Drop a rock on one
  and it explodes. **Butterflies** (magenta) explode into nine diamonds. Both
  follow walls: a butterfly circles a room along its walls.
- The **amoeba** grows into earth and space. Box it in and it turns to
  diamonds. Let it grow too big and it turns to stone.
- The **magic wall** looks like brick until a rock falls on it. For a while
  after that, boulders that fall through come out as diamonds (and diamonds
  as boulders).
- **Spouts** (the domes in the ceiling) rain gems, and in later wings rocks
  too, until they run dry.
- Remaining time is added to your score when you leave a cave. An extra life
  every 500 points. After cave Z the caves start again at the next level,
  with less time and faster physics.

## Attract mode

The title screen has its music and the name split by the ground: UNDER
stands against a starry night sky, MINED is dug into the earth below, and
a little digger tunnels along underneath. A scroller runs along the bottom. After it come two tours, in
turn:
- **The Legend:** the mountain by night, to a slow hymn. Stars twinkle,
  lanterns flicker in the caves, a miner walks home into the mountain, and
  the story types itself out. Then the guide to what lives in the caves.
- **The Seven Wings:** each wing's stone and gems, animated, beside its
  name. Then the guide to what waits deeper: geodes, slime, keys, locks and
  shades.

Both tours end with the high-score table and a **demo**. The demo replays a
cave's recorded solution, a different cave each time across all seven wings
and the hidden chambers. The rules are deterministic, so the replay plays
out exactly as it did for the bot. Press any key to leave the demo.

Each wing's cave card plays its own jingle. Clearing cave Z brings the
ending, "Daybreak", and a new high score is entered to its own tune.

## Building

Needs Python 3 and Pillow (for screenshots); sjasmplus is in `tools/`.

```
py build.py                     generate data, check every solution, assemble, write build/ and release/
py tools/bot.py [letters]       let the solving bot play caves on the Python model
py tools/tune.py [letters]      solve caves, set their clocks, save tools/solutions.py
py tools/verify.py [letters]    play the solutions on the Z80 build, compared tick by tick
py tools/crosscheck.py 0,4 400  random play: Z80 and Python model compared every tick
py tools/test_game.py           scripted physics checks (all should pass)
py tools/test_joy.py            the MZ-1X03 joystick on the simulator's model of it
py tools/sheet.py               all caves on one contact sheet, at their true sizes (build/caves_sheet.png)
py tools/scrollshot.py C R      walk through a cave on the Z80 build and screenshot the scrolling
py tools/themeshots.py          one in-game screenshot per wing (build/wings.png)
py tools/perf.py T 500 all [joy] game speed in a cave (walking right, so it scrolls) under the VRAM wait model
py tools/wav.py 40              render the title music to build/title_music.wav
py tools/pictures.py            preview the story and ending pictures (build/pic_*.png)
py tools/showcase.py            screenshots and the animated GIF for showcase/ (about 10 minutes)
```

The simulator needs the MZ-700 character ROM as `rom/mz700fon.int` (not
included).

| Path | What |
|---|---|
| `src/main.asm` | entry, attract loop, memory map |
| `src/cave.asm` | cave unpacking, the physics scan, the spouts, the cave's random numbers |
| `src/player.asm` | controls, the player's move, scoring, demo replay |
| `src/render.asm` | cave view, reveal / cover dissolve, HUD |
| `src/game.asm` | game flow, the tick and clock, cave cards, game over |
| `src/screens.asm` | title, guide pages, high scores |
| `src/attract.asm` | the story, the seven wings, the ending: pictures, walkers, typewriter |
| `src/sound.asm` | one-voice music player and effects |
| `tools/cavelist.py` | the designs of wings I-V, and the play order |
| `tools/wings67.py` | wings VI-VII and the six bonus caves |
| `tools/pictures.py` | the story and ending pictures (`py tools/pictures.py` previews them) |
| `tools/caves.py` | element codes, tile looks, drawing brushes |
| `tools/engine.py` | the rules in Python, tick for tick like the Z80 |
| `tools/bot.py`, `tools/tune.py`, `tools/solutions.py` | the solver, the tuner, the solutions |
| `tools/music.py` | the songs (title, hymn, daybreak, name entry, a jingle per wing) and sound effects |

## How it works

- **One cell per tile, scrolling window.** A cave is up to 64 x 32 cells and lives in a 2K map with a row stride of 64. The screen shows a 40 x 22 window; it stays put until the player comes within 6 columns or 4 rows of its edge, then glides a cell per frame until the player is well inside. Tiles are character-ROM glyphs with colour.
- **Themes.** Each wing has its own earth, wall, steel, boulder, gem and amoeba looks. A theme is a whole look table that the cave loader copies into place, so the renderer never changes.
- **Physics** is a top-to-bottom scan of the whole cave (not just the window) once per tick, 8 to 12 per second; a 64 x 32 cave still runs at full speed. An object
  that moves right or down is written with a "moved" bit so the scan skips
  it. Falling and rolling, explosions, firefly/butterfly wall following,
  amoeba growth, the magic wall and the spouts all work this way.
- **Shades** step towards the player every other tick, along the longer
  distance first, but only into empty space: they follow the tunnels you
  dig. A rock that falls on one turns it into nine gems.
- **Deterministic.** Amoeba growth, slime and the spouts draw on the cave's own
  random sequence: a xorshift seeded per cave, never the Z80's R register.
  A push succeeds on the second tick of pushing. Every timer counts ticks.
  So the same keys always give the same game, which is what makes the
  recorded solutions and the demo replays possible.
- **Rendering.** A cell's low 6 bits are its element (up to 64), bit 7
  marks it as moved this tick. Each element maps through a table of four
  animation phases to a display index (so diamonds sparkle and fireflies
  spin), and only cells whose display
  index changed are written to VRAM. Under the VRAM wait model, VRAM waits
  take about 3% of the CPU, even while the window scrolls.
- **Caves** are painted in Python with brushes (boxes, ellipses, stamps, pegs, spouts, rock drops over earth plugs) on a seeded random fill, and stored Huffman-coded: a per-cave code tree plus a bit stream, about 350 bytes for a full 64 x 32 cave, under 11K for all thirty-two.
