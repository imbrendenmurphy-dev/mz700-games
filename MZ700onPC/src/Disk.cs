// MZ700onPC - floppy disk images: D88 (.d88/.d77/.d68), CPC DSK and Extended DSK (.dsk, the format the Sharp MZ
// community uses), and raw 2D (.2d, 40 x 2 x 16 x 256). Sector data is kept exactly as it is on the disk; the MZ's
// MB8876 controller has an inverted data bus, so MZ disks hold every byte complemented and the FDC inverts it back.
// Sharp's logical records: record r is on logical track r/16, sector r%16+1, and logical track t sits on cylinder
// t/2, head (t&1)^1 - so the IPL record ("\x03IPLPRO", size at 14h, load 16h, exec 18h, first record 1Eh) is on
// cylinder 0, head 1, sector 1 (checked against real MZ disk images).
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public sealed class MzSector
{
    public int C, H, R, N;
    public byte[] Data;
    public bool Deleted, CrcError, IdCrcError;
    public int Size { get { return Data.Length; } }
}

public sealed class MzDisk
{
    public const int MAXCYL = 84;
    public string Path = "", Format = "D88";
    public bool WriteProtect, Dirty;
    public readonly List<MzSector>[,] Tracks = new List<MzSector>[MAXCYL, 2];
    public int Cylinders, Heads = 2;
    public long Reads, Writes;

    public MzDisk() { for (int c = 0; c < MAXCYL; c++) for (int h = 0; h < 2; h++) Tracks[c, h] = new List<MzSector>(); }

    public List<MzSector> Track(int c, int h) { return c >= 0 && c < MAXCYL && h >= 0 && h < 2 ? Tracks[c, h] : new List<MzSector>(); }
    public string Name { get { return System.IO.Path.GetFileName(Path); } }

    // ---------------------------------------------------------------- loading
    public static MzDisk Load(string path)
    {
        var raw = File.ReadAllBytes(path);
        var d = new MzDisk(); d.Path = path;
        string ext = System.IO.Path.GetExtension(path).ToLowerInvariant();
        string sig = Encoding.ASCII.GetString(raw, 0, Math.Min(raw.Length, 34));
        if (sig.StartsWith("EXTENDED") || sig.StartsWith("MV - CPC")) d.LoadDsk(raw, sig.StartsWith("EXTENDED"));
        else if (ext == ".2d" || ext == ".img" || ext == ".raw") d.LoadRaw(raw);
        else d.LoadD88(raw);
        d.Cylinders = 0;
        for (int c = 0; c < MAXCYL; c++) for (int h = 0; h < 2; h++) if (d.Tracks[c, h].Count > 0) d.Cylinders = c + 1;
        if (d.Cylinders == 0) throw new InvalidDataException("no sectors found - not a D88, DSK or raw 2D disk image");
        return d;
    }

    void LoadD88(byte[] raw)
    {
        Format = "D88";
        if (raw.Length < 0x2B0) throw new InvalidDataException("too short for a D88 image");
        WriteProtect = raw[0x1A] != 0;
        int size = BitConverter.ToInt32(raw, 0x1C);
        if (size < 0x2B0 || size > raw.Length) size = raw.Length;
        for (int t = 0; t < 164; t++)
        {
            int off = BitConverter.ToInt32(raw, 0x20 + t * 4);
            if (off < 0x20 || off >= size) continue;
            int p = off, nsec = 1;
            for (int s = 0; s < nsec && p + 16 <= size; s++)
            {
                var sec = new MzSector { C = raw[p], H = raw[p + 1], R = raw[p + 2], N = raw[p + 3] };
                nsec = BitConverter.ToUInt16(raw, p + 4); if (nsec == 0 || nsec > 64) nsec = 1;
                sec.Deleted = raw[p + 7] != 0;
                int st = raw[p + 8];
                sec.IdCrcError = st == 0xA0; sec.CrcError = st == 0xB0;
                int len = BitConverter.ToUInt16(raw, p + 14);
                if (p + 16 + len > size) len = Math.Max(0, size - p - 16);
                sec.Data = new byte[len]; Array.Copy(raw, p + 16, sec.Data, 0, len);
                Track(t >> 1, t & 1).Add(sec);
                p += 16 + len;
            }
        }
    }

