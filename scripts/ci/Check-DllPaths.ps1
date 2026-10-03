<#
.SYNOPSIS
    Rejects DLL names that carry an escaped backslash.

.DESCRIPTION
    AutoHotkey v2 escapes with a backtick, never with a backslash: inside a
    quoted string "\\" is two literal backslash characters. A call written as

        DllCall("gdi32\\CreateRoundRectRgn", ...)

    therefore asks Windows to load a DLL literally named "gdi32\\", which
    throws "Failed to load DLL" at runtime and ends the thread that made the
    call (a settings window that never opens, for instance). AutoHotkey's own
    syntax check cannot catch it, because the string itself is valid - only the
    DLL name inside it is wrong.

    This guard scans every .ahk file for "<dll>\<Function>" string literals
    whose backslash run is longer than one character and fails, reporting file
    and line, when it finds one.

.PARAMETER RepoRoot
    Repository root to scan. Defaults to the folder two levels above this
    script (scripts\ci\*.ps1 -> <repo>).

.EXAMPLE
    .\scripts\ci\Check-DllPaths.ps1
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).ProviderPath
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath

# A quoted "<dll>\<Function>" literal; group 1 captures the backslash run.
$pattern = [regex]'"[A-Za-z0-9_]+(\\+)[A-Za-z][A-Za-z0-9_]*"'

$files = @(Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ahk' -File |
    Where-Object { $_.FullName -notmatch '[\\/](?:\.git|autohotkey|build|node_modules)[\\/]' })

$offenders = [System.Collections.Generic.List[string]]::new()

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    foreach ($match in $pattern.Matches($content)) {
        if ($match.Groups[1].Value.Length -le 1) {
            continue
        }
        $line = ($content.Substring(0, $match.Index) -split "`n").Count
        $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/')
        $offenders.Add(('{0} ({1}): {2}' -f $relative, $line, $match.Value))
    }
}

if ($offenders.Count -gt 0) {
    foreach ($offender in $offenders) {
        Write-Host ('::error::{0}: doubled backslash in a DLL name. AutoHotkey v2 does not treat "\" as an escape character - use a single backslash.' -f $offender)
    }
    throw "Found $($offenders.Count) DLL name(s) with an escaped backslash."
}

Write-Host "OK: $($files.Count) .ahk file(s) scanned, every DLL name uses a single backslash."
