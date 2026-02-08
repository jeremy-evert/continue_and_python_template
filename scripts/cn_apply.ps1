<#
scripts/cn_apply.ps1

CLI harness for Continue ("cn"):

Prompt -> cn -> extract/validate unified diff -> git apply --check -> git apply
-> run scripts/check.ps1 -> optional autofix loop -> optional commit

Design goals:
- Fail hard on native command errors (git/cn/pwsh)
- Treat check.ps1 success by exit code, not text
- Never "OK" something that didn't actually happen
- Save raw model outputs + patch attempts for postmortem

Usage examples:

# Basic (apply + check, no commit)
pwsh .\scripts\cn_apply.ps1 -Name fizzbuzz -PromptFile .\docs\prompts\fizzbuzz.txt

# Dry run (generate + validate patch, but don't apply)
pwsh .\scripts\cn_apply.ps1 -Name fizzbuzz -PromptFile .\docs\prompts\fizzbuzz.txt -DryRun

# Auto-fix loop (up to 2) + commit if green
pwsh .\scripts\cn_apply.ps1 -Name fizzbuzz -PromptFile .\docs\prompts\fizzbuzz.txt -AutoFix -MaxFixes 2 -Commit -CommitMessage "continue: fizzbuzz smoke test (cli)"

# Include Ollama check inside check.ps1 (if your check.ps1 supports it)
pwsh .\scripts\cn_apply.ps1 -Name fizzbuzz -PromptFile .\docs\prompts\fizzbuzz.txt -WithOllama
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

    # How many times to ask cn again if it returns an invalid patch
    [int] $MaxAttempts = 3,

    [switch] $DryRun,

    [switch] $Commit,

    [string] $CommitMessage = "continue: apply patch",

    # Pass -WithOllama to scripts/check.ps1
    [switch] $WithOllama,

    # Any extra args to pass to scripts/check.ps1 (string, appended)
    [string] $CheckArgs = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "INFO: $msg" }
function Write-Ok($msg)   { Write-Host "OK:   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "WARN: $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "ERR:  $msg" -ForegroundColor Red }

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null | Out-String).Trim()
    if (-not $root) { throw "Not inside a git repo (git rev-parse failed)." }
    return $root
}

function Assert-ToolExists([string]$ToolName) {
    $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "Required tool not found in PATH: $ToolName" }
}

function Read-PromptText {
    if ($PromptFile) {
        if (-not (Test-Path -LiteralPath $PromptFile)) { throw "PromptFile not found: $PromptFile" }
        return (Get-Content -LiteralPath $PromptFile -Raw)
    }
    if ($Prompt) { return $Prompt }
    throw "Provide -Prompt or -PromptFile."
}

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][scriptblock]$Command
    )
    $output = & $Command 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        if ($output) { $output | ForEach-Object { Write-Host $_ } }
        throw "$Label failed (exit $code)."
    }
    return ($output | Out-String)
}

function Normalize-Newlines([string]$Text) {
    # Normalize to LF internally
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Strip-CodeFences([string[]]$Lines) {
    return $Lines | Where-Object { $_ -notmatch '^\s*```' }
}

function Extract-GitPatchFromRaw([string]$RawText) {
    # Returns $null if we can't extract a plausible patch
    $t = Normalize-Newlines $RawText
    $lines = $t -split "`n"
    $lines = Strip-CodeFences $lines

    # Find first diff header
    $diffIdx = -1
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*diff --git\s+') { $diffIdx = $i; break }
    }
    if ($diffIdx -lt 0) { return $null }

    $patchLines = $lines[$diffIdx..($lines.Count - 1)]

    # Trim trailing whitespace-only lines
    while ($patchLines.Count -gt 0 -and ($patchLines[-1].Trim() -eq "")) {
        $patchLines = $patchLines[0..($patchLines.Count - 2)]
    }

    # Ensure final newline for git apply happiness
    return (($patchLines -join "`n").TrimEnd() + "`n")
}

