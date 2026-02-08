<#
setup_gitignore.ps1
Appends a "Python Template" ignore block to .gitignore (idempotent).

Usage:
  pwsh .\scripts\setup_gitignore.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$gitignorePath = Join-Path $repoRoot ".gitignore"

if (-not (Test-Path $gitignorePath)) {
    New-Item -ItemType File -Path $gitignorePath -Force | Out-Null
}

$beginMarker = "# --- python_template: BEGIN ---"
$endMarker   = "# --- python_template: END ---"

$block = @"
$beginMarker

# Python virtual environments
.venv/
venv/
ENV/
env/

# Python cache / build artifacts
__pycache__/
*.py[cod]
*$py.class
.pytest_cache/
.ruff_cache/
.mypy_cache/
.pytype/
.coverage
coverage.xml
htmlcov/
dist/
build/
*.egg-info/

# OS / editor junk
.DS_Store
Thumbs.db
*.swp
*.swo
.vscode/
.idea/

# Project artifacts (keep folder via .gitkeep, ignore contents)
reports/*
runs/*
!reports/.gitkeep
!runs/.gitkeep

$endMarker
"@

$content = Get-Content -Path $gitignorePath -Raw

if ($content -match [regex]::Escape($beginMarker)) {
    Write-Host "✅ .gitignore already contains template block. No changes made."
    exit 0
}

Add-Content -Path $gitignorePath -Value "`r`n$block"
Write-Host "✅ Appended template ignore block to .gitignore."
