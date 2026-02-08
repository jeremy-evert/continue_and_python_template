# Development Modes and Expectations

This repo supports multiple development modes.
Each mode represents **different expectations**, not different levels of respect.

Choose the mode that matches where you are **right now**.

---

## Overview

| Area                | Starter Mode                  | Builder Mode                  |
|---------------------|-------------------------------|-------------------------------|
| Primary goal        | Learn concepts                | Build reliable software       |
| Tests               | Encouraged, not exhaustive    | Required and meaningful       |
| Code structure      | Simple > perfect              | Clear boundaries enforced     |
| Ruff / formatting   | Auto-fix is fine              | Clean before commit           |
| Architecture rules  | Guidance only                 | Enforced                      |
| LLM usage           | Allowed with disclosure       | Allowed with responsibility   |
| Commit quality      | Descriptive                   | Professional, consistent      |

Starter Mode and Builder Mode describe *expectations*, not skill level or grades.


---

## Starter Mode (Learning-First)

**Who this is for**
- Intro programming courses
- First exposure to tooling
- Students still building mental models

**What matters most**
- Code runs
- Concepts are visible
- You can explain what you wrote

**What is optional**
- Perfect naming
- Full test coverage
- Ideal architecture

**LLM usage**
- Allowed
- You must be able to explain the result
- Treat the LLM as a tutor, not a ghostwriter
- If asked, you should be able to describe what you prompted and what you changed.

**Failure is allowed**
- Broken tests are part of learning
- Formatting mistakes are normal
- The workflow exists to *teach*, not punish

---

## Builder Mode (Quality and Boundaries)

**Who this is for**
- Upper-division courses
- Research, tooling, automation
- Anything you might ship or reuse

**What matters most**
- Tests reflect intent
- Boundaries are respected (`core/` stays pure)
- Changes are reviewable and reasoned

**What is required**
- Tests for non-trivial logic
- Passing `pwsh scripts/check.ps1` before commits
- Clear commit messages

**LLM usage**
- Allowed
- You own the result
- You review, test, and refine the output

**Failure is informative**
- Broken checks tell you *where to improve*
- The tooling is your early warning system

---

## Switching Modes

You are allowed to switch modes.
Just be explicit about which one you are in.

---

## The Point

Modes exist to:
- reduce confusion
- set clear expectations
- help you grow without guessing what matters

They are not about control.
They are about focus.
