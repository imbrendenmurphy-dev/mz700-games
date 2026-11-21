// MZ700onPC visualiser: live panels (Z80, code, hot spots, frame budget, VRAM by line, opcodes, stack | memory map,
// beam and CPU, video, 8253 and speaker, keyboard and joysticks, I/O, tape and character generator) drawn into two
// 320x1080 bitmaps. Shared by the window (sidebars / visualiser window) and mzemu ("vis" command).
using System;
using System.Collections.Generic;
using System.IO;

public sealed class MzVis
{
    public const int W = 320, H = 1080;
    public readonly int[] Left = new int[W * H], Right = new int[W * H];
    readonly MzMachine m;
    public MzTrace T;
    public readonly Dictionary<int, string> Sym = new Dictionary<int, string>();
    public string SymFile;

    const int BG = 0x06080C, PANEL = 0x0A0E16, FRAME = 0x23345A, TBG = 0x121C34, TITLE = 0x58A8FF, TXT = 0xB8C8E0,
        DIM = 0x56627A, HI = 0xFFFFFF, AMBER = 0xFFB700, RED = 0xFF4848, CYAN = 0x41E0E0, MAG = 0xD060FF, BLUE = 0x5A84FF,
        GREEN = 0x40E040, ORANGE = 0xFF8A00, IDLEC = 0x14264A, WAITC = 0xE05A28;

    int[] buf;
    public MzVis(MzMachine machine) { m = machine; }

    // ================================================================ symbols
    /// <summary>Loads symbols for a program: NAME.sym next to the .MZT, or in ../build, ../out, .. (any case).
    /// Takes zasm "ADDR NAME" lines and sjasmplus "NAME: EQU 0xADDR" lines. If ../build has one .sym, that one.</summary>
    public void FindSymbols(string path)
    {
        Sym.Clear(); SymFile = null;
        if (path == null) return;
        string dir = Path.GetDirectoryName(Path.GetFullPath(path)), bn = Path.GetFileNameWithoutExtension(path);
        var dirs = new List<string> { dir };
        string par = Path.GetDirectoryName(dir);
        if (par != null) { dirs.Add(Path.Combine(par, "build")); dirs.Add(Path.Combine(par, "out")); dirs.Add(par); }
        foreach (var d in dirs)
        {
            string p = Path.Combine(d, bn + ".sym");
            if (File.Exists(p)) { LoadSymbols(p); return; }
        }
        if (par != null && Directory.Exists(Path.Combine(par, "build")))
        {
            var s = Directory.GetFiles(Path.Combine(par, "build"), "*.sym");
            if (s.Length == 1) LoadSymbols(s[0]);
        }
    }
    public void LoadSymbols(string path)
    {
        try
        {
            foreach (var line in File.ReadAllLines(path))
            {
                var p = line.Trim().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                if (p.Length < 2) continue;
                int a; string n;
                try
                {
                    if (p.Length >= 3 && p[1].ToUpperInvariant() == "EQU") { n = p[0].TrimEnd(':'); string v = p[2]; a = v.StartsWith("0x") ? Convert.ToInt32(v.Substring(2), 16) : v.EndsWith("h") ? Convert.ToInt32(v.TrimEnd('h'), 16) : int.Parse(v); }
                    else { a = Convert.ToInt32(p[0].TrimStart('$'), 16); n = p[1]; }
                }
                catch { continue; }
                n = n.ToUpperInvariant();
                if (n.StartsWith(".") || n.StartsWith("@") || n.Contains(".")) continue;
                // equates for constants are not code labels: keep values that look like addresses in RAM above 1000h
                if (a < 0x1000 || a > 0xFFFF) continue;
                if (!Sym.ContainsKey(a)) Sym[a] = n;
            }
            SymFile = path;
        }
        catch { }
    }
    string Label(int a)
    {
        string s; if (Sym.TryGetValue(a, out s)) return s;
        if (T != null && routine[a] && a >= 0x1000) return "SUB_" + a.ToString("X4");
        return null;
    }

    // ================================================================ drawing primitives
    void Fill(int x, int y, int w, int h, int c)
    {
        if (x < 0) { w += x; x = 0; } if (y < 0) { h += y; y = 0; }
        if (x + w > W) w = W - x; if (y + h > H) h = H - y;
        for (int j = 0; j < h; j++) { int o = (y + j) * W + x; for (int i = 0; i < w; i++) buf[o + i] = c; }
    }
    void Px(int x, int y, int c) { if ((uint)x < W && (uint)y < H) buf[y * W + x] = c; }
    void Rect(int x, int y, int w, int h, int c) { Fill(x, y, w, 1, c); Fill(x, y + h - 1, w, 1, c); Fill(x, y, 1, h, c); Fill(x + w - 1, y, 1, h, c); }

    static int Glyph(char ch)
    {
        if (ch >= 'a' && ch <= 'z') ch = (char)(ch - 32);
        if (ch >= '@' && ch <= '_') return ch - 64;
        if (ch >= ' ' && ch <= '?') return ch;
        return 63;
    }
    int Text(int x, int y, string s, int c)
    {
        foreach (char ch in s)
        {
            if (x > W - 6) break;
            if (ch == '_') { for (int i = 0; i < 5; i++) Px(x + i, y + 6, c); }
            else if (ch != ' ')
            {
                int g = Glyph(ch);
                for (int r = 0; r < 7; r++)
                {
                    int bits = Font6847.F[g, r];
                    if (bits == 0 || y + r >= H) continue;
                    int o = (y + r) * W + x;
                    for (int i = 0; i < 5; i++) if (((bits >> (4 - i)) & 1) != 0) buf[o + i] = c;
                }
            }
            x += 6;
        }
        return x;
    }
    int TextR(int xr, int y, string s, int c) { return Text(xr - s.Length * 6, y, s, c); }

    static int Lerp(int a, int b, double t)
    {
        if (t < 0) t = 0; if (t > 1) t = 1;
        int r = (int)(((a >> 16) & 255) + (((b >> 16) & 255) - ((a >> 16) & 255)) * t);
        int g = (int)(((a >> 8) & 255) + (((b >> 8) & 255) - ((a >> 8) & 255)) * t);
        int bl = (int)((a & 255) + ((b & 255) - (a & 255)) * t);
        return (r << 16) | (g << 8) | bl;
    }
    static int Heat(double t)
    {
        if (t <= 0) return 0x0C1018;
        if (t < 0.33) return Lerp(0x0C1A40, 0x2A70FF, t / 0.33);
        if (t < 0.66) return Lerp(0x2A70FF, 0x40F0FF, (t - 0.33) / 0.33);
        return Lerp(0x40F0FF, 0xFFFFFF, (t - 0.66) / 0.34);
    }

