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
