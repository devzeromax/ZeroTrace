# Copies zerotrace_engine.dll next to the Flutter Windows runner executable.
# Run from cleanshare/:  .\tool\copy_engine_dll.ps1
# Optional:            .\tool\copy_engine_dll.ps1 -Build

param(
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$dllSource = Join-Path $root "engine\zerotrace_engine\target\release\zerotrace_engine.dll"

if (-not (Test-Path $dllSource)) {
    Write-Error @"
Rust DLL not found at:
  $dllSource

Build it first:
  cd engine\zerotrace_engine
  cargo build --release --features onnx
"@
}

if ($Build) {
    Write-Host "Building Flutter Windows app..."
    Push-Location $root
    flutter build windows
    Pop-Location
}

$destDirs = @(
    (Join-Path $root "build\windows\x64\runner\Debug"),
    (Join-Path $root "build\windows\x64\runner\Release")
)

$copied = $false
foreach ($dir in $destDirs) {
    $parent = Split-Path $dir -Parent
    if (-not (Test-Path $parent)) {
        Write-Warning "Skipping $dir - run 'flutter run -d windows' or 'flutter build windows' first."
        continue
    }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Copy-Item -Path $dllSource -Destination $dir -Force
    Write-Host "Copied zerotrace_engine.dll -> $dir"
    $copied = $true
}

if (-not $copied) {
    Write-Host ""
    Write-Host "No runner folder yet. Start once with:"
    Write-Host "  flutter run -d windows"
    Write-Host "Then re-run:"
    Write-Host "  .\tool\copy_engine_dll.ps1"
    exit 1
}
