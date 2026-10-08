# Hardened release APK build (obfuscation + integrity pin workflow).
# Usage (from cleanshare/):
#   .\tool\build_release_android.ps1
#   .\tool\build_release_android.ps1 -SkipEngine

param(
    [switch]$SkipEngine,
    # Byte-patching libapp.so breaks plugin registration — do not use for installable APKs.
    [switch]$PartialScrub,
    # Build from C:\build\zerotrace so libapp.so has no username/OneDrive path (recommended for public APK).
    [switch]$NeutralPath
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$symbols = Join-Path $root "build\symbols"
$apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"

Push-Location $root
try {
    if (-not $SkipEngine) {
        Write-Host "Building Android engine..."
        & "$PSScriptRoot\build_engine_android.ps1"
    }

    New-Item -ItemType Directory -Force -Path $symbols | Out-Null

    Write-Host ""
    Write-Host "Building obfuscated release APK (arm64)..."
    flutter build apk --release `
        --target-platform android-arm64 `
        --obfuscate `
        --split-debug-info="$symbols"

    if (-not (Test-Path $apk)) {
        Write-Error "APK not found at $apk"
    }

    Write-Host ""
    Write-Host "Pinning stripped engine hash..."
    dart run tool/embed_engine_hash.dart --platform android --release-apk

    Write-Host ""
    Write-Host "Pinning APK signing certificate..."
    $apksigner = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Recurse -Filter "apksigner.bat" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($apksigner) {
        $out = & $apksigner.FullName verify --print-certs $apk 2>&1 | Out-String
        if ($out -match 'SHA-256 digest:\s*([0-9a-fA-F]{64})') {
            $certSha = $Matches[1].ToLower()
            dart run tool/embed_release_cert.dart --sha256 $certSha
            Write-Host "Rebuilding once more so cert pin is embedded in APK..."
            flutter build apk --release `
                --target-platform android-arm64 `
                --obfuscate `
                --split-debug-info="$symbols"
        } else {
            Write-Warning "Could not parse cert SHA-256 from apksigner output."
        }
    } else {
        Write-Warning "apksigner not found - pin cert manually with embed_release_cert.dart"
    }

    if ($PartialScrub) {
        Write-Host ""
        Write-Warning "Partial scrub breaks cold start (plugin registrant URI). Use -NeutralPath instead."
        Write-Host "Partial scrub (username + OneDrive) in libapp.so + re-signing..."
        & "$PSScriptRoot\scrub_apk_paths.ps1" -Apk $apk
    } else {
        Write-Host ""
        Write-Host "No libapp.so scrub (required for a bootable APK)."
    }

    Write-Host ""
    Write-Host "Release APK: $apk"
    Write-Host "Debug symbols (keep private): $symbols"
} finally {
    Pop-Location
}
