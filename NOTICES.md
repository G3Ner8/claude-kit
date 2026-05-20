# Notices & Credits

This kit is MIT-licensed (see [LICENSE](./LICENSE)). Portions of it are derived from open-source projects listed below. Each derived skill carries its own attribution block in its README.

## Derived skills

### `plugins/react-core/skills/react-perf`

- **Upstream**: [vercel-labs/agent-skills/skills/react-best-practices](https://github.com/vercel-labs/agent-skills)
- **Upstream license**: MIT
- **Relationship**: Curated subset for Vite + TanStack Query SPAs. ~27 rules carried verbatim, ~9 rewritten for Vite/SWR→TanStack Query, ~29 upstream rules dropped (RSC / SSR / Next.js-specific). See [plugin README](./plugins/react-core/skills/react-perf/README.md) for the full mapping.

### `plugins/react-core/skills/react-composition`

- **Upstream**: [vercel-labs/agent-skills/skills/composition-patterns](https://github.com/vercel-labs/agent-skills)
- **Upstream license**: MIT
- **Relationship**: 8/8 patterns preserved. Examples rewritten from React Native primitives (`TextInput`, `onPress`) to web React (`<input>`, `onClick`). See [plugin README](./plugins/react-core/skills/react-composition/README.md).

## Project-internal skills & agents

All other skills (`react-audit`, `react-revamp`, `react-ux-review`, `react-dry`, `pps-ui`) and all three agents (`web-implement`, `web-polish`, `web-pre-commit`) were authored in-project. No external attribution required.

## Format & runtime

Built for [Claude Code](https://docs.claude.com/en/docs/claude-code). Skill/agent file formats and the plugin marketplace mechanism are defined by Anthropic — not redistributed here.
