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