    void LoadDsk(byte[] raw, bool ext)
    {
        Format = ext ? "EDSK" : "DSK";
        int ntr = raw[0x30], nsd = Math.Max(1, (int)raw[0x31]);
        Heads = nsd;
        int p = 0x100;
        for (int t = 0; t < ntr; t++)
            for (int s = 0; s < nsd; s++)
            {
                int tsize = ext ? raw[0x34 + t * nsd + s] * 256 : BitConverter.ToUInt16(raw, 0x32);
                if (tsize == 0) continue;
                if (p + 0x100 > raw.Length) return;
                if (Encoding.ASCII.GetString(raw, p, 10) != "Track-Info") { p += tsize; continue; }
                int cyl = raw[p + 0x10], head = raw[p + 0x11], nsec = raw[p + 0x15], defN = raw[p + 0x14];
                int dp = p + 0x100;
                for (int i = 0; i < nsec; i++)
                {
                    int q = p + 0x18 + i * 8;
                    var sec = new MzSector { C = raw[q], H = raw[q + 1], R = raw[q + 2], N = raw[q + 3] };
                    int st1 = raw[q + 4], st2 = raw[q + 5];
                    int len = ext ? BitConverter.ToUInt16(raw, q + 6) : 128 << Math.Min(6, defN);
                    if (len == 0) len = 128 << Math.Min(6, (int)sec.N);
                    sec.CrcError = (st2 & 0x20) != 0; sec.IdCrcError = (st1 & 0x20) != 0 && (st2 & 0x20) == 0;
                    sec.Deleted = (st2 & 0x40) != 0;
                    int n = Math.Min(len, Math.Max(0, raw.Length - dp));
                    // weak/multiple copies: keep the first copy
                    int want = 128 << Math.Min(6, (int)sec.N);
                    sec.Data = new byte[Math.Min(n, Math.Max(want, 128))];
                    Array.Copy(raw, dp, sec.Data, 0, sec.Data.Length);
                    dp += len;
                    Track(cyl, head).Add(sec);
                }
                p += tsize;
            }
    }

    void LoadRaw(byte[] raw)
    {
        Format = "RAW";
        int n = raw.Length / 256, idx = 0;
        for (int c = 0; c < MAXCYL && idx < n; c++)
            for (int h = 0; h < 2 && idx < n; h++)
                for (int r = 1; r <= 16 && idx < n; r++, idx++)
                {
                    var sec = new MzSector { C = c, H = h, R = r, N = 1, Data = new byte[256] };
                    Array.Copy(raw, idx * 256, sec.Data, 0, 256);
                    Track(c, h).Add(sec);
                }
    }

    // ---------------------------------------------------------------- saving
    public void Save() { Save(Path); }

    public void Save(string path)
    {
        string ext = System.IO.Path.GetExtension(path).ToLowerInvariant();
        byte[] b = ext == ".dsk" ? SaveEdsk() : ext == ".2d" || ext == ".img" || ext == ".raw" ? SaveRaw() : SaveD88();
        File.WriteAllBytes(path, b);
        Path = path; Dirty = false;
    }

    byte[] SaveD88()
    {
        var ms = new MemoryStream();
        var hdr = new byte[0x2B0];
        var nm = Encoding.ASCII.GetBytes(System.IO.Path.GetFileNameWithoutExtension(Path));
        Array.Copy(nm, hdr, Math.Min(16, nm.Length));
        hdr[0x1A] = (byte)(WriteProtect ? 0x10 : 0); hdr[0x1B] = 0x00;          // 2D
        ms.Write(hdr, 0, hdr.Length);
        var offs = new int[164];
        for (int t = 0; t < 164; t++)
        {
            var tr = Track(t >> 1, t & 1);
            if (tr.Count == 0) continue;
            offs[t] = (int)ms.Length;
            foreach (var s in tr)
            {
                var sh = new byte[16];
                sh[0] = (byte)s.C; sh[1] = (byte)s.H; sh[2] = (byte)s.R; sh[3] = (byte)s.N;
                sh[4] = (byte)tr.Count; sh[5] = (byte)(tr.Count >> 8);
                sh[7] = (byte)(s.Deleted ? 0x10 : 0); sh[8] = (byte)(s.CrcError ? 0xB0 : s.IdCrcError ? 0xA0 : 0);
                sh[14] = (byte)s.Data.Length; sh[15] = (byte)(s.Data.Length >> 8);
                ms.Write(sh, 0, 16); ms.Write(s.Data, 0, s.Data.Length);
            }
        }
        var b = ms.ToArray();
        Array.Copy(BitConverter.GetBytes(b.Length), 0, b, 0x1C, 4);
        for (int t = 0; t < 164; t++) Array.Copy(BitConverter.GetBytes(offs[t]), 0, b, 0x20 + t * 4, 4);
        return b;
    }

