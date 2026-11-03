<#
.SYNOPSIS
  Runs the TokiGo backend behind an ngrok tunnel and points the Flutter app at
  the public HTTPS URL.

.DESCRIPTION
  Use this when the phone is NOT on the same network as this machine, so
  `adb reverse` and wireless debugging cannot be used. The device reaches the
  backend through ngrok instead of the LAN.

  The public URL is read from ngrok's local API (127.0.0.1:4040), so the app
  always gets the *current* URL even on a random free-tier domain — no need to
  copy it by hand.

.PARAMETER Domain
  Optional ngrok static domain, e.g. tokigo-dev.ngrok-free.app (no scheme).
  When omitted ngrok assigns a random URL each run.

.PARAMETER Port
  Local backend port. Default 3000 (matches backend/src/main.ts).

.PARAMETER Mode
  apk  - build a release APK to install on the phone (default).
  run  - `flutter run` on a connected device (same-network / wireless ADB).
  none - only start the backend + tunnel and print the public URL.

.PARAMETER Device
  Optional Flutter device id (see `flutter devices`). Only used with -Mode run.

.EXAMPLE
  ./tool/run-ngrok.ps1 -Domain tokigo-dev.ngrok-free.app
  ./tool/run-ngrok.ps1 -Mode apk
  ./tool/run-ngrok.ps1 -Mode none
#>
[CmdletBinding()]
param(
  [string]$Domain,
  [int]$Port = 3000,
  [ValidateSet('apk', 'run', 'none')]
  [string]$Mode = 'apk',
  [string]$Device
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot        # repo root (this script lives in tool/)
$backendDir = Join-Path $root 'backend'

# Accept "https://x.ngrok-free.app", "x.ngrok-free.app/" or a bare domain.
if ($Domain) { $Domain = ($Domain -replace '^https?://', '') -replace '/+$', '' }

function Test-LocalPort([int]$p) {
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect('127.0.0.1', $p, $null, $null)
    if ($iar.AsyncWaitHandle.WaitOne(300)) { $client.EndConnect($iar); return $true }
    return $false
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

# --- preflight --------------------------------------------------------------
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
  # winget only updates PATH for *new* shells; recover the install dir here so
  # the script also works from the terminal that installed ngrok.
  $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  $found = Get-ChildItem $pkgRoot -Recurse -Filter 'ngrok.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($found) { $env:PATH = "$($found.Directory.FullName);$env:PATH" }
}
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
  throw "ngrok not found. Install it (winget install --id ngrok.ngrok) and open a new shell."
}
$ngrokConfig = Join-Path $env:LOCALAPPDATA 'ngrok\ngrok.yml'
if (-not (Test-Path $ngrokConfig)) {
  throw "ngrok is not authenticated. Run:  ngrok config add-authtoken <TOKEN>   (free account: https://dashboard.ngrok.com/get-started/your-authtoken)"
}

# --- backend ----------------------------------------------------------------
if (Test-LocalPort $Port) {
  Write-Host "[backend] something already listens on $Port - reusing it." -ForegroundColor DarkGray
} else {
  Write-Host "[backend] starting 'npm run start:dev' in a new window..." -ForegroundColor Cyan
  Start-Process -FilePath 'powershell.exe' `
    -ArgumentList '-NoExit', '-Command', 'npm run start:dev' `
    -WorkingDirectory $backendDir | Out-Null

  Write-Host "[backend] waiting for port $Port..."
  $up = $false
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-LocalPort $Port) { $up = $true; break }
  }
  if (-not $up) { throw "backend did not open port $Port within 30s. Check the backend window for errors." }
  Write-Host "[backend] up." -ForegroundColor Green
}

# --- tunnel -----------------------------------------------------------------
# ngrok 3.3.x uses --domain; newer builds also accept --url (--domain still works).
$ngrokCmd = if ($Domain) { "ngrok http --domain=$Domain $Port" } else { "ngrok http $Port" }
Write-Host "[ngrok]   $ngrokCmd" -ForegroundColor Cyan
$ngrokJob = Start-Job -ScriptBlock { param($c) Invoke-Expression $c } -ArgumentList $ngrokCmd

try {
  $publicUrl = $null
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    try {
      $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels' -TimeoutSec 2
      $tunnel = $resp.tunnels | Where-Object { $_.public_url -like 'https://*' } | Select-Object -First 1
      if ($tunnel) { $publicUrl = $tunnel.public_url; break }
    } catch { }
    # surface an early ngrok failure instead of waiting the full 30s
    if ($ngrokJob.State -ne 'Running') {
      Receive-Job $ngrokJob | Write-Host
      throw "ngrok exited before a tunnel was established (see output above)."
    }
  }
  if (-not $publicUrl) {
    Receive-Job $ngrokJob | Write-Host
    throw "could not read the ngrok public URL from 127.0.0.1:4040 after 30s."
  }

  $define = "--dart-define=API_BASE_URL=$publicUrl"
  Write-Host ""
  Write-Host "  Public API URL : $publicUrl" -ForegroundColor Green
  Write-Host "  dart-define    : $define" -ForegroundColor Green
  Write-Host ""

  if ($Mode -eq 'none') {
    Write-Host "Tunnel is running. Press Ctrl+C to stop." -ForegroundColor Yellow
    Wait-Job $ngrokJob | Out-Null
    exit 0
  }

  Push-Location $root
  try {
    if ($Mode -eq 'apk') {
      Write-Host "[flutter] building release APK (install it on the phone)..." -ForegroundColor Cyan
      flutter build apk --release $define
      $apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
      Write-Host ""
      Write-Host "  APK: $apk" -ForegroundColor Green
      Write-Host "  Transfer it to the phone (e.g. cloud drive / the APK-serving tunnel) and install." -ForegroundColor Green
    } else {
      Write-Host "[flutter] flutter run..." -ForegroundColor Cyan
      if ($Device) { flutter run -d $Device $define } else { flutter run $define }
    }
  } finally {
    Pop-Location
  }
} finally {
  if ($ngrokJob) {
    Write-Host "[ngrok]   stopping tunnel..." -ForegroundColor DarkGray
    Stop-Job $ngrokJob -ErrorAction SilentlyContinue
    Remove-Job $ngrokJob -Force -ErrorAction SilentlyContinue
  }
}
