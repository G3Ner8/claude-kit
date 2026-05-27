# claude-kit

[![validate](https://github.com/G3Ner8/claude-kit/actions/workflows/validate.yml/badge.svg)](https://github.com/G3Ner8/claude-kit/actions/workflows/validate.yml)

A [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace for React 19 SPA work. Ships two installable plugins:

| Plugin | What | Portable? |
| --- | --- | --- |
| [`react-core`](./plugins/react-core/) | 10 skills — perf, composition, audit, revamp, ux-review, dry, test-patterns, debug, scrutinize, post-mortem | ✅ Any React 19 / Vite project |
| [`react-agents`](./plugins/react-agents/) | Templates + `/profile-generator` skill that scaffolds the build/polish/pre-commit trio for your project | ✅ Any React 19 / Vite project |

A filled-in worked example (the Aware `pps-web` profile) is kept under [`_archive/pps-web-profile/`](./_archive/pps-web-profile/) for reference — read it to see what a generated profile looks like. It is not published to the marketplace.

## Install

```
# In any Claude Code session
/plugin marketplace add G3Ner8/claude-kit
/plugin install react-core@claude-kit
/plugin install react-agents@claude-kit
```

For your own project, after installing `react-agents`:

```
/profile-generator
```

→ Claude asks ~28 questions in 5 short rounds, then writes a filled-in profile (4 agents + plugin manifest + README) to a folder you pick. Ready to symlink into `.claude/agents/` or push as its own plugin.

Update later with `/plugin marketplace update`.

## Why two plugins?

| Plugin | Role | Couples to |
|---|---|---|
| `react-core` | Stack-knowledge skills | React 19 / Vite (no project) |
| `react-agents` | Agent pattern + generator | Same — fully parameterized |

Splitting them means:

- Portable knowledge stays decoupled from any one repo.
- The agent **pattern** (build → polish → pre-commit trio) is reusable across projects via templates; the **content** (paths, conventions, Swagger URL) is per-project.
- A filled-in profile is project-specific, so it lives in your own repo (generate it with `/profile-generator`). The archived `_archive/pps-web-profile/` shows what one looks like.

## Plugin layout

```
claude-kit/
├── .claude-plugin/marketplace.json     # catalog (2 plugins)
├── plugins/
│   ├── react-core/                     # 7 portable skills
│   │   ├── .claude-plugin/plugin.json
│   │   ├── skills/{react-perf,react-composition,react-audit,
│   │   │           react-revamp,react-ux-review,react-dry,
│   │   │           react-test-patterns}/
│   │   └── docs/CONVENTIONS.template.md
│   └── react-agents/                   # templates + generator
│       ├── .claude-plugin/plugin.json
│       ├── skills/profile-generator/SKILL.md
│       ├── templates/agents/{implement,polish,pre-commit,test}.template.md
│       └── docs/{PLACEHOLDER-REFERENCE.md, FORK-GUIDE.md}
├── _archive/pps-web-profile/           # worked example (not published)
│   ├── .claude-plugin/plugin.json
│   └── agents/{web-implement,web-polish,web-pre-commit,web-test}.md
├── LICENSE                             # MIT
└── README.md
```

## Workflows (example, from the archived pps-web profile)

These show how a generated profile's agents drive a feature end-to-end. They reference the archived [`_archive/pps-web-profile/`](./_archive/pps-web-profile/) agents (`web-*`) as a concrete illustration — your own generated profile follows the same pattern with your project's names.

### Build a feature

```
User:  "implement leave-balance widget on EmployeeProfilePage"
       ↓
web-implement       Step 0 (recon → plan) → STOP
User:  "ลุย"
       ↓
web-implement       Chunked apply → build → Thai report (compact MC block)
       ↓
User:  "ship it"
       ↓
web-pre-commit      Bug scan · Build · Pre-flight · MC verify · Commit draft (English)
       ↓
User runs:  git commit
```

### Revamp a page

```
User:  "revamp LeaveListPage เช็ค BE ด้วย"
       ↓
web-implement       BE-scope (Swagger) → recon → audit → mockup → plan → STOP
User:  "ลุย chunks 1-2"
       ↓
web-implement       Chunked apply → build → Thai report
User:  "polish the diff"  →  web-polish
User:  "ship it"          →  web-pre-commit
```

### Cross-feature consistency

```
User:  "align leave, attendance, timesheet"
       ↓
web-polish    →  react-audit (multi-mode) → divergence matrix → STOP
User picks rows + "ลุย"  →  web-polish (plan → STOP)
User:  "ลุย chunks"      →  web-polish (apply → build → Thai report)
```

### Standalone skill (no agent)

```
User:  "/react-dry"  or  "audit Button usages, just findings"
       ↓
react-dry           AskUserQuestion → discover → findings table
```

Read-only output. User reads, decides, no edit.

## Versioning

- This repo follows [Semantic Versioning](https://semver.org/). Plugins are versioned independently in their `plugin.json`.
- Bumps are tracked per plugin in [CHANGELOG.md](./CHANGELOG.md).
- For active development, pin to `main`. For stability, install at a tag (`/plugin install react-core@claude-kit@v0.1.0`).

## License

MIT — all skills and agents authored in this repository. See [LICENSE](./LICENSE).

Kit code: **MIT**, see [LICENSE](./LICENSE).

## Contributing

This is a personal kit, not actively accepting external PRs. If you want to riff on it, fork freely. For bug reports specific to a skill or agent, open an issue and tag the plugin name.