    int Panel(int y, int h, string title, string info)
    {
        Fill(0, y, W, h, PANEL);
        Rect(0, y, W, h, FRAME);
        Fill(1, y + 1, W - 2, 11, TBG);
        Text(5, y + 3, title, TITLE);
        if (info != null) TextR(W - 5, y + 3, info, DIM);
        return y + 15;
    }
    static string H2(int v) { return (v & 255).ToString("X2"); }
    static string H4(int v) { return (v & 0xFFFF).ToString("X4"); }
    static string Pct(double f) { return ((int)Math.Round(f * 100)) + "%"; }

    // ================================================================ render
    int[] prevRegs = new int[12];

    public void Render()
    {
        if (T == null) return;
        if (++routineScan % 25 == 1) UpdateRoutines();
        buf = Left; Fill(0, 0, W, H, BG);
        int y = 0;
        y = PRegs(y) + 6;
        y = PCode(y, 18) + 6;
        y = PHot(y, 7) + 6;
        y = PBudget(y) + 6;
        y = PVramLines(y) + 6;
        y = POps(y) + 6;
        PStack(y, H - y);

        buf = Right; Fill(0, 0, W, H, BG);
        y = 0;
        y = PMem(y) + 6;
        y = PBeam(y) + 6;
        y = PVideo(y) + 6;
        y = PSound(y) + 6;
        y = PKeys(y) + 6;
        PIo(y, H - y);
    }

    // ---------------------------------------------------------------- Z80 registers
    int PRegs(int y0)
    {
        var c = m.Cpu;
        int h = 15 + 6 * 11 + 4;
        int y = Panel(y0, h, "Z80 REGISTERS", "3.55 MHZ PAL");
        int[] v = { (c.A << 8) | c.F, (c.B << 8) | c.C, (c.D << 8) | c.E, (c.H << 8) | c.L,
                    (c.A_ << 8) | c.F_, (c.B_ << 8) | c.C_, (c.D_ << 8) | c.E_, (c.H_ << 8) | c.L_, c.IX, c.IY, c.SP, c.PC };
        string[] n = { "AF ", "BC ", "DE ", "HL ", "AF'", "BC'", "DE'", "HL'", "IX ", "IY ", "SP ", "PC " };
        for (int i = 0; i < 12; i++)
        {
            int x = 5 + (i % 4) * 78, yy = y + (i / 4) * 11;
            Text(x, yy, n[i], DIM);
            Text(x + 20, yy, H4(v[i]), v[i] != prevRegs[i] ? AMBER : TXT);
            prevRegs[i] = v[i];
        }
        int y3 = y + 33;
        int x3 = Text(5, y3, "I ", DIM); x3 = Text(x3, y3, H2(c.I), TXT);
        x3 = Text(x3 + 8, y3, "R ", DIM); x3 = Text(x3, y3, H2(c.R), TXT);
        x3 = Text(x3 + 8, y3, "IM ", DIM); x3 = Text(x3, y3, c.IM.ToString(), TXT);
        x3 = Text(x3 + 8, y3, "IFF ", DIM); x3 = Text(x3, y3, (c.IFF1 ? "1" : "0") + (c.IFF2 ? "1" : "0"), c.IFF1 ? GREEN : RED);
        x3 = Text(x3 + 8, y3, "INT ", DIM); x3 = Text(x3, y3, c.IntLine ? "LOW" : "HIGH", c.IntLine ? AMBER : TXT);
        x3 = Text(x3 + 8, y3, "INTS/F ", DIM); Text(x3, y3, T.Ints.ToString(), TXT);
        if (c.Halted) TextR(W - 5, y3, "HALT", AMBER);
        int y4 = y + 45;
        Text(5, y4 + 1, "FLAGS", DIM);
        string fl = "SZYHXPNC";
        for (int i = 0; i < 8; i++)
        {
            bool on = ((c.F >> (7 - i)) & 1) != 0;
            int x = 44 + i * 25;
            Fill(x, y4 - 1, 21, 10, on ? 0x2A70FF : 0x121A2C);
            Text(x + 8, y4 + 1, fl[i].ToString(), on ? HI : DIM);
        }
        int y5 = y + 57;
        int x5 = Text(5, y5, "T ", DIM); x5 = Text(x5, y5, c.Cyc.ToString(), TXT);
        x5 = Text(x5 + 12, y5, "FIELD ", DIM); Text(x5, y5, m.Frames.ToString(), TXT);
        return y0 + h;
    }

    // ---------------------------------------------------------------- code
    int PCode(int y0, int lines)
    {
        int h = 15 + lines * 9 + 4;
        int y = Panel(y0, h, "CODE", "SAMPLED WHILE BUSY");
        int pc = T.ShownPc >= 0 ? T.ShownPc : m.Cpu.PC;
        int start = pc, back = 0;
        for (int a = pc - 1; a >= pc - 60 && back < 9; a--) if (a >= 0 && T.Start[a]) { start = a; back++; }
        Func<int, int> rd = m.Peek;
        int ad = start, ln = 0;
        while (ln < lines)
        {
            string lab = Label(ad);
            if (lab != null) { Text(5, y + ln * 9, lab + ":", AMBER); ln++; if (ln >= lines) break; }
            int len;
            string s = Z80Dis.Dis(rd, ad, out len, Label);
            int yy = y + ln * 9;
            bool isPc = ad == pc;
            if (isPc) Fill(2, yy - 1, W - 4, 9, 0x1E2E58);
            int hx = T.HX[ad];
            int col = isPc ? HI : hx > 0 ? Lerp(DIM, TXT, hx / 255.0) : DIM;
            if (ad == m.Cpu.PC) Text(5, yy, ">", RED);
            Text(12, yy, H4(ad), isPc ? HI : DIM);
            string bytes = "";
            for (int i = 0; i < len && i < 4; i++) bytes += H2(rd((ad + i) & 0xFFFF));
            Text(42, yy, bytes, isPc ? TXT : 0x3C4A68);
            Text(96, yy, s, col);
            ad = (ad + Math.Max(1, len)) & 0xFFFF; ln++;
        }
        return y0 + h;
    }

