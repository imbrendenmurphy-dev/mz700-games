// MZ700onPC live trace: records what the Z80, the bus, VRAM waits, the 8253 and the I/O are doing, for the
// visualiser panels (Vis.cs). Attach with machine.Tr = new MzTrace(machine); detach with null.
using System;
using System.Collections.Generic;

public sealed class MzTrace
{
    readonly MzMachine m;
    public const int FT = MzMachine.FT, LINES = MzMachine.LINES, LT = MzMachine.LT;

    // memory heat (255 = touched this frame, fades over ~1/2 second)
    public readonly byte[] HR = new byte[65536], HW = new byte[65536], HX = new byte[65536];
    public readonly bool[] Start = new bool[65536];
    public readonly bool[] CallTarget = new bool[65536];
    readonly long[] visit = new long[65536];

    public readonly long[] Prof = new long[65536]; public long[] ProfShown = new long[65536]; public long ProfShownT;
    public readonly int[] Ops = new int[256]; public int[] OpsShown = new int[256]; public long OpsShownN;
    public int ProfVersion;
    int window;

    // per-T-state activity for one field and bus overlays (double buffered: *Shown = the last whole field)
    public const byte S_NONE = 0, S_BUSY = 1, S_IDLE = 2, S_ISR = 3, S_TAPE = 4, S_VWAIT = 5;
    public const byte O_VR = 1, O_VW = 2, O_SND = 3, O_OUT = 4, O_IN = 5, O_KEY = 6, O_PIT = 7, O_JOY = 8;
    byte[] ras = new byte[FT], ov = new byte[FT];
    public byte[] Ras = new byte[FT], Ov = new byte[FT];
    // changes to what the beam draws, at the T-state they land: VRAM (from the next 8-pixel cell), PCG, palette/priority
    public const byte P_CELL = 1, P_CG = 2, P_PAL = 3;
    byte[] pic = new byte[FT]; public byte[] PicShown = new byte[FT];

    // VRAM accesses per line (and those outside the free window)
    int[] lvw = new int[LINES], lvr = new int[LINES], lcont = new int[LINES];
    public int[] LineVW = new int[LINES], LineVR = new int[LINES], LineCont = new int[LINES];

    long lastWriteT, idleMark, tapeCarry; bool inIsr; int isrSp; long isrT0;
    int intsFrame; public int Ints;
    readonly List<long> waitT = new List<long>(); readonly List<int> waitN = new List<int>();

    public const int HIST = 300;
    public readonly byte[] HBusy = new byte[HIST], HIsr = new byte[HIST], HWait = new byte[HIST], HTape = new byte[HIST];
    public readonly int[] HSp = new int[HIST]; public int HPos;
    public double Busy, Isr, Idle, VWait, TapeF;
    int spMin = 0xFFFF; public int SpMinSecond = 0xFFFF; int spMinWin = 0xFFFF; int spMaxWin; public int SpMaxSecond = 0xFFFF;

    // ports and memory-mapped I/O (E000-E012)
    public readonly byte[] PIn = new byte[256], POut = new byte[256];
    public readonly int[] PValIn = new int[256], PValOut = new int[256];
    readonly int[] pCount = new int[512]; public int[] PCountShown = new int[512];
    public readonly List<int> Recent = new List<int>();     // (out?256:0)+port
    public readonly byte[] IoR = new byte[19], IoW = new byte[19];
    public readonly int[] IoValR = new int[19], IoValW = new int[19];
    readonly int[] ioCount = new int[38]; public int[] IoCountShown = new int[38];
    public readonly byte[] RowScan = new byte[10];
    int pitN, joyN; public int PitAccess, JoyReads;

    int vramW, vramR, cont; public int VramW, VramR, Contended;
    public long WaitShown;

    // speaker: the 44.1 kHz level, one field
    public float[] Spk = new float[1000], SpkShown = new float[1000]; int spkN; public int SpkShownN;
    public readonly float[] SpkRing = new float[2048]; public int SpkRingPos;
    int sndW; public int SoundWrites;

    public byte TapeLed;
    readonly Random rnd = new Random(1);
    int sampleT, sampleCand = -1, lastSample = -1; public int ShownPc = -1; int frameNo;

    static readonly byte[] decay = new byte[256];
    static MzTrace() { for (int i = 0; i < 256; i++) decay[i] = (byte)Math.Max(0, i - (i >> 4) - 2); }

    public MzTrace(MzMachine machine) { m = machine; sampleT = rnd.Next(FT); }

    int RelOf(long t) { long r = (t * 5 - m.FrameStartM) / 5; return r < 0 ? 0 : r >= FT ? FT - 1 : (int)r; }
    int Rel { get { return RelOf(m.Cpu.AccessT); } }
    int LineNow { get { int l = (int)((m.NowM - m.FrameStartM) / MzMachine.LINE_M); return l < 0 ? 0 : l >= LINES ? LINES - 1 : l; } }

