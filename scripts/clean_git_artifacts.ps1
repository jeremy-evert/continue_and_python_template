<#
Remove tracked artifact files from git index (but keep them on disk).
Use if runs/ or reports/ contents were accidentally committed.

Usage:
  pwsh .\scripts\clean_git_artifacts.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "🧽 Removing tracked artifacts from git index..." -ForegroundColor Cyan

git rm -r --cached runs/* 2>$null
git rm -r --cached reports/* 2>$null

# restore keepers
if (-not (Test-Path "runs/.gitkeep")) { New-Item -ItemType File -Force -Path "runs/.gitkeep" | Out-Null }
if (-not (Test-Path "reports/.gitkeep")) { New-Item -ItemType File -Force -Path "reports/.gitkeep" | Out-Null }

git add runs/.gitkeep reports/.gitkeep

Write-Host "✅ Done. Now commit:" -ForegroundColor Green
Write-Host "   git commit -m `"Stop tracking artifact outputs in runs/ and reports/`"" -ForegroundColor Gray
