---
name: scrutinize
description: Intent-validation review for a diff (or PR) — does the change actually do what the original task asked for, no more, no less? Compares stated intent against the actual diff and surfaces scope creep, missed requirements, and silent assumptions. Complements `react-audit` (which checks code quality) — scrutinize checks alignment to intent. Use after pre-commit passes but before merge. Triggers - "scrutinize this", "does this diff match the task", "second opinion on this PR", "intent check", "scope creep check".
license: MIT
user-invocable: true
metadata:
  version: "0.1.0"
  type: gate
  status: experimental
  stack: any (language-agnostic; React is just where the agents using it live)
  scope: read-only — produces a verdict + bullets, no edits
---

# React Scrutinize

A second-opinion review with one job: **does the diff do what the task asked, and only that?**

Code-quality reviews (lint, `react-audit`, `react-perf`) catch *bad* code. They don't catch:

- A diff that solves a different problem than the one asked for.
- A diff that solves the right problem **plus three extras** the user didn't sign off on.
- A diff that *says* it solves the problem but actually leaves the core requirement unaddressed.
- A diff that silently makes assumptions the user wouldn't approve.

This skill is the intent gate. Run it after `*-pre-commit` passes and before the diff merges.

## When to use

- After `*-pre-commit` greenlights a diff and before you click "merge."
- When a PR feels "off" but you can't articulate why — scrutinize forces the comparison.
- When the agent that produced the diff feels eager — every chunk applied, every check green, but the diff is twice the size you expected.
- When you're reviewing a teammate's PR and want a structured way to ask "did this stay in scope?"

Skip this skill for:

- Trivial PRs (typo fixes, dead-import removal) — there is no intent to scrutinize.
- Code-quality concerns alone (use `react-audit` / `react-perf` / `react-composition`).
- Tests-only diffs whose intent is "raise coverage on X" — scope is already narrow.

## Step 1 — Gather inputs (MANDATORY before any work)

Do not run `git diff` / `Glob` / `Read` until you have these two inputs collected via `AskUserQuestion`:

1. **Stated intent** — what the original task asked for. Paste the user's request verbatim, or the issue/ticket title + description.
2. **Diff scope** — confirm what to scrutinize: staged + unstaged, last commit, a branch range, a PR. Default: staged + unstaged.

If either is missing or ambiguous, stop and ask. **Do not infer intent from the diff itself** — that's circular.

## Step 2 — Read the diff in full

- `git diff` (per scope confirmed in Step 1).
- `Read` every file the diff touches **in full**, not just the hunks. The intent might be violated by what the diff *didn't* change in a file it modified.
- For files the diff *creates*, read each in full.

This is the only step that reads code; the rest is comparison.

## Step 3 — Build the alignment matrix

Produce this table. One row per "requirement implied by the stated intent." Mark each.

```
| # | Requirement (from intent)                         | Met? | Evidence (file:line)                  |
|---|---------------------------------------------------|------|---------------------------------------|
| 1 | Toggle persists across reload                     | ✅   | hooks/useTheme.ts:24 (localStorage)   |
| 2 | Honors system preference when no saved value      | ⚠️    | hooks/useTheme.ts:30 — hardcoded 'light' |
| 3 | Accessible via keyboard (Esc closes menu)         | ❌   | not addressed                          |
```

Rules:

- **List every requirement, even if obviously met.** Forcing the enumeration is how missed requirements surface.
- **`✅` requires a `file:line` citation.** "Looks done" without evidence is not done.
- **`⚠️` means "addressed but with a caveat"** — typically a silent assumption (hardcoded value, missing edge case, comment-promised-but-not-implemented).
- **`❌` means "not addressed."** Adjacent code is not evidence.

## Step 4 — Build the scope-creep matrix

Reverse the perspective. One row per "change in the diff that doesn't trace back to the stated intent."

