---
name: react-ux-review
description: Read-only UX/UI workflow critic. Compares a target React page against canonical Polished baseline pages on workflow dimensions (dirty tracking, validation feedback, error recovery, keyboard shortcuts, loading states, unsaved-guard coverage) — not just visual tokens. Use for "review ux on page X", "best practice check for page X", "audit ux flow", or as a mandatory pre-step before `react-revamp` / `web-implement` redesign. Produces a workflow divergence table + severity rating + remediation plan; never edits.
license: MIT
user-invocable: true
metadata:
  version: "1.0.0"
  derived_from: project-internal (companion to react-revamp + react-audit)
  stack: framework-agnostic procedure; examples target React 19 codebases with form-heavy pages
  scope: Read-only workflow critique — single page or small page cluster
---

# React UX Workflow Review

A read-only critic that compares a target page's **user-facing workflow** against canonical Polished baselines in the same codebase. Where `react-audit` focuses on structure/visual tokens and `react-revamp` proposes new flows, this skill answers a narrower question: **does the existing workflow follow the patterns the team's best pages already prove?**

Output is a divergence table — each row a workflow pattern, marked High/Med/Low severity with a remediation hint. **Stops before any edit.** The invoking agent (or user) decides what to apply.

---

## Step 1 — Gather Inputs (MANDATORY)

Do not `Read`, `Glob`, `Grep` until inputs are answered. Use `AskUserQuestion` to collect them in one call.

Required:

1. **Target page path** — page folder + entry file (e.g. `src/features/leave/pages/LeaveListPage/index.tsx`). If only a name given, resolve to a concrete path and confirm.
2. **Baseline page paths** — 1–3 Polished baseline pages **in the same role** as the target (list / detail / config / form). The baselines drive the dimension expectations. Default suggestions if user doesn't know:
   - List pages → `src/features/payroll/pages/PayrollListPage/index.tsx`, `src/features/organization/pages/DepartmentListPage/index.tsx`
   - Detail/Form pages → `src/features/employee/pages/EmployeeDetailPage/index.tsx`, `src/features/payroll/pages/PayrollDetailPage/index.tsx`
3. **Output language** — `English` or `Thai`. Default to English.

Optional (ask only if scope is ambiguous):

4. **Specific dimensions to focus on** — e.g. "only form-related" or "skip a11y". Otherwise run all dimensions.

Stop and wait until inputs are answered.

---

## Step 2 — Discovery

Once inputs confirmed:

- `Read` the target page **in full** plus the components it directly composes (form sections, dialogs it owns, page-level skeleton).
- `Read` each baseline page **in full** plus its shell/wrapper component(s) (e.g. `EmployeeFormShell`, `PayrollDetailHeader`).
- Build a quick mental model: what role each page plays, what user does on it, what data drives it.
- Identify shared workflow primitives in the codebase by `Grep`:
  - `useUnsavedChangesGuard`, `useKeyboardShortcuts`, `useTabDirtyState` (or equivalent)
  - `<LoadingButton>`, `<LoadingOverlay>`, `<ErrorState>`, `<EmptyState>`
  - `<Alert error>` + `animate-shake` (or codebase equivalent)
  - `methods.setFocus`, `methods.trigger`, `confirmLeave()`
- Note any helper utility files the baselines use (e.g. `*FormValidation.ts`, `*TabFields.ts`, `getTabForField`).

This step is calibration only — no findings yet.

---

## Step 3 — Workflow Critique

Critique the target against the baselines on **9 workflow dimensions**. For each dimension, record:

