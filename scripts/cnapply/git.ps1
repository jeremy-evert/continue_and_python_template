function Get-RepoRoot {
    $root = (Invoke-NativeChecked "git rev-parse" { git rev-parse --show-toplevel }).Trim()
    if (-not $root) { throw "Not inside a git repo (git rev-parse returned empty)." }
    return $root
}

function Get-GitPorcelain {
    return (& git status --porcelain | Out-String).Trim()
}
