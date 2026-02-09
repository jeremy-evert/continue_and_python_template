# scripts/CnApply.Lib.psm1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Module root (scripts/)
$script:CnApplyRoot = $PSScriptRoot
$lib = Join-Path $script:CnApplyRoot "cnapply"

# Dot-source libs into THIS module scope (so exports work cleanly)
. (Join-Path $lib "logging.ps1")
. (Join-Path $lib "io.ps1")
. (Join-Path $lib "native.ps1")
. (Join-Path $lib "git.ps1")
. (Join-Path $lib "prompt.ps1")
. (Join-Path $lib "patch.ps1")
. (Join-Path $lib "repocheck.ps1")
. (Join-Path $lib "orchestrator.ps1")

Export-ModuleMember -Function Invoke-CnApply
