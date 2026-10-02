<#
.SYNOPSIS
    Compiles CapsLock-.exe locally, packaging the optional C# backend into it.

.DESCRIPTION
    One command for the whole release-shaped build:

      1. provision lib\ahk#\lib\ahk#.bridge.dll and lib\CapsLockSharp.dll and
         write the generated CSharpPayload.ahk (scripts\Setup-CSharpBackend.ps1);
      2. run Ahk2Exe unattended, which inlines every #Include and embeds both
         DLLs as RCDATA resources because of the directives in that file;
      3. verify the finished EXE really carries both resources.

    Without step 1 the same source compiles to a pure-AHK executable: the
    generated include is absent, `#Include *i CSharpPayload.ahk` resolves to
    nothing and no directive is seen. Pass -SkipCSharp for that build.

    At runtime Core\CSharpPayload.ahk extracts the resources next to the EXE
    (or into %LOCALAPPDATA%\CapsLock- when the install folder is read-only) and
    Services.Boot() starts the CLR on the first C# request only.

    Every failure is echoed as a GitHub Actions ::error:: annotation as well as
    an exception, so an unattended run says what broke instead of only exiting
    non-zero.

.PARAMETER Architecture
    x64 (default), x86, or both - the same layout the release workflow ships.

.PARAMETER OutDir
    Where the executables are written. Defaults to build\.

.PARAMETER SkipCSharp
    Build a pure-AHK executable and remove any generated payload include.

.PARAMETER SkipPayloadVerify
    Compile only; do not inspect the finished executables.

.PARAMETER RebuildIcon
    Regenerate assets\CapsLock-.ico first (needs ImageMagick). The committed ICO
    is used otherwise, so a build machine without ImageMagick still works.

.PARAMETER Ahk2Exe
    Explicit path to Ahk2Exe.exe. Searched for otherwise.

.PARAMETER Base64
.PARAMETER Base32
    Explicit base files (.bin or AutoHotkey<bitness>.exe). CI passes the paths
    its AutoHotkey installer reported, which removes any guesswork.

.EXAMPLE
    .\scripts\build.ps1

.EXAMPLE
    .\scripts\build.ps1 -Architecture both -RebuildIcon

.EXAMPLE
    .\scripts\build.ps1 -SkipCSharp
#>
[CmdletBinding()]
param(
    [ValidateSet('x64', 'x86', 'both')]
    [string] $Architecture = 'x64',

    [string] $OutDir = '',

    [switch] $SkipCSharp,

    [switch] $SkipPayloadVerify,

    [switch] $RebuildIcon,

    [string] $Ahk2Exe = '',

    [string] $Base64 = '',

    [string] $Base32 = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$script = Join-Path $repoRoot 'CapsLock-.ahk'
$icon = Join-Path $repoRoot 'assets\CapsLock-.ico'
$payloadInclude = Join-Path $repoRoot 'CSharpPayload.ahk'

if ($OutDir -eq '') { $OutDir = Join-Path $repoRoot 'build' }
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = Join-Path $repoRoot $OutDir }
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

function Fail {
    param([string] $Message)
    # GitHub keeps annotations even when the raw job log is unavailable, so a
    # failure has to say what it was in the annotation, not only in the log.
    Write-Host ('::error::{0}' -f ($Message -replace "`r?`n", ' | '))
    throw $Message
}

function Get-BaseFile {
    param([string] $Arch)

    $bits = if ($Arch -eq 'x64') { 64 } else { 32 }

    # An explicit path always wins; that is what CI passes.
    $explicit = if ($Arch -eq 'x64') { $Base64 } else { $Base32 }
    if ($explicit) {
        if (-not (Test-Path -LiteralPath $explicit -PathType Leaf)) {
            Fail "The $Arch base file does not exist: $explicit"
        }
        return (Resolve-Path -LiteralPath $explicit).ProviderPath
    }

    # Otherwise look through every AutoHotkey location this repository knows
    # about. The base may be one of the shipped "Unicode <bits>-bit.bin" files
    # in the compiler folder, or one of the interpreters in an install.
    $roots = @()
    if ($script:compiler) {
        $compilerDir = Split-Path -Parent $script:compiler
        $roots += $compilerDir
        $roots += (Split-Path -Parent $compilerDir)
    }
    if ($env:AHK_EXE) { $roots += (Split-Path -Parent $env:AHK_EXE) }
    $roots += (Join-Path $repoRoot 'autohotkey')      # where CI unpacks it
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ($base) {
            $roots += (Join-Path $base 'AutoHotkey')
            $roots += (Join-Path $base 'Programs\AutoHotkey')
        }
    }

    $names = @(
        ('Unicode {0}-bit.bin' -f $bits),
        ('v2\AutoHotkey{0}.exe' -f $bits),
        ('AutoHotkey{0}.exe' -f $bits)
    )

    foreach ($root in $roots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
        foreach ($name in $names) {
            $candidate = Join-Path $root $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return (Resolve-Path -LiteralPath $candidate).ProviderPath
            }
        }
    }

    # Last resort: whatever an installer unpacked into the repository.
    $searchRoot = Join-Path $repoRoot 'autohotkey'
    if (Test-Path -LiteralPath $searchRoot) {
        foreach ($name in $names) {
            $found = Get-ChildItem -LiteralPath $searchRoot -Recurse -Filter $name -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    Fail ("No $Arch base file was found (looked for 'Unicode $bits-bit.bin' and 'AutoHotkey$bits.exe' in: " +
        (($roots | Where-Object { $_ }) -join '; ') + "). Pass -Base$bits.")
}

function Find-Ahk2Exe {
    param([string] $Explicit)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
            Fail "Ahk2Exe.exe not found: $Explicit"
        }
        return (Resolve-Path -LiteralPath $Explicit).ProviderPath
    }

    $folders = @()
    if ($env:AHK_EXE) { $folders += (Split-Path -Parent $env:AHK_EXE) }
    $folders += (Join-Path $repoRoot 'autohotkey')          # where CI unpacks it
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ($base) {
            $folders += (Join-Path $base 'AutoHotkey')
            $folders += (Join-Path $base 'Programs\AutoHotkey')
        }
    }

    foreach ($folder in $folders) {
        $candidate = Join-Path $folder 'Compiler\Ahk2Exe.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }

    # An installer that laid the compiler out somewhere unexpected.
    $found = Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter 'Ahk2Exe.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) { return $found.FullName }

    Fail 'Ahk2Exe.exe was not found. Install the AutoHotkey compiler (the v2 Dash offers it), or pass -Ahk2Exe.'
}

