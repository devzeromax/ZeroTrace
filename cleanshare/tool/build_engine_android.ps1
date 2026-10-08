# Builds zerotrace_engine for Android and copies .so into jniLibs.
# ONNX Runtime prebuilts support arm64-v8a only (not armeabi-v7a / x86_64).
# Usage (from cleanshare/):
#   .\tool\build_engine_android.ps1
#   .\tool\build_engine_android.ps1 -Flutter   # also rebuild release APK

param(
    [switch]$Flutter,
    [switch]$NoOnnx
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$crate = Join-Path $root "engine\zerotrace_engine"
$jniRoot = Join-Path $root "android\app\src\main\jniLibs"

# ort download-binaries only ships ONNX Runtime for arm64 on Android.
$targets = @(
    @{ rust = "aarch64-linux-android"; abi = "arm64-v8a" }
)

$featureArgs = @("--features", "onnx")
if ($NoOnnx) {
    $featureArgs = @()
    Write-Host "Building without ONNX runtime..."
} else {
    Write-Host "Building with ONNX runtime (ort, arm64-v8a only)..."
}

if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
    Write-Host "Installing cargo-ndk..."
    cargo install cargo-ndk
}

foreach ($t in $targets) {
    rustup target add $t.rust | Out-Null
}

# Pick newest installed NDK (Flutter uses flutter.ndkVersion from the SDK).
$sdkRoot = $env:ANDROID_HOME
if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
if (-not $sdkRoot) { $sdkRoot = "$env:LOCALAPPDATA\Android\Sdk" }
$ndkRoot = Join-Path $sdkRoot "ndk"
if (-not (Test-Path $ndkRoot)) {
    Write-Error "Android NDK not found under $ndkRoot. Install via Android Studio SDK Manager."
}
$ndkVersion = (Get-ChildItem $ndkRoot | Sort-Object Name -Descending | Select-Object -First 1).Name
$env:ANDROID_NDK_HOME = Join-Path $ndkRoot $ndkVersion
Write-Host "Using NDK: $env:ANDROID_NDK_HOME"

$ndkTargets = $targets | ForEach-Object { $_.abi }
Write-Host "Building zerotrace_engine for Android ($($ndkTargets -join ', '))..."

# Privacy: remove the build machine's home path (username, .cargo registry,
# project folder) from panic-location / debug strings baked into the .so.
# Remapping the whole user-home prefix covers C:\Users\<user>\.cargo and the
# project path in one rule. Add both separator styles for rustc on Windows.
$homeWin = $env:USERPROFILE
$homeFwd = $homeWin -replace '\\', '/'
$remap = "--remap-path-prefix=$homeWin=/build --remap-path-prefix=$homeFwd=/build"
if ($env:RUSTFLAGS) {
    $env:RUSTFLAGS = "$($env:RUSTFLAGS) $remap"
} else {
    $env:RUSTFLAGS = $remap
}
Write-Host "RUSTFLAGS: $env:RUSTFLAGS"

Push-Location $crate
try {
    $ndkArgs = @()
    foreach ($abi in $ndkTargets) {
        $ndkArgs += @("-t", $abi)
    }
    $ndkArgs += @("-o", $jniRoot, "build", "--release") + $featureArgs
    & cargo ndk @ndkArgs
} finally {
    Pop-Location
}

$missing = @()
foreach ($t in $targets) {
    $so = Join-Path $jniRoot "$($t.abi)\libzerotrace_engine.so"
    if (-not (Test-Path $so)) {
        $missing += $so
    } else {
        $size = (Get-Item $so).Length / 1MB
        Write-Host "OK $($t.abi) -> $so ($([math]::Round($size, 1)) MB)"
    }
}

if ($missing.Count -gt 0) {
    Write-Error ("Build failed - missing libraries:" + [Environment]::NewLine + ($missing -join [Environment]::NewLine))
}

# libzerotrace_engine.so links against libc++_shared — must ship in the APK.
$prebuiltHost = if ($IsMacOS) { "darwin-x86_64" } elseif ($IsLinux) { "linux-x86_64" } else { "windows-x86_64" }
$libcxxRoot = Join-Path $env:ANDROID_NDK_HOME "toolchains\llvm\prebuilt\$prebuiltHost\sysroot\usr\lib"
foreach ($t in $targets) {
    $abiFolder = switch ($t.abi) {
        "arm64-v8a" { "aarch64-linux-android" }
        "armeabi-v7a" { "arm-linux-androideabi" }
        "x86_64" { "x86_64-linux-android" }
        default { $null }
    }
    if (-not $abiFolder) { continue }
    $libcxx = Join-Path $libcxxRoot "$abiFolder\libc++_shared.so"
    if (-not (Test-Path $libcxx)) {
        Write-Warning "libc++_shared.so not found for $($t.abi) at $libcxx"
        continue
    }
    $destDir = Join-Path $jniRoot $t.abi
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $dest = Join-Path $destDir "libc++_shared.so"
    Copy-Item $libcxx $dest -Force
    $size = (Get-Item $dest).Length / 1MB
    Write-Host "OK $($t.abi) -> $dest (libc++_shared, $([math]::Round($size, 1)) MB)"
}

Write-Host ""
Write-Host "Android engine libraries bundled in:"
Write-Host "  $jniRoot"

if ($Flutter) {
    Write-Host ""
    Write-Host "Building release APK..."
    Push-Location $root
    flutter build apk --release --target-platform android-arm64
    Pop-Location
    Write-Host ""
    Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk"
} else {
    Write-Host ""
    Write-Host "Pin engine hash for release integrity checks:"
    Write-Host "  dart run tool/embed_engine_hash.dart --platform android"
    Write-Host ""
}