    byte[] SaveEdsk()
    {
        int ncyl = Math.Max(1, Cylinders), nsd = 2;
        for (int c = 0; c < MAXCYL; c++) for (int h = 0; h < 2; h++) if (Tracks[c, h].Count > 0) ncyl = Math.Max(ncyl, c + 1);
        var ms = new MemoryStream();
        var hdr = new byte[0x100];
        var sig = Encoding.ASCII.GetBytes("EXTENDED CPC DSK File\r\nDisk-Info\r\nMZ700onPC     ");
        Array.Copy(sig, hdr, Math.Min(sig.Length, 0x30));
        hdr[0x30] = (byte)ncyl; hdr[0x31] = (byte)nsd;
        ms.Write(hdr, 0, hdr.Length);
        for (int c = 0; c < ncyl; c++)
            for (int h = 0; h < nsd; h++)
            {
                var tr = Tracks[c, h];
                if (tr.Count == 0) { hdr[0x34 + c * nsd + h] = 0; continue; }
                int dataLen = 0; foreach (var s in tr) dataLen += s.Data.Length;
                int tsize = (0x100 + dataLen + 255) & ~255;
                var tb = new byte[tsize];
                Array.Copy(Encoding.ASCII.GetBytes("Track-Info\r\n"), tb, 12);
                tb[0x10] = (byte)c; tb[0x11] = (byte)h; tb[0x14] = (byte)tr[0].N; tb[0x15] = (byte)tr.Count; tb[0x16] = 0x4E; tb[0x17] = 0xE5;
                int dp = 0x100;
                for (int i = 0; i < tr.Count; i++)
                {
                    var s = tr[i]; int q = 0x18 + i * 8;
                    tb[q] = (byte)s.C; tb[q + 1] = (byte)s.H; tb[q + 2] = (byte)s.R; tb[q + 3] = (byte)s.N;
                    tb[q + 4] = (byte)(s.CrcError || s.IdCrcError ? 0x20 : 0); tb[q + 5] = (byte)((s.CrcError ? 0x20 : 0) | (s.Deleted ? 0x40 : 0));
                    tb[q + 6] = (byte)s.Data.Length; tb[q + 7] = (byte)(s.Data.Length >> 8);
                    Array.Copy(s.Data, 0, tb, dp, s.Data.Length); dp += s.Data.Length;
                }
                hdr[0x34 + c * nsd + h] = (byte)(tsize / 256);
                ms.Write(tb, 0, tb.Length);
            }
        var b = ms.ToArray(); Array.Copy(hdr, b, 0x100);
        return b;
    }

    byte[] SaveRaw()
    {
        var ms = new MemoryStream();
        for (int c = 0; c < Math.Max(40, Cylinders); c++)
            for (int h = 0; h < 2; h++)
                for (int r = 1; r <= 16; r++)
                {
                    var s = Find(c, h, r);
                    var d = new byte[256];
                    if (s != null) Array.Copy(s.Data, d, Math.Min(256, s.Data.Length));
                    ms.Write(d, 0, 256);
                }
        return ms.ToArray();
    }

    public MzSector Find(int cyl, int head, int r)
    {
        foreach (var s in Track(cyl, head)) if (s.R == r) return s;
        return null;
    }

