// MZ700onPC - Sharp MZ-700 (PAL) emulator: machine core.
// Memory map and bank switching (OUT E0-E6), 8255 (keyboard, /VBLK, cassette, cursor 556), 8253 (sound, HSYNC
// counter, interrupt counter), E008 (TEMPO, joystick, HBLANK, sound gate), VRAM wait states, 40x25 colour text video
// with the CG-ROM, the PCG-700 and MZ-1500 PCG options, MZ-1X03 joysticks, the data recorder, MZT loading.
// Timing facts are from Takeda's Common Source Code Project (eMZ-700), MAME and the 1Z-013A ROM itself.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public enum PcgType { None, Pcg700, Mz1500 }
public enum VramWaitMode { Off, Display, All }
public enum JoyType { None, Mz1x03 }

public sealed class MzMachine
{
    // ---------------------------------------------------------------- timing (master clock 17.734475 MHz)
    public const int MCLK = 17734475, CLOCK = MCLK / 5;          // Z80 at 3,546,895 Hz
    public const int LINE_M = 1136, LINES = 312, FRAME_M = LINE_M * LINES;   // 227.2 T per line, 70886.4 T per field
    public const int FT = (FRAME_M + 4) / 5, LT = 228;           // T-state slots per field / per line (for the visualiser)
    public const int VIS = 200;                                   // picture lines (0-199); /VBLK low on 200-311
    public const int DISP_M = 640;                                // picture: the first 128 T of each line (320 pixels)
    public int Clock { get { return CLOCK; } }

    // ---------------------------------------------------------------- configuration
    public PcgType Pcg = PcgType.None;
    public VramWaitMode VramWait = VramWaitMode.All;
    public int WaitW0 = 128, WaitW1 = 208;                        // VRAM is free from T WaitW0 to WaitW1 of each line (CSP)
    public JoyType Joystick = JoyType.Mz1x03;
    public bool UseRom = true;                                    // false = always the built-in stub monitor
    public bool Japanese;                                         // Japanese CG-ROM (mz700fon.jpn)
    public bool FastTape = true;                                  // trap the monitor's tape reads (RDINF/RDDAT) and load at once
    public bool RomWait = true;                                   // 1 wait state on monitor ROM accesses (CSP)

    // ---------------------------------------------------------------- state
    public readonly Z80 Cpu = new Z80();
    public byte[] Rom = new byte[0x1000];
    public string RomName = "";
    public byte[] Ram = new byte[0x10000];
    public byte[] Vram = new byte[0x1000];                        // D000-D7FF characters, D800-DFFF attributes
    public byte[] Font = new byte[0x1000];                        // CG-ROM, flipped so the leftmost pixel is bit 7
    public bool HasFont;
    public string FontName = "";
    public bool RomIn = true, IoIn = true, Inhibit;               // 0000-0FFF monitor, D000-FFFF VRAM+I/O, E5 lock
    bool ioBeforeInhibit;
    public readonly PitCounter[] Pit = { new PitCounter(), new PitCounter(), new PitCounter() };
    public int PortA, PortC = 0x0F;                               // 8255 outputs (PC0-PC3)
    public int[] Keys = new int[10];                              // matrix rows, active low
    public bool SoundGate;                                        // E008 bit 0 = GATE0
    public long FrameStartM, Frames;
    public int CurPc;
    public long WaitT, WaitTFrame, WaitAccesses, RomWaits;        // VRAM wait states (T) total / this frame
    public long ContendedAccesses;                                // VRAM accesses outside the free window (counted even with waits off)
    public long ContendedFrame;
    public int ContendedFirstPc = -1; public long ContendedFirstFrame;
    public long Interrupts;
    public readonly MzCassette Cass = new MzCassette();
    public readonly MzTapeRecorder TapeOut = new MzTapeRecorder();
    public List<string> TapeLog = new List<string>();
    public bool HasRom { get { return RomName != ""; } }

    // joysticks (MZ-1X03): axes -1..+1, two buttons each
    public readonly double[] JoyX = new double[2], JoyY = new double[2];
    public readonly bool[] JoyA = new bool[2], JoyB = new bool[2];
    public int JoyPulseStart = 150, JoyPulseCentre = 6600, JoyPulseRange = 3500;   // T from the start of VBLANK

    // PCG-700: 2K of RAM for codes 80-FF of both character sets
    public byte[] Pcg700 = new byte[0x1000];
    public int PcgData, PcgAddr, PcgCtrl = 0xFF;
    public long PcgWrites;
    public bool Pcg700On { get { return Pcg == PcgType.Pcg700 && (PcgCtrl & 8) == 0; } }
    // MZ-1500 PCG: three 8K planes (blue, red, green), 1024 characters
    public byte[][] Plane = { new byte[0x2000], new byte[0x2000], new byte[0x2000] };
    public int PcgMap = -1;                                       // E5 data: -1 not mapped, 0 CG-ROM, 1 blue, 2 red, 3 green
    public int PcgPriority, PcgCells;
    public int[] Palette = { 0, 1, 2, 3, 4, 5, 6, 7 };

