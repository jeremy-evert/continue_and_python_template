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
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Name,

    [string] $Prompt,
    [string] $PromptFile,

    [string] $Config = "$HOME\.continue\config.yaml",
    [string] $OutDir  = ".\runs",

    [switch] $AutoFix,
    [int] $MaxFixes = 1,

    [int] $MaxAttempts = 3,
    [switch] $DryRun,

    [switch] $Commit,
    [string] $CommitMessage = "continue: apply patch",

    [switch] $WithOllama,
    [string] $CheckArgs = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import library in the same folder as this script
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here "CnApply.Lib.psm1") -Force

Invoke-CnApply `
    -Name $Name `
    -Prompt $Prompt `
    -PromptFile $PromptFile `
    -Config $Config `
    -OutDir $OutDir `
    -AutoFix:$AutoFix `
    -MaxFixes $MaxFixes `
    -MaxAttempts $MaxAttempts `
    -DryRun:$DryRun `
    -Commit:$Commit `
    -CommitMessage $CommitMessage `
    -WithOllama:$WithOllama `
    -CheckArgs $CheckArgs