    bool Contend()
    {
        long pos = (m.Cpu.AccessT * 5) % MzMachine.FRAME_M; int x = (int)(pos % MzMachine.LINE_M);
        return x < m.WaitW0 * 5 || x >= m.WaitW1 * 5;
    }

    // ---------------------------------------------------------------- bus events
    public void R(int a)
    {
        HR[a] = 255;
        if (a >= 0xD000 && a < 0xE000 && m.IoIn && !m.Inhibit) { vramR++; ov[Rel] = O_VR; lvr[LineNow]++; if (Contend()) { cont++; lcont[LineNow]++; } }
    }
    public void X(int a) { HX[a] = 255; }
    public void W(int a, int v)
    {
        HW[a] = 255;
        lastWriteT = m.Cpu.Cyc;
        if (a >= 0xD000 && a < 0xE000 && m.IoIn && !m.Inhibit) { vramW++; ov[Rel] = O_VW; lvw[LineNow]++; if (Contend()) { cont++; lcont[LineNow]++; } }
    }
    public void Io(int a, int v, bool write)
    {
        int i = a - 0xE000; if (i < 0 || i > 18) return;
        if (write) { IoW[i] = 255; IoValW[i] = v; ioCount[19 + i]++; lastWriteT = m.Cpu.Cyc; if (i >= 4 && i <= 8) { sndW++; ov[Rel] = O_SND; } }
        else { IoR[i] = 255; IoValR[i] = v; ioCount[i]++; }
    }
    public void KeyRead(int row) { if (row < 10) RowScan[row] = 255; ov[Rel] = O_KEY; }
    public void Pit() { pitN++; if (ov[Rel] == 0) ov[Rel] = O_PIT; }
    public void Joy() { joyN++; ov[Rel] = O_JOY; }
    public void Port(int lo, int v, bool isOut)
    {
        if (isOut) { POut[lo] = 255; PValOut[lo] = v; pCount[256 + lo]++; lastWriteT = m.Cpu.Cyc; ov[Rel] = O_OUT; }
        else { PIn[lo] = 255; PValIn[lo] = v; pCount[lo]++; ov[Rel] = O_IN; }
        int key = (isOut ? 256 : 0) + lo;
        if (Recent.Count == 0 || Recent[0] != key) { Recent.Remove(key); Recent.Insert(0, key); if (Recent.Count > 16) Recent.RemoveAt(16); }
    }
    public void Pic(byte kind) { int r = Rel; if (kind > pic[r]) pic[r] = kind; }
    public void Wait(long t, int n) { waitT.Add(t); waitN.Add(n); }
    public void Line(int ln) { }
    public void Sample(double lvl)
    {
        float f = (float)lvl;
        if (spkN < Spk.Length) Spk[spkN++] = f;
        SpkRing[SpkRingPos] = f; SpkRingPos = (SpkRingPos + 1) & 2047;
    }

    // ---------------------------------------------------------------- instructions
    public void Step(int pc, long t0, long t1, bool intTaken, bool halted)
    {
        byte st;
        if (intTaken)
        {
            if (!inIsr) { inIsr = true; isrSp = (m.Cpu.SP + 2) & 0xFFFF; isrT0 = t0; }
            intsFrame++; st = S_ISR; Prof[0x38] += t1 - t0;
        }
        else
        {
            Start[pc] = true;
            Prof[pc] += t1 - t0;
            int op = m.Peek(pc);
            Ops[op]++;
            st = inIsr ? S_ISR : halted ? S_IDLE : S_BUSY;
            if (!halted)
            {
                if (op == 0xCD || (op & 0xC7) == 0xC4) { if (m.Cpu.PC != ((pc + 3) & 0xFFFF)) CallTarget[m.Cpu.PC] = true; }
                else if ((op & 0xC7) == 0xC7) CallTarget[op & 0x38] = true;
            }
            if (st == S_BUSY)
            {
                long pv = visit[pc]; visit[pc] = t0;
                if (pv != 0 && pv < t0 && pv > lastWriteT && t0 - pv < 256)
                {
                    int from = RelOf(Math.Max(pv, idleMark)), to = RelOf(t0);
                    if (m.FrameStartM <= pv * 5 || true) for (int r = from; r < to; r++) if (ras[r] == S_BUSY) ras[r] = S_IDLE;
                    st = S_IDLE;
                }
            }
            if (inIsr && (m.Cpu.SP >= isrSp || t1 - isrT0 > FT)) inIsr = false;
        }
        if (st == S_IDLE) idleMark = t1;
        int r0 = RelOf(t0), r1 = RelOf(t1); if (t1 * 5 - m.FrameStartM >= (long)FT * 5) r1 = FT;
        for (int r = r0; r < r1; r++) ras[r] = st;
        for (int i = 0; i < waitT.Count; i++)
        {
            int w0 = RelOf(waitT[i]);
            for (int r = w0; r < w0 + waitN[i] && r < FT; r++) ras[r] = S_VWAIT;
        }
        waitT.Clear(); waitN.Clear();
        if (sampleT >= r0 && sampleT < r1 && st == S_BUSY) sampleCand = pc;
        int sp = m.Cpu.SP; if (sp >= 0x1000) { if (sp < spMin) spMin = sp; if (sp > spMaxWin) spMaxWin = sp; }
    }