    // ---------------------------------------------------------------- hot spots
    readonly bool[] routine = new bool[65536];
    int routineScan;
    void UpdateRoutines()
    {
        int last = -100;
        for (int a = 0; a < 65536; a++)
        {
            routine[a] = false;
            if (!T.CallTarget[a]) continue;
            if (a - last >= 16 || Sym.ContainsKey(a)) routine[a] = true;
            last = a;
        }
    }
    int hotVersion = -1; List<KeyValuePair<string, long>> hot = new List<KeyValuePair<string, long>>();
    void BuildHot()
    {
        hotVersion = T.ProfVersion; hot.Clear();
        var starts = new List<int>();
        foreach (var k in Sym.Keys) starts.Add(k);
        UpdateRoutines();
        for (int a = 0x1000; a < 65536; a++) if (routine[a] && !Sym.ContainsKey(a)) starts.Add(a);
        starts.Sort();
        var sums = new Dictionary<string, long>();
        for (int a = 0; a < 65536; a++)
        {
            long t = T.ProfShown[a]; if (t == 0) continue;
            string name;
            if (a < 0x1000 && m.RomIn) name = a >= 0x38 && a < 0x40 ? "MONITOR ISR" : "MONITOR $" + H4(a & 0xFF00);
            else
            {
                int i = starts.BinarySearch(a); if (i < 0) i = ~i - 1;
                if (i >= 0 && a - starts[i] < 0x1000) { int s = starts[i]; string sn; name = Sym.TryGetValue(s, out sn) ? sn : "SUB_" + H4(s); }
                else name = "$" + H4(a & 0xFF00) + " BLOCK";
            }
            long o; sums.TryGetValue(name, out o); sums[name] = o + t;
        }
        foreach (var kv in sums) hot.Add(kv);
        hot.Sort((p, q) => q.Value.CompareTo(p.Value));
    }
    int PHot(int y0, int lines)
    {
        if (hotVersion != T.ProfVersion) BuildHot();
        int h = 15 + lines * 11 + 2;
        int y = Panel(y0, h, "HOT SPOTS", Sym.Count > 0 ? "CPU TIME, SYMBOLS" : "CPU TIME, LAST SECOND");
        long tot = Math.Max(1, T.ProfShownT);
        for (int i = 0; i < lines && i < hot.Count; i++)
        {
            int yy = y + i * 11;
            double f = (double)hot[i].Value / tot;
            string nm = hot[i].Key; if (nm.Length > 17) nm = nm.Substring(0, 17);
            Text(5, yy, nm, i == 0 ? HI : TXT);
            TextR(146, yy, (f * 100).ToString(f < 0.1 ? "0.0" : "0") + "%", AMBER);
            Fill(150, yy - 1, 166, 9, 0x0E1424);
            Fill(150, yy - 1, Math.Max(1, (int)(f * 166)), 9, Heat(0.25 + f * 0.75));
        }
        if (hot.Count == 0) Text(5, y, "COLLECTING...", DIM);
        return y0 + h;
    }

    // ---------------------------------------------------------------- frame budget
    int PBudget(int y0)
    {
        int h = 15 + 12 + 4 + 10 + 50 + 4;
        int y = Panel(y0, h, "FRAME BUDGET", "50 HZ FIELD = 70886 T");
        int x = 5, bw = W - 10;
        int wb = (int)(T.Busy * bw), wi = (int)(T.Isr * bw), ww = (int)(T.VWait * bw), wt = (int)(T.TapeF * bw);
        Fill(x, y, bw, 12, IDLEC);
        Fill(x, y, wb, 12, GREEN); Fill(x + wb, y, wi, 12, MAG); Fill(x + wb + wi, y, ww, 12, WAITC); Fill(x + wb + wi + ww, y, wt, 12, ORANGE);
        Text(x + 4, y + 3, Pct(T.Busy + T.Isr + T.VWait + T.TapeF) + " USED", 0x002000);
        int yt = y + 16;
        int xt = Text(5, yt, "BUSY ", GREEN); xt = Text(xt, yt, Pct(T.Busy), TXT);
        xt = Text(xt + 8, yt, "ISR ", MAG); xt = Text(xt, yt, Pct(T.Isr), TXT);
        xt = Text(xt + 8, yt, "VRAM WAIT ", WAITC); xt = Text(xt, yt, Pct(T.VWait), TXT);
        xt = Text(xt + 8, yt, "IDLE ", BLUE); Text(xt, yt, Pct(T.Idle), TXT);
        int gy = yt + 12, gh = 48;
        Fill(5, gy, 300, gh, 0x080C14);
        for (int i = 0; i < MzTrace.HIST; i++)
        {
            int k = (T.HPos + i) % MzTrace.HIST;
            int b = T.HBusy[k] * gh / 100, s = T.HIsr[k] * gh / 100, w = T.HWait[k] * gh / 100, d = T.HTape[k] * gh / 100;
            int yb = gy + gh;
            Fill(5 + i, yb - b, 1, b, 0x28A028); yb -= b;
            Fill(5 + i, yb - s, 1, s, MAG); yb -= s;
            Fill(5 + i, yb - w, 1, w, WAITC); yb -= w;
            Fill(5 + i, yb - d, 1, d, ORANGE);
        }
        Fill(5, gy + gh / 2, 300, 1, 0x1A2438);
        TextR(W - 4, gy, "100", DIM); TextR(W - 4, gy + gh - 8, "0", DIM);
        return y0 + h;
    }

