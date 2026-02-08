<#
Clean template repo working tree (safe):
- Deletes local build/caches/venv/temp files
- Deletes contents of runs/ and reports/ but keeps .gitkeep
- Does NOT delete .git directory or your source/docs/tests/scripts

Usage:
  pwsh .\scripts\clean.ps1
  pwsh .\scripts\clean.ps1 -WhatIf   # preview only
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = "Stop"

function Remove-PathSafe {
  param([string]$Path)

  if (Test-Path $Path) {
    if ($PSCmdlet.ShouldProcess($Path, "Remove")) {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Write-Host "🧹 Cleaning repo junk (safe)..." -ForegroundColor Cyan

# Common dirs
$dirsToRemove = @(
  ".venv",
  "venv",
  "__pycache__",
  ".pytest_cache",
  ".ruff_cache",
  ".mypy_cache",
  "build",
  "dist",
  ".tox",
  ".nox",
  ".cache",
  "htmlcov",
  "*.egg-info"
)

foreach ($d in $dirsToRemove) {
  Get-ChildItem -Force -Recurse -Directory -Filter $d -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-PathSafe $_.FullName }
}

# Files by pattern
$filePatterns = @(
  "*.pyc",
  "*.pyo",
  "*.log",
  "*.tmp",
  "*.bak",
  "*.old",
  "*.swp",
  "*.swo",
  ".coverage",
  "coverage.xml",
  "*.zip",
  "*.7z"
)

foreach ($pat in $filePatterns) {
  Get-ChildItem -Force -Recurse -File -Filter $pat -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-PathSafe $_.FullName }
}

# runs/ and reports/ contents, keep .gitRecurse safe
$artifactRoots = @("runs", "reports")
foreach ($root in $artifactRoots) {
  if (Test-Path $root) {
    Get-ChildItem -Force -Recurse $root -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne ".gitkeep" } |
      ForEach-Object { Remove-PathSafe $_.FullName }

    # ensure .gitkeep exists
    $keep = Join-Path $root ".gitkeep"
    if (-not (Test-Path $keep)) {
      if ($PSCmdlet.ShouldProcess($keep, "Create")) {
        New-Item -ItemType File -Force -Path $keep | Out-Null
      }
    }
  }
}

Write-Host "✅ Clean complete." -ForegroundColor Green
