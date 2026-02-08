Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------
# Logging
# ---------------------------
function Write-Info { param($msg) Write-Host "INFO: $msg" }
function Write-Ok   { param($msg) Write-Host "OK:   $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "WARN: $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "ERR:  $msg" -ForegroundColor Red }

# ---------------------------
# Utilities
# ---------------------------
function Write-Utf8NoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Text)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Assert-ToolExists {
    param([Parameter(Mandatory)][string]$ToolName)
    $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "Required tool not found in PATH: $ToolName" }
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

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null | Out-String).Trim()
    if (-not $root) { throw "Not inside a git repo (git rev-parse failed)." }
    return $root
}

function Ensure-Dir {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Get-GitPorcelain {
    return (& git status --porcelain | Out-String).Trim()
}

function Normalize-Newlines {
    param([Parameter(Mandatory)][string]$Text)
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Strip-CodeFences {
    param([Parameter(Mandatory)][string[]]$Lines)
    return $Lines | Where-Object { $_ -notmatch '^\s*```' }
}

# ---------------------------
# Prompt handling
# ---------------------------
function Read-PromptText {
    param([string]$Prompt, [string]$PromptFile)

    if ($Prompt -and $PromptFile) {
        throw "Use only one of -Prompt or -PromptFile (not both)."
    }

    if ($PromptFile) {
        if (-not (Test-Path -LiteralPath $PromptFile)) { throw "PromptFile not found: $PromptFile" }
        return (Get-Content -LiteralPath $PromptFile -Raw)
    }

    if ($Prompt) { return $Prompt }

    throw "Provide -Prompt or -PromptFile."
}

function Build-StrictPrompt {
    param([Parameter(Mandatory)][string]$BasePrompt)

    $prefix = @"
Return ONLY a unified diff in git format.
No markdown. No code fences. No commentary. No JSON.
The first non-empty line MUST start with: diff --git
Include full headers (--- and +++) and hunks (@@ ...).
"@.Trim()

    return ($prefix + "`n`n" + $BasePrompt.Trim())
}

# ---------------------------
# Continue + Patch extraction/validation
# ---------------------------
function Run-Continue {
    param(
        [Parameter(Mandatory)][string]$Config,
        [Parameter(Mandatory)][string]$PromptText,
        [Parameter(Mandatory)][string]$RawOutPath
    )

    if (-not (Test-Path -LiteralPath $Config)) { throw "Continue config not found: $Config" }

    Write-Info "Running cn (silent) using config: $Config"
    $raw = & cn --config $Config --silent -p $PromptText 2>&1 | Out-String

    Write-Utf8NoBom -Path $RawOutPath -Text $raw
    return $raw
}

function Extract-GitPatchFromRaw {
    param([Parameter(Mandatory)][string]$RawText)

    $t = Normalize-Newlines $RawText
    $lines = Strip-CodeFences ($t -split "`n")

    $diffIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*diff --git\s+') { $diffIdx = $i; break }
    }
    if ($diffIdx -lt 0) { return $null }

    $patchLines = $lines[$diffIdx..($lines.Count - 1)]

    while ($patchLines.Count -gt 0 -and ($patchLines[-1].Trim() -eq "")) {
        $patchLines = $patchLines[0..($patchLines.Count - 2)]
    }

    return (($patchLines -join "`n").TrimEnd() + "`n")
}

function Test-PatchLooksReal {
    param([Parameter(Mandatory)][string]$PatchText)

    $p = Normalize-Newlines $PatchText

    if ($p -notmatch '(?m)^\s*diff --git\s+') { return $false }
    if ($p -notmatch '(?m)^\s*---\s+')       { return $false }
    if ($p -notmatch '(?m)^\s*\+\+\+\s+')    { return $false }
    if ($p -notmatch '(?m)^\s*@@\s')         { return $false }

    # Reject obvious "line-numbered listing" junk
    if ($p -match '(?m)^\s*\d+\s+\{') { return $false }

    return $true
}

function Validate-PatchWithGitApplyCheck {
    param([Parameter(Mandatory)][string]$PatchPath)
    Invoke-NativeChecked "git apply --check" { git apply --check $PatchPath } | Out-Null
}

function Apply-PatchChecked {
    param([Parameter(Mandatory)][string]$PatchPath)
    Validate-PatchWithGitApplyCheck -PatchPath $PatchPath
    Invoke-NativeChecked "git apply" { git apply --whitespace=fix $PatchPath } | Out-Null
}

function New-ValidPatchOrThrow {
    param(
        [Parameter(Mandatory)][string]$Config,
        [Parameter(Mandatory)][string]$BasePrompt,
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Timestamp,
        [Parameter(Mandatory)][int]$MaxAttempts
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $rawPath   = Join-Path $OutDir "$Name.$Timestamp.attempt$attempt.raw.txt"
        $patchPath = Join-Path $OutDir "$Name.$Timestamp.attempt$attempt.patch"

        $prompt = Build-StrictPrompt -BasePrompt $BasePrompt
        $raw = Run-Continue -Config $Config -PromptText $prompt -RawOutPath $rawPath

        $patch = Extract-GitPatchFromRaw -RawText $raw
        if (-not $patch) {
            Write-Warn "Attempt $($attempt): no 'diff --git' found. Raw saved: $rawPath"
            continue
        }

        if (-not (Test-PatchLooksReal -PatchText $patch)) {
            Write-Warn "Attempt $($attempt): extracted patch failed sanity checks. Raw: $rawPath"
            Write-Utf8NoBom -Path $patchPath -Text $patch
            continue
        }

        Write-Utf8NoBom -Path $patchPath -Text $patch

        try {
            Validate-PatchWithGitApplyCheck -PatchPath $patchPath
            Write-Ok "Attempt $($attempt): patch validated with git apply --check"
            return @{ RawPath = $rawPath; PatchPath = $patchPath; PatchText = $patch }
        }
        catch {
            Write-Warn "Attempt $($attempt): git apply --check failed. Keeping: $rawPath / $patchPath"
            continue
        }
    }

    throw "Failed to obtain a valid git-apply patch after $MaxAttempts attempt(s). See runs for details."
}

# ---------------------------
# Repo checking
# ---------------------------
function Run-RepoCheck {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$CheckOutPath,
        [switch]$WithOllama,
        [string]$CheckArgs = ""
    )

    $check = Join-Path $RepoRoot "scripts\check.ps1"
    if (-not (Test-Path -LiteralPath $check)) { throw "check.ps1 not found at $check" }

    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $check, "-Fast")
    if ($WithOllama) { $args += "-WithOllama" }
    if ($CheckArgs -and $CheckArgs.Trim()) {
        $args += ($CheckArgs.Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries))
    }

    Write-Info ("Running: pwsh " + ($args -join " "))
    $output = & pwsh @args 2>&1 | Out-String
    $exit = $LASTEXITCODE

    Write-Utf8NoBom -Path $CheckOutPath -Text $output
    return @{ Output = $output; ExitCode = $exit }
}

