// MZ700onPC - MZ-1E05 floppy interface with MZ-1F02 drives: a Fujitsu MB8876 FDC (WD1793 family with an inverted
// data bus) at Z80 ports D8-DB, and the interface latches (CSP eMZ-700 floppy.cpp):
//   D8 command / status, D9 track, DA sector, DB data - every value complemented on the CPU side
//   DC drive register: bit 7 motor (0.56 s spin-up, 1.5 s run-on), bit 2 = latch bits 0-1 as the drive number
//   DD side (bit 0 = head), DF bit 0 = raise INT while DRQ is up (interrupt-driven transfers)
// Timing: 300 rpm (200 ms per turn), MFM double density 32 us per byte (6250 bytes a track), step rates
// 6/12/20/30 ms, 15 ms head settle. Sectors sit evenly round the track, so latency depends on where the disk is.
using System;
using System.Collections.Generic;

public sealed class MzFdc
{
    public const int DRIVES = 4;
    public readonly MzDisk[] Disk = new MzDisk[DRIVES];
    public readonly int[] HeadCyl = new int[DRIVES];

    // registers (true values; the CPU sees them complemented)
    public int Cmd, Track, Sector, Data, Status;
    public bool Busy { get { return (Status & 1) != 0; } }
    public bool Drq, Intrq;
    int lastType = 1;
    public int Drive, Side, DcReg;
    public bool Motor, IrqEnable;
    long motorEventM = -1; bool motorTarget;
    public bool InUse;                                             // any port touched: the visualiser shows the panel

    // statistics
    public long SectorsRead, SectorsWritten, LostData, Commands;
    public readonly int[] HeatR = new int[MzDisk.MAXCYL * 2], HeatW = new int[MzDisk.MAXCYL * 2];   // for the visualiser
    public string LastCmd = "";

    // timing in master clocks (17.734475 MHz)
    const double M = 17734475.0;
    public const long REV = (long)(M * 0.2);                       // one turn
    public const long BYTE = (long)(M * 32e-6 + 0.5);              // 567.5 -> 568 master clocks per byte
    const int TRACKBYTES = 6250;
    static readonly int[] stepMs = { 6, 12, 20, 30 };

    // command state
    enum St { Idle, TypeI, ReadData, WriteWait, WriteData, ReadAddr, ReadTrack, WriteTrack }
    St st = St.Idle;
    long nextM;                                                    // time of the next event
    byte[] buf; int bufPos, bufLen;
    MzSector cur;
    List<byte> wtrack;

    public Action<string> Log;

    // ---------------------------------------------------------------- CPU side
    public int In(int port, long m)
    {
        InUse = true;
        Sync(m);
        switch (port & 3)
        {
            case 0: Intrq = false; return (~StatusNow(m)) & 0xFF;
            case 1: return (~Track) & 0xFF;
            case 2: return (~Sector) & 0xFF;
            default: Drq = false; return (~Data) & 0xFF;
        }
    }

    public void Out(int port, int v, long m)
    {
        InUse = true;
        Sync(m);
        switch (port)
        {
            case 0xD8: Command(v ^ 0xFF, m); break;
            case 0xD9: Track = v ^ 0xFF; break;
            case 0xDA: Sector = v ^ 0xFF; break;
            case 0xDB: Data = v ^ 0xFF; Drq = false; break;
            case 0xDC:
                if ((v & 4) != 0) Drive = v & 3;
                bool on = (v & 0x80) != 0, was = (DcReg & 0x80) != 0;
                if (on && !was) { if (!Motor) { motorEventM = m + (long)(M * 0.56); motorTarget = true; } else motorEventM = -1; }
                else if (!on && was) { if (Motor) { motorEventM = m + (long)(M * 1.5); motorTarget = false; } else motorEventM = -1; }
                DcReg = v;
                break;
            case 0xDD: Side = v & 1; break;
            case 0xDF: IrqEnable = (v & 1) != 0; break;
        }
    }

    /// <summary>The DF-enabled interrupt request (DRQ while enabled).</summary>
    public bool IntRequest { get { return IrqEnable && Drq; } }

    MzDisk D { get { return Disk[Drive]; } }
    bool Ready { get { return Motor && D != null; } }
    public bool Active { get { return st != St.Idle || motorEventM >= 0; } }

