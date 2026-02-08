<#
.SYNOPSIS
  Run pre-commit using the repo's venv Python (venv-first).

.DESCRIPTION
  Avoids "pre-commit not recognized" issues by invoking:
    .\.venv\Scripts\python.exe -m pre_commit

  Default behavior: run on all files.

.PARAMETER AllFiles
  Run on all files (default: true).

.PARAMETER Args
  Extra arguments passed through to pre-commit (optional).
#>

[CmdletBinding()]
param(
  [switch]$AllFiles = $true,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$py = Join-Path $repoRoot ".venv\Scripts\python.exe"

if (-not (Test-Path $py)) {
  Write-Error "Missing venv python: $py`nRun: pwsh .\scripts\check.ps1 (or create .venv) first."
}

$cmd = @($py, "-m", "pre_commit", "run")

if ($AllFiles) { $cmd += "--all-files" }
if ($Args) { $cmd += $Args }

Write-Host ("Running: " + ($cmd -join " "))
& $cmd[0] $cmd[1..($cmd.Count-1)]
exit $LASTEXITCODE
