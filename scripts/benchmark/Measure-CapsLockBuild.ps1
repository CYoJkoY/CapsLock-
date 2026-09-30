#Requires -Version 5.1
<#
.SYNOPSIS
    Benchmarks one compiled CapsLock- build.

.DESCRIPTION
    Produces the measurements the release-compiler evaluation needs (issue
    #46). Every number is gathered from outside the process, so the current
    AutoHotkey compiler output and an AHKCompiler output can be compared
    without any difference in instrumentation.

    Measured
      * executable size and SHA-256
      * cold start, as "time from launch until the process is idle"
      * idle working set, private bytes, GDI / USER objects, handle count
      * idle CPU over a configurable sample window
      * CapsLock + T latency        (key press -> WS_EX_TOPMOST changes)
      * CapsLock + C latency        (key press -> clipboard sequence changes)
      * CapsLock + Shift + V latency (key press -> history menu window opens)
      * resident-feature soak with before/after handle and memory deltas

    Output
      * <OutDir>\<Profile>.json     machine-readable results
      * <OutDir>\<Profile>.md       one table, ready to paste into the report
      * <OutDir>\<Profile>.env.json environment captured for the run

.EXAMPLE
    .\Measure-CapsLockBuild.ps1 -ExePath .\build\CapsLock-.exe -Profile ahk2exe -OutDir .\bench

.EXAMPLE
    .\Measure-CapsLockBuild.ps1 -ExePath .\build\CapsLock-_ahk2bc_x64.exe `
        -Profile ahkcompiler -OutDir .\bench -Repetitions 5

.NOTES
    Run on an otherwise idle machine, on AC power, with the same power plan for
    every profile. See docs/build/compiler-evaluation.md for the full protocol.
#>

[CmdletBinding()]
param(
    # The compiled executable to measure.
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ExePath,

    # Short name for this build, used for output file names.
    [Parameter(Mandatory = $true)]
    [string] $Profile,

    # Directory that receives the result files. Created if missing.
    [string] $OutDir = (Join-Path $PSScriptRoot 'results'),

    # How many times the whole measure cycle is repeated. The reported value is
    # the median across repetitions.
    [int] $Repetitions = 3,

    # Iterations per latency probe inside one repetition.
    [int] $LatencyIterations = 15,

    # Quiet period after start-up before idle sampling.
    [int] $IdleSettleSeconds = 45,

    # Length of one idle CPU sample window.
    [int] $IdleSampleSeconds = 20,

    # Number of idle samples taken per repetition.
    [int] $IdleSamples = 3,

    # Skip the interactive latency probes (useful on a locked session, where
    # synthetic input does not reach the shell).
    [switch] $SkipLatency,

    # Skip the resident-feature soak.
    [switch] $SkipSoak
)

$ErrorActionPreference = 'Stop'

# Interactive probes cannot work on a locked or disconnected session.
function Test-InteractiveSession {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop | Out-Null
        if ([System.Windows.Forms.SystemInformation]::UserInteractive) { return $true }
    } catch {
        # Fall through to the process-based check.
    }

    $explorer = Get-Process -Name 'explorer' -ErrorAction SilentlyContinue
    return ($null -ne $explorer)
}

# --- Setup ------------------------------------------------------------------

$modulePath = Join-Path $PSScriptRoot 'CapsLockBench.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw "Cannot find $modulePath"
}
Import-Module $modulePath -Force

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$interactive = Test-InteractiveSession
if (-not $interactive) {
    Write-Warning 'Session does not look interactive. Latency probes and the soak will be skipped.'
    $SkipLatency = $true
    $SkipSoak = $true
}

$environment = Get-BenchEnvironment
$environment['profile'] = $Profile
$environment['skip_latency'] = [bool]$SkipLatency
$environment['skip_soak'] = [bool]$SkipSoak
$environment['repetitions'] = $Repetitions
$environment['latency_iterations'] = $LatencyIterations

$fileFacts = Get-BenchFileFacts -Path $ExePath

Write-Host ''
Write-Host ('=== Profile: {0} ===' -f $Profile) -ForegroundColor Cyan
Write-Host ('    exe      : {0}' -f $fileFacts.name)
Write-Host ('    size     : {0} KB ({1} bytes)' -f $fileFacts.size_kb, $fileFacts.size_bytes)
Write-Host ('    sha256   : {0}' -f $fileFacts.sha256.Substring(0, 16))
Write-Host ('    machine  : {0} / {1} cores / plan {2}' -f $environment.machine, $environment.cpu_cores, $environment.power_plan)
Write-Host ''

$repetitions = New-Object System.Collections.ArrayList

for ($rep = 1; $rep -le $Repetitions; $rep++) {
    Write-Host ('--- repetition {0} of {1} ---' -f $rep, $Repetitions)

    $workDir = Join-Path $env:TEMP ('CapsLockBench_{0}_{1}' -f $Profile, [guid]::NewGuid().ToString('N'))
    $scratch = $null
    $run = $null

    try {
        if (-not $SkipLatency) {
            $scratch = New-BenchScratchWindow
        }

        $run = Start-BenchCapsLock -ExePath $ExePath -WorkDir $workDir
        $procId = $run.process.Id

        Write-Host ('    start-up to idle : {0} ms (idle reached: {1})' -f $run.startup_to_idle_ms, $run.reached_idle)

        if (-not $run.reached_idle) {
            Write-Warning 'Process never reached an idle state; start-up figure is the timeout.'
        }

        Write-Host ('    settling {0} s before idle sampling...' -f $IdleSettleSeconds)
        Start-Sleep -Seconds $IdleSettleSeconds

        $idleSamples = New-Object System.Collections.ArrayList
        for ($s = 1; $s -le $IdleSamples; $s++) {
            Write-Host ('    idle sample {0} of {1} ({2} s)...' -f $s, $IdleSamples, $IdleSampleSeconds)
            $cpu = Measure-BenchCpuPercent -Id $procId -SampleMs ($IdleSampleSeconds * 1000)
            $snap = Get-BenchProcessSnapshot -Id $procId
            $snap['cpu_percent'] = $cpu
            $idleSamples.Add($snap) | Out-Null
        }

        # The first sample carries any leftover start-up work, so the reported
        # idle figures come from the last sample of the run.
        $idle = $idleSamples[$idleSamples.Count - 1]

        $result = @{
            repetition     = $rep
            startup_to_idle_ms = $run.startup_to_idle_ms
            reached_idle   = $run.reached_idle
            launch_ms      = $run.launch_ms
            idle           = $idle
            idle_samples   = $idleSamples.ToArray()
            latency        = @{}
            soak           = $null
        }

        if (-not $SkipLatency) {
            Write-Host '    measuring CapsLock + T latency...'
            $result.latency['topmost_ms'] = Measure-BenchTopmostLatency `
                -WindowHandle $scratch.hwnd -Iterations $LatencyIterations

            Write-Host '    measuring CapsLock + C latency...'
            $result.latency['copy_ms'] = Measure-BenchCopyLatency `
                -WindowHandle $scratch.hwnd -Iterations $LatencyIterations

            Write-Host '    measuring CapsLock + Shift + V latency...'
            $result.latency['history_menu_ms'] = Measure-BenchHistoryMenuLatency `
                -ProcessId $procId -Iterations ([int][math]::Max(5, [math]::Floor($LatencyIterations * 0.6)))
        }

        if (-not $SkipSoak) {
            Write-Host '    running resident-feature soak...'
            $result.soak = Invoke-BenchFeatureSoak -ProcessId $procId -ScratchHandle $scratch.hwnd

            if (-not $result.soak.alive) {
                Write-Warning 'Process exited during the soak.'
            }

            $stderrText = ''
            if (Test-Path -LiteralPath $run.stderr_path) {
                $stderrText = Get-Content -LiteralPath $run.stderr_path -Raw -ErrorAction SilentlyContinue
            }
            if ([string]::IsNullOrWhiteSpace($stderrText)) { $stderrText = '' }
            $result['stderr'] = $stderrText
        }

        $repetitions.Add($result) | Out-Null
    } finally {
        if ($run) {
            Stop-BenchCapsLock -Process $run.process
        }
        Remove-BenchScratchWindow -Scratch $scratch
        Start-Sleep -Milliseconds 800

        if (Test-Path -LiteralPath $workDir) {
            Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Aggregate --------------------------------------------------------------

$startupValues = @()
$idleWorkingSet = @()
$idlePrivate = @()
$idleCpu = @()
$idleHandles = @()
$idleGdi = @()

foreach ($r in $repetitions) {
    $startupValues += [double]$r.startup_to_idle_ms
    $idleWorkingSet += [double]$r.idle.working_set_kb
    $idlePrivate += [double]$r.idle.private_kb
    $idleCpu += [double]$r.idle.cpu_percent
    $idleHandles += [double]$r.idle.handle_count
    $idleGdi += [double]$r.idle.gdi_objects
}

$report = @{
    profile     = $Profile
    generated   = (Get-Date).ToUniversalTime().ToString('o')
    file        = $fileFacts
    environment = $environment
    aggregate   = @{
        repetitions          = $repetitions.Count
        startup_to_idle_ms   = [math]::Round((Get-BenchPercentile -Values $startupValues -Percentile 50), 2)
        startup_min_ms       = [math]::Round((Get-BenchPercentile -Values $startupValues -Percentile 0), 2)
        startup_max_ms       = [math]::Round((Get-BenchPercentile -Values $startupValues -Percentile 100), 2)
        idle_working_set_kb  = [math]::Round((Get-BenchPercentile -Values $idleWorkingSet -Percentile 50), 1)
        idle_private_kb      = [math]::Round((Get-BenchPercentile -Values $idlePrivate -Percentile 50), 1)
        idle_cpu_percent     = [math]::Round((Get-BenchPercentile -Values $idleCpu -Percentile 50), 3)
        idle_cpu_max_percent = [math]::Round((Get-BenchPercentile -Values $idleCpu -Percentile 100), 3)
        idle_handle_count    = [math]::Round((Get-BenchPercentile -Values $idleHandles -Percentile 50), 0)
        idle_gdi_objects     = [math]::Round((Get-BenchPercentile -Values $idleGdi -Percentile 50), 0)
    }
    latency     = @{}
    soak        = $null
    repetitions = $repetitions.ToArray()
}

# Latency: pool the per-iteration samples of every repetition rather than
# averaging summaries, so the percentiles stay meaningful.
if (-not $SkipLatency) {
    foreach ($metric in @('topmost_ms', 'copy_ms', 'history_menu_ms')) {
        $failures = 0
        $min = @(); $p50 = @(); $p95 = @(); $max = @(); $mean = @(); $n = 0
        foreach ($r in $repetitions) {
            if (-not $r.latency.ContainsKey($metric)) { continue }
            $s = $r.latency[$metric].summary
            $n += [int]$s.n
            $min += [double]$s.min
            $p50 += [double]$s.p50
            $p95 += [double]$s.p95
            $max += [double]$s.max
            $mean += [double]$s.mean
        }

        $report.latency[$metric] = @{
            n            = $n
            failures     = $failures
            median_p50   = [math]::Round((Get-BenchPercentile -Values $p50 -Percentile 50), 2)
            median_p95   = [math]::Round((Get-BenchPercentile -Values $p95 -Percentile 50), 2)
            worst_max    = [math]::Round((Get-BenchPercentile -Values $max -Percentile 100), 2)
            best_min     = [math]::Round((Get-BenchPercentile -Values $min -Percentile 0), 2)
        }
    }
}

if (-not $SkipSoak -and $repetitions.Count -gt 0) {
    $last = $repetitions[$repetitions.Count - 1]
    $report.soak = @{
        alive               = $last.soak.alive
        steps               = $last.soak.steps
        delta_handles       = $last.soak.delta_handles
        delta_threads       = $last.soak.delta_threads
        delta_gdi           = $last.soak.delta_gdi
        delta_user          = $last.soak.delta_user
        delta_private_kb    = $last.soak.delta_private_kb
        delta_working_set_kb = $last.soak.delta_working_set_kb
        stderr              = $last.stderr
    }
}

# --- Output -----------------------------------------------------------------

$jsonPath = Join-Path $OutDir ($Profile + '.json')
$envPath = Join-Path $OutDir ($Profile + '.env.json')
$mdPath = Join-Path $OutDir ($Profile + '.md')

$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$environment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $envPath -Encoding UTF8

$latencyRows = ''
foreach ($key in $report.latency.Keys) {
    $m = $report.latency[$key]
    $latencyRows += ('| latency {0} | {1} | {2} | {3} | {4} | {5} |{6}' -f `
        $key, $m.n, $m.median_p50, $m.median_p95, $m.worst_max, $m.failures, [Environment]::NewLine)
}

$soakRows = ''
if ($report.soak) {
    $soakRows = @"

### Resident-feature soak

| Check | Value |
| :---- | :---- |
| process alive after soak | $($report.soak.alive) |
| delta handles | $($report.soak.delta_handles) |
| delta threads | $($report.soak.delta_threads) |
| delta GDI objects | $($report.soak.delta_gdi) |
| delta USER objects | $($report.soak.delta_user) |
| delta private KB | $($report.soak.delta_private_kb) |
| delta working set KB | $($report.soak.delta_working_set_kb) |

Steps: $($report.soak.steps -join '; ')
"@
}

$markdown = @"
# CapsLock- build benchmark: $Profile

Generated (UTC): $($report.generated)

## Artifact

| Field | Value |
| :---- | :---- |
| file | $($fileFacts.name) |
| size | $($fileFacts.size_kb) KB ($($fileFacts.size_bytes) bytes) |
| sha256 | $($fileFacts.sha256) |
| file version | $($fileFacts.file_version) |

## Results (median of $($report.aggregate.repetitions) repetitions)

| Metric | Value |
| :----- | :---- |
| start-up to idle (p50) | $($report.aggregate.startup_to_idle_ms) ms |
| start-up to idle (min / max) | $($report.aggregate.startup_min_ms) / $($report.aggregate.startup_max_ms) ms |
| idle working set | $($report.aggregate.idle_working_set_kb) KB |
| idle private bytes | $($report.aggregate.idle_private_kb) KB |
| idle CPU (p50) | $($report.aggregate.idle_cpu_percent) % |
| idle CPU (max sample) | $($report.aggregate.idle_cpu_max_percent) % |
| idle handles | $($report.aggregate.idle_handle_count) |
| idle GDI objects | $($report.aggregate.idle_gdi_objects) |

## Latency (ms)

| Metric | n | p50 | p95 | max | failures |
| :----- | -: | --: | --: | --: | ------: |
$latencyRows
$soakRows

## Environment

| Field | Value |
| :---- | :---- |
| machine | $($environment.machine) |
| OS | $($environment.os_caption) ($($environment.os_build)) |
| CPU | $($environment.cpu) |
| cores | $($environment.cpu_cores) |
| RAM | $($environment.ram_gb) GB |
| power plan | $($environment.power_plan) |
| PowerShell | $($environment.ps_version) |
| profile | $($environment.profile) |
| repetitions | $($environment.repetitions) |
| latency iterations | $($environment.latency_iterations) |
"@

Set-Content -LiteralPath $mdPath -Value $markdown -Encoding UTF8

Write-Host ''
Write-Host '=== Summary ===' -ForegroundColor Green
Write-Host ('  size                : {0} KB' -f $fileFacts.size_kb)
Write-Host ('  start-up to idle    : {0} ms' -f $report.aggregate.startup_to_idle_ms)
Write-Host ('  idle working set    : {0} KB' -f $report.aggregate.idle_working_set_kb)
Write-Host ('  idle private bytes  : {0} KB' -f $report.aggregate.idle_private_kb)
Write-Host ('  idle CPU            : {0} %' -f $report.aggregate.idle_cpu_percent)
foreach ($key in $report.latency.Keys) {
    Write-Host ('  latency {0} : p50 {1} ms, p95 {2} ms' -f $key, $report.latency[$key].median_p50, $report.latency[$key].median_p95)
}
Write-Host ''
Write-Host ('  results : {0}' -f $jsonPath)
Write-Host ('  report  : {0}' -f $mdPath)
Write-Host ''

return $report
