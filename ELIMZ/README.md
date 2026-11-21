# STARHAUL (prototype) — Sharp MZ-700

An original wireframe space-combat and trading game for the 64K Sharp MZ-700, in the open-world style of the 1980s. All of it is new: the code, the ship and station designs, the names and the layout. The music is an original arrangement of Johann Strauss II's *Blue Danube* waltz, which is in the public domain.

`release/STARHAUL.MZT` is for emulators and `release/STARHAUL.MZF` for UniCMT. Both load at 1200h. **Not yet tested on real hardware.**

## Controls
| Key | Action |
| --- | --- |
| Cursor left / right | roll |
| Cursor up / down | dive / climb |
| A / Z | faster / slower |
| SPACE | lasers (watch the LSR heat bar) |
| H | hyperspace to the target chosen on the galaxy chart (needs fuel) |
| M | fire a seeker missile at the ship nearest the sights |
| J | jammer pulse: destroys every seeker in flight (costs energy) |
| D | auto-dock on/off (if fitted; it plays the waltz) |
| P | pause |
| S | sound on/off |

On the title screen, L loads a saved pilot and J switches the joystick on or off.

### Joystick (Sharp MZ-1X03)
Plug the stick into either socket, leave it centred with the buttons up, and press J on the title screen. The game finds the socket and calibrates, then shows JOYSTICK ON (or NO JOYSTICK). The stick steers like the cursor keys (forward dives), SW1 fires the lasers and works as SPACE/RETURN on the menus, and SW2 fires a seeker. The keyboard keeps working alongside it.

The MZ-1X03 is analogue: from the start of each vertical blank, each axis line on E008h gives a pulse whose length follows the stick, and while the picture is displayed the same lines carry the two buttons. `src/joy.asm` times the pulses in scan lines on 8253 counter 1, from the VBLANK start, which it tracks to the line even when the program sees it late. Sources disagree on the signal's polarity and scale, so switching on learns the resting levels and the centre, and a direction counts once the pulse is half the centre's length shorter or longer. On the music screens it reads the stick every other frame, which costs the mixer about 1 ms of sound each time. Tested only in the simulator (`py tools/test_joy.py`, which models the stick as mz800emu and the MiSTer core do). When docked, S saves and L loads (a normal tape file, so UniCMT works).

To dock, fly straight into the slot on the station's front face. The station spins; flying in down its centre line always works.

## What the prototype has
- A 3D view of 40 × 18 cells drawn in the CG-ROM's dotted quarter blocks (F0h–FFh), which gives 80 × 36 dots. It has perspective projection, near-plane clipping and Cohen-Sutherland 2D clipping. Only changed cells are written to VRAM.
- **Hidden lines:** each model carries the planes of its convex hull, worked out by `build.py`. Once per object the camera is moved into the model's space, then three byte multiplies a face say whether it faces us. Only edges on a face towards us are drawn, so ships and the station look solid. Far ships (under about four dots across) skip the test, and from inside the station's hull every edge is drawn.
- **The planet** is a back-lit crescent in cyan, with its night side black against the stars. The lit part is the disc minus the same disc shifted away from the sun, which turns with the world, so the crescent stays true as you roll. Ships hide it: the planet is placed first but drawn after the ships, and while a ship over it is drawn, `plot` notes each dot row's span so the planet skips those dots. A cell a ship has drawn in keeps the ship's colour.
- The universe rotates around the player with small-angle rotations that need only shifts. Multiplication uses quarter-square tables.
- A hexagonal orbital hub that spins, a planet, star dust, Dart and Mantis pirates (the AI rolls, pitches, fires and breaks off when close), and Hauler traders.
- **The console:** a bezel across the top of the dashboard with the panel titles (SYSTEMS, SCANNER, STATUS) set into it, and dividers between the panels. Speed, shields, energy and laser heat are dot-matrix LED meters in the CG-ROM's quarter-block glyphs: two dots per cell, graded green, yellow and red, with the unlit dots in dim blue. The scanner is a blue scope whose blips take each ship's colour, seekers show as missile icons, and the station compass is a small scope of its own. A hit flashes the bezel red.
- A title screen where each ship in turn spins in real time (64 steps a turn, 16.7 fps) over a drifting parallax starfield while the waltz plays, and a game-over screen.
- **Galaxy:** 256 star systems generated at build time by `tools/galaxy.py`. Names come from my own syllable list, and each system has an economy, a government and a tech level. The build checks that every system can be reached on a full 7.0 ly tank.
- **Docked menu:** M opens the market, C the galaxy chart and F refuels (0.2 credits per 0.1 ly). The waltz plays while docked.
- **Market:** ten goods, two of them contraband, with prices and stock set by the system's economy plus a random swing. The hold takes 20 units, and credits are 24-bit, up to 1,677,721.5.
- **Galaxy chart:** shows every star with a fuel-range circle. Moving the cursor selects the nearest system and shows its distance, whether it is in range, its economy and its government.
- **Seeker missiles:** you start with one and can carry three. They home in and pay the bounty on a kill. Mantis pirates carry one each and may fire it at you; the jammer destroys every seeker in flight.
- **Police and the law:** Warden patrols appear in orderly systems. Shooting a Warden, destroying a trader or launching with contraband (Stims, Arms) raises your legal status from CLEAN to SUSPECT to WANTED. When you are wanted, Wardens attack you and one launches after you from the station. The record halves with each jump.
- **Equipment shop** (E when docked; what's on sale depends on the system's tech level): seeker missile, jammer, twin laser (double damage), cargo pod (+15 hold), shield booster (faster recharge), cargo scoop, auto-dock.
- **Colour 3D view:** each dot cell takes the colour of whatever was drawn last: green planet, red Darts and Raptors, magenta Mantises, yellow Haulers, cyan Wardens, white station. The radar, the chart and the hyperspace rings are coloured too.
- **More objects:** the Raptor warlord pirate (9 hit points, two seekers, lawless systems only, 60 cr bounty), tumbling asteroids that break into ore, and cargo canisters dropped by destroyed ships. You scoop canisters by flying into them with a cargo scoop fitted; without one they just hit you.
- **Effects:** explosions start as a yellow fireball ring and then throw red and yellow sparks. Leaving the station runs a launch tunnel, hyperspace a tunnel of coloured rings, and your own death a white flash and rings of fire.
- **Hyperspace ambushes:** about one jump in six arrives with pirates waiting.
- **Attract mode:** after 20 s the title hands over to an AI demo pilot in a lawless system. It hunts pirates, leaves traders alone, jams incoming seekers and fires seekers at Raptors. Then come a gallery of every ship with notes, and a pilot's handbook page; any key returns to the title.
- **Rank** from kills: Cadet, Pilot, Gunner, Veteran, Ace, Hotshot, Legend.
- **Hyperspace:** H starts a countdown, followed by a jump effect. You arrive with the new system's station ahead of you. Lawless systems spawn more pirates; orderly ones spawn more traders.

