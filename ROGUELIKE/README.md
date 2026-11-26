# LUMEN — a roguelike of light and shadow

An original roguelike dungeon crawler for the Sharp MZ-700 (64K, PAL, European CG-ROM, no PCG).
Carry the last lantern into the deep, find the three sigils, open the sealed library door, turn the
sun's beam in the crystal sanctum and defeat the Lightless King.

`release/LUMEN.MZT` (emulators) and `release/LUMEN.MZF` (the same file, for UniCMT on a real machine).
Loads at 1200h. **Not yet tried on real hardware.**

## The game

- **Light is the core mechanic.** Every cell's light is computed each frame: ray-cast line of sight
  from the player, a flickering lantern that falls off with distance, static lights with their own
  shadows (braziers, wall sconces, lava, glowing fungus, crystals, runes, the sun beam), and moving
  lights (spells in flight, flares, glowing creatures, blast flashes). Lights are coloured — warm
  torchlight, cold crystal light, toxic fungus, arcane runes, sunlight — and tiles take the colour of
  the light that falls on them, through 8 colour ramps. Light falls off slowly (a light of strength S
  reaches 2S cells), so the lantern and braziers throw long fans of light down corridors and across
  rooms, broken by the shadows of columns and statues. Shades can only be seen
  in bright light. Walls and objects you have seen stay on the map in dim blue; unlit floor is dark,
  so shadows read as shadows.
- **The lantern burns oil.** Without it your light shrinks to a few cells; shades and the king drink
  it. Oil flasks are found, bought, and kept in chests.
- **Eight interconnected zones**, generated fresh every game, each with its own wall and floor look,
  light sources, creatures and treasure: the Hollow Crypt, Fungal Grotto, Drowned Halls, Ember Forge,
  Frost Vault, Shadow Library, Crystal Sanctum and the Hollow Throne. Zones link both ways (not a
  linear descent) and stay as you left them.
- **Great halls, bigger than the light**: each zone has up to two halls made by joining parts of the
  map - a great hall of up to 38 x 18 (the whole view), or wide and tall halls - set out as colonnades,
  pillar forests and rings of giant columns, so the lantern's light falls across them in rays. Other
  rooms nearly fill their part of the zone. Rooms are set out with round 2 x 2 columns (four triangle glyphs), 3 x 3 octagonal
  columns, galleries of statues on plinths, and great chalice braziers, all of which block and cast light.
- **The sun-stone**, a relic resting on a stand somewhere in the Crypt. Bump the stand to lift it: while
  you carry it, a wide golden light replaces the lantern and no oil burns. Set it on any empty stand
  (some rooms have one) and it lights that room with steady sunlight. **Dark-glass doors** open only while
  steady light falls on them, so to pass the sun gates in the Fungal Grotto and the Frost Vault you
  must leave the stone on the stand outside and go on by lantern, then fetch it back. The vaults hold the
  shadow cloak and the sun blade.
- **Puzzle vaults** (hand-made rooms placed into the generated zones): boulders onto pressure plates,
  braziers across lava that only a firebolt can reach, an ice hall where you slide until something
  stops you, lever gates that all swap at once, a sigil seal, and mirrors that steer a beam of
  sunlight onto a target, and the sun gates. Freezing a lake with FROST makes a path to the drowned island.
- **31 creatures** with different behaviours: chasers, erratic flyers, ranged casters (imps, liches,
  floating eyes), wall-passing wraiths, eels that stay in water, mimics and gargoyles that wait in
  disguise, wisps that flee and light the way, spore creatures that burst, poisoners, oil-drinkers,
  armoured golems, and the Lightless King.
- **Six spells**: FIREBOLT (lights braziers, burns webs), FROST (freezes creatures, water and lava),
  FLARE (a hovering light for 40 turns that burns shades), HEAL, BLINK and LIGHTNING.
- **Seven folk**: the Hermit, Sage, Ghost and Oracle teach spells and give hints, the Trader and the
  Smith keep shops, the Seer heals.
