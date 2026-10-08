# Starts ZeroTrace for mobile browser testing via QR code.
# Usage (from cleanshare/):  .\tool\run_mobile_web.ps1
# Optional port:             .\tool\run_mobile_web.ps1 -Port 8080

param(
    [int]$Port = 7357
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

function Get-LanIPv4 {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        Sort-Object -Property InterfaceMetric

    if ($candidates) {
        return ($candidates | Select-Object -First 1).IPAddress
    }

    throw "No LAN IPv4 address found. Connect to Wi‑Fi or Ethernet first."
}

Push-Location $root

try {
    $ip = Get-LanIPv4
    $url = "http://${ip}:$Port"
    $qrHtml = Join-Path $PSScriptRoot "mobile_qr.html"
    $qrPath = $qrHtml.Replace('\', '/')
    $qrUri = "file:///$qrPath`?url=$([uri]::EscapeDataString($url))"

    Write-Host ""
    Write-Host "ZeroTrace mobile web dev" -ForegroundColor Green
    Write-Host "========================"
    Write-Host "LAN URL:  $url"
    Write-Host ""
    Write-Host "1. Opening QR code page in your browser..."
    Write-Host "2. Scan the QR code with your phone camera."
    Write-Host "3. Wait for Flutter to finish compiling below."
    Write-Host ""

    Start-Process $qrUri

    flutter run -d web-server `
        --web-hostname 0.0.0.0 `
        --web-port $Port `
        --web-launch-url $url
}
finally {
    Pop-Location
}
