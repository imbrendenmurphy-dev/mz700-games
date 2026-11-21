// MZ700onPC - the cassette (CMT): MZT/MZF tape images, the tape signal the monitor reads on 8255 PC5,
// the data recorder's motor (PC3 toggles it, PC4 senses it), and recording what the MZ writes on PC1.
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

/// <summary>One file on tape: the 128-byte header (attribute, name, size, load and exec address, comment) and the data.</summary>
public sealed class MzBlock
{
    public byte[] Header = new byte[128];
    public byte[] Data = new byte[0];
    public int Attr { get { return Header[0]; } }
    public int Size { get { return Header[0x12] | (Header[0x13] << 8); } }
    public int Load { get { return Header[0x14] | (Header[0x15] << 8); } }
    public int Exec { get { return Header[0x16] | (Header[0x17] << 8); } }
    public string Name
    {
        get
        {
            var sb = new StringBuilder();
            for (int i = 1; i < 18; i++) { int c = Header[i]; if (c == 0x0D || c == 0) break; sb.Append(c >= 32 && c < 127 ? (char)c : '?'); }
            return sb.ToString();
        }
    }
    public string Describe() { return string.Format("\"{0}\" attr {1:X2} load {2:X4} size {3:X4} exec {4:X4}", Name, Attr, Load, Size, Exec); }
}

public sealed class MzTapeFile
{
    public string Path;
    public readonly List<MzBlock> Blocks = new List<MzBlock>();

    /// <summary>Reads an .MZT / .MZF / .M12 file (one or more 128-byte headers each followed by its data).</summary>
    public static MzTapeFile Load(string path)
    {
        var raw = File.ReadAllBytes(path);
        string head = Encoding.ASCII.GetString(raw, 0, Math.Min(raw.Length, 256)).ToLowerInvariant();
        if (head.Contains("<!doctype") || head.Contains("<html"))
            throw new InvalidDataException("this is a web page saved with a tape file's name, not a tape image - download the raw file");
        var t = new MzTapeFile { Path = path };
        int p = 0;
        while (p + 128 <= raw.Length)
        {
            var b = new MzBlock();
            Array.Copy(raw, p, b.Header, 0, 128); p += 128;
            int n = Math.Min(b.Size, raw.Length - p);
            b.Data = new byte[n]; Array.Copy(raw, p, b.Data, 0, n); p += n;
            t.Blocks.Add(b);
            if (b.Size == 0 && b.Attr == 0) break;
        }
        if (t.Blocks.Count == 0) throw new InvalidDataException("not an MZT/MZF file (shorter than a 128-byte header)");
        return t;
    }

    public static bool IsTapeName(string path)
    {
        string e = System.IO.Path.GetExtension(path).ToLowerInvariant();
        return e == ".mzt" || e == ".mzf" || e == ".m12" || e == ".mzb";
    }
}

/// <summary>The tape signal of an MZT file as the Sharp PWM format: a long pulse (about 958 us) is a 1, a short pulse
/// (about 504 us) a 0. Each byte is a 1 bit followed by its 8 bits, most significant first. A file is a header block
/// (22000 short, tape mark 40 long + 40 short, 1 long, 128 bytes, 2-byte checksum, 1 long, 256 short, the copy,
/// checksum, 1 long) and a data block (11000 short, 20 long + 20 short, 1 long, data, checksum, 1 long, 256 short,
/// copy, checksum, 1 long). The checksum is the number of 1 bits, big-endian.</summary>
public sealed class MzTapeSignal
{
    // half-pulse lengths in master clocks (17.734475 MHz)
    public static int LongHi = 8228, LongLo = 8761, ShortHi = 4256, ShortLo = 4682;  // 464/494 us, 240/264 us
    readonly List<int> edges = new List<int>();   // durations of alternating levels, starting high
    public readonly List<long> BlockStart = new List<long>(); public readonly List<string> BlockName = new List<string>();
    long total;
    public long TotalM { get { return total; } }

    void Pulse(bool one) { edges.Add(one ? LongHi : ShortHi); edges.Add(one ? LongLo : ShortLo); total += one ? LongHi + LongLo : ShortHi + ShortLo; }
    void Run(bool one, int n) { for (int i = 0; i < n; i++) Pulse(one); }
    void Bytes(byte[] d, int n)
    {
        int sum = 0;
        for (int i = 0; i < n; i++) { int v = i < d.Length ? d[i] : 0; Pulse(true); for (int b = 7; b >= 0; b--) { bool one = ((v >> b) & 1) != 0; if (one) sum++; Pulse(one); } }
        int hi = (sum >> 8) & 255, lo = sum & 255;
        foreach (int v in new[] { hi, lo }) { Pulse(true); for (int b = 7; b >= 0; b--) Pulse(((v >> b) & 1) != 0); }
    }
    void Silence(int us) { int m = (int)(us * 17.734475); edges.Add(0); edges.Add(m); total += m; }

