# SHARP EDGES — a megademo for the Sharp MZ-700

A '90s-style party demo by the (fictional) group SPRITELESS. It has 22 parts, runs for 5:03 and then loops.

| | |
|---|---|
| `release/SHARPEDG.MZT` | for emulators (MZ700onPC: `MZ700onPC.exe release\SHARPEDG.MZT`) |
| `release/SHARPEDG.MZF` | the same bytes, for a real euro-spec MZ-700 through UniCMT |
| `release/screens.png` | one frame from each part |
| `showcase/` | `BLURB.md`, a still of every part and `sharpedges.gif` (made by `py tools/showcase.py`) |

The tape file is packed: 39 KB of program plus 8 KB of high-RAM data become 31.8 KB. A stub shows `DECRUNCHING...`,
unpacks the data into the RAM under VRAM, unpacks the program in place and starts it.

## Parts (synced to the music, bar numbers in brackets)

| # | Part | Bars | What | fps |
|---|---|---|---|---|
| 1 | Intro | 0–3 | typewriter text, then a colour-block glitch | 50 |
| 2 | Title | 4–15 | the SHARP EDGES logo with diagonal-cell edges and a shine, copper bars behind it in 1-line steps (split glyphs 70h/36h/7Ah/7Eh/3Eh/3Ch), a sine scroller, and **sampled speech** shouting "Sharp edges!" | 25 |
| 3 | Plasma | 16–23 | 40×50 pixels in 8 colours, a new palette every bar | 23 |
| 4 | 3D starfield | 24–27 | 72 stars in 80×50 dots, near stars bigger and whiter, warp speed swells | 25 |
| 5 | Rotozoomer | 28–35 | a 16×16 tile rotated and zoomed, letterboxed | 16.7 |
| 6 | Fire | 36–43 | "Doom" fire under a big FIRE title | 16.5 |
| 7 | Tunnel | 44–51 | textured, rotating, flying forward | 25 |
| 8 | Vortex | 52–55 | the tunnel engine with a spiral texture | 25 |
| 9 | Kefrens bars | 56–63 | one bar per scan line for 128 lines, no raster interrupt | 50 / 12.5 |
| 10 | Twister | 64–71 | a square bar twisting and swaying, faces shaded by angle | 25 |
| 11 | Shadebobs | 72–79 | 3 round stamps adding up in a 16-colour cycle | 50 |
| 12 | Moiré | 80–87 | two sets of rings XORed into 4 colours | 17 |
| 13 | Sunset floor | 88–95 | a striped synthwave sun over a perspective checkerboard | 16.5 |
| 14 | Vector cube | 96–103 | a solid, flat-shaded rotating cube (polygon fill, back-face culling) | 19 |
| 15 | Vector dots | 104–115 | 64 morphing 3D dots: sphere, cube, torus, double helix, "MZ", star | 23 |
| 16 | Rolling barrels | 116–123 | two text cylinders turning opposite ways | 25 |
| 17 | Sine dots | 124–127 | 80 dots on Lissajous curves that change every bar | 16.5 |
| 18 | Endless bobs | 128–131 | never-erased 3×3-character balls | 50 |
| 19 | Wobbling logo | 132–135 | the logo as chunky pixels, every pixel row on its own sine | 16.5 |
| 20 | Fake crash | 136–137 | memory-dump garbage and noise, then a "Guru Meditation" box | 50 |
| 21 | Greetings | 138–149 | "JUST KIDDING!", then a chunky scroller with a rippling reflection and parallax stars | 25 |
| 22 | End | 150–157 | credits revealed under a colour wave | 25 |

Each part after the first starts on a white flash at the bar change.

## Tricks

- **Half-block mode.** Every character is 7Ah (top half filled), so ink is the top 8×4 pixel and paper is the bottom
  one: 40×50 pixels in 8 colours, changed by writing attributes only. Plasma, rotozoomer and tunnel all use it.
- **Interrupt-driven music.** 8253 counter 1 counts scan lines (78), and counter 2 counts those (2), giving an INT every
  156 lines = 100 Hz. The monitor ROM is paged out (`OUT (E0h)`) so the handler sits at 0038h. The handler switches
  to its own stack, so only its return address lands on the interrupted SP. That makes SP-based blits safe with
  interrupts on.
