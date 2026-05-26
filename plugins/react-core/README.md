# react-core

Seven Claude Code skills for React 19 / Vite SPA projects. Stack-agnostic across any web-React codebase — no project-specific bindings.

## Install

From a Claude Code session that has already added the parent marketplace:

```
/plugin install react-core@claude-kit
```

(See the [root README](../../README.md) for the marketplace add step.)

## Skills

| Skill | Purpose |
| --- | --- |
| [`react-perf`](./skills/react-perf/) | 40 React 19 + Vite + TanStack Query performance rules (waterfalls, bundles, re-renders, JS micro-opts). |
| [`react-composition`](./skills/react-composition/) | 8 React 19 composition patterns (boolean-prop bloat, compound components, context, render props, R19 API changes). |
| [`react-audit`](./skills/react-audit/) | Read-only audit. Three modes: single-feature, multi-feature divergence matrix, visual-consistency across pages. |
| [`react-revamp`](./skills/react-revamp/) | Read-only revamp proposal for a single page (discovery → audit → flow → sketches → plan). |
| [`react-ux-review`](./skills/react-ux-review/) | Read-only workflow critic across 9 UX dimensions (dirty tracking, validation, cancel, loading, keyboard, etc.). |
| [`react-dry`](./skills/react-dry/) | Read-only CSS/style/class divergence audit across one or more component usages. Table-first findings. |
| [`react-test-patterns`](./skills/react-test-patterns/) | Reference manual for Vitest 4 + React Testing Library 16 + MSW 2 test patterns. Layered conventions (schema / API / hook / component) consulted by the `*-test` agent. |

All read-only. None modify files. Each skill is self-contained — invoke individually (e.g. `/react-perf`) or let your agents call them via the `Skill` tool.

## Stack assumptions

- React ≥ 19.0
- Vite (or any non-SSR bundler — RSC / Next.js App Router rules are intentionally excluded)
- TanStack Query ≥ 5 or SWR ≥ 2 for client data fetching
- TypeScript (examples are TS; rules apply to JS)

If your stack differs, individual rules may still apply — read the per-skill rationale.

## Project conventions (for `react-audit`)

`react-audit` references a project-level mandatory-conventions doc (commonly `CLAUDE.md`). A reference template ships at [`docs/CONVENTIONS.template.md`](./docs/CONVENTIONS.template.md) with 7 default sections (HTML/a11y, Inputs, Tables, Modal/Drawer, Forms, i18n, Logging). Copy to your repo root, adapt to your stack, then point the audit at it.

## License

MIT — all seven skills authored in this repository. See [../../LICENSE](../../LICENSE) and [NOTICES.md](../../NOTICES.md).
