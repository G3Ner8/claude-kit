# Changelog

All notable changes to this kit are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the kit uses [Semantic Versioning](https://semver.org/).

Plugins are versioned independently in their `plugin.json`. The headings below group changes by plugin.

## [Unreleased]

### `react-agents` 0.1.0
- New plugin shipping three agent templates (`implement` / `polish` / `pre-commit`) with `{{PLACEHOLDER}}` substitution points for project-specific content.
- New `profile-generator` skill (`/profile-generator`) — interactive 4-round AskUserQuestion flow that gathers project facts, substitutes placeholders, and writes a complete filled-in profile (agents + plugin.json + README + optional UI inventory stub) to a user-chosen folder.
- Ships `docs/PLACEHOLDER-REFERENCE.md` (all 22 placeholders documented with example values from `pps-web`) and `docs/FORK-GUIDE.md` (manual fork procedure).

### Marketplace
- Added `react-agents` to `marketplace.json`.
- Reframed `pps-web-profile` as a worked example rather than primary distribution.

## [0.1.0] — 2026-05-20

Initial extraction from the in-tree `Aware Payroll/claude-kit/` into a standalone plugin marketplace.

### `react-core` 0.1.0
- Added six skills: `react-perf`, `react-composition`, `react-audit`, `react-revamp`, `react-ux-review`, `react-dry`.
- De-coupled from `pps-web`: `react-audit` Phase E now references the user's project conventions doc (template at `docs/CONVENTIONS.template.md`) instead of `pps-web/CLAUDE.md`; `react-dry` example codebase path generalized.
- Provenance preserved: `react-perf` and `react-composition` retain `derived_from: vercel-labs/agent-skills` in frontmatter and full upstream mapping in their READMEs.

### `pps-web-profile` 0.1.0
- Added one skill (`pps-ui`) and three agents (`web-implement`, `web-polish`, `web-pre-commit`) verbatim from the in-tree kit.
- README explicitly marks this plugin as project-bound and points readers at the agents themselves as a forking template.
