# claude-kit

[![validate](https://github.com/G3Ner8/claude-kit/actions/workflows/validate.yml/badge.svg)](https://github.com/G3Ner8/claude-kit/actions/workflows/validate.yml)

A tiered [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace: stack-agnostic disciplines on top, React 19 / Vite tooling below.

| Plugin | What | Scope |
| --- | --- | --- |
| [`dev-core`](./plugins/dev-core/) | `drafter` (plan → agent work order) · `detective` (debug discipline) · `inspector` (intent-validation diff review) · `archivist` (incident post-mortem) · `surveyor` (project-status survey) | Any stack · experimental |
| [`react-core`](./plugins/react-core/) | 8 React skills — perf, composition, audit, revamp, ux-review, dry, test-patterns, debug | React 19 / Vite · stable |
| [`react-agents`](./plugins/react-agents/) | `/profile-generator` + agent templates (build → polish → pre-commit → test) | React 19 / Vite · stable |

The `dev-core` five are personas spanning the work lifecycle: **drafter** writes the work order, **detective** finds the cause, **inspector** gates the change, **archivist** preserves the lesson, **surveyor** surveys where it all stands.

## Install

```
/plugin marketplace add G3Ner8/claude-kit
/plugin install dev-core@claude-kit       # any stack — the foundational tier
/plugin install react-core@claude-kit     # React 19 / Vite projects only
/plugin install react-agents@claude-kit   # React 19 / Vite projects only
```

Update later with `/plugin marketplace update`.

## Use it

Skills work immediately — invoke any with `/<skill>` (`/detective`, `/react-perf`, …) or let your agents call them.

For the agent quartet (implement / polish / pre-commit / test), generate a project-specific profile:

```
/profile-generator
```

A short interview scans your repo and writes a filled-in profile (4 agents + manifest) to a transient folder (default `/tmp/<project>-profile`); copy the `agents/*.md` into your project's `.claude/agents/` and discard the rest. See [`react-agents`](./plugins/react-agents/) for how the agents work and which skills each one calls, and [`PLACEHOLDER-REFERENCE.md`](./plugins/react-agents/docs/PLACEHOLDER-REFERENCE.md) for example values of every placeholder.

## Versioning & license

SemVer per plugin (see [CHANGELOG.md](./CHANGELOG.md)) — pin a tag for stability, `main` for latest. MIT — see [LICENSE](./LICENSE).

## Contributing

Personal kit — not taking external PRs, but fork freely. For a bug in a specific skill or agent, open an issue and tag the plugin name.
