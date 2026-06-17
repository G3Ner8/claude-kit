# dev-core

Cross-cutting engineering-discipline skills for Claude Code — **stack-agnostic**, independent of framework or language. The foundational tier of claude-kit (the `react-*` plugins sit at the domain layer below).

## Install

From a Claude Code session that has already added the parent marketplace:

```
/plugin install dev-core@claude-kit
```

(See the [root README](../../README.md) for the marketplace add step.)

## Skills

Each skill is a **persona** — a stance the assistant adopts at a distinct moment of the lifecycle.

| Skill | Persona | Moment | Purpose | Try |
| --- | --- | --- | --- | --- |
| [`drafter`](./skills/drafter/) | 📐 drafter | **before** work | Turn a crystallized plan into a scope-tight, checkable work order for a headless coding agent (e.g. an SDC agent-ready issue). Preserves discovered knowledge (root cause, constraints, traps), drops choreography, makes acceptance criteria the contract. _(experimental)_ | "turn this plan into an agent issue" |
| [`detective`](./skills/detective/) | 🕵️ detective | **while** debugging | Reproduce → follow the fail path inward → falsify hypotheses → name the root cause **before** fixing. Breaks the "patch the symptom" reflex. _(experimental)_ | "why is X broken?" |
| [`inspector`](./skills/inspector/) | 🔎 inspector | **before** merge | Read-only intent-validation review of a diff / PR — does it do what the task asked, no more / no less? Surfaces scope creep, missed requirements, silent assumptions. No rubber-stamp. _(experimental)_ | "does this diff match the task?" |
| [`archivist`](./skills/archivist/) | 📚 archivist | **after** resolution | Standardized incident post-mortem / RCA (impact, timeline, single root cause, fix, prevention with owners), shaped so a future reader who wasn't there learns the lesson. _(experimental)_ | "document the login outage" |
| [`surveyor`](./skills/surveyor/) | 🗺️ surveyor | **between** cycles | Survey the real project state — reconcile declared status (backlog, status docs, tracker) against ground truth (merged history, MR/issue state, the code), report the drift, recommend next work by feasibility, offer to sync stale docs. Verifies, never trusts the doc. _(experimental)_ | "where are we — what's actually done?" |

Read-only deliverables — they produce a report / document and never touch code (`surveyor` can sync status docs, but only on explicit approval). Invoke individually (`/drafter`, `/detective`, `/inspector`, `/archivist`, `/surveyor`) from any project regardless of stack. The five line up across the lifecycle: **drafter** writes the work order, **detective** finds the cause, **inspector** gates the change, **archivist** preserves the lesson, **surveyor** surveys where it all stands.

## Why a separate tier

These apply to **any** codebase, not just React. Keeping them out of `react-core` keeps that plugin's scope honest (React 19 / Vite) and gives stack-agnostic disciplines a home that can grow (e.g. future commit-message, changelog, or ADR helpers).

`detective` is the framework-agnostic debug discipline; for React's backend↔frontend data-fetch chain specifically, `react-core` ships the specialized `react-debug`.

## License

MIT — authored in this repository. See [../../LICENSE](../../LICENSE).