# ---------------------------------------------------------------------------
# 1. Payload
# ---------------------------------------------------------------------------

if ($SkipCSharp) {
    if (Test-Path -LiteralPath $payloadInclude) {
        Remove-Item -LiteralPath $payloadInclude -Force
        Write-Host 'Removed the generated payload include: building pure AHK.'
    }
}
else {
    # Called in this runspace, so a throw in the setup script lands here and is
    # annotated like every other failure.
    try {
        & (Join-Path $PSScriptRoot 'Setup-CSharpBackend.ps1')
    }
    catch {
        Fail "Setup-CSharpBackend.ps1 failed: $($_.Exception.Message)"
    }
    Write-Host ('Payload include present: {0}' -f (Test-Path -LiteralPath $payloadInclude))
}

if ($RebuildIcon) {
    try {
        & (Join-Path $PSScriptRoot 'build_icon.ps1')
    }
    catch {
        Fail "build_icon.ps1 failed: $($_.Exception.Message)"
    }
}
if (-not (Test-Path -LiteralPath $icon)) {
    Fail "The application icon is missing: $icon (run with -RebuildIcon, which needs ImageMagick)."
}

# ---------------------------------------------------------------------------
# 2. Compile
# ---------------------------------------------------------------------------

$script:compiler = Find-Ahk2Exe -Explicit $Ahk2Exe
Write-Host "Ahk2Exe: $($script:compiler)"

$targets = if ($Architecture -eq 'both') { @('x64', 'x86') } else { @($Architecture) }
$built = @()

foreach ($arch in $targets) {
    # The release workflow publishes CapsLock-.exe for x64 and CapsLock-_x86.exe
    # for x86; keep the same names so a local build is directly comparable.
    $name = if ($arch -eq 'x64') { 'CapsLock-.exe' } else { 'CapsLock-_x86.exe' }
    $out = Join-Path $OutDir $name
    $base = Get-BaseFile -Arch $arch

    if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }

    Write-Host ''
    Write-Host "Compiling $arch with base $base"

    # Ahk2Exe is a GUI-subsystem program like AutoHotkey itself: a plain `&`
    # returns before it finishes and leaves $LASTEXITCODE untouched, which would
    # report success for a compile that is still running (see the header of
    # scripts\ci\Invoke-Ahk.ps1). Start-Process waits and reports the real code.
    $arguments = @(
        '/in', ('"{0}"' -f $script),
        '/out', ('"{0}"' -f $out),
        '/icon', ('"{0}"' -f $icon),
        '/base', ('"{0}"' -f $base),
        '/silent', 'verbose'
    )
    $stdout = Join-Path $OutDir "ahk2exe-$arch.log"
    $process = Start-Process -FilePath $script:compiler -ArgumentList $arguments -Wait -NoNewWindow -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError "$stdout.err"

    $logText = ''
    foreach ($log in @($stdout, "$stdout.err")) {
        if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -gt 0) {
            $content = (Get-Content -LiteralPath $log -Raw)
            $logText += $content
            Write-Host "--- $(Split-Path -Leaf $log) ---"
            Write-Host $content
        }
        Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
    }

    if ($process.ExitCode -ne 0) {
        $tail = ($logText -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last 6) -join ' | '
        Fail "Ahk2Exe failed for $arch with exit code $($process.ExitCode). Last output: $tail"
    }
    if (-not (Test-Path -LiteralPath $out)) {
        Fail "Ahk2Exe reported success but produced no $out"
    }
    $built += $out
}

# ---------------------------------------------------------------------------
# 3. Verify the packaged payload
# ---------------------------------------------------------------------------

if (-not $SkipCSharp -and -not $SkipPayloadVerify) {
    foreach ($exe in $built) {
        & (Join-Path $PSScriptRoot 'ci\Test-CSharpPayload.ps1') -Path $exe
    }
}

Write-Host ''
Write-Host 'Build summary'
foreach ($exe in $built) {
    $size = (Get-Item -LiteralPath $exe).Length
    Write-Host ('  {0} ({1:N0} bytes)' -f $exe, $size)
}
