# Release APK built from a neutral path (no username / OneDrive in libapp.so).
# Syncs cleanshare to C:\build\zerotrace\cleanshare, builds there, copies APK back.
#
# Usage (from cleanshare/):
#   .\tool\build_release_neutral.ps1
#   .\tool\build_release_neutral.ps1 -SkipEngine

param([switch]$SkipEngine)

$ErrorActionPreference = "Stop"
$src = Split-Path $PSScriptRoot -Parent
$neutralRoot = "C:\build\zerotrace"
$neutral = Join-Path $neutralRoot "cleanshare"
$outApk = Join-Path $src "build\app\outputs\flutter-apk\app-release.apk"

Write-Host "Syncing project to neutral build path: $neutral"
New-Item -ItemType Directory -Force -Path $neutralRoot | Out-Null

# Mirror source; drop heavy/regenerated dirs so the neutral tree gets a clean Flutter build.
$robolog = Join-Path $env:TEMP "zerotrace-neutral-robocopy.log"
robocopy $src $neutral /MIR /XD build .dart_tool .git /XF *.apk /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed (exit $LASTEXITCODE). See $robolog"
}

Push-Location $neutral
try {
    Write-Host "flutter pub get..."
    flutter pub get | Out-Host

    Write-Host ""
    Write-Host "Building release from neutral path (no path scrub)..."
    & (Join-Path $neutral "tool\build_release_android.ps1") @PSBoundParameters
} finally {
    Pop-Location
}

$built = Join-Path $neutral "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $built)) {
    Write-Error "Neutral build did not produce $built"
}

New-Item -ItemType Directory -Force -Path (Split-Path $outApk) | Out-Null
Copy-Item $built $outApk -Force
Write-Host ""
Write-Host "Copied neutral-path APK -> $outApk"