    int StatusNow(long m)
    {
        int s = Status & ~0x80;
        if (!Ready) s |= 0x80;
        if (lastType == 1)
        {
            s &= ~0x46;
            if (D != null && D.WriteProtect) s |= 0x40;
            if (HeadCyl[Drive] == 0) s |= 0x04;
            if (Ready && (m % REV) < (long)(M * 0.004)) s |= 0x02;   // index hole, ~4 ms
        }
        else { s &= ~0x02; if (Drq) s |= 0x02; }
        return s;
    }

    // ---------------------------------------------------------------- commands
    void Command(int c, long m)
    {
        Commands++;
        if ((c & 0xF0) == 0xD0)                                      // force interrupt
        {
            LastCmd = "FORCE INT";
            if (st == St.Idle) { lastType = 1; Status = 0; }
            st = St.Idle; Status &= ~1; Drq = false;
            if ((c & 0x0F) != 0) Intrq = true;
            return;
        }
        if (Busy) return;                                            // ignored while busy
        Cmd = c; Intrq = false; Drq = false;
        int hi = c >> 4;
        if (hi < 8)
        {
            lastType = 1; Status = 1;
            int steps = 0, dir = 0;
            if (hi == 0) { LastCmd = "RESTORE"; steps = Math.Max(HeadCyl[Drive], 0); dir = -1; Track = 0; steps = HeadCyl[Drive]; }
            else if (hi == 1) { LastCmd = "SEEK " + Data; dir = Data > Track ? 1 : -1; steps = Math.Abs(Data - Track); Track = Data; }
            else
            {
                if (hi >= 4 && hi <= 5) { lastDir = 1; LastCmd = "STEP IN"; }
                else if (hi >= 6) { lastDir = -1; LastCmd = "STEP OUT"; }
                else LastCmd = "STEP";
                dir = lastDir; steps = 1;
                if ((c & 0x10) != 0) Track = (Track + dir) & 0xFF;
            }
            int cyl = HeadCyl[Drive] + dir * steps;
            if (hi == 0) cyl = 0;
            HeadCyl[Drive] = Math.Max(0, Math.Min(MzDisk.MAXCYL - 1, cyl));
            long t = m + (long)(M * 1e-3 * stepMs[c & 3]) * Math.Max(steps, 0) + 200;
            if ((c & 4) != 0)                                         // verify
            {
                t += (long)(M * 0.015);
                bool ok = Ready && FindId(Track, -1, false, t) != null;
                if (ok) t = idTime; else { t += 5 * REV; Status |= 0x10; }
            }
            if ((c & 8) != 0) Status |= 0x20;                         // head loaded
            st = St.TypeI; nextM = t;
            return;
        }
        lastType = hi < 0xC ? 2 : 3;
        Status = 1;
        if (!Ready) { Status = 0x80; Intrq = true; st = St.Idle; return; }
        long start = m + ((c & 4) != 0 ? (long)(M * 0.015) : 200);
        bool write = hi == 0xA || hi == 0xB || hi == 0xF;
        if (write && D.WriteProtect) { Status = 0x40; Intrq = true; st = St.Idle; LastCmd = "WRITE (PROTECTED)"; return; }
        switch (hi)
        {
            case 8: case 9: LastCmd = "READ " + Track + "/" + Side + "/" + Sector + ((hi & 1) != 0 ? " MULTI" : ""); StartSector(start, false); break;
            case 0xA: case 0xB: LastCmd = "WRITE " + Track + "/" + Side + "/" + Sector + ((hi & 1) != 0 ? " MULTI" : ""); StartSector(start, true); break;
            case 0xC:
                {
                    LastCmd = "READ ADDRESS";
                    var s = FindId(-1, -1, false, start);
                    if (s == null) { Fail(start + 5 * REV, 0x10); break; }
                    buf = new byte[] { (byte)s.C, (byte)s.H, (byte)s.R, (byte)s.N, 0, 0 };
                    int crc = Crc(new byte[] { 0xA1, 0xA1, 0xA1, 0xFE, buf[0], buf[1], buf[2], buf[3] }); buf[4] = (byte)(crc >> 8); buf[5] = (byte)crc;
                    bufPos = 0; bufLen = 6; cur = s; st = St.ReadAddr; nextM = idTime + BYTE * 4;
                    break;
                }
            case 0xE:
                LastCmd = "READ TRACK";
                buf = BuildTrack(D.Track(HeadCyl[Drive], Side)); bufPos = 0; bufLen = TRACKBYTES;
                st = St.ReadTrack; nextM = NextIndex(start);
                break;
            case 0xF:
                LastCmd = "WRITE TRACK";
                wtrack = new List<byte>(); Drq = true; bufPos = 0;
                st = St.WriteTrack; nextM = NextIndex(start) + BYTE * 3;
                break;
        }
    }
    int lastDir = 1;