    public MzTapeSignal(MzTapeFile f)
    {
        Silence(200000);
        foreach (var b in f.Blocks)
        {
            BlockStart.Add(total); BlockName.Add(b.Name);
            Run(false, 22000); Run(true, 40); Run(false, 40); Pulse(true);
            Bytes(b.Header, 128); Pulse(true); Run(false, 256); Bytes(b.Header, 128); Pulse(true);
            Run(false, 11000); Run(true, 20); Run(false, 20); Pulse(true);
            Bytes(b.Data, b.Size); Pulse(true); Run(false, 256); Bytes(b.Data, b.Size); Pulse(true);
            Silence(500000);
        }
    }

    int cur; long curStart;
    /// <summary>The level at tape position t (master clocks from the start). Fast for increasing t.</summary>
    public bool Level(long t)
    {
        if (t < curStart) { cur = 0; curStart = 0; }
        while (cur < edges.Count && curStart + edges[cur] <= t) { curStart += edges[cur]; cur++; }
        if (cur >= edges.Count) return false;
        return (cur & 1) == 0;
    }
}

/// <summary>The data recorder: an MZT played as a real signal, or an audio file, with the motor.</summary>
public sealed class MzCassette
{
    public MzTapeFile File;          // the tape image (also used by the fast-load traps)
    public MzTapeSignal Signal;      // its signal, for loading at real speed
    public VzTape Audio;             // or an audio recording
    public string Name;
    public bool PlayPressed;         // PLAY held down (a tape is in and playing)
    public bool Motor;               // the motor is turning
    public long PosM;                // tape position in master clocks
    public int FastIndex;            // next block for the fast-load traps
    public bool Invert;
    long lastM = -1;
    public int MotorToggles;

    public bool HasTape { get { return File != null || Audio != null; } }
    public void Eject() { File = null; Signal = null; Audio = null; Name = null; PlayPressed = false; Motor = false; PosM = 0; FastIndex = 0; }

    public void InsertMzt(MzTapeFile f) { Eject(); File = f; Signal = new MzTapeSignal(f); Name = System.IO.Path.GetFileName(f.Path); }
    public void InsertAudio(VzTape a) { Eject(); Audio = a; Name = a.Name; }

    public void Play(long nowM) { if (!HasTape) return; Advance(nowM); PlayPressed = true; Motor = true; }
    public void Stop(long nowM) { Advance(nowM); PlayPressed = false; Motor = false; }
    public void Rewind() { PosM = 0; FastIndex = 0; }

    public void Advance(long nowM)
    {
        if (lastM >= 0 && Motor && PlayPressed) PosM += nowM - lastM;
        lastM = nowM;
    }

    /// <summary>The M-ON line (8255 PC3): a rising edge toggles the motor while PLAY is down.</summary>
    public void MotorPulse(long nowM) { Advance(nowM); MotorToggles++; if (PlayPressed) Motor = !Motor; }

    /// <summary>RDATA (8255 PC5).</summary>
    public bool Level(long nowM)
    {
        Advance(nowM);
        if (!Motor || !PlayPressed) return false;
        bool v;
        if (Signal != null) v = Signal.Level(PosM);
        else if (Audio != null)
        {
            var s = Audio.Samples; long i = (long)(PosM / 17734475.0 * Audio.Rate);
            if (i >= s.Length) return false;
            v = s[i] > 0;
        }
        else return false;
        return v != Invert;
    }

    public double Seconds { get { return PosM / 17734475.0; } }
    public double Length { get { return Signal != null ? Signal.TotalM / 17734475.0 : Audio != null ? Audio.Seconds : 0; } }
}

/// <summary>Records the cassette write line (8255 PC1) to a WAV, and decodes the Sharp PWM pulses back to an MZT.</summary>
public sealed class MzTapeRecorder
{
    public bool Recording; public string File; long startM; bool level; long lastEdgeM;
    readonly List<long> edges = new List<long>();   // master-clock times of level changes
    public long StartM { get { return startM; } }
    public int Edges { get { return edges.Count; } }

    public void Start(string file, long nowM, bool lvl) { File = file; startM = nowM; level = lvl; edges.Clear(); Recording = true; lastEdgeM = nowM; }
    public void Line(long nowM, bool lvl) { if (!Recording || lvl == level) return; level = lvl; edges.Add(nowM); lastEdgeM = nowM; }

