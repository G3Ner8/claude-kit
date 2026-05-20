# claude-kit

A [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace for React 19 SPA work. Ships three installable plugins:

| Plugin | What | Portable? |
| --- | --- | --- |
| [`react-core`](./plugins/react-core/) | 6 skills — perf, composition, audit, revamp, ux-review, dry | ✅ Any React 19 / Vite project |
| [`react-agents`](./plugins/react-agents/) | Templates + `/profile-generator` skill that scaffolds the build/polish/pre-commit trio for your project | ✅ Any React 19 / Vite project |
| [`pps-web-profile`](./plugins/pps-web-profile/) | Worked example: 1 skill + 3 agents filled in for Aware `pps-web` | ❌ Reference only — fork via `react-agents` for your own project |

## Install

```
# In any Claude Code session
/plugin marketplace add G3Ner8/claude-kit
/plugin install react-core@claude-kit
/plugin install react-agents@claude-kit

# Optional: install the pps-web reference profile as a working example
/plugin install pps-web-profile@claude-kit
```

For your own project, after installing `react-agents`:

```
/profile-generator
```

→ Claude asks ~22 questions in 4 short rounds, then writes a filled-in profile (3 agents + plugin manifest + README) to a folder you pick. Ready to symlink into `.claude/agents/` or push as its own plugin.

Update later with `/plugin marketplace update`.

## Why three plugins?

| Plugin | Role | Couples to |
|---|---|---|
| `react-core` | Stack-knowledge skills | React 19 / Vite (no project) |
| `react-agents` | Agent pattern + generator | Same — fully parameterized |
| `pps-web-profile` | Aware-specific working example | `pps-web` repo |

Splitting them means:

- Portable knowledge stays decoupled from any one repo.
- The agent **pattern** (build → polish → pre-commit trio) is reusable across projects via templates; the **content** (paths, conventions, Swagger URL) is per-project.
- `pps-web-profile` becomes a worked example that shows what a filled-in profile looks like — newcomers can read it as documentation.

## Plugin layout

```
claude-kit/
├── .claude-plugin/marketplace.json     # catalog (3 plugins)
├── plugins/
│   ├── react-core/                     # 6 portable skills
│   │   ├── .claude-plugin/plugin.json
│   │   ├── skills/{react-perf,react-composition,react-audit,
│   │   │           react-revamp,react-ux-review,react-dry}/
│   │   └── docs/CONVENTIONS.template.md
│   ├── react-agents/                   # templates + generator
│   │   ├── .claude-plugin/plugin.json
│   │   ├── skills/profile-generator/SKILL.md
│   │   ├── templates/agents/{implement,polish,pre-commit}.template.md
│   │   └── docs/{PLACEHOLDER-REFERENCE.md, FORK-GUIDE.md}
│   └── pps-web-profile/                # Aware reference profile
│       ├── .claude-plugin/plugin.json
│       ├── skills/pps-ui/
│       └── agents/{web-implement,web-polish,web-pre-commit}.md
├── NOTICES.md                          # upstream attribution
├── LICENSE                             # MIT
└── README.md
```

## Workflows (pps-web-profile)

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

## Provenance & license

`react-perf` and `react-composition` are curated forks of [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (MIT). All other skills and agents are project-internal. Full attribution: [NOTICES.md](./NOTICES.md).

Kit code: **MIT**, see [LICENSE](./LICENSE).

## Contributing

This is a personal kit, not actively accepting external PRs. If you want to riff on it, fork freely. For bug reports specific to a skill or agent, open an issue and tag the plugin name.
