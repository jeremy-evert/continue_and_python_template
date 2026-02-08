<#
init_template_folders.ps1
Creates the Python-first, polyglot-ready template folder structure.
Safe to run multiple times.

Usage:
  pwsh .\scripts\init_template_folders.ps1 -PackageName project_name
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$PackageName = "project_name"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "📁 Created: $Path"
    } else {
        Write-Host "↩️  Exists:  $Path"
    }
}

function Ensure-GitKeep([string]$DirPath) {
    $gitkeep = Join-Path $DirPath ".gitkeep"
    if (-not (Test-Path $gitkeep)) {
        New-Item -ItemType File -Path $gitkeep -Force | Out-Null
        Write-Host "  ➕ Added .gitkeep in $DirPath"
    }
}

# Core folder map
$dirs = @(
    "src",
    "src\$PackageName",
    "src\$PackageName\core",
    "src\$PackageName\adapters",
    "src\$PackageName\app",
    "src\$PackageName\cli",
    "tests",
    "tools",
    "docs",
    "reports",
    "runs",
    "scripts",
    "web"
)

foreach ($d in $dirs) {
    Ensure-Dir (Join-Path $repoRoot $d)
}

# Add __init__.py so package imports work immediately
$initPath = Join-Path $repoRoot "src\$PackageName\__init__.py"
if (-not (Test-Path $initPath)) {
    New-Item -ItemType File -Path $initPath -Force | Out-Null
    Write-Host "🐍 Added: $initPath"
} else {
    Write-Host "↩️  Exists:  $initPath"
}

# Add .gitkeep for artifact folders so they exist in git
Ensure-GitKeep (Join-Path $repoRoot "reports")
Ensure-GitKeep (Join-Path $repoRoot "runs")
Ensure-GitKeep (Join-Path $repoRoot "docs")
Ensure-GitKeep (Join-Path $repoRoot "tools")
Ensure-GitKeep (Join-Path $repoRoot "tests")
Ensure-GitKeep (Join-Path $repoRoot "web")

Write-Host "✅ Template folder structure initialized."
Write-Host "Next: add pyproject.toml + pre-commit + ruff/pytest config."
