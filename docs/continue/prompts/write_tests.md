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
