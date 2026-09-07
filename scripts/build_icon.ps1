$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot '..\assets\CapsLock-icon.svg'
$output = Join-Path $PSScriptRoot '..\assets\CapsLock-.ico'

$magick = Get-Command magick.exe -ErrorAction SilentlyContinue
if (-not $magick) {
    throw 'ImageMagick (magick.exe) is required to build the application icon.'
}

& $magick.Source -background none $source -define icon:auto-resize=256,128,64,48,32,16 $output
if ($LASTEXITCODE -ne 0) {
    throw "ImageMagick failed while generating the ICO (exit code $LASTEXITCODE)."
}

if (-not (Test-Path $output) -or (Get-Item $output).Length -eq 0) {
    throw 'ImageMagick did not produce a valid ICO file.'
}

Write-Host "Generated $output"
