@echo off
rem Builds MZ700onPC.exe (the emulator window) and mzemu.exe (headless test runner)
rem with the C# compiler that ships with Windows (.NET Framework 4). No installs needed.
setlocal
cd /d "%~dp0"
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
set CORE=src\Z80.cs src\Z80Dis.cs src\Font6847.cs src\MfAudio.cs src\Tape.cs src\Pit.cs src\Cmt.cs src\Psg.cs src\Disk.cs src\Fdc.cs src\FdIpl.cs src\Machine.cs src\Trace.cs src\Vis.cs src\Headless.cs
set REFS=-r:System.Drawing.dll -r:System.Windows.Forms.dll

"%CSC%" -nologo -optimize+ -target:exe -out:mzemu.exe -main:Headless %REFS% %CORE%
if errorlevel 1 exit /b 1
if "%1"=="headless" goto done
"%CSC%" -nologo -optimize+ -target:winexe -out:MZ700onPC.exe -main:MzApp -win32icon:src\mz.ico %REFS% %CORE% src\WinIO.cs src\MainForm.cs
if errorlevel 1 exit /b 1
:done
echo Built MZ700onPC.exe and mzemu.exe
