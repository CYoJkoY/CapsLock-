#Requires -Version 5.1
<#
.SYNOPSIS
    Measurement helpers for comparing CapsLock- builds (issue #46).

.DESCRIPTION
    This module contains everything the release-compiler evaluation needs to
    produce reproducible numbers for a compiled CapsLock- executable:

      * executable size and hash
      * cold-start time, defined as "time from launch until the process is idle"
      * idle working set / private bytes / GDI + USER objects / CPU
      * hotkey-to-observable-effect latency
      * a resident-feature soak with before/after handle and memory deltas

    Everything is measured from outside the process. Nothing in CapsLock- has
    to be instrumented, so the same harness measures the current compiler
    output and an AHKCompiler output under exactly the same conditions.

    Requires Windows. Run on an otherwise idle machine - see
    docs/build/compiler-evaluation.md for the required machine state.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Virtual key codes
# ---------------------------------------------------------------------------
$script:VK_CAPITAL = [byte]0x14   # CapsLock
$script:VK_SHIFT   = [byte]0x10
$script:VK_CONTROL = [byte]0x11
$script:VK_MENU    = [byte]0x12   # Alt
$script:VK_ESCAPE  = [byte]0x1B
$script:VK_BACK    = [byte]0x08

$script:GWL_EXSTYLE = -20
$script:WS_EX_TOPMOST = 0x00000008

$script:Keys = @{
    A = [byte]0x41; C = [byte]0x43; D = [byte]0x44; F = [byte]0x46
    H = [byte]0x48; J = [byte]0x4A; K = [byte]0x4B; L = [byte]0x4C
    O = [byte]0x4F; P = [byte]0x50; Q = [byte]0x51; S = [byte]0x53
    T = [byte]0x54; V = [byte]0x56; W = [byte]0x57; X = [byte]0x58
    Z = [byte]0x5A
}

# ---------------------------------------------------------------------------
# Win32 interop
# ---------------------------------------------------------------------------

$script:NativeReady = $false

function Initialize-BenchNative {
    <#
    .SYNOPSIS
        Compiles the Win32 interop class once per session.
    #>
    if ($script:NativeReady) { return }

    if (-not ('CapsLockBench.Native' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace CapsLockBench
{
    public static class Native
    {
        public const uint KEYEVENTF_KEYUP = 0x0002;
        public const uint CF_UNICODETEXT  = 13;
        public const uint GMEM_MOVEABLE   = 0x0002;
        public const uint GMEM_ZEROINIT   = 0x0040;

        [DllImport("user32.dll")]
        public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, IntPtr dwExtraInfo);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")]
        public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", EntryPoint = "GetWindowLong")]
        public static extern IntPtr GetWindowLong32(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll")]
        public static extern uint GetClipboardSequenceNumber();

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern uint GetGuiResources(IntPtr hProcess, uint uiFlags);

        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

        [DllImport("kernel32.dll")]
        public static extern bool CloseHandle(IntPtr hObject);

        [DllImport("user32.dll")]
        public static extern bool OpenClipboard(IntPtr hWndNewOwner);

        [DllImport("user32.dll")]
        public static extern bool CloseClipboard();

        [DllImport("user32.dll")]
        public static extern bool EmptyClipboard();

        [DllImport("user32.dll")]
        public static extern IntPtr SetClipboardData(uint uFormat, IntPtr hMem);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GlobalAlloc(uint uFlags, UIntPtr dwBytes);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GlobalLock(IntPtr hMem);

        [DllImport("kernel32.dll")]
        public static extern bool GlobalUnlock(IntPtr hMem);

        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        // GetWindowLongPtr only exists as an export on 64-bit Windows; the
        // 32-bit build has to fall back to GetWindowLong.
        public static IntPtr GetWindowLongSafe(IntPtr hWnd, int nIndex)
        {
            if (IntPtr.Size == 8) { return GetWindowLongPtr64(hWnd, nIndex); }
            return GetWindowLong32(hWnd, nIndex);
        }

        public static void KeyDown(byte vk) { keybd_event(vk, 0, 0, IntPtr.Zero); }

        public static void KeyUp(byte vk) { keybd_event(vk, 0, KEYEVENTF_KEYUP, IntPtr.Zero); }

        public static void Tap(byte vk) { KeyDown(vk); KeyUp(vk); }

        public static bool IsTopmost(IntPtr hWnd)
        {
            long style = GetWindowLongSafe(hWnd, -20).ToInt64();
            return (style & 0x00000008L) != 0;
        }

        public static List<IntPtr> VisibleWindowsOfProcess(uint pid)
        {
            List<IntPtr> result = new List<IntPtr>();
            EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
            {
                uint windowPid;
                GetWindowThreadProcessId(hWnd, out windowPid);
                if (windowPid == pid && IsWindowVisible(hWnd)) { result.Add(hWnd); }
                return true;
            }, IntPtr.Zero);
            return result;
        }

        public static bool SetClipboardText(string text)
        {
            if (!OpenClipboard(IntPtr.Zero)) { return false; }
            try
            {
                if (!EmptyClipboard()) { return false; }
                byte[] bytes = Encoding.Unicode.GetBytes(text + "\0");
                IntPtr hMem = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, (UIntPtr)bytes.Length);
                if (hMem == IntPtr.Zero) { return false; }
                IntPtr p = GlobalLock(hMem);
                if (p == IntPtr.Zero) { return false; }
                Marshal.Copy(bytes, 0, p, bytes.Length);
                GlobalUnlock(hMem);
                return SetClipboardData(CF_UNICODETEXT, hMem) != IntPtr.Zero;
            }
            finally
            {
                CloseClipboard();
            }
        }
    }
}
'@
    }

    $script:NativeReady = $true
}

