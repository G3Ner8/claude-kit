# dev-core

Cross-cutting engineering-discipline skills for Claude Code — **stack-agnostic**, independent of framework or language. The foundational tier of claude-kit (the `react-*` plugins sit at the domain layer below).

## Install

From a Claude Code session that has already added the parent marketplace:

```
/plugin install dev-core@claude-kit
```

(See the [root README](../../README.md) for the marketplace add step.)

## Skills

| Skill | Purpose |
| --- | --- |
| [`scrutinize`](./skills/scrutinize/) | Read-only intent-validation review of a diff / PR — does the change do what the task asked, no more / no less? Surfaces scope creep, missed requirements, silent assumptions. Run after pre-commit passes, before merge. _(experimental)_ |
| [`post-mortem`](./skills/post-mortem/) | Standardized incident post-mortem / RCA document (impact, timeline, single root cause, fix, prevention with owners). Run after an incident is resolved, never during firefighting. _(experimental)_ |

Both read-only — they produce a report / document, never edit code. Invoke individually (`/scrutinize`, `/post-mortem`) or from any project regardless of stack.

## Why a separate tier

These apply to **any** codebase, not just React. Keeping them out of `react-core` keeps that plugin's scope honest (React 19 / Vite) and gives stack-agnostic disciplines a home that can grow (e.g. future commit-message, changelog, or ADR helpers).

## License

MIT — authored in this repository. See [../../LICENSE](../../LICENSE).
