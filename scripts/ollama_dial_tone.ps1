# scripts/ollama_dial_tone.ps1
# Purpose: One-command verification that Ollama is reachable and can answer a tiny prompt.
# Exit codes:
#   0 = OK
#   1 = Ollama not reachable
#   2 = No models installed (or tags endpoint empty)
#   3 = Generate call failed
#   4 = Generate succeeded but response not as expected (soft fail)
#   5 = Unexpected error

[CmdletBinding()]
param(
    [string]$BaseUrl = "http://localhost:11434",
    [string]$Model = "",                 # optional override, otherwise first installed model is used
    [string]$Prompt = "Say OK.",
    [int]$TimeoutSec = 8,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) {
    if (-not $Quiet) { Write-Host $msg }
}

function Write-WarnMsg([string]$msg) {
    if (-not $Quiet) { Write-Host $msg }
}

try {
    $BaseUrl = $BaseUrl.TrimEnd("/")

    Write-Info "== Ollama Dial-Tone =="
    Write-Info "Base URL : $BaseUrl"
    Write-Info ""

    # 1) Reachability + list models
    $tagsUri = "$BaseUrl/api/tags"
    Write-Info "[1/3] Checking server + installed models: $tagsUri"

    $tags = Invoke-RestMethod -Uri $tagsUri -Method Get -TimeoutSec $TimeoutSec

    if (-not $tags -or -not $tags.models -or $tags.models.Count -eq 0) {
        Write-WarnMsg "No models reported by /api/tags."
        Write-WarnMsg "Fix: run `ollama list` or `ollama pull llama3.1:8b` (example) on this machine."
        exit 2
    }

    $modelNames = $tags.models | ForEach-Object { $_.name }
    Write-Info ("Models   : " + ($modelNames -join ", "))

    if ([string]::IsNullOrWhiteSpace($Model)) {
        $Model = $modelNames[0]
        Write-Info "Using    : $Model (first installed model)"
    } else {
        if ($modelNames -notcontains $Model) {
            Write-WarnMsg "Requested model '$Model' not found in installed models."
            Write-WarnMsg ("Installed: " + ($modelNames -join ", "))
            exit 2
        }
        Write-Info "Using    : $Model (requested)"
    }

    Write-Info ""

    # 2) Generate a tiny response and time it
    $genUri = "$BaseUrl/api/generate"
    Write-Info "[2/3] Running tiny prompt (timed): $Prompt"
    $payload = @{
        model  = $Model
        prompt = $Prompt
        stream = $false
    } | ConvertTo-Json

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
    if (-not $Quiet) {
        Write-Host "❌ Unexpected error:"
        Write-Host $_.Exception.Message
    }
    exit 5
}