# ---------------------------------------------------------------------------
# Small utilities
# ---------------------------------------------------------------------------

function Wait-BenchCondition {
    <#
    .SYNOPSIS
        Spins until a condition becomes true or the timeout expires.

    .DESCRIPTION
        Uses Thread.Sleep(0) rather than Start-Sleep so polling resolution is
        not limited to the Windows timer tick (~15.6 ms). That matters: the
        hotkey latencies being measured are of that order.
    #>
    param(
        [Parameter(Mandatory = $true)] [scriptblock] $Condition,
        [int] $TimeoutMs = 5000
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalMilliseconds -lt $TimeoutMs) {
        if ((& $Condition) -eq $true) { return $true }
        [System.Threading.Thread]::Sleep(0)
    }
    return $false
}

function Send-KeyTap {
    param([Parameter(Mandatory = $true)] [byte] $Key, [int] $DelayMs = 15)

    Initialize-BenchNative
    [CapsLockBench.Native]::Tap($Key) | Out-Null
    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
}

function Send-Chord {
    <#
    .SYNOPSIS
        Holds modifiers down, taps a key, and releases the modifiers.
    #>
    param(
        [Parameter(Mandatory = $true)] [byte] $Key,
        [byte[]] $Modifiers = @(),
        [int] $DelayMs = 15,
        [int] $SettleMs = 60
    )

    Initialize-BenchNative

    foreach ($m in $Modifiers) { [CapsLockBench.Native]::KeyDown($m) | Out-Null }

    # Give AutoHotkey time to observe the modifier before the key is pressed;
    # #HotIf is evaluated when the hotkey fires, not when the modifier changes.
    if ($SettleMs -gt 0) { Start-Sleep -Milliseconds $SettleMs }

    [CapsLockBench.Native]::Tap($Key) | Out-Null

    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

    for ($i = $Modifiers.Length - 1; $i -ge 0; $i--) {
        [CapsLockBench.Native]::KeyUp($Modifiers[$i]) | Out-Null
    }
}