    // ---------------------------------------------------------------- Sharp logical records
    public static void LogicalPlace(int rec, out int cyl, out int head, out int sec)
    {
        int lt = rec / 16; cyl = lt >> 1; head = (lt & 1) ^ 1; sec = rec % 16 + 1;
    }

    /// <summary>A logical record as the CPU sees it (uninverted), or null.</summary>
    public byte[] ReadRecord(int rec)
    {
        int c, h, r; LogicalPlace(rec, out c, out h, out r);
        var s = Find(c, h, r); if (s == null) return null;
        var d = new byte[256]; for (int i = 0; i < 256; i++) d[i] = (byte)~(i < s.Data.Length ? s.Data[i] : 0xFF);
        return d;
    }

    public void WriteRecord(int rec, byte[] cpuData)
    {
        int c, h, r; LogicalPlace(rec, out c, out h, out r);
        var s = Find(c, h, r); if (s == null) throw new InvalidOperationException("record " + rec + " is not on the disk");
        for (int i = 0; i < s.Data.Length; i++) s.Data[i] = (byte)~(i < cpuData.Length ? cpuData[i] : 0);
        Dirty = true;
    }

    /// <summary>A formatted MZ 2D disk: 40 cylinders, 2 heads, 16 x 256-byte sectors, logically all zero.</summary>
    public static MzDisk Blank(string path)
    {
        var d = new MzDisk(); d.Path = path; d.Format = "EDSK"; d.Cylinders = 40;
        for (int c = 0; c < 40; c++)
            for (int h = 0; h < 2; h++)
                for (int r = 1; r <= 16; r++)
                {
                    var data = new byte[256]; for (int i = 0; i < 256; i++) data[i] = 0xFF;
                    d.Tracks[c, h].Add(new MzSector { C = c, H = h, R = r, N = 1, Data = data });
                }
        return d;
    }

    /// <summary>A bootable disk: the IPL record plus the program from record 1 (what the MZ-1E05 boots).</summary>
    public static MzDisk FromProgram(string path, string name, byte[] body, int load, int exec)
    {
        var d = Blank(path);
        if (body.Length > 2559 * 256) throw new InvalidDataException("program too large for a 2D disk");
        var ipl = new byte[256];
        ipl[0] = 3; Array.Copy(Encoding.ASCII.GetBytes("IPLPRO"), 0, ipl, 1, 6);
        for (int i = 7; i < 7 + 13; i++) ipl[i] = 0x0D;
        var nb = Encoding.ASCII.GetBytes(name.ToUpperInvariant()); Array.Copy(nb, 0, ipl, 7, Math.Min(12, nb.Length));
        ipl[0x14] = (byte)body.Length; ipl[0x15] = (byte)(body.Length >> 8);
        ipl[0x16] = (byte)load; ipl[0x17] = (byte)(load >> 8);
        ipl[0x18] = (byte)exec; ipl[0x19] = (byte)(exec >> 8);
        ipl[0x1E] = 1;
        d.WriteRecord(0, ipl);
        for (int i = 0; i * 256 < body.Length; i++)
        {
            var rec = new byte[256]; Array.Copy(body, i * 256, rec, 0, Math.Min(256, body.Length - i * 256));
            d.WriteRecord(1 + i, rec);
        }
        return d;
    }

    /// <summary>The IPL record's name, size, load and exec, or null when the disk is not bootable.</summary>
    public string IplInfo(out int size, out int load, out int exec, out int start)
    {
        size = load = exec = start = 0;
        var b = ReadRecord(0);
        if (b == null || Encoding.ASCII.GetString(b, 1, 6) != "IPLPRO") return null;
        var sb = new StringBuilder();
        for (int i = 7; i < 7 + 13 && b[i] != 0x0D; i++) sb.Append(b[i] >= 32 && b[i] < 127 ? (char)b[i] : '?');
        size = b[0x14] | b[0x15] << 8; load = b[0x16] | b[0x17] << 8; exec = b[0x18] | b[0x19] << 8; start = b[0x1E] | b[0x1F] << 8;
        return "type " + b[0].ToString("X2") + " \"" + sb + "\"";
    }
}