    long idTime;
    /// <summary>The next sector ID to pass the head (after time t) that matches C / R (-1 = any) on the current
    /// cylinder and side, within five turns. Sets idTime to when its ID field ends.</summary>
    MzSector FindId(int c, int r, bool sideCmp, long t)
    {
        var tr = D == null ? null : D.Track(HeadCyl[Drive], Side);
        if (tr == null || tr.Count == 0) return null;
        long best = long.MaxValue; MzSector found = null;
        int n = tr.Count;
        for (int i = 0; i < n; i++)
        {
            var s = tr[i];
            if (c >= 0 && s.C != c) continue;
            if (r >= 0 && s.R != r) continue;
            if (sideCmp && s.H != (((Cmd >> 3) & 1))) continue;
            long pos = (146 + (long)i * (TRACKBYTES - 146) / n + 10) * BYTE;   // end of this sector's ID field
            long turn = t / REV * REV + pos; if (turn < t) turn += REV;
            if (turn < best) { best = turn; found = s; }
        }
        idTime = best;
        return found;
    }

    long NextIndex(long t) { return (t / REV + 1) * REV; }

    void StartSector(long t, bool write)
    {
        bool sideCmp = (Cmd & 2) != 0;
        var s = FindId(Track, Sector, sideCmp, t);
        if (s == null) { Fail(t + 5 * REV, 0x10); return; }
        if (s.IdCrcError) { Fail(idTime + 5 * REV, 0x18); return; }
        cur = s; bufLen = 128 << Math.Min(3, s.N); bufPos = 0;
        if (write)
        {
            buf = new byte[bufLen];
            Drq = true;                                               // DRQ 2 bytes after the ID, data needed 11 bytes later
            st = St.WriteWait; nextM = idTime + BYTE * 22;
        }
        else
        {
            buf = s.Data;
            if (s.Deleted) Status |= 0x20;
            st = St.ReadData; nextM = idTime + BYTE * 43;            // gap 2, sync and data mark
        }
    }

    void Fail(long at, int bits) { st = St.TypeI; nextM = at; Status |= bits; }

    // ---------------------------------------------------------------- time
    public void Sync(long m)
    {
        if (motorEventM >= 0 && m >= motorEventM) { Motor = motorTarget; motorEventM = -1; }
        int guard = 0;
        while (st != St.Idle && nextM <= m && guard++ < 100000) Event();
    }

    void Done(int bits)
    {
        Status = (Status | bits) & ~1;
        st = St.Idle; Intrq = true;
    }

    void Event()
    {
        switch (st)
        {
            case St.TypeI: Done(0); break;
            case St.ReadData:
            case St.ReadAddr:
            case St.ReadTrack:
                if (bufPos < bufLen)
                {
                    if (Drq) { Status |= 0x04; LostData++; }
                    Data = bufPos < buf.Length ? buf[bufPos] : 0xFF; bufPos++; Drq = true;
                    nextM += BYTE;
                    if (bufPos == bufLen) nextM += BYTE * 2;          // CRC
                    break;
                }
                if (st == St.ReadAddr) { Sector = buf[0]; Done(0); break; }
                if (st == St.ReadTrack) { Done(0); break; }
                D.Reads++; SectorsRead++; HeatR[HeadCyl[Drive] * 2 + Side] = 255;
                if (cur.CrcError) { Done(0x08); break; }
                if ((Cmd & 0x10) != 0) { Sector = (Sector + 1) & 0xFF; StartSector(nextM, false); if (st == St.TypeI) { } break; }
                Done(0);
                break;
            case St.WriteWait:
                if (Drq) { Drq = false; Status |= 0x04; LostData++; Done(0); break; }
                st = St.WriteData; nextM += BYTE * 21;                // sync, data mark
                buf[0] = (byte)Data; bufPos = 1; Drq = bufLen > 1;
                nextM += BYTE;
                break;
            case St.WriteData:
                if (bufPos < bufLen)
                {
                    if (Drq) { Status |= 0x04; LostData++; Data = 0; Drq = false; }
                    buf[bufPos++] = (byte)Data;
                    if (bufPos < bufLen) Drq = true;
                    nextM += BYTE;
                    break;
                }
                Array.Copy(buf, cur.Data, Math.Min(buf.Length, cur.Data.Length));
                cur.CrcError = false;
                if ((Cmd & 1) != 0) cur.Deleted = true; else cur.Deleted = false;
                D.Dirty = true; D.Writes++; SectorsWritten++; HeatW[HeadCyl[Drive] * 2 + Side] = 255;
                if ((Cmd & 0x10) != 0) { Sector = (Sector + 1) & 0xFF; StartSector(nextM + BYTE * 3, true); break; }
                Done(0);
                break;
            case St.WriteTrack:
                if (Drq) { Status |= 0x04; LostData++; if (wtrack.Count == 0) { Done(0); break; } Data = 0x4E; }
                wtrack.Add((byte)Data);
                if (wtrack.Count >= TRACKBYTES) { ParseTrack(); Done(0); break; }
                Drq = true; nextM += BYTE;
                break;
        }
    }

