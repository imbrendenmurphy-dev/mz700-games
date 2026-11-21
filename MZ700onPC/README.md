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
- **MZ-1500 PSG sound (optional):** two SN76489AN chips (three tones and noise each) on `OUT E9`/`F2`/`F3`, mixed
  with the speaker.
- **Floppy disks (optional):** the MZ-1E05 interface and MZ-1F02 drives: an MB8876 controller on ports `D8`–`DF`, D88
  and DSK disk images, and a built-in boot ROM at `F000` (type `F` at the monitor, or drop a disk image on the window).
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
| `roms\` | `1z013a.rom` (monitor, 4K), `mz700fon.int` (European CG-ROM), `mz700fon.jpn` (Japanese), optionally `mz1e05.rom` (the floppy interface ROM). Not in git. |
| `tools\mkmzt.py` | wraps a raw binary in an MZT header: `py tools\mkmzt.py game.bin GAME.MZT 0x1200` |
| `tools\fdipl.asm`, `tools\mkipl.ps1` | the built-in floppy boot ROM, and the script that rebuilds `src\FdIpl.cs` from it |
| `test\` | test programs: `pcg700.asm`, `pcg1500.asm`, `psgtest.asm` (PSG tones and noise), `fdctest.asm` (every FDC command) |
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
- **Disks:** drop a `.D88`, `.DSK` or `.2D` image on the window to boot it, or use the **Disk** menu.
  - **Ctrl+F2** inserts a disk in drive 1 (there is a drive 2 too). **Ctrl+F3** inserts one and boots it.
  - Booting powers on, lets the monitor reach `*`, then does what typing `F` does: it runs the interface ROM at `F000`.
    You can type `F` yourself at any time.
  - Writes go to the image file when the disk is ejected or the emulator closes. Turn **Disk → Write disk changes
    back** off to keep images untouched, or use **Save disk changes now**.
  - **Disk → Make a boot disk from an .MZT** puts a program on a new bootable disk. **New blank formatted disk** makes
    an empty 2D disk.
- **Machine → MZ-1500 PSG sound** and **Machine → MZ-1E05 floppy interface** fit or remove the two expansions.
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
| Ctrl+F2 / Ctrl+F3 | insert a disk in drive 1 / insert one and boot it |

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

**MZ-1500 PSG** (CSP eMZ-1500)
- Two SN76489AN chips: `OUT (E9)` writes both, `OUT (F2)` the left one and `OUT (F3)` the right one. The window's sound
  is mono, so both chips are mixed.
- **Clock:** 3.579545 MHz, the MZ-1500's. A tone register N gives 3579545 / (32 N) Hz, so N = 254 is 440 Hz. N = 0
  counts as 1024.
- **Registers:** `1rrrdddd` latches register rrr (0/2/4 tone, 1/3/5/7 attenuation, 6 noise) with the low 4 bits, then
  `0-dddddd` sets a tone's upper 6 bits. Attenuation is 2 dB a step, and 15 is off.
- **Noise:** bit 2 = white (or periodic), bits 0–1 = rate (clock/512, /1024, /2048, or tone 3's rate). It is the
  17-bit shift register CSP and MAME use for the "AN" part.
- Each voice is a quarter of the speaker's full level, so all eight together still don't clip.
- `psgtest.asm` measures 440.0 Hz and 658.3 Hz for N = 254 and 170.

**Floppy: MZ-1E05 interface and MZ-1F02 drives** (CSP eMZ-700)
- **Ports.** The controller is an MB8876, a WD1793 with an **inverted data bus**:
  - `D8` command (write) and status (read), `D9` track, `DA` sector, `DB` data. The CPU complements every value, so
    write `CPL`ed commands and `CPL` the status.
  - **Sector data is not complemented in software.** MZ disks hold every byte inverted, so it reaches the CPU as it was
    written.
  - `DC` is the drive register: bit 7 starts the motor (0.56 s spin-up, 1.5 s run-on), and with bit 2 set bits 0–1 pick
    the drive. `DD` bit 0 selects the head. `DF` bit 0 raises INT while DRQ is up, for interrupt-driven transfers.
- **Commands.** Restore, seek, step in/out, read and write sector (single and multi), read address, read track, write
  track (format: `F5`/`F6`/`F7` write sync marks and CRCs), and force interrupt.
  - Status bits are not ready, write protect, head loaded / record type, seek error / RNF, CRC and lost data / track 00,
    plus index, DRQ and busy.
- **Timing.**
  - 300 rpm and 32 µs a byte (MFM). A byte waiting in the data register when the next arrives sets **lost data**,
    as on the real chip, so a disk routine has to keep up with 113 T a byte.
  - Step rates 6/12/20/30 ms and 15 ms head settle. Sectors are spaced evenly round the track, so the wait for a
    sector depends on where the disk has turned to.
- **Disk images.** D88 (`.d88`/`.d77`/`.d68`), CPC DSK and Extended DSK (`.dsk`, the usual Sharp MZ format), and raw
  2D (`.2d`, 40 × 2 × 16 × 256). Images are saved back in their own format.
- **Sharp's disk layout.**
  - Record r is on logical track r/16, sector r%16+1, and logical track t is cylinder t/2, head (t&1)^1. So record 0 is
    cylinder 0, **head 1**, sector 1.
  - That record is the IPL header: `03 "IPLPRO"`, the name (to `0Dh`), then size at `14h`, load at `16h`, exec at
    `18h` and the first record at `1Eh`.
  - This was checked against real MZ disk images, the CP/M system disks MZTools ships.
- **Boot ROM.** `roms\mz1e05.rom` is used when present. Otherwise a built-in IPL of my own (`tools\fdipl.asm`, 496
  bytes) does what the real one does:
  - it starts with `00h`, so the monitor's `F` command runs it;
  - it waits for the drive and reads the IPL record;
  - it prints `IPL IS LOADING name`, loads the program and runs it.
  - It says `NOT A BOOT DISK` or `DISK READ ERROR` and waits for a key when it can't.
  - For loads below `1000h` (CP/M-style systems) it switches RAM in at `0000` first, as the MZ-800's IPL does.
  - Without a monitor ROM, booting loads the IPL record's program directly.
- **Tests.** `fdctest.asm` passes all seven checks:
  - write and read back, read address, format a track, read the formatted sector;
  - a multi-sector read stopped by force interrupt;
  - an interrupt-driven read with an `INI` handler;
  - track 00 after a seek.
- A Dracula 2 boot disk made with `diskmake` loads its 184 sectors through the real monitor and the IPL in about
  5 seconds. The MZ-800 CP/M disks load, then stop at MZ-800 hardware the MZ-700 doesn't have.

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
- **Floppy** (when the interface is fitted). The drive, image and motor; the command in progress, status, DRQ;
  track/sector registers, the head position, and sectors read and written, with lost data in red. Underneath is a
  map of 42 cylinders × 2 heads: tracks flash green when read and red when written, and the head is amber.
- **Stack.** SP over time and the return addresses.

**Right column**
- **Memory map.** All 64K, with reads, writes and execution glowing, and the current banking labelled (MON/RAM,
  VRAM/ATTR/I/O, or LOCK).
- **Beam and CPU.** One field as 228 T × 312 lines, showing what the CPU did at every moment: busy, ISR, VRAM wait,
  idle. On top are VRAM writes and reads, sound writes, 8253 and joystick accesses, and port OUTs. HBLANK, VBLANK and
  the free window are marked.
- **Video.** The colours in use, character set 2 cells, codes 80–FF, the PCG state, the banks and the wait mode.
- **8253 and speaker.** All three counters: mode, count, OUT and gate. Counter 0's frequency and musical note, a
  scope of the field's audio, and a 0–6 kHz spectrum with the peak note. With the MZ-1500 PSG fitted, two more rows
  show each chip's three tones (note and Hz) and its noise setting, with a box lit by each voice's volume.
- **Keyboard matrix and joysticks.** The 10×8 matrix, with pressed keys lit and the rows the game scans flashing.
  Beside it, both MZ-1X03 sticks.
- **I/O, tape and character generator.**
  - `E000`–`E008` register activity, recent `OUT`s and `IN`s (bank switching, PCG, PSG and floppy ports, named),
    and the tape state.
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
| `psg on\|off` | the MZ-1500 PSGs |
| `floppy on\|off` | the MZ-1E05 interface (`disk` turns it on) |
| `disk [N] FILE` | insert a D88/DSK/2D image in drive N (1–4, default 1); prints whether it has an IPL record |
| `diskeject [N]`, `diskprotect N on\|off` | |
| `diskblank FILE` | write a blank formatted 2D disk (`.dsk` = Extended DSK, `.d88` = D88) |
| `diskmake FILE GAME.MZT [NAME]` | write a bootable IPL disk holding the MZT's first block |
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
| `diskboot` | power on and boot drive 1 (monitor, then `F000`) |
| `disksave [N] [FILE]` | write drive N's image back, or to FILE (the format follows the extension). Headless runs never save on their own |

**Inspection**

| | |
|---|---|
| `screen FILE [scale] [border]`, `shots PREFIX COUNT [every]` | |
| `text` | the screen as ASCII (letters, digits, a few signs; `#` for anything else) |
| `regs`, `mode`, `pit` | registers; banks, PCG, waits, fonts; the 8253 counters and the interrupt mask |
| `psgstate` | both PSGs: each voice's frequency and attenuation, the noise mode, write counts |
| `fdc` | the controller: state, command, status, registers, drive, motor, head, sector and lost-data counts, the disks |
| `diskdump REC [n]` | logical records of drive 1 as the CPU sees them (uninverted), in hex and ASCII |
| `peek A [n]`, `peekw A`, `dis A [n]` | |
| `dump FILE` (as the CPU sees it), `dumpram FILE`, `dumpvram FILE` | |
| `wav FILE` … `wavend` | speaker audio at 44.1 kHz |
| `sndlog FILE` … `sndlogend` | every 8253/`E008` write as `T address value`, for sound tools (PSG writes appear as `100E9`, `100F2` and `100F3`) |
| `waits`, `waitreset` | VRAM wait T-states, waited accesses, accesses outside the window and where the first was |
| `tmark ADDR` + `tstats` | fields per frame, measured by writes to ADDR |
| `prof 1` … `profsave FILE` | T-states per symbol |
| `minsp`, `ring on` / `ring FILE`, `frame` | |
| `vis on` | start tracing (put it before `mzt` so the whole run is recorded) |
| `vis FILE [panels]` | save the visualiser as a PNG: 1920×1080 with the screen in the middle, or just the panels |

