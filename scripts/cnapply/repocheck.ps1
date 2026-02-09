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