```
| # | Change in diff                                    | Justified? | Notes                              |
|---|---------------------------------------------------|------------|------------------------------------|
| 1 | Renamed `<Header>` to `<TopBar>` (12 files)       | ❌         | Not in intent; unrelated refactor  |
| 2 | Added `<ErrorBoundary>` wrapper to RouteShell     | ⚠️         | Adjacent improvement; ask user     |
| 3 | Replaced `useState` with `useReducer` in Theme    | ✅         | Required by req #1 (persistence)   |
```

Rules:

- **List every meaningful change.** Whitespace, lint-fix-style touches can be aggregated as one row.
- **`✅` means "required to satisfy a row from Step 3's matrix."** Cite which row.
- **`⚠️` means "adjacent improvement that benefits the diff but wasn't asked for."** These are scope creep — flag, let the user decide.
- **`❌` means "no traceable connection to intent."** Either revert or split into a separate PR.

## Step 5 — Verdict

Synthesize the two matrices into a one-line verdict + reasoning:

```
Verdict: <ALIGNED | SCOPE_CREEP | MISSED_REQUIREMENT | OFF_TARGET>

- ALIGNED: every requirement met, every change traces back to a requirement.
- SCOPE_CREEP: every requirement met, BUT diff includes ❌ changes — split or revert the extras.
- MISSED_REQUIREMENT: at least one ❌ in the alignment matrix — the diff is incomplete or wrong.
- OFF_TARGET: most rows of either matrix don't line up — the diff solves a different problem.
```

The verdict is the deliverable. Don't soften it — the user asked for a second opinion.

## Step 6 — Stop conditions

This skill ends with the report. **Do not edit code, do not commit, do not "address the findings."** Apply happens elsewhere — the user reads the report, decides, and dispatches the appropriate agent (`*-implement` to fix missed requirements, `*-polish` to extract scope creep into its own PR, etc.).

## Operating rules

- **Cite or it didn't happen** — every `✅` and `❌` claim references `file:line` or "not addressed."
- **Read in full** — never anchor on hunks alone; the diff's neighborhood is part of the evidence.
- **Don't infer intent from the diff** — the stated intent is the contract; the diff is what's measured against it.
- **The verdict is binary clear** — no "mostly aligned." If there's a single ❌ in alignment, it's MISSED_REQUIREMENT. If only scope-creep ❌, it's SCOPE_CREEP.
- **Silent assumptions are ⚠️, not ✅** — hardcoded values, magic numbers, missing edge cases that the requirement *could* have demanded → caveat, not pass.
- **Don't recommend code** — that's `*-implement`'s job. Recommend *what's wrong*, not *how to fix it*.

## Report format

```
# Scrutinize: <1-line task summary>

## Stated intent
<verbatim quote of the user's request, or paraphrase if too long>

## Alignment matrix
<table from Step 3>

## Scope-creep matrix
<table from Step 4>

## Verdict
<ALIGNED | SCOPE_CREEP | MISSED_REQUIREMENT | OFF_TARGET>

## Reasoning
<3-5 bullets — the specific rows that drove the verdict>

## Recommended next action
- If ALIGNED → "Ready to merge."
- If SCOPE_CREEP → "Split rows X, Y of the creep matrix into a separate PR before merging."
- If MISSED_REQUIREMENT → "Send back to <agent> with row #N as the gap."
- If OFF_TARGET → "Stop. Reconcile intent with the user before any further edits."
```

## You DON'T

- Edit any file — read-only.
- Run linters / build / tests — those are `*-pre-commit`'s scope.
- Re-do the code review — `react-audit` already did that, and it's a different concern.
- Infer requirements from the diff — that's the trap this skill exists to avoid.
- Soften the verdict to be polite — bluntness is the value.

## Edge cases

- **Intent is too vague to enumerate** ("clean up X") → stop in Step 1, ask for concrete requirements before reading the diff.
- **Diff is empty** → return "no diff to scrutinize."
- **Stated intent matches the diff but the user is unhappy** → the bug is in the intent capture, not the diff. Replay the original task with the user; this skill doesn't repair upstream miscommunication.
- **Diff is huge (> 30 files)** → produce a summary table by feature area, not per file. Recommend splitting before deeper scrutiny.
