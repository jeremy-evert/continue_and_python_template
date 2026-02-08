# Continue + Ollama (Local) Setup

Goal: point Continue at local Ollama and get repeatable behavior via rules + prompts.

This repo uses two “modes” for assistant behavior:

- **Starter**: simpler, more explicit, student-friendly steps
- **Builder**: stricter, more professional expectations

---

## Prereqs

1) Install Ollama (local LLM server)
2) Pull at least one model:

```powershell
ollama list
ollama pull llama3.2:3b
````

3. Confirm Ollama is alive:

```powershell
curl http://127.0.0.1:11434/api/tags
```

---

## Continue: connect to Ollama

In Continue settings:

* Provider: **Ollama**
* Base URL: `http://127.0.0.1:11434`
* Model: use something small and reliable for dev workflows:

  * `llama3.2:3b` (good default)
  * `qwen2.5-coder:7b` (stronger code, heavier)

If Continue fails to see Ollama, check:

* firewall rules
* the port (11434)
* whether Ollama is running

---

## Repo rules (copy/paste)

Pick one ruleset and paste it into your Continue rules area:

* Starter rules: `docs/continue/rules/starter.md`
* Builder rules: `docs/continue/rules/builder.md`

---

## Repo prompts (copy/paste)

These are “no creativity required” prompts. Paste one into Continue chat or an
action prompt, and fill in the variables.

* Commit message: `docs/continue/prompts/commit_message.md`
* Refactor: extract function: `docs/continue/prompts/refactor_extract_function.md`
* Write tests: `docs/continue/prompts/write_tests.md`

---

## Recommended workflow

1. Make a small change
2. Run health check:

```powershell
pwsh .\scripts\check.ps1
```

3. Use prompts to:

* extract a function cleanly
* add tests
* write a calm commit message

---

## “Tools must run through the venv” tip (Windows)

When tools act weird, run them through the repo’s venv explicitly:

```powershell
.\.venv\Scripts\python.exe -m pre_commit run --all-files
```

This avoids calling a global Python that doesn’t have the right packages.

````

---

## `docs/continue/rules/starter.md`

```md
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
````

---

## `docs/continue/rules/builder.md`

```md
# Continue Rules: Builder

You are acting like a disciplined pair programmer in a clean-code template repo.

## Principles
- Small, shippable increments.
- Tests are part of the change, not an optional garnish.
- Keep core pure. Push I/O to adapters.
- Prefer clarity over cleverness.

## Architecture boundaries (strict)
- `src/python_template/core/` must not import:
  - `requests`
  - `subprocess`
  - `sqlite3`
- If a feature needs those, create an adapter and inject it.

## Code quality
- Functions should be short and single-purpose.
- Avoid deep nesting: extract helpers.
- Prefer explicit control flow over dense comprehensions when teaching clarity.
- Use type hints where they improve understanding.

## Tooling rules
- Format: `ruff format .`
- Lint: `ruff check .`
- Tests: `pytest -q`
- Encourage running `pwsh .\scripts\check.ps1` before commits.

## Response format
When making changes:
1) Say what you’ll change (1–3 bullets)
2) Show the code diff or replacement
3) Provide verification commands
```

---

## `docs/continue/prompts/commit_message.md`

```md
# Prompt: Commit Message (calm + consistent)

You are helping write a Git commit message.

Inputs I will paste:
1) `git status`
2) `git diff --stat`
3) (optional) `git diff`

Rules:
- Use imperative mood (e.g., “Add…”, “Fix…”, “Refactor…”)
- Keep subject <= 72 characters
- If needed, add a short body with why (not how), wrapped at ~72 chars
- Avoid jokes, profanity, or vague messages (“stuff”, “updates”)

Output exactly:
- `subject:` <one line>
- `body:` <either empty or 2–6 lines>
- `files_touched:` <short list inferred from diff/stat>

Now wait for my pasted inputs.
```

---

## `docs/continue/prompts/refactor_extract_function.md`

```md
# Prompt: Refactor (extract function)

Goal: extract a function cleanly without changing behavior.

I will paste:
- the current code block
- what I want extracted (description)
- target file path

Constraints:
- No behavior changes unless explicitly requested
- Keep function names snake_case
- Keep functions small and readable
- If the code belongs in core vs adapters, follow repo boundaries
- Update or add tests if behavior is touched

Output:
1) Proposed function signature
2) Updated code (full replacement for the touched section)
3) Any tests to add/update
4) Commands to verify (prefer `pwsh .\scripts\check.ps1`)
```

---

## `docs/continue/prompts/write_tests.md`

```md
# Prompt: Write tests (pytest)

Goal: create or improve tests for the given module/function.

I will paste:
- the target code (or file)
- what the code is supposed to do
- any edge cases I care about

Constraints:
- Use pytest
- Keep tests deterministic (no random without seeding)
- Prefer small, focused tests
- Use Arrange / Act / Assert comments if it helps teaching clarity

Output:
1) Test plan (3–8 bullets)
2) Test file content (full file)
3) Commands to run tests (`pytest -q`, or `pwsh .\scripts\check.ps1`)
```

---