- **One channel, many voices.** `tools/music.py` renders the song to a 100 Hz tick stream. Lead and bass are
  interleaved tick by tick, chords are fast arpeggios, and drums are a kick (pitch sweep) plus snare and hats (noise
  bursts of random counter-0 periods). The bytes are stored as unique 12-tick rows, 16 per bar.
- **Blits.** Unrolled `pop hl / ld (nn),hl` per 40-byte row gets about 6 bytes per scan line under the VRAM waits, so
  1000 bytes take about 170 lines. Push-fills run downwards, so an interrupt can only touch cells that are written
  later. Any buffer area that gets blitted must be rebuilt every frame, because a blit leaves a return address in what
  it copied.
- **Kefrens without a raster interrupt.** Every VRAM access outside a line's free window (T 128–208) waits for the
  next one. So a loop that writes 3 bytes per pass, and takes longer than the window but less than a line, writes
  exactly once per scan line. Interrupts are off and the two music ticks are called directly.
  - The bar window uses character 7Bh (left half filled), which gives 52 colour columns 4 pixels wide.
  - A character row exists only once in VRAM, so each row's starting state is written in VBLANK with unrolled pops.
  - Counter 1 (which counts scan lines, period 78) finds line 72: 312 = 4 × 78, so it reads the same at line 200 of
    every frame.
  - Bars are simulated ahead into a second buffer set, a quarter of the rows per frame, and swapped in when done.
- **Memory: overlays and high RAM.** The program sits at 1200–AFFF. B000–CFFF is an 8 KB work area that each part
  fills when it starts: palettes, rotozoomer and tunnel textures, the perspective table, moiré rings, fire heat,
  twister spans. The 12 KB under VRAM/IO (D000–FFFF, `OUT (E1h)` / `OUT (E3h)`) holds data that is only copied down
  at a part's start, 256 bytes at a time with interrupts off. That includes the tunnel's angle/depth table, the dot
  shapes, the moiré quarter, the sky picture, the twister templates and the speech sample.
- **Sampled speech.** `tools/speech.wav` (Windows text-to-speech, saved in the repo) is resampled to 15.6 kHz and
  turned into 1 bit by sigma-delta modulation. Each bit is played by writing an 8253 control word for counter 0:
  mode 0 drives the speaker low, mode 4 high. It is 0.93 s in 1.8 KB, with the music paused while it plays.
- **Dots.** Each frame builds four 128-byte rotation tables, and a static 16×128 perspective table does the
  projection. Only the cells that changed are written to VRAM.

## Building and testing

    py build.py

This generates `build/gen_data.inc`, assembles `src/main.asm` with `tools/sjasmplus`, packs the binary with
`tools/crunch.py`, assembles `src/stub.asm`, and writes the release files. `build/MEGADEMO_RAW.MZT` is the unpacked
build, with symbols in `build/megademo.sym`.

The on-screen words (intro, scroll text, greetings, credits, shape names) are at the top of `build.py`. The song is in
`tools/music.py`.

Testing uses `..\MZ700onPC\mzemu.exe`:

    mzemu -e "sym build/megademo.sym; crash; mzt build/MEGADEMO_RAW.MZT; shots build/shots/s 48 150"
    mzemu -e "mzt release/SHARPEDG.MZT; wav build/demo.wav; seconds 140; wavend"
    mzemu -e "sym build/megademo.sym; mzt build/MEGADEMO_RAW.MZT; untilmem mus_pos 26 9000; prof 1; frames 200; profsave p.txt"

`mus_pos` is the bar being played, and `fcount` counts updates, so (Δfcount / Δframes) × 50 = fps.

## Status

- Runs cleanly in MZ700onPC (headless with crash checks, with the real 1Z-013A monitor, and in the GUI window).
- **Not yet tried on real hardware.** Things to watch for:
  - the counter-1/counter-2 interrupt at 100 Hz (the same mechanism as the monitor's clock);
  - Kefrens relies on the WAIT behaviour and on counter 1 being clocked at a fixed point in each line. If it ticks
    near the free window, the curtain could shake by one line;
  - VRAM timing, which follows the CSP eMZ-700 model;
  - how the one-channel music balances;
  - paging D000–FFFF to RAM (`OUT (E1h)`) in the loader and at part starts;
  - the speech, which depends on the speaker following counter 0's output as control words are written.
- `build/MEGADEMO_RAW.MZT` loads only the program, not the high-RAM data, so the parts that copy from high RAM
  (tunnel, vortex, dots, moiré, floor, twister, speech) look wrong with it. Test with `release/SHARPEDG.MZT`.
