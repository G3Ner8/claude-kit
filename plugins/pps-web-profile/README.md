# pps-web-profile

Project-specific Claude Code agents for the Aware `pps-web` codebase. This plugin is **not portable** — it carries hardcoded references to MC-1..MC-7, `EmployeeFormShell`, `payroll-dev-api` Swagger, and the `lint:structure` script.

If you don't work on `pps-web`, install [`react-core`](../react-core/) + [`react-agents`](../react-agents/) and run `/profile-generator` to scaffold your own profile.

## Install

```
/plugin install pps-web-profile@claude-kit
```

Requires [`react-core`](../react-core/) — agents invoke `react-audit`, `react-revamp`, `react-ux-review`, `react-dry`, `react-perf`, `react-composition`, `react-test-patterns` skills from there.

## Contents

### Agents

| Agent | Role | Model | Output language |
| --- | --- | --- | --- |
| [`web-implement`](./agents/web-implement.md) | Code builder + API debugger | opus | Thai |
| [`web-polish`](./agents/web-polish.md) | Cleanup + consistency | sonnet | Thai |
| [`web-pre-commit`](./agents/web-pre-commit.md) | Pre-commit gate (build verify, docs sync, commit draft) | sonnet | English |
| [`web-test`](./agents/web-test.md) | Test writer (retrofit / expand / integration) | opus | Thai |

None of the agents execute `git add` / `git commit` / `git push`. They draft and stop.

### Primitive guidance — adaptive, not a separate skill

Agents look up primitive choice + variants by reading `pps-web`'s own docs directly:

1. `pps-web/docs/components/<X>.md` — per-primitive details (Button, Drawer, etc.)
2. `pps-web/docs/architecture/design-system.md` — tokens + design principles + anti-patterns
3. `pps-web/src/components/ui/<X>.tsx` — implementation source

No separate `pps-ui` skill needed — agents read the canonical source of truth (which evolves alongside the code).

## How agents work

See the agent files for full behavior. High-level flow:

```
User: "implement leave-balance widget"   →  web-implement  (recon → plan → STOP)
User: "เริ่ม" / "start"                  →  web-implement  (apply → build → Thai report)
User: "ship it"                          →  web-pre-commit (gates → commit draft, English)
User: git commit                         →  (manual)
```

The full lifecycle (build → polish → commit) is documented in [the root README's workflows section](../../README.md#workflows).

## Forking for another project

Best path: don't fork this plugin — install [`react-agents`](../react-agents/) and run `/profile-generator`, which scans your project and asks ~5-7 questions to scaffold a fresh profile.

If you must fork:

1. Copy this folder to a new plugin name (e.g. `acme-web-profile/`).
2. Find-and-replace `pps-web` / `pps-api` / `Aware` / `payroll-dev-api` with your project's equivalents.
3. Update `agents/*.md` baseline references — they currently cite `pps-web/src/features/employee` and `pps-web/src/features/payroll` as canonical baselines.
4. Update MC-N rules if your project's `CLAUDE.md` deviates from the 7-section default template.

## License

MIT — see [../../LICENSE](../../LICENSE).