function Get-BenchPercentile {
    param(
        [Parameter(Mandatory = $true)] [double[]] $Values,
        [Parameter(Mandatory = $true)] [double] $Percentile
    )

    if ($Values.Length -eq 0) { return 0.0 }

    $sorted = $Values | Sort-Object
    if ($sorted.Length -eq 1) { return [double]$sorted[0] }

    $rank = ($Percentile / 100.0) * ($sorted.Length - 1)
    $lower = [int][math]::Floor($rank)
    $upper = [int][math]::Ceiling($rank)

    if ($lower -eq $upper) { return [double]$sorted[$lower] }

    $fraction = $rank - $lower
    return [double]($sorted[$lower] + ($sorted[$upper] - $sorted[$lower]) * $fraction)
}

function Get-BenchSummary {
    param([Parameter(Mandatory = $true)] [double[]] $Values)

    if ($Values.Length -eq 0) {
        return @{ n = 0; min = 0; p50 = 0; p95 = 0; max = 0; mean = 0 }
    }

    $sum = 0.0
    foreach ($v in $Values) { $sum += $v }

    return @{
        n    = $Values.Length
        min  = [math]::Round((Get-BenchPercentile -Values $Values -Percentile 0), 2)
        p50  = [math]::Round((Get-BenchPercentile -Values $Values -Percentile 50), 2)
        p95  = [math]::Round((Get-BenchPercentile -Values $Values -Percentile 95), 2)
        max  = [math]::Round((Get-BenchPercentile -Values $Values -Percentile 100), 2)
        mean = [math]::Round(($sum / $Values.Length), 2)
    }
}

# ---------------------------------------------------------------------------
# Environment and artifact facts
# ---------------------------------------------------------------------------

function Get-BenchEnvironment {
    <#
    .SYNOPSIS
        Records everything that has to be identical between two benchmark runs
        for their results to be comparable.
    #>

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $plan = Get-CimInstance -Namespace 'root\cimv2\power' -ClassName Win32_PowerPlan -ErrorAction SilentlyContinue |
        Where-Object { $_.IsActive } | Select-Object -First 1

    return @{
        timestamp_utc   = (Get-Date).ToUniversalTime().ToString('o')
        machine         = $env:COMPUTERNAME
        os_caption      = $os.Caption
        os_version      = $os.Version
        os_build        = $os.BuildNumber
        cpu             = $cpu.Name
        cpu_cores       = [int]$env:NUMBER_OF_PROCESSORS
        ram_gb          = [math]::Round(($os.TotalVisibleMemorySize / 1MB), 2)
        power_plan      = if ($plan) { $plan.ElementName } else { 'unknown' }
        ps_version      = $PSVersionTable.PSVersion.ToString()
        dotnet_clr      = $PSVersionTable.CLRVersion.ToString()
        session_id      = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    }
}

function Get-BenchFileFacts {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $item = Get-Item -LiteralPath $Path
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash

    $version = $null
    try {
        $vi = $item.VersionInfo
        if ($vi -and $vi.FileVersion) { $version = $vi.FileVersion }
    } catch {
        $version = $null
    }

    return @{
        path         = $item.FullName
        name         = $item.Name
        size_bytes   = [int64]$item.Length
        size_kb      = [math]::Round(($item.Length / 1KB), 1)
        sha256       = $hash
        file_version = $version
    }
}

# ---------------------------------------------------------------------------
# Process metrics
# ---------------------------------------------------------------------------

function Get-BenchProcessSnapshot {
    param([Parameter(Mandatory = $true)] [int] $Id)

    Initialize-BenchNative

    $p = Get-Process -Id $Id

    $handle = [CapsLockBench.Native]::OpenProcess(0x1000, $false, [uint32]$Id)  # PROCESS_QUERY_LIMITED_INFORMATION
    $gdi = -1
    $user = -1
    if ($handle -ne [IntPtr]::Zero) {
        try {
            $gdi = [int][CapsLockBench.Native]::GetGuiResources($handle, 0)   # GR_GDIOBJECTS
            $user = [int][CapsLockBench.Native]::GetGuiResources($handle, 1)  # GR_USEROBJECTS
        } finally {
            [CapsLockBench.Native]::CloseHandle($handle) | Out-Null
        }
    }

    return @{
        utc             = (Get-Date).ToUniversalTime().ToString('o')
        working_set_kb  = [math]::Round(($p.WorkingSet64 / 1KB), 1)
        private_kb      = [math]::Round(($p.PrivateMemorySize64 / 1KB), 1)
        virtual_kb      = [math]::Round(($p.VirtualMemorySize64 / 1KB), 1)
        handle_count    = [int]$p.HandleCount
        thread_count    = [int]$p.Threads.Count
        gdi_objects     = $gdi
        user_objects    = $user
        cpu_total_s     = [double]$p.TotalProcessorTime.TotalSeconds
    }
}