    public void Tape(long t0, long t1)
    {
        TapeLed = 255; lastWriteT = t1;
        int r0 = RelOf(t0); long end = t1 * 5 - m.FrameStartM;
        int r1 = end >= (long)FT * 5 ? FT : RelOf(t1);
        for (int r = r0; r < r1; r++) ras[r] = S_TAPE;
        if (end > (long)FT * 5) tapeCarry = end / 5 - FT;
    }

    public void ResetTimes() { Array.Clear(visit, 0, visit.Length); lastWriteT = idleMark = 0; inIsr = false; tapeCarry = 0; waitT.Clear(); waitN.Clear(); }

    // ---------------------------------------------------------------- end of a field
    public void EndFrame()
    {
        var sw = SpkShown; SpkShown = Spk; Spk = sw; SpkShownN = spkN; spkN = 0;
        SoundWrites = sndW; sndW = 0;

        int nb = 0, ni = 0, nw = 0, nt = 0, nx = 0;
        for (int i = 0; i < FT; i++)
            switch (ras[i]) { case S_BUSY: case S_NONE: nb++; break; case S_ISR: ni++; break; case S_VWAIT: nw++; break; case S_TAPE: nt++; break; default: nx++; break; }
        Busy = (double)nb / FT; Isr = (double)ni / FT; VWait = (double)nw / FT; TapeF = (double)nt / FT; Idle = (double)nx / FT;
        HBusy[HPos] = (byte)Math.Round(Busy * 100); HIsr[HPos] = (byte)Math.Round(Isr * 100); HWait[HPos] = (byte)Math.Round(VWait * 100); HTape[HPos] = (byte)Math.Round(TapeF * 100);
        HSp[HPos] = spMin; HPos = (HPos + 1) % HIST;
        if (spMin < spMinWin) spMinWin = spMin;
        spMin = 0xFFFF;

        var b = Ras; Ras = ras; ras = b; Array.Clear(ras, 0, FT);
        b = Ov; Ov = ov; ov = b; Array.Clear(ov, 0, FT);
        b = PicShown; PicShown = pic; pic = b; Array.Clear(pic, 0, FT);
        if (tapeCarry > 0) { for (int i = 0; i < Math.Min(FT, tapeCarry); i++) ras[i] = S_TAPE; tapeCarry = 0; }
        var l = LineVW; LineVW = lvw; lvw = l; Array.Clear(lvw, 0, LINES);
        l = LineVR; LineVR = lvr; lvr = l; Array.Clear(lvr, 0, LINES);
        l = LineCont; LineCont = lcont; lcont = l; Array.Clear(lcont, 0, LINES);

        Ints = intsFrame; intsFrame = 0;
        VramW = vramW; VramR = vramR; Contended = cont; vramW = vramR = cont = 0;
        WaitShown = m.WaitTFrame;
        PitAccess = pitN; JoyReads = joyN; pitN = joyN = 0;
        Array.Copy(pCount, PCountShown, 512); Array.Clear(pCount, 0, 512);
        Array.Copy(ioCount, IoCountShown, 38); Array.Clear(ioCount, 0, 38);

        for (int i = 0; i < 65536; i++) { HR[i] = decay[HR[i]]; HW[i] = decay[HW[i]]; HX[i] = decay[HX[i]]; }
        for (int i = 0; i < 256; i++) { PIn[i] = decay[PIn[i]]; POut[i] = decay[POut[i]]; }
        for (int i = 0; i < 19; i++) { IoR[i] = decay[IoR[i]]; IoW[i] = decay[IoW[i]]; }
        for (int i = 0; i < 10; i++) RowScan[i] = decay[decay[RowScan[i]]];
        TapeLed = decay[decay[TapeLed]];

        if (sampleCand >= 0 && Ras[sampleT] == S_BUSY) lastSample = sampleCand;
        sampleCand = -1; sampleT = rnd.Next(FT);
        frameNo++;
        if (frameNo % 6 == 0 || ShownPc < 0) ShownPc = lastSample >= 0 ? lastSample : m.Cpu.PC;

        if (++window >= 50)
        {
            window = 0;
            long tot = 0;
            for (int i = 0; i < 65536; i++) { ProfShown[i] = Prof[i]; tot += Prof[i]; Prof[i] = 0; }
            ProfShownT = tot;
            long n = 0;
            for (int i = 0; i < 256; i++) { OpsShown[i] = Ops[i]; n += Ops[i]; Ops[i] = 0; }
            OpsShownN = n;
            SpMinSecond = spMinWin; spMinWin = 0xFFFF; SpMaxSecond = spMaxWin == 0 ? 0xFFFF : spMaxWin; spMaxWin = 0;
            ProfVersion++;
        }
    }
}
