# react-agents

Templates + interactive generator for the build/polish/pre-commit subagent trio used by [claude-kit](../../README.md). Pairs with [`react-core`](../react-core/) (the skills the agents invoke).

## Install

```
/plugin install react-agents@claude-kit
```

## What's in it

| Piece | Path | Purpose |
| --- | --- | --- |
| `profile-generator` skill | [`skills/profile-generator/`](./skills/profile-generator/) | Interactive scaffolder. Invoke via `/profile-generator`. |
| Agent templates | [`templates/agents/`](./templates/agents/) | `{{PLACEHOLDER}}` versions of `implement` / `polish` / `pre-commit` agents. |
| Placeholder reference | [`docs/PLACEHOLDER-REFERENCE.md`](./docs/PLACEHOLDER-REFERENCE.md) | Every placeholder defined with example values. |
| Fork guide | [`docs/FORK-GUIDE.md`](./docs/FORK-GUIDE.md) | Manual fork instructions (if you don't want the generator). |

## Two ways to use

### A — Interactive (recommended)

```
/profile-generator
```

Claude asks ~22 questions in 4 short rounds (project name, paths, commands, BE settings), confirms once, then writes a complete profile to a folder you pick. Output is ready to symlink into `.claude/agents/` or `git init` + push as its own plugin.

### B — Manual fork

If you'd rather edit the templates yourself: copy `templates/agents/*.template.md` into your project, do find-replace on the placeholders documented in [`docs/PLACEHOLDER-REFERENCE.md`](./docs/PLACEHOLDER-REFERENCE.md), and place the result under your project's `.claude/agents/`. See [`docs/FORK-GUIDE.md`](./docs/FORK-GUIDE.md) for step-by-step.

## What the generated profile contains

```
<output-folder>/
├── .claude-plugin/plugin.json
├── README.md
├── agents/
│   ├── <prefix>-implement.md     # builder + API debugger
│   ├── <prefix>-polish.md        # cleanup + consistency
│   └── <prefix>-pre-commit.md    # pre-commit gate
└── skills/
    └── <project>-ui/             # optional UI inventory stub
        ├── SKILL.md
        └── README.md
```

All three agents:
- Reference your project's `CLAUDE.md` (or whatever you name it) as the source of truth for MC-1..MC-N conventions
- Invoke `react-core` skills (`react-audit`, `react-revamp`, `react-ux-review`, `react-dry`, `react-perf`, `react-composition`) when triggered
- Do NOT execute `git add` / `commit` / `push` — they draft and stop

## Working reference

The Aware `pps-web` profile is shipped as a separate plugin ([`pps-web-profile`](../pps-web-profile/)) — install or read it as a worked example of a filled-in profile.

## License

MIT — see [../../LICENSE](../../LICENSE).
