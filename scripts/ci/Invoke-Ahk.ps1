<#
.SYNOPSIS
    Runs an AutoHotkey v2 script to completion and fails if the script fails.

.DESCRIPTION
    AutoHotkey32.exe / AutoHotkey64.exe are GUI-subsystem programs. When
    PowerShell runs one as a bare command (or with `&`) it does NOT wait for the
    process, does NOT set $LASTEXITCODE and does NOT capture its output. A CI
    step written that way reports success immediately - whatever the script
    does afterwards - and a later `if ($LASTEXITCODE -ne 0)` fails spuriously
    because the variable is $null.

    This wrapper starts the process directly instead. It

      * waits for the script to exit, with a timeout, so a hidden dialog (for
        example an AutoHotkey #Warn MsgBox) cannot hang the job;
      * copies stdout and stderr to the log (AutoHotkey writes load errors,
        selected by /ErrorStdOut, to stderr and FileAppend "*" output to stdout);
      * turns "FAIL ..." lines and a non-zero exit code into GitHub Actions
        error annotations; and
      * throws, so a PowerShell step stops, on a non-zero exit code or a timeout.

    The scripts under scripts\ exit with 0 when every check passed.

.PARAMETER Script
    The .ahk file to run (or, with -Validate, to load and syntax-check).

.PARAMETER ScriptArguments
    Arguments passed to the script after its path, e.g. '-CSharp'.

.PARAMETER Validate
    Pass /Validate: load the script, report load-time errors and exit without
    running it. The exit code is 0 only if the script loaded successfully.

.PARAMETER Architecture
    x64 (AutoHotkey64.exe, the default) or x86 (AutoHotkey32.exe).

.PARAMETER Executable
    Explicit AutoHotkey executable. Overrides -Architecture. When neither is
    given, the executable is searched in the AHK_EXE environment variable's
    folder, <repo>\autohotkey (installed by holy-tao/install-autohotkey) and
    the usual AutoHotkey v2 install folders.

.PARAMETER TimeoutSeconds
    The script is killed, and the step fails, if it runs longer than this.

.EXAMPLE
    .\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\ServiceEquivalence.ahk

.EXAMPLE
    .\scripts\ci\Invoke-Ahk.ps1 .\scripts\perf\ServiceEquivalence.ahk -ScriptArguments '-CSharp' -Architecture x86

.EXAMPLE
    .\scripts\ci\Invoke-Ahk.ps1 .\CapsLock-.ahk -Validate
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Script,

    [string[]] $ScriptArguments = @(),

    [switch] $Validate,

    [ValidateSet('x64', 'x86')]
    [string] $Architecture = 'x64',

    [string] $Executable = '',

    [ValidateRange(1, 3600)]
    [int] $TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

function Find-AutoHotkey {
    param([string] $Explicit, [string] $Arch)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
            throw "AutoHotkey executable not found: $Explicit"
        }
        return (Resolve-Path -LiteralPath $Explicit).ProviderPath
    }

    $name = if ($Arch -eq 'x86') { 'AutoHotkey32.exe' } else { 'AutoHotkey64.exe' }
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).ProviderPath
    $folders = @()
    if ($env:AHK_EXE) { $folders += (Split-Path -Parent $env:AHK_EXE) }
    $folders += (Join-Path $repoRoot 'autohotkey')
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ($base) {
            $folders += (Join-Path $base 'AutoHotkey\v2')
            $folders += (Join-Path $base 'Programs\AutoHotkey\v2')
        }
    }
    foreach ($folder in $folders) {
        $candidate = Join-Path $folder $name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }
    throw "$name was not found. Pass -Executable, set AHK_EXE, or install AutoHotkey v2 into <repo>\autohotkey."
}

function ConvertTo-WorkflowData {
    param([string] $Text)
    # Escaping required by GitHub Actions workflow commands.
    return $Text.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
}

function Get-StreamText {
    param($Task, [string] $Name)
    # The pipe stays open if AutoHotkey left a child process behind; never hang on it.
    if ($Task.Wait(10000)) { return [string] $Task.Result }
    return "($Name did not close within 10 s)"
}

$exe = Find-AutoHotkey -Explicit $Executable -Arch $Architecture
$scriptPath = (Resolve-Path -LiteralPath $Script).ProviderPath
$scriptLabel = $Script

$arguments = [System.Collections.Generic.List[string]]::new()
# /ErrorStdOut sends load-time errors to stderr instead of a dialog.
$arguments.Add('/ErrorStdOut=UTF-8')
if ($Validate) { $arguments.Add('/Validate') }
$arguments.Add($scriptPath)
foreach ($argument in $ScriptArguments) { $arguments.Add($argument) }

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $exe
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
$startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
$startInfo.WorkingDirectory = (Get-Location).ProviderPath
foreach ($argument in $arguments) { $startInfo.ArgumentList.Add($argument) }

Write-Host "AutoHotkey: $exe"
Write-Host "Command   : $($arguments -join ' ')"

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$watch = [System.Diagnostics.Stopwatch]::StartNew()
[void] $process.Start()
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()

$exited = $process.WaitForExit($TimeoutSeconds * 1000)
if ($exited) {
    # Second call: make sure the process object is fully settled.
    $process.WaitForExit()
}
else {
    try { $process.Kill($true) } catch { Write-Warning "Could not stop AutoHotkey: $_" }
    [void] $process.WaitForExit(10000)
}
$watch.Stop()

$stdout = Get-StreamText -Task $stdoutTask -Name 'stdout'
$stderr = Get-StreamText -Task $stderrTask -Name 'stderr'
$exitCode = if ($exited) { $process.ExitCode } else { -1 }
$process.Dispose()

if ($stdout.Trim().Length -gt 0) {
    Write-Host '--- stdout ---'
    Write-Host $stdout.TrimEnd()
}
if ($stderr.Trim().Length -gt 0) {
    Write-Host '--- stderr ---'
    Write-Host $stderr.TrimEnd()
}
Write-Host ('--- {0}: exit code {1} after {2:N1} s ---' -f $scriptLabel, $exitCode, $watch.Elapsed.TotalSeconds)

$failed = (-not $exited) -or ($exitCode -ne 0)

# Surface failures in the PR checks UI (GitHub keeps at most 10 annotations per
# step): the scripts print "FAIL <check>" for every failed check, and load-time
# errors are written to stderr as "<file> (<line>) : ==> <message>".
if ($failed) {
    $annotated = 0
    $candidates = @()
    $candidates += @($stdout -split "\r?\n" | Where-Object { $_ -match '^\s*FAIL\b' })
    $candidates += @($stderr -split "\r?\n" | Where-Object { $_.Trim().Length -gt 0 })
    foreach ($line in $candidates) {
        if ($annotated -ge 8) { break }
        Write-Host ('::error::{0}: {1}' -f (ConvertTo-WorkflowData $scriptLabel), (ConvertTo-WorkflowData $line.Trim()))
        $annotated++
    }
}

if (-not $exited) {
    Write-Host "::error::$(ConvertTo-WorkflowData $scriptLabel): timed out after $TimeoutSeconds s. A dialog (for example an AutoHotkey #Warn MsgBox) may be waiting."
    throw "$scriptLabel timed out after $TimeoutSeconds s."
}
if ($exitCode -ne 0) {
    Write-Host "::error::$(ConvertTo-WorkflowData $scriptLabel): AutoHotkey exited with code $exitCode."
    throw "$scriptLabel failed with exit code $exitCode."
}
