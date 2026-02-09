# scripts/cnapply/patch.ps1
# Patch extraction + Continue runner.
# Handles:
# - Empty output
# - Markdown fences
# - Tool-call JSON output (e.g., {"name":"diff","parameters":{"a":"...","b":"..."}})

function Normalize-Newlines {
    param([AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Strip-CodeFences {
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Lines
    )
    if ($null -eq $Lines -or $Lines.Count -eq 0) { return @() }
    return $Lines | Where-Object { $_ -notmatch '^\s*```' }
}

function Resolve-ToolJsonToText {
    param(
        [Parameter(Mandatory)][string]$RawText,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $trim = $RawText.Trim()
    if (-not $trim) { return "" }

    # Heuristic: looks like JSON object
    if (-not ($trim.StartsWith("{") -and $trim.EndsWith("}"))) {
        return $RawText
    }

    try {
        $obj = $trim | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        # Not actually JSON, just starts with '{' sometimes
        return $RawText
    }

    # Expected tool-call-ish shapes:
    # {"name":"diff","parameters":{"a":"./something.patch","b":"./x"}}
    # Sometimes could be {"tool":"diff", ...} depending on providers.
    $toolName = $null
    if ($obj.PSObject.Properties.Name -contains "name") { $toolName = [string]$obj.name }
    elseif ($obj.PSObject.Properties.Name -contains "tool") { $toolName = [string]$obj.tool }

    if (-not $toolName) {
        throw "Continue returned JSON but no 'name'/'tool' field was found. Raw: $trim"
    }

    if ($toolName -ne "diff") {
        throw "Continue returned tool-call JSON for tool '$toolName', not a unified diff. Raw: $trim"
    }

    $p = $obj.parameters
    if (-not $p) {
        throw "Continue returned diff tool-call JSON but no 'parameters' field. Raw: $trim"
    }

    # Best guess: parameters.a is the patch file it wants diffed from
    $candidatePaths = @()
    foreach ($k in @("a", "patch", "path", "file", "filepath")) {
        if ($p.PSObject.Properties.Name -contains $k) {
            $v = [string]$p.$k
            if ($v) { $candidatePaths += $v }
        }
    }

    foreach ($cp in $candidatePaths) {
        # Resolve relative paths against repo root
        $resolved = $cp
        if (-not [System.IO.Path]::IsPathRooted($resolved)) {
            $resolved = Join-Path $RepoRoot $cp
        }

        if (Test-Path -LiteralPath $resolved) {
            $txt = Get-Content -LiteralPath $resolved -Raw
            if ($txt -and $txt.Trim()) {
                return $txt
            }
        }
    }

    throw "Continue returned diff tool-call JSON but I couldn't find/read a referenced patch file. Raw: $trim"
}

function Run-Continue {
    param(
        [Parameter(Mandatory)][string]$Config,
        [Parameter(Mandatory)][string]$PromptText,
        [Parameter(Mandatory)][string]$RawOutPath
    )

    if (-not (Test-Path -LiteralPath $Config)) { throw "Continue config not found: $Config" }

    Write-Info "Running cn (silent) using config: $Config"
    # NOTE: Invoke-NativeChecked should come from scripts/cnapply/native.ps1
    $raw = Invoke-NativeChecked "cn" { cn --config $Config --silent -p $PromptText }
    Write-Utf8NoBom -Path $RawOutPath -Text $raw
    return $raw
}

function Extract-GitPatchFromRaw {
    param(
        [AllowEmptyString()]
        [string]$RawText
    )

    if ($null -eq $RawText -or -not $RawText.Trim()) { return $null }

    $t = Normalize-Newlines $RawText
    $lines = Strip-CodeFences ($t -split "`n")

    if ($null -eq $lines -or $lines.Count -eq 0) { return $null }

    # Find first diff header
    $diffIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*diff --git\s+') { $diffIdx = $i; break }
    }
    if ($diffIdx -lt 0) { return $null }

    $patchLines = $lines[$diffIdx..($lines.Count - 1)]

    # Trim trailing blank lines
    while ($patchLines.Count -gt 0 -and ($patchLines[-1].Trim() -eq "")) {
        if ($patchLines.Count -eq 1) { $patchLines = @(); break }
        $patchLines = $patchLines[0..($patchLines.Count - 2)]
    }

    if ($patchLines.Count -eq 0) { return $null }

    # Ensure final newline for git apply happiness
    return (($patchLines -join "`n").TrimEnd() + "`n")
}

function Test-PatchLooksReal {
    param([Parameter(Mandatory)][string]$PatchText)

    if (-not $PatchText.Trim()) { return $false }
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
        [Parameter(Mandatory)][int]$MaxAttempts,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $rawPath   = Join-Path $OutDir "$Name.$Timestamp.attempt$attempt.raw.txt"
        $patchPath = Join-Path $OutDir "$Name.$Timestamp.attempt$attempt.patch"

        $prompt = Build-StrictPrompt -BasePrompt $BasePrompt
        $raw = Run-Continue -Config $Config -PromptText $prompt -RawOutPath $rawPath

        # If cn returned tool-call JSON, translate it into text we can parse
        $rawResolved = Resolve-ToolJsonToText -RawText $raw -RepoRoot $RepoRoot

        $patch = Extract-GitPatchFromRaw -RawText $rawResolved
        if (-not $patch) {
            Write-Warn "Attempt $($attempt): no 'diff --git' found. Raw saved: $rawPath"
            continue
        }

        if (-not (Test-PatchLooksReal -PatchText $patch)) {
            Write-Warn "Attempt $($attempt): patch failed sanity checks. Raw: $rawPath"
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
        }
    }

    throw "Failed to obtain a valid git-apply patch after $MaxAttempts attempt(s). See runs for details."
}
