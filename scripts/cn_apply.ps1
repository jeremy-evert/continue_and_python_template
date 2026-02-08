<#
scripts/cn_apply.ps1

CLI harness for Continue ("cn"):
Prompt -> unified diff -> git apply -> check -> optional autofix -> optional commit

Usage examples:

# Basic (no commit)
pwsh .\scripts\cn_apply.ps1 -Name fizzbuzz -Prompt @"
Return ONLY a unified diff (git apply format).
Create src/python_template/core/fizzbuzz.py with fizzbuzz(n: int) -> list[str] for 1..n (Fizz/Buzz/FizzBuzz).
Create tests/test_fizzbuzz.py covering n=15.
Keep ruff/format clean and pytest green.
"@

# With auto-fix loop (up to 2 repair passes) + commit
pwsh .\scripts\cn_apply.ps1 -Name fizzbuzz -PromptFile .\docs\prompts\fizzbuzz.txt -AutoFix -MaxFixes 2 -Commit -CommitMessage "continue: fizzbuzz smoke test (cli)"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $false)]
    [string] $Prompt,

    [Parameter(Mandatory = $false)]
    [string] $PromptFile,

    [Parameter(Mandatory = $false)]
    [string] $Config = "$HOME\.continue\config.yaml",

    [Parameter(Mandatory = $false)]
    [string] $OutDir = ".\runs",

    [switch] $AutoFix,

    [int] $MaxFixes = 1,

    [switch] $Commit,

    [string] $CommitMessage = "continue: apply patch"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "INFO: $msg" }
function Write-Ok($msg)   { Write-Host "OK:   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "WARN: $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "ERR:  $msg" -ForegroundColor Red }

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null).Trim()
    if (-not $root) { throw "Not inside a git repo (git rev-parse failed)." }
    return $root
}

function Read-Prompt {
    if ($PromptFile) {
        if (-not (Test-Path -LiteralPath $PromptFile)) { throw "PromptFile not found: $PromptFile" }
        return Get-Content -LiteralPath $PromptFile -Raw
    }
    if ($Prompt) { return $Prompt }
    throw "Provide -Prompt or -PromptFile."
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Extract-UnifiedDiff([string]$Raw) {
    # Remove markdown fences if present
    $lines = $Raw -split "`r?`n"
    $lines = $lines | Where-Object { $_ -notmatch '^\s*```' }
    $clean = ($lines -join "`n").Trim()

    # Find the first "diff --git" and keep everything from there
    $m = [regex]::Match($clean, "(?ms)^diff --git .+")
    if (-not $m.Success) {
        return $null
    }
    return $m.Value.Trim() + "`n"
}

function Run-Continue([string]$PromptText, [string]$RawOutPath) {
    if (-not (Test-Path -LiteralPath $Config)) { throw "Continue config not found: $Config" }

    Write-Info "Running cn (silent) using config: $Config"
    $raw = & cn --config $Config --silent -p $PromptText 2>&1 | Out-String

    Write-Utf8NoBom -Path $RawOutPath -Text $raw
    return $raw
}

function Apply-Patch([string]$PatchPath) {
    Write-Info "git apply --check $PatchPath"
    & git apply --check $PatchPath | Out-Null

    Write-Info "git apply --whitespace=fix $PatchPath"
    & git apply --whitespace=fix $PatchPath | Out-Null
}

function Run-CheckFast([string]$RepoRoot) {
    $check = Join-Path $RepoRoot "scripts\check.ps1"
    if (-not (Test-Path -LiteralPath $check)) { throw "check.ps1 not found at $check" }

    Write-Info "Running: pwsh $check -Fast"
    $output = & pwsh $check -Fast 2>&1 | Out-String
    return $output
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

$promptText = Read-Prompt

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$rawPath   = Join-Path $OutDir "$Name.$timestamp.raw.txt"
$patchPath = Join-Path $OutDir "$Name.$timestamp.patch"
$checkPath = Join-Path $OutDir "$Name.$timestamp.check.txt"

# Safety: recommend starting clean (but don't force it)
$porcelain = (& git status --porcelain).Trim()
if ($porcelain) {
    Write-Warn "Working tree not clean. That's OK, but patch application is safer on a clean tree."
}

# Main pass
$raw = Run-Continue -PromptText $promptText -RawOutPath $rawPath
$patch = Extract-UnifiedDiff -Raw $raw
if (-not $patch) {
    Write-Err "No unified diff found in cn output. Saved raw output to: $rawPath"
    throw "Model did not return a valid patch (missing 'diff --git')."
}

Write-Utf8NoBom -Path $patchPath -Text $patch
Write-Ok "Patch saved: $patchPath"

Apply-Patch -PatchPath $patchPath
Write-Ok "Patch applied."

$checkOut = Run-CheckFast -RepoRoot $repoRoot
Write-Utf8NoBom -Path $checkPath -Text $checkOut

if ($checkOut -match "✅ Healthy") {
    Write-Ok "Repo is green."
} elseif ($AutoFix) {
    Write-Warn "Repo not green. Entering auto-fix loop (max $MaxFixes)."
    for ($i = 1; $i -le $MaxFixes; $i++) {
        $fixPrompt = @"
Return ONLY a unified diff (git apply format).
The previous patch has been applied already.
Fix ONLY what is necessary to make `pwsh .\scripts\check.ps1 -Fast` pass (ruff + pytest).
Here is the failing output:

$checkOut
"@

        $fixRawPath   = Join-Path $OutDir "$Name.$timestamp.fix$i.raw.txt"
        $fixPatchPath = Join-Path $OutDir "$Name.$timestamp.fix$i.patch"
        $fixCheckPath = Join-Path $OutDir "$Name.$timestamp.fix$i.check.txt"

        $fixRaw = Run-Continue -PromptText $fixPrompt -RawOutPath $fixRawPath
        $fixPatch = Extract-UnifiedDiff -Raw $fixRaw
        if (-not $fixPatch) {
            Write-Err "Auto-fix $i produced no patch. Raw saved: $fixRawPath"
            break
        }

        Write-Utf8NoBom -Path $fixPatchPath -Text $fixPatch
        Apply-Patch -PatchPath $fixPatchPath

        $checkOut = Run-CheckFast -RepoRoot $repoRoot
        Write-Utf8NoBom -Path $fixCheckPath -Text $checkOut

        if ($checkOut -match "✅ Healthy") {
            Write-Ok "Repo is green after auto-fix $i."
            break
        }

        Write-Warn "Still failing after auto-fix $i."
    }
} else {
    Write-Warn "Repo not green. See: $checkPath"
}

# Optional commit
if ($Commit) {
    if (-not ($checkOut -match "✅ Healthy")) {
        throw "Refusing to commit because checks are not green. See: $checkPath"
    }
    & git add -A
    & git commit -m $CommitMessage
    Write-Ok "Committed: $CommitMessage"
}
