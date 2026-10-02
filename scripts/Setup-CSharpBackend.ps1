<#
.SYNOPSIS
    Provisions the optional C# backend: the pinned AHK# bridge and the
    precompiled CapsLockSharp services assembly.

.DESCRIPTION
    The AHK <-> .NET boundary (issue #12) needs exactly two files before the CLR
    can be started:

        lib\ahk#\lib\ahk#.bridge.dll      the pinned AHK# bridge
        lib\CapsLockSharp.dll             the precompiled services (AnyCPU)

    A `git clone` of AHKSharp at the pinned commit plus `dotnet build` produces
    the same layout (see docs\perf\csharp-boundary.md); this script does it
    without git and without Visual Studio:

      * the three runtime files of the pinned AHK# commit are downloaded from
        raw.githubusercontent.com or fallback mirrors (Invoke-WebRequest -OutFile keeps the bytes
        verbatim), unless they are already there;
      * the bridge is then checked against the SHA-256 that AHK# pins in its own
        source, because AHK# refuses to load a DLL whose digest differs - better
        to fail here with one line than at CLR boot later;
      * the services assembly is built with the .NET 8 SDK when it is missing
        (with support for installing .NET 8 SDK via winget when missing).

    Finally it writes CSharpPayload.ahk next to CapsLock-.ahk, holding only the
    compiler directives that embed both files into the EXE. CapsLock-.ahk has
    `#Include *i CSharpPayload.ahk`, so with the file present a build packages
    the C# backend and without it the very same source builds pure AHK.

    Nothing here is required to run the application: the shipped default stays
    `[Services] Backend=ahk` and every service has an AHK fallback.

.PARAMETER BridgeCommit
    AHK# commit to use. The default is the one pinned by
    docs\perf\csharp-boundary.md, Core\CSharpRuntime.ahk and dotnet.yml.

.PARAMETER Force
    Re-download and rebuild even when the files already exist.

.PARAMETER SkipAssembly
    Provision the bridge only, for example on a machine without the .NET SDK.

.PARAMETER InstallDotNet8
    Automatically attempt to install .NET 8 SDK via winget if missing.

.PARAMETER NoPayloadInclude
    Leave CSharpPayload.ahk alone instead of writing it.

.EXAMPLE
    .\scripts\Setup-CSharpBackend.ps1

.EXAMPLE
    .\scripts\Setup-CSharpBackend.ps1 -Force

.EXAMPLE
    .\scripts\Setup-CSharpBackend.ps1 -InstallDotNet8
#>
[CmdletBinding()]
param(
    [string] $BridgeCommit = 'e3b895c7590eba47748b0ed963b7978c237d1daf',

    [switch] $Force,

    [switch] $SkipAssembly,

    [switch] $InstallDotNet8,

    [switch] $NoPayloadInclude
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$libDir = Join-Path $repoRoot 'lib'
$bridgeDir = Join-Path $libDir 'ahk#\lib'
$bridgeDll = Join-Path $bridgeDir 'ahk#.bridge.dll'
$bridgeAhk = Join-Path $bridgeDir 'ahk#.ahk'
$assembly = Join-Path $libDir 'CapsLockSharp.dll'
$project = Join-Path $repoRoot 'src\CapsLockSharp\CapsLockSharp.csproj'
$payloadInclude = Join-Path $repoRoot 'CSharpPayload.ahk'

function Get-Sha256 {
    param([string] $Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
        }
        finally { $stream.Dispose() }
    }
    finally { $sha.Dispose() }
}

function Get-PinnedBridgeDigest {
    if (-not (Test-Path -LiteralPath $bridgeAhk)) { return '' }
    $text = Get-Content -LiteralPath $bridgeAhk -Raw
    if ($text -match '(?i)AHK_SHARP_BRIDGE_SHA256[^0-9a-fA-F]*([0-9a-fA-F]{64})') {
        return $Matches[1].ToLowerInvariant()
    }
    return ''
}

function Get-TextFile {
    param(
        [string[]] $Urls,
        [string] $Destination,
        [string] $Label
    )
    Write-Host "Downloading $Label"
    $previousProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $downloaded = $false
    $lastError = $null

    try {
        foreach ($url in $Urls) {
            try {
                Invoke-WebRequest -Uri $url -OutFile $Destination -UseBasicParsing -TimeoutSec 30
                if ((Test-Path -LiteralPath $Destination) -and (Get-Item -LiteralPath $Destination).Length -gt 0) {
                    $downloaded = $true
                    Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue
                    break
                }
            }
            catch {
                $lastError = $_
                if (Test-Path -LiteralPath $Destination) {
                    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    finally {
        $ProgressPreference = $previousProgress
    }

    if (-not $downloaded) {
        throw "Download produced no $Label. Tried URLs: $($Urls -join ', '). Last error: $lastError"
    }
}

function Refresh-PathEnvironment {
    try {
        $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $combined = "$machine;$user"
        if ($env:ProgramFiles) {
            $pfDotNet = Join-Path $env:ProgramFiles 'dotnet'
            if ((Test-Path -LiteralPath $pfDotNet) -and ($combined -notmatch [regex]::Escape($pfDotNet))) {
                $combined = "$pfDotNet;$combined"
            }
        }
        $env:PATH = $combined
    }
    catch {}
}

function Get-DotNetPath {
    Refresh-PathEnvironment
    $cmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'dotnet\dotnet.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\dotnet\dotnet.exe')
    )
    foreach ($cand in $candidates) {
        if ($cand -and (Test-Path -LiteralPath $cand)) {
            $dir = Split-Path -Parent $cand
            $env:PATH = "$dir;$($env:PATH)"
            return $cand
        }
    }
    return $null
}

function Test-DotNet8Sdk {
    param([string] $DotNetExe)
    if (-not $DotNetExe) { return $false }
    try {
        $sdks = & $DotNetExe --list-sdks 2>$null
        foreach ($line in $sdks) {
            if ($line -match '^\s*8\.') {
                return $true
            }
        }
        $ver = & $DotNetExe --version 2>$null
        if ($ver -match '^8\.') {
            return $true
        }
    }
    catch {}
    return $false
}

try {
    $tls12 = [System.Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor $tls12
}
catch {
    Write-Warning "Could not enable TLS 1.2 ($_); downloads may fail."
}

# ---------------------------------------------------------------------------
# 1. The pinned AHK# bridge
# ---------------------------------------------------------------------------

$bridgeFiles = @(
    @{
        Name = 'ahk#.ahk'
        Urls = @(
            "https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.ahk",
            "https://raw.gitmirror.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.ahk",
            "https://ghfast.top/https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.ahk",
            "https://cdn.jsdelivr.net/gh/owhs/AHKSharp@$BridgeCommit/lib/ahk%23.ahk"
        )
    },
    @{
        Name = 'ahk#.bridge.dll'
        Urls = @(
            "https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.bridge.dll",
            "https://raw.gitmirror.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.bridge.dll",
            "https://ghfast.top/https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.bridge.dll",
            "https://cdn.jsdelivr.net/gh/owhs/AHKSharp@$BridgeCommit/lib/ahk%23.bridge.dll"
        )
    },
    @{
        Name = 'build.ps1'
        Urls = @(
            "https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/build.ps1",
            "https://raw.gitmirror.com/owhs/AHKSharp/$BridgeCommit/lib/build.ps1",
            "https://ghfast.top/https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/build.ps1",
            "https://cdn.jsdelivr.net/gh/owhs/AHKSharp@$BridgeCommit/lib/build.ps1"
        )
    }
)

if (-not (Test-Path -LiteralPath $bridgeDir)) {
    New-Item -ItemType Directory -Path $bridgeDir -Force | Out-Null
}

foreach ($file in $bridgeFiles) {
    $target = Join-Path $bridgeDir $file.Name
    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        Write-Host "Keeping existing $($file.Name)"
        continue
    }
    Get-TextFile -Urls $file.Urls -Destination $target -Label $file.Name
}

if (-not (Test-Path -LiteralPath $bridgeDll)) {
    throw "The AHK# bridge is missing: $bridgeDll"
}

$pinned = Get-PinnedBridgeDigest
if ($pinned -eq '') {
    Write-Warning 'No pinned SHA-256 found in ahk#.ahk; AHK# will still verify it at boot.'
}
else {
    $actual = Get-Sha256 -Path $bridgeDll
    if ($actual -ne $pinned) {
        Remove-Item -LiteralPath $bridgeDll -Force
        throw "Bridge SHA-256 mismatch: expected $pinned but got $actual. The download was removed."
    }
    Write-Host "Bridge SHA-256 verified: $pinned"
}

# ---------------------------------------------------------------------------
# 2. The precompiled services assembly
# ---------------------------------------------------------------------------

if ($SkipAssembly) {
    Write-Host 'Skipping the services assembly (-SkipAssembly).'
}
elseif ((Test-Path -LiteralPath $assembly) -and -not $Force) {
    Write-Host "Keeping existing CapsLockSharp.dll"
}
else {
    $dotnet = Get-DotNetPath
    $hasDotNet8 = Test-DotNet8Sdk -DotNetExe $dotnet

    if (-not $hasDotNet8) {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget -and ($InstallDotNet8 -or [Environment]::UserInteractive)) {
            Write-Host 'Missing .NET 8 SDK. Installing via winget (using official winget source)...' -ForegroundColor Cyan
            & $winget.Source install --id Microsoft.DotNet.SDK.8 --source winget --accept-source-agreements --accept-package-agreements
            Refresh-PathEnvironment
            $dotnet = Get-DotNetPath
            $hasDotNet8 = Test-DotNet8Sdk -DotNetExe $dotnet
        }
    }

    if (-not $dotnet) {
        throw 'dotnet was not found on PATH. Install the .NET 8 SDK, pass -InstallDotNet8 to install via winget, pass -SkipAssembly, or use one-click setup in Settings Center.'
    }
    if (-not (Test-Path -LiteralPath $project)) {
        throw "The services project is missing: $project"
    }

    Write-Host 'Building the services assembly (netstandard2.0, AnyCPU)'
    $buildOutput = & $dotnet build $project -c Release --nologo -o $libDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error ('dotnet build failed with exit code {0}:`n{1}' -f $LASTEXITCODE, ($buildOutput -join "`n"))
        throw ('dotnet build failed with exit code {0}. Hint: Ensure .NET 8 SDK is installed and functional.' -f $LASTEXITCODE)
    }
    if (-not (Test-Path -LiteralPath $assembly)) {
        throw "dotnet build did not produce $assembly"
    }
    Unblock-File -LiteralPath $assembly -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# 3. The generated compiler-directive include
# ---------------------------------------------------------------------------

if ($NoPayloadInclude) {
    Write-Host 'Leaving CSharpPayload.ahk alone (-NoPayloadInclude).'
}
elseif ((Test-Path -LiteralPath $assembly) -and (Test-Path -LiteralPath $bridgeDll)) {
    $lines = @(
        '; GENERATED FILE - do not edit and do not commit.',
        ';',
        '; Written by scripts\Setup-CSharpBackend.ps1. These are the only lines that make',
        '; Ahk2Exe embed the C# backend into CapsLock-.exe; CapsLock-.ahk picks the file up',
        '; through `#Include *i CSharpPayload.ahk`. Delete it for a pure-AHK executable.',
        '; Core\CSharpPayload.ahk extracts both resources on first use and verifies them.',
        ";@Ahk2Exe-AddResource lib\CapsLockSharp.dll, CSHARP_DLL",
        ";@Ahk2Exe-AddResource lib\ahk#\lib\ahk#.bridge.dll, AHK_BRIDGE_DLL",
        ''
    )
    Set-Content -LiteralPath $payloadInclude -Value $lines -Encoding ASCII
    Write-Host "Wrote $payloadInclude"
}
else {
    if (Test-Path -LiteralPath $payloadInclude) {
        Remove-Item -LiteralPath $payloadInclude -Force
        Write-Host "Removed $payloadInclude (no complete payload on disk)."
    }
    Write-Warning 'The payload is incomplete, so a build from this checkout stays pure AHK.'
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host 'C# backend provisioning summary'
foreach ($entry in @(
    @{ Label = 'AHK# bridge'; Path = $bridgeDll },
    @{ Label = 'AHK# library'; Path = $bridgeAhk },
    @{ Label = 'Services assembly'; Path = $assembly },
    @{ Label = 'Payload include'; Path = $payloadInclude }
)) {
    if (Test-Path -LiteralPath $entry.Path) {
        $size = (Get-Item -LiteralPath $entry.Path).Length
        Write-Host ('  {0,-18} {1} ({2:N0} bytes)' -f $entry.Label, $entry.Path, $size)
    }
    else {
        Write-Host ('  {0,-18} missing' -f $entry.Label)
    }
}
