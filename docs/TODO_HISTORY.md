# TODO History (Curated Narrative)

This file preserves the story of how `docs/TODO.md` evolved.
Rule: `docs/TODO.md` stays short (next actions only). This file holds the longer narrative and “why”.



## transfer from todo.md at 2026 02 08 14:29
- repo scaffold + baseline tooling (ruff/pytest)
- [x] fresh repo ritual verified (template UI → clean clone → scripts → CI green)
- [x] setup_precommit.ps1 verified (hooks install + pre-commit first run)
- pre-commit installed + working
- `check.ps1` + `doctor.ps1` working
- CI fast-check on push/PR
- docs: template usage + help + encoding recovery
- Continue docs + starter rules/prompts present (repo-local docs)

---
## other
  - [x]  run pwsh .\scripts\check.ps1 -WithOllama -Model "llama3.2:3b" once to prove the wiring works
  - [x] add/verify a single “AI is alive” script:
  - `scripts/ollama_dial_tone.ps1`
  - checks: CLI exists, server reachable, at least one model available

---

### 1) Re-verify “fresh repo ritual” (template clone → green)
Goal: click → clone → green checks in under 10 minutes.

- [x] create a brand-new repo from this template (GitHub UI)
- [x] clone it to a clean folder (no prior venv)
- [x] run:
  - `pwsh .\scripts\setup_precommit.ps1`
  - `pwsh .\scripts\check.ps1 -Fast`
  - `pwsh .\scripts\doctor.ps1 -Fast`
- [x] confirm CI goes green automatically on first push

Deliverable:
- [x] verified student-zero path (no tribal knowledge required)


## Era 0: Bootstrapping (scaffold → hooks → check/doctor → CI)
- Repo scaffold, ruff/pytest, pre-commit, check.ps1, doctor.ps1, CI fast-check.

## Era 1: Encoding + reliability hardening
- UTF-8/BOM cleanup, docs recovery script, help workflow improvements.

## Era 2: TODO creep and the fix
- The TODO grew into a living document.
- Decision: keep TODO small + append-only, move narrative here.



# TODO History (Curated)

This file is the curated narrative of how `docs/TODO.md` evolved.
Git retains the full audit trail (`git log --follow -- docs/TODO.md`).
This document keeps the *why* without forcing anyone to read a 4-mile scroll.

## Era 1: Bootstrap the repo (scaffold → tooling → “shippable”)
**Motivation:** students need a repeatable setup with low judgment fatigue.

Key outcomes:
- Repo skeleton established (`src/`, `tests/`, `docs/`, `tools/`, etc.)
- Python baseline: `pyproject.toml`, ruff, pytest, smoke test
- Pre-commit installed with doc-safe hooks
- “One command smoke ritual” added (`check.ps1`)

## Era 2: Anti-molasses instrumentation (Repo Doctor)
**Motivation:** the repo should tell you where to poke.

Key outcomes:
- `tools/repo_doctor.py` created to generate `reports/project_health.csv`
- `scripts/doctor.ps1` wrapper added with `-Fast` and `-Verbose`

## Era 3: CI makes it permanent
**Motivation:** keep it shippable even when nobody is watching.

Key outcomes:
- GitHub Actions workflow runs `pwsh .\scripts\check.ps1 -Fast` on push/PR
- CI green became a baseline requirement

## Era 4: Encoding incidents (UTF-8 / BOM / mojibake)
**Motivation:** Windows + terminals + markdown can corrupt docs visually and emotionally.

Key outcomes:
- `scripts/fix_docs_utf8.ps1` introduced as a one-command recovery
- GET_HELP gained canonical checks for mojibake + BOM detection
- Docs were normalized and protected via hooks

## Era 5: Local AI plumbing (Continue + Ollama)
**Motivation:** make LLM assistance repeatable.

Key outcomes:
- Continue docs + starter/builder rules + prompts added
- Ollama dial-tone script added for “is AI alive?” checks

## Era 6: Friction lessons (kept here, not in TODO)
These came from real workflow pain and should stay archived unless reactivated:
- Pre-commit PATH issues → wrapper script idea (`scripts/precommit.ps1`)
- Line ending noise (CRLF/LF) → `.gitattributes` idea
- Patch staging + pre-commit auto-fix friction → recommended commit flow notes

## Retired / Merged Items
- Repeated “help hygiene wiring” items merged into GET_HELP + README
- Encoding cleanups moved from TODO into scripts + hooks + documentation
- Large “Done” sections removed from TODO to keep it actionable

## Rule going forward
- `docs/TODO.md` stays short: “what we do next”
- When something is completed, we update the Done short list and (if needed) add a note here.
- We do not use LLMs to rewrite TODO wholesale; only append or mark items done.
