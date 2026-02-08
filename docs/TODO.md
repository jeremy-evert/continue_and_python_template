# TODO (Ranked)

**Policy:** keep this file small (next actions only).  
Append-only: don’t rewrite big sections, just add/mark items.  
If it gets long, move narrative/detail to `docs/TODO_HISTORY.md`.

This TODO is the single source of truth for what we do next.

We optimize for:
- high ROI
- repeatable workflows
- student-friendly setup
- shippable increments
- minimum molasses

---

## ✅ Done (short list)
- repo scaffold + baseline tooling (ruff/pytest)
- pre-commit installed + working
- `check.ps1` + `doctor.ps1` working
- CI fast-check on push/PR
- docs: template usage + help + encoding recovery
- Continue docs + starter rules/prompts present (repo-local docs)

---

## 🧱 Next (keep this list small)

### 1) Re-verify “fresh repo ritual” (template clone → green)
Goal: click → clone → green checks in under 10 minutes.

- [ ] create a brand-new repo from this template (GitHub UI)
- [ ] clone it to a clean folder (no prior venv)
- [ ] run:
  - `pwsh .\scripts\setup_precommit.ps1`
  - `pwsh .\scripts\check.ps1 -Fast`
  - `pwsh .\scripts\doctor.ps1 -Fast`
- [ ] confirm CI goes green automatically on first push

Deliverable:
- [ ] verified student-zero path (no tribal knowledge required)

---

### 2) Re-verify encoding “disaster recovery” (Windows mojibake/BOM)
Goal: docs never stay broken; recovery is one command.

- [ ] intentionally introduce a known-bad encoding case in a scratch branch
  - e.g., add a file with wrong encoding / weird characters
- [ ] confirm:
  - `pwsh .\scripts\fix_docs_utf8.ps1` restores docs to normal
  - GET_HELP still points to the correct recovery steps
- [ ] confirm pre-commit hooks don’t re-break or fight the fix

Deliverable:
- [ ] “docs are readable again” recovery validated end-to-end

---

### 3) Line ending noise control (CRLF/LF)
Goal: stop churn in diffs across Windows/Linux.

- [ ] add/verify `.gitattributes` for:
  - `*.ps1` (CRLF okay)
  - `*.sh` (LF)
  - `*.py` (LF)
  - `*.md` (LF)
- [ ] verify on Windows that `git status` stays clean after edits
- [ ] verify in CI that formatting/linters don’t flip endings

Deliverable:
- [ ] no “why did 400 lines change?” commits

---

### 4) Pre-commit friction check (PATH + staging + auto-fixes)
Goal: students can run pre-commit without PATH weirdness or confusion.

- [ ] confirm `scripts/precommit.ps1` exists and works in a fresh clone:
  - runs venv-first: `.\.venv\Scripts\python.exe -m pre_commit run --all-files`
- [ ] confirm README + GET_HELP recommend:
  - `pwsh .\scripts\precommit.ps1`
- [ ] document the “auto-fix loop” briefly (run, then `git add -A`, rerun if needed)

Deliverable:
- [ ] zero “pre-commit not recognized” + predictable fix flow

---

### 5) Continue + Ollama CPU-only dial tone (the whole point)
Goal: Continue can reliably use local CPU models via Ollama.

- [ ] add/verify a single “AI is alive” script:
  - `scripts/ollama_smoke_test.ps1`
  - checks: CLI exists, server reachable, at least one model available
- [ ] verify Continue configuration is actually used by VS Code:
  - repo-local config present (`.continue/` if used)
  - rules/prompts referenced from `docs/continue/`
- [ ] verify a real workflow:
  - open a Python file
  - run a Continue prompt (“simplify function”, “add tests”, etc.)
  - apply patch
  - run `pwsh .\scripts\check.ps1 -Fast` and stay green

Deliverable:
- [ ] confirmed “CPU-only local assistant” works end-to-end

---

## Definition of Done (this repo as a template)
- [ ] Fresh repo passes the “10-minute green” ritual
- [ ] Encoding recovery verified (`fix_docs_utf8.ps1` works)
- [ ] Line ending noise controlled (`.gitattributes` verified)
- [ ] Pre-commit wrapper verified on a clean Windows machine
- [ ] Continue + Ollama CPU-only workflow verified (edit → tests pass → CI green)
