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

    At runtime Core\CSharpRuntime.ahk extracts the resources next to the EXE
    (or into %LOCALAPPDATA%\CapsLock- when the install folder is read-only) and
    Services.Boot() starts the CLR on the first C# request only.

.PARAMETER Architecture
    x64 (default), x86, or both - the same layout the release workflow ships.

.PARAMETER OutDir
    Where the executables are written. Defaults to build\.

.PARAMETER SkipCSharp
    Build a pure-AHK executable and remove any generated payload include.

.PARAMETER RebuildIcon
    Regenerate assets\CapsLock-.ico first (needs ImageMagick). The committed ICO
    is used otherwise, so a build machine without ImageMagick still works.

.PARAMETER Ahk2Exe
    Explicit path to Ahk2Exe.exe. Searched for otherwise.

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

    [switch] $RebuildIcon,

    [string] $Ahk2Exe = ''
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

function Find-Ahk2Exe {
    param([string] $Explicit)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
            throw "Ahk2Exe.exe not found: $Explicit"
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
    throw 'Ahk2Exe.exe was not found. Install the AutoHotkey compiler (the v2 Dash offers it), or pass -Ahk2Exe.'
}

function Get-BaseFile {
    param([string] $Ahk2ExePath, [string] $Arch)

    $bits = if ($Arch -eq 'x64') { 64 } else { 32 }

    # The base file may sit in the compiler folder (the shipped
    # "Unicode <bits>-bit.bin") or be one of the interpreters in an install, so
    # look through every AutoHotkey location this repository knows about.
    $compilerDir = Split-Path -Parent $Ahk2ExePath
    $roots = @($compilerDir, (Split-Path -Parent $compilerDir))
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

    # Last resort: whatever the AutoHotkey installer unpacked into the repo.
    $searchRoot = Join-Path $repoRoot 'autohotkey'
    if (Test-Path -LiteralPath $searchRoot) {
        foreach ($name in $names) {
            $found = Get-ChildItem -LiteralPath $searchRoot -Recurse -Filter $name -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    throw "No $Arch base file was found for $Ahk2ExePath. Pass a -Ahk2Exe from an AutoHotkey install that has one (Compiler\Unicode $bits-bit.bin)."
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
    # Called in this runspace: a throw in the setup script stops the build here.
    & (Join-Path $PSScriptRoot 'Setup-CSharpBackend.ps1')
}

if ($RebuildIcon) {
    & (Join-Path $PSScriptRoot 'build_icon.ps1')
}
if (-not (Test-Path -LiteralPath $icon)) {
    throw "The application icon is missing: $icon (run with -RebuildIcon, which needs ImageMagick)."
}

# ---------------------------------------------------------------------------
# 2. Compile
# ---------------------------------------------------------------------------

$compiler = Find-Ahk2Exe -Explicit $Ahk2Exe
Write-Host "Ahk2Exe: $compiler"

$targets = if ($Architecture -eq 'both') { @('x64', 'x86') } else { @($Architecture) }
$built = @()

foreach ($arch in $targets) {
    # The release workflow publishes CapsLock-.exe for x64 and CapsLock-_x86.exe
    # for x86; keep the same names so a local build is directly comparable.
    $name = if ($arch -eq 'x64') { 'CapsLock-.exe' } else { 'CapsLock-_x86.exe' }
    $out = Join-Path $OutDir $name
    $base = Get-BaseFile -Ahk2ExePath $compiler -Arch $arch

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
    $process = Start-Process -FilePath $compiler -ArgumentList $arguments -Wait -NoNewWindow -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError "$stdout.err"
    foreach ($log in @($stdout, "$stdout.err")) {
        if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -gt 0) {
            Write-Host "--- $(Split-Path -Leaf $log) ---"
            Write-Host (Get-Content -LiteralPath $log -Raw)
        }
        Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
    }
    if ($process.ExitCode -ne 0) {
        throw "Ahk2Exe failed for $arch with exit code $($process.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $out)) {
        throw "Ahk2Exe reported success but produced no $out"
    }
    $built += $out
}

# ---------------------------------------------------------------------------
# 3. Verify the packaged payload
# ---------------------------------------------------------------------------

if (-not $SkipCSharp) {
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