- **Weapons** (dagger to the sun blade; the flame brand and frost blade glow), **armour**, potions,
  bombs, teleport and mapping scrolls, keys, gold. Experience levels.
- **Particles**: embers, sparks, frost, spores, blood, healing light, magic swirls, dripping water,
  lava bubbles, beam glints — up to 28 at once.
- Front end: a title logo built from CG-ROM shape glyphs (white-hot letters in a twinkling dithered
  aura, a shine sweeping across; `tools/logo.py`, other styles in `tools/logo_mocks.py`), embers rising, tracker title music,
  story page, bestiary, high-score table with name entry, an **AI-driven attract demo** (it explores,
  fights, drinks, casts firebolts and heads for new zones), death and victory screens.

## Controls

| | |
|---|---|
| Cursor keys / Q A O P | move, attack, push, open, talk (bump) |
| 1 – 6 | choose a spell (if known) |
| SPACE | cast the chosen spell (then a direction) |
| H / M | drink a healing / mana potion |
| B | throw a bomb (then a direction) |
| T / R | read a teleport / mapping scroll |
| W or . | wait a turn |
| CR | pause |
| BREAK | abandon the game |

Keys pressed during an animation are kept and acted on afterwards.

## Building and testing

```
py build.py                       generates build/gen_*.inc, assembles, writes build/ and release/ LUMEN.MZT/MZF
py tools/test_puzzles.py [seed]   solves every puzzle vault on the Z80 build in mzemu
py tools/mapdump.py test/ram.bin  prints the current zone from an mzemu RAM dump
py tools/prefabs.py               the vault designs and their Python solvers
py tools/mock.py                  previews the lighting model in Python
```

Testing uses the shared emulator `..\MZ700onPC\mzemu.exe`; `tools/harness.py` drives it (fixed dungeon
seed via `dbg_seed`, zone warps via `dbg_warp`, the `in_input` flag to wait for the game to be idle).

## Source

| | |
|---|---|
| `tools/defs.py` | tiles, light hues and colour ramps, zone themes, particle kinds |
| `tools/content.py` | creatures, items, weapons, armour, spells, the eight zones |
| `tools/prefabs.py` | the hand-made vaults (with solvers that prove them solvable) |
| `tools/music.py` | the tracker tunes and sound effects |
| `src/main.asm` | memory map, start, the attract loop |
| `src/fov.asm` | ray-cast field of view, static lights, dynamic light stamps |
| `src/render.asm`, `ovl.asm` | light pass, overlays, the compositor with dirty spans |
| `src/gen.asm`, `zone.asm` | zone generation, zone switching and storage |
| `src/game.asm`, `monsters.asm`, `magic.asm`, `items.asm`, `puzzle.asm`, `npc.asm` | the game |
| `src/hud.asm`, `msg.asm` | status rows, message queue, overlay text and boxes |
| `src/particles.asm`, `sound.asm`, `bot.asm`, `screens.asm` | effects, sound, demo pilot, front end |

### Memory

| | |
|---|---|
| 0000–0FFF | the current zone (64 × 32) and its static light map (the monitor ROM is paged out) |
| 1000–11FF | stack |
| 1200–7FFF | program and data |
| 8000–97FF | view buffers (light, overlays, the screen's shadow copy), BFS queue |
| 9800–A7FF | what the player sees (per map cell), distance map |
| A800–AFFF | the zone's creatures and items, variables, tile looks |
| B000–BFFF | zones 0–1 while away; C000–C8FF every zone's creatures and items |
| C900–CFFF | prefab data (loaded after the program, moved here at start) |
| D000–FFFF | zones 2–7 while away, in the RAM behind VRAM (paged in with OUT E1h for the copy) |

The renderer runs at 25 frames a second: a full relight and recompose happens only when a turn changes
the view; otherwise only the lantern's flicker zone (when its strength changes), moving lights,
overlays and one rolling row are redrawn, and only changed cells are written to VRAM.
