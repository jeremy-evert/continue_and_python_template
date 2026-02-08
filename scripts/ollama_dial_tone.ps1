# scripts/ollama_dial_tone.ps1
# Purpose: One-command verification that Ollama is reachable and can answer a tiny prompt.
#
# Exit codes:
#   0 = OK
#   1 = Ollama not reachable / tags endpoint failed
#   2 = No models installed OR requested model not installed
#   3 = Generate call failed
#   4 = Generate succeeded but response didn't contain "OK" (soft fail)
#   5 = Unexpected error (should be rare)

[CmdletBinding()]
param(
    [string]$BaseUrl = "http://localhost:11434",
    [string]$Model = "",                 # optional override, otherwise a preferred installed model is used
    [string]$Prompt = "Say OK.",
    [int]$TimeoutSec = 8,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Info([string]$msg) {
    if (-not $Quiet) { Write-Host $msg }
}
function Write-WarnMsg([string]$msg) {
    if (-not $Quiet) { Write-Host $msg }
}

# Track stage so we can return sane exit codes even when -Quiet suppresses details.
$stage = "init"

try {
    $BaseUrl = $BaseUrl.TrimEnd("/")

    Write-Info "== Ollama Dial-Tone =="
    Write-Info "Base URL : $BaseUrl"
    Write-Info ""

    # 1) Reachability + list models
    $stage = "tags"
    $tagsUri = "$BaseUrl/api/tags"
    Write-Info "[1/3] Checking server + installed models: $tagsUri"

    $tags = Invoke-RestMethod -Uri $tagsUri -Method Get -TimeoutSec $TimeoutSec

    if (-not $tags -or -not $tags.models -or $tags.models.Count -eq 0) {
        Write-WarnMsg "No models reported by /api/tags."
        Write-WarnMsg "Fix: run `ollama list` or `ollama pull llama3.2:3b` (example) on this machine."
        exit 2
    }

    $modelNames = @($tags.models | ForEach-Object { $_.name })
    Write-Info ("Models   : " + ($modelNames -join ", "))

    # Choose model:
    # - If user requests a model, require it
    # - Else, pick something fast/small if present; fallback to first installed
    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        if ($modelNames -notcontains $Model) {
            Write-WarnMsg "Requested model '$Model' not found in installed models."
            Write-WarnMsg ("Installed: " + ($modelNames -join ", "))
            exit 2
        }
        Write-Info "Using    : $Model (requested)"
    } else {
        $preferredOrder = @(
            "llama3.2:1b",
            "llama3.2:3b",
            "phi3:mini",
            "qwen2.5-coder:1.5b-base",
            "llama3.2:1b-cpu",
            "llama3.2:3b-cpu",
            "phi3:mini-cpu",
            "qwen2.5:7b-cpu",
            "llama3.1:8b-cpu",
            "mistral:7b-cpu"
        )

        $picked = $null
        foreach ($p in $preferredOrder) {
            if ($modelNames -contains $p) { $picked = $p; break }
        }
        if (-not $picked) { $picked = $modelNames[0] }

        $Model = $picked
        Write-Info "Using    : $Model (auto-picked)"
    }

    Write-Info ""

    # 2) Generate a tiny response and time it
    $stage = "generate"
    $genUri = "$BaseUrl/api/generate"
    Write-Info "[2/3] Running tiny prompt (timed): $Prompt"

    $payload = @{
        model  = $Model
        prompt = $Prompt
        stream = $false
    } | ConvertTo-Json

    $gen = $null
    $elapsed = Measure-Command {
        $gen = Invoke-RestMethod -Uri $genUri -Method Post -TimeoutSec $TimeoutSec `
            -ContentType "application/json" -Body $payload
    }

    if (-not $gen -or -not $gen.response) {
        Write-WarnMsg "Generate call returned no response."
        exit 3
    }

    $text = ($gen.response.ToString()).Trim()
    $ms = [Math]::Round($elapsed.TotalMilliseconds)

    Write-Info "Response : $text"
    Write-Info "Latency  : ${ms}ms"
    Write-Info ""

    # 3) Simple sanity check (soft)
    $stage = "sanity"
    Write-Info "[3/3] Sanity check"

    if ($text -match "\bOK\b") {
        Write-Info "✅ Dial-tone OK"
        exit 0
    } else {
        Write-WarnMsg "⚠️ Dial-tone ran, but response didn't contain 'OK'."
        Write-WarnMsg "This can be normal depending on model/prompt. Treating as soft fail."
        exit 4
    }
}
catch {
    $msg = $_.Exception.Message

    if (-not $Quiet) {
        Write-Host "❌ Error during stage: $stage"
        Write-Host $msg
    }

    # Stage-aware exit codes (reduces mysterious 5s)
    switch ($stage) {
        "tags"     { exit 1 }
        "generate" { exit 3 }
        default    { exit 5 }
    }
}
