# Install

Three ways to consume claude-kit, in order of recommendation.

## A — Plugin marketplace (recommended)

```
/plugin marketplace add G3Ner8/claude-kit
/plugin install react-core@claude-kit
/plugin install react-agents@claude-kit
/plugin install pps-web-profile@claude-kit   # optional reference profile
```

For your own project, after `react-agents` is installed, run `/profile-generator` and answer ~22 questions to scaffold a filled-in agent trio.

Updates: `/plugin marketplace update` then re-install if a plugin's `version` field bumped.

Uninstall: `/plugin uninstall react-core@claude-kit`.

Private repo? Set `GITHUB_TOKEN` in your environment so Claude Code can read the catalog.

## B — Local symlinks (active development)

If you're editing this kit and want changes to land in your project immediately:

```bash
# From your project root
cd "$(git rev-parse --show-toplevel)"
mkdir -p .claude/skills .claude/agents

# react-core skills
for skill in react-perf react-composition react-audit react-revamp react-ux-review react-dry; do
  ln -s "$HOME/Workspace/claude-kit/plugins/react-core/skills/$skill" \
        ".claude/skills/$skill"
done

# pps-web-profile (only for pps-web)
ln -s "$HOME/Workspace/claude-kit/plugins/pps-web-profile/skills/pps-ui" \
      ".claude/skills/pps-ui"
for agent in web-implement web-polish web-pre-commit; do
  ln -s "$HOME/Workspace/claude-kit/plugins/pps-web-profile/agents/$agent.md" \
        ".claude/agents/$agent.md"
done
```

Edits to `~/Workspace/claude-kit/` propagate to the project on the next Claude Code session.

## C — Copy (frozen snapshot)

```bash
cd "$(git rev-parse --show-toplevel)"
mkdir -p .claude/skills .claude/agents
cp -R "$HOME/Workspace/claude-kit/plugins/react-core/skills/"* .claude/skills/
cp -R "$HOME/Workspace/claude-kit/plugins/pps-web-profile/skills/pps-ui" .claude/skills/
cp "$HOME/Workspace/claude-kit/plugins/pps-web-profile/agents/"*.md .claude/agents/
```

No live updates — re-copy when you want a refresh.

## Verifying

```
/agents     # web-implement, web-polish, web-pre-commit must appear (if pps-web-profile installed)
```

Quick functional test: ask "audit Button usages" — response should reference `react-dry`'s table-first findings format.
