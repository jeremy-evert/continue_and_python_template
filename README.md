# python_template

A Python-first, polyglot-ready GitHub **template repository** with clean-code guardrails and a repeatable workflow.

Designed for:
- **CS1 and beyond** (students start with good habits)
- **real projects** (Canvas tooling, sysadmin scripts, pipelines)
- **LLM-assisted development** without getting stuck in "molasses"

---

## What you get

- A clean folder layout that answers: **"where do I poke?"**
- A standard dev toolchain: **ruff + pytest + pre-commit**
- One-command “is this repo healthy?” checks
- Reserved folders for artifacts (`runs/`, `reports/`) so work is measurable

---

## Folder layout

```text
src/python_template/
  core/        # pure logic (no I/O)
  adapters/    # outside world: APIs, files, subprocess, LLMs
  app/         # orchestration workflows
  cli/         # entrypoints

tests/         # tests first, always
tools/         # repo doctor, commit wizard, etc.
docs/          # checklists, modes, prompts
scripts/       # setup + check helpers
runs/          # runtime artifacts (json/csv outputs)
reports/       # reports (lint, metrics, dashboards later)
web/           # optional HTML/CSS/JS
````

---

## Use this template

### Make a new repo in ~60 seconds

1. On GitHub, click **Use this template** (green button).
2. Name your new repo (example: `cs1_project_01`).
3. Clone your new repo locally.
4. First-time setup (Windows PowerShell):

```powershell
cd path\to\your\new\repo

python -m venv .venv
.\.venv\Scripts\activate
python -m pip install -U pip

pip install -e ".[dev]"
pwsh .\scripts\setup_precommit.ps1
pwsh .\scripts\check.ps1
```

---

## The “10-minute green” test (recommended)

Goal: click → clone → green checks without guessing.

```powershell
pwsh .\scripts\setup_precommit.ps1
pwsh .\scripts\check.ps1 -Fast
pwsh .\scripts\doctor.ps1 -Fast
```

If those pass, you’re officially in the “calm developer timeline.” ✅

---

## Standard workflow

### Setup once

```powershell
pwsh .\scripts\setup_precommit.ps1
# If "pre-commit" isn't recognized, use the venv-first wrapper:
pwsh .\scripts\precommit.ps1
```

### Check health anytime

```powershell
pwsh .\scripts\check.ps1
pwsh .\scripts\check.ps1 -Fast
```

### Repo health report (anti-molasses)

```powershell
pwsh .\scripts\doctor.ps1
pwsh .\scripts\doctor.ps1 -Fast
pwsh .\scripts\doctor.ps1 -Verbose
```

---

## Docs not rendering right (emoji/checkbox hieroglyphics)

If your Markdown turns into `â€¦` or your checkmarks look cursed, fix it in one command:

```powershell
pwsh .\scripts\fix_docs_utf8.ps1
pwsh .\scripts\check.ps1 -Fast
```

(That normalizes docs to **UTF-8 (no BOM)**.)

---

## When stuck (read this before asking for help)

1. Run the health check:

```powershell
pwsh .\scripts\check.ps1
```

2. Then follow the help checklist:

* Read: `docs/GET_HELP.md`
* When you ask for help, include the **last ~30 lines** of output from `check.ps1`
* Also include: your OS + `python --version`

That combo gets you answers fast, without guesswork.

---

## Supported Python versions

* **Target: Python 3.10+**
* If you must support older lab machines later, we can adjust. Default is modern tooling and fewer surprises.

---

## Contributing

Small, shippable commits. Each meaningful change should produce something observable:

* updated code, or
* a test, or
* a report/artifact in `reports/` or `runs/`

---

## Docs index

* `docs/GET_HELP.md` (how to ask for help effectively)
* `docs/MODES.md` (Starter vs Builder expectations)
* `docs/TODO.md` (ranked next steps)
* `docs/continue/README.md` (Continue + prompts/rules)
