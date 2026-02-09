# scripts/cnapply/_selftest_patch.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (& git rev-parse --show-toplevel | Out-String).Trim()
if (-not $repoRoot) { throw "Run inside a git repo." }

. (Join-Path $repoRoot "scripts\cnapply\patch.ps1")

function Assert($cond, $msg) {
    if (-not $cond) { throw "ASSERT FAILED: $msg" }
}

Write-Host "Selftest: Extract-GitPatchFromRaw basics..."

# 1) Empty output should return $null (and not throw)
$p = Extract-GitPatchFromRaw -RawText ""
Assert ($null -eq $p) "Empty raw should return null"

# 2) Code fences stripped
$raw2 = @"
```diff
diff --git a/x b/x
--- a/x
+++ b/x
@@ -0,0 +1 @@
+test
"@
$p2 = Extract-GitPatchFromRaw -RawText $raw2
Assert ($p2 -match '^\sdiff --git') "Should extract patch even with fences"
Assert ($p2 -match '(?m)^\s@@') "Should include hunk header"

3) Tool JSON resolves to a referenced patch file

$tmp = Join-Path $repoRoot "runs_selftest_tool.patch"
New-Item -ItemType Directory -Force -Path (Split-Path $tmp -Parent) | Out-Null
Set-Content -LiteralPath $tmp -Value @"
diff --git a/x b/x
--- a/x
+++ b/x
@@ -0,0 +1 @@
+toolfile
"@ -NoNewline

$json = '{"name":"diff","parameters":{"a":"runs/_selftest_tool.patch","b":"./x"}}'
$resolved = Resolve-ToolJsonToText -RawText $json -RepoRoot $repoRoot
Assert ($resolved -match 'toolfile') "Tool JSON should resolve to file contents"

Write-Host "OK: patch.ps1 selftests passed." -ForegroundColor Green