    // ---------------------------------------------------------------- VRAM accesses by line
    int PVramLines(int y0)
    {
        int rh = 156;
        int h = 15 + rh + 24;
        int y = Panel(y0, h, "VRAM BY LINE", m.VramWait == VramWaitMode.Off ? "WAITS OFF" : "FREE T " + m.WaitW0 + "-" + m.WaitW1);
        int bx = 30, bw = W - bx - 6;
        Fill(bx, y, bw, rh, 0x080C14);
        int max = 8;
        for (int l = 0; l < MzTrace.LINES; l++) max = Math.Max(max, T.LineVW[l] + T.LineVR[l]);
        for (int r = 0; r < rh; r++)
        {
            int l0 = r * 2, l1 = l0 + 1;
            int wv = T.LineVW[l0] + T.LineVW[l1], rv = T.LineVR[l0] + T.LineVR[l1], cv = T.LineCont[l0] + T.LineCont[l1];
            int ww = wv * bw / (2 * max), rw = rv * bw / (2 * max), cw = cv * bw / (2 * max);
            bool vb = l0 >= MzMachine.VIS;
            Fill(bx - 6, y + r, 4, 1, vb ? 0x302410 : 0x1A3A20);
            Fill(bx, y + r, ww, 1, HI); Fill(bx + ww, y + r, rw, 1, CYAN);
            if (cw > 0) Fill(bx, y + r, cw, 1, RED);
        }
        Fill(bx, y + MzMachine.VIS / 2, bw, 1, 0x806020);
        Text(2, y, "0", DIM); Text(2, y + MzMachine.VIS / 2 - 8, "199", DIM); Text(2, y + MzMachine.VIS / 2 + 2, "VBL", 0xC09040); Text(2, y + rh - 8, "311", DIM);
        int ly = y + rh + 3;
        int x = Text(5, ly, "WRITES ", HI); x = Text(x, ly, T.VramW.ToString(), TXT);
        x = Text(x + 8, ly, "READS ", CYAN); x = Text(x, ly, T.VramR.ToString(), TXT);
        x = Text(x + 8, ly, "OUTSIDE WINDOW ", RED); Text(x, ly, T.Contended.ToString(), T.Contended > 0 ? AMBER : TXT);
        ly += 10;
        x = Text(5, ly, "WAIT THIS FIELD ", WAITC); x = Text(x, ly, T.WaitShown + " T", TXT);
        Text(x + 8, ly, "(" + (T.WaitShown * 100 / 70886) + "% OF THE FIELD)", DIM);
        return y0 + h;
    }

    // ---------------------------------------------------------------- opcode heatmap
    int POps(int y0)
    {
        int cw = 18, ch = 9;
        int h = 15 + 9 + 16 * ch + 4 + 20;
        int y = Panel(y0, h, "OPCODES", "FIRST BYTE, LAST SECOND");
        int gx = 17;
        for (int i = 0; i < 16; i++) Text(gx + i * cw + 6, y, i.ToString("X"), DIM);
        y += 9;
        long n = Math.Max(1, T.OpsShownN);
        int max = 1; for (int i = 0; i < 256; i++) if (T.OpsShown[i] > max) max = T.OpsShown[i];
        double lmax = Math.Log(1 + max);
        for (int r = 0; r < 16; r++)
        {
            Text(5, y + r * ch + 1, r.ToString("X"), DIM);
            for (int col = 0; col < 16; col++)
            {
                int cnt = T.OpsShown[r * 16 + col];
                Fill(gx + col * cw, y + r * ch, cw - 1, ch - 1, cnt == 0 ? 0x0C1018 : Heat(Math.Log(1 + cnt) / lmax));
            }
        }
        var idx = new List<int>(); for (int i = 0; i < 256; i++) if (T.OpsShown[i] > 0) idx.Add(i);
        idx.Sort((a, b) => T.OpsShown[b].CompareTo(T.OpsShown[a]));
        int ty = y + 16 * ch + 3;
        for (int i = 0; i < 4 && i < idx.Count; i++)
        {
            int op = idx[i]; int len;
            byte[] fake = { (byte)op, 0, 0, 0 };
            string s = op == 0xCB ? "CB PREFIX" : op == 0xED ? "ED PREFIX" : op == 0xDD ? "IX PREFIX" : op == 0xFD ? "IY PREFIX"
                : Z80Dis.Dis(a => fake[a & 3], 0, out len, null, true);
            string line = ((int)Math.Round(100.0 * T.OpsShown[op] / n)) + "% " + s;
            if (line.Length > 25) line = line.Substring(0, 25);
            Text(5 + (i % 2) * 156, ty + (i / 2) * 10, line, i == 0 ? HI : TXT);
        }
        return y0 + h;
    }

    // ---------------------------------------------------------------- stack
    int PStack(int y0, int avail)
    {
        int h = Math.Min(avail, 15 + 10 + 38 + 4 + 10 + 8 * 10 + 4);
        int y = Panel(y0, h, "STACK", null);
        int sp = m.Cpu.SP;
        int x = Text(5, y, "SP ", DIM); x = Text(x, y, H4(sp), TXT);
        x = Text(x + 12, y, "LOWEST THIS SECOND ", DIM); Text(x, y, T.SpMinSecond == 0xFFFF ? "----" : H4(T.SpMinSecond), AMBER);
        int gy = y + 11, gh = 36;
        Fill(5, gy, 300, gh, 0x080C14);
        int lo = 0xFFFF, hi = 0;
        for (int i = 0; i < MzTrace.HIST; i++) { int v = T.HSp[i]; if (v == 0xFFFF || v == 0) continue; if (v < lo) lo = v; if (v > hi) hi = v; }
        if (hi >= lo)
        {
            hi = Math.Max(hi, lo + 16);
            for (int i = 0; i < MzTrace.HIST; i++)
            {
                int v = T.HSp[(T.HPos + i) % MzTrace.HIST]; if (v == 0xFFFF || v == 0) continue;
                int py = gy + (int)((long)(v - lo) * (gh - 2) / (hi - lo));
                Fill(5 + i, py, 1, gy + gh - py, 0x1C3060); Px(5 + i, py, CYAN);
            }
            TextR(W - 4, gy, H4(lo), DIM); TextR(W - 4, gy + gh - 8, H4(hi), DIM);
        }
        int ly = gy + gh + 4;
        Text(5, ly, "RETURN ADDRESSES ON THE STACK", DIM); ly += 10;
        int shown = 0;
        for (int k = 0; k < 24 && shown < 8 && ly + 9 < y0 + h; k++)
        {
            int a = (sp + k * 2) & 0xFFFF;
            if (a >= T.SpMaxSecond + 2 || a < sp) break;
            int w = m.Peek(a) | (m.Peek((a + 1) & 0xFFFF) << 8);
            int b3 = m.Peek((w - 3) & 0xFFFF), b1 = m.Peek((w - 1) & 0xFFFF);
            bool call = b3 == 0xCD || (b3 & 0xC7) == 0xC4;
            bool rst = (b1 & 0xC7) == 0xC7 && b1 != 0xFF;
            if (!call && !rst) continue;
            string from;
            if (call) { int tgt = m.Peek((w - 2) & 0xFFFF) | (m.Peek((w - 1) & 0xFFFF) << 8); from = "CALL " + (Label(tgt) ?? "$" + H4(tgt)); }
            else from = "RST $" + H2(b1 & 0x38);
            int xx = Text(5, ly, H4(a), DIM); xx = Text(xx + 6, ly, H4(w), TXT);
            Text(xx + 8, ly, "FROM " + from, shown == 0 ? AMBER : TXT);
            ly += 10; shown++;
        }
        if (shown == 0) Text(5, ly, "(NONE)", DIM);
        return y0 + h;
    }

