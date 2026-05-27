# claude-kit

[![validate](https://github.com/G3Ner8/claude-kit/actions/workflows/validate.yml/badge.svg)](https://github.com/G3Ner8/claude-kit/actions/workflows/validate.yml)

A tiered [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace: stack-agnostic disciplines on top, React 19 / Vite tooling below.

| Plugin | What | Scope |
| --- | --- | --- |
| [`dev-core`](./plugins/dev-core/) | `detective` (debug discipline) · `inspector` (intent-validation diff review) · `archivist` (incident post-mortem) | Any stack |
| [`react-core`](./plugins/react-core/) | 8 React skills — perf, composition, audit, revamp, ux-review, dry, test-patterns, debug | React 19 / Vite |
| [`react-agents`](./plugins/react-agents/) | `/profile-generator` + agent templates (build → polish → pre-commit → test) | React 19 / Vite |

## Install

```
/plugin marketplace add G3Ner8/claude-kit
/plugin install dev-core@claude-kit       # optional — any stack
/plugin install react-core@claude-kit
/plugin install react-agents@claude-kit
```

Update later with `/plugin marketplace update`.

## Use it

Skills work immediately — invoke any with `/<skill>` (`/react-perf`, `/detective`, …) or let your agents call them.

For the agent quartet (implement / polish / pre-commit / test), generate a project-specific profile:

```
/profile-generator
```

A short interview scans your repo and writes a filled-in profile (4 agents + manifest) to a folder you pick. See [`react-agents`](./plugins/react-agents/) for how the agents work and which skills each one calls.

> `_archive/pps-web-profile/` is a worked example of generator output (not published to the marketplace).

## Versioning & license

SemVer per plugin (see [CHANGELOG.md](./CHANGELOG.md)) — pin a tag for stability, `main` for latest. MIT — see [LICENSE](./LICENSE).

## Contributing

Personal kit — not taking external PRs, but fork freely. For a bug in a specific skill or agent, open an issue and tag the plugin name.
