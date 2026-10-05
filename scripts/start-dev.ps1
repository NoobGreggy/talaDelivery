# Starts every TalaDelivery dev microservice in its own window-free background
# process with logs written to .logs/<service>.log
#
#   powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1 -NoRealtime
#
# Each service gets its own POSTGRES_DB_NAME so no global override in .env can
# point every service at the same database.

[CmdletBinding()]
param(
  # The realtime gateway (port 3008) backs the Socket.IO connection both
  # Angular apps use for live notifications and rider positions. It is on by
  # default because leaving it off only shows up as a silently dead
  # notification bell in the UI. Pass -NoRealtime to skip it.
  [switch]$NoRealtime
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$logDir = Join-Path $root '.logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$services = @(
  # The gateway owns no database; it is the single entry point the Angular
  # apps proxy to, so it must start first and is not part of $services.
  @{ name = 'api-gateway';          port = 3000; db = '' },
  @{ name = 'identity-service';     port = 3001; db = 'taladelivery_identity' },
  @{ name = 'merchant-service';     port = 3002; db = 'taladelivery_merchant' },
  @{ name = 'catalog-service';      port = 3003; db = 'taladelivery_catalog' },
  @{ name = 'order-service';        port = 3004; db = 'taladelivery_order' },
  @{ name = 'dispatch-service';     port = 3005; db = 'taladelivery_dispatch' },
  @{ name = 'payment-service';      port = 3006; db = 'taladelivery_payment' },
  @{ name = 'notification-service'; port = 3007; db = 'taladelivery_notification' }
)

if (-not $NoRealtime) {
  $services += @{ name = 'realtime-service'; port = 3008; db = 'taladelivery_realtime' }
}

& (Join-Path $PSScriptRoot 'stop-dev.ps1')

foreach ($svc in $services) {
  $log = Join-Path $logDir "$($svc.name).log"
  $err = Join-Path $logDir "$($svc.name).err.log"
  if (Test-Path $log) { Remove-Item $log -Force }
  if (Test-Path $err) { Remove-Item $err -Force }

  $entry = "apps/$($svc.name)/src/main.ts"
  $env:NODE_ENV = 'development'
  $env:POSTGRES_DB_NAME = $svc.db
  $env:SERVICE_NAME = $svc.name

  $dbLabel = if ($svc.db -eq '') { 'no db' } else { "db=$($svc.db)" }
  Write-Host "Starting $($svc.name) on port $($svc.port) ($dbLabel)"
  $proc = Start-Process -FilePath 'node' `
    -ArgumentList @('-r', 'ts-node/register', '-r', 'tsconfig-paths/register', $entry) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $log `
    -RedirectStandardError $err `
    -NoNewWindow -PassThru
  $proc.Id | Out-File -FilePath (Join-Path $logDir "$($svc.name).pid") -Encoding ascii

  # Each service is a separate ts-node process (~150-250MB). Starting all of
  # them at once can exhaust memory and kill the last one with
  # "Zone Allocation failed - process out of memory", so stagger them.
  Start-Sleep -Seconds 4
}

Write-Host ''
Write-Host '--- Health probe (waiting for each service, up to 60s) ---'
foreach ($svc in $services) {
  $up = $false
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    try {
      $r = Invoke-RestMethod -Uri "http://localhost:$($svc.port)/health/live" -TimeoutSec 3
      Write-Host ("{0,-22} UP   {1}" -f $svc.name, ($r | ConvertTo-Json -Compress))
      $up = $true
      break
    } catch { }
  }
  if (-not $up) {
    Write-Host ("{0,-22} DOWN  see {1}" -f $svc.name, (Join-Path $logDir "$($svc.name).err.log"))
  }
}
Write-Host ''
Write-Host "Logs: $logDir"
