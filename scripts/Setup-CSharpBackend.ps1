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
        raw.githubusercontent.com (Invoke-WebRequest -OutFile keeps the bytes
        verbatim), unless they are already there;
      * the bridge is then checked against the SHA-256 that AHK# pins in its own
        source, because AHK# refuses to load a DLL whose digest differs - better
        to fail here with one line than at CLR boot later;
      * the services assembly is built with the .NET SDK when it is missing.

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

.PARAMETER NoPayloadInclude
    Leave CSharpPayload.ahk alone instead of writing it.

.EXAMPLE
    .\scripts\Setup-CSharpBackend.ps1

.EXAMPLE
    .\scripts\Setup-CSharpBackend.ps1 -Force
#>
[CmdletBinding()]
param(
    [string] $BridgeCommit = 'e3b895c7590eba47748b0ed963b7978c237d1daf',

    [switch] $Force,

    [switch] $SkipAssembly,

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
    # AHK# writes the digest of the committed DLL into its own source and
    # refuses to load anything else, so that file is the authority here.
    if (-not (Test-Path -LiteralPath $bridgeAhk)) { return '' }
    $text = Get-Content -LiteralPath $bridgeAhk -Raw
    if ($text -match '(?i)AHK_SHARP_BRIDGE_SHA256[^0-9a-fA-F]*([0-9a-fA-F]{64})') {
        return $Matches[1].ToLowerInvariant()
    }
    return ''
}

function Get-TextFile {
    param([string] $Url, [string] $Destination, [string] $Label)
    Write-Host "Downloading $Label"
    # The progress stream costs more than the transfer on Windows PowerShell 5.1.
    $previousProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }
    finally {
        $ProgressPreference = $previousProgress
    }
    if (-not (Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -eq 0) {
        throw "Download produced no $Label from $Url"
    }
}

# GitHub rejects TLS 1.0/1.1, which Windows PowerShell 5.1 still negotiates by
# default. Tls12 exists on every supported .NET 4.x, but resolve it by name so
# an older runtime fails here instead of at the first request.
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
    @{ Name = 'ahk#.ahk'; Url = "https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.ahk" },
    @{ Name = 'ahk#.bridge.dll'; Url = "https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/ahk%23.bridge.dll" },
    @{ Name = 'build.ps1'; Url = "https://raw.githubusercontent.com/owhs/AHKSharp/$BridgeCommit/lib/build.ps1" }
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
    Get-TextFile -Url $file.Url -Destination $target -Label $file.Name
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
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        throw 'dotnet was not found on PATH. Install the .NET 8 SDK, pass -SkipAssembly, or use the one-click setup in the Settings Center (it downloads the published assembly).'
    }
    if (-not (Test-Path -LiteralPath $project)) {
        throw "The services project is missing: $project"
    }
    Write-Host 'Building the services assembly (netstandard2.0, AnyCPU)'
    & $dotnet.Source build $project -c Release --nologo -o $libDir
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $assembly)) {
        throw "dotnet build did not produce $assembly"
    }
}

# ---------------------------------------------------------------------------
# 3. The generated compiler-directive include
# ---------------------------------------------------------------------------

if ($NoPayloadInclude) {
    Write-Host 'Leaving CSharpPayload.ahk alone (-NoPayloadInclude).'
}
elseif ((Test-Path -LiteralPath $assembly) -and (Test-Path -LiteralPath $bridgeDll)) {
    # Ahk2Exe resolves AddResource paths against the script's own directory, so
    # these stay relative to the repository root next to CapsLock-.ahk.
    $lines = @(
        '; GENERATED FILE - do not edit and do not commit.',
        ';',
        '; Written by scripts\Setup-CSharpBackend.ps1. These are the only lines that make',
        '; Ahk2Exe embed the C# backend into CapsLock-.exe; CapsLock-.ahk picks the file up',
        '; through `#Include *i CSharpPayload.ahk`. Delete it for a pure-AHK executable.',
        '; Core\CSharpRuntime.ahk extracts both resources on first use and verifies them.',
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