# ---------------------------
# Public entrypoint
# ---------------------------
function Invoke-CnApply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,

        [string]$Prompt,
        [string]$PromptFile,

        [Parameter(Mandatory)][string]$Config,
        [Parameter(Mandatory)][string]$OutDir,

        [switch]$AutoFix,
        [int]$MaxFixes = 1,

        [int]$MaxAttempts = 3,
        [switch]$DryRun,

        [switch]$Commit,
        [string]$CommitMessage = "continue: apply patch",

        [switch]$WithOllama,
        [string]$CheckArgs = ""
    )

    Assert-ToolExists "git"
    Assert-ToolExists "cn"
    Assert-ToolExists "pwsh"

    $repoRoot = Get-RepoRoot
    Set-Location $repoRoot

    Ensure-Dir -Path $OutDir

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $porcelain = Get-GitPorcelain
    if ($porcelain) {
        Write-Warn "Working tree not clean. Patch application is safest on a clean tree."
    }

    $basePrompt = Read-PromptText -Prompt $Prompt -PromptFile $PromptFile

    # 1) Make a patch that git will accept
    $gen = New-ValidPatchOrThrow `
        -Config $Config `
        -BasePrompt $basePrompt `
        -OutDir $OutDir `
        -Name $Name `
        -Timestamp $timestamp `
        -MaxAttempts $MaxAttempts

    $patchPath = $gen.PatchPath
    Write-Ok "Patch ready: $patchPath"

    if ($DryRun) {
        Write-Ok "DryRun: patch validated but not applied."
        return
    }

    # 2) Apply it
    Apply-PatchChecked -PatchPath $patchPath
    Write-Ok "Patch applied."

    # 3) Check repo
    $checkPath = Join-Path $OutDir "$Name.$timestamp.check.txt"
    $check = Run-RepoCheck -RepoRoot $repoRoot -CheckOutPath $checkPath -WithOllama:$WithOllama -CheckArgs $CheckArgs

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

            $fixGen = New-ValidPatchOrThrow `
                -Config $Config `
                -BasePrompt $fixPrompt `
                -OutDir $OutDir `
                -Name $Name `
                -Timestamp $fixTimestamp `
                -MaxAttempts $MaxAttempts

            Apply-PatchChecked -PatchPath $fixGen.PatchPath
            Write-Ok "Applied auto-fix patch $($i): $($fixGen.PatchPath)"

            $fixCheckPath = Join-Path $OutDir "$Name.$fixTimestamp.check.txt"
            $check = Run-RepoCheck -RepoRoot $repoRoot -CheckOutPath $fixCheckPath -WithOllama:$WithOllama -CheckArgs $CheckArgs
            $currentOutput = $check.Output

            if ($check.ExitCode -eq 0) {
                Write-Ok "Repo is green after auto-fix $($i)."
                $fixed = $true
                break
            }

            Write-Warn "Still failing after auto-fix $($i) (exit $($check.ExitCode))."
        }

        if (-not $fixed) {
            throw "Auto-fix exhausted ($MaxFixes). See check output: $checkPath"
        }
    }
    else {
        throw "Repo not green (exit $($check.ExitCode)). See check output: $checkPath"
    }

    # 4) Commit
    if ($Commit) {
        $porcelain = Get-GitPorcelain
        if (-not $porcelain) {
            Write-Warn "Nothing to commit (working tree clean)."
            return
        }

        Invoke-NativeChecked "git add" { git add -A } | Out-Null
        Invoke-NativeChecked "git commit" { git commit -m $CommitMessage } | Out-Null
        Write-Ok "Committed: $CommitMessage"
    }
}

Export-ModuleMember -Function Invoke-CnApply
