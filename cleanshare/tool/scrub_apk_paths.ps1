# UNSAFE FOR INSTALLABLE APKs — byte-patching libapp.so breaks Flutter plugin
# registration (cold start shows "could not start safely"). Use build_release_neutral.ps1
# to compile from C:\build\zerotrace instead.
#
# Usage (from cleanshare/):
#   .\tool\scrub_apk_paths.ps1
#   .\tool\scrub_apk_paths.ps1 -Apk build\app\outputs\flutter-apk\app-release.apk

param(
    [string]$Apk,
    [string]$Keystore,
    [string]$KeyAlias,
    [string]$StorePass,
    [string]$KeyPass,
    [string[]]$Tokens
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not $Apk) { $Apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk" }
if (-not (Test-Path $Apk)) { Write-Error "APK not found: $Apk" }

# Re-sign with the SAME keystore the build used, so the pinned signing-cert SHA
# stays valid. If android/key.properties exists (release signing), use it;
# otherwise fall back to the Android debug keystore.
if (-not $Keystore) {
    $keyProps = Join-Path $root "android\key.properties"
    if (Test-Path $keyProps) {
        $props = @{}
        foreach ($line in Get-Content $keyProps) {
            if ($line -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$') { $props[$Matches[1]] = $Matches[2] }
        }
        $KeyAlias = $props['keyAlias']
        $StorePass = $props['storePassword']
        $KeyPass = $props['keyPassword']
        $storeFile = $props['storeFile']
        # gradle resolves storeFile relative to android/app.
        if ([System.IO.Path]::IsPathRooted($storeFile)) { $Keystore = $storeFile }
        else { $Keystore = Join-Path (Join-Path $root "android\app") $storeFile }
        Write-Host "Re-signing with release keystore from key.properties"
    } else {
        $Keystore = "$env:USERPROFILE\.android\debug.keystore"
        $KeyAlias = "androiddebugkey"
        $StorePass = "android"
        $KeyPass = "android"
        Write-Host "Re-signing with debug keystore (no android/key.properties found)"
    }
}

# Partial scrub (safe default): OS username + OneDrive only.
# Leaves project path segments (e.g. Desktop/ZeroTrace) so the AOT snapshot stays valid.
# Do NOT scrub "Desktop" or "Desktop/ZeroTrace" — those strings overlap Dart identifiers
# and the plugin-registrant URI; equal-length replace corrupts startup.
if (-not $Tokens) {
    $userLeaf = Split-Path $env:USERPROFILE -Leaf
    $Tokens = @($userLeaf, "OneDrive") | Where-Object { $_ -and $_.Length -gt 1 }
}
$forbiddenTokens = @('Desktop', 'Desktop/ZeroTrace', 'Desktop\ZeroTrace', 'cleanshare')
foreach ($tok in $Tokens) {
    foreach ($bad in $forbiddenTokens) {
        if ($tok -eq $bad -or $tok -like "*$bad*") {
            Write-Error "Forbidden scrub token '$tok' - use partial scrub (username + OneDrive only)."
        }
    }
}
Write-Host "Partial scrub tokens: $($Tokens -join ', ')"
Write-Host "(Desktop/ZeroTrace left intact - generic project path only)"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$latin1 = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
# Flutter fat APK embeds the same AOT path string in every ABI's libapp.so.
$targetEntries = @(
    'lib/arm64-v8a/libapp.so',
    'lib/armeabi-v7a/libapp.so',
    'lib/x86_64/libapp.so'
)

# Work on a copy so a failed run never corrupts the build output.
$work = "$Apk.scrub.tmp"
Copy-Item $Apk $work -Force

$totalHits = 0
$zip = [System.IO.Compression.ZipFile]::Open($work, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    foreach ($targetEntry in $targetEntries) {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq $targetEntry }
        if (-not $entry) {
            Write-Host "Skipping missing $targetEntry"
            continue
        }

        $ms = New-Object System.IO.MemoryStream
        $s = $entry.Open()
        $s.CopyTo($ms)
        $s.Close()
        $bytes = $ms.ToArray()
        $text = $latin1.GetString($bytes)

        $entryHits = 0
        foreach ($tok in $Tokens) {
            $hits = [regex]::Matches($text, [regex]::Escape($tok)).Count
            if ($hits -gt 0) {
                $repl = ('x' * $tok.Length)
                $text = $text.Replace($tok, $repl)
                $entryHits += $hits
                Write-Host "  $targetEntry : $tok -> $repl ($hits)"
            }
        }

        if ($entryHits -eq 0) { continue }

        $newBytes = $latin1.GetBytes($text)
        if ($newBytes.Length -ne $bytes.Length) {
            Write-Error "Length changed after redaction in $targetEntry ($($bytes.Length) -> $($newBytes.Length)); aborting."
        }
        # ELF magic sanity check (0x7F 'E' 'L' 'F').
        if (-not ($newBytes[0] -eq 0x7F -and $newBytes[1] -eq 0x45 -and $newBytes[2] -eq 0x4C -and $newBytes[3] -eq 0x46)) {
            Write-Error "Patched $targetEntry lost its ELF header; aborting."
        }
        $w = $entry.Open()
        $w.SetLength(0)
        $w.Write($newBytes, 0, $newBytes.Length)
        $w.Close()
        $totalHits += $entryHits
    }
} finally {
    $zip.Dispose()
}

if ($totalHits -eq 0) {
    Write-Host "No tokens found in any libapp.so - nothing to scrub."
    Remove-Item $work -Force
    exit 0
}

# zipalign (4-byte) then re-sign so the modified zip is valid + trusted.
$buildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Directory |
    Sort-Object Name -Descending | Select-Object -First 1
$zipalign = Join-Path $buildTools.FullName "zipalign.exe"
$apksigner = Join-Path $buildTools.FullName "apksigner.bat"

# apksigner.bat uses JAVA_HOME. Modern debug.keystore files use HmacPBESHA256,
# which old JDKs (e.g. 11.0.2) can't read. Prefer Android Studio's JBR (JDK 17+).
$jbr = "C:\Program Files\Android\Android Studio\jbr"
if (Test-Path "$jbr\bin\java.exe") {
    $env:JAVA_HOME = $jbr
    Write-Host "Using JBR for apksigner: $jbr"
}

$aligned = "$Apk.aligned.tmp"
Remove-Item $aligned -ErrorAction SilentlyContinue
& $zipalign -f -p 4 $work $aligned
if ($LASTEXITCODE -ne 0) { Write-Error "zipalign failed" }

& $apksigner sign --ks $Keystore --ks-key-alias $KeyAlias --ks-pass "pass:$StorePass" --key-pass "pass:$KeyPass" $aligned
if ($LASTEXITCODE -ne 0) { Write-Error "apksigner sign failed" }

Move-Item $aligned $Apk -Force
Remove-Item $work -Force
Remove-Item "$Apk.idsig" -ErrorAction SilentlyContinue | Out-Null

Write-Host ""
Write-Host "Scrubbed + re-signed: $Apk"
Write-Host "Smoke-test the app launches on a device (AOT snapshot was byte-patched)."
