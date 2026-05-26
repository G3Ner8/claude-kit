# pps-web-profile

Project-specific Claude Code agents and primitive inventory for the Aware `pps-web` codebase. This plugin is **not portable** — it carries hardcoded references to MC-1..MC-7, `EmployeeFormShell`, `payroll-dev-api` Swagger, the `lint:structure` script, and the 65-primitive inventory in `pps-web/src/components/ui/`.

If you don't work on `pps-web`, install [`react-core`](../react-core/) only and fork this plugin's agents as a starting template.

## Install

```
/plugin install pps-web-profile@claude-kit
```

Requires [`react-core`](../react-core/) to be useful — the agents invoke `react-audit`, `react-revamp`, `react-ux-review`, `react-dry` skills from there.

## Contents

### Agents

| Agent | Role | Model | Output language |
| --- | --- | --- | --- |
| [`web-implement`](./agents/web-implement.md) | Code builder + API debugger | opus | Thai |
| [`web-polish`](./agents/web-polish.md) | Cleanup + consistency | sonnet | Thai |
| [`web-pre-commit`](./agents/web-pre-commit.md) | Pre-commit gate (build verify, docs sync, commit draft) | sonnet | English |

None of the agents execute `git add` / `git commit` / `git push`. They draft and stop.

### Skills

| Skill | Purpose |
| --- | --- |
| [`pps-ui`](./skills/pps-ui/) | 65-primitive inventory of `pps-web/src/components/ui/` + "don't roll your own" decision rules. |

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

This plugin is the working reference for what a project-bound profile looks like. To adapt for a new project:

1. Copy this folder to a new plugin name (e.g. `acme-web-profile/`).
2. Find-and-replace `pps-web` / `pps-api` / `Aware` / `payroll-dev-api` with your project's equivalents.
3. Rewrite `skills/pps-ui/` against your project's primitive inventory (the README inside the skill has detailed instructions).
4. Update `agents/*.md` baseline references — they currently cite `pps-web/src/features/employee` and `pps-web/src/features/payroll` as canonical baselines.
5. Update MC-N rules if your project's `CONVENTIONS.md` deviates from the 7-section default template.

## License

MIT — see [../../LICENSE](../../LICENSE).
