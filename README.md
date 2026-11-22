# MZ-700 games

Original games for the **Sharp MZ-700** (64K, PAL, stock European character
ROM, no PCG), loadable from tape or a UniCMT USB cassette emulator.

| Game | Status |
|---|---|
| [Rotoball](ROTOBALL/) | Milestone 3: rotating-maze game, 8 levels, title, attract mode, music, high scores |
| [Robogeddon 2085](ROBOTROMZ/) | 1.0, tested on hardware: keyboard twin-stick arena shooter, 40 waves, power-ups, attract mode with AI demo, high scores (`release/ROBOGEDN.MZT`) |
| [Override](PARADROIMZ/) | 1.0: droid-transfer game, 3 ships / 19 decks, circuit duels, title music, attract mode with AI demo (`release/OVERRIDE.MZT`) |
| [Kiko and the Colour Thief](MASCOT/) | 1.0: mascot platformer, 4 worlds / 12 levels / 4 bosses, colour-swap mechanic, title music, attract mode with AI demo, ending (`release/KIKO.MZT`) |
| [Rockfall](BOULDER/) | 2.1: cave-digging game, 20 scrolling caves up to 64x32 in 5 wings, each with its own stone and colours, picture caves and jewel showers, every cave solved and verified on the Z80 build, title music, attract mode replaying the solutions (`release/ROCKFALL.MZT`) |
| [Skink and the Sun Mosaic](REPTON/) | 1.0: Repton 2-style adventure, 14 linked caverns that remember everything, scrolling 2x2-character tiles, eggs, beasts, spirits, mould, switches, tape saves, verified solution (`release/SKINK.MZT`) |
| [Circus 2](CIRCUS2/) | 1.0: conversion of the VZ300 seesaw-and-balloons game, 9 acts + encore, 2 bonus rounds, 7 power-ups, monkey and ring of fire, circus march, attract mode with AI demo, high-score entry (`release/CIRCUS2.MZT`) |
| [Nova Storm](VSHMUP/) | 0.9: vertically scrolling space shoot-'em-up, 5 stages with scrolling scenery and a boss each, 7 power-ups, medals and formation bonuses, tracker music, attract mode with AI demo, high-score entry, joystick (`release/NOVASTRM.MZT`) |

Each game folder has its source, a Python build script (no extra packages
needed) and a ready-to-load `.MZF` in `release/`.
