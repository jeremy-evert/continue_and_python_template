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
