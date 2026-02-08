# scripts/fix_docs_utf8.ps1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$utf8NoBomStrict = New-Object System.Text.UTF8Encoding($false, $true)
$utf8NoBom       = New-Object System.Text.UTF8Encoding($false)

$docs = Join-Path $PSScriptRoot "..\docs"
$files = Get-ChildItem $docs -Recurse -Filter *.md -File

$changed = 0
foreach ($f in $files) {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)

    # Strip UTF-8 BOM if present
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }

    # Decode strictly as UTF-8; if invalid, fall back to Windows-1252
    try {
        $text = $utf8NoBomStrict.GetString($bytes)
    } catch {
        $text = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)
    }

    # Write back as UTF-8 (no BOM)
    $newBytes = $utf8NoBom.GetBytes($text)

    # Only write if content/bytes differ (avoid dirtying git for no reason)
    $orig = [IO.File]::ReadAllBytes($f.FullName)
    if (($orig.Length -ne $newBytes.Length) -or -not ($orig -ceq $newBytes)) {
        [IO.File]::WriteAllBytes($f.FullName, $newBytes)
        $changed++
    }
}

Write-Host "Docs normalized to UTF-8 (no BOM). Files changed: $changed"
exit 0
