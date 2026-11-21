# MZ700onPC

An emulator for the **Sharp MZ-700** (European PAL model) for Windows, built for beta-testing the games in this
folder. It is the MZ-700 sibling of VZonPC: the same visualiser, the same kind of headless runner, the same build.

- **Machine:** Z80 at 3.546895 MHz, 64K RAM, bank switching (`OUT E0`–`E6`), the 1Z-013A monitor.
- **Video:** 40×25 colour text from the CG-ROM. Lines are drawn as the beam leaves the picture.
- **VRAM wait states:** the CPU is held in WAIT outside each line's blanking window. Four models are available (see below).
- **Sound:** the 8253's counter 0 into the speaker, through the PC's sound card. Pulse-width and control-word mixers come out right.
- **Character generators (optional):**
  - the **HAL PCG-700**: user-defined characters 80–FF in both character sets;
  - the **MZ-1500 colour PCG**: three planes, 1024 characters, priority and palette.
- **Joysticks:** two **MZ-1X03** analogue joysticks on `E008`. USB gamepads and their analogue sticks map to them, or a
  gamepad can stand in for the cursor keys, SPACE and RETURN in keyboard games.
- **Data recorder:** MZT/MZF tapes load instantly or at real speed through the monitor's own routine. WAV, FLAC and MP3
  audio tapes also play. `SAVE` is recorded back to an `.MZT` or a `.WAV`.
- **Testing:** `mzemu.exe`, a headless runner for scripted tests, screenshots, WAV and sound logs, profiling, VRAM wait
  checks and crash checks.

It builds with the C# compiler that comes with Windows (`build.bat`). There is nothing to install.

## Files

| | |
|---|---|
| `MZ700onPC.exe` | the emulator window |
| `mzemu.exe` | headless test runner (same emulation core) |
| `build.bat` | rebuilds both from `src\` (`build.bat headless` builds only `mzemu.exe`) |
| `roms\` | `1z013a.rom` (monitor, 4K), `mz700fon.int` (European CG-ROM), `mz700fon.jpn` (Japanese). Not in git. |
| `tools\mkmzt.py` | wraps a raw binary in an MZT header: `py tools\mkmzt.py game.bin GAME.MZT 0x1200` |
| `test\` | PCG test programs (`pcg700.asm`, `pcg1500.asm`) |
| `mz700onpc.ini` | settings, written on exit |

**Without the monitor ROM** a small built-in stand-in sets the hardware up, and `0038h` jumps to `1038h` as in the
real monitor. Machine-code programs loaded with F3 or a drop run the same way. **Without the CG-ROM** a rough built-in
font is used.

## Using it

- **F3**, or dropping an `.MZT`/`.MZF` on the window, loads a program.
  - The machine is switched on first and the real monitor boots to its `*` prompt.
  - Then the file goes into memory, the same way the monitor's `L` command leaves things: the header at `10F0h`,
    SP = `10F0h`, interrupts off. The program runs from its exec address.
  - Any further files in the same MZT stay on the tape, for programs that load more parts through the monitor.
- **F2** puts a tape in the data recorder and presses PLAY. Type `L` and RETURN at the monitor prompt to load it.
  - With **File → Fast tape loading** on, the monitor's RDINF (`04D8h`) and RDDAT (`04F8h`) finish at once.
  - With it off, the MZT is played as a real Sharp PWM signal on PC5, at real speed. The monitor reads it with its own
    code, and the motor is driven by PC3 and sensed on PC4. That is a good way to check a loader.
- **File → Record tape output** records PC1 while the program saves. Name the file `.mzt` to have the pulses decoded
  back into a tape file, or `.wav` for the audio.
- Symbols are found automatically when there is a `.sym` next to the MZT or in `..\build`, and named routines show in
  the visualiser. Both the sjasmplus format (`NAME: EQU 0x1234`) and zasm's (`1234 NAME`) work.

| Key | |
|---|---|
| F1 | help |
| F2 | insert a tape (MZT or audio) and press PLAY |
| F3 | load a program |
| F4 / Shift+F4 | power cycle / the RESET switch |
| F5 | reload the last program |
| F6 | pause |
| F7 | paste the clipboard as typing |
| F8 | mute |
| F9 | warp speed |
| F10 | visualiser (sidebars in fullscreen, its own window otherwise) |
| F11 or Alt+Enter, or double-click | fullscreen |
| F12 | screenshot, saved to `screenshots\` |

**MZ keyboard:** letters, digits, SPACE, RETURN, SHIFT, CTRL and the punctuation keys work as typed.

| PC key | MZ key |
|---|---|
| Backspace or Delete | DEL |
| Insert | INST |
| Esc | BREAK |
| Home | ALPHA |
| End | GRAPH |
| `` ` `` | `@` |
| `'` | `:` |
| Ctrl+F1 to Ctrl+F5 | F1 to F5 |