    /// <summary>Stops: writes the WAV (or, for a .mzt/.mzf name, the decoded file). Returns a description.</summary>
    public string Stop(long nowM)
    {
        Recording = false;
        string ext = Path.GetExtension(File).ToLowerInvariant();
        if (ext == ".mzt" || ext == ".mzf")
        {
            var blocks = Decode();
            if (blocks.Count == 0) return "no file found in the recording (" + edges.Count + " edges)";
            using (var f = new FileStream(File, FileMode.Create))
                foreach (var b in blocks) { f.Write(b.Header, 0, 128); f.Write(b.Data, 0, b.Data.Length); }
            var sb = new StringBuilder(); foreach (var b in blocks) sb.Append(b.Name + " ");
            return "saved " + blocks.Count + " file(s): " + sb.ToString().Trim();
        }
        // WAV: 44.1 kHz, the level held, fading after 5 ms like an AC-coupled input
        double secs = (nowM - startM) / 17734475.0;
        int n = (int)(secs * 44100) + 1;
        var pcm = new short[n];
        int ei = 0; bool lv = !level; // initial level: before the first edge
        if (edges.Count % 2 == 0) lv = level;
        long lastChange = startM;
        for (int i = 0; i < n; i++)
        {
            long t = startM + (long)(i * 17734475.0 / 44100);
            while (ei < edges.Count && edges[ei] <= t) { lv = !lv; lastChange = edges[ei]; ei++; }
            double held = (t - lastChange) / 17734475.0;
            double amp = held < 0.005 ? 1 : Math.Max(0, 1 - (held - 0.005) * 200);
            pcm[i] = (short)((lv ? 1 : -1) * 20000 * amp);
        }
        using (var w = new BinaryWriter(System.IO.File.Create(File)))
        {
            w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write(36 + n * 2); w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(44100); w.Write(88200); w.Write((short)2); w.Write((short)16);
            w.Write(Encoding.ASCII.GetBytes("data")); w.Write(n * 2);
            foreach (var s in pcm) w.Write(s);
        }
        return string.Format("{0:F1} s of tape", secs);
    }

    /// <summary>Turns the recorded pulses back into files. A pulse is measured rising edge to rising edge.</summary>
    public List<MzBlock> Decode()
    {
        // pulse lengths (rising to rising) in microseconds; the polarity is found by trying both
        var res = new List<MzBlock>();
        for (int phase = 0; phase < 2 && res.Count == 0; phase++)
        {
            var bits = new List<int>();
            for (int i = phase; i + 2 < edges.Count; i += 2)
            {
                double us = (edges[i + 2] - edges[i]) / 17.734475;
                bits.Add(us > 1500 ? -1 : us > 730 ? 1 : 0);   // -1 = a gap
            }
            res = ParseBits(bits);
        }
        return res;
    }

    static List<MzBlock> ParseBits(List<int> bits)
    {
        var res = new List<MzBlock>();
        int p = 0; MzBlock hdr = null;
        while (p < bits.Count)
        {
            // a tape mark: a run of >= 15 long pulses then >= 15 short, then a long
            int q = p; while (q < bits.Count && bits[q] != 1) q++;
            int l = q; while (l < bits.Count && bits[l] == 1) l++;
            if (l >= bits.Count) break;
            int s = l; while (s < bits.Count && bits[s] == 0) s++;
            if (l - q < 15 || s - l < 15 || s >= bits.Count || bits[s] != 1) { p = Math.Max(l, q + 1); continue; }
            p = s + 1;
            int want = hdr == null ? 128 : hdr.Size;
            var data = new byte[want]; bool ok = true;
            for (int i = 0; i < want && ok; i++) ok = ReadByte(bits, ref p, out data[i]);
            byte hi, lo; ok = ok && ReadByte(bits, ref p, out hi) && ReadByte(bits, ref p, out lo);
            if (!ok) break;
            if (hdr == null) { hdr = new MzBlock(); hdr.Header = data; }
            else { hdr.Data = data; res.Add(hdr); hdr = null; }
            // skip the copy
            while (p < bits.Count && bits[p] != -1 && !(p + 15 < bits.Count && RunOf(bits, p, 1, 15) && hdrFollow(bits, p))) p++;
        }
        return res;
    }
    static bool RunOf(List<int> b, int p, int v, int n) { for (int i = 0; i < n; i++) if (p + i >= b.Count || b[p + i] != v) return false; return true; }
    static bool hdrFollow(List<int> b, int p) { return p > 0 && b[p - 1] == 0; }

    static bool ReadByte(List<int> bits, ref int p, out byte v)
    {
        v = 0;
        if (p + 9 > bits.Count || bits[p] != 1) return false;
        p++;
        int x = 0;
        for (int i = 0; i < 8; i++) { int b = bits[p++]; if (b < 0) return false; x = (x << 1) | b; }
        v = (byte)x; return true;
    }
}
