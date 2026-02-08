param(
  [string]$ConfigPath = (Join-Path $HOME ".continue\config.yaml"),
  [switch]$Strict
)

$ErrorActionPreference = "Stop"

function Fail($msg, $code = 1) {
  Write-Host "FAIL: $msg"
  exit $code
}

function Ok($msg) {
  Write-Host "OK:   $msg"
}

# 1) Config exists
if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Fail "Continue config not found at: $ConfigPath" 10
}
Ok "Found Continue config: $ConfigPath"

# 2) Basic sanity checks (cheap YAML-ish checks without needing a YAML parser)
$raw = Get-Content -LiteralPath $ConfigPath -Raw

if ($raw -notmatch "(?m)^\s*schema:\s*v1\s*$") { Fail "Missing or wrong 'schema: v1' in config.yaml" 11 }
if ($raw -notmatch "(?m)^\s*models:\s*$")      { Fail "Missing 'models:' block in config.yaml" 12 }

# Extract model IDs referenced in config (lines like: model: llama3.2:3b-cpu)
$configModels = @()
$raw -split "`n" | ForEach-Object {
  if ($_ -match "^\s*model:\s*([^\s#]+)\s*$") {
    $configModels += $Matches[1].Trim()
  }
}
$configModels = $configModels | Sort-Object -Unique

if ($configModels.Count -eq 0) { Fail "No 'model:' entries found in config.yaml" 13 }
Ok ("Config references {0} Ollama model(s): {1}" -f $configModels.Count, ($configModels -join ", "))

# 3) Roles presence checks (optional but useful)
$hasAutocomplete = $raw -match "(?m)roles:\s*\[[^\]]*autocomplete[^\]]*\]"
$hasChat         = $raw -match "(?m)roles:\s*\[[^\]]*chat[^\]]*\]"
$hasEmbed        = $raw -match "(?m)roles:\s*\[[^\]]*embed[^\]]*\]"

if (-not $hasAutocomplete) { Write-Host "WARN: No model with role 'autocomplete' found." }
if (-not $hasChat)         { Write-Host "WARN: No model with role 'chat' found." }
if (-not $hasEmbed)        { Write-Host "WARN: No model with role 'embed' found." }
Ok "Role scan complete (warns above are informational unless you're expecting those roles)."

# 4) Ollama CLI + server/model availability
$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $ollamaCmd) { Fail "ollama CLI not found on PATH." 20 }
Ok "Found ollama: $($ollamaCmd.Source)"

# Try ollama list; if server isn't running, this may error
$ollamaList = ""
try {
  $ollamaList = & ollama list 2>$null
} catch {
  # fallback: try HTTP tags endpoint
  try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -Method Get -TimeoutSec 2
    $names = @($tags.models.name)
    if (-not $names -or $names.Count -eq 0) { Fail "Ollama reachable, but no models returned from /api/tags." 22 }
    $installed = $names | Sort-Object -Unique
    Ok ("Ollama API reachable. Models found: {0}" -f $installed.Count)
  } catch {
    Fail "Could not run 'ollama list' AND could not reach Ollama at http://127.0.0.1:11434 (is Ollama running?)." 21
  }
}

if ($ollamaList) {
  # Parse NAME column from `ollama list`
  $installed = @()
  ($ollamaList -split "`n") | Select-Object -Skip 1 | ForEach-Object {
    $line = $_.Trim()
    if ($line) {
      $installed += ($line -split "\s+")[0]
    }
  }
  $installed = $installed | Sort-Object -Unique
  Ok ("Ollama list returned {0} installed model(s)." -f $installed.Count)
}

# 5) Compare config references vs installed models
$missing = $configModels | Where-Object { $_ -notin $installed }

if ($missing.Count -gt 0) {
  Write-Host ""
  Write-Host "Missing model(s) referenced by Continue config:"
  $missing | ForEach-Object { Write-Host "  - $_" }
  Write-Host ""
  Write-Host "Fix:"
  $missing | ForEach-Object { Write-Host "  ollama pull $_" }

  if ($Strict) { Fail "Missing models. Run the pulls above." 30 }
  else { Write-Host "WARN: Missing models (run pulls above). Continuing (non-strict mode)." }
} else {
  Ok "All models referenced in Continue config are installed in Ollama."
}

Write-Host ""
Ok "Continue pulse check complete."
exit 0