    // hooks for the headless runner and tools
    public Action<int, int> WriteHook;
    public Func<bool> PreStep;
    public Action<long, int, int> SoundHook;                      // (T, address, value) for 8253 / E008 writes
    public Action<string> Log = delegate (string s) { Console.Error.WriteLine(s); };
    public MzTrace Tr;
    public bool Quiet;

    // video
    public const int FBW = 384, FBH = 256, BX = 32, BY = 28;
    public int[] Fb = new int[FBW * FBH];
    public bool Mono;
    int renderLine;

    public MzMachine()
    {
        Cpu.Rd = Rd; Cpu.Fetch = Fetch; Cpu.Wr = Wr; Cpu.In = In; Cpu.Out = Out;
        for (int i = 0; i < 10; i++) Keys[i] = 0xFF;
        BuildStubRom();
    }

    // ---------------------------------------------------------------- ROMs
    public static string RomDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "roms");
    static readonly string[] romNames = { "1z013a.rom", "1z-013a.rom", "mz700.rom", "1z013b.rom", "mz700j.rom" };

    public void LoadRoms()
    {
        RomName = "";
        if (UseRom)
            foreach (var n in romNames)
            {
                string p = Path.Combine(RomDir, n);
                if (File.Exists(p) && new FileInfo(p).Length >= 0x1000) { Array.Copy(File.ReadAllBytes(p), Rom, 0x1000); RomName = n; break; }
            }
        if (RomName == "") BuildStubRom();
        LoadFont();
    }

    public void LoadFont()
    {
        HasFont = false; FontName = "";
        var names = Japanese ? new[] { "mz700fon.jpn", "mz700fon.jp", "mz700fon.int", "mz700fon.dat" } : new[] { "mz700fon.int", "mz700fon.dat", "mz700fon.jpn" };
        foreach (var n in names)
        {
            string p = Path.Combine(RomDir, n);
            if (!File.Exists(p)) continue;
            var raw = File.ReadAllBytes(p);
            for (int i = 0; i < 0x1000; i++) { int b = i < raw.Length ? raw[i] : 0, r = 0; for (int k = 0; k < 8; k++) if ((b & (1 << k)) != 0) r |= 0x80 >> k; Font[i] = (byte)r; }
            HasFont = true; FontName = n; break;
        }
        if (!HasFont) BuildFallbackFont();
    }

    void BuildFallbackFont()
    {
        // no CG-ROM: letters and digits from the visualiser's 5x7 font, dot blocks F0-FF, a box for everything else
        for (int c = 0; c < 512; c++)
        {
            int code = c & 255;
            for (int r = 0; r < 8; r++)
            {
                int v = 0;
                if (code == 0) v = 0;
                else if (code >= 1 && code <= 26) v = r < 7 ? Font6847.F[code, r] << 2 : 0;
                else if (code >= 0x20 && code <= 0x29) v = r < 7 ? Font6847.F[48 + code - 0x20, r] << 2 : 0;
                else if (code == 0x43) v = 0xFF;
                else if (code >= 0xF0) { int q = code & 15; bool top = r < 4; if (r != 0 && r != 4) v = (((q & (top ? 1 : 4)) != 0) ? 0x70 : 0) | (((q & (top ? 2 : 8)) != 0) ? 0x07 : 0); }
                else v = (r == 0 || r == 7) ? 0 : (r == 1 || r == 6) ? 0x7E : 0x42;
                Font[c * 8 + r] = (byte)v;
            }
        }
        FontName = "built-in (no mz700fon.int)";
    }

    /// <summary>A small stand-in monitor: sets the hardware up like 1Z-013A, says there is no ROM, and waits.
    /// 0038h jumps to 1038h as in the real monitor, so programs that put their interrupt handler there still work.</summary>
    void BuildStubRom()
    {
        Array.Clear(Rom, 0, Rom.Length);
        var c = new List<byte>();
        Action<int[]> e = bs => { foreach (int b in bs) c.Add((byte)b); };
        e(new[] { 0xF3, 0x31, 0xF0, 0x10, 0xED, 0x56 });            // DI; LD SP,10F0; IM 1
        e(new[] { 0x3E, 0x8A, 0x32, 0x03, 0xE0 });                  // 8255: A out, B in, C hi in, C lo out
        e(new[] { 0x3E, 0x07, 0x32, 0x03, 0xE0, 0x3E, 0x05, 0x32, 0x03, 0xE0 });   // PC3 = 1, PC2 = 1
        e(new[] { 0x3E, 0x36, 0x32, 0x07, 0xE0 });                  // 8253 counter 0 mode 3
        e(new[] { 0x3E, 0x00, 0x32, 0x08, 0xE0 });                  // sound gate off
        // clear the screen: D000-D3FF = 0, D800-DBFF = 71h
        e(new[] { 0x21, 0x00, 0xD0, 0x01, 0x00, 0x04, 0x36, 0x00, 0x23, 0x0B, 0x78, 0xB1, 0x20, 0xF8 });
        e(new[] { 0x21, 0x00, 0xD8, 0x01, 0x00, 0x04, 0x36, 0x71, 0x23, 0x0B, 0x78, 0xB1, 0x20, 0xF8 });
        // copy the message to the screen: LD HL,msg; LD DE,D000+40*2+1; LD BC,len; LDIR
        int msgAt = 0x100;
        string[] lines = { "MZ700ONPC", "", "NO MONITOR ROM  ROMS 1Z013A ROM", "", "DROP AN MZT FILE ON THE WINDOW", "OR PRESS F2" };
        var msg = new List<byte>(); var pos = new List<int>();
        for (int i = 0; i < lines.Length; i++) foreach (char ch in lines[i]) { msg.Add((byte)DisplayCode(ch)); pos.Add(0xD000 + (2 + i) * 40 + 2); }
        // simple: write each line with its own LDIR
        int mo = 0;
        for (int i = 0; i < lines.Length; i++)
        {
            int len = lines[i].Length; if (len == 0) continue;
            int dst = 0xD000 + (2 + i * 2) * 40 + 2, src = msgAt + mo;
            e(new[] { 0x21, src & 255, src >> 8, 0x11, dst & 255, dst >> 8, 0x01, len, 0, 0xED, 0xB0 });
            mo += len;
        }
        e(new[] { 0x18, 0xFE });                                    // JR $
        for (int i = 0; i < c.Count; i++) Rom[i] = c[i];
        for (int i = 0; i < msg.Count; i++) Rom[msgAt + i] = msg[i];
        Rom[0x38] = 0xC3; Rom[0x39] = 0x38; Rom[0x3A] = 0x10;       // JP 1038h
        Rom[0x66] = 0xED; Rom[0x67] = 0x45;                         // RETN
        RomName = "";
    }

    /// <summary>ASCII to MZ-700 display code (letters, digits and a few signs).</summary>
    public static int DisplayCode(char ch)
    {
        if (ch >= 'A' && ch <= 'Z') return ch - 'A' + 1;
        if (ch >= 'a' && ch <= 'z') return ch - 'a' + 0x81;
        if (ch >= '0' && ch <= '9') return ch - '0' + 0x20;
        switch (ch) { case '-': return 0x2A; case '=': return 0x2B; case ';': return 0x2C; case '/': return 0x2D; case '.': return 0x2E; case ',': return 0x2F; case ':': return 0x4F; case '?': return 0x49; case '!': return 0x61; }
        return 0;
    }
    /// <summary>MZ-700 display code to ASCII, for the text dump.</summary>
    public static char AsciiOf(int d)
    {
        if (d >= 1 && d <= 26) return (char)('A' + d - 1);
        if (d >= 0x81 && d <= 0x9A) return (char)('a' + d - 0x81);
        if (d >= 0x20 && d <= 0x29) return (char)('0' + d - 0x20);
        switch (d) { case 0: return ' '; case 0x2A: return '-'; case 0x2B: return '='; case 0x2C: return ';'; case 0x2D: return '/'; case 0x2E: return '.'; case 0x2F: return ','; case 0x4F: return ':'; case 0x49: return '?'; case 0x61: return '!'; }
        return '#';
    }

    // ---------------------------------------------------------------- power
    public void PowerOn(int randSeed = -1)
    {
        LoadRoms();
        if (randSeed >= 0) { var r = new Random(randSeed); r.NextBytes(Ram); r.NextBytes(Vram); }
        else
        {
            // DRAM powers up in stripes; programs must not rely on it
            for (int i = 0; i < 0x10000; i++) Ram[i] = (byte)(((i >> 7) & 1) != 0 ? 0xFF : 0x00);
            for (int i = 0; i < 0x1000; i++) Vram[i] = 0;
        }
        // the monitor never writes the attributes: CSP starts them at 71h (white on blue), the familiar boot screen
        for (int i = 0x800; i < 0xC00; i++) Vram[i] = 0x71;
        Array.Clear(Pcg700, 0, Pcg700.Length);
        if (HasFont) Array.Copy(Font, Pcg700, 0x1000);               // CSP: the lower codes keep the CG-ROM
        foreach (var p in Plane) Array.Clear(p, 0, p.Length);
        Reset();
        Cass.FastIndex = 0;
    }

    public void Reset()
    {
        RomIn = true; IoIn = true; Inhibit = false;
        foreach (var p in Pit) p.Reset();
        Pit[0].Mode = 3;
        PortA = 0; PortC = 0x0F; SoundGate = false; Pit[0].SetGate(false);
        PcgCtrl = 0xFF; PcgMap = -1; PcgPriority = 0; for (int i = 0; i < 8; i++) Palette[i] = i;
        Cpu.Reset();
        c0Clk = Cpu.Cyc * 5 / 16; lineClk = Cpu.Cyc * 5 / LINE_M; audM = Cpu.Cyc * 5;
        if (Tr != null) Tr.ResetTimes();
    }

    // ---------------------------------------------------------------- time helpers
    public long NowM { get { return Cpu.Cyc * 5; } }
    long AccM { get { return (Cpu.Cyc - 2) * 5; } }                 // a bus access: ~2 T before the instruction ends
    public int Line { get { return (int)((NowM - FrameStartM) / LINE_M); } }
    public bool VBlankAt(long m) { return (m % FRAME_M) / LINE_M >= VIS; }
    public bool HBlankAt(long m) { return (m % LINE_M) >= DISP_M; }

    // ---------------------------------------------------------------- memory
    public int Rd(int a) { if (Tr != null) Tr.R(a); return Mem(a, false); }
    public int Fetch(int a) { if (Tr != null) Tr.X(a); return Mem(a, false); }
    /// <summary>Memory as the CPU sees it, without waits or side effects.</summary>
    public int Peek(int a) { return Mem(a & 0xFFFF, true); }

    int Mem(int a, bool peek)
    {
        if (a < 0x1000) { if (RomIn) { if (!peek && RomWait) { Cpu.Cyc++; RomWaits++; } return Rom[a]; } return Ram[a]; }
        if (a < 0xD000 || !IoIn) return Ram[a];
        if (Inhibit) return 0xFF;
        if (Pcg == PcgType.Mz1500 && PcgMap >= 0 && a < 0xF000)
        {
            if (!peek) VramAccess(a, false);
            int o = a - 0xD000;
            return PcgMap == 0 ? (o < 0x1000 ? Font[o] : 0xFF) : Plane[PcgMap - 1][o];
        }
        if (a < 0xE000) { if (!peek) VramAccess(a, false); return Vram[a - 0xD000]; }
        if (a < 0xE800) return peek ? PeekIo(a) : ReadIo(a);
        return 0xFF;
    }

    public void Wr(int a, int v)
    {
        if (WriteHook != null) WriteHook(a, v);
        if (Tr != null) Tr.W(a, v);
        if (a < 0x1000) { if (RomIn) { if (RomWait) { Cpu.Cyc++; RomWaits++; } } else Ram[a] = (byte)v; return; }
        if (a < 0xD000 || !IoIn) { Ram[a] = (byte)v; return; }
        if (Inhibit) return;
        if (Pcg == PcgType.Mz1500 && PcgMap >= 0 && a < 0xF000)
        {
            VramAccess(a, true);
            if (PcgMap > 0) { Plane[PcgMap - 1][a - 0xD000] = (byte)v; PcgWrites++; }
            return;
        }
        if (a < 0xE000) { VramAccess(a, true); SyncVideo(); Vram[a - 0xD000] = (byte)v; return; }
        if (a < 0xE800) WriteIo(a, v);
    }

    // ---------------------------------------------------------------- VRAM wait states
    // CSP: an access to D000-DFFF outside the line's blanking window holds the CPU in WAIT until it starts, on every
    // line including VBLANK. The window is T 128-208 of the 227.2 T line (Display mode: no waits during VBLANK).
    void VramAccess(int a, bool write)
    {
        long m = AccM;
        long pos = m % FRAME_M; int line = (int)(pos / LINE_M); int x = (int)(pos % LINE_M);
        int w0 = WaitW0 * 5, w1 = WaitW1 * 5;
        if (x >= w0 && x < w1) return;
        if (VramWait == VramWaitMode.Display && line >= VIS) return;
        ContendedAccesses++; ContendedFrame++;
        if (ContendedFirstPc < 0) { ContendedFirstPc = CurPc; ContendedFirstFrame = Frames; }
        if (VramWait == VramWaitMode.Off) return;
        int wm = x < w0 ? w0 - x : LINE_M - x + w0;
        int wt = (wm + 4) / 5;
        if (Tr != null) Tr.Wait(Cpu.Cyc - 2, wt);
        Cpu.Cyc += wt; WaitT += wt; WaitTFrame += wt; WaitAccesses++;
    }

    // ---------------------------------------------------------------- memory-mapped I/O (E000-E7FF)
    int PeekIo(int a)
    {
        switch (a)
        {
            case 0xE001: return KeyRead();
            case 0xE002: return PortCRead(NowM);
            case 0xE008: return E008(NowM);
            default: return 0xFF;
        }
    }

    int ReadIo(int a)
    {
        long m = AccM;
        int r = 0xFF;
        switch (a)
        {
            case 0xE000: r = PortA; break;
            case 0xE001: r = KeyRead(); if (Tr != null) Tr.KeyRead(PortA & 15); break;
            case 0xE002: r = PortCRead(m); break;
            case 0xE004: case 0xE005: case 0xE006: SyncPit(m); r = Pit[a - 0xE004].Read(); if (Tr != null) Tr.Pit(); break;
            case 0xE008: r = E008(m); if (Tr != null) Tr.Joy(); break;
        }
        if (Tr != null) Tr.Io(a, r, false);
        return r;
    }

    void WriteIo(int a, int v)
    {
        long m = AccM;
        if (Tr != null) Tr.Io(a, v, true);
        switch (a)
        {
            case 0xE000: PortA = v; break;
            case 0xE002: SetPortC(m, (PortC & 0xF0) | (v & 0x0F)); break;
            case 0xE003:
                if ((v & 0x80) == 0) { int bit = (v >> 1) & 7; SetPortC(m, (v & 1) != 0 ? PortC | (1 << bit) : PortC & ~(1 << bit)); }
                else SetPortC(m, 0);    // a mode set clears the outputs
                break;
            case 0xE004: case 0xE005: case 0xE006: case 0xE007:
                {
                    SyncPit(m);
                    if (a == 0xE007) { int sc = v >> 6; if (sc < 3) Pit[sc].Control(v); }
                    else Pit[a - 0xE004].Write(v);
                    UpdateInt();
                    if (SoundHook != null) SoundHook(m / 5, a, v);
                    if (Tr != null) Tr.Pit();
                }
                break;
            case 0xE008:
                SyncPit(m);
                SoundGate = (v & 1) != 0; Pit[0].SetGate(SoundGate);
                if (SoundHook != null) SoundHook(m / 5, a, v);
                break;
            case 0xE010: if (Pcg == PcgType.Pcg700) PcgData = v; break;
            case 0xE011: if (Pcg == PcgType.Pcg700) PcgAddr = v; break;
            case 0xE012:
                if (Pcg == PcgType.Pcg700)
                {
                    if ((PcgCtrl & 0x10) == 0 && (v & 0x10) != 0)
                    {
                        SyncVideo();
                        int off = PcgAddr | ((v & 3) << 8);
                        off |= (v & 4) != 0 ? 0xC00 : 0x400;
                        Pcg700[off] = (v & 0x20) != 0 ? Font[off] : (byte)PcgData;
                        PcgWrites++;
                    }
                    if (((PcgCtrl ^ v) & 8) != 0) SyncVideo();
                    PcgCtrl = v;
                }
                break;
        }
    }

    int KeyRead()
    {
        int row = PortA & 15;
        return row < 10 ? Keys[row] : 0xFF;
    }

    int PortCRead(long m)
    {
        int r = PortC & 0x0F;
        if (Cass.Motor && Cass.PlayPressed) r |= 0x10;
        if (Cass.Level(m)) r |= 0x20;
        if (((m / (MCLK / 3)) & 1) == 0) r |= 0x40;                  // 556 cursor blink, ~1.5 Hz
        if (!VBlankAt(m)) r |= 0x80;                                  // /VBLK
        return r;
    }

    void SetPortC(long m, int v)
    {
        int old = PortC; PortC = v & 0x0F;
        if (((old ^ PortC) & 2) != 0) TapeOut.Line(m, (PortC & 2) != 0);
        if ((old & 8) == 0 && (PortC & 8) != 0) Cass.MotorPulse(m);
        if (((old ^ PortC) & 4) != 0) UpdateInt();
    }

    int E008(long m)
    {
        int r = 0;
        if (!HBlankAt(m)) r |= 0x80;                                  // CSP: bit 7 = 0 during HBLANK
        if (((m / (MCLK / 64)) & 1) != 0) r |= 1;                     // 556 TEMPO, ~32 Hz (CSP)
        r |= JoyBits(m);
        return r;
    }

    // MZ-1X03: in VBLANK each axis line goes low at the start and comes back after a time set by the pot; while the
    // picture is drawn the lines carry the buttons (low = pressed). JA1 = bit 1, JA2 = bit 2, JB1 = bit 3, JB2 = bit 4.
    int JoyBits(long m)
    {
        int v = 0x1E;
        if (Joystick == JoyType.None) return v;
        long pos = m % FRAME_M;
        if (pos >= (long)VIS * LINE_M)
        {
            double t = (pos - (long)VIS * LINE_M) / 5.0;
            for (int j = 0; j < 2; j++)
            {
                double x = Math.Max(-1, Math.Min(1, JoyX[j])), y = Math.Max(-1, Math.Min(1, JoyY[j]));
                if (t >= JoyPulseStart && t < JoyPulseStart + JoyPulseCentre + JoyPulseRange * x) v &= ~(2 << (j * 2));
                if (t >= JoyPulseStart && t < JoyPulseStart + JoyPulseCentre + JoyPulseRange * y) v &= ~(4 << (j * 2));
            }
        }
        else
        {
            for (int j = 0; j < 2; j++) { if (JoyA[j]) v &= ~(2 << (j * 2)); if (JoyB[j]) v &= ~(4 << (j * 2)); }
        }
        return v;
    }

    // ---------------------------------------------------------------- Z80 ports: bank switching and the MZ-1500 PCG
    public int In(int port) { int lo = port & 0xFF; if (Tr != null) Tr.Port(lo, 0xFF, false); return 0xFF; }

    public void Out(int port, int v)
    {
        int lo = port & 0xFF;
        if (Tr != null) Tr.Port(lo, v, true);
        bool p15 = Pcg == PcgType.Mz1500;
        switch (lo)
        {
            case 0xE0: RomIn = false; break;
            case 0xE1: IoIn = false; break;
            case 0xE2: RomIn = true; break;
            case 0xE3: IoIn = true; break;
            case 0xE4: RomIn = true; IoIn = true; Inhibit = false; if (p15) PcgMap = -1; break;
            case 0xE5:
                if (p15) PcgMap = v & 3;
                else if (!Inhibit) { ioBeforeInhibit = IoIn; Inhibit = true; IoIn = true; }
                break;
            case 0xE6:
                if (p15) PcgMap = -1;
                else if (Inhibit) { Inhibit = false; IoIn = ioBeforeInhibit; }
                break;
            case 0xF0: if (p15) { SyncVideo(); PcgPriority = v; } break;
            case 0xF1: if (p15) { SyncVideo(); Palette[(v >> 4) & 7] = v & 7; } break;
        }
    }

    // ---------------------------------------------------------------- 8253
    long c0Clk, lineClk;

    /// <summary>Brings counter 0 (1.108 MHz) and counters 1/2 (one clock per line) up to master clock m.</summary>
    void SyncPit(long m)
    {
        AudioTo(m);                                                   // clocks counter 0 along with the sound
        long l = m / LINE_M;
        while (lineClk < l)
        {
            lineClk++;
            long rises = Pit[1].Clock(1);
            if (rises > 0 && Pit[2].Clock(rises) > 0) { }
        }
        UpdateInt();
    }

    bool intLevel;
    void UpdateInt()
    {
        bool lv = Pit[2].Out && (PortC & 4) != 0;
        if (lv && !intLevel) Interrupts++;
        intLevel = lv;
        Cpu.IntLine = lv;
    }

    // ---------------------------------------------------------------- sound: OUT0 -> 44.1 kHz
    public const int RATE = 44100;
    public short[] Audio = new short[4096]; public int AudioN;
    public bool AudioOn = true;
    public int Volume = 7000;
    public Action<short> SampleHook;
    long audM; double sampFrac; double hp, hpPrev;
    const double SAMP_M = (double)MCLK / RATE;

    /// <summary>Integrates the speaker (OUT0) from the last audio time up to master clock m, making samples.</summary>
    void AudioTo(long m)
    {
        if (m <= audM) return;
        // counter 0 must be synced to audM before integrating
        long c = audM / 16; if (c > c0Clk) { Pit[0].Clock(c - c0Clk); c0Clk = c; }
        while (true)
        {
            double next = audM + (SAMP_M - sampFrac);
            long end = (long)Math.Ceiling(next);
            bool full = end <= m;
            if (!full) end = m;
            long n = end / 16 - c0Clk;
            double hf = n > 0 ? Pit[0].HighFraction(n) : (Pit[0].Out ? 1 : 0);
            double dur = end - audM;
            acc += (hf * 2 - 1) * dur;
            if (n > 0) { Pit[0].Clock(n); c0Clk += n; }
            sampFrac += dur; audM = end;
            if (!full) break;
            double lvl = acc / sampFrac; acc = 0; sampFrac -= SAMP_M; if (sampFrac < 0) sampFrac = 0;
            // AC coupling: a one-pole high-pass at ~10 Hz so a held level fades to silence
            double y = 0.9986 * (hp + lvl - hpPrev); hpPrev = lvl; hp = y;
            short smp = (short)Math.Max(-32768, Math.Min(32767, y * Volume));
            if (AudioOn && AudioN < Audio.Length) Audio[AudioN++] = smp;
            if (SampleHook != null) SampleHook(smp);
            if (Tr != null) Tr.Sample(lvl);
        }
    }
    double acc;

    // ---------------------------------------------------------------- execution
    /// <summary>Executes one instruction. Returns false (without executing) at a frame boundary.</summary>
    public bool StepOne()
    {
        long now = NowM;
        long rel = now - FrameStartM;
        if (rel >= FRAME_M)
        {
            SyncVideo(); while (renderLine < VIS) RenderLine(renderLine++);
            AudioTo(FrameStartM + FRAME_M);
            if (Tr != null) Tr.EndFrame();
            FrameStartM += FRAME_M; Frames++; renderLine = 0;
            WaitTFrame = 0; ContendedFrame = 0;
            return false;
        }
        SyncPit(now);
        while (renderLine < VIS && rel >= (long)renderLine * LINE_M + DISP_M) RenderLine(renderLine++);
        CurPc = Cpu.PC;
        if (FastTape && RomIn && Cass.File != null && (CurPc == 0x04D8 || CurPc == 0x04F8) && Rom[0x27] == 0xC3)
        {
            long d0 = Cpu.Cyc; TapeTrap(); if (Tr != null) Tr.Tape(d0, Cpu.Cyc); return true;
        }
        if (PreStep != null && !PreStep()) return true;
        if (Tr == null) { Cpu.Step(); return true; }
        long t0 = Cpu.Cyc;
        bool intTaken = Cpu.IntLine && Cpu.IFF1 && Cpu.EiDelay == 0;
        bool halted = Cpu.Halted && !intTaken;
        Cpu.Step();
        Tr.Step(CurPc, t0, Cpu.Cyc, intTaken, halted);
        return true;
    }

    public void RunFrame()
    {
        AudioN = 0;
        long end = Frames + 1;
        while (Frames < end) StepOne();
    }
    public void RunFrames(long n) { long t = Frames + n; while (Frames < t) StepOne(); }

    // ---------------------------------------------------------------- video
    public static readonly int[] Rgb = { 0x000000, 0x0000FF, 0xFF0000, 0xFF00FF, 0x00FF00, 0x00FFFF, 0xFFFF00, 0xFFFFFF };
    static readonly int[] Grey = { 0x000000, 0x1D1D1D, 0x4C4C4C, 0x696969, 0x969696, 0xB3B3B3, 0xE2E2E2, 0xFFFFFF };
    void SyncVideo() { }   // lines are drawn as the beam leaves the picture; nothing to flush

    void RenderLine(int ln)
    {
        int row = ln >> 3, y = ln & 7;
        int[] pal = Mono ? Grey : Rgb;
        int o = (BY + ln) * FBW + BX;
        bool p7 = Pcg700On;
        bool p15 = Pcg == PcgType.Mz1500 && (PcgPriority & 1) != 0;
        int cells = 0;
        for (int col = 0; col < 40; col++)
        {
            int idx = row * 40 + col;
            int code = Vram[idx], at = Vram[0x800 + idx];
            int gi = ((at & 0x80) << 4) | (code << 3) | y;
            int bits = p7 ? Pcg700[gi] : Font[gi];
            int fg = (at >> 4) & 7, bg = at & 7;
            if (p15 && (Vram[0xC00 + idx] & 8) != 0)
            {
                cells++;
                int pat = Vram[0x400 + idx], pat2 = Vram[0xC00 + idx];
                int pc = (pat << 3) | ((pat2 & 0xC0) << 5) | y;
                int b = Plane[0][pc], r = Plane[1][pc], g = Plane[2][pc];
                bool over = (PcgPriority & 2) != 0;
                for (int i = 0; i < 8; i++)
                {
                    int msk = 0x80 >> i;
                    int pcgc = ((b & msk) != 0 ? 1 : 0) | ((r & msk) != 0 ? 2 : 0) | ((g & msk) != 0 ? 4 : 0);
                    bool on = (bits & msk) != 0;
                    int c;
                    if (over) c = pcgc != 0 ? pcgc : (on ? fg : bg);
                    else c = on ? fg : (pcgc != 0 ? pcgc : bg);
                    Fb[o + col * 8 + i] = pal[Palette[c]];
                }
                continue;
            }
            if (Pcg == PcgType.Mz1500) { fg = Palette[fg]; bg = Palette[bg]; }
            int f = pal[fg], bk = pal[bg];
            int d = o + col * 8;
            for (int i = 0; i < 8; i++) Fb[d + i] = (bits & (0x80 >> i)) != 0 ? f : bk;
        }
        if (p15) PcgCells = ln == 0 ? cells : PcgCells + cells;
        if (Tr != null) Tr.Line(ln);
    }

    /// <summary>The current picture: 320x200, or 384x256 with the (black) border.</summary>
    public int[] Snapshot(bool border, out int w, out int h)
    {
        if (border) { w = FBW; h = FBH; return (int[])Fb.Clone(); }
        w = 320; h = 200; var p = new int[w * h];
        for (int y = 0; y < h; y++) Array.Copy(Fb, (BY + y) * FBW + BX, p, y * w, w);
        return p;
    }

    /// <summary>The screen as text (40x25), using display codes for letters, digits and a few signs.</summary>
    public string ScreenText()
    {
        var sb = new StringBuilder();
        for (int r = 0; r < 25; r++)
        {
            var line = new StringBuilder();
            for (int c = 0; c < 40; c++) { int d = Vram[r * 40 + c]; line.Append((Vram[0x800 + r * 40 + c] & 0x80) != 0 && d != 0 ? '#' : AsciiOf(d)); }
            sb.AppendLine(line.ToString().TrimEnd());
        }
        return sb.ToString().TrimEnd();
    }

    // ---------------------------------------------------------------- keyboard
    // the matrix: [row, bit]; rows 0-9 strobed by E000 bits 0-3, read on E001 (active low)
    public static readonly string[,] KROWS = {
        { "CR", ":", ";", "", "ALPHA", "=", "GRAPH", "_" },
        { "", "", "", "]", "[", "@", "Z", "Y" },
        { "X", "W", "V", "U", "T", "S", "R", "Q" },
        { "P", "O", "N", "M", "L", "K", "J", "I" },
        { "H", "G", "F", "E", "D", "C", "B", "A" },
        { "8", "7", "6", "5", "4", "3", "2", "1" },
        { ".", ",", "9", "0", "SPACE", "-", "^", "\\" },
        { "/", "?", "LEFT", "RIGHT", "DOWN", "UP", "DEL", "INST" },
        { "SHIFT", "", "", "", "", "", "CTRL", "BREAK" },
        { "", "", "", "F5", "F4", "F3", "F2", "F1" } };
    static readonly Dictionary<string, int> keyIndex = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    static MzMachine()
    {
        for (int r = 0; r < 10; r++) for (int b = 0; b < 8; b++) if (KROWS[r, b] != "") keyIndex[KROWS[r, b]] = r * 8 + b;
        keyIndex["RETURN"] = 0; keyIndex["ENTER"] = 0; keyIndex["SPC"] = 6 * 8 + 4; keyIndex["ESC"] = 8 * 8 + 7;
        keyIndex["INS"] = 7 * 8 + 7; keyIndex["BACKSPACE"] = 7 * 8 + 6;
    }
    public bool SetKey(string name, bool down)
    {
        int k; if (!keyIndex.TryGetValue(name, out k)) return false;
        if (down) Keys[k >> 3] &= ~(1 << (k & 7)); else Keys[k >> 3] |= 1 << (k & 7);
        return true;
    }
    public static bool KeyExists(string name) { return keyIndex.ContainsKey(name); }

    /// <summary>The keys to press for a character typed into the monitor or BASIC.</summary>
    public static string[] CharKeys(char ch)
    {
        if (ch >= 'a' && ch <= 'z') ch = (char)(ch - 32);
        if ((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')) return new[] { ch.ToString() };
        switch (ch)
        {
            case '\r': case '\n': return new[] { "CR" };
            case ' ': return new[] { "SPACE" };
            case ',': case '.': case '-': case '/': case ':': case ';': case '@': case '[': case ']': case '^': case '\\': case '?': case '=': case '_':
                return new[] { ch.ToString() };
            case '!': return new[] { "SHIFT", "1" }; case '"': return new[] { "SHIFT", "2" }; case '#': return new[] { "SHIFT", "3" };
            case '$': return new[] { "SHIFT", "4" }; case '%': return new[] { "SHIFT", "5" }; case '&': return new[] { "SHIFT", "6" };
            case '\'': return new[] { "SHIFT", "7" }; case '(': return new[] { "SHIFT", "8" }; case ')': return new[] { "SHIFT", "9" };
            case '+': return new[] { "SHIFT", ";" }; case '*': return new[] { "SHIFT", ":" }; case '<': return new[] { "SHIFT", "," };
            case '>': return new[] { "SHIFT", "." };
        }
        return null;
    }

    // ---------------------------------------------------------------- program loading
    public MzTapeFile Program;
    public string ProgramPath;

    /// <summary>Loads an MZT/MZF straight into memory and runs it, as the monitor's L command would leave things:
    /// the header at 10F0h, SP = 10F0h, interrupts off. With the real monitor it first boots to the * prompt.
    /// Further files in the image stay on the tape for the program's own loads.</summary>
    public MzBlock LaunchMzt(string path)
    {
        var f = MzTapeFile.Load(path);
        PowerOn();
        if (HasRom) RunFrames(60);
        Program = f; ProgramPath = path;
        Cass.InsertMzt(f);
        var b = f.Blocks[0];
        LoadBlock(b);
        Cass.FastIndex = 1;
        Cpu.SP = 0x10F0; Cpu.PC = b.Exec; Cpu.IFF1 = Cpu.IFF2 = false; Cpu.Halted = false; Cpu.IM = 1;
        TapeLog.Add("LOAD " + b.Describe());
        if (b.Attr != 1) Log(b.Attr == 2 ? "\"" + b.Name + "\" is a BASIC program (attribute 02): load S-BASIC first, then LOAD it from tape (F2)"
            : string.Format("\"{0}\" has file attribute {1:X2}, not 01 (machine code)", b.Name, b.Attr));
        return b;
    }

    public void LoadBlock(MzBlock b)
    {
        for (int i = 0; i < 128; i++) Ram[0x10F0 + i] = b.Header[i];
        for (int i = 0; i < b.Data.Length; i++) PokeRam((b.Load + i) & 0xFFFF, b.Data[i]);
    }
    void PokeRam(int a, int v) { Ram[a] = (byte)v; if (a >= 0xD000 && a < 0xE000 && IoIn) Vram[a - 0xD000] = (byte)v; }

    /// <summary>The monitor's RDINF (04D8h) and RDDAT (04F8h), done at once from the tape image.</summary>
    void TapeTrap()
    {
        int pc = Cpu.PC;
        var f = Cass.File;
        if (pc == 0x04D8)
        {
            if (Cass.FastIndex >= f.Blocks.Count) { Ret(true, 2); TapeLog.Add("RDINF: end of tape (BREAK)"); return; }
            var b = f.Blocks[Cass.FastIndex];
            for (int i = 0; i < 128; i++) Wr(0x10F0 + i, b.Header[i]);
            TapeLog.Add("RDINF " + b.Describe());
            if (!Quiet) Log("tape: header " + b.Describe());
            Cpu.Cyc += 3546895 / 4;
        }
        else
        {
            int size = Peek(0x1102) | (Peek(0x1103) << 8), load = Peek(0x1104) | (Peek(0x1105) << 8);
            var b = Cass.FastIndex < f.Blocks.Count ? f.Blocks[Cass.FastIndex] : null;
            if (b == null) { Ret(true, 2); return; }
            for (int i = 0; i < size; i++) Wr((load + i) & 0xFFFF, i < b.Data.Length ? b.Data[i] : 0);
            Cass.FastIndex++;
            TapeLog.Add(string.Format("RDDAT {0:X4} bytes to {1:X4}", size, load));
            if (!Quiet) Log(string.Format("tape: data {0:X4} bytes to {1:X4}", size, load));
            Cpu.Cyc += size * 50;
        }
        if (TapeLog.Count > 40) TapeLog.RemoveAt(0);
        Ret(false, 0);
    }
    void Ret(bool carry, int a)
    {
        if (carry) { Cpu.A = a; Cpu.F |= Z80.CF; } else Cpu.F &= ~Z80.CF;
        int r = Peek(Cpu.SP) | (Peek((Cpu.SP + 1) & 0xFFFF) << 8); Cpu.SP = (Cpu.SP + 2) & 0xFFFF; Cpu.PC = r;
        if (Peek(0x119C) == 0xF0) { Cpu.IFF1 = Cpu.IFF2 = true; }
    }
}
