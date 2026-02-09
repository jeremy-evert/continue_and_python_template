function Invoke-CnApply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,

        [string]$Prompt,
        [string]$PromptFile,

        [string]$Config = "$HOME\.continue\config.yaml",
        [string]$OutDir  = ".\runs",

        [switch]$AutoFix,
        [int]$MaxFixes = 1,

        [int]$MaxAttempts = 3,
        [switch]$DryRun,

        [switch]$Commit,
        [string]$CommitMessage = "continue: apply patch",

        [switch]$WithOllama,
        [string]$CheckArgs = ""
    )

    # Optional defaults file
    $defaultsPath = Join-Path $script:CnApplyRoot "CnApply.Config.psd1"
    if (Test-Path -LiteralPath $defaultsPath) {
        $d = Import-PowerShellDataFile -Path $defaultsPath
        if (-not $PSBoundParameters.ContainsKey("OutDir") -and $d.DefaultOutDir) { $OutDir = $d.DefaultOutDir }
        if (-not $PSBoundParameters.ContainsKey("MaxFixes") -and $d.DefaultMaxFixes) { $MaxFixes = [int]$d.DefaultMaxFixes }
        if (-not $PSBoundParameters.ContainsKey("MaxAttempts") -and $d.DefaultMaxAttempts) { $MaxAttempts = [int]$d.DefaultMaxAttempts }
    }

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

    # 1) Generate patch that git accepts
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

    # 2) Apply patch
    Apply-PatchChecked -PatchPath $patchPath
    Write-Ok "Patch applied."

    # 3) Check repo (exit code decides reality)
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

    # 4) Optional commit
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
