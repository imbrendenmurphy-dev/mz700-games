// MZ700onPC headless runner (mzemu.exe): scripted tests, screenshots, WAV capture, sound logs, profiling,
// VRAM wait and crash checks, the visualiser as PNG. Same emulation core as the window.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

public sealed class Headless
{
    readonly MzMachine m = new MzMachine();
    MzVis vis;
    Z80 cpu { get { return m.Cpu; } }
    readonly Dictionary<string, int> sym = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
    bool booted = false;
    string baseDir = ".";

    bool crashCheck = false, crashed = false;
    int[] ringPc = new int[4096]; int ringPos = 0; bool ringOn;
    int tmarkAddr = -1; long tmarkLast = -1; int[] tmarkHist = new int[16];
    long[] prof = null;
    int minSp = 0xFFFF, spLo = 0x1000, spHi = 0x10F1;
    List<int[]> watches = new List<int[]>();
    BinaryWriter wav; long wavN;
    StreamWriter sndLog;

    public Headless()
    {
        m.UseRom = false;
        m.AudioOn = false;
        m.Log = s => Console.Error.WriteLine(s);
        m.PreStep = PreStep;
        m.WriteHook = WriteHook;
    }

    void Boot()
    {
        if (booted) return;
        string rr = Environment.GetEnvironmentVariable("RANDRAM");
        m.PowerOn(rr != null ? int.Parse(rr) : -1);
        if (m.HasRom) m.RunFrames(60);
        booted = true;
    }

    bool PreStep()
    {
        int pc = m.CurPc;
        if (ringOn || crashCheck) { ringPc[ringPos] = pc | (cpu.SP << 16); ringPos = (ringPos + 1) & 4095; }
        if (crashCheck && !crashed)
        {
            bool bad = false;
            if (pc < 0x1000 && !m.HasRom && pc != 0x38 && pc != 0x66 && m.RomIn) bad = true;
            if (pc >= 0xD000 && pc < 0xE800 && m.IoIn) bad = true;
            if (bad)
            {
                crashed = true;
                Console.Error.WriteLine("CRASH? pc={0:X4} sp={1:X4} frame {2}", pc, cpu.SP, m.Frames);
                using (var w = new StreamWriter(Path.Combine(baseDir, "crash.txt")))
                    for (int i = 0; i < 4096; i++) { int k = (ringPos + i) & 4095; w.WriteLine("{0:X4} SP={1:X4} {2}", ringPc[k] & 0xFFFF, (ringPc[k] >> 16) & 0xFFFF, Near(ringPc[k] & 0xFFFF)); }
                return false;
            }
        }
        if (cpu.SP >= spLo && cpu.SP < spHi && cpu.SP < minSp) minSp = cpu.SP;
        return true;
    }

    void WriteHook(int a, int v)
    {
        if (a == tmarkAddr)
        {
            long t = cpu.Cyc;
            if (tmarkLast >= 0) { int f = (int)((t - tmarkLast + MzMachine.FT / 2) / MzMachine.FT); if (f > 15) f = 15; tmarkHist[f]++; }
            tmarkLast = t;
        }
        foreach (var wr in watches)
            if (a >= wr[0] && a <= wr[1])
            {
                long rel = cpu.Cyc * 5 - m.FrameStartM;
                Console.Error.WriteLine("write {0:X4}={1:X2} pc={2:X4} {3} frame {4} line {5} t {6}", a, v & 255, m.CurPc, Near(m.CurPc), m.Frames, rel / MzMachine.LINE_M, (rel % MzMachine.LINE_M) / 5);
            }
    }

    void Step()
    {
        if (prof == null) { m.StepOne(); return; }
        int pc = cpu.PC; long c0 = cpu.Cyc;
        m.StepOne();
        prof[pc] += cpu.Cyc - c0;
    }
    void RunFrames(long n) { long t = m.Frames + n; while (m.Frames < t && !crashed) Step(); }

    string Near(int a)
    {
        string best = null; int bv = -1;
        foreach (var kv in sym) if (kv.Value <= a && kv.Value > bv && a - kv.Value < 0x800) { bv = kv.Value; best = kv.Key; }
        return best == null ? "" : best + "+" + (a - bv);
    }

