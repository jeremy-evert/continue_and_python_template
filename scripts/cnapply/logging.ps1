function Write-Info { param([string]$Msg) Write-Host "INFO: $Msg" }
function Write-Ok   { param([string]$Msg) Write-Host "OK:   $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "WARN: $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "ERR:  $Msg" -ForegroundColor Red }