Speed (simulator, no VRAM waits): 16.7 fps in open space, including while turning. With three pirates close ahead of the planet it runs at 8 fps (`py tools/scene_fight.py`; 9 before the hidden lines and the filled crescent), and with three ships over a close planet at 6.7 (`tools/scene_planet.py`).
## Sound
The MZ-700 has one tone generator (8253 counter 0) and a 1-bit speaker, so the game uses it in three ways:
- **Tracker** for the title and the whole attract sequence (demo, gallery, handbook): one square-wave channel set once per 50 Hz tick, the way MZ-700 demos play music (Genesis Project's *Sharper* was the model). `tools/music.py` arranges the waltz for it at build time: every note starts with a one-tick octave pluck, each bar opens with a kick falling into the bass note, the two "pahs" are quick chord blips, held notes get a slow vibrato and gaps fill with a fading arpeggio of the chord. It packs into 851 bytes plus a 61-entry divisor table. The counter plays the note by itself, so the tracker needs almost no CPU and the screen can animate flat out. Effects take the channel in turns with the music, so the attract demo keeps its waltz under the laser fire.
- **3-voice mixer** for the docked and menu screens, the launch tunnel, hyperspace, your death and the game-over tune. Writing an 8253 control word sets the speaker output at once (mode 0 low, mode 4 high). The mixer interleaves three pulse-width voices at about 16.4 kHz, as the VZ300 games and Dracula's Castle 2 here do. A voice's duty is its loudness, so notes pluck and fade and effects swell and die away. Voice 2 can play white noise. The waltz is arranged for melody with vibrato, an oom-pah-pah bass and a soft chord pad. The mixer only plays while the program waits for a frame, so these screens keep their per-frame work small. While the program works, the mixer times the gap on counter 1 and moves each voice's phase on by the time it missed, which keeps the pitch right.
- **Tone generator** in flight, where the 3D view needs all the CPU. Counter 0 plays by itself, and two effect slots step about 100 times a second on a scan-line clock, so no ticks are lost while the view is drawn. When both slots are busy they take turns, so a laser sounds over an explosion. The auto-dock waltz plays its melody and bass in turns the same way. There are effects for the laser, hits, explosions, kills, seeker launches, the jammer, incoming-missile and low-energy alarms, collisions and the cargo scoop.

All the music and effects are defined in `tools/music.py`. `py tools/wav.py title|launch|dock|hyper|death|fight|over [seconds]` records a scene's speaker output from the simulator to `build/sound/*.wav`.

Frames are paced by 8253 counter 1, which counts scan lines, so a frame that misses a few vertical blanks no longer idles while waiting for the next one.

## Filled polygons?
`py tools/filled_mock.py` draws one scene four ways at the MZ-700's real limits (80 x 36 dots, or one CG-ROM glyph per cell in one ink and one paper colour) into `build/shots/mock_filled.png`: the plain wireframe, the wireframe with hidden lines removed, filled and flat-shaded polygons, and hidden-line ships over a filled, back-lit crescent planet. Filled ships read as chunky blocks, and a filled, lit planet floods the screen with colour, so the game uses the fourth: hidden lines and the crescent. `tools/scene_planet.py`, `scene_fight.py`, `scene_station.py` and `scene_open.py` set up test views and measure the frame rate.

## Next steps
Testing on real hardware, especially the new sound engine. More speed (a faster line drawer, a reciprocal table for the projection).

## Build and test
```
py build.py
py tools/run.py 300 120,299 --keys "150:space,156:-"
py tools/test_flow.py
```
`tools/test_joy.py` checks the joystick in both sockets and both polarities. `tools/test_flow.py` runs the whole game: the attract cycle, launching, docking, the market, hyperspace, death and game over.
`tools/run.py`, `mzsim.py` and `z80.py` are the shared Python MZ-700 simulator. Screenshots go to `build/shots/`. The CG-ROM image `rom/mz700fon.int` is not committed.
