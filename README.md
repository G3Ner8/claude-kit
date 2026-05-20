# claude-kit

A [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace for React 19 SPA work. Ships two installable plugins:

| Plugin | What | Portable? |
| --- | --- | --- |
| [`react-core`](./plugins/react-core/) | 6 skills — perf, composition, audit, revamp, ux-review, dry | ✅ Any React 19 / Vite project |
| [`pps-web-profile`](./plugins/pps-web-profile/) | 1 skill + 3 agents — `pps-ui` inventory + build/polish/pre-commit agents | ❌ Aware `pps-web` only (fork as template) |

## Install

```
# In any Claude Code session
/plugin marketplace add chettawat-p/claude-kit
/plugin install react-core@claude-kit
/plugin install pps-web-profile@claude-kit   # only if you work on pps-web
```

Replace `chettawat-p` with the actual GitHub owner once the repo is pushed.

Update later with `/plugin marketplace update`.

## Why two plugins?

`react-core` is stack-knowledge that travels across projects. `pps-web-profile` is the lived-in working reference — agents wired to specific baselines, Swagger URLs, MC-1..MC-7 conventions. Splitting them means:

- Outside contributors install only what's portable.
- The profile stays free to embed project-specific paths without polluting the portable core.
- New projects can copy `pps-web-profile/` as a template, replace bindings, and publish their own profile plugin against the same `react-core`.

## Plugin layout

```
claude-kit/
├── .claude-plugin/marketplace.json     # catalog (2 plugins)
├── plugins/
│   ├── react-core/                     # portable
│   │   ├── .claude-plugin/plugin.json
│   │   ├── skills/{react-perf,react-composition,react-audit,
│   │   │           react-revamp,react-ux-review,react-dry}/
│   │   └── docs/CONVENTIONS.template.md
│   └── pps-web-profile/                # project-bound
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
