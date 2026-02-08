<#
setup_precommit.ps1
Bootstraps the repo's dev tooling and installs pre-commit hooks.

Usage:
  pwsh .\scripts\setup_precommit.ps1
#>

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$venvDir = Join-Path $repoRoot ".venv"
$activate = Join-Path $venvDir "Scripts\Activate.ps1"

function Ensure-Venv {
    if (-not (Test-Path $activate)) {
        Write-Host "🐍 Creating virtual environment at .venv..."
        python -m venv .venv
    } else {
        Write-Host "↩️  Virtual environment exists: .venv"
    }
}

function Activate-Venv {
    if (-not (Test-Path $activate)) {
        throw "Virtual env activation script not found: $activate"
    }
    Write-Host "⚡ Activating virtual environment..."
    . $activate
}

function Install-DevDeps {
    Write-Host "📦 Upgrading pip..."
    python -m pip install -U pip

    Write-Host "📦 Installing dev dependencies (editable)..."
    pip install -e ".[dev]"
}

function Install-PreCommit {
    Write-Host "🧷 Installing pre-commit hooks..."
    pre-commit install

    Write-Host "🧪 Running pre-commit on all files (first run may take a minute)..."
    pre-commit run --all-files
}

Ensure-Venv
Activate-Venv
Install-DevDeps
Install-PreCommit

Write-Host "✅ pre-commit is installed and ready."
Write-Host "Next time, just run: pre-commit run --all-files"
