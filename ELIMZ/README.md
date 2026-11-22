# ARGOSY — Sharp MZ-700

An original wireframe space-combat and trading game for the 64K Sharp MZ-700, in the open-world style of the 1980s. All of it is new: the code, the ship and station designs, the names and the layout. The music is an original arrangement of Johann Strauss II's *Blue Danube* waltz, which is in the public domain.

`release/ARGOSY.MZT` is for emulators and `release/ARGOSY.MZF` for UniCMT. Both load at 1200h. **Not yet tested on real hardware.**

## Controls
The keys follow ZX Spectrum Elite, the standard for space-trading players.

| Key | In flight |
| --- | --- |
| N / M (or cursor left / right) | roll left / right |
| S / X (or cursor up / down) | dive / climb |
| SPACE / SHIFT | faster / slower |
| A | lasers, from the front view (watch the LSR heat bar) |
| F | fire a seeker missile at the ship nearest the sights |
| E | ECM: a jammer pulse destroys every seeker in flight (costs energy) |
| C | docking computer on/off (if fitted; it plays the waltz) |
| H | hyperspace to the chosen target (needs fuel) |
| J | jump drive, held: rush ahead while nothing is near (MASS LOCKED near ships, the station, the planet or the sun) |
| 1 / 2 / 3 / 4 | front / rear / left / right view |
| I / O / P | galactic chart / local chart / data on the system (also F2 / F3 / F4) |
| F1 | help: every key |
| CTRL | freeze (the Spectrum's CAPS SHIFT); while frozen Q sound off, S sound on, CTRL or SPACE go on |

| Key | Docked |
| --- | --- |
| 1 | launch (SPACE also) |
| 2 / 3 | buy / sell cargo (the market; K also) |
| 4 | equip ship |
| F | fill the tank at this station's fuel price |
| 5 | shipyard |
| I / O / P | galactic chart / local chart / data on the system |
| S / L | save / load the pilot |

The galactic chart chooses the jump target with the cursor keys; the local chart is a zoomed map of the systems in reach, with their names and the fuel circle. Data on the system shows a picture of its planet and sun with its economy, government, tech level, star and world type.

A new game starts docked at the home station with 100 credits in a Kestrel, so you can read the system data, trade, refuel and fit equipment before launching.

### Fuel, the sun and ships
- **Fuel is a good.** Every jump burns its distance in fuel, and each station sells it by the light year at its own price and stock: cheap at industrial, high-tech stations, dear on farm worlds and in lawless space, where it is sometimes sold out. It is the last row of the market (RIGHT buys a light year; it cannot be sold), and F fills the tank as far as credits and stock allow.
- **The sun can be flown at.** It lies well beyond the planet, about half a minute flat out, and the jump drive will not take you close. Fly towards it and it swells. Inside its heat the cabin warms (the TMP meter on the console); with a **fuel scoop** fitted (equipment, 100 credits) skimming it fills the tank. Stay too long and the heat burns the shields and then the energy banks.
- **Ships.** The shipyard (5 when docked) sells four hulls; the one you fly is traded in at 60%. Better hulls need a higher rank, which comes from kills, and the hold must take your cargo.

| Hull | Price | Hold | Range | Top speed | Seeker racks | Notes | Rank |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Kestrel | 600 | 20 | 7.0 ly | 32 | 3 | the starter | Cadet |
| Swift | 1100 | 12 | 12.0 ly | 44 | 2 | courier | Pilot |
| Galleon | 1800 | 60 | 9.0 ly | 24 | 2 | armoured freighter | Gunner |
| Warhawk | 2500 | 15 | 8.0 ly | 38 | 4 | armoured gunship, fast shields | Veteran |

Armour halves laser and seeker damage. Every tank holds at least 7.0 ly, the range the galaxy was built for, so no ship can be stranded.

On the title screen, L loads a saved pilot and J switches the joystick on or off.

### Joystick (Sharp MZ-1X03)
Plug the stick into either socket, leave it centred with the buttons up, and press J on the title screen. The game finds the socket and calibrates, then shows JOYSTICK ON (or NO JOYSTICK). The stick steers like the cursor keys (forward dives), SW1 fires the lasers and works as SPACE/RETURN on the menus, and SW2 fires a seeker. The keyboard keeps working alongside it.

The MZ-1X03 is analogue: from the start of each vertical blank, each axis line on E008h gives a pulse whose length follows the stick, and while the picture is displayed the same lines carry the two buttons. `src/joy.asm` times the pulses in scan lines on 8253 counter 1, from the VBLANK start, which it tracks to the line even when the program sees it late. Sources disagree on the signal's polarity and scale, so switching on learns the resting levels and the centre, and a direction counts once the pulse is half the centre's length shorter or longer. On the music screens it reads the stick every other frame, which costs the mixer about 1 ms of sound each time. Tested only in the simulator (`py tools/test_joy.py`, which models the stick as mz800emu and the MiSTer core do). When docked, S saves and L loads (a normal tape file, so UniCMT works).

To dock, fly straight into the slot on the station's front face. The station spins; flying in down its centre line always works.

## What the prototype has
- A 3D view of 40 × 18 cells drawn in the CG-ROM's dotted quarter blocks (F0h–FFh), which gives 80 × 36 dots. It has perspective projection, near-plane clipping and Cohen-Sutherland 2D clipping. Only changed cells are written to VRAM.
- **Views:** keys 1-4 look ahead, behind, left or right. For the length of the drawing every world vector (ships, planet, sun, dust) is turned into that camera and back again, so physics, lasers, scanner and compass stay in the front view. The sights and laser beams show only ahead.
- **Hidden lines:** each model carries the planes of its convex hull, worked out by `build.py`. Once per object the camera is moved into the model's space, then three byte multiplies a face say whether it faces us. Only edges on a face towards us are drawn, so ships and the station look solid. Far ships (under about four dots across) skip the test, and from inside the station's hull every edge is drawn.
- **The planet and its sun:** every system has its own planet colour and star colour (`tools/galaxy.py`: farm worlds lean green, industrial ones yellow and red; stars are mostly yellow, some white, red or blue-white, each with one of four corona colours, so sixteen star looks in all), and the galaxy chart shows each star in its colour. The sun is a small ring with a burnt-out centre, as if the bright star had dazzled the sensor, and a corona of eight flickering rays, and it sits on one of four sides of the planet depending on the system. It is hidden behind ships and behind the planet's whole disc, night side included, so it can peek over the limb or be eclipsed. The planet is a back-lit crescent with its night side black against the stars, lit from the sun's direction. The lit part is the disc minus the same disc shifted away from the sun, which turns with the world, so the crescent stays true as you roll. Ships hide it: the planet is placed first but drawn after the ships, and while a ship over it is drawn, `plot` notes each dot row's span so the planet skips those dots. A cell a ship has drawn in keeps the ship's colour.
- The universe rotates around the player with small-angle rotations that need only shifts. Multiplication uses quarter-square tables.
- A hexagonal orbital hub that spins, a planet, star dust, Dart and Mantis pirates (the AI rolls, pitches, fires and breaks off when close), and Hauler traders.
- **Info screens** share one look: a box-drawn bezel with the title set into its top line and the key hints into its bottom line, section rules with their own titles, labels and values in aligned columns, and menu entries as key caps (white on blue).
- **The console:** a bezel across the top of the dashboard with the panel titles (SYSTEMS, SCANNER, STATUS) set into it, and dividers between the panels. Speed, shields, energy and laser heat are dot-matrix LED meters in the CG-ROM's quarter-block glyphs: two dots per cell, graded green, yellow and red, with the unlit dots in dim blue. The scanner is a blue scope whose blips take each ship's colour; anything after you (pirates, police on the hunt, seekers aimed at you) flashes white. Seekers show as missile icons, and the station compass is a small scope of its own. A hit flashes the bezel red.
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
- **Effects:** explosions start as a yellow fireball ring and then throw red and yellow sparks. Leaving and entering the station run through its tunnel in real-time 3D: hexagonal rings joined by struts rush at you and turn with the station, white near, cyan, then blue. It sounds like thrusters: an ignition crack, a hiss building to a roar, then the roar falling away. Hyperspace runs a tunnel of coloured rings.
- **Death camera:** when you are destroyed the camera leaves the cockpit. Your ship bursts into tumbling white and cyan spars inside a fireball. The camera pans round the wreck and pulls back, then turns until the ship that last fired on you (or the nearest ship) sits beyond the debris.
- **Hyperspace ambushes:** about one jump in six arrives with pirates waiting.
- **Attract mode:** after 20 s the title hands over to an AI demo pilot in a lawless system. It hunts pirates, leaves traders alone, jams incoming seekers and fires seekers at Raptors. Then come a gallery of every ship, each tumbling as large as the view allows, with notes, and a pilot's handbook page; any key returns to the title.
- **Rank** from kills: Cadet, Pilot, Gunner, Veteran, Ace, Hotshot, Legend.
- **Hyperspace:** H starts a countdown, followed by a jump effect. You arrive with the new system's station ahead of you. Lawless systems spawn more pirates; orderly ones spawn more traders.

Speed (simulator, no VRAM waits): 16.7 fps in open space, including while turning. With three pirates close ahead of the planet and the sun in view it runs at 7.5 fps (`py tools/scene_fight.py`; 9 before the hidden lines, the filled crescent and the sun), and with three ships over a close planet at 6.7 (`tools/scene_planet.py`).
## Sound
One output for the whole game: 8253 counter 0 plays a square wave by itself, so sound costs almost no CPU and every screen can animate.
- **Music is a tracker:** one channel set once per 50 Hz tick, the way MZ-700 demos play it (Genesis Project's *Sharper* was the model). `tools/music.py` arranges the waltz at build time: every note starts with a one-tick octave pluck, each bar opens with a kick falling into the bass note, the two "pahs" are quick chord blips, held notes get a slow vibrato and gaps fill with a fading arpeggio of the chord. The same waltz plays on the title, through the attract sequence, while docked and on every info screen, and with the docking computer; the game-over tune is arranged the same way.
- **Effects:** two slots step about 100 times a second on a scan-line clock, so no ticks are lost while the view is drawn. When both are busy they take turns, so a laser sounds over an explosion; while either plays, the music waits. There are effects for the laser, hits, explosions, kills, seekers, the ECM, alarms, collisions, the scoop, buying, saving, docking, launching, hyperspace and your death.

An earlier 3-voice software mixer was dropped: it only played while the program waited, so it broke up on screens that animate, and removing it freed about 2 KB.

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
`tools/test_ships.py` checks fuel buying, the shipyard and skimming the sun. `tools/test_keys.py` checks the Spectrum key layout in flight and docked. `tools/test_views.py` checks the views and the F1-F4 screens in flight and docked. `tools/test_joy.py` checks the joystick in both sockets and both polarities. `tools/test_flow.py` runs the whole game: the attract cycle, launching, docking, the market, hyperspace, death and game over.
`tools/run.py`, `mzsim.py` and `z80.py` are the shared Python MZ-700 simulator. Screenshots go to `build/shots/`. The CG-ROM image `rom/mz700fon.int` is not committed.