    // ================================================================ right column
    int PMem(int y0)
    {
        int h = 15 + 256 + 4 + 10 + 2;
        int y = Panel(y0, h, "MEMORY MAP", "64K, 1 PIXEL = 1 BYTE");
        int mx = 4;
        for (int a = 0; a < 65536; a++)
        {
            int tr, tg, tb;
            if (a < 0x1000) { if (m.RomIn) { tr = 14; tg = 16; tb = 40; } else { tr = 8; tg = 10; tb = 16; } }
            else if (a < 0xD000 || !m.IoIn) { tr = 8; tg = 10; tb = 16; }
            else if (a < 0xE000) { tr = 0; tg = 30; tb = 26; }
            else if (a < 0xE800) { tr = 34; tg = 26; tb = 0; }
            else { tr = 4; tg = 4; tb = 4; }
            int v = m.Peek(a);
            int lum = (a >= 0xE000 && m.IoIn && a < 0x10000 && a >= 0xE000) ? 0 : (v >> 3);
            int r = tr + lum, g = tg + lum, b = tb + lum;
            int hr = T.HR[a], hw = T.HW[a], hx = T.HX[a];
            if (hw > r) r = hw;
            if (hw / 3 > g) g = hw / 3;
            if (hr * 7 / 8 > g) g = hr * 7 / 8;
            if (hx > b) b = hx;
            if (hx / 2 > g) g = Math.Max(g, hx / 2);
            if (hx / 4 > r) r = Math.Max(r, hx / 4);
            buf[(y + (a >> 8)) * W + mx + (a & 255)] = (Math.Min(255, r) << 16) | (Math.Min(255, g) << 8) | Math.Min(255, b);
        }
        int pc = m.Cpu.PC, sp = m.Cpu.SP;
        Fill(mx + 257, y + (pc >> 8), 5, 1, HI);
        Fill(mx + 257, y + (sp >> 8), 5, 1, AMBER);
        for (int d = -2; d <= 2; d++) { Px(mx + (pc & 255) + d, y + (pc >> 8), HI); Px(mx + (pc & 255), y + (pc >> 8) + d, HI); }
        int lx = mx + 264;
        LabelAt(lx, y, 0x0000, m.RomIn ? "MON" : "RAM", m.RomIn ? 0x8090D0 : TXT, 0x1000);
        LabelAt(lx, y, 0x1000, "RAM", TXT, 0xD000);
        if (m.IoIn && !m.Inhibit)
        {
            LabelAt(lx, y, 0xD000, m.Pcg == PcgType.Mz1500 && m.PcgMap >= 0 ? "PCG" : "VRAM", GREEN, 0xD800);
            LabelAt(lx, y, 0xD800, "ATTR", GREEN, 0xE000);
            LabelAt(lx, y, 0xE000, "I/O", AMBER, 0xE800);
            LabelAt(lx, y, 0xE800, "----", DIM, 0x10000);
        }
        else LabelAt(lx, y, 0xD000, m.Inhibit ? "LOCK" : "RAM", m.Inhibit ? RED : TXT, 0x10000);
        int ly = y + 256 + 4;
        int x = Text(5, ly, "READ", GREEN); x = Text(x + 10, ly, "WRITE", RED); x = Text(x + 10, ly, "EXECUTE", BLUE);
        x = Text(x + 14, ly, "PC", HI); Text(x + 10, ly, "SP", AMBER);
        return y0 + h;
    }
    void LabelAt(int x, int y, int addr, string name, int c, int next)
    {
        int yy = y + (addr >> 8);
        Fill(x - 4, yy, 3, 1, c);
        Text(x, yy + 1, name, c);
        if (((next - addr) >> 8) >= 18) Text(x, yy + 10, H4(addr), DIM);
    }

    // ---------------------------------------------------------------- beam / CPU timing
    static readonly int[] stCol = { 0x0A0C14, 0x1E8A2A, IDLEC, 0x9A3CC8, 0xC86A00, WAITC };
    static readonly int[] ovCol = { 0, CYAN, HI, RED, AMBER, 0xE0E060, 0x808080, 0x60A0FF, 0xFF60C0 };
    static readonly int[] stPri = { 0, 2, 1, 4, 3, 5 };

    int PBeam(int y0)
    {
        int rh = MzTrace.LINES / 2;
        int h = 15 + rh + 4 + 20;
        int y = Panel(y0, h, "BEAM AND CPU", "228 T X 312 LINES");
        int bx = 4;
        var ras = T.Ras; var ov = T.Ov;
        for (int r = 0; r < rh; r++)
        {
            int o = (y + r) * W + bx;
            for (int t = 0; t < MzTrace.LT; t++)
            {
                // T slot of line l at tick t: (l * 1136 / 5) + t
                int i0 = (int)((r * 2L * MzMachine.LINE_M) / 5) + t, i1 = (int)(((r * 2L + 1) * MzMachine.LINE_M) / 5) + t;
                if (i1 >= MzTrace.FT) i1 = MzTrace.FT - 1; if (i0 >= MzTrace.FT) i0 = MzTrace.FT - 1;
                int ovv = ov[i0] != 0 ? ov[i0] : ov[i1];
                if (ov[i0] == MzTrace.O_VW || ov[i1] == MzTrace.O_VW) ovv = MzTrace.O_VW;
                if (ovv != 0) { buf[o + t] = ovCol[ovv]; continue; }
                int s = stPri[ras[i0]] >= stPri[ras[i1]] ? ras[i0] : ras[i1];
                buf[o + t] = stCol[s];
            }
        }
        int p1 = MzMachine.VIS / 2;
        for (int t = 0; t < MzTrace.LT; t += 2) Px(bx + t, y + p1, 0xA08040);
        for (int r = 0; r < rh; r += 2) { Px(bx + 128, y + r, 0x50A060); Px(bx + m.WaitW0, y + r + 1, 0x406090); Px(bx + m.WaitW1, y + r + 1, 0x406090); }
        int lx = bx + MzTrace.LT + 6;
        Text(lx, y, "0 PIC", 0x70C080); Text(lx, y + p1 + 1, "200", DIM); Text(lx, y + p1 + 10, "VBLANK", 0xC09040); Text(lx, y + rh - 8, "311", DIM);
        Text(lx, y + 40, "T 128", DIM); Text(lx, y + 49, "HBLANK", DIM);
        int ly = y + rh + 4;
        int x = Text(5, ly, "BUSY", 0x30C040); x = Text(x + 8, ly, "ISR", MAG); x = Text(x + 8, ly, "VRAM WAIT", WAITC);
        x = Text(x + 8, ly, "IDLE", BLUE); x = Text(x + 8, ly, "TAPE", ORANGE); Text(x + 8, ly, "KEYS", 0x808080);
        ly += 10;
        x = Text(5, ly, "VRAM WRITE", HI); x = Text(x + 8, ly, "READ", CYAN); x = Text(x + 8, ly, "SOUND", RED);
        x = Text(x + 8, ly, "8253", 0x60A0FF); x = Text(x + 8, ly, "JOY", 0xFF60C0); Text(x + 8, ly, "OUT", AMBER);
        return y0 + h;
    }

