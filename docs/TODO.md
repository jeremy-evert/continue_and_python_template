# Template Repository TODO (Ranked)

**Policy:** keep this file small (next actions only).
Append-only: don’t rewrite big sections, just add items.
If it gets long, move narrative/detail to `docs/TODO_HISTORY.md`.


This TODO is the single source of truth for what we do next.
If it gets long, we move detail to `docs/TODO_HISTORY.md`.

We optimize for:
- high ROI
- repeatable workflows
- student-friendly setup
- shippable increments
- minimum molasses

## ✅ Done (short list)
- repo scaffold + baseline tooling (ruff/pytest)
- pre-commit installed + working
- check.ps1 + doctor.ps1 working
- CI fast-check on push/PR
- docs: template usage + help + encoding recovery

---



### 1) `scripts/precommit.ps1` wrapper (venv-first)
Goal: students can run pre-commit even if PATH is weird.

- [X] add `scripts/precommit.ps1` that runs:
  - `.\.venv\Scripts\python.exe -m pre_commit run --all-files`
- [X] update README + GET_HELP to recommend:
  - `pwsh .\scripts\precommit.ps1`

Deliverable:
- [x] zero “pre-commit not recognized” confusion

---
## 🧱 Next (keep this list small)

### 2) Confirm template toggle + run the fresh-repo ritual
Goal: click → clone → green checks in under 10 minutes.

- [x] confirm “Template repository” is enabled on GitHub
- [ ] create a new repo from template and run:
  - `pwsh .\scripts\setup_precommit.ps1`
  - `pwsh .\scripts\check.ps1 -Fast`
  - `pwsh .\scripts\doctor.ps1 -Fast`
- [X] confirm CI goes green automatically

Deliverable:
- [x] verified student-zero path

---

## Definition of Done
- [x] `setup_precommit.ps1`, `check.ps1`, `doctor.ps1` all work
- [x] CI runs `check.ps1 -Fast`
- [x] repo confirmed as GitHub Template
- [x] fresh repo passes the “10-minute green” ritual
