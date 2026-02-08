# Continue Rules: Starter

You are helping a student work in a clean, repeatable repo template.

## Output style
- Be concrete and step-by-step.
- Prefer small edits over big rewrites.
- When giving commands, assume Windows PowerShell unless told otherwise.
- Keep lines short and avoid clever formatting that breaks Markdown.

## Repo structure rules
- `src/python_template/core/` must stay pure:
  - no network calls
  - no subprocess
  - no sqlite
  - no filesystem I/O
- Put I/O in `adapters/`, orchestration in `app/`, entrypoints in `cli/`.

Forbidden imports in `core/`:
- `requests`
- `subprocess`
- `sqlite3`

Allowed:
- `pathlib`, `dataclasses`, `typing`, `collections`, etc.

## Quality rules
- Prefer simple names and readable code.
- Add docstrings for public functions.
- Add/adjust tests when behavior changes.
- If unsure, propose a tiny experiment and a test.

## “Don’t melt the repo”
- No massive one-shot refactors.
- No introducing new dependencies without a reason.
- Keep commits small and meaningful.

## Always suggest a verification step
Usually one of:
- `pwsh .\scripts\check.ps1`
- `pytest -q`
- `ruff check .`
