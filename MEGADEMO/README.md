# SHARP EDGES — a megademo for the Sharp MZ-700

A '90s-style party demo by the (fictional) group SPRITELESS. It runs for 2:34 and then loops.

| | |
|---|---|
| `release/SHARPEDG.MZT` | for emulators (MZ700onPC: `MZ700onPC.exe release\SHARPEDG.MZT`) |
| `release/SHARPEDG.MZF` | the same bytes, for a real euro-spec MZ-700 through UniCMT |
| `release/screens.png` | one frame from each part |

The tape file is packed (46.6 KB → 24 KB). A stub shows `DECRUNCHING...`, unpacks the demo in place and starts it.

## Parts (synced to the music, bar numbers in brackets)

1. **Intro** (0–3): typewriter text, then a colour-block glitch into the title.
2. **Title** (4–15): the SHARP EDGES logo built from full blocks and the ROM's diagonal half-cells (the "sharp edges"),
   with a white shine sweeping across it. Copper bars run behind it with 1-scan-line steps, made with the split glyphs
   70h/36h/7Ah/7Eh/3Eh/3Ch. A sine scroller runs underneath. 25 fps.
3. **Plasma** (16–23): 40×50 pixels in 8 colours, with a new palette every bar. 23–25 fps.
4. **Rotozoomer** (24–31): rotates and zooms a 16×16 tile, letterboxed. 16.7 fps.
5. **Tunnel** (32–39): a textured tunnel that rotates and flies forward. 25 fps.
6. **Kefrens bars** (40–47): one bar per scan line for 128 lines, stacking into a curtain. The display runs at 50 fps
   and the bars move at 12.5 fps.
7. **Vector dots** (48–59): 64 dots in 80×50 (the ROM's dotted quarter blocks). They morph between a sphere, cube,
   torus, double helix, "MZ" and a star. 23–25 fps.
8. **Greetings** (60–71): a big chunky scroller with a rippling reflection and parallax stars. 25 fps.
9. **End** (72–79): credits revealed line by line under a colour wave.

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
  - how the one-channel music balances.