- **Baseline pattern** — what the canonical page does (1 line + `file:line` citation)
- **Target state** — what the target does (or doesn't)
- **Gap** — the specific delta
- **Severity** — High / Med / Low (criteria below)
- **Remediation hint** — 1 line, names the helper/primitive to copy

### Severity criteria

- **High** — Silent data loss · ambiguous save scope · validation dead-ends · keyboard nav broken
- **Med** — Inconsistent feedback · missing confirmation on destructive · loading state gaps · cancel semantics differ
- **Low** — Cosmetic regression · keyboard shortcut missing · testid missing · code style divergence

### Dimensions

1. **Form save scope** — single form vs multi-form, page-level vs per-section save. Is the scope predictable to the user?
2. **Dirty tracking** — page-level `isDirty` only, or per-section / per-tab? Does the Save button gate on the right scope?
3. **Validation feedback on submit-with-errors** — silent fail · banner only · banner + auto-switch-to-error-tab + focus first error field. Compare to baseline's choice.
4. **Cancel / Discard semantics** — silent `reset()` · `confirmLeave()` modal · navigate-away guard. Does this match the baseline's pattern for the same role?
5. **Loading states** — `<LoadingButton>` for in-place async · `<LoadingOverlay>` for full-form lock during submit · skeleton mirror on initial fetch. Coverage gaps?
6. **Empty / Error states** — `<EmptyState>` on no-data · `<ErrorState>` with `onRetry` on fetch fail · skeleton during refetch. All three covered?
7. **Keyboard shortcuts** — `useKeyboardShortcuts({ onSave, onCancel })` wired? Cmd/Ctrl+S works? Esc to cancel?
8. **Unsaved-changes guard coverage** — `useUnsavedChangesGuard` on form pages — does it cover refresh/page-nav AND tab-switch-within-page when state isn't bound to URL?
9. **Side-effect commit timing** — uploads / sub-resource saves that commit before main form `Save` — does the user have a way to know which actions are atomic vs eager? Are eager commits clearly communicated?

If user opted to focus on a subset (Step 1.4), run only those.

---

## Step 4 — Output Template

```
# UX Review: <target page path>

## Inputs
- Target: <path>
- Baselines: <paths>
- Dimensions: <all / focused list>

## Discovery
- Target role: <list / detail / config / form>
- Target workflow summary: <1 sentence>
- Baseline workflow summary: <1 sentence per baseline>

## Workflow divergence table

| # | Dimension | Baseline (canonical) | Target (current) | Gap | Severity | Remediation hint |
|---|---|---|---|---|---|---|
| 1 | Form save scope | <…> | <…> | <…> | High/Med/Low | <…> |
| 2 | Dirty tracking | <…> | <…> | <…> | … | <…> |
| … | … | … | … | … | … | … |

## What target does well (alignment confirmed)
- <dimension> — matches baseline at <file:line>
- ...

## Cross-cutting concerns (not tied to one dimension)
- <pattern that spans multiple dimensions, e.g. "tab 4 is an island that breaks all multi-tab patterns at once">

## Severity rollup
- High: <count>
- Med: <count>
- Low: <count>

---

## Suggested next step
- `<count_high> High` findings — recommend addressing before any feature work on this page
- `<count_med> Med` findings — recommend bundling into the next polish pass
- `<count_low> Low` findings — defer or batch

(Or, if zero findings: "Target page is aligned with baselines on all checked dimensions.")

Status: read-only UX review complete. Waiting for "apply" before any edit.
```

---

## Stop Conditions (READ-ONLY discipline)

This skill is **read-only by design**. After the report:

- Do not run `Edit`, `Write`, `NotebookEdit`, or any modification.
- Do not stage / commit / push.
- End with: `Status: read-only UX review complete. Waiting for "apply" before any edit.`

The invoking agent (or user) says "apply" / "go ahead" / "fix it" / "ลุย" to leave review mode. Even then, the agent — not this skill — performs the edits.

---

## When to Reference Other Skills

While critiquing, if you encounter:

- **Structural divergence** (folder layout, file naming, sub-domain split) → recommend `react-audit` single-feature mode for a deeper structural pass.
- **Visual primitive drift** (same primitive looks different across pages) → recommend `react-audit` visual-consistency mode on the specific primitive.
- **The target's flow is fundamentally wrong, not just gappy** (e.g. modal-on-modal, no clear primary action, user can't recover) → recommend `react-revamp` for a full flow proposal instead of patching.
- **Performance smells** (sequential awaits, missing memo) → flag in remediation hint, recommend `react-perf`.

Surface as recommendations in the report, not as additional review work.

---

## Notes for the invoking agent

- This skill **does not** decide whether to apply. The invoking agent (`web-implement`) reads the divergence table and writes the actual Plan, which the user then approves with `ลุย`.
- When invoked from `web-implement` in a `redesign` / `revamp` flow, this skill runs **before** `react-revamp` — workflow gaps shape the flow proposal, not the other way around.
- The 9 dimensions are a **starter list**. As the codebase grows new shared patterns, this skill should be updated to include them. Treat the dimensions as extensible, not exhaustive.
