<#
.SYNOPSIS
    Verifies that a compiled CapsLock- EXE carries the C# payload.

.DESCRIPTION
    The C# backend is packaged as two RCDATA resources, named by the generated
    CSharpPayload.ahk directives:

        CSHARP_DLL       lib\CapsLockSharp.dll
        AHK_BRIDGE_DLL   lib\ahk#\lib\ahk#.bridge.dll

    This reads the resource directory of the finished EXE (the file is mapped
    read-only as a data file, it is never executed) and fails when a resource is
    missing or empty. That is the check that makes the packaging claim real: if
    Ahk2Exe ever stopped honouring directives inside an #Included file, or the
    payload was not provisioned before compiling, a release would ship an EXE
    that silently cannot start the CLR. Here it fails the build instead.

    When the source files are still on disk their sizes are compared as well.

.PARAMETER Path
    The compiled executable to inspect.

.EXAMPLE
    .\scripts\ci\Test-CSharpPayload.ps1 -Path .\build\CapsLock-.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Path
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "No such executable: $Path"
}
$exePath = (Resolve-Path -LiteralPath $Path).ProviderPath

if (-not ('CapsLock.PayloadInspector' -as [type])) {
    Add-Type -Namespace CapsLock -Name PayloadInspector -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr LoadLibraryEx(string fileName, System.IntPtr reserved, uint flags);

[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr FindResource(System.IntPtr module, string name, System.IntPtr type);

[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
public static extern uint SizeofResource(System.IntPtr module, System.IntPtr resource);

[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
public static extern bool FreeLibrary(System.IntPtr module);
'@
}

$LOAD_LIBRARY_AS_DATAFILE = 0x2
$RT_RCDATA = [System.IntPtr]10

$module = [CapsLock.PayloadInspector]::LoadLibraryEx($exePath, [System.IntPtr]::Zero, $LOAD_LIBRARY_AS_DATAFILE)
if ($module -eq [System.IntPtr]::Zero) {
    throw "Could not open $exePath as a data file (Win32 error $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
}

$expected = @(
    @{ Name = 'CSHARP_DLL'; Source = 'lib\CapsLockSharp.dll'; Label = 'services assembly' },
    @{ Name = 'AHK_BRIDGE_DLL'; Source = 'lib\ahk#\lib\ahk#.bridge.dll'; Label = 'AHK# bridge' }
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).ProviderPath
$failures = @()

Write-Host "Inspecting $exePath"

try {
    foreach ($entry in $expected) {
        $resource = [CapsLock.PayloadInspector]::FindResource($module, $entry.Name, $RT_RCDATA)
        if ($resource -eq [System.IntPtr]::Zero) {
            $failures += ('resource {0} ({1}) is not in the executable' -f $entry.Name, $entry.Label)
            continue
        }

        $size = [CapsLock.PayloadInspector]::SizeofResource($module, $resource)
        if ($size -eq 0) {
            $failures += ('resource {0} ({1}) is empty' -f $entry.Name, $entry.Label)
            continue
        }

        $note = ''
        $sourcePath = Join-Path $repoRoot $entry.Source
        if (Test-Path -LiteralPath $sourcePath) {
            $sourceSize = (Get-Item -LiteralPath $sourcePath).Length
            if ($sourceSize -ne $size) {
                $failures += ('resource {0} is {1} bytes but {2} is {3} bytes - stale payload' -f $entry.Name, $size, $entry.Source, $sourceSize)
            }
            else {
                $note = " (matches $entry.Source)"
            }
        }

        Write-Host ('  {0,-15} {1,10:N0} bytes  {2}{3}' -f $entry.Name, $size, $entry.Label, $note)
    }
}
finally {
    [void] [CapsLock.PayloadInspector]::FreeLibrary($module)
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host ('::error::{0}' -f $failure)
        Write-Host "FAIL $failure"
    }
    throw 'The compiled EXE does not carry a complete C# payload. Run scripts\Setup-CSharpBackend.ps1 before compiling, or build with -SkipCSharp for a pure-AHK executable.'
}

Write-Host 'PASS the C# payload is packaged'