The arrow keys are the MZ cursor keys. Under **Input** they can be made joystick 1 instead, with Right Ctrl and
Right Shift as its two buttons.

## Hardware details

Where these come from: Takeda Toshiya's Common Source Code Project (eMZ-700), MAME, and the 1Z-013A ROM itself.

**Timing**
- The master clock is 17.734475 MHz. The CPU runs at that ÷5, a line is 1136 master clocks (227.2 T), and a field
  is 312 lines (70886.4 T).
- The picture takes the first 128 T of lines 0–199. /VBLK (`E002` bit 7) is low on lines 200–311.
- `E008` bit 7 is 0 during HBLANK, from T 128 to the end of the line. This is CSP's polarity; MAME has it the other way.

**VRAM wait states** (Machine → VRAM wait states)
- **Accurate (default):** an access to `D000`–`DFFF` outside T 128–208 of its line waits until T 128. This applies on
  every line, VBLANK included, as in CSP.
- **Conservative:** the free window is T 128–191, the 63 T measured on NTSC hardware. Use it to be sure a renderer will
  keep up.
- **Display lines only:** VBLANK is free.
- **Off:** no waits at all.

Monitor ROM accesses also take 1 wait state (CSP). The visualiser and `mzemu`'s `waits` command count the T-states
lost and the accesses outside the window. Those are counted even when waits are off.

**8253**
- Counter 0 runs at 1.108 MHz (master ÷16) and drives the speaker. `E008` bit 0 is its GATE.
- Counter 1 counts HSYNC, one clock per line. Counter 2 counts OUT1.
- OUT2 AND PC2 is the Z80's INT.
- All six modes are emulated. Writing a control word sets OUT at once (low for mode 0, high otherwise), so 1-bit
  mixers that toggle the speaker with mode 0/4 control words sound right.
- The speaker is integrated exactly at 44.1 kHz, so PWM duty comes out as loudness.

**8255**
- PA0–3 select the keyboard row, and PB reads it.
- PC1 is the tape write line, PC2 the interrupt mask, PC3 the motor toggle (a rising edge).
- PC4 senses the motor, PC5 is tape read, PC6 the 556 cursor blink (~1.5 Hz) and PC7 /VBLK.
- `E008` bit 0 is the 556 TEMPO signal, at ~32 Hz.

