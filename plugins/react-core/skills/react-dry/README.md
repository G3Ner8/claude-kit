# react-dry — Maintenance & Provenance

A read-only audit skill for cross-component CSS / style / class standardization. Replaces the legacy `unify` agent. Findings come back as a **comparison table for discussion** before any detailed planning.

## Why "table first, then discuss"

Component-usage audits routinely surface 20–60 findings across a codebase. Producing a complete execution plan up front wastes both sides: the user reads through plan items they may not agree with, and you spend tokens specifying fixes for findings the user will skip.

The legacy `unify` agent solved this by stopping after the findings table. This skill keeps that discipline:

1. Audit → findings table
2. Stop
3. User picks which findings to address
4. Then plan
5. Then edit

The "discuss after table" step compresses the work; the user disambiguates priorities before specifications are written.

## Stack assumptions

Procedure is **framework-agnostic**. Examples in the skill body use React 19 + Tailwind because that's the most common stack, but the audit categories apply to any component-based UI codebase with a design-token system.

Specifically the skill assumes:

- One or more reusable UI components used across the codebase
- A design-token system (Tailwind, CSS variables, theme object, etc.)
- The tokens are the standard against which divergence is measured

If no token system exists, the audit still runs — findings just point at "raw hex / raw px values" without a "use token X" recommendation. The user can decide if they want to introduce tokens first.

## Inputs

The skill mandates `AskUserQuestion` up front to collect:

- Components to audit (1+, more is better)
- Codebase root for usage search
- Design tokens location
- Output language (EN/TH — asked when ≥ 2 components or large codebase)

## Output

**Just the findings table** — no detailed plan. The table has columns:

| Component | Concern | Variants seen | Files (sample) | Recommendation | Severity |

Plus a "Cross-component themes" section for pattern-level issues that span multiple components.

After the table, the skill ends with `Status: read-only audit complete. Findings ready for discussion.`

## Read-only enforcement

Spelled out in the skill body. The skill can `Read`, `Glob`, `Grep`, `Bash` (query) — never `Edit`, `Write`, `NotebookEdit`. The detailed execution plan and the edits are separate steps after user discussion.

## Refreshing / updating

Project-internal (no upstream). To update:

1. Edit `SKILL.md` directly.
2. Bump `metadata.version` when behavior changes meaningfully.
3. Note the change in a top-level changelog if the repo has one.

## Related skills in this kit

- `react-audit` — feature-level audit. If divergence is per-feature not per-component, run audit first.
- `react-revamp` — page-level UX revamp. If a single page is the problem, not the component, run flow first.
- `react-perf` — performance rules. Flagged when the audit finds re-render anti-patterns in the component itself.
- `react-composition` — architecture / API patterns. Flagged when audit finds prop bloat / inline components.

These four are loosely coupled. The audit recommends related skills in "Cross-component themes" — it doesn't drag them in automatically.