    int Num(string s)
    {
        int plus = s.IndexOf('+', 1);
        if (plus > 0) return Num(s.Substring(0, plus)) + Num(s.Substring(plus + 1));
        int v; if (sym.TryGetValue(s, out v)) return v;
        if (s.StartsWith("$")) return Convert.ToInt32(s.Substring(1), 16);
        if (s.StartsWith("0x") || s.StartsWith("0X")) return Convert.ToInt32(s.Substring(2), 16);
        if ((s.EndsWith("h") || s.EndsWith("H")) && s.Length > 1) return Convert.ToInt32(s.Substring(0, s.Length - 1), 16);
        int d; if (int.TryParse(s, out d)) return d;
        return Convert.ToInt32(s, 16);
    }
    static double Dbl(string s) { return double.Parse(s, System.Globalization.CultureInfo.InvariantCulture); }

    void SetKey(string k, bool down)
    {
        string K = k.ToUpperInvariant();
        if (K.Length > 2 && (K.StartsWith("J1") || K.StartsWith("J2")))
        {
            int j = K[1] - '1'; string w = K.Substring(2);
            double v = down ? 1 : 0;
            switch (w)
            {
                case "LEFT": m.JoyX[j] = -v; return; case "RIGHT": m.JoyX[j] = v; return;
                case "UP": m.JoyY[j] = -v; return; case "DOWN": m.JoyY[j] = v; return;
                case "FIRE": case "A": m.JoyA[j] = down; return; case "B": case "ARM": m.JoyB[j] = down; return;
            }
        }
        if (!m.SetKey(K, down)) Console.Error.WriteLine("unknown key " + k);
    }

