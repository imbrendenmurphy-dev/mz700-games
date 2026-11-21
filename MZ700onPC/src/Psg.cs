// MZ700onPC - SN76489AN programmable sound generator (the MZ-1500's two PSGs).
// Three square-wave tones and a noise channel, 4-bit attenuation in 2 dB steps. Port map as in the MZ-1500
// (Takeda's CSP eMZ-1500): OUT E9 writes both chips, OUT F2 the left one, OUT F3 the right one.
// The chips run from the MZ-1500's 3.579545 MHz clock; a tone register N gives clock / (32 N) Hz.
// Noise is the SN76489A form (17-bit shift register, taps 2 and 3), as CSP and MAME use for the "AN" part.
using System;

public sealed class Sn76489
{
    public const double CLOCK = 3579545.0;
    public const double TICK = CLOCK / 16;                         // tone counters count at clock / 16

    public readonly int[] Reg = new int[8];                       // 0,2,4 tone periods; 1,3,5,7 attenuation; 6 noise
    public int Latch;                                             // register the next data byte goes to
    readonly int[] count = new int[4];
    readonly bool[] sig = new bool[4];
    int noise = 0x10000;
    double tickFrac;
    public long Writes;
    static readonly double[] vol = new double[16];

    static Sn76489()
    {
        double v = 1.0;
        for (int i = 0; i < 15; i++) { vol[i] = v; v /= 1.258925412; }   // 2 dB per step
        vol[15] = 0;
    }

    public Sn76489() { Reset(); }

    public void Reset()
    {
        for (int i = 0; i < 8; i += 2) { Reg[i] = 0; Reg[i + 1] = 15; }
        for (int i = 0; i < 4; i++) { count[i] = 0; sig[i] = false; }
        noise = 0x10000; Latch = 0; tickFrac = 0;
    }

    int Period(int c)
    {
        if (c < 3) return Reg[c * 2] == 0 ? 0x400 : Reg[c * 2];
        int n = Reg[6] & 3;
        return n == 3 ? Period(2) * 2 : 32 << n;
    }

    public void Write(int v)
    {
        Writes++;
        if ((v & 0x80) != 0)
        {
            Latch = (v >> 4) & 7;
            if (Latch == 6) { Reg[6] = v & 7; noise = 0x10000; sig[3] = false; }
            else if ((Latch & 1) != 0) Reg[Latch] = v & 15;
            else Reg[Latch] = (Reg[Latch] & 0x3F0) | (v & 15);
        }
        else if ((Latch & 1) == 0 && Latch != 6)
            Reg[Latch] = (Reg[Latch] & 0x0F) | ((v & 0x3F) << 4);
    }

    /// <summary>Runs the chip for the given number of seconds and returns the mean output (each voice -1..+1 at
    /// full volume, so the sum is -4..+4).</summary>
    public double Run(double seconds)
    {
        double t = seconds * TICK + tickFrac;
        int ticks = (int)t; tickFrac = t - ticks;
        if (ticks <= 0) return Level();
        double sum = 0;
        for (int k = 0; k < ticks; k++)
        {
            for (int c = 0; c < 4; c++)
            {
                if (--count[c] > 0) continue;
                count[c] = Period(c);
                if (c < 3) sig[c] = !sig[c];
                else
                {
                    // CSP: feedback = bit 2, XOR bit 3 in white-noise mode
                    bool fb = (Reg[6] & 4) != 0 ? (((noise >> 2) ^ (noise >> 3)) & 1) != 0 : ((noise >> 2) & 1) != 0;
                    noise = (noise >> 1) | (fb ? 0x10000 : 0);
                    sig[3] = (noise & 1) != 0;
                }
            }
            sum += Level();
        }
        return sum / ticks;
    }

    double Level()
    {
        double s = 0;
        for (int c = 0; c < 4; c++) { double a = vol[Reg[c * 2 + 1]]; if (a > 0) s += sig[c] ? a : -a; }
        return s;
    }

    public double Hz(int c) { return c < 3 ? CLOCK / (32.0 * Period(c)) : CLOCK / (32.0 * Period(3)); }
    public int Atten(int c) { return Reg[c * 2 + 1]; }
    public string NoiseName { get { int n = Reg[6] & 3; return ((Reg[6] & 4) != 0 ? "WHITE " : "PERIODIC ") + (n == 3 ? "TONE3" : "N/" + (512 << n)); } }
}