**Keyboard:** the 10×8 matrix (rows on `E000` bits 0–3, read on `E001`, active low). Row 0 has CR `:` `;` ALPHA `=`
GRAPH `_`; rows 2–4 are the letters, row 5 digits 1–8, row 6 `.` `,` 9 0 SPACE `-` `^` `\`, row 7 `/` `?` and the
cursor keys, DEL, INST; row 8 SHIFT, CTRL, BREAK; row 9 F1–F5.

**MZ-1X03 joysticks** (`E008` bits 1–4 = JA1 JA2 JB1 JB2)
- During VBLANK each axis line goes low at the start and comes back after a time set by the pot. The pulse runs from
  T 150 for 6600 T at the centre, ±3500 T at full deflection.
- While the picture is drawn, the lines carry the buttons (low = pressed): JA1 and JB1 carry button A, JA2 and JB2 button B.
- This is the same model as Ghost Hunter 2's `mzsim.py`, which its auto-calibrating reader was built against. It
  measures centre 31h, left 19h and right 4Ah here. **It is not verified on a real MZ-1X03.**

**PCG-700** (CSP)
- **Registers:** `E010` takes the data and `E011` the address low byte.
- **`E012` control:**
  - bits 0–1 are address bits 8–9;
  - bit 2 picks the character set;
  - a rising bit 4 writes the byte;
  - bit 5 copies the byte from the CG-ROM instead;
  - bit 3 **low** turns the PCG display on. It starts off.
- **Display:** codes 80–FF of both sets come from the PCG's 2K. Codes 00–7F stay on the CG-ROM. The PCG can't be read back.

**MZ-1500 PCG** (CSP)
- **Mapping:**
  - `OUT (E5),n` maps a plane at `D000`–`EFFF`: n = 1 blue, 2 red, 3 green. 0 maps the CG-ROM, read only.
  - `OUT (E6)` or `OUT (E4)` unmaps it.
- **Per cell:**
  - the PCG code is `D400+cell`, with bits 8–9 from bits 6–7 of `DC00+cell`;
  - bit 3 of `DC00+cell` turns the PCG on for that cell.
- **Display controls:**
  - `OUT (F0)`: bit 0 turns the PCG display on. Bit 1 = 1 puts the PCG over the text; 0 puts the text foreground over
    the PCG over the text background.
  - `OUT (F1)` sets the palette: colour `(d>>4)&7` → `d&7`.
- With this PCG fitted, `E5`/`E6` have their MZ-1500 meaning. Otherwise `E5` locks `D000`–`FFFF` and `E6` unlocks it.

**Power-on:** RAM comes up in stripes (`RANDRAM=seed` for random). The attributes `D800`–`DBFF` start at `71h` (white
on blue), as in CSP. The monitor never writes them.

## The visualiser (F10)

**Left column**
- **Z80 registers and flags.** Values that changed are amber.
- **Live code.** It follows a sampled busy PC and shows symbol names.
- **Hot spots.** CPU time per routine over the last second.
- **Frame budget.** Each 50 Hz field split into busy, ISR, **VRAM wait** (orange-red), tape and idle, with a 6-second
  history.
- **VRAM by line.** Writes (white) and reads (cyan) to `D000`–`DFFF` on each of the 312 lines. Accesses outside the free
  window are red. Underneath: the T-states lost to waits this field.
- **Opcodes.** A heat map of the first opcode byte, and the top instructions.
- **Stack.** SP over time and the return addresses.

**Right column**
- **Memory map.** All 64K, with reads, writes and execution glowing, and the current banking labelled (MON/RAM,
  VRAM/ATTR/I/O, or LOCK).
- **Beam and CPU.** One field as 228 T × 312 lines, showing what the CPU did at every moment: busy, ISR, VRAM wait,
  idle. On top are VRAM writes and reads, sound writes, 8253 and joystick accesses, and port OUTs. HBLANK, VBLANK and
  the free window are marked.
- **Video.** The colours in use, character set 2 cells, codes 80–FF, the PCG state, the banks and the wait mode.
- **8253 and speaker.** All three counters: mode, count, OUT and gate. Counter 0's frequency and musical note, a
  scope of the field's audio, and a 0–6 kHz spectrum with the peak note.
- **Keyboard matrix and joysticks.** The 10×8 matrix, with pressed keys lit and the rows the game scans flashing.
  Beside it, both MZ-1X03 sticks.
- **I/O, tape and character generator.**
  - `E000`–`E008` register activity, recent `OUT`s (bank switching and PCG ports, named), and the tape state.
  - A 16×16 grid of the character generator. It shows the CG-ROM, both sets alternating, or the PCG RAM when one is
    fitted, with the PCG-700's own area in amber.

## For Claude Code sessions: testing MZ-700 programs

Use `mzemu.exe` instead of writing a new Python simulator for each game. It is much faster (about 40× real time).

```
C:\Users\Owner\Documents\MZ700\MZ700onPC\mzemu.exe script.txt      run a script
mzemu.exe -e "mzt GAME.MZT; frames 300; screen s.png 2"             inline commands, separated by ;
mzemu.exe GAME.MZT [frames] [out.png]                               quick look: load, run, screenshot at 2x
```

- Paths are relative to the current directory. Numbers are decimal unless marked as hex: `$3564`, `0x3564` or `3564h`.
  Bare hex is only accepted when it can't be decimal: `D000` works, but `3564` means decimal 3564. Symbol names from
  `sym` work too.
- `tap` holds a key for 4 fields. Some games (Xevious) need it longer: `down SPACE; frames 30; up SPACE`.
- Screenshots are PNGs, 320×200 × scale. Add `border` after the scale for 384×256.
- The exit code is 2 when a crash check fired.

**Configuration** (defaults: no monitor ROM, the built-in stub, accurate VRAM waits, MZ-1X03 joysticks, no PCG)

| | |
|---|---|
| `rom auto` / `rom DIR` / `rom none` | the 1Z-013A from `MZ700onPC\roms` (the real monitor boots for 60 fields first) |
| `pcg none` / `pcg 700` / `pcg 1500` | character generator expansion |
| `vramwait accurate\|conservative\|display\|off [W0 W1]` | the wait model; W0–W1 is the free window in T |
| `joy none` / `joy mz` | joysticks fitted or not |
| `cgrom eu` / `cgrom jp` | character ROM |
| `fasttape on\|off`, `romwait on\|off` | |
| `sym FILE` | symbols, from sjasmplus (`NAME: EQU 0x...`) or zasm (`ADDR NAME`) |
| `crash` | stop and write `crash.txt` (the last 4096 PCs) when PC enters VRAM/I/O, or the stub ROM, or SP drops below 1000h |
| `stack LO HI`, `watch LO [HI]`, `quiet`, `print TEXT` | |

**Running and input**

| | |
|---|---|
| `mzt FILE` | power on, load and run an MZT/MZF (aliases `load`, `mzf`) |
| `frames N`, `seconds N` | |
| `until ADDR [maxframes]`, `untilmem ADDR VAL [max]`, `untiltext TEXT [max]` | `untiltext` uses `_` for a space |
| `down KEY`, `up KEY`, `tap KEY [frames]`, `release` | KEY = an MZ key name: A–Z, 0–9, CR, SPACE, SHIFT, CTRL, BREAK, LEFT, RIGHT, UP, DOWN, DEL, INST, ALPHA, GRAPH, F1–F5, punctuation; or J1LEFT J1RIGHT J1UP J1DOWN J1A J1B (J1FIRE = J1A), J2… |
| `joy N X Y [A] [B]` | stick N (1 or 2) at X,Y (-1 to 1), buttons 0/1, e.g. `joy 1 0.5 0 1` |
| `type TEXT` | type at the keyboard (`\r` = RETURN) |
| `rand FRAMES [seed] [KEY,KEY,...]` | random-input soak |
| `reset`, `power`, `poke A V`, `out PORT V`, `bin FILE ADDR`, `pc ADDR`, `sp ADDR` | |
| `tape FILE` | insert an MZT/WAV and press PLAY (real speed unless `fasttape` is on and the monitor ROM is loaded) |
| `tapeinsert FILE`, `tapeplay`, `tapestop`, `taperew`, `tapepos`, `tapelog` | |
| `taperec FILE` … `taperecend` | record PC1; a `.mzt` name decodes the pulses to a tape file |

**Inspection**

| | |
|---|---|
| `screen FILE [scale] [border]`, `shots PREFIX COUNT [every]` | |
| `text` | the screen as ASCII (letters, digits, a few signs; `#` for anything else) |
| `regs`, `mode`, `pit` | registers; banks, PCG, waits, fonts; the 8253 counters and the interrupt mask |
| `peek A [n]`, `peekw A`, `dis A [n]` | |
| `dump FILE` (as the CPU sees it), `dumpram FILE`, `dumpvram FILE` | |
| `wav FILE` … `wavend` | speaker audio at 44.1 kHz |
| `sndlog FILE` … `sndlogend` | every 8253/`E008` write as `T address value`, for sound tools |
| `waits`, `waitreset` | VRAM wait T-states, waited accesses, accesses outside the window and where the first was |
| `tmark ADDR` + `tstats` | fields per frame, measured by writes to ADDR |
| `prof 1` … `profsave FILE` | T-states per symbol |
| `minsp`, `ring on` / `ring FILE`, `frame` | |
| `vis on` | start tracing (put it before `mzt` so the whole run is recorded) |
| `vis FILE [panels]` | save the visualiser as a PNG: 1920×1080 with the screen in the middle, or just the panels |

