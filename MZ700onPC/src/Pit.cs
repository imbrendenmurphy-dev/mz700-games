// MZ700onPC - Intel 8253 programmable interval timer (one counter).
// The MZ-700 clocks counter 0 at 1.108 MHz (sound), counter 1 from HSYNC (15.6 kHz) and counter 2 from OUT1.
// Counters are clocked in bulk (Clock(n)), so counter 0 can be brought up to date lazily, and its output
// waveform is known in closed form between writes (HighClocks), which the audio uses.
using System;

public sealed class PitCounter
{
    public int Mode;            // 0..5
    public int Rl = 3;          // 1 LSB, 2 MSB, 3 LSB then MSB
    public bool Bcd;
    public int Reload = 65536;  // the count register (1..65536)
    public bool Out = true;
    public bool Gate = true;
    public bool Counting;       // a count has been written since the control word
    public long Writes, Loads;
    public bool Fired;          // mode 0/4: terminal count reached since the last load
    int phase;                  // modes 2/3: clocks into the current period (0..Reload-1); modes 0/1/4/5: clocks since load
    bool wHigh, rHigh;          // LSB/MSB flip-flops
    int wLow;
    int latched = -1;           // latched count, or -1

    public void Reset() { Mode = 0; Rl = 3; Reload = 65536; Out = true; Gate = true; Counting = false; phase = 0; wHigh = rHigh = false; latched = -1; Fired = false; }

    public void Control(int v)
    {
        int rl = (v >> 4) & 3;
        if (rl == 0) { latched = Count; rHigh = false; return; }
        Rl = rl; Mode = (v >> 1) & 7; if (Mode > 5) Mode -= 4; Bcd = (v & 1) != 0;
        Counting = false; wHigh = rHigh = false; latched = -1; Fired = false;
        Out = Mode != 0;
        Writes++;
    }

    /// <summary>A write to the counter's data port. Returns true when the count is complete (the counter (re)loads).</summary>
    public bool Write(int v)
    {
        Writes++;
        int n;
        if (Rl == 1) n = v;
        else if (Rl == 2) n = v << 8;
        else
        {
            if (!wHigh) { wLow = v; wHigh = true; if (Mode == 0) Out = false; return false; }
            wHigh = false; n = wLow | (v << 8);
        }
        if (Bcd) n = FromBcd(n);
        Reload = n == 0 ? (Bcd ? 10000 : 65536) : n;
        Loads++;
        // modes 2 and 3 pick the new count up at the end of the current period when already running
        if ((Mode == 2 || Mode == 3) && Counting) return true;
        Counting = true; phase = 0; Fired = false;
        if (Mode == 0) Out = false; else Out = true;
        return true;
    }

    static int FromBcd(int n) { return (n & 15) + ((n >> 4) & 15) * 10 + ((n >> 8) & 15) * 100 + ((n >> 12) & 15) * 1000; }

    /// <summary>The count as the CPU would read it now.</summary>
    public int Count
    {
        get
        {
            if (!Counting) return Reload & 0xFFFF;
            int c;
            switch (Mode)
            {
                case 2: c = Reload - phase; break;
                case 3: { int h = (Reload + 1) / 2; int k = phase < h ? phase : phase - h; c = Reload - 2 * k; if (c <= 0) c += Reload; } break;
                default: c = (int)((Reload - (long)phase) & 0xFFFF); break;
            }
            return c & 0xFFFF;
        }
    }

    public int Read()
    {
        int v = latched >= 0 ? latched : Count;
        int r;
        if (Rl == 1) { r = v & 255; latched = -1; }
        else if (Rl == 2) { r = v >> 8; latched = -1; }
        else
        {
            if (!rHigh) { r = v & 255; rHigh = true; }
            else { r = v >> 8; rHigh = false; latched = -1; }
        }
        return r;
    }

    public bool Running { get { return Counting && (Gate || Mode == 1 || Mode == 5); } }

    /// <summary>Advances n input clocks. Returns the number of rising edges on OUT.</summary>
    public long Clock(long n)
    {
        if (n <= 0 || !Running) return 0;
        long rises = 0;
        int N = Reload;
        switch (Mode)
        {
            case 2:
                {
                    long k = phase + n;
                    rises = k / N;                  // OUT goes low for the last clock of each period, high again at reload
                    phase = (int)(k % N);
                    Out = phase != N - 1;
                }
                break;
            case 3:
                {
                    int h = (N + 1) / 2;
                    long k = phase + n;
                    rises = k / N;
                    phase = (int)(k % N);
                    Out = phase < h;
                }
                break;
            case 0: case 1:
                {
                    long k = phase + n;
                    if (!Fired && k >= N) { Fired = true; if (!Out) rises = 1; Out = true; }
                    phase = (int)Math.Min(k, 1L << 30);
                    if (phase >= 65536 + N) phase = N + (int)((phase - N) % 65536);
                }
                break;
            default:   // 4, 5: one low pulse at terminal count
                {
                    long k = phase + n;
                    if (!Fired && k >= N) { Fired = true; Out = k > N; if (k > N) rises = 1; }
                    else if (Fired && !Out && k > N) { Out = true; rises = 1; }
                    phase = (int)Math.Min(k, 1L << 30);
                    if (phase >= 65536 + N + 1) phase = N + 1 + (int)((phase - N - 1) % 65536);
                }
                break;
        }
        return rises;
    }

    public void SetGate(bool g)
    {
        if (g == Gate) return;
        Gate = g;
        if (!g && (Mode == 2 || Mode == 3)) Out = true;       // gate low forces OUT high in modes 2 and 3
        if (g && (Mode == 2 || Mode == 3) && Counting) phase = 0;  // and a rising gate restarts the period
        if (g && (Mode == 1 || Mode == 5) && Counting) { phase = 0; Fired = false; Out = Mode == 5; if (Mode == 1) Out = false; }
    }

    /// <summary>How many of the next n clocks OUT is high, assuming nothing is written meanwhile (closed form, for audio).</summary>
    public double HighFraction(long n)
    {
        if (n <= 0) return Out ? 1 : 0;
        if (!Running) return Out ? 1 : 0;
        int N = Reload;
        switch (Mode)
        {
            case 3:
                {
                    int h = (N + 1) / 2;
                    return (double)(G(phase + n, N, h) - G(phase, N, h)) / n;
                }
            case 2: return 1.0 - (double)((phase + 1 + n) / N - (phase + 1) / N) / n;
            case 0: case 1:
                {
                    if (Fired) return 1;
                    long left = N - phase;                 // clocks until OUT goes high
                    return left >= n ? 0 : (double)(n - left) / n;
                }
            default:
                {
                    if (Fired && Out) return 1;
                    long left = N - phase;
                    return (left >= 0 && left < n) ? 1.0 - 1.0 / n : 1;
                }
        }
    }
    static long G(long x, int N, int h) { return (x / N) * h + Math.Min(x % N, h); }

    public string ModeName
    {
        get
        {
            switch (Mode) { case 0: return "INT ON TC"; case 1: return "ONE-SHOT"; case 2: return "RATE GEN"; case 3: return "SQUARE"; case 4: return "SW STROBE"; default: return "HW STROBE"; }
        }
    }
}
