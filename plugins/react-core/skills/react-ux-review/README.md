# react-ux-review — Maintenance & Provenance

A read-only UX/UI **workflow critic**. Compares a target page against canonical Polished baseline pages on workflow dimensions — not just visual tokens or folder structure.

## Why this skill exists

`react-audit` checks structure (folder layout, file naming, primitive choice) and visuals (tokens, spacing, colors). `react-revamp` proposes a brand-new flow. Neither answers the narrower question:

> "The target page renders. It uses the right primitives. The tokens are correct. But does its **user-facing workflow** match what our best pages already prove?"

`react-ux-review` answers that question. The output is a divergence table — each row a workflow pattern with severity rating.

## When to invoke

| Situation | Use this skill |
|---|---|
| User says "review ux on page X" / "best practice check" / "audit ux flow" | Direct call |
| `web-implement` is starting a `redesign` / `revamp` and the page already exists | Mandatory pre-step (workflow gaps shape the revamp proposal) |
| `web-pre-commit` touches a Polished page and the diff is form-heavy | Recommended workflow regression check |

When **not** to use:
- Brand-new page that has no baseline yet → use `react-revamp` to propose a flow
- Pure visual cleanup with no workflow change → use `react-audit` visual-consistency mode
- Cross-feature consistency audit → use `react-audit` multi-feature mode

## Stack assumptions

Procedure is **framework-agnostic** but examples target React 19 + TypeScript + Tailwind. The 9 workflow dimensions reference patterns common in form-heavy React codebases:

- Dirty tracking via `react-hook-form` `dirtyFields`
- Validation feedback via `methods.trigger` + `setFocus`
- Unsaved-changes guard via a `useUnsavedChangesGuard`-style hook
- Loading states via `<LoadingButton>` + `<LoadingOverlay>`
- Empty/Error states via `<EmptyState>` + `<ErrorState>`
- Keyboard shortcuts via a `useKeyboardShortcuts`-style hook

If the project uses different primitives (e.g. Formik, custom hooks), the dimensions still apply — just substitute the equivalent helper names when reading the report.

## Dimensions list (current)

1. Form save scope
2. Dirty tracking
3. Validation feedback on submit-with-errors
4. Cancel / Discard semantics
5. Loading states
6. Empty / Error states
7. Keyboard shortcuts
8. Unsaved-changes guard coverage
9. Side-effect commit timing

This list is **extensible**. As the codebase grows new shared workflow patterns, add a dimension here.

## Relationship to other skills

- **`react-audit`** — complementary. `react-audit` is the *structure/visual* lens; `react-ux-review` is the *workflow* lens. Run both on a redesign target for a complete picture.
- **`react-revamp`** — `react-ux-review` runs **before** `react-revamp` in a redesign flow. Workflow gaps inform the revamp's "Best Practices Applied" section.
- **`react-perf` / `react-composition`** — Out of scope here. Surface as remediation hints when relevant; don't duplicate their checks.

## Read-only discipline

This skill **never** edits. The output is a critique + remediation hints. The invoking agent (`web-implement` typically) writes the actual Plan from the report and waits for the user's `เริ่ม` / `start` before any edit.