    public void SaveScreen(string fn, int scale, bool border)
    {
        int w, h; int[] px = m.Snapshot(border, out w, out h);
        SavePng(fn, px, w, h, scale);
    }
    public static void SavePng(string fn, int[] src, int w, int h, int scale)
    {
        if (scale < 1) scale = 1;
        var bmp = new Bitmap(w * scale, h * scale, PixelFormat.Format32bppRgb);
        var bd = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.WriteOnly, PixelFormat.Format32bppRgb);
        int[] dst = new int[bmp.Width * bmp.Height];
        for (int y = 0; y < bmp.Height; y++) for (int x = 0; x < bmp.Width; x++) dst[y * bmp.Width + x] = src[(y / scale) * w + x / scale];
        System.Runtime.InteropServices.Marshal.Copy(dst, 0, bd.Scan0, dst.Length);
        bmp.UnlockBits(bd);
        string dir = Path.GetDirectoryName(Path.GetFullPath(fn)); if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        bmp.Save(fn, ImageFormat.Png); bmp.Dispose();
    }

    void WavStart(string fn)
    {
        wav = new BinaryWriter(File.Create(fn)); wav.Write(new byte[44]); wavN = 0;
        m.SampleHook = s => { wav.Write(s); wavN++; };
    }
    void WavEnd()
    {
        if (wav == null) return;
        m.SampleHook = null;
        var s = wav.BaseStream; long n = wavN;
        s.Seek(0, SeekOrigin.Begin);
        var w = new BinaryWriter(s);
        w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write((int)(36 + n * 2)); w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
        w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(44100); w.Write(88200); w.Write((short)2); w.Write((short)16);
        w.Write(Encoding.ASCII.GetBytes("data")); w.Write((int)(n * 2));
        w.Flush(); s.Close(); wav = null;
        Console.Error.WriteLine("wav: {0:F1} s", n / 44100.0);
    }

    string Regs()
    {
        return string.Format("frame {0} line {1} PC={2:X4} {11} SP={3:X4} AF={4:X2}{5:X2} BC={6:X4} DE={7:X4} HL={8:X4} IX={9:X4} IY={10:X4} IFF1={12} IM={13} banks {14}",
            m.Frames, m.Line, cpu.PC, cpu.SP, cpu.A, cpu.F, (cpu.B << 8) | cpu.C, (cpu.D << 8) | cpu.E, (cpu.H << 8) | cpu.L, cpu.IX, cpu.IY, Near(cpu.PC), cpu.IFF1, cpu.IM, Banks());
    }
    string Banks() { return (m.RomIn ? "ROM" : "RAM") + "/" + (m.Inhibit ? "LOCKED" : m.IoIn ? "VRAM" : "RAM"); }

    public int RunScript(string path)
    {
        baseDir = Path.GetDirectoryName(Path.GetFullPath(path));
        return RunLines(File.ReadAllLines(path));
    }

    public int RunLines(IEnumerable<string> lines)
    {
        foreach (var raw in lines)
        {
            string ln = raw.Trim(); if (ln.Length == 0 || ln.StartsWith(";") || ln.StartsWith("#")) continue;
            bool go;
            try { go = Exec(ln); }
            catch (Exception ex) { Console.Error.WriteLine("error in '" + ln + "': " + ex.Message); return 1; }
            if (!go) break;
            if (crashed) { Console.Error.WriteLine("stopping: crash"); break; }
        }
        if (wav != null) WavEnd();
        if (sndLog != null) sndLog.Close();
        Console.Error.WriteLine("done at frame {0}; min SP {1:X4}; VRAM waits {2} T; contended accesses {3}", m.Frames, minSp, m.WaitT, m.ContendedAccesses);
        return crashed ? 2 : 0;
    }

    void VisOn()
    {
        if (vis != null) return;
        m.Tr = new MzTrace(m); vis = new MzVis(m) { T = m.Tr };
        foreach (var kv in sym) if (!vis.Sym.ContainsKey(kv.Value & 0xFFFF)) vis.Sym[kv.Value & 0xFFFF] = kv.Key.ToUpperInvariant();
    }

    void LoadSym(string f)
    {
        foreach (var sl in File.ReadAllLines(f))
        {
            // "ADDR NAME" (zasm) or "NAME: EQU 0x0000ADDR" (sjasmplus)
            var p = sl.Split(new[] { ' ', '\t', '=' }, StringSplitOptions.RemoveEmptyEntries);
            if (p.Length < 2) continue;
            try
            {
                if (p.Length >= 3 && p[1].ToUpperInvariant() == "EQU") { sym[p[0].TrimEnd(':')] = Num(p[2]) & 0xFFFF; continue; }
                sym[p[1]] = Convert.ToInt32(p[0].TrimStart('$'), 16);
            }
            catch { }
        }
    }

    static readonly HashSet<string> configCmds = new HashSet<string> { "rom", "pcg", "vramwait", "joy", "joystick", "cgrom", "fasttape", "romwait", "sym", "quiet", "crash", "stack", "print", "watch", "ring" };

    bool Exec(string ln)
    {
        var a = ln.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
        string cmd = a[0].ToLowerInvariant();
        string a1 = a.Length > 1 ? a[1] : "", a2 = a.Length > 2 ? a[2] : "";
        string rest = ln.Trim().Substring(a[0].Length).Trim().Trim('"');
        if (!configCmds.Contains(cmd)) Boot();
        switch (cmd)
        {
            // ---- configuration
            case "rom": m.UseRom = a1.ToLowerInvariant() != "none"; if (m.UseRom && a1.ToLowerInvariant() != "auto") MzMachine.RomDir = Path.GetFullPath(a1); booted = false; break;
            case "pcg":
                { string p = a1.ToLowerInvariant(); m.Pcg = p.Contains("700") ? PcgType.Pcg700 : p.Contains("1500") ? PcgType.Mz1500 : PcgType.None; booted = false; }
                break;
            case "vramwait":
                {
                    string p = a1.ToLowerInvariant();
                    m.VramWait = p == "off" ? VramWaitMode.Off : p.StartsWith("disp") ? VramWaitMode.Display : VramWaitMode.All;
                    m.WaitW0 = 128; m.WaitW1 = p.StartsWith("cons") ? 191 : 208;
                    if (a.Length > 3) { m.WaitW0 = Num(a[2]); m.WaitW1 = Num(a[3]); }
                }
                break;
            case "joy": case "joystick":
                if (a1.ToLowerInvariant() == "none" || a1 == "off") m.Joystick = JoyType.None;
                else if (a1.ToLowerInvariant().StartsWith("mz") || a1 == "on") m.Joystick = JoyType.Mz1x03;
                else
                {
                    // joy N X Y [A] [B]: stick N (1 or 2) at X,Y (-1..1), buttons 0/1
                    int j = Num(a1) - 1; m.JoyX[j] = Dbl(a2); m.JoyY[j] = a.Length > 3 ? Dbl(a[3]) : 0;
                    m.JoyA[j] = a.Length > 4 && a[4] == "1"; m.JoyB[j] = a.Length > 5 && a[5] == "1";
                }
                break;
            case "cgrom": m.Japanese = a1.ToLowerInvariant().StartsWith("j"); booted = false; break;
            case "fasttape": m.FastTape = a1 != "off" && a1 != "0"; break;
            case "romwait": m.RomWait = a1 != "off" && a1 != "0"; break;
            case "sym": LoadSym(rest); break;
            case "quiet": m.Quiet = true; break;
            case "crash": crashCheck = true; break;
            case "stack": spLo = Num(a1); spHi = Num(a2); break;
            case "watch": watches.Add(new[] { Num(a1), a2 != "" ? Num(a2) : Num(a1) }); break;
            case "print": Console.WriteLine(rest); break;

            // ---- running
            case "mzt": case "mzf": case "load": case "vz":
                {
                    var b = m.LaunchMzt(rest);
                    Console.Error.WriteLine("loaded {0}", b.Describe());
                    if (vis != null && vis.Sym.Count == 0) vis.FindSymbols(rest);
                }
                break;
            case "reset": m.Reset(); break;
            case "power": m.PowerOn(); if (m.HasRom) m.RunFrames(60); break;
            case "frames": RunFrames(Num(a1)); break;
            case "seconds": RunFrames((long)(Dbl(a1) * 50)); break;
            case "down": SetKey(a1, true); break;
            case "up": SetKey(a1, false); break;
            case "tap": SetKey(a1, true); RunFrames(a2 != "" ? Num(a2) : 4); SetKey(a1, false); RunFrames(4); break;
            case "type": TypeText(ln.Substring(4).TrimStart().Replace("\\r", "\r")); break;
            case "release": for (int i = 0; i < 10; i++) m.Keys[i] = 0xFF; for (int j = 0; j < 2; j++) { m.JoyX[j] = m.JoyY[j] = 0; m.JoyA[j] = m.JoyB[j] = false; } break;
            case "rand":
                {
                    int n = Num(a1); var rnd = new Random(a2 != "" ? Num(a2) : 1);
                    string[] ks = a.Length > 3 ? a[3].Split(',') : new[] { "SPACE", "LEFT", "RIGHT", "UP", "DOWN" };
                    for (int i = 0; i < n && !crashed; i += 8) { for (int k = 0; k < ks.Length; k++) SetKey(ks[k], rnd.Next(3) == 0 || (k == 0 && rnd.Next(4) == 0)); RunFrames(8); }
                    for (int k = 0; k < ks.Length; k++) SetKey(ks[k], false);
                }
                break;
            case "poke": m.Wr(Num(a1), Num(a2)); break;
            case "out": m.Out(Num(a1), Num(a2)); break;
            case "bin":
                {
                    var b = File.ReadAllBytes(a1); int ad = Num(a2);
                    for (int i = 0; i < b.Length; i++) m.Ram[(ad + i) & 0xFFFF] = b[i];
                    Console.WriteLine("bin: {0} bytes at {1:X4}", b.Length, ad);
                }
                break;
            case "pc": cpu.PC = Num(a1); break;
            case "sp": cpu.SP = Num(a1); break;

            // ---- cassette
            case "tape":
                {
                    string f = rest; bool wavIn = !MzTapeFile.IsTapeName(f);
                    if (wavIn) m.Cass.InsertAudio(VzTape.Load(f, 0)); else m.Cass.InsertMzt(MzTapeFile.Load(f));
                    m.Cass.Play(m.NowM);
                    Console.Error.WriteLine("tape: {0} ({1:F1} s), playing", m.Cass.Name, m.Cass.Length);
                }
                break;
            case "tapeinsert": { string f = rest; if (MzTapeFile.IsTapeName(f)) m.Cass.InsertMzt(MzTapeFile.Load(f)); else m.Cass.InsertAudio(VzTape.Load(f, 0)); } break;
            case "tapeplay": m.Cass.Play(m.NowM); break;
            case "tapestop": m.Cass.Stop(m.NowM); break;
            case "taperew": m.Cass.Rewind(); break;
            case "tapepos": Console.Error.WriteLine("tape {0:F2} s of {1:F1}, motor {2}, play {3}, toggles {4}", m.Cass.Seconds, m.Cass.Length, m.Cass.Motor ? "on" : "off", m.Cass.PlayPressed ? "down" : "up", m.Cass.MotorToggles); break;
            case "taperec": m.TapeOut.Start(rest, m.NowM, (m.PortC & 2) != 0); break;
            case "taperecend": Console.WriteLine("tape out: " + m.TapeOut.Stop(m.NowM)); break;
            case "tapelog": foreach (var l in m.TapeLog) Console.WriteLine("  " + l); break;

            // ---- inspection
            case "screen": SaveScreen(a1, a2 != "" ? Num(a2) : 1, a.Length > 3 && a[3] == "border"); break;
            case "shots":
                { int n = Num(a2), ev = a.Length > 3 ? Num(a[3]) : 25; for (int i = 0; i < n; i++) { RunFrames(ev); SaveScreen(a1 + i.ToString("D3") + ".png", 1, false); } }
                break;
            case "text": Console.WriteLine(m.ScreenText()); break;
            case "regs": Console.Error.WriteLine(Regs()); break;
            case "mode":
                Console.WriteLine("banks {0}  pcg {1} {2}  vram wait {3} {4}-{5}  joystick {6}  font {7}  monitor {8}", Banks(), m.Pcg,
                    m.Pcg == PcgType.Pcg700 ? (m.Pcg700On ? "on" : "off") : m.Pcg == PcgType.Mz1500 ? "map " + m.PcgMap + " priority " + m.PcgPriority : "",
                    m.VramWait, m.WaitW0, m.WaitW1, m.Joystick, m.FontName, m.HasRom ? m.RomName : "stub");
                break;
            case "pit":
                for (int i = 0; i < 3; i++) { var p = m.Pit[i]; Console.WriteLine("counter {0}: mode {1} {2} reload {3} count {4} out {5} gate {6} {7}", i, p.Mode, p.ModeName, p.Reload, p.Count, p.Out ? 1 : 0, p.Gate ? 1 : 0, p.Counting ? "running" : "stopped"); }
                Console.WriteLine("int mask PC2 {0}, interrupts {1}", (m.PortC & 4) != 0 ? 1 : 0, m.Interrupts);
                break;
            case "peek":
                { int ad = Num(a1), n = a2 != "" ? Num(a2) : 1; var sb = new StringBuilder(); sb.AppendFormat("{0} {1:X4}:", a1, ad); for (int i = 0; i < n; i++) sb.AppendFormat(" {0:X2}", m.Peek((ad + i) & 0xFFFF)); Console.WriteLine(sb.ToString()); }
                break;
            case "peekw": { int ad = Num(a1); Console.WriteLine("{0} = {1}", a1, m.Peek(ad) | (m.Peek((ad + 1) & 0xFFFF) << 8)); } break;
            case "dump": { var d = new byte[65536]; for (int i = 0; i < 65536; i++) d[i] = (byte)m.Peek(i); File.WriteAllBytes(a1, d); } break;
            case "dumpram": File.WriteAllBytes(a1, m.Ram); break;
            case "dumpvram": File.WriteAllBytes(a1, m.Vram); break;
            case "wav": WavStart(rest); break;
            case "wavend": WavEnd(); break;
            case "sndlog":
                // sndlog FILE: every 8253 / E008 write as "T address value" (hex); sndlogend closes it
                sndLog = new StreamWriter(rest);
                m.SoundHook = (t, ad, v) => sndLog.WriteLine("{0} {1:X4} {2:X2}", t, ad, v);
                break;
            case "sndlogend": m.SoundHook = null; if (sndLog != null) sndLog.Close(); sndLog = null; break;
            case "waits":
                Console.WriteLine("vram waits: {0} T over {1} accesses (mode {2}, window {3}-{4}); contended accesses {5}{6}; rom waits {7}", m.WaitT, m.WaitAccesses, m.VramWait, m.WaitW0, m.WaitW1, m.ContendedAccesses,
                    m.ContendedFirstPc >= 0 ? string.Format(" (first at PC {0:X4} {1}, frame {2})", m.ContendedFirstPc, Near(m.ContendedFirstPc), m.ContendedFirstFrame) : "", m.RomWaits);
                break;
            case "waitreset": m.WaitT = m.WaitAccesses = m.ContendedAccesses = 0; m.ContendedFirstPc = -1; break;
            case "tmark": tmarkAddr = Num(a1); tmarkLast = -1; Array.Clear(tmarkHist, 0, 16); break;
            case "tstats":
                {
                    long tot = 0; for (int i = 0; i < 16; i++) tot += tmarkHist[i];
                    var sb = new StringBuilder("fields per frame:"); for (int i = 0; i < 16; i++) if (tmarkHist[i] > 0) sb.AppendFormat("  {0}:{1:F1}%", i, 100.0 * tmarkHist[i] / Math.Max(1, tot));
                    Console.WriteLine(sb.ToString() + "  (" + tot + " frames)");
                }
                break;
            case "prof": prof = Num(a1) != 0 ? new long[65536] : null; break;
            case "profsave":
                {
                    var agg = new Dictionary<string, long>(); long tot = 0;
                    for (int i = 0; i < 65536; i++) if (prof[i] > 0) { string n = Near(i); int plus = n.IndexOf('+'); if (plus > 0) n = n.Substring(0, plus); if (n == "") n = i.ToString("X4"); long v; agg.TryGetValue(n, out v); agg[n] = v + prof[i]; tot += prof[i]; }
                    var l = new List<KeyValuePair<string, long>>(agg); l.Sort((x, y) => y.Value.CompareTo(x.Value));
                    using (var w = new StreamWriter(a1)) foreach (var kv in l) w.WriteLine("{0,8:F2}% {1,12} {2}", 100.0 * kv.Value / tot, kv.Value, kv.Key);
                }
                break;
            case "dis":
                {
                    int ad = Num(a1), n = a2 != "" ? Num(a2) : 16;
                    for (int i = 0; i < n; i++)
                    {
                        int len; string t = Z80Dis.Dis(m.Peek, ad, out len);
                        var hx = new StringBuilder(); for (int k = 0; k < len; k++) hx.Append(m.Peek((ad + k) & 0xFFFF).ToString("X2"));
                        Console.WriteLine("{0:X4}  {1,-9} {2,-20} {3}", ad, hx, t, Near(ad));
                        ad = (ad + Math.Max(1, len)) & 0xFFFF;
                    }
                }
                break;
            case "ring":
                if (a1.ToLowerInvariant() == "on") ringOn = true;
                else using (var w = new StreamWriter(Path.GetFullPath(a1)))
                    for (int i = 0; i < 4096; i++) { int k = (ringPos + i) & 4095; w.WriteLine("{0:X4} SP={1:X4} {2}", ringPc[k] & 0xFFFF, (ringPc[k] >> 16) & 0xFFFF, Near(ringPc[k] & 0xFFFF)); }
                break;
            case "until":
                {
                    int pc = Num(a1); long mx = m.Frames + (a2 != "" ? Num(a2) : 500); bool hit = false;
                    while (m.Frames < mx && !crashed) { Step(); if (cpu.PC == pc) { hit = true; break; } }
                    Console.Error.WriteLine("until {0}: {1} at frame {2}", a1, hit ? "reached" : "NOT reached", m.Frames);
                }
                break;
            case "untilmem":
                {
                    int ad = Num(a1), v = Num(a2); long mx = m.Frames + (a.Length > 3 ? Num(a[3]) : 500); bool hit = false;
                    while (m.Frames < mx && !crashed) { RunFrames(1); if (m.Peek(ad) == v) { hit = true; break; } }
                    Console.Error.WriteLine("untilmem {0}={1}: {2} at frame {3}", a1, a2, hit ? "reached" : "NOT reached", m.Frames);
                }
                break;
            case "untiltext":
                {
                    // untiltext TEXT [maxframes]: run until the screen shows TEXT
                    string t = a1.Replace('_', ' '); long mx = m.Frames + (a2 != "" ? Num(a2) : 500); bool hit = false;
                    while (m.Frames < mx && !crashed) { RunFrames(1); if (m.ScreenText().Contains(t)) { hit = true; break; } }
                    Console.Error.WriteLine("untiltext {0}: {1} at frame {2}", a1, hit ? "reached" : "NOT reached", m.Frames);
                }
                break;
            case "minsp": Console.WriteLine("min SP {0:X4}", minSp); break;
            case "frame": Console.WriteLine("frame {0}", m.Frames); break;
            case "vis":
                VisOn();
                if (a1 != "" && a1.ToLowerInvariant() != "on")
                {
                    vis.Render();
                    int vw, vh; int[] sp = m.Snapshot(true, out vw, out vh);
                    int[] img; int iw, ih;
                    if (a2.ToLowerInvariant() == "panels")
                    {
                        iw = MzVis.W * 2; ih = MzVis.H; img = new int[iw * ih];
                        for (int y = 0; y < ih; y++) { Array.Copy(vis.Left, y * MzVis.W, img, y * iw, MzVis.W); Array.Copy(vis.Right, y * MzVis.W, img, y * iw + MzVis.W, MzVis.W); }
                    }
                    else
                    {
                        iw = 1920; ih = 1080; img = new int[iw * ih]; int s = 3;
                        int ox = (iw - vw * s) / 2, oy = (ih - vh * s) / 2;
                        for (int y = 0; y < ih; y++)
                        {
                            Array.Copy(vis.Left, y * MzVis.W, img, y * iw, MzVis.W);
                            Array.Copy(vis.Right, y * MzVis.W, img, y * iw + iw - MzVis.W, MzVis.W);
                            int sy = y - oy; if (sy < 0 || sy >= vh * s) continue;
                            for (int x = 0; x < vw * s; x++) img[y * iw + ox + x] = sp[(sy / s) * vw + x / s];
                        }
                    }
                    SavePng(a1, img, iw, ih, 1);
                }
                break;
            case "quit": case "exit": return false;
            default: Console.Error.WriteLine("?? " + cmd); break;
        }
        return true;
    }

    void TypeText(string s)
    {
        foreach (char ch in s)
        {
            var ks = MzMachine.CharKeys(ch); if (ks == null) continue;
            foreach (var k in ks) m.SetKey(k, true);
            RunFrames(3);
            foreach (var k in ks) m.SetKey(k, false);
            RunFrames(3);
        }
    }

    public static int Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("mzemu script.txt               run a test script (see README.md)");
            Console.Error.WriteLine("mzemu -e \"cmd; cmd; ...\"       run commands given inline");
            Console.Error.WriteLine("mzemu game.mzt [frames] [out.png]   load, run, screenshot");
            return 1;
        }
        var h = new Headless();
        if (args[0] == "-e") return h.RunLines(string.Join(" ", args, 1, args.Length - 1).Split(';'));
        if (MzTapeFile.IsTapeName(args[0]))
        {
            var l = new List<string>();
            l.Add("mzt " + args[0]);
            l.Add("frames " + (args.Length > 1 ? args[1] : "250"));
            l.Add("screen " + (args.Length > 2 ? args[2] : "screen.png") + " 2");
            return h.RunLines(l);
        }
        return h.RunScript(args[0]);
    }
}