function Measure-BenchCpuPercent {
    param(
        [Parameter(Mandatory = $true)] [int] $Id,
        [int] $SampleMs = 10000
    )

    $cores = [int]$env:NUMBER_OF_PROCESSORS
    $before = Get-Process -Id $Id
    $wall = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Milliseconds $SampleMs
    $after = Get-Process -Id $Id
    $wall.Stop()

    $cpuDelta = ($after.TotalProcessorTime - $before.TotalProcessorTime).TotalSeconds
    $wallDelta = $wall.Elapsed.TotalSeconds

    if ($wallDelta -le 0) { return 0.0 }

    return [math]::Round((($cpuDelta / $wallDelta) / $cores) * 100.0, 3)
}

function Wait-BenchProcessIdle {
    <#
    .SYNOPSIS
        Waits until the process stops consuming CPU.

    .DESCRIPTION
        "Ready" is defined without instrumenting the application: the process
        is considered ready once CPU time stops advancing across a set of
        consecutive samples. That is the moment the script has finished loading
        and settled, which is what a user perceives as start-up completion.
    #>
    param(
        [Parameter(Mandatory = $true)] [int] $Id,
        [int] $SampleMs = 100,
        [int] $StableSamples = 4,
        [int] $TimeoutMs = 60000,
        [double] $CpuThresholdPercent = 2.0
    )

    $cores = [int]$env:NUMBER_OF_PROCESSORS
    $stable = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $previous = Get-Process -Id $Id

    while ($sw.Elapsed.TotalMilliseconds -lt $TimeoutMs) {
        $sampleStart = [System.Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Milliseconds $SampleMs
        $current = Get-Process -Id $Id
        $sampleStart.Stop()

        $cpuDelta = ($current.TotalProcessorTime - $previous.TotalProcessorTime).TotalSeconds
        $wallDelta = $sampleStart.Elapsed.TotalSeconds
        $previous = $current

        if ($wallDelta -gt 0) {
            $cpuPercent = (($cpuDelta / $wallDelta) / $cores) * 100.0
            if ($cpuPercent -lt $CpuThresholdPercent) {
                $stable++
                if ($stable -ge $StableSamples) { return $true }
            } else {
                $stable = 0
            }
        }
    }

    return $false
}

function Start-BenchCapsLock {
    <#
    .SYNOPSIS
        Launches a compiled CapsLock- build in an isolated working directory
        and measures cold start.
    #>
    param(
        [Parameter(Mandatory = $true)] [string] $ExePath,
        [Parameter(Mandatory = $true)] [string] $WorkDir
    )

    if (Test-Path -LiteralPath $WorkDir) {
        Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

    $exeName = Split-Path -Leaf $ExePath
    $localExe = Join-Path $WorkDir $exeName
    Copy-Item -LiteralPath $ExePath -Destination $localExe -Force

    $stdoutPath = Join-Path $WorkDir 'stdout.log'
    $stderrPath = Join-Path $WorkDir 'stderr.log'

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath $localExe -WorkingDirectory $WorkDir -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $launchMs = $sw.Elapsed.TotalMilliseconds

    $reachedIdle = Wait-BenchProcessIdle -Id $proc.Id
    $sw.Stop()

    return @{
        process        = $proc
        work_dir       = $WorkDir
        stdout_path    = $stdoutPath
        stderr_path    = $stderrPath
        launch_ms      = [math]::Round($launchMs, 2)
        startup_to_idle_ms = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
        reached_idle   = $reachedIdle
    }
}

function Stop-BenchCapsLock {
    param([Parameter(Mandatory = $true)] [System.Diagnostics.Process] $Process)

    if ($null -eq $Process) { return }

    try {
        if (-not $Process.HasExited) {
            $Process.Kill()
            $Process.WaitForExit(10000) | Out-Null
        }
    } catch {
        # Already gone, or access denied because it exited on its own.
    }
}

# ---------------------------------------------------------------------------
# Scratch target window
# ---------------------------------------------------------------------------

function New-BenchScratchWindow {
    <#
    .SYNOPSIS
        Opens Notepad with known selected text.

    .DESCRIPTION
        The hotkey probes need a foreground window with a text selection.
        Notepad is used because it ships with every Windows install and is a
        real target application, which is more representative than a synthetic
        window. No UI framework is needed on the harness side.
    #>
    param([string] $MarkerText = 'CapsLockBench scratch target 0123456789')

    Initialize-BenchNative

    $notepad = Join-Path $env:SystemRoot 'System32\notepad.exe'
    if (-not (Test-Path -LiteralPath $notepad)) {
        throw "notepad.exe not found at $notepad"
    }

    $proc = Start-Process -FilePath $notepad -PassThru
    $proc.WaitForInputIdle(10000) | Out-Null

    $found = Wait-BenchCondition -TimeoutMs 15000 -Condition {
        $windows = [CapsLockBench.Native]::VisibleWindowsOfProcess([uint32]$proc.Id)
        return ($windows.Count -gt 0)
    }

    if (-not $found) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw 'Notepad did not open a window within 15 s.'
    }

    $windows = [CapsLockBench.Native]::VisibleWindowsOfProcess([uint32]$proc.Id)
    $hwnd = $windows[0]
    [CapsLockBench.Native]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 400

    # Clear anything Notepad restored, then insert a known selection.
    Send-Chord -Key $script:Keys.A -Modifiers @($script:VK_CONTROL) -DelayMs 60 -SettleMs 30
    Send-KeyTap -Key $script:VK_BACK -DelayMs 60

    [CapsLockBench.Native]::SetClipboardText($MarkerText) | Out-Null
    Send-Chord -Key $script:Keys.V -Modifiers @($script:VK_CONTROL) -DelayMs 80 -SettleMs 30

    # Leave everything selected so CapsLock + C has something to copy.
    Send-Chord -Key $script:Keys.A -Modifiers @($script:VK_CONTROL) -DelayMs 80 -SettleMs 30

    return @{
        process  = $proc
        hwnd     = $hwnd
        marker   = $MarkerText
    }
}

function Remove-BenchScratchWindow {
    param($Scratch)

    if ($null -eq $Scratch) { return }
    if ($null -eq $Scratch.process) { return }

    try {
        if (-not $Scratch.process.HasExited) {
            Stop-Process -Id $Scratch.process.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # ignore
    }
}

# ---------------------------------------------------------------------------
# Latency probes
# ---------------------------------------------------------------------------

function Measure-BenchTopmostLatency {
    <#
    .SYNOPSIS
        CapsLock + T latency, measured as key-press to WS_EX_TOPMOST change.

    .DESCRIPTION
        CapsLock + T is the simplest observable action: it flips WS_EX_TOPMOST
        on the foreground window. The harness reads the extended style through
        GetWindowLong, so the measurement needs no cooperation from the app.
        Each iteration toggles the style, so the window ends up back where it
        started after an even number of iterations.
    #>
    param(
        [Parameter(Mandatory = $true)] [IntPtr] $WindowHandle,
        [int] $Iterations = 15,
        [int] $TimeoutMs = 4000
    )

    Initialize-BenchNative

    $samples = New-Object System.Collections.Generic.List[double]
    $failures = 0

    [CapsLockBench.Native]::SetForegroundWindow($WindowHandle) | Out-Null
    Start-Sleep -Milliseconds 250

    # The probe toggles the style, so make sure it starts unpinned.
    if ([CapsLockBench.Native]::IsTopmost($WindowHandle)) {
        Send-Chord -Key $script:Keys.T -Modifiers @($script:VK_CAPITAL) -DelayMs 200
    }

    for ($i = 0; $i -lt $Iterations; $i++) {
        [CapsLockBench.Native]::SetForegroundWindow($WindowHandle) | Out-Null
        Start-Sleep -Milliseconds 120

        $before = [CapsLockBench.Native]::IsTopmost($WindowHandle)

        [CapsLockBench.Native]::KeyDown($script:VK_CAPITAL) | Out-Null
        Start-Sleep -Milliseconds 60

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        [CapsLockBench.Native]::Tap($script:Keys.T) | Out-Null

        $changed = Wait-BenchCondition -TimeoutMs $TimeoutMs -Condition {
            return ([CapsLockBench.Native]::IsTopmost($WindowHandle) -ne $before)
        }

        $sw.Stop()
        [CapsLockBench.Native]::KeyUp($script:VK_CAPITAL) | Out-Null

        if ($changed) {
            $samples.Add($sw.Elapsed.TotalMilliseconds)
        } else {
            $failures++
        }

        # Let the OSD toast expire before the next sample.
        Start-Sleep -Milliseconds 1700
    }

    return @{
        summary  = Get-BenchSummary -Values $samples.ToArray()
        failures = $failures
    }
}

function Measure-BenchCopyLatency {
    <#
    .SYNOPSIS
        CapsLock + C latency, measured as key-press to clipboard change.

    .DESCRIPTION
        Covers the plain-text copy path, the clipboard replacement and the
        history insert that runs immediately after it, up to the point the
        clipboard sequence number advances.
    #>
    param(
        [Parameter(Mandatory = $true)] [IntPtr] $WindowHandle,
        [int] $Iterations = 15,
        [int] $TimeoutMs = 4000
    )

    Initialize-BenchNative

    $samples = New-Object System.Collections.Generic.List[double]
    $failures = 0

    [CapsLockBench.Native]::SetForegroundWindow($WindowHandle) | Out-Null
    Start-Sleep -Milliseconds 250

    for ($i = 0; $i -lt $Iterations; $i++) {
        # Re-select so the copy has a target, and park a sentinel on the
        # clipboard so the sequence number is guaranteed to change.
        [CapsLockBench.Native]::SetForegroundWindow($WindowHandle) | Out-Null
        Send-Chord -Key $script:Keys.A -Modifiers @($script:VK_CONTROL) -DelayMs 80 -SettleMs 30
        [CapsLockBench.Native]::SetClipboardText('CapsLockBench sentinel ' + $i) | Out-Null
        Start-Sleep -Milliseconds 80

        $before = [CapsLockBench.Native]::GetClipboardSequenceNumber()

        [CapsLockBench.Native]::KeyDown($script:VK_CAPITAL) | Out-Null
        Start-Sleep -Milliseconds 60

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        [CapsLockBench.Native]::Tap($script:Keys.C) | Out-Null

        $changed = Wait-BenchCondition -TimeoutMs $TimeoutMs -Condition {
            return ([uint32][CapsLockBench.Native]::GetClipboardSequenceNumber() -ne $before)
        }

        $sw.Stop()
        [CapsLockBench.Native]::KeyUp($script:VK_CAPITAL) | Out-Null

        if ($changed) {
            $samples.Add($sw.Elapsed.TotalMilliseconds)
        } else {
            $failures++
        }

        Start-Sleep -Milliseconds 250
    }

    return @{
        summary  = Get-BenchSummary -Values $samples.ToArray()
        failures = $failures
    }
}

function Measure-BenchHistoryMenuLatency {
    <#
    .SYNOPSIS
        CapsLock + Shift + V latency, measured as key-press to menu window.

    .DESCRIPTION
        The history menu is a window created by the script process, so the
        probe watches for the visible-window count of that process to rise.
    #>
    param(
        [Parameter(Mandatory = $true)] [int] $ProcessId,
        [int] $Iterations = 10,
        [int] $TimeoutMs = 5000
    )

    Initialize-BenchNative

    $samples = New-Object System.Collections.Generic.List[double]
    $failures = 0

    $baseline = ([CapsLockBench.Native]::VisibleWindowsOfProcess([uint32]$ProcessId)).Count

    for ($i = 0; $i -lt $Iterations; $i++) {
        # Make sure no menu is left open from the previous iteration.
        Send-KeyTap -Key $script:VK_ESCAPE -DelayMs 150
        Start-Sleep -Milliseconds 400

        $current = ([CapsLockBench.Native]::VisibleWindowsOfProcess([uint32]$ProcessId)).Count

        [CapsLockBench.Native]::KeyDown($script:VK_CAPITAL) | Out-Null
        [CapsLockBench.Native]::KeyDown($script:VK_SHIFT) | Out-Null
        Start-Sleep -Milliseconds 60

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        [CapsLockBench.Native]::Tap($script:Keys.V) | Out-Null

        $opened = Wait-BenchCondition -TimeoutMs $TimeoutMs -Condition {
            $count = ([CapsLockBench.Native]::VisibleWindowsOfProcess([uint32]$ProcessId)).Count
            return ($count -gt $current)
        }

        $sw.Stop()
        [CapsLockBench.Native]::KeyUp($script:VK_SHIFT) | Out-Null
        [CapsLockBench.Native]::KeyUp($script:VK_CAPITAL) | Out-Null

        if ($opened) {
            $samples.Add($sw.Elapsed.TotalMilliseconds)
        } else {
            $failures++
        }

        Send-KeyTap -Key $script:VK_ESCAPE -DelayMs 200
        Start-Sleep -Milliseconds 400
    }

    return @{
        summary  = Get-BenchSummary -Values $samples.ToArray()
        failures = $failures
        baseline_visible_windows = $baseline
    }
}

# ---------------------------------------------------------------------------
# Resident-feature soak
# ---------------------------------------------------------------------------

function Invoke-BenchFeatureSoak {
    <#
    .SYNOPSIS
        Exercises the resident features and reports before/after deltas.

    .DESCRIPTION
        Covers the stability requirement: Tray, Quick Phrase, Clipboard
        History, Window Hole and the new cursor effects are each driven once,
        then handle counts, GDI objects and private bytes are compared against
        the pre-soak snapshot. A leak or a crash shows up as a large delta or a
        dead process.
    #>
    param(
        [Parameter(Mandatory = $true)] [int] $ProcessId,
        [Parameter(Mandatory = $true)] [IntPtr] $ScratchHandle
    )

    Initialize-BenchNative

    $before = Get-BenchProcessSnapshot -Id $ProcessId
    $notes = New-Object System.Collections.Generic.List[string]

    # A script block rather than a nested function: PowerShell resolves names
    # dynamically, so a nested function would not see the caller's $notes.
    $invokeStep = {
        param([string] $Name, [scriptblock] $Body, $Notes)

        try {
            & $Body
            $Notes.Add("ok: $Name")
        } catch {
            $Notes.Add("error: $Name -> $($_.Exception.Message)")
        }
    }

    # Always-on-top (CapsLock + T), twice, so the window ends unpinned.
    & $invokeStep -Name 'always-on-top' -Notes $notes -Body {
        Send-Chord -Key $script:Keys.T -Modifiers @($script:VK_CAPITAL) -DelayMs 300
        Send-Chord -Key $script:Keys.T -Modifiers @($script:VK_CAPITAL) -DelayMs 300
    }

    Start-Sleep -Milliseconds 1800

    # Clipboard copy + history menu + dismiss.
    & $invokeStep -Name 'clipboard-history' -Notes $notes -Body {
        [CapsLockBench.Native]::SetForegroundWindow($ScratchHandle) | Out-Null
        Send-Chord -Key $script:Keys.A -Modifiers @($script:VK_CONTROL) -DelayMs 100 -SettleMs 30
        Send-Chord -Key $script:Keys.C -Modifiers @($script:VK_CAPITAL) -DelayMs 300
        Send-Chord -Key $script:Keys.V -Modifiers @($script:VK_CAPITAL, $script:VK_SHIFT) -DelayMs 500
        Send-KeyTap -Key $script:VK_ESCAPE -DelayMs 200
    }

    # Quick Phrase selector (CapsLock + Shift + P) and dismiss.
    & $invokeStep -Name 'quick-phrase' -Notes $notes -Body {
        Send-Chord -Key $script:Keys.P -Modifiers @($script:VK_CAPITAL, $script:VK_SHIFT) -DelayMs 600
        Send-KeyTap -Key $script:VK_ESCAPE -DelayMs 300
    }

    # Cheatsheet (CapsLock + H) and dismiss.
    & $invokeStep -Name 'cheatsheet' -Notes $notes -Body {
        Send-Chord -Key $script:Keys.H -Modifiers @($script:VK_CAPITAL) -DelayMs 600
        Send-KeyTap -Key $script:VK_ESCAPE -DelayMs 300
    }

    # Spotlight (CapsLock + O) and back off.
    & $invokeStep -Name 'spotlight' -Notes $notes -Body {
        Send-Chord -Key $script:Keys.O -Modifiers @($script:VK_CAPITAL) -DelayMs 700
        Send-Chord -Key $script:Keys.O -Modifiers @($script:VK_CAPITAL) -DelayMs 400
    }

    # Dynamic Zoom (CapsLock + Z) and back off.
    & $invokeStep -Name 'dynamic-zoom' -Notes $notes -Body {
        Send-Chord -Key $script:Keys.Z -Modifiers @($script:VK_CAPITAL) -DelayMs 900
        Send-Chord -Key $script:Keys.Z -Modifiers @($script:VK_CAPITAL) -DelayMs 400
    }

    # Window Hole (CapsLock + X, hold mode releases on key up).
    & $invokeStep -Name 'window-hole' -Notes $notes -Body {
        Send-Chord -Key $script:Keys.X -Modifiers @($script:VK_CAPITAL) -DelayMs 800
    }

    # Window switcher (CapsLock + L) and dismiss.
    & $invokeStep -Name 'window-switcher' -Notes $notes -Body {
        Send-Chord -Key $script:Keys.L -Modifiers @($script:VK_CAPITAL) -DelayMs 700
        Send-KeyTap -Key $script:VK_ESCAPE -DelayMs 300
    }

    Start-Sleep -Milliseconds 2500

    $alive = $true
    try {
        $proc = Get-Process -Id $ProcessId
        $alive = -not $proc.HasExited
    } catch {
        $alive = $false
    }

    $after = $null
    if ($alive) { $after = Get-BenchProcessSnapshot -Id $ProcessId }

    $result = @{
        alive           = $alive
        steps           = $notes.ToArray()
        before          = $before
        after           = $after
    }

    if ($after) {
        $result['delta_handles'] = $after.handle_count - $before.handle_count
        $result['delta_threads'] = $after.thread_count - $before.thread_count
        $result['delta_gdi'] = $after.gdi_objects - $before.gdi_objects
        $result['delta_user'] = $after.user_objects - $before.user_objects
        $result['delta_private_kb'] = [math]::Round(($after.private_kb - $before.private_kb), 1)
        $result['delta_working_set_kb'] = [math]::Round(($after.working_set_kb - $before.working_set_kb), 1)
    }

    return $result
}

Export-ModuleMember -Function @(
    'Initialize-BenchNative',
    'Wait-BenchCondition',
    'Send-KeyTap',
    'Send-Chord',
    'Get-BenchPercentile',
    'Get-BenchSummary',
    'Get-BenchEnvironment',
    'Get-BenchFileFacts',
    'Get-BenchProcessSnapshot',
    'Measure-BenchCpuPercent',
    'Wait-BenchProcessIdle',
    'Start-BenchCapsLock',
    'Stop-BenchCapsLock',
    'New-BenchScratchWindow',
    'Remove-BenchScratchWindow',
    'Measure-BenchTopmostLatency',
    'Measure-BenchCopyLatency',
    'Measure-BenchHistoryMenuLatency',
    'Invoke-BenchFeatureSoak'
)
