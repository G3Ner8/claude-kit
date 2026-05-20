# react-revamp — Maintenance & Provenance

A read-only proposal skill for revamping the UX/UI flow of a single frontend page. Replaces the legacy `flow` agent — same procedure, now invokable from any agent (typically `web-implement`).

## Why a skill, not an agent

The legacy `flow` agent did one thing: propose a flow revamp for one page, then stop. That's a self-contained **procedure**, not a role — moving it to a skill lets any role-agent (e.g. `web-implement`) invoke it when needed, and lets the procedure be maintained independently.

The skill stays read-only by design. The invoking agent — not this skill — performs the edits after the user approves the proposal.

## Stack assumptions

Procedure is **framework-agnostic**. It assumes:

- A single-page-per-route pattern (any router)
- A design-token system (Tailwind, CSS variables, theme object)
- Optional: a Swagger/OpenAPI spec for API verification
- An i18n helper of some kind (the proposal flags raw string literals)

Code examples in the skill body are framework-neutral — the patterns work for React, Vue, Svelte, Solid, any component framework.

## Inputs

The skill mandates `AskUserQuestion` up front to collect:

- Target page path
- Reference / canonical page paths
- Design tokens location
- API discovery method (Swagger URL / OpenAPI path / skip)
- Output language (EN/TH — flow proposals are almost always long)

Optional follow-ups (max 1–2): primary user goal, constraints.

## Output

A single structured markdown report with:

- Inputs echo, Discovery, Audit findings
- Proposed flow (5–10 step user journey)
- Layout sketches per state (default / loading / empty / error / success)
- Component decisions (reuse / copy-from / new with justification)
- State map
- Execution plan (commit-sized chunks)
- Best practices (UX/UI + Arch/Dev)
- Open questions
- Read-only sign-off

## Read-only enforcement

Spelled out in the skill body under "Stop Conditions". The skill can `Read`, `Glob`, `Grep`, `WebFetch`, `Bash` (for query commands) — never `Edit`, `Write`, `NotebookEdit`. After producing the proposal, the turn ends.

## Refreshing / updating

Project-internal (no upstream). To update:

1. Edit `SKILL.md` directly.
2. Bump `metadata.version` when behavior changes meaningfully.
3. Note the change in a top-level changelog if the repo has one.

## Related skills in this kit

- `react-audit` — feature-level consistency audit (this skill is page-level; if the issue spans multiple features, audit first)
- `react-perf` — performance rules; this skill flags perf smells and points users here
- `react-composition` — architecture/API patterns; flagged when the page has prop bloat / inline components
- `react-dry` — component CSS standardization; flagged when the page's children diverge on tokens

These four are loosely coupled — each does one thing well. The proposal recommends them; it doesn't drag them in automatically.