    // ---------------------------------------------------------------- whole tracks
    static int Crc(byte[] b)
    {
        int crc = 0xFFFF;
        foreach (byte x in b) { crc ^= x << 8; for (int k = 0; k < 8; k++) crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF; }
        return crc;
    }

    /// <summary>A formatted MFM track as Read Track returns it (sync marks are delivered as A1/C2).</summary>
    byte[] BuildTrack(List<MzSector> tr)
    {
        var t = new List<byte>();
        Action<int, int> fill = (v, n) => { for (int i = 0; i < n; i++) t.Add((byte)v); };
        fill(0x4E, 80); fill(0, 12); fill(0xC2, 3); t.Add(0xFC); fill(0x4E, 50);
        foreach (var s in tr)
        {
            fill(0, 12); fill(0xA1, 3);
            var id = new byte[] { 0xA1, 0xA1, 0xA1, 0xFE, (byte)s.C, (byte)s.H, (byte)s.R, (byte)s.N };
            int crc = Crc(id); for (int i = 3; i < 8; i++) t.Add(id[i]); t.Add((byte)(crc >> 8)); t.Add((byte)crc);
            fill(0x4E, 22); fill(0, 12); fill(0xA1, 3);
            var dm = new List<byte> { 0xA1, 0xA1, 0xA1, (byte)(s.Deleted ? 0xF8 : 0xFB) }; dm.AddRange(s.Data);
            crc = Crc(dm.ToArray()); if (s.CrcError) crc ^= 0xFFFF;
            t.Add(dm[3]); t.AddRange(s.Data); t.Add((byte)(crc >> 8)); t.Add((byte)crc);
            fill(0x4E, 54);
        }
        while (t.Count < TRACKBYTES) t.Add(0x4E);
        var b = t.ToArray(); if (b.Length > TRACKBYTES) Array.Resize(ref b, TRACKBYTES);
        return b;
    }

    /// <summary>Write Track: F5 writes an A1 sync mark, F6 a C2, F7 two CRC bytes; FE starts an ID, FB/F8 data.</summary>
    void ParseTrack()
    {
        var tr = D.Track(HeadCyl[Drive], Side);
        var news = new List<MzSector>();
        var w = wtrack; int i = 0;
        MzSector pending = null;
        while (i < w.Count)
        {
            if (w[i] == 0xF5)
            {
                while (i < w.Count && w[i] == 0xF5) i++;
                if (i >= w.Count) break;
                int mark = w[i++];
                if (mark == 0xFE && i + 4 <= w.Count) { pending = new MzSector { C = w[i], H = w[i + 1], R = w[i + 2], N = w[i + 3] & 3 }; i += 4; continue; }
                if ((mark == 0xFB || mark == 0xF8) && pending != null)
                {
                    int len = 128 << pending.N; pending.Data = new byte[len];
                    for (int k = 0; k < len; k++) pending.Data[k] = i + k < w.Count ? w[i + k] : (byte)0x4E;
                    pending.Deleted = mark == 0xF8;
                    i += len; news.Add(pending); pending = null; continue;
                }
                continue;
            }
            i++;
        }
        tr.Clear(); tr.AddRange(news); HeatW[HeadCyl[Drive] * 2 + Side] = 255;
        D.Dirty = true;
        if (HeadCyl[Drive] + 1 > D.Cylinders) D.Cylinders = HeadCyl[Drive] + 1;
    }

    public void Reset()
    {
        st = St.Idle; Status = 0; Drq = false; Intrq = false; lastType = 1;
        Cmd = 0; Track = 0; Sector = 1; Data = 0; DcReg = 0; Motor = false; motorEventM = -1; IrqEnable = false; Side = 0; Drive = 0;
    }

    public string StateName { get { return st.ToString().ToUpperInvariant(); } }
}
