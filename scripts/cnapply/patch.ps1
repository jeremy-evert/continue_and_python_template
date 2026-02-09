function Normalize-Newlines {
    param([AllowEmptyString()][string]$Text)
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Strip-CodeFences {
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    if ($null -eq $Lines) { return @() }
    if ($Lines.Count -eq 0) { return @() }

    # If we got a single empty element, treat it as "no lines"
    if ($Lines.Count -eq 1 -and [string]::IsNullOrWhiteSpace($Lines[0])) { return @() }

    return $Lines | Where-Object { $_ -notmatch '^\s*```' }
}

function Run-Continue {
    param(
        [Parameter(Mandatory)][string]$Config,
        [Parameter(Mandatory)][string]$PromptText,
        [Parameter(Mandatory)][string]$RawOutPath
    )

    if (-not (Test-Path -LiteralPath $Config)) { throw "Continue config not found: $Config" }

    Write-Info "Running cn (silent) using config: $Config"
    $raw = Invoke-NativeChecked "cn" { cn --config $Config --silent -p $PromptText }
    Write-Utf8NoBom -Path $RawOutPath -Text $raw
    return $raw
}

function Extract-GitPatchFromRaw {
    param([AllowEmptyString()][string]$RawText)

    # If cn returned nothing (or whitespace), there is no patch.
    if ([string]::IsNullOrWhiteSpace($RawText)) { return $null }

    $t = Normalize-Newlines $RawText

    # Split safely; treat empty result as no lines
    $split = $t -split "`n"
    $lines = Strip-CodeFences -Lines $split

    if ($null -eq $lines -or $lines.Count -eq 0) { return $null }

    $diffIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*diff --git\s+') { $diffIdx = $i; break }
    }
    if ($diffIdx -lt 0) { return $null }

    $patchLines = $lines[$diffIdx..($lines.Count - 1)]

    # Trim trailing whitespace-only lines
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
            Write-Warn "Attempt $($attempt): no 'diff --git' found (or empty output). Raw saved: $rawPath"
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
