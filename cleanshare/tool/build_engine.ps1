# Builds zerotrace_engine and copies the DLL beside the Windows runner.
# Usage (from cleanshare/):
#   .\tool\build_engine.ps1
#   .\tool\build_engine.ps1 -Flutter

param(
    [switch]$Flutter,
    [switch]$NoOnnx
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$crate = Join-Path $root "engine\zerotrace_engine"

$featureArgs = @("--features", "onnx")
if ($NoOnnx) {
    $featureArgs = @()
    Write-Host "Building without ONNX runtime..."
} else {
    Write-Host "Building with ONNX runtime (ort)..."
}

Write-Host "Building zerotrace_engine (release)..."
Push-Location $crate
cargo build --release @featureArgs
Pop-Location

$dll = Join-Path $crate "target\release\zerotrace_engine.dll"
if (-not (Test-Path $dll)) {
    Write-Error "Build failed - DLL not found at $dll"
}

if ($Flutter) {
    Write-Host "Building Flutter Windows app..."
    Push-Location $root
    flutter build windows
    Pop-Location
}

& (Join-Path $PSScriptRoot "copy_engine_dll.ps1")

Write-Host ""
Write-Host "zerotrace_engine bundled. Run: flutter run -d windows"
