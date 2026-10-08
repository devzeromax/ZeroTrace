# Creates a release keystore + android/key.properties for Play Store builds.
# Safe to re-run: skips if the keystore already exists.
#
# Usage (from cleanshare/):
#   .\tool\create_release_keystore.ps1
#
# BACK UP android/keystore/zerotrace-release.jks and android/key.properties
# somewhere secure (password manager, encrypted drive). You need them for
# every future app update on Play Store.

param(
    [string]$Alias = "zerotrace",
    [int]$ValidityYears = 25
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$keystoreDir = Join-Path $root "android\keystore"
$keystoreFile = Join-Path $keystoreDir "zerotrace-release.jks"
$keyProps = Join-Path $root "android\key.properties"
$credsBackup = Join-Path $keystoreDir "BACKUP_THESE_CREDENTIALS.txt"

$jbrKeytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if (-not (Test-Path $jbrKeytool)) {
    $jbrKeytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
}
if (-not $jbrKeytool) { Write-Error "keytool not found. Install Android Studio or JDK." }

if (Test-Path $keystoreFile) {
    Write-Host "Release keystore already exists: $keystoreFile"
    if (-not (Test-Path $keyProps)) {
        Write-Error "key.properties missing but keystore exists. Restore key.properties from backup."
    }
    Write-Host "Nothing to do. Run .\tool\build_release_android.ps1 to build."
    exit 0
}

function New-RandomPassword([int]$Length = 32) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $bytes = New-Object byte[] $Length
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

$storePass = New-RandomPassword
# PKCS12 keystores use a single password for store + key.
$keyPass = $storePass

New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null

$dname = "CN=ZeroTrace, OU=Mobile, O=ZeroTrace, L=Unknown, ST=Unknown, C=US"
Write-Host "Creating release keystore..."
& $jbrKeytool -genkeypair `
    -v `
    -storetype PKCS12 `
    -keystore $keystoreFile `
    -alias $Alias `
    -keyalg RSA `
    -keysize 2048 `
    -validity ($ValidityYears * 365) `
    -storepass $storePass `
    -keypass $keyPass `
    -dname $dname

if ($LASTEXITCODE -ne 0) { Write-Error "keytool failed" }

# storeFile path is relative to android/app/ (see build.gradle.kts).
@"
storePassword=$storePass
keyPassword=$keyPass
keyAlias=$Alias
storeFile=../keystore/zerotrace-release.jks
"@ | Out-File -FilePath $keyProps -Encoding ascii

$backupText = @"
ZeroTrace release signing credentials
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Keystore: android/keystore/zerotrace-release.jks
Alias:    $Alias
Password: $storePass  (same for store + key; PKCS12 uses one password)

IMPORTANT:
- Back up the .jks file AND this password. Play Store requires the SAME key for all updates.
- Do NOT commit this file or key.properties to git.
- Delete this file after saving credentials to a password manager.
"@
[System.IO.File]::WriteAllText($credsBackup, $backupText.TrimEnd() + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Created:"
Write-Host "  $keystoreFile"
Write-Host "  $keyProps"
Write-Host "  $credsBackup  (read once, then store passwords securely and delete)"
Write-Host ""
Write-Host "Next: .\tool\build_release_android.ps1"