function Test-PatchLooksReal([string]$PatchText) {
    # We reject the exact garbage you got:
    # diff header + "+++ b/file" + then line-numbered code like "1 {"
    # A real git patch must have:
    # - diff --git
    # - --- and +++
    # - at least one @@ hunk header
    # This keeps us from applying nonsense.
    $p = Normalize-Newlines $PatchText

    if ($p -notmatch '(?m)^\s*diff --git\s+') { return $false }
    if ($p -notmatch '(?m)^\s*---\s+')       { return $false }
    if ($p -notmatch '(?m)^\s*\+\+\+\s+')    { return $false }
    if ($p -notmatch '(?m)^\s*@@\s')         { return $false }

    # Additional sanity: reject patches that contain obvious "line-numbered listing" right after headers
    # (common when a model prints code with line numbers)
    if ($p -match '(?m)^\s*\d+\s+\{') { return $false }

    return $true
}

function Run-Continue([string]$PromptText, [string]$RawOutPath) {
    if (-not (Test-Path -LiteralPath $Config)) { throw "Continue config not found: $Config" }

    Write-Info "Running cn (silent) using config: $Config"
    # capture raw text
    $raw = & cn --config $Config --silent -p $PromptText 2>&1 | Out-String
    Write-Utf8NoBom -Path $RawOutPath -Text $raw
    return $raw
}

function Validate-PatchWithGitApplyCheck([string]$PatchPath) {
    Invoke-NativeChecked "git apply --check" { git apply --check $PatchPath } | Out-Null
}

function Apply-PatchChecked([string]$PatchPath) {
    Validate-PatchWithGitApplyCheck -PatchPath $PatchPath
    Invoke-NativeChecked "git apply" { git apply --whitespace=fix $PatchPath } | Out-Null
}

function Run-Check([string]$RepoRoot, [string]$CheckOutPath) {
    $check = Join-Path $RepoRoot "scripts\check.ps1"
    if (-not (Test-Path -LiteralPath $check)) { throw "check.ps1 not found at $check" }

    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $check, "-Fast")
    if ($WithOllama) { $args += "-WithOllama" }
    if ($CheckArgs -and $CheckArgs.Trim()) {
        # Split on spaces (simple). If you need fancy quoting, keep CheckArgs empty and add a real parameter later.
        $args += ($CheckArgs.Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries))
    }

    Write-Info ("Running: pwsh " + ($args -join " "))
    $output = & pwsh @args 2>&1 | Out-String
    $exit = $LASTEXITCODE

    Write-Utf8NoBom -Path $CheckOutPath -Text $output
    return @{ Output = $output; ExitCode = $exit }
}

function Get-GitPorcelain {
    return (& git status --porcelain | Out-String).Trim()
}

