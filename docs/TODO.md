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

## ✅ Previous Items (short list)

- [x] fresh repo ritual verified (template UI → clean clone → scripts → CI green)
- [x] pre-commit verified (venv-first + wrapper)
  - [x] `.\.venv\Scripts\python.exe -m pre_commit run --all-files`
  - [x] `python -m pre_commit run --all-files`
  - [x] `pwsh .\scripts\precommit.ps1`
- [x] Ollama dial tone verified (check.ps1 -WithOllama works; default + explicit model)
  - [x] `pwsh .\scripts\check.ps1 -WithOllama`
  - [x] `pwsh .\scripts\check.ps1 -WithOllama -Model "llama3.2:3b"`
- [x] Continue config + Ollama models verified via pwsh .\scripts\continue_pulse.ps1 (and -Strict)
- [x] encoding recovery verified (UTF-8/BOM): injected BOM + fixed via `pwsh .\scripts\fix_docs_utf8.ps1`
- [x] post-recovery toolchain verified: pre-commit stays green after recovery
- [x] GET_HELP includes encoding recovery steps + detectors
  - Note: scan may match intentional examples (detector ≠ broken docs)

## 🧱 Next (keep this list small)

### 1) Continue + Ollama CPU-only dial tone (the whole point)
Goal: Continue can reliably use local CPU models via Ollama.


- [x] In VS Code, confirm Continue model labels match config.yaml model names
  - config is loaded from ~/.continue/config.yaml (verified via model labels + pulse script)
  - rules/prompts referenced from `docs/continue/`
- [ ] In VS Code, set Embed model to “Embeddings: Nomic Embed Text” (Ollama) instead of Transformers.js
- [ ] Continue Apply Smoke Test
  - In VS Code, open Continue chat and confirm model = Chat/Edit/Apply: Llama 3.2 3B (CPU-stable)
  - Prompt to paste:
    * Create src/python_template/core/fizzbuzz.py with fizzbuzz(n: int) -> list[str] returning the classic 1..n list (Fizz, Buzz, FizzBuzz). Add tests/test_fizzbuzz.py covering n=15. Make it ruff/format clean and pytest green.
  - Hit Apply (so we test the apply pipeline)
  - Run: `pwsh .\scripts\check.ps1 -Fast`
  - Commit.
- [ ] verify a real workflow:
  - open a Python file
  - run a Continue prompt (“simplify function”, “add tests”, etc.)
  - apply patch
  - run `pwsh .\scripts\check.ps1 -Fast` and stay green


Deliverable:
- [ ] confirmed “CPU-only local assistant” works end-to-end

---
### 2) Pre-commit friction check (PATH + staging + auto-fixes)
Goal: students can run pre-commit without PATH weirdness or confusion.

- [x] confirm `scripts/precommit.ps1` exists and works in a fresh clone:
  - runs venv-first: `.\.venv\Scripts\python.exe -m pre_commit run --all-files`
- [x] confirm README + GET_HELP recommend:
  - `pwsh .\scripts\precommit.ps1`
- [ ] document the “auto-fix loop” briefly (run, then `git add -A`, rerun if needed)

Deliverable:
- [ ] zero “pre-commit not recognized” + predictable fix flow

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


### 4) Deliver the template
- [ ] confirm this repo is enabled as a GitHub Template repository (Settings → Template repository)

### 5) Test the template with a project
- [ ] create a new repo from the template
- [ ] build one tiny tool/function with tests
- [ ] confirm CI stays green
- [ ] confirm student-zero UX is still under 10 minutes

## Definition of Done (this repo as a template)
- [x] Fresh repo passes the “10-minute green” ritual
- [x] Encoding recovery verified (`fix_docs_utf8.ps1` works)
- [ ] Line ending noise controlled (`.gitattributes` verified)
- [x] Pre-commit wrapper verified on a clean Windows machine
- [x] Continue config + Ollama models verified (scripts/continue_pulse.ps1 -Strict)
- [ ] Continue + Ollama CPU-only workflow verified (edit → tests pass → CI green)
