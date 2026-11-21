// MZ700onPC main window: menus, display scaling / fullscreen, keyboard + joystick input,
// emulation thread paced by the sound card.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;

public static class MzApp
{
    [STAThread]
    public static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm(args));
        return 0;
    }
}

sealed class DisplayPanel : Panel
{
    public Action Repaint;
    public DisplayPanel() { SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.Opaque, true); BackColor = Color.Black; }
    protected override void OnPaint(PaintEventArgs e) { if (Repaint != null) Repaint(); }
}

public sealed class MainForm : Form
{
    readonly MzMachine m = new MzMachine();
    readonly ConcurrentQueue<Action> cmds = new ConcurrentQueue<Action>();
    readonly DisplayPanel display = new DisplayPanel();
    readonly MenuStrip menu = new MenuStrip();
    readonly StatusStrip status = new StatusStrip();
    readonly ToolStripStatusLabel stLeft = new ToolStripStatusLabel(), stRight = new ToolStripStatusLabel();
    Thread emuThread; volatile bool running = true;
    IntPtr displayHwnd, formHwnd;
    volatile int dispW, dispH;

    readonly string iniPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "mz700onpc.ini");
    int scale = 2;
    bool integerScale = true, showBorder = true, fullscreen = false, arrowsJoy = false, swapJoy = false, muted = false, padKeys = false;
    bool paused = false, warp = false;
    string lastProgram = null, lastDir = null;
    string message = ""; int messageFrames = 0;

    readonly object frameLock = new object();
    int[] frame = new int[MzMachine.FBW * MzMachine.FBH]; int frameW = MzMachine.FBW, frameH = MzMachine.FBH;

    readonly Queue<string[]> typeQueue = new Queue<string[]>();
    string[] typing; int typePhase, typeHold;

    double fps; Rectangle savedBounds; FormWindowState savedState;

    readonly MzVis vis;
    volatile bool visOn;
    VisForm visForm; volatile IntPtr visHwnd; volatile int visW, visH;

    public MainForm(string[] args)
    {
        Text = "MZ700onPC";
        try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
        KeyPreview = true;
        AllowDrop = true;
        vis = new MzVis(m);
        if (!Array.Exists(args, x => x == "--no-settings" || x == "--quit-after")) LoadSettings();
        ParseArgs(args);

        display.Dock = DockStyle.Fill;
        display.Repaint = BlitLatest;
        display.Resize += (s, e) => { dispW = display.ClientSize.Width; dispH = display.ClientSize.Height; BlitLatest(); };
        display.MouseDoubleClick += (s, e) => ToggleFullscreen();
        status.Items.Add(stLeft); stLeft.Spring = true; stLeft.TextAlign = ContentAlignment.MiddleLeft;
        status.Items.Add(stRight);
        BuildMenu();
        Controls.Add(display);
        Controls.Add(status);
        Controls.Add(menu);
        MainMenuStrip = menu;

        DragEnter += (s, e) => { if (e.Data.GetDataPresent(DataFormats.FileDrop)) e.Effect = DragDropEffects.Copy; };
        DragDrop += OnDrop;

        Load += (s, e) =>
        {
            displayHwnd = display.Handle; formHwnd = Handle;
            dispW = display.ClientSize.Width; dispH = display.ClientSize.Height;
            ApplyScale();
            if (fullscreen) { fullscreen = false; ToggleFullscreen(); }
            if (visOn) { visOn = false; ToggleVis(); }
            Joysticks.Scan();
            emuThread = new Thread(EmuLoop) { IsBackground = true, Name = "emulation" };
            emuThread.Start();
            var t = new System.Windows.Forms.Timer { Interval = 500 }; t.Tick += (s2, e2) => UpdateStatus(); t.Start();
            if (quitAfter > 0)
            {
                var q = new System.Windows.Forms.Timer { Interval = (int)(quitAfter * 1000) };
                q.Tick += (s2, e2) =>
                {
                    q.Stop();
                    UpdateStatus(); Refresh();
                    if (shotPath != null)
                    {
                        CaptureWindow(this, shotPath);
                        if (visForm != null) CaptureWindow(visForm, Path.ChangeExtension(shotPath, null) + "_vis.png");
                    }
                    Console.WriteLine("fps " + fps.ToString("0.0"));
                    Close();
                };
                q.Start();
            }
        };
        FormClosing += (s, e) => { running = false; if (emuThread != null) emuThread.Join(1000); if (m.TapeOut.Recording) m.TapeOut.Stop(m.NowM); if (diskWriteBack) SaveDisksNow(false); if (!noSettings) SaveSettings(); };

        m.Log = s => ShowMessage(s);
        m.Quiet = true;
        cmds.Enqueue(() =>
        {
            PowerOnNow();
            if (startProgram != null) LaunchNow(startProgram);
            if (autoType != null) { typeHold = startProgram == null && m.HasRom ? 60 : 0; TypeString(autoType); }
            if (startTape != null) InsertTapeNow(startTape, true);
            if (startDisk[1] != null) InsertDiskNow(1, startDisk[1], false);
            if (startDisk[0] != null) InsertDiskNow(0, startDisk[0], startProgram == null);
        });
    }

    static void CaptureWindow(Form f, string path)
    {
        var r = f.RectangleToScreen(f.ClientRectangle);
        using (var bmp = new Bitmap(r.Width, r.Height))
        {
            using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(r.Location, Point.Empty, r.Size);
            bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
        }
    }

    string startProgram, shotPath, autoType, startTape; double quitAfter; bool noSettings;
    void ParseArgs(string[] args)
    {
        noSettings = Array.Exists(args, x => x == "--no-settings" || x == "--quit-after");
        for (int i = 0; i < args.Length; i++)
        {
            string a = args[i].ToLowerInvariant();
            string v = i + 1 < args.Length ? args[i + 1] : "";
            if (a == "--scale") { int.TryParse(v, out scale); i++; }
            else if (a == "--fullscreen") fullscreen = true;
            else if (a == "--window") fullscreen = false;
            else if (a == "--shot") { shotPath = Path.GetFullPath(v); i++; }
            else if (a == "--quit-after") { double.TryParse(v, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out quitAfter); i++; }
            else if (a == "--type") { autoType = v.Replace("\\r", "\r"); i++; }
            else if (a == "--tape") { startTape = Path.GetFullPath(v); i++; }
            else if (a == "--pcg") { v = v.ToLowerInvariant(); m.Pcg = v.Contains("700") ? PcgType.Pcg700 : v.Contains("1500") ? PcgType.Mz1500 : PcgType.None; i++; }
            else if (a == "--rom") { m.UseRom = v.ToLowerInvariant() != "none"; i++; }
            else if (a == "--vramwait") { SetWaitMode(v.ToLowerInvariant()); i++; }
            else if (a == "--fasttape") { m.FastTape = v != "0" && v != "off"; i++; }
            else if (a == "--border") { showBorder = v != "0"; i++; }
            else if (a == "--integer") { integerScale = v != "0"; i++; }
            else if (a == "--no-settings") { }
            else if (a == "--vis") visOn = true;
            else if (a == "--psg") { m.PsgOn = v != "0" && v != "off"; i++; }
            else if (a == "--floppy") { m.FloppyOn = v != "0" && v != "off"; i++; }
            else if (a == "--disk" || a == "--disk1") { startDisk[0] = Path.GetFullPath(v); i++; }
            else if (a == "--disk2") { startDisk[1] = Path.GetFullPath(v); i++; }
            else if (File.Exists(args[i]) && IsDiskName(args[i])) startDisk[0] = Path.GetFullPath(args[i]);
            else if (File.Exists(args[i])) startProgram = Path.GetFullPath(args[i]);
        }
    }
    void SetWaitMode(string v)
    {
        if (v == "off") m.VramWait = VramWaitMode.Off;
        else if (v.StartsWith("disp")) { m.VramWait = VramWaitMode.Display; m.WaitW0 = 128; m.WaitW1 = 208; }
        else if (v.StartsWith("cons")) { m.VramWait = VramWaitMode.All; m.WaitW0 = 128; m.WaitW1 = 191; }
        else { m.VramWait = VramWaitMode.All; m.WaitW0 = 128; m.WaitW1 = 208; }
    }
    string WaitModeName { get { return m.VramWait == VramWaitMode.Off ? "off" : m.VramWait == VramWaitMode.Display ? "display" : m.WaitW1 <= 191 ? "conservative" : "accurate"; } }

    // ------------------------------------------------------------------ menus
    ToolStripMenuItem miRom, miJp, miPcgNone, miPcg700, miPcg1500, miWaitAcc, miWaitCons, miWaitDisp, miWaitOff, miJoy, miFastTape,
        miBorder, miVis, miInteger, miMono, miStatus, miFull, miArrowsJoy, miArrowsCursor, miPadJoy, miPadKeys, miSwap, miPause, miWarp, miMute, miJoyList,
        miTapePlay, miTapeStop, miRec, miRecStop, miPsg, miFloppy, miWriteBack;
    ToolStripMenuItem[] miDiskEject = new ToolStripMenuItem[2], miDiskProt = new ToolStripMenuItem[2];
    bool diskWriteBack = true;
    string[] startDisk = new string[2];
    ToolStripMenuItem[] miScale = new ToolStripMenuItem[6];

    static ToolStripMenuItem Item(string text, Keys keys, EventHandler click)
    {
        var mi = new ToolStripMenuItem(text, null, click);
        if (keys != Keys.None) mi.ShortcutKeys = keys;
        return mi;
    }

    void BuildMenu()
    {
        var file = new ToolStripMenuItem("&File");
        file.DropDownItems.Add(Item("Load program (.MZT / .MZF)...", Keys.F3, (s, e) => OpenProgramDialog()));
        file.DropDownItems.Add(Item("Reload last program", Keys.F5, (s, e) => { if (lastProgram != null) Launch(lastProgram); }));
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(Item("Insert tape (MZT, or WAV / FLAC / MP3 audio)...", Keys.F2, (s, e) => OpenTapeDialog()));
        miTapePlay = Item("Tape: press PLAY", Keys.None, (s, e) => cmds.Enqueue(() => { m.Cass.Play(m.NowM); ShowMessage("Tape playing"); }));
        miTapeStop = Item("Tape: STOP", Keys.None, (s, e) => cmds.Enqueue(() => { m.Cass.Stop(m.NowM); ShowMessage("Tape stopped"); }));
        file.DropDownItems.Add(miTapePlay);
        file.DropDownItems.Add(miTapeStop);
        file.DropDownItems.Add(Item("Tape: rewind", Keys.None, (s, e) => cmds.Enqueue(() => { m.Cass.Rewind(); ShowMessage("Tape rewound"); })));
        file.DropDownItems.Add(Item("Tape: eject", Keys.None, (s, e) => cmds.Enqueue(() => { m.Cass.Eject(); ShowMessage("Tape ejected"); })));
        miFastTape = Item("Fast tape loading (the monitor's tape reads happen at once)", Keys.None, (s, e) => cmds.Enqueue(() => { m.FastTape = !m.FastTape; ShowMessage(m.FastTape ? "Fast tape loading on" : "Tapes load at real speed: type L and RETURN"); }));
        file.DropDownItems.Add(miFastTape);
        miRec = Item("Record tape output (SAVE) to .MZT or .WAV...", Keys.None, (s, e) => RecordDialog());
        miRecStop = Item("Stop recording", Keys.None, (s, e) => cmds.Enqueue(StopRecordingNow));
        file.DropDownItems.Add(miRec);
        file.DropDownItems.Add(miRecStop);
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(Item("Paste text as typing", Keys.F7, (s, e) => PasteText()));
        file.DropDownItems.Add(Item("Save screenshot", Keys.F12, (s, e) => Screenshot()));
        file.DropDownItems.Add(Item("Open the screenshots folder", Keys.None, (s, e) => { string d = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "screenshots"); Directory.CreateDirectory(d); Process.Start("explorer.exe", "\"" + d + "\""); }));
        file.DropDownItems.Add(new ToolStripSeparator());
        file.DropDownItems.Add(Item("Exit", Keys.None, (s, e) => Close()));

        var disk = new ToolStripMenuItem("&Disk");
        for (int d = 0; d < 2; d++)
        {
            int dn = d;
            disk.DropDownItems.Add(Item("Insert disk in drive " + (dn + 1) + " (.D88 / .DSK / .2D)...", dn == 0 ? Keys.Control | Keys.F2 : Keys.None, (s, e) => OpenDiskDialog(dn, false)));
        }
        disk.DropDownItems.Add(Item("Insert a disk in drive 1 and boot it...", Keys.Control | Keys.F3, (s, e) => OpenDiskDialog(0, true)));
        disk.DropDownItems.Add(Item("Boot drive 1 (the monitor's F command)", Keys.None, (s, e) => cmds.Enqueue(BootDiskNow)));
        disk.DropDownItems.Add(new ToolStripSeparator());
        for (int d = 0; d < 2; d++)
        {
            int dn = d;
            miDiskEject[dn] = Item("Eject drive " + (dn + 1), Keys.None, (s, e) => cmds.Enqueue(() => EjectDiskNow(dn)));
            miDiskProt[dn] = Item("Write-protect drive " + (dn + 1), Keys.None, (s, e) => cmds.Enqueue(() => { var dk = m.Fdc.Disk[dn]; if (dk != null) { dk.WriteProtect = !dk.WriteProtect; ShowMessage("Drive " + (dn + 1) + (dk.WriteProtect ? " write-protected" : " writable")); } }));
        }
        disk.DropDownItems.AddRange(new ToolStripItem[] { miDiskEject[0], miDiskEject[1], miDiskProt[0], miDiskProt[1], new ToolStripSeparator() });
        miWriteBack = Item("Write disk changes back to the image file (on eject and exit)", Keys.None, (s, e) => { diskWriteBack = !diskWriteBack; });
        disk.DropDownItems.Add(miWriteBack);
        disk.DropDownItems.Add(Item("Save disk changes now", Keys.None, (s, e) => cmds.Enqueue(() => SaveDisksNow(true))));
        disk.DropDownItems.Add(new ToolStripSeparator());
        disk.DropDownItems.Add(Item("New blank formatted disk...", Keys.None, (s, e) => NewDiskDialog()));
        disk.DropDownItems.Add(Item("Make a boot disk from an .MZT...", Keys.None, (s, e) => MakeBootDiskDialog()));

        var mach = new ToolStripMenuItem("&Machine");
        miRom = Item("Monitor ROM 1Z-013A (roms\\1z013a.rom)", Keys.None, (s, e) => Reconfigure(() => m.UseRom = !m.UseRom));
        miJp = Item("Japanese character ROM (roms\\mz700fon.jpn)", Keys.None, (s, e) => Reconfigure(() => m.Japanese = !m.Japanese));
        var pcg = new ToolStripMenuItem("Character generator expansion");
        miPcgNone = Item("None (CG-ROM only)", Keys.None, (s, e) => Reconfigure(() => m.Pcg = PcgType.None));
        miPcg700 = Item("HAL PCG-700 (E010-E012, codes 80-FF)", Keys.None, (s, e) => Reconfigure(() => m.Pcg = PcgType.Pcg700));
        miPcg1500 = Item("MZ-1500 colour PCG (ports E5/E6, F0/F1, 3 planes)", Keys.None, (s, e) => Reconfigure(() => m.Pcg = PcgType.Mz1500));
        pcg.DropDownItems.AddRange(new ToolStripItem[] { miPcgNone, miPcg700, miPcg1500 });
        var wait = new ToolStripMenuItem("VRAM wait states");
        miWaitAcc = Item("Accurate: free only in T 128-208 of every line (Takeda's eMZ-700)", Keys.None, (s, e) => cmds.Enqueue(() => { SetWaitMode("accurate"); ShowMessage("VRAM waits: T 128-208 free on every line"); }));
        miWaitCons = Item("Conservative: free only in T 128-191 (63 T, as measured on NTSC)", Keys.None, (s, e) => cmds.Enqueue(() => { SetWaitMode("conservative"); ShowMessage("VRAM waits: T 128-191 free on every line"); }));
        miWaitDisp = Item("Display lines only (VBLANK free)", Keys.None, (s, e) => cmds.Enqueue(() => { SetWaitMode("display"); ShowMessage("VRAM waits: picture lines only"); }));
        miWaitOff = Item("Off (no waits, faster than the real machine)", Keys.None, (s, e) => cmds.Enqueue(() => { SetWaitMode("off"); ShowMessage("VRAM waits off"); }));
        wait.DropDownItems.AddRange(new ToolStripItem[] { miWaitAcc, miWaitCons, miWaitDisp, miWaitOff });
        miJoy = Item("MZ-1X03 joysticks on E008", Keys.None, (s, e) => cmds.Enqueue(() => m.Joystick = m.Joystick == JoyType.None ? JoyType.Mz1x03 : JoyType.None));
        miFloppy = Item("MZ-1E05 floppy interface + MZ-1F02 drives (ports D8-DF, ROM F000)", Keys.None, (s, e) => cmds.Enqueue(() => { m.FloppyOn = !m.FloppyOn; ShowMessage(m.FloppyOn ? "Floppy interface fitted: " + m.FdRomName + " at F000 (type F at the monitor)" : "Floppy interface removed"); }));
        miPsg = Item("MZ-1500 PSG sound (2 x SN76489, ports E9 / F2 / F3)", Keys.None, (s, e) => cmds.Enqueue(() => { m.PsgOn = !m.PsgOn; m.PsgL.Reset(); m.PsgR.Reset(); ShowMessage(m.PsgOn ? "MZ-1500 PSG fitted" : "MZ-1500 PSG removed"); }));
        mach.DropDownItems.AddRange(new ToolStripItem[] { miRom, miJp, pcg, wait, miJoy, miPsg, miFloppy, new ToolStripSeparator() });
        mach.DropDownItems.Add(Item("Power cycle", Keys.F4, (s, e) => cmds.Enqueue(PowerOnNow)));
        mach.DropDownItems.Add(Item("Reset (the RESET switch)", Keys.Shift | Keys.F4, (s, e) => cmds.Enqueue(() => m.Reset())));
        miPause = Item("Pause", Keys.F6, (s, e) => { paused = !paused; });
        miWarp = Item("Warp speed", Keys.F9, (s, e) => { warp = !warp; });
        miMute = Item("Mute sound", Keys.F8, (s, e) => { muted = !muted; });
        mach.DropDownItems.AddRange(new ToolStripItem[] { miPause, miWarp, miMute });

        var view = new ToolStripMenuItem("&View");
        for (int i = 1; i <= 5; i++)
        {
            int s0 = i;
            miScale[i] = Item(i == 1 ? "1:1 pixels (x1)" : "Scale x" + i, Keys.None, (s, e) => { scale = s0; if (fullscreen) ToggleFullscreen(); ApplyScale(); });
            view.DropDownItems.Add(miScale[i]);
        }
        view.DropDownItems.Add(new ToolStripSeparator());
        miVis = Item("Visualiser   (F10)", Keys.None, (s, e) => ToggleVis());
        view.DropDownItems.Add(miVis);
        view.DropDownItems.Add(new ToolStripSeparator());
        miInteger = Item("Whole-pixel scaling only (sharp)", Keys.None, (s, e) => { integerScale = !integerScale; BlitLatest(); });
        miFull = Item("Fullscreen   (F11 / Alt+Enter)", Keys.F11, (s, e) => ToggleFullscreen());
        miBorder = Item("Show border", Keys.None, (s, e) => { showBorder = !showBorder; ApplyScale(); });
        miMono = Item("Monochrome TV", Keys.None, (s, e) => { m.Mono = !m.Mono; });
        miStatus = Item("Status bar", Keys.None, (s, e) => { status.Visible = !status.Visible; ApplyScale(); });
        view.DropDownItems.AddRange(new ToolStripItem[] { miInteger, miFull, new ToolStripSeparator(), miBorder, miMono, miStatus });

        var input = new ToolStripMenuItem("&Input");
        miArrowsCursor = Item("Arrow keys = MZ cursor keys", Keys.None, (s, e) => arrowsJoy = false);
        miArrowsJoy = Item("Arrow keys + Right Ctrl / Right Shift = MZ-1X03 joystick 1", Keys.None, (s, e) => arrowsJoy = true);
        miPadJoy = Item("PC gamepads = MZ-1X03 joysticks (analogue)", Keys.None, (s, e) => padKeys = false);
        miPadKeys = Item("PC gamepad 1 = cursor keys, SPACE and RETURN (for keyboard games)", Keys.None, (s, e) => padKeys = true);
        miSwap = Item("Swap joysticks 1 and 2", Keys.None, (s, e) => swapJoy = !swapJoy);
        miJoyList = new ToolStripMenuItem("PC joysticks found: 0") { Enabled = false };
        input.DropDownItems.AddRange(new ToolStripItem[] { miArrowsCursor, miArrowsJoy, new ToolStripSeparator(), miPadJoy, miPadKeys, miSwap,
            Item("Rescan joysticks", Keys.None, (s, e) => { Joysticks.Scan(); ShowMessage(Joysticks.Count + " joystick(s): " + string.Join(", ", Joysticks.Names)); }), miJoyList });

        var help = new ToolStripMenuItem("&Help");
        help.DropDownItems.Add(Item("Keys and controls", Keys.F1, (s, e) => MessageBox.Show(this, HelpText, "MZ700onPC keys")));
        help.DropDownItems.Add(Item("About", Keys.None, (s, e) => MessageBox.Show(this,
            "MZ700onPC - Sharp MZ-700 (PAL) emulator\n\nZ80, 8253, 8255, colour text video with VRAM wait states, PCG-700 and MZ-1500 PCG, " +
            "MZ-1X03 joysticks, data recorder, sound, visualiser.\n\nMonitor: " + (m.HasRom ? m.RomName : "none (built-in stub)") +
            "\nCharacter ROM: " + m.FontName + "\nROM folder: " + MzMachine.RomDir, "About MZ700onPC")));

        menu.Items.AddRange(new ToolStripItem[] { file, disk, mach, view, input, help });
        menu.MenuActivate += (s, e) => SyncMenu();
    }

    const string HelpText =
        "MZ keyboard: letters, digits, SPACE, RETURN, SHIFT, CTRL and the punctuation keys.\n" +
        "  Backspace / Delete = DEL    Insert = INST    Esc = BREAK (SHIFT+Esc = SHIFT+BREAK)\n" +
        "  ` = @    [ ] = [ ]    ' = :    Home = ALPHA    End = GRAPH    Ctrl+F1..F5 = MZ F1..F5\n\n" +
        "Arrow keys: MZ cursor keys, or joystick 1 (Input menu; Right Ctrl and Right Shift are its buttons).\n" +
        "PC gamepads are MZ-1X03 joysticks (analogue sticks work), or cursor keys + SPACE / RETURN for keyboard games.\n\n" +
        "F1 help   F2 insert tape   F3 load program   F4 power cycle   F5 reload program\n" +
        "F6 pause   F7 paste text   F8 mute   F9 warp   F10 visualiser   F11 / Alt+Enter fullscreen   F12 screenshot\n" +
        "Drop an .MZT / .MZF on the window to run it; drop a .WAV to put it in the data recorder.\n" +
        "Drop a .D88 / .DSK disk image to boot it. Ctrl+F2 inserts a disk, Ctrl+F3 inserts and boots; F at the monitor boots drive 1.";

    void SyncMenu()
    {
        miRom.Checked = m.UseRom; miJp.Checked = m.Japanese;
        miPcgNone.Checked = m.Pcg == PcgType.None; miPcg700.Checked = m.Pcg == PcgType.Pcg700; miPcg1500.Checked = m.Pcg == PcgType.Mz1500;
        string wm = WaitModeName;
        miWaitAcc.Checked = wm == "accurate"; miWaitCons.Checked = wm == "conservative"; miWaitDisp.Checked = wm == "display"; miWaitOff.Checked = wm == "off";
        miJoy.Checked = m.Joystick == JoyType.Mz1x03;
        miPsg.Checked = m.PsgOn; miFloppy.Checked = m.FloppyOn; miWriteBack.Checked = diskWriteBack;
        for (int d = 0; d < 2; d++)
        {
            var dk = m.Fdc.Disk[d];
            miDiskEject[d].Enabled = dk != null; miDiskProt[d].Enabled = dk != null; miDiskProt[d].Checked = dk != null && dk.WriteProtect;
            miDiskEject[d].Text = "Eject drive " + (d + 1) + (dk != null ? " (" + dk.Name + (dk.Dirty ? ", changed" : "") + ")" : "");
        }
        miFastTape.Checked = m.FastTape;
        miTapePlay.Enabled = m.Cass.HasTape; miTapeStop.Enabled = m.Cass.HasTape;
        miRec.Enabled = !m.TapeOut.Recording; miRecStop.Enabled = m.TapeOut.Recording;
        for (int i = 1; i <= 5; i++) miScale[i].Checked = scale == i && !fullscreen;
        miVis.Checked = visOn;
        miInteger.Checked = integerScale; miFull.Checked = fullscreen; miBorder.Checked = showBorder; miMono.Checked = m.Mono; miStatus.Checked = status.Visible;
        miArrowsJoy.Checked = arrowsJoy; miArrowsCursor.Checked = !arrowsJoy; miPadJoy.Checked = !padKeys; miPadKeys.Checked = padKeys; miSwap.Checked = swapJoy;
        miPause.Checked = paused; miWarp.Checked = warp; miMute.Checked = muted;
        miJoyList.Text = "PC joysticks found: " + (Joysticks.Count == 0 ? "none" : string.Join(", ", Joysticks.Names));
    }

    void Reconfigure(Action change)
    {
        cmds.Enqueue(() =>
        {
            change();
            if (lastProgram != null && sessionProgram && File.Exists(lastProgram)) LaunchNow(lastProgram);
            else PowerOnNow();
            ShowMessage(ConfigText());
        });
    }
    bool sessionProgram;

    void PowerOnNow()
    {
        sessionProgram = false;
        m.PowerOn();
        ShowMessage(m.HasRom ? "Power on: monitor " + m.RomName : "Power on: no monitor ROM (roms\\1z013a.rom) - press F3 to load a program");
        BeginInvoke((Action)(() => Text = "MZ700onPC"));
    }

    string ConfigText()
    {
        string s = "MZ-700" + (m.HasRom ? "" : " (no monitor ROM)");
        if (m.Pcg == PcgType.Pcg700) s += " + PCG-700"; else if (m.Pcg == PcgType.Mz1500) s += " + MZ-1500 PCG";
        if (m.Joystick == JoyType.Mz1x03) s += " + 2 x MZ-1X03";
        if (m.PsgOn) s += " + MZ-1500 PSG";
        if (m.FloppyOn) s += " + MZ-1E05 floppy";
        if (m.Japanese) s += ", Japanese CG-ROM";
        s += ", VRAM waits " + WaitModeName;
        return s;
    }

    // ------------------------------------------------------------------ loading
    void Launch(string path) { cmds.Enqueue(() => LaunchNow(path)); }

    void LaunchNow(string path)
    {
        try
        {
            typeQueue.Clear(); typing = null;
            var b = m.LaunchMzt(path);
            vis.FindSymbols(path);
            lastProgram = path; lastDir = Path.GetDirectoryName(path); sessionProgram = true;
            string name = Path.GetFileName(path);
            BeginInvoke((Action)(() => Text = "MZ700onPC - " + name));
            ShowMessage("Loaded " + name + ": \"" + b.Name + "\" at " + b.Load.ToString("X4") + "h, run " + b.Exec.ToString("X4") + "h" + (vis.SymFile != null ? ", symbols " + Path.GetFileName(vis.SymFile) : ""));
        }
        catch (Exception ex) { ShowMessage("Can't load " + Path.GetFileName(path) + ": " + ex.Message); }
    }

    void InsertTapeNow(string p, bool play)
    {
        try
        {
            if (MzTapeFile.IsTapeName(p)) m.Cass.InsertMzt(MzTapeFile.Load(p));
            else m.Cass.InsertAudio(VzTape.Load(p, 0));
            if (play) m.Cass.Play(m.NowM);
            ShowMessage("Tape: " + Path.GetFileName(p) + (m.FastTape && m.Cass.File != null ? " - type L and RETURN to load it (fast)" : " - PLAY pressed; type L and RETURN"));
        }
        catch (Exception ex) { ShowMessage("Tape: " + ex.Message); }
    }

    void OpenProgramDialog()
    {
        using (var d = new OpenFileDialog { Filter = "MZ-700 programs (*.mzt;*.mzf;*.m12)|*.mzt;*.mzf;*.m12|All files|*.*", InitialDirectory = lastDir ?? "" })
            if (d.ShowDialog(this) == DialogResult.OK) Launch(d.FileName);
    }
    void OpenTapeDialog()
    {
        using (var d = new OpenFileDialog { Filter = "Tapes (*.mzt;*.mzf;*.m12;*.wav;*.flac;*.mp3)|*.mzt;*.mzf;*.m12;*.wav;*.flac;*.mp3|All files|*.*", InitialDirectory = lastDir ?? "", Title = "Put a tape in the data recorder" })
            if (d.ShowDialog(this) == DialogResult.OK) { string p = d.FileName; cmds.Enqueue(() => InsertTapeNow(p, true)); }
    }
    void RecordDialog()
    {
        using (var f = new SaveFileDialog { Filter = "MZ tape file, decoded (*.mzt)|*.mzt|WAV audio (*.wav)|*.wav", FileName = "saved.mzt", Title = "Record the cassette output to" })
            if (f.ShowDialog(this) == DialogResult.OK)
            {
                string p = f.FileName;
                cmds.Enqueue(() => { m.TapeOut.Start(p, m.NowM, (m.PortC & 2) != 0); ShowMessage("Recording to " + Path.GetFileName(p) + ": SAVE now, then File > Stop recording"); });
            }
    }
    void StopRecordingNow()
    {
        if (!m.TapeOut.Recording) return;
        try { ShowMessage("Tape out: " + m.TapeOut.Stop(m.NowM)); } catch (Exception ex) { ShowMessage("Tape: " + ex.Message); }
    }

    void OnDrop(object sender, DragEventArgs e)
    {
        var files = (string[])e.Data.GetData(DataFormats.FileDrop);
        if (files == null || files.Length == 0) return;
        string p = files[0];
        if (IsDiskName(p)) { cmds.Enqueue(() => InsertDiskNow(0, p, true)); return; }
        if (MzTapeFile.IsTapeName(p)) Launch(p);
        else if (p.EndsWith(".wav", StringComparison.OrdinalIgnoreCase) || p.EndsWith(".flac", StringComparison.OrdinalIgnoreCase) || p.EndsWith(".mp3", StringComparison.OrdinalIgnoreCase))
            cmds.Enqueue(() => InsertTapeNow(p, true));
        else Launch(p);
    }

    // ------------------------------------------------------------------ floppy disks
    static bool IsDiskName(string p)
    {
        string e = Path.GetExtension(p).ToLowerInvariant();
        return e == ".d88" || e == ".d77" || e == ".d68" || e == ".dsk" || e == ".2d";
    }

    void InsertDiskNow(int drive, string p, bool boot)
    {
        try
        {
            if (diskWriteBack && m.Fdc.Disk[drive] != null && m.Fdc.Disk[drive].Dirty) m.Fdc.Disk[drive].Save();
            var d = MzDisk.Load(p);
            m.Fdc.Disk[drive] = d; m.FloppyOn = true;
            lastDir = Path.GetDirectoryName(p);
            int sz, ld, ex, st; string ipl = d.IplInfo(out sz, out ld, out ex, out st);
            if (boot)
            {
                string r = m.BootDisk();
                lastProgram = null; sessionProgram = false;
                string name = Path.GetFileName(p);
                BeginInvoke((Action)(() => Text = "MZ700onPC - " + name));
                ShowMessage("Drive 1: " + name + " - " + r);
            }
            else ShowMessage("Drive " + (drive + 1) + ": " + d.Name + " (" + d.Format + ")" + (ipl != null ? ", boot disk " + ipl : "") + (m.HasRom ? " - type F at the monitor to boot" : ""));
        }
        catch (Exception ex) { ShowMessage("Disk: " + ex.Message); }
    }

    void EjectDiskNow(int drive)
    {
        var d = m.Fdc.Disk[drive]; if (d == null) return;
        try { if (diskWriteBack && d.Dirty) d.Save(); } catch (Exception ex) { ShowMessage("Disk: can't save " + d.Name + ": " + ex.Message); return; }
        m.Fdc.Disk[drive] = null;
        ShowMessage("Drive " + (drive + 1) + " ejected" + (d.Writes > 0 ? (diskWriteBack ? ", changes saved" : ", changes discarded") : ""));
    }

    void SaveDisksNow(bool report)
    {
        int n = 0;
        for (int i = 0; i < MzFdc.DRIVES; i++)
        {
            var d = m.Fdc.Disk[i];
            if (d == null || !d.Dirty) continue;
            try { d.Save(); n++; } catch (Exception ex) { if (report) ShowMessage("Disk: can't save " + d.Name + ": " + ex.Message); }
        }
        if (report) ShowMessage(n == 0 ? "No disk changes to save" : "Saved " + n + " disk image(s)");
    }

    void BootDiskNow()
    {
        string r = m.BootDisk();
        lastProgram = null; sessionProgram = false;
        ShowMessage("Boot: " + r);
    }

    void OpenDiskDialog(int drive, bool boot)
    {
        using (var d = new OpenFileDialog { Filter = "Floppy disk images (*.d88;*.d77;*.dsk;*.2d)|*.d88;*.d77;*.d68;*.dsk;*.2d|All files|*.*", InitialDirectory = lastDir ?? "", Title = boot ? "Boot a disk in drive 1" : "Insert a disk in drive " + (drive + 1) })
            if (d.ShowDialog(this) == DialogResult.OK) { string p = d.FileName; cmds.Enqueue(() => InsertDiskNow(drive, p, boot)); }
    }

    void NewDiskDialog()
    {
        using (var f = new SaveFileDialog { Filter = "Extended DSK (*.dsk)|*.dsk|D88 (*.d88)|*.d88", FileName = "blank.dsk", Title = "New blank formatted MZ disk (40 x 2 x 16 x 256)" })
            if (f.ShowDialog(this) == DialogResult.OK)
            {
                string p = f.FileName;
                cmds.Enqueue(() =>
                {
                    try { MzDisk.Blank(p).Save(); InsertDiskNow(m.Fdc.Disk[0] != null && m.Fdc.Disk[1] == null ? 1 : 0, p, false); }
                    catch (Exception ex) { ShowMessage("Disk: " + ex.Message); }
                });
            }
    }

    void MakeBootDiskDialog()
    {
        string src;
        using (var d = new OpenFileDialog { Filter = "MZ-700 programs (*.mzt;*.mzf)|*.mzt;*.mzf|All files|*.*", InitialDirectory = lastDir ?? "", Title = "Program to put on a boot disk" })
        { if (d.ShowDialog(this) != DialogResult.OK) return; src = d.FileName; }
        using (var f = new SaveFileDialog { Filter = "Extended DSK (*.dsk)|*.dsk|D88 (*.d88)|*.d88", FileName = Path.GetFileNameWithoutExtension(src) + ".dsk", Title = "Save the boot disk as" })
        {
            if (f.ShowDialog(this) != DialogResult.OK) return;
            string p = f.FileName;
            cmds.Enqueue(() =>
            {
                try
                {
                    var t = MzTapeFile.Load(src); var b = t.Blocks[0];
                    MzDisk.FromProgram(p, b.Name, b.Data, b.Load, b.Exec).Save();
                    InsertDiskNow(0, p, true);
                    if (t.Blocks.Count > 1) ShowMessage("Boot disk made from the first tape block only; this program loads more from tape");
                }
                catch (Exception ex) { ShowMessage("Disk: " + ex.Message); }
            });
        }
    }


    void PasteText()
    {
        if (!Clipboard.ContainsText()) { ShowMessage("Clipboard has no text"); return; }
        string t = Clipboard.GetText().Replace("\r\n", "\r").Replace('\n', '\r');
        cmds.Enqueue(() => TypeString(t));
    }
    void TypeString(string s) { foreach (char c in s) { var k = MzMachine.CharKeys(c); if (k != null) typeQueue.Enqueue(k); } }

    void Screenshot()
    {
        int[] px; int w, h;
        lock (frameLock) { px = (int[])frame.Clone(); w = frameW; h = frameH; }
        string dir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "screenshots");
        Directory.CreateDirectory(dir);
        string name = (lastProgram != null ? Path.GetFileNameWithoutExtension(lastProgram) : "MZ700") + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".png";
        Headless.SavePng(Path.Combine(dir, name), px, w, h, 2);
        ShowMessage("Saved screenshots\\" + name);
    }

    // ------------------------------------------------------------------ display
    void ApplyScale()
    {
        if (fullscreen) return;
        int w = showBorder ? MzMachine.FBW : 320, h = showBorder ? MzMachine.FBH : 200;
        if (WindowState == FormWindowState.Maximized) WindowState = FormWindowState.Normal;
        ClientSize = new Size(w * scale, h * scale + (menu.Visible ? menu.Height : 0) + (status.Visible ? status.Height : 0));
        BlitLatest();
    }

    void ToggleFullscreen()
    {
        fullscreen = !fullscreen;
        if (fullscreen)
        {
            savedBounds = Bounds; savedState = WindowState;
            menu.Visible = false; status.Visible = false;
            FormBorderStyle = FormBorderStyle.None;
            WindowState = FormWindowState.Normal;
            Bounds = Screen.FromControl(this).Bounds;
            Cursor.Hide();
        }
        else
        {
            FormBorderStyle = FormBorderStyle.Sizable;
            menu.Visible = true; status.Visible = true;
            Bounds = savedBounds; WindowState = savedState;
            Cursor.Show();
        }
        UpdateVisWindow();
        BlitLatest();
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == (Keys.Alt | Keys.Enter)) { ToggleFullscreen(); return true; }
        if (keyData == Keys.F10) { ToggleVis(); return true; }
        if (keyData == Keys.Menu || keyData == (Keys.Alt | Keys.Menu)) return true;
        if ((keyData & Keys.Control) != 0 && (keyData & Keys.KeyCode) >= Keys.F1 && (keyData & Keys.KeyCode) <= Keys.F5) return true;   // MZ F1-F5
        return base.ProcessCmdKey(ref msg, keyData);
    }
    protected override void OnKeyDown(KeyEventArgs e) { e.Handled = true; e.SuppressKeyPress = true; }

    void BlitLatest()
    {
        if (displayHwnd == IntPtr.Zero) return;
        lock (frameLock) Present(frame, frameW, frameH);
    }

    void Present(int[] px, int w, int h)
    {
        int cw = dispW, ch = dispH;
        if (cw <= 0 || ch <= 0) return;
        if (fullscreen && visOn) { PresentWithSidebars(px, w, h, cw, ch); return; }
        PresentVisWindow();
        int dw, dh;
        if (integerScale) { int s = Math.Max(1, Math.Min(cw / w, ch / h)); dw = w * s; dh = h * s; }
        else { double s = Math.Min((double)cw / w, (double)ch / h); dw = (int)(w * s); dh = (int)(h * s); }
        Native.Blit(displayHwnd, px, w, h, cw, ch, (cw - dw) / 2, (ch - dh) / 2, dw, dh);
    }

    void PresentWithSidebars(int[] px, int w, int h, int cw, int ch)
    {
        int s = Math.Min((cw - 2 * MzVis.W) / w, ch / h);
        if (s < 1) s = Math.Max(1, Math.Min(cw / 2 / w, ch / h));
        int dw = w * s, dh = h * s;
        int side = (cw - dw) / 2;
        var parts = new List<Native.Part>();
        parts.Add(new Native.Part { Px = px, W = w, H = h, X = side, Y = (ch - dh) / 2, DW = dw, DH = dh });
        double k = Math.Min((double)side / MzVis.W, (double)ch / MzVis.H);
        if (k >= 2) k = Math.Floor(k); else if (k > 1) k = 1;
        int pw = (int)(MzVis.W * k), ph = (int)(MzVis.H * k);
        int py = (ch - ph) / 2;
        parts.Add(new Native.Part { Px = vis.Left, W = MzVis.W, H = MzVis.H, X = (side - pw) / 2, Y = py, DW = pw, DH = ph });
        parts.Add(new Native.Part { Px = vis.Right, W = MzVis.W, H = MzVis.H, X = side + dw + (cw - side - dw - pw) / 2, Y = py, DW = pw, DH = ph });
        Native.BlitParts(displayHwnd, cw, ch, parts);
    }

    void PresentVisWindow()
    {
        IntPtr hw = visHwnd; int cw = visW, ch = visH;
        if (hw == IntPtr.Zero || cw <= 0 || ch <= 0 || fullscreen) return;
        double k = Math.Min((double)cw / (2 * MzVis.W), (double)ch / MzVis.H);
        if (k >= 2) k = Math.Floor(k); else if (k > 1) k = 1;
        int pw = (int)(MzVis.W * k), ph = (int)(MzVis.H * k);
        int x0 = (cw - 2 * pw) / 2;
        var parts = new List<Native.Part>();
        parts.Add(new Native.Part { Px = vis.Left, W = MzVis.W, H = MzVis.H, X = x0, Y = 0, DW = pw, DH = ph });
        parts.Add(new Native.Part { Px = vis.Right, W = MzVis.W, H = MzVis.H, X = x0 + pw, Y = 0, DW = pw, DH = ph });
        Native.BlitParts(hw, cw, ch, parts);
    }

    void ToggleVis()
    {
        visOn = !visOn;
        bool on = visOn;
        cmds.Enqueue(() =>
        {
            if (on) { if (m.Tr == null) m.Tr = new MzTrace(m); vis.T = m.Tr; if (vis.Sym.Count == 0 && lastProgram != null) vis.FindSymbols(lastProgram); }
            else { m.Tr = null; vis.T = null; }
        });
        if (on) ShowMessage("Visualiser on (F10 to close)");
        UpdateVisWindow();
        BlitLatest();
    }

    void UpdateVisWindow()
    {
        bool want = visOn && !fullscreen;
        if (want && visForm == null)
        {
            var f = new VisForm(this);
            var wa = Screen.FromControl(this).WorkingArea;
            int ch = Math.Min(MzVis.H, wa.Height - 40);
            int cw = (int)Math.Round(2.0 * MzVis.W * ch / MzVis.H);
            f.ClientSize = new Size(cw, ch);
            f.StartPosition = FormStartPosition.Manual;
            int x = Right + 4; if (x + f.Width > wa.Right) x = Math.Max(wa.Left, wa.Right - f.Width);
            int extra = f.Height - f.ClientSize.Height;
            if (f.Height > wa.Height) { ch = wa.Height - extra; cw = (int)Math.Round(2.0 * MzVis.W * ch / MzVis.H); f.ClientSize = new Size(cw, ch); }
            f.Location = new Point(x, wa.Top);
            f.Panel.Resize += (s, e) => { visW = f.Panel.ClientSize.Width; visH = f.Panel.ClientSize.Height; };
            f.Panel.Repaint = () => { lock (frameLock) PresentVisWindow(); };
            f.FormClosed += (s, e) =>
            {
                if (visForm != f) return;
                visHwnd = IntPtr.Zero; visForm = null;
                if (!fullscreen && visOn) { visOn = false; cmds.Enqueue(() => { m.Tr = null; vis.T = null; }); }
            };
            visForm = f;
            f.Show(this);
            visW = f.Panel.ClientSize.Width; visH = f.Panel.ClientSize.Height;
            visHwnd = f.Panel.Handle;
            Activate();
        }
        else if (!want && visForm != null)
        {
            var f = visForm; visHwnd = IntPtr.Zero; visForm = null; f.Close();
        }
    }

    void ShowMessage(string s) { message = s; messageFrames = 200; }

    void UpdateStatus()
    {
        stLeft.Text = messageFrames > 0 ? message : ConfigText();
        string st = "";
        var c = m.Cass;
        if (c.HasTape && (c.Motor || c.PlayPressed)) st += "TAPE " + (c.Motor ? ">" : "||") + " " + (int)(c.Seconds / 60) + ":" + ((int)c.Seconds % 60).ToString("00") + "  ";
        if (m.TapeOut.Recording) st += "REC  ";
        if (m.FloppyOn && m.Fdc.Motor) st += "FD" + (m.Fdc.Drive + 1) + " " + m.Fdc.HeadCyl[m.Fdc.Drive] + "/" + m.Fdc.Side + (m.Fdc.Busy ? " *" : "") + "  ";
        stRight.Text = st + (paused ? "PAUSED  " : "") + (warp ? "WARP  " : "") + (muted ? "MUTE  " : "") + fps.ToString("0") + " fps";
    }

    // ------------------------------------------------------------------ input
    static readonly int[] letterVk = new int[36];
    static readonly string[] letterKey = new string[36];
    static MainForm()
    {
        for (int i = 0; i < 26; i++) { letterVk[i] = 'A' + i; letterKey[i] = ((char)('A' + i)).ToString(); }
        for (int i = 0; i < 10; i++) { letterVk[26 + i] = '0' + i; letterKey[26 + i] = ((char)('0' + i)).ToString(); }
    }

    void K(string k) { m.SetKey(k, true); }

    void PollInput()
    {
        for (int i = 0; i < 10; i++) m.Keys[i] = 0xFF;
        double[] jx = new double[2], jy = new double[2]; bool[] ja = new bool[2], jb = new bool[2];
        bool focused = Native.GetForegroundWindow() == formHwnd;
        if (focused)
        {
            bool ctrl = Native.KeyDown(0xA2) || (!arrowsJoy && Native.KeyDown(0xA3));
            bool fkey = false;
            for (int i = 0; i < 5; i++) if (ctrl && Native.KeyDown(0x70 + i)) { K("F" + (i + 1)); fkey = true; }
            for (int i = 0; i < 36; i++) if (Native.KeyDown(letterVk[i])) K(letterKey[i]);
            if (Native.KeyDown(0x20)) K("SPACE");
            if (Native.KeyDown(0x0D)) K("CR");
            if (Native.KeyDown(0xA0) || (!arrowsJoy && Native.KeyDown(0xA1))) K("SHIFT");
            if (ctrl && !fkey) K("CTRL");
            if (Native.KeyDown(0xBC)) K(",");
            if (Native.KeyDown(0xBE)) K(".");
            if (Native.KeyDown(0xBD)) K("-");
            if (Native.KeyDown(0xBA)) K(";");
            if (Native.KeyDown(0xDE)) K(":");
            if (Native.KeyDown(0xBF)) K("/");
            if (Native.KeyDown(0xBB)) K("=");
            if (Native.KeyDown(0xC0)) K("@");
            if (Native.KeyDown(0xDB)) K("[");
            if (Native.KeyDown(0xDD)) K("]");
            if (Native.KeyDown(0xDC)) K("\\");
            if (Native.KeyDown(0x08) || Native.KeyDown(0x2E)) K("DEL");
            if (Native.KeyDown(0x2D)) K("INST");
            if (Native.KeyDown(0x1B)) K("BREAK");
            if (Native.KeyDown(0x24)) K("ALPHA");
            if (Native.KeyDown(0x23)) K("GRAPH");
            bool up = Native.KeyDown(0x26), dn = Native.KeyDown(0x28), lf = Native.KeyDown(0x25), rt = Native.KeyDown(0x27);
            if (arrowsJoy)
            {
                if (up) jy[0] = -1; if (dn) jy[0] = 1; if (lf) jx[0] = -1; if (rt) jx[0] = 1;
                if (Native.KeyDown(0xA3)) ja[0] = true;
                if (Native.KeyDown(0xA1)) jb[0] = true;
            }
            else { if (up) K("UP"); if (dn) K("DOWN"); if (lf) K("LEFT"); if (rt) K("RIGHT"); }
        }
        for (int n = 0; n < 2; n++)
        {
            double x, y; int b;
            if (!Joysticks.ReadAnalog(n, out x, out y, out b)) continue;
            int j = swapJoy ? 1 - n : n;
            if (padKeys && n == 0)
            {
                if (x < -0.5) K("LEFT"); if (x > 0.5) K("RIGHT"); if (y < -0.5) K("UP"); if (y > 0.5) K("DOWN");
                if ((b & 5) != 0) K("SPACE"); if ((b & 0xA) != 0) K("CR");
                continue;
            }
            if (x != 0) jx[j] = x; if (y != 0) jy[j] = y;
            if ((b & 5) != 0) ja[j] = true; if ((b & 0xA) != 0) jb[j] = true;
        }
        for (int j = 0; j < 2; j++) { m.JoyX[j] = jx[j]; m.JoyY[j] = jy[j]; m.JoyA[j] = ja[j]; m.JoyB[j] = jb[j]; }

        if (typeHold > 0) typeHold--;
        else if (typing == null && typeQueue.Count > 0) { typing = typeQueue.Dequeue(); typePhase = 0; }
        if (typing != null)
        {
            if (typePhase < 3) foreach (var k in typing) m.SetKey(k, true);
            if (++typePhase >= 6) typing = null;
        }
    }

    // ------------------------------------------------------------------ emulation thread
    void EmuLoop()
    {
        Native.timeBeginPeriod(1);
        WaveOut wave = null;
        try { wave = new WaveOut(MzMachine.RATE); } catch { wave = null; }
        var sw = Stopwatch.StartNew();
        double nextT = 0; int fpsFrames = 0; double fpsT = 0;
        try
        {
            while (running)
            {
                Action c;
                while (cmds.TryDequeue(out c)) { try { c(); } catch (Exception ex) { ShowMessage(ex.Message); } }
                if (messageFrames > 0) messageFrames--;
                if (paused) { Thread.Sleep(20); nextT = sw.Elapsed.TotalMilliseconds; BlitLatest(); continue; }

                PollInput();
                m.AudioOn = !warp && wave != null && wave.Ok;
                m.RunFrame();
                if (vis.T != null && visOn) vis.Render();

                int w, h; int[] px = m.Snapshot(showBorder, out w, out h);
                lock (frameLock) { frame = px; frameW = w; frameH = h; Present(px, w, h); }

                fpsFrames++;
                double now = sw.Elapsed.TotalMilliseconds;
                if (now - fpsT >= 1000) { fps = fpsFrames * 1000.0 / (now - fpsT); fpsFrames = 0; fpsT = now; }

                if (warp) { nextT = now; continue; }
                double frameMs = 1000.0 * MzMachine.FRAME_M / MzMachine.MCLK;
                if (m.AudioOn)
                {
                    if (muted) for (int i = 0; i < m.AudioN; i++) m.Audio[i] = 0;
                    wave.Write(m.Audio, m.AudioN);
                    int guard = 0;
                    while (running && wave.Queued > 3 && guard++ < 100) Thread.Sleep(1);
                    nextT = sw.Elapsed.TotalMilliseconds;
                }
                else
                {
                    nextT += frameMs;
                    double wait = nextT - sw.Elapsed.TotalMilliseconds;
                    if (wait > 1) Thread.Sleep((int)wait);
                    else if (wait < -100) nextT = sw.Elapsed.TotalMilliseconds;
                }
            }
        }
        finally
        {
            if (wave != null) wave.Dispose();
            Native.timeEndPeriod(1);
        }
    }

    // ------------------------------------------------------------------ settings
    void LoadSettings()
    {
        if (!File.Exists(iniPath)) return;
        foreach (var line in File.ReadAllLines(iniPath))
        {
            int eq = line.IndexOf('='); if (eq < 0) continue;
            string k = line.Substring(0, eq).Trim().ToLowerInvariant(), v = line.Substring(eq + 1).Trim();
            try
            {
                switch (k)
                {
                    case "rom": m.UseRom = v == "1"; break;
                    case "japanese": m.Japanese = v == "1"; break;
                    case "pcg": m.Pcg = (PcgType)Enum.Parse(typeof(PcgType), v); break;
                    case "vramwait": SetWaitMode(v); break;
                    case "joystick": m.Joystick = v == "1" ? JoyType.Mz1x03 : JoyType.None; break;
                    case "fasttape": m.FastTape = v == "1"; break;
                    case "psg": m.PsgOn = v == "1"; break;
                    case "floppy": m.FloppyOn = v == "1"; break;
                    case "diskwriteback": diskWriteBack = v == "1"; break;
                    case "scale": scale = Math.Max(1, Math.Min(5, int.Parse(v))); break;
                    case "integerscale": integerScale = v == "1"; break;
                    case "border": showBorder = v == "1"; break;
                    case "fullscreen": fullscreen = v == "1"; break;
                    case "mono": m.Mono = v == "1"; break;
                    case "arrowsjoystick": arrowsJoy = v == "1"; break;
                    case "padkeys": padKeys = v == "1"; break;
                    case "swapjoysticks": swapJoy = v == "1"; break;
                    case "muted": muted = v == "1"; break;
                    case "visualiser": visOn = v == "1"; break;
                    case "lastprogram": lastProgram = File.Exists(v) ? v : null; break;
                    case "lastdir": lastDir = Directory.Exists(v) ? v : null; break;
                }
            }
            catch { }
        }
    }

    void SaveSettings()
    {
        try
        {
            File.WriteAllLines(iniPath, new[] {
                "rom=" + (m.UseRom ? 1 : 0), "japanese=" + (m.Japanese ? 1 : 0), "pcg=" + m.Pcg, "vramwait=" + WaitModeName,
                "joystick=" + (m.Joystick == JoyType.Mz1x03 ? 1 : 0), "fasttape=" + (m.FastTape ? 1 : 0),
                "psg=" + (m.PsgOn ? 1 : 0), "floppy=" + (m.FloppyOn ? 1 : 0), "diskwriteback=" + (diskWriteBack ? 1 : 0),
                "scale=" + scale, "integerscale=" + (integerScale ? 1 : 0), "border=" + (showBorder ? 1 : 0),
                "fullscreen=" + (fullscreen ? 1 : 0), "mono=" + (m.Mono ? 1 : 0),
                "arrowsjoystick=" + (arrowsJoy ? 1 : 0), "padkeys=" + (padKeys ? 1 : 0), "swapjoysticks=" + (swapJoy ? 1 : 0), "muted=" + (muted ? 1 : 0), "visualiser=" + (visOn ? 1 : 0),
                "lastprogram=" + (lastProgram ?? ""), "lastdir=" + (lastDir ?? "") });
        }
        catch { }
    }
}

/// <summary>The visualiser's own window (used when the emulator isn't fullscreen).</summary>
sealed class VisForm : Form
{
    public readonly DisplayPanel Panel = new DisplayPanel();
    public VisForm(Form owner)
    {
        Text = "MZ700onPC visualiser";
        try { Icon = owner.Icon; } catch { }
        Panel.Dock = DockStyle.Fill;
        Controls.Add(Panel);
        KeyPreview = true;
        KeyDown += (s, e) => { if (e.KeyCode == Keys.F10 || e.KeyCode == Keys.Escape) Close(); };
    }
}
