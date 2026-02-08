<#
Hard reset for a template repo clone:
- Deletes .venv and caches
- Deletes runs/ and reports/ contents (keeps .gitkeep)
- Leaves git history intact
- Leaves src/tests/docs/scripts intact

Usage:
  pwsh .\scripts\template_hard_reset.ps1
  pwsh .\scripts\template_hard_reset.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = "Stop"

Write-Host "🔥 HARD RESET (local) starting..." -ForegroundColor Yellow

# call the safe cleaner first
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "clean.ps1") @($PSBoundParameters.Keys | ForEach-Object { "-$_" })

# additionally nuke venv explicitly
if (Test-Path ".venv") {
  if ($PSCmdlet.ShouldProcess(".venv", "Remove")) {
    Remove-Item ".venv" -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "✅ Hard reset complete. Rebuild with:" -ForegroundColor Green
Write-Host "   python -m venv .venv" -ForegroundColor Gray
Write-Host "   .\.venv\Scripts\activate" -ForegroundColor Gray
Write-Host "   pip install -e `".[dev]`"" -ForegroundColor Gray
Write-Host "   pwsh .\scripts\setup_precommit.ps1" -ForegroundColor Gray