    // ---------------------------------------------------------------- video
    int PVideo(int y0)
    {
        int h = 15 + 4 * 10 + 2;
        string pcg = m.Pcg == PcgType.Pcg700 ? "PCG-700" : m.Pcg == PcgType.Mz1500 ? "MZ-1500 PCG" : "CG-ROM ONLY";
        int y = Panel(y0, h, "VIDEO  40 X 25 COLOUR TEXT", pcg);
        // colours and character sets in use
        int[] fgUse = new int[8], bgUse = new int[8]; int set1 = 0, hiCodes = 0;
        for (int i = 0; i < 1000; i++) { int at = m.Vram[0x800 + i]; fgUse[(at >> 4) & 7]++; bgUse[at & 7]++; if ((at & 0x80) != 0) set1++; if (m.Vram[i] >= 0x80) hiCodes++; }
        int x = Text(5, y, "FG ", DIM);
        for (int c = 0; c < 8; c++) { Fill(x + c * 14, y - 1, 12, 8, MzMachine.Rgb[c]); if (fgUse[c] > 0) Fill(x + c * 14, y + 8, 12, 1, HI); }
        x = Text(x + 8 * 14 + 8, y, "BG ", DIM);
        for (int c = 0; c < 8; c++) { Fill(x + c * 14, y - 1, 12, 8, MzMachine.Rgb[c]); if (bgUse[c] > 0) Fill(x + c * 14, y + 8, 12, 1, HI); }
        int y2 = y + 11;
        x = Text(5, y2, "CHAR SET 2 CELLS ", DIM); x = Text(x, y2, set1.ToString(), TXT);
        x = Text(x + 8, y2, "CODES 80-FF ", DIM); x = Text(x, y2, hiCodes.ToString(), TXT);
        Text(x + 8, y2, m.FontName.ToUpperInvariant(), DIM);
        int y3 = y2 + 10;
        if (m.Pcg == PcgType.Pcg700)
        {
            x = Text(5, y3, "PCG-700 ", DIM); x = Text(x, y3, m.Pcg700On ? "ON" : "OFF", m.Pcg700On ? GREEN : DIM);
            x = Text(x + 8, y3, "CTRL $" + H2(m.PcgCtrl) + " ADDR $" + H2(m.PcgAddr) + " DATA $" + H2(m.PcgData), TXT);
            Text(x + 8, y3, "WRITES " + m.PcgWrites, DIM);
        }
        else if (m.Pcg == PcgType.Mz1500)
        {
            x = Text(5, y3, "PCG ", DIM); x = Text(x, y3, (m.PcgPriority & 1) != 0 ? "ON" : "OFF", (m.PcgPriority & 1) != 0 ? GREEN : DIM);
            x = Text(x + 8, y3, (m.PcgPriority & 2) != 0 ? "OVER TEXT" : "UNDER TEXT FG", TXT);
            x = Text(x + 8, y3, "MAP " + (m.PcgMap < 0 ? "-" : m.PcgMap == 0 ? "CG" : "BRG"[m.PcgMap - 1].ToString()), TXT);
            Text(x + 8, y3, "CELLS " + m.PcgCells, DIM);
        }
        else Text(5, y3, "NO PCG FITTED", DIM);
        int y4 = y3 + 10;
        x = Text(5, y4, "BANKS ", DIM); x = Text(x, y4, (m.RomIn ? "MONITOR" : "RAM") + " / " + (m.Inhibit ? "LOCKED" : m.IoIn ? "VRAM+IO" : "RAM"), TXT);
        x = Text(x + 8, y4, "WAITS ", DIM); Text(x, y4, m.VramWait == VramWaitMode.Off ? "OFF" : m.VramWait == VramWaitMode.All ? "ALL LINES" : "DISPLAY ONLY", TXT);
        return y0 + h;
    }

