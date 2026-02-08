# How to Get Help (Read This First)

This document exists to help you get **useful help fast**.

If you follow the steps below, you will usually get an answer quickly.
If you skip them, the most common response will be:

> “Please run `pwsh .\scripts\check.ps1` and paste the last ~30 lines.”

That’s not punishment. That’s just how we debug without guessing.

---

## Step 0: Run the repo health check (required)

Before asking for help, you must run **one** of these:

### Full check (recommended)
```powershell
pwsh .\scripts\check.ps1
````

### Fast check (CI-style)

```powershell
pwsh .\scripts\check.ps1 -Fast
```

What it does:

* ensures `.venv` exists
* installs dev dependencies (unless `-Fast`)
* runs format + lint + tests
* prints clear pass/fail output

If this fails, **do not guess**. Go to Step 1 and paste the output.

---

## Step 1: Collect the required info (copy/paste this)

When asking for help (Canvas message, email, Discord, in person), include ALL of the following.

### 1) Your environment

Fill this in:

* **Operating system**: (Windows / macOS / Linux + version if you know it)
* **Shell**: (PowerShell / Git Bash / Terminal / etc.)
* **Python version**:

  ```powershell
  python --version
  ```

---

### 2) The exact command you ran

Example:

```powershell
pwsh .\scripts\check.ps1
```

Or:

```powershell
pwsh .\scripts\check.ps1 -Fast
```

Copy/paste the exact command. Don’t summarize.

---

### 3) The output (this part matters most)

Include ONE of these:

* ✅ **Preferred**: the full output
* ✅ **Acceptable**: the **last ~30 lines** of output

Paste it as text. Avoid screenshots unless explicitly asked.

Tip for last ~30 lines:

```powershell
pwsh .\scripts\check.ps1 2>&1 | Select-Object -Last 30
```
* “If pre-commit is not recognized, run: pwsh .\scripts\precommit.ps1”
---

### 4) Expected vs Actual (two short sentences)

Example:

* **Expected**: `check.ps1` to pass.
* **Actual**: pytest failed with an import error.

---

## Step 2: Ask the question clearly

Good examples:

* “Why is pytest failing even though ruff passes?”
* “Why does this import work locally but fail in tests?”
* “What does this ruff error mean in plain English?”

Bad examples:

* “It doesn’t work”
* “I’m stuck”
* “My code is broken”

---

## Common fixes (try these before spiraling)

### ❌ `.venv` missing or broken

```powershell
pwsh .\scripts\setup_precommit.ps1
```

### ❌ Ruff errors

Ruff usually tells you exactly what to change. You can also run:

```powershell
ruff format .
ruff check .
```

### ❌ Tests failing

Focus on the **first failure**, not the last line.
The real error is almost always higher up.

Run:

```powershell
pytest -q
```

---

## Encoding / emoji weirdness (mojibake)

If checkmarks/emojis turn into garbage (examples: `â€¦` or `ï»¿`), do this:

```powershell
pwsh .\scripts\fix_docs_utf8.ps1
pwsh .\scripts\check.ps1 -Fast
```

Canonical scan for encoding artifacts:

```powershell
Select-String -Path .\docs\**\*.md -Pattern "â|Ã|Â|�|ï»¿" -AllMatches
```

Canonical BOM detector (UTF-8 BOM files):

```powershell
Get-ChildItem .\docs -Recurse -Filter *.md -File | ForEach-Object {
  $b = [IO.File]::ReadAllBytes($_.FullName)
  $hasBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
  if ($hasBom) { $_.FullName }
}
```

---

## Why we do it this way

Professional debugging is:

* reproducible
* observable
* specific

This process is not about being strict.
It’s about saving time (including yours).

---

## TL;DR (paste this with your help request)

1. Output of: `pwsh .\scripts\check.ps1` (or last ~30 lines)
2. OS + Python version + shell
3. Exact command you ran
4. Expected vs actual behavior
