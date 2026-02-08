# scripts/check.ps1
# One-command smoke ritual: "Is this repo healthy?"
#
# Usage:
#   pwsh .\scripts\check.ps1
#   pwsh .\scripts\check.ps1 -Fast
#   pwsh .\scripts\check.ps1 -NoFormat
#   pwsh .\scripts\check.ps1 -NoTests
#   pwsh .\scripts\check.ps1 -WithOllama
#   pwsh .\scripts\check.ps1 -WithOllama -Model "llama3.1:8b"
#
# Exit codes:
#   0 = healthy
#   1 = failed checks/tests
#   2 = environment/setup failure (python/venv/deps) OR optional Ollama requested but unavailable

[CmdletBinding()]
param(
    [switch]$Fast,
    [switch]$NoFormat,
    [switch]$NoTests,

    [switch]$WithOllama,
    [string]$Model = "",
    [string]$OllamaBaseUrl = "http://localhost:11434",
    [int]$OllamaTimeoutSec = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step([string]$msg) { Write-Host "🧪 $msg" }
function Write-Note([string]$msg) { Write-Host "ℹ️  $msg" }
function Write-WarnMsg([string]$msg) { Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Ok([string]$msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Fail([string]$msg, [int]$code = 1) {
    Write-Host "❌ $msg" -ForegroundColor Red
    exit $code
}

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][scriptblock]$Block,
        [int]$FailCode = 1
    )
    Write-Step $Title
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Block
    } catch {
        $sw.Stop()
        Fail "$Title failed after $([int]$sw.Elapsed.TotalSeconds)s. Error: $($_.Exception.Message)" $FailCode
    }
    $sw.Stop()
}

# Always run from repo root (script lives in scripts/)
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot
Write-Step "Repo root: $RepoRoot"

# ---- Find Python ----
$PythonCmd = $null
foreach ($candidate in @("python", "py")) {
    try {
        & $candidate --version 2>$null | Out-Host
        if ($LASTEXITCODE -eq 0) { $PythonCmd = $candidate; break }
    } catch {}
}
if (-not $PythonCmd) {
    Fail "Python not found on PATH. Install Python or ensure 'python' works in PowerShell." 2
}
Write-Step "Python found: $PythonCmd"
& $PythonCmd --version | Out-Host

# ---- Ensure venv exists ----
$VenvPath = Join-Path $RepoRoot ".venv"
$VenvPython = Join-Path $VenvPath "Scripts\python.exe"
$VenvScripts = Join-Path $VenvPath "Scripts"

if (-not (Test-Path $VenvPython)) {
    Invoke-Step -Title "Creating virtual environment: .venv" -FailCode 2 -Block {
        & $PythonCmd -m venv .venv | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "venv creation returned exit code $LASTEXITCODE" }
    }
}

# Make sure venv executables are found for this process (ruff/pytest entrypoints, etc.)
if (Test-Path $VenvScripts) {
    $env:PATH = "$VenvScripts;$env:PATH"
} else {
    Fail "Virtual environment scripts folder missing at: $VenvScripts" 2
}

# ---- Helper: check if dev deps exist in venv ----
function Test-DevDepsPresent {
    # Use the venv python to avoid relying on PATH/activation.
    try {
        & $VenvPython -m ruff --version 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }

        & $VenvPython -m pytest --version 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }

        return $true
    } catch {
        return $false
    }
}

# ---- Install/refresh dev deps ----
$needInstall = -not (Test-DevDepsPresent)

if ($Fast) {
    if ($needInstall) {
        Write-Note "Fast mode: deps missing in fresh venv; installing dev deps (editable) anyway"
        Invoke-Step -Title 'pip install -e ".[dev]"' -FailCode 2 -Block {
            & $VenvPython -m pip install -e ".[dev]" | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "pip install failed with exit code $LASTEXITCODE" }
        }
    } else {
        Write-Note "Fast mode: deps already present; skipping pip upgrade + pip install"
    }
} else {
    Invoke-Step -Title "Upgrading pip" -FailCode 2 -Block {
        & $VenvPython -m pip install -U pip | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed with exit code $LASTEXITCODE" }
    }

    Invoke-Step -Title 'Installing dev deps (editable): pip install -e ".[dev]"' -FailCode 2 -Block {
        & $VenvPython -m pip install -e ".[dev]" | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "pip install failed with exit code $LASTEXITCODE" }
    }
}

# ---- Versions (always helpful, especially in CI) ----
Write-Note "Versions:"
& $VenvPython --version | Out-Host
& $VenvPython -m ruff --version | Out-Host
& $VenvPython -m pytest --version | Out-Host

# ---- Run checks ----
if (-not $NoFormat) {
    Invoke-Step -Title "ruff format ." -FailCode 1 -Block {
        & $VenvPython -m ruff format . | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "ruff format returned exit code $LASTEXITCODE" }
    }
} else {
    Write-Note "NoFormat: skipping ruff format"
}

Invoke-Step -Title "ruff check ." -FailCode 1 -Block {
    & $VenvPython -m ruff check . | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "ruff check returned exit code $LASTEXITCODE" }
}

if (-not $NoTests) {
    Invoke-Step -Title "pytest -q" -FailCode 1 -Block {
        & $VenvPython -m pytest -q | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "pytest returned exit code $LASTEXITCODE" }
    }
} else {
    Write-Note "NoTests: skipping pytest"
}

# ---- Optional: Ollama dial-tone ----
if ($WithOllama) {
    $DialToneScript = Join-Path $RepoRoot "scripts\ollama_dial_tone.ps1"
    if (-not (Test-Path $DialToneScript)) {
        Fail "Ollama check requested, but missing $DialToneScript" 2
    }

    Write-Step "Ollama dial-tone (optional)"
    $args = @(
        "-NoProfile",
        "-File", $DialToneScript,
        "-BaseUrl", $OllamaBaseUrl,
        "-TimeoutSec", $OllamaTimeoutSec,
        "-Quiet"
    )
    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $args += @("-Model", $Model)
    }

    & pwsh @args
    $ollamaCode = $LASTEXITCODE

    if ($ollamaCode -eq 0) {
        Write-Ok "Ollama dial-tone OK"
    } elseif ($ollamaCode -eq 4) {
        Write-WarnMsg "Ollama dial-tone ran (soft). Response didn't contain 'OK'."
    } else {
        Fail "Ollama dial-tone failed (exit code $ollamaCode). Try: pwsh .\scripts\ollama_dial_tone.ps1" 2
    }
} else {
    Write-Note "Ollama check not requested (use -WithOllama to enable)"
}

Write-Ok "Healthy. Checks and tests passed."
exit 0
