# dev-core

Cross-cutting engineering-discipline skills for Claude Code — **stack-agnostic**, independent of framework or language. The foundational tier of claude-kit (`react-core` and `agent-profiles` sit at the domain layer below).

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
| [`architect`](./skills/architect/) | 🏛️ architect | **before** a plan exists | Design an implementation plan from a spec — explore the codebase, name the target and its traps, grill open design forks, lock interfaces, decompose into independently testable tasks with checkable acceptance criteria. Produces the plan `drafter` consumes. _(experimental)_ | "plan X" / "write an implementation plan for X" |
| [`drafter`](./skills/drafter/) | 📐 drafter | **before** work | Turn a crystallized plan into a scope-tight, checkable work order for a headless coding agent (e.g. an SDC agent-ready issue). Preserves discovered knowledge (root cause, constraints, traps), drops choreography, makes acceptance criteria the contract. _(experimental)_ | "turn this plan into an agent issue" |
| [`detective`](./skills/detective/) | 🕵️ detective | **while** debugging | Reproduce → follow the fail path inward → falsify hypotheses → name the root cause **before** fixing. Breaks the "patch the symptom" reflex. _(experimental)_ | "why is X broken?" |
| [`inspector`](./skills/inspector/) | 🔎 inspector | **before** merge | Read-only intent-validation review of a diff / PR — does it do what the task asked, no more / no less? Surfaces scope creep, missed requirements, silent assumptions. No rubber-stamp. _(experimental)_ | "does this diff match the task?" |
| [`archivist`](./skills/archivist/) | 📚 archivist | **after** resolution | Standardized incident post-mortem / RCA (impact, timeline, single root cause, fix, prevention with owners), shaped so a future reader who wasn't there learns the lesson. _(experimental)_ | "document the login outage" |
| [`scout`](./skills/scout/) | 🔭 scout | **before** or **during** work | Reconnaissance on fresh code — fetch first, then go look at a point (a work item, a list of them, the branch you are on, a function, a checkable question), follow its connections to the boundary (frontend to backend API included), and report what is there and what looks wrong within line of sight. Sees, never investigates — sightings hand off to `detective`. _(experimental)_ | "scout X before I start" / "check my queue" / "where am I on X" |
| [`herald`](./skills/herald/) | 📯 herald | **at** release | Tell the people who test or use a frontend what changed on screen between two tags (or in one MR) — every visible add, change and removal, each proven at `file:line` in the diff and tied to the test cases the issue names, so a red automated test reads as "update the test" or "file a bug". Announces, never judges. _(experimental)_ | "what changed for QA since the last tag" / "QA handoff for 0.0.2.0" |

Read-only deliverables — they produce a report / document and never touch code (`scout` fetches, fast-forwards a clean integration checkout, and syncs status markers in a work list only when explicitly asked). Invoke individually (`/architect`, `/drafter`, `/detective`, `/inspector`, `/archivist`, `/scout`, `/herald`) from any project regardless of stack. The seven line up across the lifecycle: **scout** looks before anyone commits, **architect** designs the plan, **drafter** writes the work order, **detective** finds the cause, **inspector** gates the change, **herald** tells the testers what they will see, **archivist** preserves the lesson.

## Why a separate tier

These apply to **any** codebase, not just React. Keeping them out of `react-core` keeps that plugin's scope honest (React 19 / Vite) and gives stack-agnostic disciplines a home that can grow (e.g. future commit-message, changelog, or ADR helpers).

`detective` is the framework-agnostic debug discipline; for React's backend↔frontend data-fetch chain specifically, `react-core` ships the specialized `react-debug`.

## License

MIT — authored in this repository. See [../../LICENSE](../../LICENSE).
