param(
  [switch]$Fast,
  [switch]$Verbose
)

$ErrorActionPreference = "Stop"

function Say([string]$msg) {
  Write-Host $msg
}

function Run([string]$cmd) {
  if ($Verbose) {
    Say ">> $cmd"
    Invoke-Expression $cmd
    return
  }

  # Quiet mode: capture noisy output unless the command fails
  $out = New-Object System.Collections.Generic.List[string]
  try {
    Invoke-Expression $cmd 2>&1 | ForEach-Object { $out.Add($_.ToString()) } | Out-Null
  } catch {
    Say "❌ Command failed: $cmd"
    Say ""
    Say "Last output:"
    $out | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
    throw
  }
}

Say "🩺 Repo Doctor v1"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Say "🧪 Repo root: $repoRoot"

# Activate venv if present
$venvActivate = Join-Path $repoRoot ".venv\Scripts\Activate.ps1"
if (Test-Path $venvActivate) {
  Say "🧪 Activating virtual environment: .venv"
  . $venvActivate
} else {
  Say "❌ Missing .venv. Run:"
  Say "   pwsh .\scripts\setup_precommit.ps1"
  exit 1
}

# Ensure pip is sane
if (-not $Fast) {
  Say "🧪 Ensuring dev deps (editable)"
  Run "python -m pip install -U pip"
  Run "python -m pip install -e `".`[dev`]`""
} else {
  Say "🧪 Fast mode: skipping pip install"
}

Say "🧪 Running Repo Doctor..."
Run "python -m tools.repo_doctor"

# Respect Repo Doctor exit codes
$code = $LASTEXITCODE
if ($code -eq 0) {
  Say "✅ Repo Doctor OK (no boundary violations)."
  exit 0
}
elseif ($code -eq 2) {
  Say "⚠️ Repo Doctor found boundary violations."
  exit 2
}
else {
  Say "❌ Repo Doctor failed."
  exit 1
}
