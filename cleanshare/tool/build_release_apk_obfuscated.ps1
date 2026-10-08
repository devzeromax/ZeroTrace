# Builds a release APK with Dart + Android R8 obfuscation enabled.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

Write-Host ""
Write-Host "Release APK:" (Resolve-Path "build/app/outputs/flutter-apk/app-release.apk")
Write-Host "Dart symbols:" (Resolve-Path "build/app/outputs/symbols")
