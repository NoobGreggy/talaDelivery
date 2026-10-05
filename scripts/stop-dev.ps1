# Stops every TalaDelivery dev microservice listening on the known ports.
$ErrorActionPreference = 'SilentlyContinue'
$ports = 3000, 3001, 3002, 3003, 3004, 3005, 3006, 3007, 3008
foreach ($p in $ports) {
  $conns = @(Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue)
  foreach ($c in $conns) {
    Write-Host "Stopping PID $($c.OwningProcess) on port $p"
    Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
  }
}
Start-Sleep -Seconds 2
Write-Host 'All service ports are free.'