function Ensure-OutDir([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Build-StrictPrompt([string]$BasePrompt) {
    # This wrapper is meant to force "real git diff output" and avoid the junk you saw.
    $prefix = @"
Return ONLY a unified diff in git format.
No markdown. No code fences. No commentary. No JSON.
The first non-empty line MUST start with: diff --git
Include full headers (--- and +++) and hunks (@@ ...).
"@.Trim()

    return ($prefix + "`n`n" + $BasePrompt.Trim())
}

function Generate-ValidPatchOrThrow {
    param(
        [Parameter(Mandatory)][string]$BasePrompt,
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Timestamp
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $rawPath   = Join-Path $OutDir "$Name.$Timestamp.attempt$attempt.raw.txt"
        $patchPath = Join-Path $OutDir "$Name.$Timestamp.attempt$attempt.patch"

        $prompt = Build-StrictPrompt -BasePrompt $BasePrompt
        $raw = Run-Continue -PromptText $prompt -RawOutPath $rawPath

        $patch = Extract-GitPatchFromRaw -RawText $raw
        if (-not $patch) {
            Write-Warn "Attempt $attempt: no 'diff --git' found. Raw saved: $rawPath"
            continue
        }

        if (-not (Test-PatchLooksReal -PatchText $patch)) {
            Write-Warn "Attempt $attempt: extracted patch failed sanity checks (missing hunks/headers or contains junk). Raw: $rawPath"
            Write-Utf8NoBom -Path $patchPath -Text $patch
            continue
        }

        Write-Utf8NoBom -Path $patchPath -Text $patch

        # Validate with git apply --check before accepting it
        try {
            Validate-PatchWithGitApplyCheck -PatchPath $patchPath
            Write-Ok "Attempt $attempt: patch validated with git apply --check"
            return @{ RawPath = $rawPath; PatchPath = $patchPath; PatchText = $patch }
        }
        catch {
            Write-Warn "Attempt $attempt: git apply --check failed. Keeping files: $rawPath / $patchPath"
            continue
        }
    }

    throw "Failed to obtain a valid git-apply patch after $MaxAttempts attempt(s). See runs for details."
}

# ---------------------------
# Main
# ---------------------------

Assert-ToolExists "git"
Assert-ToolExists "cn"
Assert-ToolExists "pwsh"

if ($Prompt -and $PromptFile) {
    throw "Use only one of -Prompt or -PromptFile (not both)."
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

Ensure-OutDir -Path $OutDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Safety: recommend starting clean (but don't force it)
$porcelain = Get-GitPorcelain
if ($porcelain) {
    Write-Warn "Working tree not clean. Patch application is safest on a clean tree."
}

$basePrompt = Read-PromptText

# 1) Generate a valid patch (with retries)
$gen = Generate-ValidPatchOrThrow -BasePrompt $basePrompt -OutDir $OutDir -Name $Name -Timestamp $timestamp
$patchPath = $gen.PatchPath
Write-Ok "Patch ready: $patchPath"

if ($DryRun) {
    Write-Ok "DryRun: patch was validated but not applied."
    exit 0
}

# 2) Apply patch (hard fail if git apply fails)
Apply-PatchChecked -PatchPath $patchPath
Write-Ok "Patch applied."

# 3) Run check.ps1 and decide next steps by EXIT CODE
$checkPath = Join-Path $OutDir "$Name.$timestamp.check.txt"
$check = Run-Check -RepoRoot $repoRoot -CheckOutPath $checkPath

if ($check.ExitCode -eq 0) {
    Write-Ok "Repo is green."
}
elseif ($AutoFix) {
    Write-Warn "Repo not green (exit $($check.ExitCode)). Entering auto-fix loop (max $MaxFixes)."

    $currentOutput = $check.Output
    $fixed = $false

    for ($i = 1; $i -le $MaxFixes; $i++) {
        $fixTimestamp = "$timestamp.fix$i"

        $fixPrompt = @"
The previous patch has already been applied.
Return ONLY a unified diff in git format (git apply compatible).
No markdown. No code fences. No commentary. No JSON.
The first non-empty line MUST start with: diff --git
Fix ONLY what is necessary to make: pwsh .\scripts\check.ps1 -Fast pass.

Failing output:
$currentOutput
"@.Trim()

        $fixGen = Generate-ValidPatchOrThrow -BasePrompt $fixPrompt -OutDir $OutDir -Name $Name -Timestamp $fixTimestamp
        $fixPatchPath = $fixGen.PatchPath

        Apply-PatchChecked -PatchPath $fixPatchPath
        Write-Ok "Applied auto-fix patch $i: $fixPatchPath"

        $fixCheckPath = Join-Path $OutDir "$Name.$fixTimestamp.check.txt"
        $check = Run-Check -RepoRoot $repoRoot -CheckOutPath $fixCheckPath
        $currentOutput = $check.Output

        if ($check.ExitCode -eq 0) {
            Write-Ok "Repo is green after auto-fix $i."
            $fixed = $true
            break
        }
        else {
            Write-Warn "Still failing after auto-fix $i (exit $($check.ExitCode))."
        }
    }

    if (-not $fixed) {
        throw "Auto-fix exhausted ($MaxFixes). Refusing to proceed. See check output: $checkPath"
    }
}
else {
    throw "Repo not green (exit $($check.ExitCode)). See check output: $checkPath"
}

# 4) Optional commit
if ($Commit) {
    # Ensure green right now (exit code already checked above)
    $porcelain = Get-GitPorcelain
    if (-not $porcelain) {
        Write-Warn "Nothing to commit (working tree clean)."
        exit 0
    }

    Invoke-NativeChecked "git add" { git add -A } | Out-Null
    Invoke-NativeChecked "git commit" { git commit -m $CommitMessage } | Out-Null
    Write-Ok "Committed: $CommitMessage"
}
