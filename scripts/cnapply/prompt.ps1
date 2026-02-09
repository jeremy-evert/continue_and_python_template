function Read-PromptText {
    param(
        [string]$Prompt,
        [string]$PromptFile
    )

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