**Environment:** `RANDRAM=seed` randomises RAM at power-on.

The window can check itself too: `MZ700onPC.exe GAME.MZT --quit-after 8 --shot win.png [--vis] [--pcg 700] [--vramwait conservative] [--rom none]`.
It runs the real window, captures it (and the visualiser window as `win_vis.png`), and exits without touching the
settings. Other options: `--type "L\r"`, `--tape FILE`, `--fasttape 0`, `--scale N`, `--border 0`, `--fullscreen`.

## Source

| | |
|---|---|
| `src\Z80.cs`, `src\Z80Dis.cs` | CPU and disassembler (shared with VZonPC) |
| `src\Machine.cs` | memory map, banks, 8255, `E008`, VRAM waits, video, PCGs, joysticks, sound, MZT loading, tape traps |
| `src\Pit.cs` | the 8253 |
| `src\Cmt.cs` | the tape format, signal, data recorder and recorder/decoder |
| `src\Trace.cs`, `src\Vis.cs` | the visualiser |
| `src\Headless.cs` | `mzemu` |
| `src\MainForm.cs`, `src\WinIO.cs` | the window, waveOut sound, winmm joysticks, GDI display |
| `src\Tape.cs`, `src\MfAudio.cs` | audio file decoding |

C# 5 only: no string interpolation or `?.`.

## Not emulated (yet)

- The QuickDisk, floppy and printer interfaces.
- The MZ-800's own modes.
- Hardware scrolling. The MZ-700 has none.
- Where the 320 pixels sit within the line relative to HSYNC isn't documented. Mid-line colour changes are drawn per
  line, not per pixel.