**Environment:** `RANDRAM=seed` randomises RAM at power-on.

The window can check itself too: `MZ700onPC.exe GAME.MZT --quit-after 8 --shot win.png [--vis] [--pcg 700] [--vramwait conservative] [--rom none]`.
It runs the real window, captures it (and the visualiser window as `win_vis.png`), and exits without touching the
settings. Other options: `--type "L\r"`, `--tape FILE`, `--fasttape 0`, `--scale N`, `--border 0`, `--fullscreen`,
`--psg 1`, `--floppy 1`, `--disk FILE` (or a disk image as the file argument: it boots), `--disk2 FILE`.

## Source

| | |
|---|---|
| `src\Z80.cs`, `src\Z80Dis.cs` | CPU and disassembler (shared with VZonPC) |
| `src\Machine.cs` | memory map, banks, 8255, `E008`, VRAM waits, video, PCGs, joysticks, sound, MZT loading, tape traps |
| `src\Pit.cs` | the 8253 |
| `src\Psg.cs` | the SN76489AN |
| `src\Fdc.cs`, `src\Disk.cs`, `src\FdIpl.cs` | the MB8876 and MZ-1E05 latches; D88/DSK/2D images and Sharp's record layout; the built-in IPL (generated) |
| `src\Cmt.cs` | the tape format, signal, data recorder and recorder/decoder |
| `src\Trace.cs`, `src\Vis.cs` | the visualiser |
| `src\Headless.cs` | `mzemu` |
| `src\MainForm.cs`, `src\WinIO.cs` | the window, waveOut sound, winmm joysticks, GDI display |
| `src\Tape.cs`, `src\MfAudio.cs` | audio file decoding |

C# 5 only: no string interpolation or `?.`.

## Not emulated (yet)

- The QuickDisk, printer and RS-232 interfaces.
- Sharp's real MZ-1E05 ROM is used only if you supply it. The built-in IPL boots IPLPRO disks, but software that calls
  routines inside the real ROM won't find them.
- Stereo: the PSGs' left and right chips are mixed to mono.
- The MZ-800's own modes.
- Hardware scrolling. The MZ-700 has none.
- Where the 320 pixels sit within the line relative to HSYNC isn't documented. Mid-line colour changes are drawn per
  line, not per pixel.
