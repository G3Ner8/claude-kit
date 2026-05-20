# react-audit — Maintenance & Provenance

A read-only audit skill for frontend feature folders. Consolidates two legacy project agents (`inspect` and `align`) into a single procedure with single-feature and multi-feature modes.

## Why a single skill instead of two agents

The legacy `inspect` agent audited **one** feature; `align` audited **multiple** for cross-feature consistency. The actual audit procedure was 90% identical — the only difference was a final consolidation step (divergence matrix) in `align`.

Consolidating into one skill with a mode parameter:

- One file to maintain, not two
- The mode is naturally inferred from the input count
- Cross-references stay simple
- Invoking agents (`web-implement`, `web-polish`) call this skill in either mode without choosing the right sibling

## Stack assumptions

Procedure is **framework-agnostic**. Phases reference:

- A feature-folder structure (any pattern where related code lives under a single folder)
- A baseline/canonical feature (one or more) to compare against
- A design-token system (Tailwind, CSS variables, theme object, etc.)
- An i18n helper (any flavor — react-i18next, lingui, format.js)
- Optional: a Swagger/OpenAPI spec for API verification

Code examples in the rule body are written for React 19 + TypeScript + Tailwind because that's the most common stack, but the procedure works for any component-based UI codebase.

## Modes

| Mode | Triggered by | Adds |
|---|---|---|
| Single-feature | 1 target path | Per-area findings + plan |
| Multi-feature | 2+ target paths | Divergence matrix + winner column + cross-feature themes |

A single skill, two output templates. Mode detection is purely from input count.

## Read-only enforcement

The skill is **strictly read-only**. It can `Read`, `Glob`, `Grep`, `Bash` (for query commands) — never `Edit`, `Write`, `NotebookEdit`. The skill text spells this out at the bottom under "Stop Conditions" so any invoking agent (even ones with edit tools) defers to the user before changing code.

The invoking agent — not this skill — does the edits after the user approves.

## Refreshing / updating

This skill is project-internal (no upstream). To update:

1. Edit `SKILL.md` directly.
2. Bump `metadata.version` in frontmatter when behavior changes meaningfully.
3. Note the change in a top-level changelog if the repo has one.

## Related skills in this kit

- `react-perf` — performance rules. Audit reports point users here when they find perf smells.
- `react-composition` — architecture / API patterns. Audit reports point users here for prop-bloat, inline components, etc.
- `react-dry` — component CSS standardization. Audit reports point users here for cross-file CSS divergence.
- `react-revamp` — page-level UX revamp proposal. Audit triggers when scope is feature-level; for page-level redesign, use `react-revamp` instead.

These four are loosely coupled — each does one thing well. The audit doesn't drag the others in automatically; it recommends them.