    // ---------------------------------------------------------------- 8253 + speaker
    readonly double[] fre = new double[1024], fim = new double[1024];
    readonly double[] spec = new double[512];
    static readonly string[] notes = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };
    static string Note(double hz)
    {
        if (hz < 20 || hz > 20000) return "";
        double n = 12 * Math.Log(hz / 440.0, 2) + 57;
        int k = (int)Math.Round(n);
        return notes[((k % 12) + 12) % 12] + (k / 12);
    }

    int PSound(int y0)
    {
        int h = 15 + 3 * 10 + 4 + 40 + 4 + 36 + 4 + 10 + 2;
        int y = Panel(y0, h, "8253 AND SPEAKER", m.SoundGate ? "GATE ON" : "GATE OFF");
        string[] clk = { "1.108 MHZ", "HSYNC", "OUT1" };
        for (int i = 0; i < 3; i++)
        {
            var p = m.Pit[i]; int yy = y + i * 10;
            int x = Text(5, yy, "C" + i, AMBER);
            x = Text(x + 6, yy, "M" + p.Mode + " " + p.ModeName, TXT);
            x = Text(Math.Max(x + 6, 100), yy, "N " + p.Reload, TXT);
            x = Text(Math.Max(x + 6, 160), yy, "CNT " + p.Count.ToString("X4"), DIM);
            Fill(Math.Max(x + 6, 226), yy - 1, 7, 8, p.Out ? GREEN : 0x1A2A1A);
            string extra = i == 0 && p.Mode == 3 && p.Counting ? ((int)(1108405.0 / p.Reload)) + "HZ " + Note(1108405.0 / p.Reload) : i == 1 ? "" : i == 2 ? ((m.PortC & 4) != 0 ? "INT EN" : "INT OFF") : clk[i];
            TextR(W - 4, yy, extra, i == 0 ? HI : DIM);
        }
        y += 34;
        int sx = 5, sw = 300, shh = 40;
        Fill(sx, y, sw, shh, 0x080C14);
        Fill(sx, y + shh / 2, sw, 1, 0x16203A);
        var s = T.SpkShown; int n = Math.Max(1, T.SpkShownN);
        for (int col = 0; col < sw; col++)
        {
            int a = col * n / sw, b = Math.Max(a + 1, (col + 1) * n / sw);
            float lo = 1, hi = -1;
            for (int i = a; i < b && i < n; i++) { if (s[i] < lo) lo = s[i]; if (s[i] > hi) hi = s[i]; }
            if (hi < lo) continue;
            int ylo = y + shh / 2 - (int)(hi * (shh / 2 - 3)), yhi = y + shh / 2 - (int)(lo * (shh / 2 - 3));
            Fill(sx + col, ylo, 1, yhi - ylo + 1, hi - lo > 0.05 ? 0x60C0FF : 0x3070C0);
        }
        int rp = T.SpkRingPos;
        for (int i = 0; i < 1024; i++) { double wv = 0.5 - 0.5 * Math.Cos(2 * Math.PI * i / 1023); fre[i] = T.SpkRing[(rp - 1024 + i) & 2047] * wv; fim[i] = 0; }
        double mean = 0; for (int i = 0; i < 1024; i++) mean += fre[i]; mean /= 1024;
        for (int i = 0; i < 1024; i++) fre[i] -= mean * (0.5 - 0.5 * Math.Cos(2 * Math.PI * i / 1023));
        Fft(fre, fim);
        double rate = MzMachine.RATE;
        int maxBin = (int)(6000 / (rate / 1024)); if (maxBin > 511) maxBin = 511;
        int peak = 0; double pv = 0;
        for (int i = 1; i <= maxBin; i++) { spec[i] = Math.Sqrt(fre[i] * fre[i] + fim[i] * fim[i]); if (spec[i] > pv) { pv = spec[i]; peak = i; } }
        int gy = y + shh + 4, gh = 36;
        Fill(sx, gy, sw, gh, 0x080C14);
        for (int col = 0; col < sw; col++)
        {
            int bin = 1 + col * maxBin / sw;
            double v = spec[bin];
            int bh = v <= 0 ? 0 : (int)Math.Min(gh, Math.Max(0, Math.Log10(1 + v * 4) * 18));
            Fill(sx + col, gy + gh - bh, 1, bh, Heat(0.3 + 0.7 * bh / gh));
        }
        TextR(sx + sw, gy, "6 KHZ", DIM); Text(sx + 2, gy, "0", DIM);
        int ty = gy + gh + 4;
        int xs = Text(5, ty, "SOUND WRITES/FIELD ", DIM); xs = Text(xs, ty, T.SoundWrites.ToString(), TXT);
        if (pv > 2) { xs = Text(xs + 12, ty, "PEAK ", DIM); double hz = peak * rate / 1024; Text(xs, ty, ((int)hz) + " HZ " + Note(hz), AMBER); }
        else Text(xs + 12, ty, "SILENT", DIM);
        return y0 + h;
    }

    static void Fft(double[] re, double[] im)
    {
        int n = re.Length;
        for (int i = 1, j = 0; i < n; i++)
        {
            int bit = n >> 1;
            for (; (j & bit) != 0; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j) { double t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
        }
        for (int len = 2; len <= n; len <<= 1)
        {
            double ang = -2 * Math.PI / len, wr = Math.Cos(ang), wi = Math.Sin(ang);
            for (int i = 0; i < n; i += len)
            {
                double cr = 1, ci = 0;
                for (int k = 0; k < len / 2; k++)
                {
                    int a = i + k, b = a + len / 2;
                    double xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr;
                    re[b] = re[a] - xr; im[b] = im[a] - xi; re[a] += xr; im[a] += xi;
                    double t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
                }
            }
        }
    }

    // ---------------------------------------------------------------- keyboard + joysticks
    int PKeys(int y0)
    {
        int h = 15 + 10 * 10 + 2;
        int y = Panel(y0, h, "KEYBOARD MATRIX", m.Joystick == JoyType.Mz1x03 ? "MZ-1X03 JOYSTICKS" : "NO JOYSTICKS");
        for (int r = 0; r < 10; r++)
        {
            int yy = y + r * 10;
            int sc = T.RowScan[r];
            Fill(4, yy - 1, 15, 9, Lerp(0x0E1424, 0x2A70FF, sc / 255.0));
            Text(6, yy, r.ToString(), sc > 128 ? HI : DIM);
            for (int b = 0; b < 8; b++)
            {
                string k = MzMachine.KROWS[r, 7 - b];
                int x = 22 + b * 25;
                if (k.Length == 0) continue;
                bool down = (m.Keys[r] & (1 << (7 - b))) == 0;
                string lab = k.Length > 4 ? (k == "SPACE" ? "SPC" : k == "SHIFT" ? "SHF" : k == "BREAK" ? "BRK" : k == "ALPHA" ? "ALP" : k == "GRAPH" ? "GRP" : k == "RIGHT" ? "RGT" : k == "LEFT" ? "LFT" : k.Substring(0, 4)) : k == "LEFT" ? "LFT" : k == "DOWN" ? "DWN" : k == "INST" ? "INS" : k;
                Fill(x, yy - 1, 23, 9, down ? AMBER : 0x121A2C);
                Text(x + (23 - lab.Length * 6) / 2 + 1, yy, lab, down ? 0x201000 : TXT);
            }
        }
        for (int j = 0; j < 2; j++)
        {
            int jx = 228 + j * 46, jy = y + 4, sz = 36;
            Text(jx + 12, jy, "J" + (j + 1), DIM);
            Fill(jx, jy + 10, sz, sz, 0x0E1424); Rect(jx, jy + 10, sz, sz, 0x2A3A5A);
            int px = jx + sz / 2 + (int)(m.JoyX[j] * (sz / 2 - 3)), py = jy + 10 + sz / 2 + (int)(m.JoyY[j] * (sz / 2 - 3));
            Fill(px - 2, py - 2, 5, 5, m.JoyX[j] != 0 || m.JoyY[j] != 0 ? AMBER : DIM);
            Fill(jx + 2, jy + 50, 15, 9, m.JoyA[j] ? RED : 0x301414); Text(jx + 4, jy + 51, "A", m.JoyA[j] ? HI : DIM);
            Fill(jx + 20, jy + 50, 15, 9, m.JoyB[j] ? RED : 0x301414); Text(jx + 22, jy + 51, "B", m.JoyB[j] ? HI : DIM);
        }
        Text(228, y + 70, "E008 READS", DIM); Text(228, y + 80, T.JoyReads + "/FIELD", TXT);
        return y0 + h;
    }

    // ---------------------------------------------------------------- I/O, tape and the character generator
    static readonly string[] ioName = { "E000 8255 PA", "E001 8255 PB", "E002 8255 PC", "E003 8255 CTL", "E004 8253 C0", "E005 8253 C1", "E006 8253 C2", "E007 8253 CTL", "E008 TEMPO/JOY" };

    int PIo(int y0, int avail)
    {
        int h = Math.Min(avail, 230);
        string title = m.Pcg == PcgType.None ? "I/O, TAPE, CG-ROM" : "I/O, TAPE, PCG";
        int y = Panel(y0, h, title, null);
        int ly = y;
        for (int i = 0; i < 9; i++)
        {
            int r = T.IoR[i], w = T.IoW[i];
            Fill(5, ly - 1, 5, 7, (Math.Min(255, w + 20) << 16) | (Math.Min(255, r + 20) << 8) | 0x20);
            Text(13, ly, ioName[i], r > 0 || w > 0 ? TXT : DIM);
            Text(97, ly, w > 0 ? H2(T.IoValW[i]) : r > 0 ? H2(T.IoValR[i]) : "", w > 0 ? RED : GREEN);
            Text(115, ly, (T.IoCountShown[i] + T.IoCountShown[19 + i]).ToString(), DIM);
            ly += 9;
        }
        // Z80 ports
        ly += 2;
        int px = 5;
        for (int k = 0; k < T.Recent.Count && k < 5; k++)
        {
            int key = T.Recent[k]; bool isOut = key >= 256; int p = key & 255;
            int x = Text(px, ly, (isOut ? "OUT " : "IN  ") + H2(p) + "=" + H2(isOut ? T.PValOut[p] : T.PValIn[p]), isOut ? RED : GREEN);
            Text(x + 4, ly, PortName(p), DIM);
            ly += 9;
        }
        if (T.Recent.Count == 0) { Text(px, ly, "NO Z80 PORT I/O", DIM); ly += 9; }
        // tape
        ly = y0 + h - 34;
        var c = m.Cass;
        Fill(5, ly - 1, 7, 7, c.Motor ? Lerp(0x402000, ORANGE, Math.Max(0.4, T.TapeLed / 255.0)) : T.TapeLed > 0 ? ORANGE : 0x302010);
        string nm = c.HasTape ? c.Name.ToUpperInvariant() : "NO TAPE"; if (nm.Length > 22) nm = nm.Substring(0, 22);
        Text(16, ly, "TAPE " + nm, c.HasTape ? TXT : DIM);
        ly += 9;
        Text(5, ly, c.HasTape ? string.Format("{0}  {1:F1}/{2:F0} S  {3}", c.Motor ? "MOTOR ON" : c.PlayPressed ? "PLAY" : "STOP", c.Seconds, c.Length, m.FastTape ? "FAST" : "REAL SPEED") : m.FastTape ? "FAST LOADING ON" : "REAL-SPEED LOADING", DIM);
        ly += 9;
        if (m.TapeOut.Recording) Text(5, ly, "RECORDING " + m.TapeOut.Edges + " EDGES", RED);
        else if (m.TapeLog.Count > 0) { string l = m.TapeLog[m.TapeLog.Count - 1]; if (l.Length > 26) l = l.Substring(0, 26); Text(5, ly, l.ToUpperInvariant(), DIM); }
        // character grid: 128 x 128 (16 x 16 characters)
        int gx = W - 4 - 128 - 2, gy = y + 2;
        Rect(gx - 1, gy - 1, 130, 130, 0x2A3A5A);
        int setSel = (int)((m.Frames / 150) & 1);
        for (int ch = 0; ch < 256; ch++)
        {
            int cx = gx + (ch & 15) * 8, cy = gy + (ch >> 4) * 8;
            for (int r = 0; r < 8; r++)
            {
                int gi = (setSel << 11) | (ch << 3) | r;
                int bits;
                if (m.Pcg == PcgType.Pcg700) bits = m.Pcg700[gi];
                else if (m.Pcg == PcgType.Mz1500) { int pc = (ch << 3) | r; bits = m.Plane[0][pc] | m.Plane[1][pc] | m.Plane[2][pc]; }
                else bits = m.Font[gi];
                bool pcgArea = m.Pcg == PcgType.Pcg700 && ch >= 0x80;
                int on = pcgArea ? AMBER : m.Pcg == PcgType.Mz1500 ? CYAN : TXT, off = pcgArea ? 0x1A1408 : 0x0C1018;
                for (int i = 0; i < 8; i++) buf[(cy + r) * W + cx + i] = (bits & (0x80 >> i)) != 0 ? on : off;
            }
        }
        string gl = m.Pcg == PcgType.Mz1500 ? "PCG 000-0FF" : (setSel == 0 ? "SET 1" : "SET 2") + (m.Pcg == PcgType.Pcg700 ? " 80-FF PCG" : "");
        Text(gx, gy + 132, gl, DIM);
        return y0 + h;
    }
    string PortName(int p)
    {
        switch (p)
        {
            case 0xE0: return "0000 RAM"; case 0xE1: return "D000 RAM"; case 0xE2: return "0000 ROM"; case 0xE3: return "D000 VRAM"; case 0xE4: return "RESET MAP";
            case 0xE5: return m.Pcg == PcgType.Mz1500 ? "PCG MAP" : "LOCK D000"; case 0xE6: return m.Pcg == PcgType.Mz1500 ? "PCG OFF" : "UNLOCK";
            case 0xF0: return "PCG PRIO"; case 0xF1: return "PALETTE";
        }
        return "";
    }
}
